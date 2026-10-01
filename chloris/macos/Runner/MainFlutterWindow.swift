import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    ChlorisBrowserBridge.shared.register(flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()

    // Keep the native traffic-light controls while letting Flutter paint into
    // the title-bar area. The title text and bar background disappear, but the
    // standard macOS close/minimize/zoom buttons remain available.
    self.title = ""
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = true

    for button in [
      NSWindow.ButtonType.closeButton,
      NSWindow.ButtonType.miniaturizeButton,
      NSWindow.ButtonType.zoomButton,
    ] {
      self.standardWindowButton(button)?.isHidden = false
    }
  }
}

import WebKit

private final class ChlorisBrowserBridge {
  static let shared = ChlorisBrowserBridge()
  private var sessions: [String: ChlorisBrowserSession] = [:]
  private var channel: FlutterMethodChannel?
  func register(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "chloris/browser", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self, let args = call.arguments as? [String: Any], let id = args["id"] as? String else {
        result(FlutterError(code: "browser_arguments", message: "解析参数无效", details: nil)); return
      }
      if call.method == "close" { self.sessions.removeValue(forKey: id)?.finish(nil); result(nil); return }
      guard call.method == "run" else { result(FlutterMethodNotImplemented); return }
      guard self.sessions.count < 2 else { result(FlutterError(code: "browser_busy", message: "动态解析队列已满", details: nil)); return }
      let session = ChlorisBrowserSession(args: args) { [weak self] value in self?.sessions.removeValue(forKey: id); result(value) }
      self.sessions[id] = session
      session.start()
    }
  }
}
private final class ChlorisBrowserSession: NSObject, WKNavigationDelegate {
  let args: [String: Any]
  let completion: (Any?) -> Void
  let view: WKWebView
  private var poll: Timer?
  private var timeout: Timer?
  private var completed = false
  init(args: [String: Any], completion: @escaping (Any?) -> Void) {
    self.args = args; self.completion = completion
    let config = WKWebViewConfiguration()
    config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
    config.userContentController.addUserScript(WKUserScript(source: args["capture"] as? String ?? "", injectionTime: .atDocumentStart, forMainFrameOnly: false))
    self.view = WKWebView(frame: .zero, configuration: config)
    super.init(); view.navigationDelegate = self
  }
  func start() {
    guard let url = URL(string: args["url"] as? String ?? "") else { finish(nil); return }
    timeout = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in self?.finish(FlutterError(code: "browser_timeout", message: "网页解析超时", details: nil)) }
    let headers = args["headers"] as? [String: String] ?? [:]
    view.customUserAgent = headers.first(where: { $0.key.lowercased() == "user-agent" })?.value
    let cookie = headers.first(where: { $0.key.lowercased() == "cookie" })?.value ?? ""
    let group = DispatchGroup()
    for raw in cookie.split(separator: ";") {
      let pair = raw.trimmingCharacters(in: .whitespaces).split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
      guard pair.count == 2, let host = url.host else { continue }
      if let item = HTTPCookie(properties: [.name: String(pair[0]), .value: String(pair[1]), .domain: host, .path: "/", .secure: url.scheme == "https" ? "TRUE" : "FALSE"]) {
        group.enter(); view.configuration.websiteDataStore.httpCookieStore.setCookie(item) { group.leave() }
      }
    }
    group.notify(queue: .main) { [weak self] in
      guard let self = self, !self.completed else { return }
      if let html = self.args["html"] as? String, !html.isEmpty { self.view.loadHTMLString(html, baseURL: url) }
      else { var request = URLRequest(url: url); request.allHTTPHeaderFields = headers; self.view.load(request) }
    }
  }
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    poll?.invalidate()
    poll = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
      guard let self = self, !self.completed else { return }
      self.view.evaluateJavaScript(self.args["script"] as? String ?? "null") { [weak self] value, error in
        guard let self = self, !self.completed else { return }
        if let body = value as? String, !body.isEmpty {
          self.view.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self, !self.completed else { return }
            if let data = body.data(using: .utf8), var result = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
              let host = self.view.url?.host ?? ""
              result["cookie"] = cookies.filter { host == $0.domain || host.hasSuffix($0.domain.hasPrefix(".") ? $0.domain : "." + $0.domain) }.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
              if let encoded = try? JSONSerialization.data(withJSONObject: result), let text = String(data: encoded, encoding: .utf8) { self.finish(text); return }
            }
            self.finish(body)
          }
        }
      }
    }
  }
  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { finish(FlutterError(code: "browser_crashed", message: "网页解析进程退出", details: nil)) }
  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(FlutterError(code: "browser_network", message: error.localizedDescription, details: nil)) }
  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(FlutterError(code: "browser_network", message: error.localizedDescription, details: nil)) }
  func finish(_ value: Any?) {
    guard !completed else { return }; completed = true
    poll?.invalidate(); timeout?.invalidate(); view.stopLoading(); view.navigationDelegate = nil
    completion(value)
  }
}
