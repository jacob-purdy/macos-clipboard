import AppKit

// MARK: - HistoryItemView

/// Table cell view for a single clipboard history entry.
///
/// Layout (left → right):
///   [SF Symbol badge]  [preview text (bold)]  [source app name (dimmed)]
final class HistoryItemView: NSTableCellView {

    // MARK: - Views

    private let iconView: NSImageView = {
        let iv = NSImageView()
        iv.imageScaling      = .scaleProportionallyDown
        iv.contentTintColor  = NSColor.secondaryLabelColor
        return iv
    }()

    private let previewLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.textColor             = .labelColor
        f.font                  = .systemFont(ofSize: 13, weight: .regular)
        f.lineBreakMode         = .byTruncatingTail
        f.maximumNumberOfLines  = 1
        return f
    }()

    private let sourceLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.textColor             = .tertiaryLabelColor
        f.font                  = .systemFont(ofSize: 10)
        f.lineBreakMode         = .byTruncatingTail
        f.maximumNumberOfLines  = 1
        return f
    }()

    // MARK: - Init

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("Use init(identifier:)") }

    // MARK: - Layout

    private func buildLayout() {
        [iconView, previewLabel, sourceLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            // Icon — fixed size, left-aligned, vertically centred
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 15),
            iconView.heightAnchor.constraint(equalToConstant: 15),

            // Preview label — fills the middle, hugs the icon
            previewLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            previewLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            previewLabel.trailingAnchor.constraint(lessThanOrEqualTo: sourceLabel.leadingAnchor, constant: -4),

            // Source app name — right side, constrained width so it doesn't crowd preview
            sourceLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            sourceLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            sourceLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 72),
        ])
    }

    // MARK: - Configure

    func configure(with item: ClipboardItem) {
        iconView.image         = NSImage(systemSymbolName: item.symbolName,
                                         accessibilityDescription: nil)
        previewLabel.stringValue = item.preview
        sourceLabel.stringValue  = item.sourceAppName ?? ""
    }
}

// MARK: - MediaHistoryItemView

/// Table cell view for image and file-URL clipboard entries.
///
/// Layout (left → right):
///   [40×40 thumbnail]  [preview text (top)]
///                      [source app name (bottom, dimmed)]
final class MediaHistoryItemView: NSTableCellView {

    // MARK: - Views

    private let thumbnailView: NSImageView = {
        let iv = NSImageView()
        iv.imageScaling  = .scaleProportionallyUpOrDown
        iv.wantsLayer    = true
        iv.layer?.cornerRadius  = 4
        iv.layer?.masksToBounds = true
        return iv
    }()

    private let previewLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.textColor            = .labelColor
        f.font                 = .systemFont(ofSize: 12, weight: .regular)
        f.lineBreakMode        = .byTruncatingMiddle
        f.maximumNumberOfLines = 1
        return f
    }()

    private let sourceLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.textColor            = .tertiaryLabelColor
        f.font                 = .systemFont(ofSize: 10)
        f.lineBreakMode        = .byTruncatingTail
        f.maximumNumberOfLines = 1
        return f
    }()

    private lazy var textStack: NSStackView = {
        let sv = NSStackView(views: [previewLabel, sourceLabel])
        sv.orientation = .vertical
        sv.spacing     = 2
        sv.alignment   = .leading
        return sv
    }()

    // MARK: - Init

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("Use init(identifier:)") }

    // MARK: - Layout

    private func buildLayout() {
        [thumbnailView, textStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            // Thumbnail — 40×40, left edge, vertically centred
            thumbnailView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            thumbnailView.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumbnailView.widthAnchor.constraint(equalToConstant: 40),
            thumbnailView.heightAnchor.constraint(equalToConstant: 40),

            // Text stack — fills the remaining width
            textStack.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 8),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    // MARK: - Configure

    func configure(with item: ClipboardItem) {
        previewLabel.stringValue = item.preview
        sourceLabel.stringValue  = item.sourceAppName ?? ""

        switch item.type {
        case .image:
            if let data = item.imageData {
                thumbnailView.image = NSImage(data: data)
            } else {
                thumbnailView.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
            }
        case .fileURL:
            if let url = item.fileURL {
                thumbnailView.image = NSWorkspace.shared.icon(forFile: url.path)
            } else {
                thumbnailView.image = NSImage(systemSymbolName: "doc", accessibilityDescription: nil)
            }
        default:
            thumbnailView.image = nil
        }
    }
}

// MARK: - HistoryRowView

/// Custom row view that applies a rounded, semi-transparent selection
/// highlight consistent with the dark panel aesthetic.
final class HistoryRowView: NSTableRowView {

    override func drawSelection(in dirtyRect: NSRect) {
        guard isSelected else { return }
        let rect = bounds.insetBy(dx: 4, dy: 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        NSColor.selectedContentBackgroundColor
            .withAlphaComponent(0.5)
            .setFill()
        path.fill()
    }
}
