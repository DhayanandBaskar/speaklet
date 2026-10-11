import Foundation

/// Keep the original field valid through repeated reports of the same focus,
/// but never revalidate it after focus has moved elsewhere.
public struct InsertionFocusTracker {
    public private(set) var focusStayed = true
    public init() {}

    public mutating func reportedFocus(sameElement: Bool) {
        if !sameElement { invalidate() }
    }

    public mutating func invalidate() { focusStayed = false }
}

public struct FieldSnapshot: Equatable {
    public let processID: Int32
    public let value: String
    public let selection: NSRange
    public let secure: Bool
    public init(processID: Int32, value: String, selection: NSRange, secure: Bool) {
        self.processID = processID
        self.value = value
        self.selection = selection
        self.secure = secure
    }
}

public enum InsertionPolicy {
    public static func permits(original: FieldSnapshot, current: FieldSnapshot,
                               sameElement: Bool, focusStayed: Bool) -> Bool {
        focusStayed && sameElement && !original.secure && !current.secure && original == current
            && validRange(original.selection, in: original.value)
    }

    public static func replacingSelection(in snapshot: FieldSnapshot, with text: String) -> String? {
        guard !snapshot.secure, validRange(snapshot.selection, in: snapshot.value) else { return nil }
        return (snapshot.value as NSString).replacingCharacters(in: snapshot.selection, with: text)
    }

    private static func validRange(_ range: NSRange, in text: String) -> Bool {
        let count = (text as NSString).length
        return range.location != NSNotFound && range.location >= 0 && range.length >= 0
            && range.location <= count && range.length <= count - range.location
    }
}
