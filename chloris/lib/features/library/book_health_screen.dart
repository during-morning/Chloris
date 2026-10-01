import 'dart:async';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../application/online/online_book_port.dart';
import '../../app/theme/app_icons.dart';
import '../../core/http/http_session.dart';
import '../../core/read/book_validation.dart';
import 'online_shelf_provider.dart';

class BookHealthScreen extends ConsumerStatefulWidget {
  const BookHealthScreen({super.key});
  @override
  ConsumerState<BookHealthScreen> createState() => _BookHealthState();
}

class _Health {
  const _Health(this.message, {this.invalid = false, this.valid = false});
  final String message;
  final bool invalid, valid;
}

class _BookHealthState extends ConsumerState<BookHealthScreen> {
  final _results = <String, _Health>{}, _sessions = <String>{};
  OnlineBookPort? _port;
  int _generation = 0, _done = 0;
  bool _running = false;
  void _cancel() {
    _generation++;
    for (final id in _sessions) {
      _port?.cancelSession(id);
    }
    _sessions.clear();
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  Future<void> _run() async {
    _cancel();
    final generation = _generation;
    final items = List<OnlineShelfItem>.of(ref.read(onlineShelfProvider));
    setState(() {
      _running = true;
      _done = 0;
      _results.clear();
    });
    final port = ref.read(onlineBookPortProvider);
    _port = port;
    var cursor = 0;
    Future<void> worker() async {
      while (cursor < items.length && mounted && generation == _generation) {
        final item = items[cursor++],
            id =
                'book-health.$generation.${DateTime.now().microsecondsSinceEpoch}';
        _Health result;
        final issue = bookIdentityError(
          name: item.searchBook.name,
          url: item.candidateBookUrl,
        );
        if (issue != null) {
          result = _Health(issue, invalid: true);
        } else {
          _sessions.add(id);
          try {
            result =
                await HttpSession.bind(id, () async {
                  final book = item.searchBook.toBook();
                  book.tocUrl = book.tocUrl.isEmpty
                      ? item.candidateBookUrl
                      : book.tocUrl;
                  final toc = await port.loadChapterList(
                    item.source,
                    book,
                    maxPages: 1,
                  );
                  final chapters = toc
                      .where((c) => !c.isVolume && c.url.trim().isNotEmpty)
                      .toList();
                  if (chapters.isEmpty)
                    return const _Health('书源返回空目录，可换源或移除', invalid: true);
                  if (generation != _generation) throw StateError('检查已取消');
                  final content = ref.read(
                    loadOnlineChapterContentUseCaseProvider,
                  );
                  for (final entry in chapters.take(3).toList().asMap().entries) {
                    try {
                      final body = await content(
                        source: item.source,
                        book: book,
                        chapter: entry.value,
                        nextChapterUrl: entry.key + 1 < chapters.length
                            ? chapters[entry.key + 1].url
                            : null,
                      );
                      if (body.trim().isNotEmpty) {
                        return _Health(
                          '目录 ' +
                              chapters.length.toString() +
                              ' 章，正文可读取',
                          valid: true,
                        );
                      }
                    } on DomainError catch (error) {
                      if (error.code != 'content_empty') rethrow;
                    }
                  }
                  return const _Health('前 3 章均无可读正文，可换源或移除', invalid: true);
                }).timeout(
                  const Duration(seconds: 15),
                  onTimeout: () {
                    port.cancelSession(id);
                    throw TimeoutException('检查超时');
                  },
                );
          } on DomainError catch (e) {
            result = e.code == 'content_empty'
                ? const _Health('前 3 章均无可读正文，可换源或移除', invalid: true)
                : _Health('暂时无法验证：' + e.toString().split('\n').first);
          } catch (e) {
            result = _Health('暂时无法验证：${e.toString().split('\n').first}');
          } finally {
            _sessions.remove(id);
            port.cancelSession(id);
          }
        }
        if (!mounted || generation != _generation) return;
        setState(() {
          _results[item.bookUrl] = result;
          _done++;
        });
      }
    }

    await Future.wait(List.generate(items.length.clamp(0, 2), (_) => worker()));
    if (mounted && generation == _generation) setState(() => _running = false);
  }

  Future<void> _remove(List<OnlineShelfItem> entries) async {
    if (entries.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('移除 ${entries.length} 本无效书籍？'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('移除书架条目，保留独立下载文件。'),
                const SizedBox(height: 12),
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '• ${entry.searchBook.name.trim().isEmpty ? '未命名书籍' : entry.searchBook.name} · ${entry.source.bookSourceName}',
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final shelf = ref.read(onlineShelfProvider.notifier);
    for (final entry in entries) {
      shelf.remove(entry.bookUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(onlineShelfProvider);
    final invalid = items
        .where(
          (item) =>
              _results[item.bookUrl]?.invalid == true ||
              bookIdentityError(
                    name: item.searchBook.name,
                    url: item.candidateBookUrl,
                  ) !=
                  null,
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('书籍检查'),
        actions: [
          IconButton(
            tooltip: _running ? '取消检查' : '检查在线书籍',
            onPressed: _running
                ? () {
                    _cancel();
                    setState(() => _running = false);
                  }
                : _run,
            icon: AppIcon(_running ? AppIcons.close : AppIcons.refresh),
          ),
          IconButton(
            tooltip: '移除确认无效的书籍',
            onPressed: invalid.isEmpty ? null : () => _remove(invalid),
            icon: const AppIcon(AppIcons.delete),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _running
                  ? '正在检查 $_done / ${items.length}，不会因断网删除书籍'
                  : '${items.length} 本在线书籍 · ${invalid.length} 本确认无效。点击刷新检查目录及首章。',
            ),
          ),
          if (_running)
            LinearProgressIndicator(
              value: items.isEmpty ? 0 : _done / items.length,
            ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('暂无在线书籍'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (c, i) {
                      final item = items[i];
                      final result = _results[item.bookUrl];
                      final issue = bookIdentityError(
                        name: item.searchBook.name,
                        url: item.candidateBookUrl,
                      );
                      return ListTile(
                        leading: AppIcon(
                          result?.valid == true
                              ? AppIcons.checkCircle
                              : result?.invalid == true || issue != null
                              ? AppIcons.warning
                              : AppIcons.info,
                        ),
                        title: Text(
                          item.searchBook.name.trim().isEmpty
                              ? '未命名书籍'
                              : item.searchBook.name,
                        ),
                        subtitle: Text(
                          issue ??
                              result?.message ??
                              item.source.bookSourceName,
                        ),
                        trailing: result?.invalid == true || issue != null
                            ? IconButton(
                                tooltip: '移除书架条目',
                                onPressed: () => _remove([item]),
                                icon: const AppIcon(AppIcons.delete),
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
