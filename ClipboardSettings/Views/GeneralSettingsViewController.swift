import AppKit

/// General tab — hotkey, panel position, history limit, paste behaviour,
/// persistence, daemon management, and reset to defaults.
final class GeneralSettingsViewController: NSViewController {

    // MARK: - Controls

    private let hotkeyCaptureView = HotkeyCaptureView()

    private let appearancePopup = NSPopUpButton()
    private let positionPopup = NSPopUpButton()

    private let limitStepper    = NSStepper()
    private let limitValueLabel = NSTextField(labelWithString: "10")

    private let pasteToggle   = NSButton(checkboxWithTitle: "Paste immediately after selection",
                                          target: nil, action: nil)
    private let persistToggle = NSButton(checkboxWithTitle: "Preserve history across restarts",
                                          target: nil, action: nil)

    private let launchAtLoginToggle = NSButton(checkboxWithTitle: "Launch at Login",
                                               target: nil, action: nil)
    private let startButton   = NSButton(title: "Start Clipboard",       target: nil, action: nil)
    private let restartButton = NSButton(title: "Restart Clipboard",     target: nil, action: nil)
    private let quitButton    = NSButton(title: "Quit Clipboard",        target: nil, action: nil)
    private let resetButton   = NSButton(title: "Reset to Defaults…",    target: nil, action: nil)

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 420))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureControls()
        buildLayout()
        loadValues()
        wireActions()
    }

    // MARK: - Control configuration

    private func configureControls() {
        appearancePopup.addItems(withTitles: AppearanceMode.allCases.map(\.displayName))
        positionPopup.addItems(withTitles: PanelPosition.allCases.map(\.rawValue))

        limitStepper.minValue  = 5
        limitStepper.maxValue  = 50
        limitStepper.increment = 1

        [restartButton, quitButton, resetButton].forEach { $0.bezelStyle = .rounded }
        resetButton.contentTintColor = .systemRed
    }

    // MARK: - Layout

    private func buildLayout() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment   = .leading
        stack.spacing     = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        let limitRow = NSStackView(views: [limitStepper, limitValueLabel])
        limitRow.spacing = 6

        stack.addArrangedSubview(row("Global hotkey",   control: hotkeyCaptureView))
        stack.addArrangedSubview(row("Panel position",  control: positionPopup))
        stack.addArrangedSubview(row("Appearance",      control: appearancePopup))
        stack.addArrangedSubview(row("History limit",   control: limitRow))
        stack.addArrangedSubview(pasteToggle)
        stack.addArrangedSubview(persistToggle)
        stack.addArrangedSubview(launchAtLoginToggle)

        let sep1 = separator(); stack.addArrangedSubview(sep1)
        sep1.widthAnchor.constraint(equalToConstant: 440).isActive = true

        let daemonRow = NSStackView(views: [startButton, restartButton, quitButton])
        daemonRow.spacing = 10
        stack.addArrangedSubview(daemonRow)

        let sep2 = separator(); stack.addArrangedSubview(sep2)
        sep2.widthAnchor.constraint(equalToConstant: 440).isActive = true

        stack.addArrangedSubview(resetButton)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
        ])
    }

    private func row(_ label: String, control: NSView) -> NSView {
        let lbl = NSTextField(labelWithString: label + ":")
        lbl.alignment = .right
        lbl.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        lbl.widthAnchor.constraint(equalToConstant: 120).isActive = true
        let r = NSStackView(views: [lbl, control])
        r.spacing = 10
        return r
    }

    private func separator() -> NSBox {
        let b = NSBox(); b.boxType = .separator; return b
    }

    // MARK: - Load values

    private func loadValues() {
        hotkeyCaptureView.refreshLabel()
        appearancePopup.selectItem(withTitle: SharedDefaults.appearanceMode.displayName)
        positionPopup.selectItem(withTitle: SharedDefaults.panelPosition.rawValue)
        limitStepper.integerValue    = SharedDefaults.historyLimit
        limitValueLabel.integerValue = SharedDefaults.historyLimit
        pasteToggle.state         = SharedDefaults.pasteImmediately ? .on : .off
        persistToggle.state       = SharedDefaults.persistHistory   ? .on : .off
        launchAtLoginToggle.state = SharedDefaults.launchAtLogin    ? .on : .off
    }

    // MARK: - Wire actions

    private func wireActions() {
        hotkeyCaptureView.onCapture = { [weak self] _, _ in
            self?.notifyConfigChanged()
        }
        launchAtLoginToggle.target = self; launchAtLoginToggle.action = #selector(toggleLaunchAtLogin(_:))
        pasteToggle.target   = self; pasteToggle.action   = #selector(togglePaste(_:))
        persistToggle.target = self; persistToggle.action = #selector(togglePersist(_:))
        startButton.target   = self; startButton.action   = #selector(startClipboard)
        limitStepper.target  = self; limitStepper.action  = #selector(stepperChanged(_:))
        appearancePopup.target = self; appearancePopup.action = #selector(appearanceChanged(_:))
        positionPopup.target = self; positionPopup.action = #selector(positionChanged(_:))
        restartButton.target = self; restartButton.action = #selector(restartDaemon)
        quitButton.target    = self; quitButton.action    = #selector(quitDaemon)
        resetButton.target   = self; resetButton.action   = #selector(resetToDefaults)
    }

    // MARK: - Actions

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        SharedDefaults.launchAtLogin = sender.state == .on
        notifyConfigChanged()
    }

    @objc private func startClipboard() {
        DaemonLauncher.launch()
    }

    @objc private func togglePaste(_ sender: NSButton) {
        SharedDefaults.pasteImmediately = sender.state == .on
        notifyConfigChanged()
    }

    @objc private func togglePersist(_ sender: NSButton) {
        SharedDefaults.persistHistory = sender.state == .on
        notifyConfigChanged()
    }

    @objc private func stepperChanged(_ sender: NSStepper) {
        SharedDefaults.historyLimit      = sender.integerValue
        limitValueLabel.integerValue     = sender.integerValue
        notifyConfigChanged()
    }

    @objc private func appearanceChanged(_ sender: NSPopUpButton) {
        let selected = AppearanceMode.allCases.first {
            $0.displayName == sender.titleOfSelectedItem
        } ?? .dark
        SharedDefaults.appearanceMode = selected
        NSApp.appearance = selected.nsAppearance
        notifyConfigChanged()
    }

    @objc private func positionChanged(_ sender: NSPopUpButton) {
        if let pos = PanelPosition(rawValue: sender.titleOfSelectedItem ?? "") {
            SharedDefaults.panelPosition = pos
            notifyConfigChanged()
        }
    }

    @objc private func restartDaemon() {
        postDarwin(DarwinNotification.restartDaemon)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            DaemonLauncher.launch()
        }
    }

    @objc private func quitDaemon() {
        postDarwin(DarwinNotification.quitDaemon)
    }

    @objc private func resetToDefaults() {
        let alert = NSAlert()
        alert.messageText     = "Reset all settings to defaults?"
        alert.informativeText = "This cannot be undone."
        alert.alertStyle      = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        SharedDefaults.resetToDefaults()
        loadValues()            // refresh UI to reflect new defaults
        notifyConfigChanged()   // tell the daemon to reload
    }

    // MARK: - Helpers

    private func notifyConfigChanged() { postDarwin(DarwinNotification.configChanged) }

    private func postDarwin(_ name: String) {
        DistributedNotificationCenter.default()
            .post(name: NSNotification.Name(name), object: nil)
    }
}
