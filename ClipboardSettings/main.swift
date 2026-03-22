import AppKit

// Entry point for the ClipboardSettings app.
//
// This is a normal .app (no LSUIElement) so it appears in the Dock while open.
// It quits automatically when its settings window is closed
// (see applicationShouldTerminateAfterLastWindowClosed in SettingsAppDelegate).

let app      = NSApplication.shared
let delegate = SettingsAppDelegate()
app.delegate = delegate
app.run()
