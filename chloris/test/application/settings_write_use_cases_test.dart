import 'package:flutter_test/flutter_test.dart';

import 'package:chloris/application/settings/settings_use_cases.dart';

class _FakeSettingsWritePort implements SettingsWritePort {
  final bools = <String, bool>{};
  final doubles = <String, double>{};
  final ints = <String, int>{};
  final strings = <String, String>{};

  @override
  Future<void> setBool(String key, bool value) async => bools[key] = value;

  @override
  Future<void> setDouble(String key, double value) async =>
      doubles[key] = value;

  @override
  Future<void> setInt(String key, int value) async => ints[key] = value;

  @override
  Future<void> setString(String key, String value) async =>
      strings[key] = value;
}

void main() {
  test('设置写入用例保留类型并委托到持久化端口', () async {
    final port = _FakeSettingsWritePort();
    final useCase = SettingsWriteUseCase(port);

    await useCase.setBool('debugVerbose', true);
    await useCase.setDouble('uiTextScale', 1.15);
    await useCase.setInt('searchPool', 32);
    await useCase.setString('userAgent', 'Chloris');

    expect(port.bools, {'debugVerbose': true});
    expect(port.doubles, {'uiTextScale': 1.15});
    expect(port.ints, {'searchPool': 32});
    expect(port.strings, {'userAgent': 'Chloris'});
  });

  test('网络设置重置通过同一用例写入完整默认值', () async {
    final port = _FakeSettingsWritePort();

    await SettingsWriteUseCase(port).resetNetworkDefaults();

    expect(port.ints, {
      'httpTimeoutSec': 30,
      'searchTimeoutSec': 30,
      'tocTimeoutSec': 30,
      'contentTimeoutSec': 30,
      'searchPool': 32,
      'downloadPool': 8,
    });
    expect(port.bools, {'debugVerbose': true});
    expect(port.strings, {'userAgent': ''});
  });
}
