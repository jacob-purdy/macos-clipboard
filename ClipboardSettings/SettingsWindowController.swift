import AppKit

/// Hosts the tabbed settings interface in a standard macOS window.
///
/// Tabs (toolbar style, matching System Settings conventions):
///   General   — hotkey, panel position, history limit, paste & persistence toggles,
///               daemon management buttons
///   Capture   — checkboxes for which content types to capture
///   Exclusions — per-app exclusion list with a file-browser add button
final class SettingsWindowController: NSWindowController {

    // MARK: - Init

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title       = "Clipboard Settings"
        window.isRestorable = false
        window.center()
        self.init(window: window)
        buildTabs()
    }

    // MARK: - Tab setup

    private func buildTabs() {
        let tabVC = NSTabViewController()
        tabVC.tabStyle = .toolbar

        let tabs: [(label: String, symbol: String, vc: NSViewController)] = [
            ("General",    "gearshape",         GeneralSettingsViewController()),
            ("Capture",    "doc.on.clipboard",  CaptureSettingsViewController()),
            ("Exclusions", "xmark.app",         ExclusionsSettingsViewController()),
        ]

        for tab in tabs {
            let item = NSTabViewItem(viewController: tab.vc)
            item.label = tab.label
            item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: nil)
            tabVC.addTabViewItem(item)
        }

        window?.contentViewController = tabVC
    }
}
