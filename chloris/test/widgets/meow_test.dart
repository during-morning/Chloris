import 'package:chloris/app/widgets/meow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('query fields keep selection so IME and caret work', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MeowQueryField(hint: '筛选')),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enableInteractiveSelection, isTrue);
    expect(field.autocorrect, isFalse);
    expect(field.scrollPhysics, isA<NeverScrollableScrollPhysics>());
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.enableInteractiveSelection, isTrue);
  });

  test('imeComposing is true only during an open composing range', () {
    expect(imeComposing(const TextEditingValue(text: '我的')), isFalse);
    expect(
      imeComposing(
        const TextEditingValue(
          text: 'wo',
          composing: TextRange(start: 0, end: 2),
        ),
      ),
      isTrue,
    );
  });

  testWidgets('pushed MeowPage exposes a return button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      body: MeowPage(
                        eyebrow: '测试',
                        title: '子页面',
                        child: SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('返回'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('打开'), findsOneWidget);
  });

  testWidgets('page actions stay aligned to the top right', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MeowPage(
            eyebrow: '测试',
            title: '操作页',
            actions: [
              IconButton(
                key: const ValueKey('first-action'),
                onPressed: () {},
                icon: const Icon(Icons.more_horiz),
              ),
              IconButton(
                key: const ValueKey('second-action'),
                onPressed: () {},
                icon: const Icon(Icons.settings),
              ),
            ],
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final first = tester.getRect(find.byKey(const ValueKey('first-action')));
    final second = tester.getRect(find.byKey(const ValueKey('second-action')));
    expect(second.right, closeTo(384, 1));
    expect(first.right, lessThanOrEqualTo(second.left));
  });
}
