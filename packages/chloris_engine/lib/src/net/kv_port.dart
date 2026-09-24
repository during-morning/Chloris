import '../models/domain_protocol.dart';

/// Persistent key/value store for rule variables.
///
/// 对齐 Legado-E：书源规则通过 `java.put` / `java.get` 写的**源级变量**落在
/// `CacheManager` 里，键形如 `v_<bookSourceUrl>_<key>`，没有 TTL，**重启后仍在**
/// （`data/entities/BaseSource.kt:275-286`）。
///
/// `chloris_engine` 不持有存储（要能编到 Web / 单测 / CLI），所以这里只定义端口，
/// 真机实现由 App 注入 —— SQLite、文件、浏览器 `localStorage` 都可以，只要满足
/// 「同键覆盖、删除即失效、跨进程可见」。
abstract interface class KvPort {
  /// 当前实现是否真的能跨重启。
  ///
  /// 为 `false` 时调用方要明确知道：变量只在本次运行内有效。这个标志存在的原因
  /// 是「没有持久层」不应该是静默的 —— 书源作者用 `java.put` 存登录态时，
  /// 如果只是悄悄退化成进程内 map，问题会表现为「偶尔要重新登录」这种难查的形态。
  bool get isPersistent;

  String? read(String key);

  void write(String key, String value);

  void delete(String key);
}

/// 进程内实现：接口与持久化版完全一致，但不跨重启。
///
/// 用于单测与 CLI 工具（例如真机书源闭环），也用于「本次运行内先跑通」的降级场景。
class MemoryKvPort implements KvPort {
  final Map<String, String> _store = {};

  @override
  bool get isPersistent => false;

  @override
  String? read(String key) => _store[key];

  @override
  void write(String key, String value) {
    _store[key] = value;
  }

  @override
  void delete(String key) {
    _store.remove(key);
  }

  int get length => _store.length;
}

/// 完全不可用时的实现：与 [UnsupportedFilePort] 同一条约定 —— 每个操作都抛
/// [DomainError] 并点明缺的是哪项能力，而不是回一个「看起来正常」的空值。
///
/// 注意：源级变量**没有**使用这个实现。`java.get` 读不到变量时返回 `''` 是
/// Legado 的既定行为（`CacheManager.get(...) ?: ""`），照抄即可；这里只是给
/// 需要「变量必须持久」的调用方一个显式选择。
class UnsupportedKvPort implements KvPort {
  const UnsupportedKvPort();

  @override
  bool get isPersistent => false;

  static DomainError _error(String what) => DomainError(
    code: 'kv_port_unsupported',
    stage: DomainErrorStage.request,
    message: '$what 在当前平台不可用',
    recoverable: false,
    retryable: false,
    suggestedAction: '该能力需要宿主提供持久化存储；请注入一个 KvPort 实现',
  );

  @override
  String? read(String key) => throw _error('读取规则变量');

  @override
  void write(String key, String value) => throw _error('写入规则变量');

  @override
  void delete(String key) => throw _error('删除规则变量');
}
