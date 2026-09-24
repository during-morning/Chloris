import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/persist/kv_settings.dart';
import '../../app/providers.dart';
import '../book_detail/book_detail_provider.dart';
import '../book_detail/book_detail_screen.dart';
import 'source_login_screen.dart';

class SourceDebugScreen extends ConsumerStatefulWidget {
  const SourceDebugScreen({super.key, required this.source});

  final BookSource source;

  @override
  ConsumerState<SourceDebugScreen> createState() => _SourceDebugScreenState();
}

class _SourceDebugScreenState extends ConsumerState<SourceDebugScreen> {
  final _key = TextEditingController(text: '剑来');
  final _logScroll = ScrollController();
  final _log = <String>[];
  bool _busy = false;
  SearchBook? _hit;
  Book? _book;
  List<BookChapter> _toc = const [];

  @override
  void initState() {
    super.initState();
    KvSettings.ready().then((p) {
      final last = p.getString('sourceDebugKey');
      if (last != null && last.isNotEmpty && mounted) {
        _key.text = last;
      } else if (mounted) {
        // 对齐 legado：源配置了 checkKeyWord 时，调试默认用校验关键词探针
        _key.text = widget.source.getCheckKeyword(_key.text);
      }
    });
  }

  @override
  void dispose() {
    _key.dispose();
    _logScroll.dispose();
    super.dispose();
  }

  void _add(String line) {
    setState(() => _log.add(line));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_logScroll.hasClients) return;
      _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
    });
  }

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      _add('错误 ' + e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _search() async {
    await _run(() async {
      final q = _key.text.trim();
      KvSettings.ready().then((p) => p.setString('sourceDebugKey', q));
      _add('搜索 ' + q);
      final list = await ref.read(searchOnlineBooksUseCaseProvider)(
        widget.source,
        q,
      );
      _add('命中 ' + list.length.toString());
      if (list.isNotEmpty) {
        _hit = list.first;
        _add('首条 ' + list.first.name + ' / ' + list.first.author);
      }
    });
  }

  Future<void> _info() async {
    await _run(() async {
      if (_hit == null) {
        _add('先搜索');
        return;
      }
      final book = Book(
        bookUrl: _hit!.bookUrl,
        name: _hit!.name,
        author: _hit!.author,
        origin: widget.source.bookSourceUrl,
        originName: widget.source.bookSourceName,
      );
      _book = await ref.read(loadOnlineBookInfoUseCaseProvider)(
        widget.source,
        book,
      );
      _add('详情 ' + (_book!.name) + ' 目录URL ' + (_book!.tocUrl));
    });
  }

  Future<void> _chapters() async {
    await _run(() async {
      if (_book == null) {
        _add('先取详情');
        return;
      }
      _toc = await ref.read(loadOnlineCatalogUseCaseProvider)(
        source: widget.source,
        seed: _book!,
        cacheKey: _book!.bookUrl,
        maxPages: 40,
        useCache: false,
      );
      _add('目录 ' + _toc.length.toString() + ' 章');
      if (_toc.isNotEmpty) _add('首章 ' + _toc.first.title);
    });
  }

  Future<void> _content() async {
    await _run(() async {
      if (_book == null || _toc.isEmpty) {
        _add('先取目录');
        return;
      }
      final text = await ref.read(loadOnlineChapterContentUseCaseProvider)(
        source: widget.source,
        book: _book!,
        chapter: _toc.first,
        useCache: false,
      );
      _add('正文 ' + text.length.toString() + ' 字');
      _add(text.length > 180 ? text.substring(0, 180) + '…' : text);
    });
  }

  Future<void> _explore() async {
    await _run(() async {
      final kinds = widget.source.exploreKinds;
      if (kinds.isEmpty || (kinds.first.url ?? '').isEmpty) {
        _add('无发现地址');
        return;
      }
      final url = kinds.first.url!;
      _add('发现 ' + kinds.first.title + ' ' + url);
      final list = await ref.read(exploreOnlineBooksUseCaseProvider)(
        widget.source,
        url,
      );
      _add('发现命中 ' + list.length.toString());
      if (list.isNotEmpty) {
        _hit = list.first;
        _add('首条 ' + list.first.name);
      }
    });
  }

  Future<void> _pipeline() async {
    await _search();
    if (_hit != null) await _info();
    if (_book != null) await _chapters();
    if (_toc.isNotEmpty) await _content();
  }

  Future<void> _login() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SourceLoginScreen(source: widget.source),
      ),
    );
    _add('已从登录页返回');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('调试 · ' + widget.source.bookSourceName),
        actions: [
          IconButton(
            tooltip: '复制日志',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _log.join('\n')));
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已复制调试日志')));
              }
            },
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: '清空',
            onPressed: () => setState(() => _log.clear()),
            icon: const Icon(Icons.clear_all),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _key,
              decoration: const InputDecoration(
                labelText: '搜索关键词',
                isDense: true,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: _busy ? null : _search,
                child: const Text('搜索'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _info,
                child: const Text('详情'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _chapters,
                child: const Text('目录'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _content,
                child: const Text('正文'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _explore,
                child: const Text('发现'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _pipeline,
                child: const Text('一条龙'),
              ),
              TextButton(onPressed: _login, child: const Text('登录')),
              TextButton(
                onPressed: _hit == null
                    ? null
                    : () => Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) => BookDetailScreen(
                            source: widget.source,
                            searchBook: _hit!,
                          ),
                        ),
                      ),
                child: const Text('打开详情'),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              controller: _logScroll,
              padding: const EdgeInsets.all(12),
              itemCount: _log.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  _log[i],
                  style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
