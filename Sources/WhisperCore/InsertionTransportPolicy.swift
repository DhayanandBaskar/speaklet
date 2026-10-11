import Foundation

public enum InsertionTransport: Equatable {
    case direct, paste, copyOnly
}

public enum InsertionTransportPolicy {
    public static func isTerminal(bundleIdentifier: String?, terminalSurface: Bool) -> Bool {
        terminalSurface || ["com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable"]
            .contains(bundleIdentifier ?? "")
    }

    public static func transport(isTerminal: Bool, isMultiline: Bool, pasteEnabled: Bool) -> InsertionTransport {
        // Terminal accessibility values can represent the screen or a suggestion,
        // rather than the shell's editable input buffer. Never write those values.
        if isTerminal { return pasteEnabled ? .paste : .copyOnly }
        // Custom editors and integrated terminals commonly expose a text area.
        if isMultiline && pasteEnabled { return .paste }
        return .direct
    }

    public static func terminalText(_ text: String) -> String {
        // A pasted Return can execute a command. Keep dictation on one line and
        // remove terminal controls while preserving Unicode, including joiners.
        var result = String.UnicodeScalarView()
        var previousWasControl = false
        for scalar in text.unicodeScalars {
            let value = scalar.value
            let control = value < 0x20 || (0x7f...0x9f).contains(value) || value == 0x2028 || value == 0x2029
            if control {
                if !previousWasControl { result.append(" ") }
            } else { result.append(scalar) }
            previousWasControl = control
        }
        return String(result)
    }
}
