import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/persist/kv_settings.dart';

import '../features/explore/explore_screen.dart';
import '../features/book_detail/book_detail_screen.dart';
import '../features/book_detail/toc_page.dart';
import '../features/home/home_shell.dart';
import '../features/library/library_screen.dart';
import '../features/media/music_screen.dart';
import '../features/rss/rss_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/sources/sources_screen.dart';
import 'route_args.dart';

const _homePaths = ['/library', '/search', '/explore', '/music', '/settings'];
const bookDetailRoute = '/book/detail';
const readerRoute = '/reader';
const readerTocRoute = '/reader/toc';

bool _homeRestored = false;

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: appNavigatorKey,
  initialLocation: '/library',
  redirect: (context, state) async {
    if (_homeRestored) return null;
    _homeRestored = true;
    if (state.uri.path != '/library') return null;
    try {
      final p = await KvSettings.ready();
      final saved = p.getString('homeDestination');
      final legacy = (p.getInt('homeBranch') ?? 0).clamp(0, 3);
      final want = saved != null && _homePaths.contains(saved)
          ? saved
          : const ['/library', '/search', '/explore', '/settings'][legacy];
      if (want != state.uri.path) return want;
    } catch (_) {}
    return null;
  },
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return HomeShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              builder: (context, state) => const LibraryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/explore',
              builder: (context, state) => const ExploreScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/sources',
              builder: (context, state) => const SourcesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/rss',
              builder: (context, state) => const RssScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/music',
              builder: (context, state) => const MusicScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: bookDetailRoute,
      builder: (context, state) {
        final args = state.extra;
        if (args is! BookDetailRouteArgs) {
          return const _RoutePayloadError(label: '书籍详情参数缺失');
        }
        return BookDetailScreen(
          source: args.source,
          searchBook: args.searchBook,
        );
      },
    ),
    GoRoute(
      path: readerRoute,
      builder: (context, state) {
        final args = state.extra;
        if (args is! ChapterRouteArgs) {
          return const _RoutePayloadError(label: '阅读器参数缺失');
        }
        return ChapterContentScreen(
          source: args.source,
          book: args.book,
          chapter: args.chapter,
          chapters: args.chapters,
          searchBook: args.searchBook,
        );
      },
    ),
    GoRoute(
      path: readerTocRoute,
      builder: (context, state) {
        final args = state.extra;
        if (args is! TocRouteArgs) {
          return const _RoutePayloadError(label: '目录参数缺失');
        }
        return TocPage(
          book: args.book,
          chapters: args.chapters,
          onOpenChapter: args.onOpenChapter,
        );
      },
    ),
  ],
);

class _RoutePayloadError extends StatelessWidget {
  const _RoutePayloadError({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('无法打开页面')),
      body: Center(child: Text(label)),
    );
  }
}
