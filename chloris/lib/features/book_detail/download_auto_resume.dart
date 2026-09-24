import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/download/download_recovery.dart';
import '../sources/source_library_provider.dart';
import 'book_detail_provider.dart';
import 'cache_provider.dart';

/// After sources load, rebind persisted paused/failed cache jobs and resume.
final downloadAutoResumeProvider = FutureProvider<int>((ref) async {
  final sources = await ref.watch(allSourcesProvider.future);
  final jobs = ref.read(cacheJobsProvider.notifier);
  await jobs.restored;
  if (jobs.pendingJobs.isEmpty) return 0;
  return jobs.resumePending(
    resolve: (job) async => resolvePersistedDownloadJob(
      metadata: job.metadata,
      bookName: job.bookName,
      sources: sources,
      content: ref.read(loadOnlineChapterContentUseCaseProvider),
    ),
  );
});
