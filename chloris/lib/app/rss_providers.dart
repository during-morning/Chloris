import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import '../application/rss/rss_use_cases.dart';

final rssFeedPortProvider = Provider<RssFeedPort>(
  (ref) => EngineRssFeedAdapter(ref.watch(httpPortProvider)),
);

final loadRssArticlesUseCaseProvider = Provider<LoadRssArticlesUseCase>(
  (ref) => LoadRssArticlesUseCase(
    ref.watch(rssFeedPortProvider),
    jsRuntime: ref.watch(engineFacadeProvider).jsRuntime,
  ),
);

final importRssSourcesUseCaseProvider = Provider<ImportRssSourcesUseCase>(
  (ref) => ImportRssSourcesUseCase(ref.watch(rssFeedPortProvider)),
);
