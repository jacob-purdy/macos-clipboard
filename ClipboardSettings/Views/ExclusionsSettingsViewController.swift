import AppKit
import UniformTypeIdentifiers

/// Exclusions tab — manage the list of apps the daemon ignores.
///
/// The user browses for an `.app` bundle using `NSOpenPanel`; the app's
/// bundle ID is stored in `SharedDefaults.excludedBundleIDs`.
final class ExclusionsSettingsViewController: NSViewController {

    // MARK: - Model

    private struct ExcludedApp {
        let bundleID: String
        let displayName: String
    }

    private var exclusions: [ExcludedApp] = []

    // MARK: - Views

    private let tableView  = NSTableView()
    private let scrollView = NSScrollView()
    private let addButton    = NSButton(title: "+ Add App…", target: nil, action: nil)
    private let removeButton = NSButton(title: "– Remove",   target: nil, action: nil)

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 380))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadExclusions()
        buildLayout()
        wireActions()
    }

    // MARK: - Data

    private func loadExclusions() {
        exclusions = SharedDefaults.excludedBundleIDs.map { id in
            let name = displayName(forBundleID: id) ?? id
            return ExcludedApp(bundleID: id, displayName: name)
        }
    }

    private func saveExclusions() {
        SharedDefaults.excludedBundleIDs = exclusions.map(\.bundleID)
        postConfigChanged()
    }

    /// Attempts to resolve a bundle ID to a human-readable app name.
    private func displayName(forBundleID id: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id),
              let bundle = Bundle(url: url) else { return nil }
        return bundle.infoDictionary?["CFBundleDisplayName"] as? String
            ?? bundle.infoDictionary?["CFBundleName"] as? String
    }

    // MARK: - Layout

    private func buildLayout() {
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        col.headerCell.stringValue = "Excluded Applications"
        col.isEditable = false
        tableView.addTableColumn(col)
        tableView.dataSource = self
        tableView.delegate   = self

        scrollView.documentView      = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType          = .bezelBorder

        addButton.bezelStyle    = .rounded
        removeButton.bezelStyle = .rounded

        let btnRow = NSStackView(views: [addButton, removeButton])
        btnRow.spacing = 8

        [scrollView, btnRow].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            scrollView.bottomAnchor.constraint(equalTo: btnRow.topAnchor, constant: -8),

            btnRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            btnRow.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
        ])
    }

    // MARK: - Actions

    private func wireActions() {
        addButton.target    = self; addButton.action    = #selector(addApp)
        removeButton.target = self; removeButton.action = #selector(removeApp)
    }

    @objc private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes    = [UTType.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message      = "Choose an application to exclude from clipboard capture."

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            guard let bundle   = Bundle(url: url),
                  let bundleID = bundle.bundleIdentifier else { return }

            // Avoid duplicates.
            guard let self, !self.exclusions.contains(where: { $0.bundleID == bundleID }) else { return }

            let name = bundle.infoDictionary?["CFBundleDisplayName"] as? String
                    ?? bundle.infoDictionary?["CFBundleName"] as? String
                    ?? url.deletingPathExtension().lastPathComponent

            self.exclusions.append(ExcludedApp(bundleID: bundleID, displayName: name))
            self.tableView.reloadData()
            self.saveExclusions()
        }
    }

    @objc private func removeApp() {
        let row = tableView.selectedRow
        guard row >= 0, row < exclusions.count else { return }
        exclusions.remove(at: row)
        tableView.reloadData()
        saveExclusions()
    }

    // MARK: - Helpers

    private func postConfigChanged() {
        DistributedNotificationCenter.default()
            .post(name: NSNotification.Name(DarwinNotification.configChanged), object: nil)
    }
}

// MARK: - NSTableViewDataSource / NSTableViewDelegate

extension ExclusionsSettingsViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { exclusions.count }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        let id   = NSUserInterfaceItemIdentifier("ExclusionCell")
        let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView
                   ?? makeCell(identifier: id)
        cell.textField?.stringValue = exclusions[row].displayName
        return cell
    }

    private func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier
        let tf = NSTextField(labelWithString: "")
        tf.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(tf)
        cell.textField = tf
        NSLayoutConstraint.activate([
            tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}
