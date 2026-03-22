import Cocoa
import ServiceManagement

/// Root coordinator for the clipboard daemon.
///
/// Responsibilities:
///  - Prompt for Accessibility permission on first launch (required for the
///    simulated ⌘V paste).
///  - Instantiate `ClipboardMonitor`, `HotkeyManager`, `PasteManager`, and
///    `HistoryPanel`, then wire them together.
///  - Listen for Darwin notifications posted by the Settings app so config
///    changes are picked up without a full restart.
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Components

    private var clipboardMonitor: ClipboardMonitor!
    private var hotkeyManager: HotkeyManager!
    private var historyPanel: HistoryPanel!
    private var pasteManager: PasteManager!

    private var notificationObservers: [NSObjectProtocol] = []

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityPermissionIfNeeded()
        buildComponents()
        registerDarwinObservers()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        // Persist history to disk if the user has enabled that setting.
        if SharedDefaults.persistHistory {
            SharedDefaults.savedHistory = clipboardMonitor.history
        }
        hotkeyManager.unregister()
        clipboardMonitor.stop()
    }

    // MARK: - Setup

    private func requestAccessibilityPermissionIfNeeded() {
        // Passing `kAXTrustedCheckOptionPrompt = true` shows the system prompt
        // on the first launch.  Subsequent launches succeed silently once
        // the user has granted permission in System Settings → Privacy.
        let key     = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func buildComponents() {
        pasteManager     = PasteManager()
        clipboardMonitor = ClipboardMonitor()
        historyPanel     = HistoryPanel()
        hotkeyManager    = HotkeyManager { [weak self] in
            self?.presentHistoryPanel()
        }

        // Restore persisted history when the setting is enabled.
        if SharedDefaults.persistHistory {
            clipboardMonitor.loadHistory(SharedDefaults.savedHistory)
        }

        clipboardMonitor.start()
        hotkeyManager.register()
        applyLaunchAtLogin()
    }

    // MARK: - Panel presentation

    private func presentHistoryPanel() {
        guard !clipboardMonitor.history.isEmpty else { return }
        // Snapshot the frontmost app *before* the panel steals focus.
        pasteManager.recordFrontmostApp()
        historyPanel.present(items: clipboardMonitor.history) { [weak self] item in
            self?.handleSelection(item)
        }
    }

    private func handleSelection(_ item: ClipboardItem) {
        // 1. Write the selected item back onto the system pasteboard.
        ClipboardMonitor.writeToPasteboard(item)
        // 2. Optionally simulate ⌘V into the app that was focused before.
        if SharedDefaults.pasteImmediately {
            pasteManager.pasteIntoRecordedApp()
        }
        // 3. Move the item to the front of history (most-recent-first order).
        clipboardMonitor.bringToFront(item)
    }

    // MARK: - Darwin notification listeners

    private func registerDarwinObservers() {
        observe(DarwinNotification.configChanged) { [weak self] in
            self?.hotkeyManager.reregister()
            self?.clipboardMonitor.reloadConfig()
            self?.applyLaunchAtLogin()
        }
        observe(DarwinNotification.quitDaemon) { [weak self] in
            self?.gracefulQuit()
        }
        observe(DarwinNotification.restartDaemon) { [weak self] in
            // The Settings app will relaunch us; we just need to quit cleanly.
            self?.gracefulQuit()
        }
    }

    private func applyLaunchAtLogin() {
        do {
            if SharedDefaults.launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[AppDelegate] SMAppService: \(error)")
        }
    }

    private func gracefulQuit() {
        applicationWillTerminate(
            Notification(name: NSApplication.willTerminateNotification)
        )
        NSApplication.shared.terminate(nil)
    }

    private func observe(_ name: String, handler: @escaping () -> Void) {
        let token = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(name),
            object: nil,
            queue: .main
        ) { _ in handler() }
        notificationObservers.append(token)
    }
}
