import Cocoa

/// Entry point for the Settings application.
///
/// Opens the settings window immediately on launch and terminates when the
/// window is closed.  The user can re-open it any time from the Applications
/// folder (or by pinning it to the Dock).
final class SettingsAppDelegate: NSObject, NSApplicationDelegate {

    private var windowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = SharedDefaults.appearanceMode.nsAppearance
        windowController = SettingsWindowController()
        windowController?.showWindow(nil)
        // Bring the app to the front so the settings window is immediately visible.
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    /// Quit when the settings window is closed so we don't linger in the Dock.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
