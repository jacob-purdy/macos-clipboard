import Foundation
import AppKit

// MARK: - Content type

/// Every clipboard entry belongs to exactly one of these types.
/// The raw value is used for JSON persistence and UserDefaults storage.
enum ClipboardContentType: String, Codable, CaseIterable {
    case plainText = "plainText"
    case richText  = "richText"
    case image     = "image"
    case fileURL   = "fileURL"
}

// MARK: - Model

/// A single entry captured from `NSPasteboard`.
///
/// Stored in-memory as an ordered array (most-recent first) inside
/// `ClipboardMonitor`.  When persistence is enabled the array is encoded
/// to JSON via `SharedDefaults.savedHistory`.
struct ClipboardItem: Identifiable, Codable, Equatable {

    let id: UUID

    let type: ClipboardContentType

    /// Plain-text string — present for `.plainText` items, and as the
    /// extracted string representation of `.richText` items.
    var plainText: String?

    /// RTF binary data — present for `.richText` items.
    var rtfData: Data?

    /// PNG / TIFF binary data — present for `.image` items.
    var imageData: Data?

    /// File-system URL — present for `.fileURL` items.
    var fileURL: URL?

    /// Wall-clock time the item was captured.
    let timestamp: Date

    /// Bundle ID of the app that was frontmost when the copy happened.
    let sourceAppBundleID: String?

    /// Human-readable name of that app (localised display name).
    let sourceAppName: String?

    // MARK: - Computed helpers

    /// Up-to-20-character preview string shown in the history panel rows.
    var preview: String {
        switch type {
        case .plainText:
            return truncate(plainText ?? "")

        case .richText:
            if let data = rtfData,
               let attr = try? NSAttributedString(
                   data: data,
                   options: [.documentType: NSAttributedString.DocumentType.rtf],
                   documentAttributes: nil
               ) {
                return truncate(attr.string)
            }
            return "[Rich Text]"

        case .image:
            return "[Image]"

        case .fileURL:
            return fileURL.map { truncate($0.lastPathComponent) } ?? "[File]"
        }
    }

    /// SF Symbol name used as the small type badge in the panel.
    var symbolName: String {
        switch type {
        case .plainText: return "doc.text"
        case .richText:  return "doc.richtext"
        case .image:     return "photo"
        case .fileURL:   return "doc"
        }
    }

    // MARK: - Private helpers

    private func truncate(_ string: String, limit: Int = 20) -> String {
        guard string.count > limit else { return string }
        return String(string.prefix(limit)) + "…"
    }
}
