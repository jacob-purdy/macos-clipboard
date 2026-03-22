import AppKit

/// Locates and launches `ClipboardDaemon.app`.
///
/// Search order (first match wins):
///   1. Embedded inside `ClipboardSettings.app/Contents/Resources/` — useful
///      if you ship a single distributable that bundles both apps.
///   2. `/Applications/ClipboardDaemon.app` — standard install location.
///
/// To embed the daemon, add a Copy Files build phase in Xcode that copies
/// `ClipboardDaemon.app` into the Settings app's Resources folder.
enum DaemonLauncher {

    private static let daemonName = "ClipboardDaemon"

    /// Launch (or re-launch) the daemon. Safe to call even if it's already running.
    static func launch() {
        if let url = embeddedURL() ?? applicationsURL() {
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = false   // don't steal focus
            NSWorkspace.shared.openApplication(at: url, configuration: cfg) { _, error in
                if let error {
                    print("[DaemonLauncher] Failed to launch daemon: \(error)")
                }
            }
        } else {
            print("[DaemonLauncher] Could not locate \(daemonName).app")
        }
    }

    // MARK: - Private

    private static func embeddedURL() -> URL? {
        Bundle.main.url(forResource: daemonName, withExtension: "app")
    }

    private static func applicationsURL() -> URL? {
        let url = URL(fileURLWithPath: "/Applications/\(daemonName).app")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
