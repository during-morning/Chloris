import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

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
