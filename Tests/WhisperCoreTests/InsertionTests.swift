import Foundation
import WhisperCore

final class InsertionTests {
    private let original = FieldSnapshot(processID: 123, value: "Hello world", selection: NSRange(location: 6, length: 5), secure: false)

    func testSameUnchangedFieldPermitsInsertion() {
        XCTAssertTrue(InsertionPolicy.permits(original: original, current: original, sameElement: true, focusStayed: true))
        XCTAssertEqual(InsertionPolicy.replacingSelection(in: original, with: "Berlin"), "Hello Berlin")
    }

    func testRepeatedFocusReportsKeepOriginalFieldUsable() {
        var focus = InsertionFocusTracker()
        // Simulate focus announcements during start, recording, and stop.
        for _ in 0..<3 { focus.reportedFocus(sameElement: true) }
        XCTAssertTrue(InsertionPolicy.permits(original: original, current: original,
                                               sameElement: true, focusStayed: focus.focusStayed))
        let movedCaret = FieldSnapshot(processID: original.processID, value: original.value,
                                       selection: NSRange(location: 11, length: 0), secure: false)
        XCTAssertFalse(InsertionPolicy.permits(original: original, current: movedCaret,
                                                sameElement: true, focusStayed: focus.focusStayed))
    }

    func testQueuedFocusChangeCannotBeUndoneByReturn() {
        var focus = InsertionFocusTracker()
        // Focus has returned before the queued notifications are delivered.
        // The notification's reported element must still invalidate insertion.
        focus.reportedFocus(sameElement: false)
        focus.reportedFocus(sameElement: true)
        XCTAssertFalse(InsertionPolicy.permits(original: original, current: original,
                                                sameElement: true, focusStayed: focus.focusStayed))
        var workspaceFocus = InsertionFocusTracker()
        workspaceFocus.invalidate()
        workspaceFocus.reportedFocus(sameElement: true)
        XCTAssertFalse(workspaceFocus.focusStayed)
    }

    func testFocusChangedEvenIfItReturnsToOriginal() {
        XCTAssertFalse(InsertionPolicy.permits(original: original, current: original, sameElement: true, focusStayed: false))
        XCTAssertFalse(InsertionPolicy.permits(original: original, current: original, sameElement: false, focusStayed: true))
    }

    func testChangedAppValueOrCaretRejectsInsertion() {
        let variants = [
            FieldSnapshot(processID: 456, value: original.value, selection: original.selection, secure: false),
            FieldSnapshot(processID: 123, value: "Hello changed", selection: original.selection, secure: false),
            FieldSnapshot(processID: 123, value: original.value, selection: NSRange(location: 11, length: 0), secure: false),
            FieldSnapshot(processID: 123, value: original.value, selection: original.selection, secure: true)
        ]
        for current in variants {
            XCTAssertFalse(InsertionPolicy.permits(original: original, current: current, sameElement: true, focusStayed: true))
        }
    }

    func testSecureFieldAlwaysRejected() {
        let secure = FieldSnapshot(processID: 123, value: "secret", selection: NSRange(location: 6, length: 0), secure: true)
        XCTAssertFalse(InsertionPolicy.permits(original: secure, current: secure, sameElement: true, focusStayed: true))
        XCTAssertNil(InsertionPolicy.replacingSelection(in: secure, with: "words"))
    }

    func testUTF16SelectionWithEmoji() {
        let snapshot = FieldSnapshot(processID: 123, value: "👋 hello", selection: NSRange(location: 3, length: 5), secure: false)
        XCTAssertEqual(InsertionPolicy.replacingSelection(in: snapshot, with: "Grüße"), "👋 Grüße")
    }

    func testInvalidSelectionDoesNotCrashOrOverwriteText() {
        for range in [NSRange(location: NSNotFound, length: 0), NSRange(location: 10, length: Int.max), NSRange(location: 30, length: 0)] {
            let snapshot = FieldSnapshot(processID: 123, value: "Hi", selection: range, secure: false)
            XCTAssertNil(InsertionPolicy.replacingSelection(in: snapshot, with: "words"))
            XCTAssertFalse(InsertionPolicy.permits(original: snapshot, current: snapshot, sameElement: true, focusStayed: true))
        }
    }
}
