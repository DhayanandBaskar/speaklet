import Foundation

/// Rich text editors can describe a selection using opaque accessibility text
/// markers instead of an offset into a plain string. Compare the marker bytes;
/// never interpret them as text or as character offsets.
public enum PasteSelection: Equatable {
    case characters(NSRange)
    case markers(start: Data, end: Data)

    func valid(in value: String?) -> Bool {
        switch self {
        case .characters(let range):
            guard range.location != NSNotFound, range.location >= 0, range.length >= 0,
                  range.length <= Int.max - range.location else { return false }
            guard let value else { return true }
            let count = (value as NSString).length
            return range.location <= count && range.length <= count - range.location
        case .markers(let start, let end):
            return !start.isEmpty && !end.isEmpty && start.count <= 4096 && end.count <= 4096
        }
    }
}

public struct PasteFieldSnapshot: Equatable {
    public let processID: Int32
    public let value: String?
    public let selection: PasteSelection
    public let secure: Bool
    public init(processID: Int32, value: String?, selection: PasteSelection, secure: Bool) {
        self.processID = processID
        self.value = value
        self.selection = selection
        self.secure = secure
    }
    public var plainTextSnapshot: FieldSnapshot? {
        guard let value, case .characters(let range) = selection else { return nil }
        return FieldSnapshot(processID: processID, value: value, selection: range, secure: secure)
    }
}

public enum PasteRejection: Equatable {
    case focusChanged, secureField, applicationChanged, textChanged, cursorChanged, invalidSelection
    public var message: String {
        switch self {
        case .focusChanged: return "The original text field lost focus."
        case .secureField: return "Automatic insertion is disabled in secure fields."
        case .applicationChanged: return "The app receiving the text changed."
        case .textChanged: return "The text in the original field changed."
        case .cursorChanged: return "The cursor or selected text changed."
        case .invalidSelection: return "The editor returned an invalid cursor position."
        }
    }
}

extension InsertionPolicy {
    public static func pasteRejection(original: PasteFieldSnapshot, current: PasteFieldSnapshot,
                                      sameElement: Bool, focusStayed: Bool) -> PasteRejection? {
        guard focusStayed && sameElement else { return .focusChanged }
        guard !original.secure && !current.secure else { return .secureField }
        guard original.processID == current.processID else { return .applicationChanged }
        guard original.value == current.value else { return .textChanged }
        guard original.selection == current.selection else { return .cursorChanged }
        guard original.selection.valid(in: original.value), current.selection.valid(in: current.value) else {
            return .invalidSelection
        }
        return nil
    }
}
