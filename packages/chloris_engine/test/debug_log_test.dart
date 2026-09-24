import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  test('DebugLog error buffer caps', () {
    DebugLog.clear();
    for (var i = 0; i < DebugLog.cap + 20; i++) {
      DebugLog.error('t', i.toString());
    }
    expect(DebugLog.buffer.length, DebugLog.cap);
    expect(DebugLog.buffer.last.message, contains((DebugLog.cap + 19).toString()));
    DebugLog.clear();
  });
}
