import 'package:chloris/core/persist/kv_settings.dart';
import 'package:chloris/engine/prefs_kv_port.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PrefsKvPort persists source variables across instances', () async {
    SharedPreferences.setMockInitialValues({});
    final port = PrefsKvPort(await KvSettings.ready());
    expect(port.isPersistent, isTrue);

    final srcA = BookSource(bookSourceUrl: 'https://a.example')..varStore = port;
    srcA.put('token', 'abc123');

    // A second BookSource instance for the same URL (a later "session")
    // reads the persisted value rather than an empty string.
    final srcB = BookSource(bookSourceUrl: 'https://a.example')..varStore = port;
    expect(srcB.get('token'), 'abc123');

    // Keys are namespaced by source URL: another source sees nothing.
    final other = BookSource(bookSourceUrl: 'https://b.example')..varStore = port;
    expect(other.get('token'), '');
  });

  test('BookSource.defaultVarStore auto-attaches to new instances', () {
    final store = MemoryKvPort();
    final prev = BookSource.defaultVarStore;
    BookSource.defaultVarStore = store;
    try {
      final src = BookSource(bookSourceUrl: 'https://x.example');
      src.put('k', 'v');
      expect(store.read('v_https://x.example_k'), 'v');
    } finally {
      BookSource.defaultVarStore = prev;
    }
  });
}
