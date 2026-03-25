import AppKit

/// Drives the scrollable table inside `HistoryPanel`.
///
/// Uses an `NSTableView` for the list and a custom `NSVisualEffectView`
/// background to achieve the dark vibrancy look.
final class HistoryPanelViewController: NSViewController {

    // MARK: - Callback

    /// Called when the user selects an item (click or Return/Enter).
    var onSelect: ((ClipboardItem) -> Void)?

    // MARK: - State

    private var items: [ClipboardItem] = []

    // MARK: - Views

    private lazy var blur: NSVisualEffectView = {
        let v = NSVisualEffectView()
        v.material      = .popover             // adapts to system light/dark appearance
        v.blendingMode  = .behindWindow
        v.state         = .active
        v.wantsLayer    = true
        v.layer?.cornerRadius  = 10
        v.layer?.masksToBounds = true
        return v
    }()

    private lazy var scrollView: NSScrollView = {
        let sv = NSScrollView()
        sv.hasVerticalScroller  = true
        sv.autohidesScrollers   = true
        sv.scrollerStyle        = .overlay
        sv.drawsBackground      = false
        sv.borderType           = .noBorder
        return sv
    }()

    /// Custom table view subclass that intercepts Return/Enter for activation.
    private lazy var tableView: HistoryTableView = {
        let tv = HistoryTableView()
        tv.backgroundColor   = .clear
        tv.headerView        = nil
        tv.intercellSpacing  = NSSize(width: 0, height: 2)
        tv.style             = .plain
        tv.onActivate = { [weak self] in
            self?.activateSelectedRow()
        }
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item"))
        col.isEditable = false
        tv.addTableColumn(col)
        return tv
    }()

    private lazy var footerLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.textColor = NSColor.tertiaryLabelColor
        f.font      = .systemFont(ofSize: 11)
        f.alignment = .right
        return f
    }()

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 320))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.target     = self
        tableView.action     = #selector(handleRowClick)
    }

    // MARK: - Layout

    private func buildLayout() {
        scrollView.documentView = tableView

        [blur, footerLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(scrollView)

        NSLayoutConstraint.activate([
            // Blur fills the whole view
            blur.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blur.topAnchor.constraint(equalTo: view.topAnchor),
            blur.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Footer sits at the bottom
            footerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            footerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            footerLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
            footerLabel.heightAnchor.constraint(equalToConstant: 16),

            // Scroll view fills blur above the footer
            scrollView.leadingAnchor.constraint(equalTo: blur.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: blur.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -4),
        ])
    }

    // MARK: - Data

    func reload(items: [ClipboardItem]) {
        self.items = items
        tableView.reloadData()
        footerLabel.stringValue = "\(items.count) / \(SharedDefaults.historyLimit)"
        if !items.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        }
    }

    // MARK: - Selection

    @objc private func handleRowClick() {
        let row = tableView.clickedRow
        guard row >= 0, row < items.count else { return }
        onSelect?(items[row])
    }

    private func activateSelectedRow() {
        let row = tableView.selectedRow
        guard row >= 0, row < items.count else { return }
        onSelect?(items[row])
    }
}

// MARK: - NSTableViewDataSource

extension HistoryPanelViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }
}

// MARK: - NSTableViewDelegate

extension HistoryPanelViewController: NSTableViewDelegate {

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        let item = items[row]
        switch item.type {
        case .image, .fileURL:
            let id   = NSUserInterfaceItemIdentifier("MediaHistoryItemView")
            let cell = tableView.makeView(withIdentifier: id, owner: nil) as? MediaHistoryItemView
                       ?? MediaHistoryItemView(identifier: id)
            cell.configure(with: item)
            return cell
        case .plainText, .richText:
            let id   = NSUserInterfaceItemIdentifier("HistoryItemView")
            let cell = tableView.makeView(withIdentifier: id, owner: nil) as? HistoryItemView
                       ?? HistoryItemView(identifier: id)
            cell.configure(with: item)
            return cell
        }
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row < items.count else { return 36 }
        switch items[row].type {
        case .image, .fileURL: return 48
        case .plainText, .richText: return 36
        }
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        HistoryRowView()
    }
}

// MARK: - HistoryTableView

/// `NSTableView` subclass that intercepts Return / Enter to activate the
/// selected row.  Arrow-key navigation is handled natively by `NSTableView`.
final class HistoryTableView: NSTableView {
    var onActivate: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:        // Return, Enter (numpad)
            onActivate?()
        default:
            super.keyDown(with: event)
        }
    }
}
