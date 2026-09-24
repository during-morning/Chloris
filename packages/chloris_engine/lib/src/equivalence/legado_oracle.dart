import 'dart:convert';
import 'dart:io';

import 'equivalence_audit.dart';

/// A [EquivalenceOracle] that judges fixtures against the *real* Legado-E rule
/// engine, running out-of-process in the standalone Kotlin judge at
/// `tool/legado_oracle/` (see `tool/legado_oracle/README.md`).
///
/// Each [evaluate] call serialises [EquivalenceFixture.input] (which must
/// contain `kind`, `content` and `rule`) to JSON, pipes it to the judge's
/// stdin, and parses the JSON object the judge prints on stdout. The returned
/// map is compared field-by-field against the Chloris [EquivalenceFixture.run]
/// result by [EquivalenceAudit], producing a genuine bilateral golden.
///
/// When the judge is unavailable (no JDK, or the launcher was not built) use
/// [LegadoProcessOracle.tryCreate] and fall back to [SelfBaselineOracle] so CI
/// degrades gracefully while keeping the audit runnable.
class LegadoProcessOracle implements EquivalenceOracle {
  LegadoProcessOracle({
    required this.executable,
    this.arguments = const <String>[],
    this.workingDirectory,
    this.timeout = const Duration(seconds: 30),
    this.encoding = utf8,
    this.environment,
  });

  /// Path to the judge launcher, e.g.
  /// `tool/legado_oracle/build/install/legado-oracle/bin/legado-oracle`,
  /// or `gradle` when driven via `gradle run`.
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Duration timeout;
  final Encoding encoding;
  final Map<String, String>? environment;

  @override
  String get name => 'legado-process';

  /// Returns a working oracle, or `null` when the judge cannot run in this
  /// environment (no JDK on PATH, or the launcher was never built). Callers
  /// should substitute [SelfBaselineOracle] in the `null` case so the audit
  /// still runs but is clearly marked as not bilateral.
  ///
  /// Set `LEGADO_ORACLE_SKIP=1` to force `null` (e.g. on CI without a JDK).
  static Future<LegadoProcessOracle?> tryCreate({
    String? launcherPath,
    String? projectDir,
  }) async {
    if (Platform.environment['LEGADO_ORACLE_SKIP'] == '1') return null;
    final path =
        launcherPath ?? _defaultLauncher(projectDir ?? _defaultProjectDir);
    if (!await File(path).exists()) return null;
    if (await _which('java') == null) return null;
    return LegadoProcessOracle(executable: path);
  }

  @override
  Future<Map<String, Object?>> evaluate(EquivalenceFixture fixture) async {
    final input = fixture.input;
    final request = jsonEncode(<String, Object?>{
      'kind': input['kind'] ?? input['fallback'] ?? 'regex',
      'content': input['input']?.toString() ?? '',
      'rule': input['rule']?.toString() ?? '',
    });
    // Use Process.start (not run) because this SDK's Process.run does not
    // forward stdin. We write the JSON request to the child's stdin, close it,
    // then collect stdout/stderr as raw bytes.
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
    process.stdin.add(encoding.encode(request));
    await process.stdin.close();

    final outBytes = <int>[];
    final errBytes = <int>[];
    await Future.wait<void>([
      process.stdout.forEach(outBytes.addAll),
      process.stderr.forEach(errBytes.addAll),
    ]);
    final exitCode = await process.exitCode.timeout(timeout);

    if (exitCode != 0) {
      throw StateError(
        'legado-oracle exited $exitCode: ${encoding.decode(errBytes)}',
      );
    }
    final stdoutText = encoding.decode(outBytes).trim();
    if (stdoutText.isEmpty) {
      throw StateError('legado-oracle produced no stdout');
    }
    final parsed = jsonDecode(stdoutText);
    if (parsed is! Map) {
      throw StateError('legado-oracle returned a non-object: $stdoutText');
    }
    return Map<String, Object?>.from(parsed);
  }

  static const String _defaultProjectDir = 'tool/legado_oracle';

  static String _defaultLauncher(String projectDir) =>
      '$projectDir/build/install/legado-oracle/bin/legado-oracle';

  static Future<String?> _which(String command) async {
    final which = Platform.isWindows ? 'where' : 'which';
    try {
      final result = await Process.run(
        which,
        [command],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (result.exitCode == 0) return (result.stdout as String).trim();
    } on Object {
      // Ignore — caller treats absence as "unavailable".
    }
    return null;
  }
}
