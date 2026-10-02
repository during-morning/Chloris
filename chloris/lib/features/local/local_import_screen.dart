import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/follow_route.dart';
import '../../app/illustration/sketch.dart';
import '../../app/widgets/meow.dart';
import 'local_book_provider.dart';
import 'local_book_service.dart';

import '../reader/comic_reader.dart';
import '../reader/reader_screen.dart';
import '../settings/read_record_provider.dart';
import '../library/reading_progress_provider.dart';
import 'pdf_viewer.dart';

class LocalImportScreen extends ConsumerStatefulWidget {
  const LocalImportScreen({super.key});

  @override
  ConsumerState<LocalImportScreen> createState() => _LocalImportScreenState();
}

class _LocalImportScreenState extends ConsumerState<LocalImportScreen> {
  bool _picking = false;
  String? _error;

  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['txt', 'epub', 'pdf', 'mobi', 'azw3', 'umd'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _error = '无法读取文件内容（未以字节加载）');
        return;
      }
      final rules = await ref.read(tocRulesProvider.future);
      final name = file.name.toLowerCase();
      final kind = name.endsWith('.umd')
          ? 'umd'
          : (name.endsWith('.mobi') || name.endsWith('.azw3'))
          ? 'mobi'
          : name.endsWith('.pdf')
          ? 'pdf'
          : name.endsWith('.epub')
          ? 'epub'
          : 'txt';
      final parsed = await compute(parseLocalDocumentWorker, {
        'bytes': bytes,
        'kind': kind,
        'fileName': file.name,
        'tocRules': rules.map((rule) => rule.toJson()).toList(growable: false),
      });
      final book = Book.fromJson(
        Map<String, dynamic>.from(parsed['book']! as Map),
      );
      final chapters = (parsed['chapters']! as List<dynamic>)
          .whereType<Map>()
          .map((entry) {
            final chapter = BookChapter.fromJson(
              Map<String, dynamic>.from(entry),
            );
            chapter.bookUrl = book.bookUrl;
            return chapter;
          })
          .toList(growable: false);
      final contents = Map<String, dynamic>.from(
        parsed['contents']! as Map,
      ).map((key, value) => MapEntry(key, value?.toString() ?? ''));
      final bundle = LocalBookBundle(
        book: book,
        chapters: chapters,
        document: null,
        rawBytes: bytes,
        chapterContent: contents,
        isPdf: parsed['isPdf'] == true,
        isUmd: kind == 'umd',
        htmlDocument: parsed['isHtml'] == true,
        format: switch (kind) {
          'pdf' => LocalDocumentFormat.pdf,
          'epub' => LocalDocumentFormat.epub,
          'mobi' => LocalDocumentFormat.mobi,
          'txt' => LocalDocumentFormat.txt,
          _ => null,
        },
      );
      await ref.read(localShelfProvider.notifier).addAndPersist(bundle);
      setState(() => _error = null);
    } catch (e) {
      setState(() => _error = '导入失败：' + e.toString());
    } finally {
      setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shelf = ref.watch(localShelfProvider);
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.paper,
      body: MeowPage(
        eyebrow: 'Local',
        title: '本地书籍',
        actions: [
          MeowPrimaryButton(
            icon: Icons.upload_file,
            label: _picking ? '解析中…' : '导入 TXT / EPUB / PDF / MOBI / UMD',
            onPressed: _picking ? null : _pick,
          ),
        ],
        child: Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: c.danger, fontSize: 13),
                ),
              ),
            Expanded(
              child: shelf.isEmpty
                  ? MeowEmpty(
                      illustration: SketchArt.bookStack,
                      title: '还没有本地书',
                      body: '选择 TXT、EPUB 或 PDF 文件导入到书架。',
                    )
                  : ListView.builder(
                      itemCount: shelf.length,
                      itemBuilder: (context, i) => ExpansionTile(
                        title: Text(shelf[i].book.name),
                        subtitle: Text(
                          shelf[i].chapters.length.toString() +
                              ' 章 · ' +
                              shelf[i].book.originName,
                        ),
                        initiallyExpanded: false,
                        children: shelf[i].chapters
                            .take(50)
                            .map(
                              (ch) => ListTile(
                                dense: true,
                                title: Text(ch.title),
                                onTap: () =>
                                    openLocalReader(context, shelf[i], ch),
                              ),
                            )
                            .toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class LocalBookChaptersPage extends StatelessWidget {
  const LocalBookChaptersPage({super.key, required this.bundle});

  final LocalBookBundle bundle;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.paper,
      body: MeowPage(
        eyebrow: 'Local',
        title: bundle.book.name,
        subtitle: bundle.chapters.length.toString() + ' 章',
        child: ListView.builder(
          itemCount: bundle.chapters.length,
          itemBuilder: (context, i) {
            final ch = bundle.chapters[i];
            return ListTile(
              dense: true,
              title: Text(ch.title),
              onTap: () => openLocalReader(context, bundle, ch),
            );
          },
        ),
      ),
    );
  }
}

void openLocalReader(
  BuildContext context,
  LocalBookBundle bundle,
  BookChapter chapter,
) {
  final idx = bundle.chapters.indexWhere((c) => c.url == chapter.url);
  final container = ProviderScope.containerOf(context);
  container
      .read(readingProgressProvider.notifier)
      .save(
        bookUrl: bundle.book.bookUrl,
        chapterIndex: idx < 0 ? 0 : idx,
        chapterTitle: chapter.title,
      );
  container
      .read(readRecordProvider.notifier)
      .add(
        bookName: bundle.book.name,
        chapterTitle: chapter.title,
        bookUrl: bundle.book.bookUrl,
      );
  Navigator.of(context, rootNavigator: true).push(
    FollowPageRoute(
      builder: (_) => LocalChapterReader(
        bundle: bundle,
        chapter: chapter,
        index: idx < 0 ? 0 : idx,
      ),
    ),
  );
}

class LocalChapterReader extends ConsumerStatefulWidget {
  const LocalChapterReader({
    super.key,
    required this.bundle,
    required this.chapter,
    this.index = 0,
  });

  final LocalBookBundle bundle;
  final BookChapter chapter;
  final int index;

  @override
  ConsumerState<LocalChapterReader> createState() => _LocalChapterReaderState();
}

class _LocalChapterReaderState extends ConsumerState<LocalChapterReader> {
  late BookChapter chapter = widget.chapter;
  late int index = widget.index;
  String _content = '';
  Uint8List? _pdfBytes;
  Object? _loadError;
  bool _loading = true;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCurrent());
  }

  Future<void> _loadCurrent() async {
    final token = ++_loadToken;
    setState(() {
      _loading = true;
      _loadError = null;
      _content = '';
    });
    try {
      final shelf = ref.read(localShelfProvider.notifier);
      final bytes = widget.bundle.isPdf
          ? await shelf.readOriginal(widget.bundle)
          : null;
      final text = widget.bundle.isPdf
          ? ''
          : await shelf.readChapter(widget.bundle, chapter);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _pdfBytes = bytes;
        _content = text;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  void _open(int j) {
    if (j < 0 || j >= widget.bundle.chapters.length) return;
    final ch = widget.bundle.chapters[j];
    ProviderScope.containerOf(context)
        .read(readingProgressProvider.notifier)
        .save(
          bookUrl: widget.bundle.book.bookUrl,
          chapterIndex: j,
          chapterTitle: ch.title,
        );
    setState(() {
      chapter = ch;
      index = j;
    });
    unawaited(_loadCurrent());
  }

  @override
  Widget build(BuildContext context) {
    final bundle = widget.bundle;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(bundle.book.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(bundle.book.name)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('无法读取本地书籍'),
              const SizedBox(height: 8),
              FilledButton(onPressed: _loadCurrent, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    if (bundle.isPdf && _pdfBytes != null) {
      return Scaffold(
        appBar: AppBar(title: Text(bundle.book.name)),
        body: PdfViewer(bytes: _pdfBytes!, name: bundle.book.name),
      );
    }
    final text = _content;
    if (bundle.isHtml) {
      return ReaderScreen(
        content: text,
        chapterTitle: chapter.title,
        bookTitle: bundle.book.name,
        bookAuthor: bundle.book.author,
        hasNext: index < bundle.chapters.length - 1,
        hasPrev: index > 0,
        onNextChapter: () => _open(index + 1),
        onPrevChapter: () => _open(index - 1),
        chapters: bundle.chapters,
        chapterIndex: index,
        onOpenChapter: _open,
      );
    }
    if (isMangaContent(text)) {
      return ComicReader(
        content: text,
        chapterTitle: chapter.title,
        hasPrev: index > 0,
        hasNext: index < bundle.chapters.length - 1,
        onPrev: () => _open(index - 1),
        onNext: () => _open(index + 1),
      );
    }
    return ReaderScreen(
      content: text,
      chapterTitle: chapter.title,
      bookTitle: bundle.book.name,
      bookAuthor: bundle.book.author,
      hasNext: index < bundle.chapters.length - 1,
      hasPrev: index > 0,
      onNextChapter: () => _open(index + 1),
      onPrevChapter: () => _open(index - 1),
      chapters: bundle.chapters,
      chapterIndex: index,
      onOpenChapter: _open,
    );
  }
}
