// Foundation-only test runner for Macs with Command Line Tools but no XCTest.
import Foundation

private var failures = 0
private var checks = 0
private var cases = 0

func XCTFail(_ message: String, file: StaticString = #filePath, line: UInt = #line) {
    failures += 1
    print("FAIL: \(message) (\(file):\(line))")
}
func XCTAssertTrue(_ value: @autoclosure () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
    checks += 1
    if !value() { XCTFail("Expected true", file: file, line: line) }
}
func XCTAssertFalse(_ value: @autoclosure () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
    checks += 1
    if value() { XCTFail("Expected false", file: file, line: line) }
}
func XCTAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T, file: StaticString = #filePath, line: UInt = #line) {
    checks += 1
    if lhs != rhs { XCTFail("Values were unequal: \(lhs) / \(rhs)", file: file, line: line) }
}
func XCTAssertNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) {
    checks += 1
    if value != nil { XCTFail("Expected nil", file: file, line: line) }
}
func XCTAssertNotNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) {
    checks += 1
    if value == nil { XCTFail("Expected a value", file: file, line: line) }
}
func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line, _ handler: (Error) -> Void) {
    checks += 1
    do { _ = try expression(); XCTFail("Expected an error", file: file, line: line) }
    catch { handler(error) }
}

@main struct CheckRunner {
    static func main() async {
        func run(_ name: String, _ test: () throws -> Void) {
            cases += 1
            let previous = failures
            do { try test() } catch { XCTFail("Unexpected error: \(error)") }
            print("\(previous == failures ? "PASS" : "FAIL") \(name)")
        }
        func runAsync(_ name: String, _ test: () async throws -> Void) async {
            cases += 1
            let previous = failures
            do { try await test() } catch { XCTFail("Unexpected error: \(error)") }
            print("\(previous == failures ? "PASS" : "FAIL") \(name)")
        }
        let session = SessionTests()
        run("recording/submission lifecycle", session.testRecordingSubmissionLifecycle)
        run("overlap and duplicate submission", session.testOverlappingClickAndShortcutCannotStartTwiceOrChangeOwner)
        run("release during microphone permission", session.testReleaseBeforePermissionCompletesCannotStartRecorder)
        run("stale cancelled network result", session.testCancelledNetworkResultCannotFinishNewRecording)
        run("short/silent recording rejection", session.testShortAndSilentRecordingsAreRejected)
        let shortcut = ShortcutTests()
        run("Fn edges and repeats", shortcut.testFunctionKeyEdgesAndRepeatSuppression)
        run("Fn disabled", shortcut.testFunctionCanBeDisabled)
        run("fallback hold/release", shortcut.testFallbackHoldAndRelease)
        run("modifier-first release", shortcut.testReleasingModifierBeforeSpaceStopsFallback)
        run("configured shortcut and extra modifiers", shortcut.testConfigurableShortcutAndExtraModifiers)
        run("Escape and monitor reset", shortcut.testEscapeCancelsAndResetClearsHeldState)
        let insertion = InsertionTests()
        run("unchanged field insertion", insertion.testSameUnchangedFieldPermitsInsertion)
        run("repeated original-field focus reports", insertion.testRepeatedFocusReportsKeepOriginalFieldUsable)
        run("queued focus change and return", insertion.testQueuedFocusChangeCannotBeUndoneByReturn)
        run("focus change and return", insertion.testFocusChangedEvenIfItReturnsToOriginal)
        run("app, value, caret changes", insertion.testChangedAppValueOrCaretRejectsInsertion)
        run("secure field rejection", insertion.testSecureFieldAlwaysRejected)
        run("Unicode text selection", insertion.testUTF16SelectionWithEmoji)
        run("invalid/out-of-bounds selections", insertion.testInvalidSelectionDoesNotCrashOrOverwriteText)
        let richText = RichTextInsertionTests()
        run("rich text marker cursor", richText.testMarkerCursorCanPasteWithoutPlainStringOffsets)
        run("marker cursor and selection movement", richText.testMarkerMovementOrSelectedRangeChangeRejectsPaste)
        run("rich text and app changes", richText.testRichTextContentAndApplicationChangesRejectPaste)
        run("rich text focus return and secure fields", richText.testRichTextFocusReturnAndSecureFieldsStayRejected)
        run("invalid marker data rejection", richText.testEmptyAndOversizedMarkersNeverPermitPaste)
        run("offset cursor without readable full value", richText.testOffsetCursorWithoutValueUsesPasteWithoutFullValueWrite)
        run("plain text Unicode and bounds preserved", richText.testPlainTextStillSupportsUnicodeReplacementAndBounds)
        let transport = InsertionTransportTests()
        run("terminal paste and disabled-paste behavior", transport.testTerminalNeverUsesAccessibilityReplacement)
        run("editor and ordinary-field insertion routing", transport.testEditorPastePreferenceAndOrdinaryFieldCompatibility)
        run("terminal controls and Unicode", transport.testTerminalTextCannotSendReturnOrControlCharacters)
        let credentials = CredentialCacheTests()
        run("one approved credential read per app session", credentials.testRepeatedUseNeedsOnlyOneCredentialRead)
        run("credential denial retry, replacement and removal", credentials.testDeniedReadCanRetryWithoutLosingReplacementOrRemoval)
        let transcription = TranscriptionTests()
        run("multipart request contract", transcription.testMultipartRequestUsesExpectedEndpointAndPreservesAudio)
        run("auto language and model allowlist", transcription.testAutoLanguageOmitsFieldAndUnknownModelUsesAllowlist)
        run("local credential/size/language validation", transcription.testInvalidKeyLanguageAndAudioRejectedLocally)
        await runAsync("successful JSON Unicode response", transcription.testSuccessfulResponseAndUnicode)
        await runAsync("HTTP errors and private response handling", transcription.testAPIErrorStatusMappingWithoutExposingServerBody)
        await runAsync("malformed/empty API responses", transcription.testMalformedAndEmptyResponses)
        await runAsync("pending network cancellation", transcription.testCancellationStopsPendingNetworkRequest)
        print("\(cases) cases, \(checks) assertions, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}
