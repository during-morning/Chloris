import 'dart:io';

import 'package:chloris/services/web/app_server_backend.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Drift resolves its file through path_provider, which has no implementation
/// under `flutter test`. Replacing the platform instance is the supported seam;
/// the exception from a missing handler escapes as an unhandled async error
/// that `AppDb.open`'s try/catch cannot contain.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getTemporaryPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationCachePath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late AppServerBackend backend;

  setUp(() {
    // The shelf and progress notifiers read settings on build, and the shelf
    // notifier hydrates from drift.
    SharedPreferences.setMockInitialValues({});
    PathProviderPlatform.instance = _FakePathProvider(
      Directory.systemTemp.createTempSync('chloris_backend_test').path,
    );
    container = ProviderContainer();
    backend = container.read(appServerBackendProvider);
  });

  tearDown(() => container.dispose());

  group('backend reports missing state instead of empty success', () {
    test('an unknown book is an explicit error, not an empty catalogue',
        () async {
      // Returning [] here would make a client render "this book has no
      // chapters" instead of "this book is not on the shelf".
      await expectLater(
        backend.chapterList('https://missing.test/1'),
        throwsA(
          isA<DomainError>().having(
            (e) => e.code,
            'code',
            'book_not_on_shelf',
          ),
        ),
      );
    });

    test('an unknown chapter is an explicit error', () async {
      await expectLater(
        backend.bookContent('https://missing.test/1', 3),
        throwsA(isA<DomainError>()),
      );
    });

    test('saving a book without a source fails with a usable message',
        () async {
      await expectLater(
        backend.saveBook({'bookUrl': 'https://b.test/1', 'name': 'n'}),
        throwsA(
          isA<DomainError>().having(
            (e) => e.code,
            'code',
            'source_not_found',
          ),
        ),
      );
    });

    test('saving a book without a bookUrl is rejected', () async {
      await expectLater(
        backend.saveBook({'name': 'n'}),
        throwsA(
          isA<DomainError>().having((e) => e.code, 'code', 'book_url_missing'),
        ),
      );
    });
  });

  group('an empty shelf serialises to an empty list', () {
    test('bookshelf is empty before anything is added', () async {
      expect(await backend.bookshelf(), isEmpty);
    });

    test('deleting an unknown book is a no-op', () async {
      await backend.deleteBook('https://missing.test/1');
      expect(await backend.bookshelf(), isEmpty);
    });

    test('progress without a bookUrl is ignored', () async {
      await backend.saveProgress({'chapterIndex': 3});
      // No throw: a malformed progress ping must not break a client's sync.
      expect(await backend.bookshelf(), isEmpty);
    });
  });
}
