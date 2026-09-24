import 'package:chloris/features/settings/legal_texts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disclaimer is at least 2000 Chinese characters', () {
    expect(LegalTexts.disclaimerLength, greaterThanOrEqualTo(2000));
    expect(LegalTexts.aboutIntro, contains('跨平台'));
    expect(LegalTexts.aboutIntro.length, greaterThan(200));
  });
}
