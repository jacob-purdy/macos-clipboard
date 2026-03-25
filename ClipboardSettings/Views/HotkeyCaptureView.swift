import AppKit
import Carbon   // cmdKey, shiftKey, optionKey, controlKey

/// A clickable field that records a keyboard shortcut.
///
/// - Click the view to enter recording mode.
/// - Hold modifier keys to preview the combo; press the final key to save.
/// - Press Escape to cancel without saving.
/// - At least one modifier key is required.
final class HotkeyCaptureView: NSView {

    // MARK: - Callback

    /// Called with (keyCode, carbonModifiers) when a new shortcut is recorded.
    var onCapture: ((UInt32, UInt32) -> Void)?

    // MARK: - State

    private var isRecording = false

    // MARK: - Subviews

    private let label: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.alignment             = .center
        f.font                  = .monospacedSystemFont(ofSize: 13, weight: .regular)
        f.isSelectable          = false
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }()

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.borderWidth  = 1
        setNormalAppearance()

        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
            widthAnchor.constraint(equalToConstant: 130),
            heightAnchor.constraint(equalToConstant: 26),
        ])
        refreshLabel()
    }

    required init?(coder: NSCoder) { fatalError("Use init()") }

    // MARK: - First responder

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
        label.stringValue = "Type shortcut…"
        setRecordingAppearance()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }

        if event.keyCode == 53 {    // Escape — cancel without saving
            stopRecording()
            return
        }

        // Require at least one modifier so plain letter keys aren't captured.
        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard !mods.isEmpty else { return }

        let keyCode    = UInt32(event.keyCode)
        let carbonMods = nsModsToCarbonMods(mods)

        SharedDefaults.hotkeyKeyCode    = keyCode
        SharedDefaults.hotkeyModifiers  = carbonMods
        onCapture?(keyCode, carbonMods)
        stopRecording()
    }

    /// Show a live preview of held modifiers while the user is recording.
    override func flagsChanged(with event: NSEvent) {
        guard isRecording else { return }
        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        label.stringValue = mods.isEmpty ? "Type shortcut…" : modsToSymbols(mods)
    }

    // MARK: - Public helpers

    /// Refresh the label from the current `SharedDefaults` values.
    func refreshLabel() {
        label.stringValue = HotkeyCaptureView.displayString(
            keyCode:    SharedDefaults.hotkeyKeyCode,
            carbonMods: SharedDefaults.hotkeyModifiers
        )
    }

    // MARK: - Private helpers

    private func stopRecording() {
        isRecording = false
        refreshLabel()
        setNormalAppearance()
        window?.makeFirstResponder(nil)
    }

    private func setNormalAppearance() {
        withEffectiveAppearance {
            layer?.borderColor     = NSColor.separatorColor.cgColor
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        }
        label.textColor = .labelColor
    }

    private func setRecordingAppearance() {
        withEffectiveAppearance {
            layer?.borderColor     = NSColor.controlAccentColor.cgColor
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
        }
        label.textColor = .controlAccentColor
    }

    /// Temporarily makes the view's effective appearance current so CGColor
    /// values resolve correctly for the active light/dark mode.
    private func withEffectiveAppearance(_ block: () -> Void) {
        effectiveAppearance.performAsCurrentDrawingAppearance(block)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        isRecording ? setRecordingAppearance() : setNormalAppearance()
    }

    // MARK: - Conversion

    private func nsModsToCarbonMods(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.shift)   { m |= UInt32(shiftKey) }
        if flags.contains(.option)  { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        return m
    }

    private func modsToSymbols(_ flags: NSEvent.ModifierFlags) -> String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option)  { s += "⌥" }
        if flags.contains(.shift)   { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s
    }

    // MARK: - Display string (static — reusable from GeneralSettingsVC)

    static func displayString(keyCode: UInt32, carbonMods: UInt32) -> String {
        var s = ""
        if carbonMods & UInt32(controlKey) != 0 { s += "⌃" }
        if carbonMods & UInt32(optionKey)  != 0 { s += "⌥" }
        if carbonMods & UInt32(shiftKey)   != 0 { s += "⇧" }
        if carbonMods & UInt32(cmdKey)     != 0 { s += "⌘" }
        s += keyCodeToChar(keyCode)
        return s
    }

    // MARK: - Key code map

    private static let keyCodeMap: [UInt32: String] = [
        0:  "A",  1:  "S",  2:  "D",  3:  "F",  4:  "H",  5:  "G",
        6:  "Z",  7:  "X",  8:  "C",  9:  "V",  11: "B",  12: "Q",
        13: "W",  14: "E",  15: "R",  16: "Y",  17: "T",  18: "1",
        19: "2",  20: "3",  21: "4",  22: "6",  23: "5",  24: "=",
        25: "9",  26: "7",  27: "-",  28: "8",  29: "0",  30: "]",
        31: "O",  32: "U",  33: "[",  34: "I",  35: "P",  37: "L",
        38: "J",  39: "'",  40: "K",  41: ";",  42: "\\", 43: ",",
        44: "/",  45: "N",  46: "M",  47: ".",
        48: "⇥",  49: "Space", 50: "`",
        96:  "F5",  97: "F6",  98: "F7",  99: "F3",
        100: "F8", 101: "F9", 103: "F11", 109: "F10",
        111: "F12", 118: "F4", 120: "F2", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    static func keyCodeToChar(_ code: UInt32) -> String {
        keyCodeMap[code] ?? "(\(code))"
    }
}
