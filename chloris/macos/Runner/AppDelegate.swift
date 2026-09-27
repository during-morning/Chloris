import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    // Load the icon generated from AppIcon.appiconset. Falling back to the
    // system's generic application icon here overwrites the bundle icon.
    let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
    if let iconURL, let icon = NSImage(contentsOf: iconURL) {
      NSApp.applicationIconImage = icon
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
