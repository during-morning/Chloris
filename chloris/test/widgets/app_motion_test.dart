import 'package:chloris/app/widgets/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('entrance animation respects reduced motion', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: AppEntrance(child: Text('ready'))),
      ),
    );
    final fades = tester.widgetList<FadeTransition>(
      find.byType(FadeTransition),
    );
    expect(fades.any((fade) => fade.opacity.value == 1), isTrue);
  });

  testWidgets('entrance animation fades and slides content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppEntrance(child: Text('hello'))),
    );
    await tester.pump(const Duration(milliseconds: 90));
    expect(find.text('hello'), findsOneWidget);
    expect(find.byType(FadeTransition), findsWidgets);
    expect(find.byType(SlideTransition), findsWidgets);
  });
}
