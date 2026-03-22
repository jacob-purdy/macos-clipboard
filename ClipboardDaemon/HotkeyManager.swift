import CoreGraphics
import Carbon   // cmdKey, shiftKey, optionKey, controlKey constants

/// Registers a global keyboard shortcut using a `CGEventTap`.
///
/// On every system-wide keyDown event we compare the key code and modifiers
/// against the values stored in `SharedDefaults`.  The tap fires regardless
/// of which app is frontmost.
///
/// **Permission** — `CGEventTapCreate` requires Accessibility access
/// (System Settings → Privacy & Security → Accessibility), which is the same
/// permission the paste simulation needs.  If it hasn't been granted yet the
/// tap silently fails to create; the user must grant access and restart the
/// daemon.
final class HotkeyManager {

    // MARK: - Private

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let onFire: () -> Void

    // MARK: - Init

    init(onFire: @escaping () -> Void) {
        self.onFire = onFire
    }

    deinit { unregister() }

    // MARK: - Public interface

    func register() {
        guard eventTap == nil else { return }

        let mask     = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfPtr  = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, userInfo -> Unmanaged<CGEvent>? in
                // .listenOnly — return value is ignored by the system.
                // `event` is non-optional per CGEventTapCallBack typealias.
                if let userInfo {
                    Unmanaged<HotkeyManager>
                        .fromOpaque(userInfo)
                        .takeUnretainedValue()
                        .check(event: event)
                }
                return nil
            },
            userInfo: selfPtr
        ) else {
            print("[HotkeyManager] CGEventTapCreate failed — grant Accessibility and restart daemon")
            return
        }

        eventTap      = tap
        runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func unregister() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        eventTap      = nil
        runLoopSource = nil
    }

    /// After a hotkey setting change, re-enable the tap.
    /// The key combo is read live from `SharedDefaults` on each keypress so
    /// no full teardown is needed.
    func reregister() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        } else {
            register()
        }
    }

    // MARK: - Event matching

    private func check(event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == Int64(SharedDefaults.hotkeyKeyCode) else { return }

        let actual   = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
        let expected = carbonModsToEventFlags(SharedDefaults.hotkeyModifiers)
        guard actual == expected else { return }

        DispatchQueue.main.async { self.onFire() }
    }

    /// Converts the Carbon modifier bitmask stored in `SharedDefaults` to
    /// the equivalent `CGEventFlags` for comparison.
    private func carbonModsToEventFlags(_ mods: UInt32) -> CGEventFlags {
        var flags: CGEventFlags = []
        if mods & UInt32(cmdKey)     != 0 { flags.insert(.maskCommand) }
        if mods & UInt32(shiftKey)   != 0 { flags.insert(.maskShift) }
        if mods & UInt32(optionKey)  != 0 { flags.insert(.maskAlternate) }
        if mods & UInt32(controlKey) != 0 { flags.insert(.maskControl) }
        return flags
    }
}
