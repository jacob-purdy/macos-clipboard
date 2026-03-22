import AppKit

/// Capture tab — toggle which content types the daemon captures.
final class CaptureSettingsViewController: NSViewController {

    // MARK: - Ordered type list
    // Using an ordered array (not the Set from ClipboardContentType.allCases)
    // so the display order is stable and checkbox tags map correctly.

    private let orderedTypes: [ClipboardContentType] = [
        .plainText,
        .richText,
        .image,
        .fileURL,
    ]

    private let labels: [ClipboardContentType: String] = [
        .plainText: "Plain text",
        .richText:  "Rich text (RTF)",
        .image:     "Images",
        .fileURL:   "File references",
    ]

    private var checkboxes: [ClipboardContentType: NSButton] = [:]

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 380))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
    }

    // MARK: - Layout

    private func buildLayout() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment   = .leading
        stack.spacing     = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let enabled = SharedDefaults.captureTypes

        for (index, type) in orderedTypes.enumerated() {
            let label = labels[type] ?? type.rawValue
            let cb = NSButton(checkboxWithTitle: label,
                              target: self,
                              action: #selector(checkboxChanged(_:)))
            cb.state = enabled.contains(type) ? .on : .off
            cb.tag   = index    // tag == index into orderedTypes
            checkboxes[type] = cb
            stack.addArrangedSubview(cb)
        }

        let note = NSTextField(
            wrappingLabelWithString:
            "Changes take effect immediately. Existing history is not affected."
        )
        note.textColor = .secondaryLabelColor
        note.font      = .systemFont(ofSize: 11)
        stack.addArrangedSubview(note)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
        ])
    }

    // MARK: - Actions

    @objc private func checkboxChanged(_ sender: NSButton) {
        let type = orderedTypes[sender.tag]
        var enabled = SharedDefaults.captureTypes
        if sender.state == .on { enabled.insert(type) } else { enabled.remove(type) }
        SharedDefaults.captureTypes = enabled
        postConfigChanged()
    }

    // MARK: - Helpers

    private func postConfigChanged() {
        DistributedNotificationCenter.default()
            .post(name: NSNotification.Name(DarwinNotification.configChanged), object: nil)
    }
}
