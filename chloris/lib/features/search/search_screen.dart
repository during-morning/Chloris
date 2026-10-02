import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';
import '../../core/persist/kv_settings.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_icons.dart';
import '../../app/illustration/sketch.dart';
import '../../app/widgets/app_motion.dart';
import '../../app/widgets/meow.dart';
import '../../core/search/incremental_merge.dart';
import 'search_provider.dart';
import '../book_detail/open_book.dart';
import '../library/online_shelf_provider.dart';
import '../sources/source_debug_screen.dart';
import '../sources/source_library_provider.dart';

part 'search_results.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _merged = true;
  bool _precise = false;
  String _scope = '';
  String _draft = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(_restore);
  }

  Future<void> _restore() async {
    final kv = KvSettings.instance;
    final merged = await kv.getBool('searchMerged');
    final precise = await kv.getBool('searchPrecise');
    final last = await kv.getString('searchLastQuery');
    final scope = await kv.getString('searchScope');
    if (!mounted) return;
    setState(() {
      if (merged != null) _merged = merged;
      if (precise != null) _precise = precise;
      _scope = '';
      if (scope != null) _scope = scope;
    });
    if (_controller.text.isEmpty) {
      final hist = ref.read(searchHistoryProvider);
      final fill = (last != null && last.isNotEmpty)
          ? last
          : (hist.isNotEmpty ? hist.first : '');
      if (fill.isNotEmpty) _controller.text = fill;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final q = _controller.text.trim();
    ref.read(searchQueryProvider.notifier).state = q;
    if (q.isNotEmpty) {
      ref.read(searchHistoryProvider.notifier).add(q);
      KvSettings.instance.setString('searchLastQuery', q);
    }
    ref.read(searchControllerProvider.notifier).run(q, precise: _precise);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(searchControllerProvider);
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.paper,
      body: MeowPage(
        eyebrow: '搜索',
        title: '寻找书籍',
        fullBleedBody: true,
        actions: [
          MeowChip(
            label: _merged ? '合并' : '分源',
            active: true,
            onTap: () {
              setState(() => _merged = !_merged);
              KvSettings.instance.setBool('searchMerged', _merged);
            },
          ),
          MeowChip(
            label: '精确',
            active: _precise,
            onTap: () {
              setState(() => _precise = !_precise);
              KvSettings.instance.setBool('searchPrecise', _precise);
            },
          ),
          MeowGhostButton(
            icon: AppIcons.copy,
            label: '复制结果',
            onPressed: () async {
              final books = session.rows.expand((r) => r.books).toList();
              final json = const JsonEncoder.withIndent('  ').convert(
                books
                    .map(
                      (b) => {
                        'name': b.name,
                        'author': b.author,
                        'bookUrl': b.bookUrl,
                        'originName': b.originName,
                        'latest': b.latestChapterTitle,
                      },
                    )
                    .toList(),
              );
              await Clipboard.setData(ClipboardData(text: json));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已复制 ' + books.length.toString() + ' 条'),
                  ),
                );
              }
            },
          ),
        ],
        child: Column(
          children: [
            MeowQueryField(
              controller: _controller,
              hint: '书名、作者，回车即搜',
              onChanged: (v) {
                setState(() => _draft = v.trim());
              },
              trailing: [
                IconButton(
                  tooltip: session.finished ? '搜索' : '打断并重新搜索',
                  icon: AppIcon(
                    session.finished ? AppIcons.forward : AppIcons.restart,
                  ),
                  onPressed: _submit,
                ),
              ],
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            if (_draft.length >= 1 && session.query != _draft)
              _SuggestRow(
                draft: _draft,
                onPick: (q) {
                  _controller.text = q;
                  _submit();
                },
              ),
            if (session.total > 0) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: session.total == 0 ? 0 : session.done / session.total,
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '已扫 ' +
                      session.done.toString() +
                      '/' +
                      (session.universe > 0 ? session.universe : session.total)
                          .toString() +
                      ' 源 · 命中 ' +
                      session.hits.toString() +
                      (session.failCount > 0
                          ? ' · 失败 ' + session.failCount.toString()
                          : '') +
                      (session.remaining > 0
                          ? ' · 还剩 ' + session.remaining.toString()
                          : ''),
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: c.muted),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: session.query.isEmpty
                  ? _History(
                      onPick: (q) {
                        _controller.text = q;
                        _submit();
                      },
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: _merged
                              ? _MergedList(
                                  rows: session.rows,
                                  query: session.query,
                                  precise: _precise,
                                )
                              : _BySourceList(
                                  rows: session.rows,
                                  query: session.query,
                                ),
                        ),
                        if (session.finished && session.query.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextButton(
                              onPressed: () => ref
                                  .read(searchControllerProvider.notifier)
                                  .loadMore(),
                              child: Text('加载更多 · 第${session.page + 1}页'),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
