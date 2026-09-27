import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chloris/app/widgets/meow.dart';
import 'package:chloris/features/explore/explore_screen.dart';
import 'package:chloris/features/sources/source_library_provider.dart';

void main() {
  testWidgets('探索主标签页使用全宽正文和页头', (tester) async {
    tester.view.physicalSize = const Size(3000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          enabledExploreSourcesProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: ExploreScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final page = tester.widget<MeowPage>(find.byType(MeowPage));
    expect(page.fullBleedBody, isTrue);
    expect(tester.takeException(), isNull);
  });
}
