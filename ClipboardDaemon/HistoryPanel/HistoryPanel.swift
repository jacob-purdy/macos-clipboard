import AppKit

/// The floating, non-activating panel that displays clipboard history.
///
/// Shown when the user presses the global hotkey; dismissed automatically
/// after an item is selected, or when the user presses Escape or clicks
/// outside the panel.
///
/// **Non-activating** — the `.nonactivatingPanel` style mask means the panel
/// never becomes the key window.  The previously focused app retains focus,
/// which is what allows `PasteManager` to paste into it.
final class HistoryPanel: NSPanel {

    // MARK: - Sub-controller

    private let contentVC = HistoryPanelViewController()
    private var onSelect: ((ClipboardItem) -> Void)?
    private var clickMonitor: Any?

    // MARK: - Dimensions

    private let panelWidth:  CGFloat = 260
    private let panelHeight: CGFloat = 320

    // MARK: - Init

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 320),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        configure()
    }

    // MARK: - Configuration

    private func configure() {
        isRestorable                = false
        isFloatingPanel             = true
        level                       = .floating
        isOpaque                    = false
        backgroundColor             = .clear
        hasShadow                   = true
        isMovableByWindowBackground = true
        collectionBehavior          = [.canJoinAllSpaces, .fullScreenAuxiliary]

        contentViewController = contentVC
        contentVC.onSelect = { [weak self] item in
            self?.dismiss()
            self?.onSelect?(item)
        }
    }

    // MARK: - Presentation

    /// Populate the list and show the panel at the appropriate position.
    func present(items: [ClipboardItem], onSelect: @escaping (ClipboardItem) -> Void) {
        self.onSelect = onSelect
        contentVC.reload(items: items)
        position()
        makeKeyAndOrderFront(nil)
        installClickMonitor()
    }

    func dismiss() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        orderOut(nil)
    }

    // MARK: - Click-outside monitor

    private func installClickMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self, self.isVisible else { return }
            if !self.frame.contains(NSEvent.mouseLocation) {
                self.dismiss()
            }
        }
    }

    // MARK: - Positioning

    private func position() {
        switch SharedDefaults.panelPosition {
        case .nearCursor:
            let mouse  = NSEvent.mouseLocation
            let origin = NSPoint(
                x: mouse.x + 4,
                y: mouse.y - panelHeight - 4
            )
            setFrameOrigin(clamped(origin))

        case .bottomLeft:
            if let screen = NSScreen.main {
                let inset: CGFloat = 12
                setFrameOrigin(NSPoint(
                    x: screen.visibleFrame.minX + inset,
                    y: screen.visibleFrame.minY + inset
                ))
            }

        case .bottomRight:
            if let screen = NSScreen.main {
                let inset: CGFloat = 12
                setFrameOrigin(NSPoint(
                    x: screen.visibleFrame.maxX - panelWidth - inset,
                    y: screen.visibleFrame.minY + inset
                ))
            }
        }
    }

    /// Nudges the origin so the panel stays fully on-screen.
    private func clamped(_ origin: NSPoint) -> NSPoint {
        guard let sf = NSScreen.main?.visibleFrame else { return origin }
        let x = min(max(origin.x, sf.minX), sf.maxX - panelWidth)
        let y = min(max(origin.y, sf.minY), sf.maxY - panelHeight)
        return NSPoint(x: x, y: y)
    }

    // MARK: - Keyboard pass-through

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // Escape
            dismiss()
        } else {
            super.keyDown(with: event)
        }
    }

    override var canBecomeKey: Bool { true }
}
