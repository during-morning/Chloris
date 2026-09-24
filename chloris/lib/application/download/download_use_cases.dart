/// 一个可持久化的章节引用。
///
/// 章节正文抓取闭包不能跨进程保存，因此恢复时至少要保留章节序号、
/// 标题和 URL，让上层可以根据书源重新组装抓取器。
class BatchDownloadChapterRef {
  const BatchDownloadChapterRef({
    required this.index,
    this.title = '',
    this.url = '',
    this.baseUrl = '',
  });

  factory BatchDownloadChapterRef.fromJson(Map<String, dynamic> json) {
    return BatchDownloadChapterRef(
      index: (json['index'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      baseUrl: json['baseUrl']?.toString() ?? '',
    );
  }

  final int index;
  final String title;
  final String url;
  final String baseUrl;

  Map<String, dynamic> toJson() => {
    'index': index,
    'title': title,
    'url': url,
    'baseUrl': baseUrl,
  };
}

/// 下载任务重启恢复所需的稳定元数据。
class BatchDownloadMetadata {
  const BatchDownloadMetadata({
    this.sourceId = '',
    this.bookUrl = '',
    this.tocUrl = '',
    this.chapters = const [],
  });

  factory BatchDownloadMetadata.fromJson(Map<String, dynamic> json) {
    final rawChapters = json['chapters'];
    return BatchDownloadMetadata(
      sourceId: json['sourceId']?.toString() ?? '',
      bookUrl: json['bookUrl']?.toString() ?? '',
      tocUrl: json['tocUrl']?.toString() ?? '',
      chapters: rawChapters is List
          ? [
              for (final item in rawChapters)
                if (item is Map)
                  BatchDownloadChapterRef.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
            ]
          : const [],
    );
  }

  final String sourceId;
  final String bookUrl;
  final String tocUrl;
  final List<BatchDownloadChapterRef> chapters;

  bool get canResolve =>
      sourceId.trim().isNotEmpty ||
      bookUrl.trim().isNotEmpty ||
      chapters.any((chapter) => chapter.url.trim().isNotEmpty);

  Map<String, dynamic> toJson() => {
    'sourceId': sourceId,
    'bookUrl': bookUrl,
    'tocUrl': tocUrl,
    'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
  };
}

/// 批量下载的应用边界。页面只提交任务意图，具体队列由适配器实现。
abstract interface class BatchDownloadPort {
  Future<void> enqueueOrResume({
    required String bookName,
    required int fromIndex,
    required int total,
    required Future<void> Function(int index) fetchChapter,
    String Function(int index)? hostOf,
  });
}

/// Optional extension implemented by queue adapters that persist recovery
/// metadata. Keeping it separate preserves source compatibility for lightweight
/// adapters that only need the original intent API.
abstract interface class MetadataBatchDownloadPort
    implements BatchDownloadPort {
  Future<void> enqueueOrResumeWithMetadata({
    required String bookName,
    required int fromIndex,
    required int total,
    required Future<void> Function(int index) fetchChapter,
    String Function(int index)? hostOf,
    BatchDownloadMetadata? metadata,
  });
}

/// Rebound callbacks for a persisted download after its source is loaded.
class DownloadResumeHandler {
  const DownloadResumeHandler({required this.fetchChapter, this.hostOf});

  final Future<void> Function(int index) fetchChapter;
  final String Function(int index)? hostOf;
}

class BatchDownloadUseCase {
  const BatchDownloadUseCase(this._port);

  final BatchDownloadPort _port;

  Future<void> call({
    required String bookName,
    required int fromIndex,
    required int total,
    required Future<void> Function(int index) fetchChapter,
    String Function(int index)? hostOf,
    BatchDownloadMetadata? metadata,
  }) {
    final metadataPort = _port;
    if (metadataPort is MetadataBatchDownloadPort) {
      return metadataPort.enqueueOrResumeWithMetadata(
        bookName: bookName,
        fromIndex: fromIndex,
        total: total,
        fetchChapter: fetchChapter,
        hostOf: hostOf,
        metadata: metadata,
      );
    }
    return _port.enqueueOrResume(
      bookName: bookName,
      fromIndex: fromIndex,
      total: total,
      fetchChapter: fetchChapter,
      hostOf: hostOf,
    );
  }
}
