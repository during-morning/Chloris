/// Process-wide knobs. The app writes these from settings; the engine reads.
abstract final class EngineLimits {
  static Duration httpTimeout = const Duration(seconds: 15);
  static Duration searchTimeout = const Duration(seconds: 12);
  static Duration tocTimeout = const Duration(seconds: 18);
  static Duration contentTimeout = const Duration(seconds: 20);

  /// JS 求值软截止期限（默认 15s，可配）。
  ///
  /// 引擎不持有 JS 虚拟机，无法在 VM 侧强制中断同步 `eval`；此期限用于
  /// [JsHostBridge.evalWithDeadline] 的 [Future.timeout] 边界保护，保证调用方
  /// 不被挂死。支持的运行时可借 deadline 提示提前中断自身 VM。
  static Duration jsEvalTimeout = const Duration(seconds: 15);

  /// legado `AppConfig.threadCount` default is 32. 0 host cap = unlimited.
  static int searchPool = 32;
  static int searchHostCap = 2;
  // Retained for settings/backward compatibility; full scans no longer use
  // hit-count or score based early stopping.
  static int searchEarlyStopHits = 8;
  static int searchEarlyStopScore = 650;
  static int downloadPool = 8;
  static int downloadHostCap = 3;
  static bool debugVerbose = false;
  static String? userAgent;

  static void apply({
    int? httpTimeoutSec,
    int? searchTimeoutSec,
    int? tocTimeoutSec,
    int? contentTimeoutSec,
    int? jsEvalTimeoutSec,
    int? searchPool,
    int? searchHostCap,
    int? searchEarlyStopHits,
    int? searchEarlyStopScore,
    int? downloadPool,
    int? downloadHostCap,
    bool? debugVerbose,
    String? userAgent,
  }) {
    if (httpTimeoutSec != null) {
      httpTimeout = Duration(seconds: httpTimeoutSec.clamp(6, 60));
    }
    if (searchTimeoutSec != null) {
      searchTimeout = Duration(seconds: searchTimeoutSec.clamp(6, 60));
    }
    if (tocTimeoutSec != null) {
      tocTimeout = Duration(seconds: tocTimeoutSec.clamp(6, 60));
    }
    if (contentTimeoutSec != null) {
      contentTimeout = Duration(seconds: contentTimeoutSec.clamp(6, 60));
    }
    if (jsEvalTimeoutSec != null) {
      jsEvalTimeout = Duration(seconds: jsEvalTimeoutSec.clamp(1, 120));
    }
    if (searchPool != null) {
      EngineLimits.searchPool = searchPool.clamp(4, 128).toInt();
    }
    if (searchHostCap != null) {
      EngineLimits.searchHostCap = searchHostCap.clamp(0, 128).toInt();
    }
    if (searchEarlyStopHits != null) {
      EngineLimits.searchEarlyStopHits = searchEarlyStopHits.clamp(0, 24);
    }
    if (searchEarlyStopScore != null) {
      EngineLimits.searchEarlyStopScore = searchEarlyStopScore.clamp(300, 1000);
    }
    if (downloadPool != null) {
      EngineLimits.downloadPool = downloadPool.clamp(2, 128).toInt();
    }
    if (downloadHostCap != null) {
      EngineLimits.downloadHostCap = downloadHostCap.clamp(1, 128).toInt();
    }
    if (debugVerbose != null) {
      EngineLimits.debugVerbose = debugVerbose;
    }
    if (userAgent != null) {
      EngineLimits.userAgent = userAgent.trim().isEmpty
          ? null
          : userAgent.trim();
    }
  }
}
