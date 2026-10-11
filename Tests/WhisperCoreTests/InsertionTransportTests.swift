import Foundation
import WhisperCore

final class InsertionTransportTests {
    func testTerminalNeverUsesAccessibilityReplacement() {
        for identifier in ["com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable"] {
            let terminal = InsertionTransportPolicy.isTerminal(bundleIdentifier: identifier, terminalSurface: false)
            XCTAssertTrue(terminal)
            XCTAssertEqual(InsertionTransportPolicy.transport(isTerminal: terminal, isMultiline: false, pasteEnabled: true), .paste)
            XCTAssertEqual(InsertionTransportPolicy.transport(isTerminal: terminal, isMultiline: true, pasteEnabled: false), .copyOnly)
        }
        XCTAssertTrue(InsertionTransportPolicy.isTerminal(bundleIdentifier: "com.microsoft.VSCode", terminalSurface: true))
        XCTAssertFalse(InsertionTransportPolicy.isTerminal(bundleIdentifier: "com.microsoft.VSCode", terminalSurface: false))
    }

    func testEditorPastePreferenceAndOrdinaryFieldCompatibility() {
        XCTAssertEqual(InsertionTransportPolicy.transport(isTerminal: false, isMultiline: true, pasteEnabled: true), .paste)
        XCTAssertEqual(InsertionTransportPolicy.transport(isTerminal: false, isMultiline: true, pasteEnabled: false), .direct)
        XCTAssertEqual(InsertionTransportPolicy.transport(isTerminal: false, isMultiline: false, pasteEnabled: true), .direct)
    }

    func testTerminalTextCannotSendReturnOrControlCharacters() {
        XCTAssertEqual(InsertionTransportPolicy.terminalText("echo hello\r\nnext\tword\u{1b}\u{7f}\u{85}end\u{2028}line\u{2029}"), "echo hello next word end line ")
        XCTAssertEqual(InsertionTransportPolicy.terminalText("echo 'hello world'"), "echo 'hello world'")
        XCTAssertEqual(InsertionTransportPolicy.terminalText("Grüße 👨‍👩‍👧‍👦 café"), "Grüße 👨‍👩‍👧‍👦 café")
    }
}
