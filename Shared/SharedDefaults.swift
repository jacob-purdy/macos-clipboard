import AppKit

// MARK: - Appearance mode

/// Controls which NSAppearance is applied to the panel and settings window.
enum AppearanceMode: String, CaseIterable {
    case dark   = "dark"
    case system = "system"
    case light  = "light"

    var displayName: String {
        switch self {
        case .dark:   return "Dark"
        case .system: return "Match system preference"
        case .light:  return "Light"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .dark:   return NSAppearance(named: .darkAqua)
        case .light:  return NSAppearance(named: .aqua)
        case .system: return nil
        }
    }
}

// MARK: - Panel position

/// Where the history panel appears when the hotkey is pressed.
enum PanelPosition: String, CaseIterable {
    case nearCursor  = "nearCursor"   // default — appears near the mouse pointer
    case bottomLeft  = "bottomLeft"
    case bottomRight = "bottomRight"
}

// MARK: - Darwin notification names

/// Cross-process notification names posted via `CFNotificationCenterGetDarwinNotifyCenter`.
///
/// The Settings app posts these; the daemon listens and reacts without needing
/// a full restart (except for `restartDaemon`).
enum DarwinNotification {
    /// Any config value changed — daemon should reload settings.
    static let configChanged  = "com.clipboardhistory.configChanged"
    /// Settings app requests a daemon restart (posts before relaunching it).
    static let restartDaemon  = "com.clipboardhistory.restartDaemon"
    /// Settings app requests the daemon to quit entirely.
    static let quitDaemon     = "com.clipboardhistory.quitDaemon"
}

// MARK: - Shared defaults

/// Typed wrapper around the `UserDefaults` suite shared by both the daemon
/// and the settings app.
///
/// On macOS, `UserDefaults(suiteName:)` writes to
/// `~/Library/Preferences/com.clipboardhistory.plist` — readable by any
/// process that knows the suite name, no App Group entitlement required.
struct SharedDefaults {

    static let suiteName = "com.clipboardhistory"

    private static var store: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    // MARK: - Keys

    private enum Key {
        static let captureTypes   = "captureTypes"
        static let excludedIDs    = "excludedBundleIDs"
        static let hotkeyKeyCode  = "hotkeyKeyCode"
        static let hotkeyMods     = "hotkeyModifiers"
        static let panelPosition  = "panelPosition"
        static let historyLimit   = "historyLimit"
        static let persistHistory = "persistHistory"
        static let pasteImmediate = "pasteImmediately"
        static let savedHistory   = "savedHistory"
        static let launchAtLogin  = "launchAtLogin"
        static let appearanceMode = "appearanceMode"
    }

    // MARK: - Capture types

    /// Which content types the daemon captures. Defaults to all types.
    static var captureTypes: Set<ClipboardContentType> {
        get {
            guard let raw = store.stringArray(forKey: Key.captureTypes) else {
                return Set(ClipboardContentType.allCases)
            }
            return Set(raw.compactMap(ClipboardContentType.init(rawValue:)))
        }
        set { store.set(newValue.map(\.rawValue), forKey: Key.captureTypes) }
    }

    // MARK: - App exclusions

    /// Bundle IDs of apps whose copies the daemon ignores.
    static var excludedBundleIDs: [String] {
        get { store.stringArray(forKey: Key.excludedIDs) ?? [] }
        set { store.set(newValue, forKey: Key.excludedIDs) }
    }

    // MARK: - Hotkey

    /// Carbon virtual key code for the global hotkey.
    /// Default: 9 (the V key).
    static var hotkeyKeyCode: UInt32 {
        get {
            let v = store.integer(forKey: Key.hotkeyKeyCode)
            return v == 0 ? 9 : UInt32(v)
        }
        set { store.set(Int(newValue), forKey: Key.hotkeyKeyCode) }
    }

    /// Carbon modifier flags for the global hotkey.
    /// Default: 2304 = cmdKey (256) | optionKey (2048) → ⌥⌘
    static var hotkeyModifiers: UInt32 {
        get {
            let v = store.integer(forKey: Key.hotkeyMods)
            return v == 0 ? 2304 : UInt32(v)
        }
        set { store.set(Int(newValue), forKey: Key.hotkeyMods) }
    }

    // MARK: - Panel position

    /// Where the panel appears. Default: near the cursor.
    static var panelPosition: PanelPosition {
        get { PanelPosition(rawValue: store.string(forKey: Key.panelPosition) ?? "") ?? .nearCursor }
        set { store.set(newValue.rawValue, forKey: Key.panelPosition) }
    }

    // MARK: - History limit

    /// Maximum items kept in the ring buffer. Default: 10.
    static var historyLimit: Int {
        get {
            let v = store.integer(forKey: Key.historyLimit)
            return v == 0 ? 10 : v
        }
        set { store.set(newValue, forKey: Key.historyLimit) }
    }

    // MARK: - Persistence

    /// If `true`, history is written to disk on daemon quit and reloaded on
    /// next launch. Default: `false`.
    static var persistHistory: Bool {
        get { store.bool(forKey: Key.persistHistory) }
        set { store.set(newValue, forKey: Key.persistHistory) }
    }

    // MARK: - Paste behaviour

    /// If `true`, the daemon simulates ⌘V into the previously focused app
    /// after an item is selected. If `false`, it only writes to the clipboard.
    /// Default: `true`.
    static var pasteImmediately: Bool {
        get {
            guard store.object(forKey: Key.pasteImmediate) != nil else { return true }
            return store.bool(forKey: Key.pasteImmediate)
        }
        set { store.set(newValue, forKey: Key.pasteImmediate) }
    }

    // MARK: - Appearance

    /// The appearance applied to the panel and settings window. Default: dark.
    static var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: store.string(forKey: Key.appearanceMode) ?? "") ?? .dark }
        set { store.set(newValue.rawValue, forKey: Key.appearanceMode) }
    }

    // MARK: - Launch at login

    /// Whether the daemon registers itself as a login item. Default: false.
    static var launchAtLogin: Bool {
        get { store.bool(forKey: Key.launchAtLogin) }
        set { store.set(newValue, forKey: Key.launchAtLogin) }
    }

    // MARK: - Reset

    /// Removes all stored values, restoring every setting to its coded default.
    static func resetToDefaults() {
        [Key.captureTypes, Key.excludedIDs, Key.hotkeyKeyCode, Key.hotkeyMods,
         Key.panelPosition, Key.historyLimit, Key.persistHistory,
         Key.pasteImmediate, Key.savedHistory, Key.launchAtLogin, Key.appearanceMode]
            .forEach { store.removeObject(forKey: $0) }
    }

    // MARK: - Persisted history

    /// The history array serialised to JSON (only populated when
    /// `persistHistory` is `true`).
    static var savedHistory: [ClipboardItem] {
        get {
            guard let data = store.data(forKey: Key.savedHistory) else { return [] }
            return (try? JSONDecoder().decode([ClipboardItem].self, from: data)) ?? []
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            store.set(data, forKey: Key.savedHistory)
        }
    }
}
