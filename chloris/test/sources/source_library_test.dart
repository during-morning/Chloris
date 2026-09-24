import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chloris/app/providers.dart';
import 'package:chloris/features/sources/source_library_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('导入书源可合并到书源库并可移除', () async {
    final container = ProviderContainer(
      overrides: [
        defaultSourcesProvider.overrideWith((ref) async => <BookSource>[]),
      ],
    );
    addTearDown(container.dispose);

    container.read(importedSourcesProvider.notifier).addAll([
      BookSource(bookSourceUrl: 'https://x.com', bookSourceName: 'X'),
    ]);
    final all = await container.read(allSourcesProvider.future);
    expect(all.length, 1);
    expect(all.first.bookSourceName, 'X');

    container.read(importedSourcesProvider.notifier).remove('https://x.com');
    final all2 = await container.read(allSourcesProvider.future);
    expect(all2, isEmpty);
  });
}
