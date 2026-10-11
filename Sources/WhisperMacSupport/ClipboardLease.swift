import AppKit

/// A one-use, conditional restoration of clipboard data. A private named
/// pasteboard can exercise this behavior without touching the user's clipboard.
@MainActor public final class ClipboardLease {
    private let pasteboard: NSPasteboard
    private let originals: [NSPasteboardItem]
    private let changeCount: Int
    private var restored = false

    public init(text: String, pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        originals = pasteboard.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        } ?? []
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        changeCount = pasteboard.changeCount
    }

    @discardableResult public func restoreIfUnchanged() -> Bool {
        guard !restored, pasteboard.changeCount == changeCount else { return false }
        restored = true
        pasteboard.clearContents()
        if !originals.isEmpty { pasteboard.writeObjects(originals) }
        return true
    }
}
