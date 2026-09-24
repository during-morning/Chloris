import '../models/domain_protocol.dart';

/// Platform interactions and app settings that rule scripts can reach through
/// the `java` object.
///
/// Legado exposes these on the Android host: `java.openUrl`, `java.startBrowser`,
/// `java.getVerificationCode`, `java.getReadBookConfig`, `java.getThemeMode`
/// and friends. Only a host with a UI can implement them, so the engine asks
/// through this port and treats "not available" as a real answer.
///
/// Methods that *return data* throw when unsupported; methods that are
/// fire-and-forget return false. A rule that consumes `startBrowserAwait` and
/// receives an empty string would otherwise cache a blank page as content.
abstract interface class HostEnvironment {
  /// User agent the host presents to sites.
  String userAgent();

  /// Opens a URL in the system browser. Fire-and-forget.
  Future<bool> openUrl(String url, {String? mimeType});

  /// Opens the video player. Fire-and-forget.
  Future<bool> openVideo(String url, String title, {bool float = false});

  /// Opens an interactive browser page and returns the fetched body.
  Future<String> startBrowser(
    String url, {
    String title = '',
    bool refetchAfterSuccess = false,
  });

  /// Asks the user for the verification code shown at [imageUrl].
  Future<String> verificationCode(String imageUrl);

  /// Reading configuration as rule scripts see it.
  Map<String, Object?> readBookConfig();

  /// Theme configuration as rule scripts see it.
  Map<String, Object?> themeConfig();

  /// 0 = follow system, 1 = light, 2 = dark.
  int themeMode();
}

/// The port used when no host UI is attached.
///
/// Data-returning calls throw so a rule cannot mistake "no answer" for an
/// empty answer; fire-and-forget calls report false.
class DefaultHostEnvironment implements HostEnvironment {
  const DefaultHostEnvironment({this.userAgentValue = defaultUserAgent});

  static const defaultUserAgent =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  final String userAgentValue;

  static DomainError _error(String what) => DomainError(
    code: 'host_env_unsupported',
    stage: DomainErrorStage.render,
    message: '$what 需要宿主界面支持',
    recoverable: false,
    retryable: false,
    suggestedAction: '该规则依赖应用内的交互页面；请在桌面或移动端使用',
  );

  @override
  String userAgent() => userAgentValue;

  @override
  Future<bool> openUrl(String url, {String? mimeType}) async => false;

  @override
  Future<bool> openVideo(String url, String title, {bool float = false}) async =>
      false;

  @override
  Future<String> startBrowser(
    String url, {
    String title = '',
    bool refetchAfterSuccess = false,
  }) async => throw _error('打开内置浏览器');

  @override
  Future<String> verificationCode(String imageUrl) async =>
      throw _error('输入验证码');

  @override
  Map<String, Object?> readBookConfig() => const {};

  @override
  Map<String, Object?> themeConfig() => const {};

  @override
  int themeMode() => 0;
}
