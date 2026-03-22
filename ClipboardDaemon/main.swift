import AppKit

// Entry point for the ClipboardDaemon background agent.
//
// LSUIElement = YES in Info.plist suppresses the Dock icon and menu-bar entry
// so the process runs invisibly in the background.
//
// We wire up AppDelegate manually rather than using @NSApplicationMain so
// that the entry point is explicit and easy to trace.

let app      = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
