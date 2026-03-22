import AppKit
import CoreGraphics

/// Records the frontmost application before the history panel opens, then
/// simulates a ⌘V key event into that app so the selected clipboard item
/// is pasted seamlessly.
///
/// **Accessibility permission** — `CGEvent.postToPid` only works when the
/// daemon has been granted Accessibility access in
/// System Settings → Privacy & Security → Accessibility.
/// `AppDelegate` prompts for this on first launch.
final class PasteManager {

    // MARK: - Private state

    private var targetPID: pid_t?

    // MARK: - Public interface

    /// Call this just *before* showing the history panel so that the
    /// `frontmostApplication` is still the user's target, not our panel.
    func recordFrontmostApp() {
        targetPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
    }

    /// Synthesises a ⌘V key-down + key-up pair directed at the recorded PID.
    ///
    /// A small 50 ms delay lets the panel dismiss and the target app regain
    /// focus before the keystroke arrives.
    func pasteIntoRecordedApp() {
        guard let pid = targetPID else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Self.sendCmdV(to: pid)
        }
    }

    // MARK: - Private helpers

    private static func sendCmdV(to pid: pid_t) {
        let src     = CGEventSource(stateID: .hidSystemState)
        // Virtual key code 0x09 = V
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags   = .maskCommand
        keyDown?.postToPid(pid)
        keyUp?.postToPid(pid)
    }
}
