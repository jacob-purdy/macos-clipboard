# ClipboardHistory

A lightweight macOS clipboard history manager that lives quietly in the background. Press a keyboard shortcut to instantly access and paste your recent copies.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

---

## Features

- **Clipboard history** — stores your last 10 copied items (text, rich text, images, and files)
- **Instant access** — press `⌘⌥V` to open a floating panel over any app
- **Paste directly** — select an item and it pastes immediately into your focused app
- **Scrollable history** — panel scrolls when history exceeds the visible list
- **Easy dismissal** — panel closes on selection, Escape, or clicking outside it
- **App exclusions** — ignore copies from specific apps (e.g. password managers)
- **Capture filters** — choose which content types to capture
- **Launch at Login** — optionally start automatically on every login
- **Customisable hotkey** — set your own keyboard shortcut in Settings
- **Panel position** — near cursor, bottom-left, or bottom-right
- **Dark vibrancy UI** — blends naturally with macOS

---

## Project Structure

Two targets built from a single Xcode project:

| Target | Description |
|---|---|
| `ClipboardDaemon` | Background agent (`LSUIElement`). No Dock icon. Monitors clipboard, handles hotkey, shows history panel. |
| `ClipboardSettings` | Normal app. Opens from the Applications folder to configure the daemon. |

Shared code in `Shared/` is compiled into both targets.

---

## Requirements

- macOS 13.0 or later
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

---

## Building

```bash
git clone https://github.com/your-username/macos-clipboard.git
cd macos-clipboard
xcodegen generate --spec project.yml
open ClipboardHistory.xcodeproj
```

Build and run each target separately in Xcode:
- **ClipboardDaemon** — runs silently in the background
- **ClipboardSettings** — open from Applications to configure

---

## First Launch

1. Run **ClipboardDaemon** — macOS will prompt for **Accessibility permission** (required for paste simulation). Grant it in System Settings → Privacy & Security → Accessibility.
2. Open **ClipboardSettings** → General → check **Launch at Login** so the daemon starts automatically.
3. Copy something, then press `⌘⌥V`.

---

## Settings

| Setting | Description |
|---|---|
| Global hotkey | Default: `⌘⌥V`. Click the field and press any modifier + key combo to change. |
| Panel position | Near cursor (default), bottom-left, or bottom-right |
| History limit | Number of items to keep (5–50, default 10) |
| Paste immediately | Auto-paste into the previously focused app on selection |
| Preserve history | Reload history after daemon restarts (off by default) |
| Launch at Login | Start the daemon automatically on login |
| Capture types | Toggle plain text, rich text, images, and file references |
| Exclusions | Browse to add apps whose copies are ignored |

---

## Permissions

| Permission | Why |
|---|---|
| Accessibility | Simulates `⌘V` to paste into other apps |

---

## License

MIT
