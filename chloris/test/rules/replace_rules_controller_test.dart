import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chloris_engine/chloris_engine.dart';

import 'package:chloris/features/rules/replace_rules_controller.dart';
import 'package:chloris/features/rules/rules_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('净化规则库可加载/新增/编辑', () async {
    final container = ProviderContainer(
      overrides: [
        defaultReplaceRulesProvider.overrideWith((ref) async => [
          ReplaceRule(name: 'A', pattern: 'a', replacement: 'b'),
        ]),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(replaceRulesProvider.notifier);
    await notifier.load();
    expect(notifier.state.length, 1);

    notifier.add(ReplaceRule(name: 'B', pattern: 'c', replacement: 'd'));
    expect(notifier.state.length, 2);

    notifier.update(0, ReplaceRule(name: 'A2', pattern: 'x', replacement: 'y'));
    expect(notifier.state[0].name, 'A2');
  });
}
