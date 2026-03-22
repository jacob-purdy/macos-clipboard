import AppKit

/// Monitors `NSPasteboard.general` for changes and maintains the clipboard
/// history ring buffer.
///
/// **Polling strategy** — macOS provides no push notification for pasteboard
/// changes, so we poll `NSPasteboard.changeCount` every 0.5 s on the main
/// run loop.  Only when the count changes do we read and capture the content.
///
/// **Capture priority** — on each change we try content types in this order
/// (first match wins): rich text → plain text → image → file URL.
/// Types disabled in Settings are skipped entirely.
///
/// **Deduplication** — consecutive identical plain-text copies are ignored
/// to avoid double-entries when a user rapidly presses ⌘C.
final class ClipboardMonitor {

    // MARK: - Public state

    /// History ordered most-recent first.  Maximum `SharedDefaults.historyLimit` entries.
    private(set) var history: [ClipboardItem] = []

    // MARK: - Private

    private var pollTimer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount

    // MARK: - Lifecycle

    func start() {
        pollTimer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: true
        ) { [weak self] _ in
            self?.poll()
        }
        // .common mode ensures the timer fires even during UI event tracking
        // (e.g. while a menu is open).
        RunLoop.main.add(pollTimer!, forMode: .common)
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Call after any settings change to reload filters live.
    /// The polling timer itself does not need restarting.
    func reloadConfig() {
        // Exclusion list and capture types are read from SharedDefaults on
        // every poll cycle, so no explicit action is required here.
        // This method exists as a hook for future stateful config.
    }

    // MARK: - History management

    /// Seed the history from a previously persisted snapshot.
    func loadHistory(_ items: [ClipboardItem]) {
        history = Array(items.prefix(SharedDefaults.historyLimit))
    }

    /// Move an existing item to position 0 without duplicating it.
    /// Called after the user selects an item from the panel.
    func bringToFront(_ item: ClipboardItem) {
        history.removeAll { $0.id == item.id }
        history.insert(item, at: 0)
    }

    // MARK: - Polling

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        // Identify the source application at the moment of copy.
        let frontApp = NSWorkspace.shared.frontmostApplication
        let bundleID = frontApp?.bundleIdentifier ?? ""
        let appName  = frontApp?.localizedName    ?? ""

        // Skip copies from apps on the exclusion list.
        guard !SharedDefaults.excludedBundleIDs.contains(bundleID) else { return }

        if let item = captureItem(from: pb, sourceID: bundleID, sourceName: appName) {
            insert(item)
        }
    }

    /// Tries to build a `ClipboardItem` from the current pasteboard contents.
    /// Returns `nil` if no enabled content type is available.
    private func captureItem(
        from pb: NSPasteboard,
        sourceID: String,
        sourceName: String
    ) -> ClipboardItem? {
        let enabled = SharedDefaults.captureTypes

        // --- Rich text ---
        if enabled.contains(.richText), let data = pb.data(forType: .rtf) {
            let plain = (try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ))?.string
            return ClipboardItem(
                id: UUID(), type: .richText,
                plainText: plain, rtfData: data,
                imageData: nil, fileURL: nil,
                timestamp: Date(),
                sourceAppBundleID: sourceID, sourceAppName: sourceName
            )
        }

        // --- Plain text ---
        if enabled.contains(.plainText),
           let text = pb.string(forType: .string), !text.isEmpty {
            return ClipboardItem(
                id: UUID(), type: .plainText,
                plainText: text, rtfData: nil,
                imageData: nil, fileURL: nil,
                timestamp: Date(),
                sourceAppBundleID: sourceID, sourceAppName: sourceName
            )
        }

        // --- Image (TIFF preferred, PNG fallback) ---
        if enabled.contains(.image),
           let data = pb.data(forType: .tiff) ?? pb.data(forType: .png) {
            return ClipboardItem(
                id: UUID(), type: .image,
                plainText: nil, rtfData: nil,
                imageData: data, fileURL: nil,
                timestamp: Date(),
                sourceAppBundleID: sourceID, sourceAppName: sourceName
            )
        }

        // --- File URL ---
        if enabled.contains(.fileURL),
           let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let first = urls.first {
            return ClipboardItem(
                id: UUID(), type: .fileURL,
                plainText: nil, rtfData: nil,
                imageData: nil, fileURL: first,
                timestamp: Date(),
                sourceAppBundleID: sourceID, sourceAppName: sourceName
            )
        }

        return nil
    }

    /// Inserts a new item at the front of history, trims to the limit, and
    /// deduplicates consecutive identical plain-text entries.
    private func insert(_ item: ClipboardItem) {
        // Ignore consecutive identical plain-text copies.
        if let last = history.first,
           last.type == .plainText,
           item.type == .plainText,
           last.plainText == item.plainText { return }

        history.insert(item, at: 0)
        let limit = SharedDefaults.historyLimit
        if history.count > limit {
            history = Array(history.prefix(limit))
        }
    }

    // MARK: - Static write helper

    /// Writes a `ClipboardItem` back onto `NSPasteboard.general`.
    /// Called by `AppDelegate` when the user selects an item.
    static func writeToPasteboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.type {
        case .plainText:
            if let text = item.plainText { pb.setString(text, forType: .string) }
        case .richText:
            if let data = item.rtfData  { pb.setData(data, forType: .rtf) }
            if let text = item.plainText { pb.setString(text, forType: .string) }
        case .image:
            if let data = item.imageData { pb.setData(data, forType: .tiff) }
        case .fileURL:
            if let url = item.fileURL   { pb.writeObjects([url as NSURL]) }
        }
    }
}
