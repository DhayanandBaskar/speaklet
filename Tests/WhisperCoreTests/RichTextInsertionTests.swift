import Foundation
import WhisperCore

final class RichTextInsertionTests {
    private let cursor = PasteSelection.markers(start: Data([1, 2, 3]), end: Data([1, 2, 3]))
    private func field(value: String? = nil, selection: PasteSelection? = nil, pid: Int32 = 123,
                       secure: Bool = false) -> PasteFieldSnapshot {
        PasteFieldSnapshot(processID: pid, value: value, selection: selection ?? cursor, secure: secure)
    }
    private func rejection(_ original: PasteFieldSnapshot, _ current: PasteFieldSnapshot,
                           sameElement: Bool = true, focusStayed: Bool = true) -> PasteRejection? {
        InsertionPolicy.pasteRejection(original: original, current: current,
                                      sameElement: sameElement, focusStayed: focusStayed)
    }
    func testMarkerCursorCanPasteWithoutPlainStringOffsets() {
        let original = field(value: "Hello")
        XCTAssertNil(rejection(original, original))
        XCTAssertNil(original.plainTextSnapshot)
        let withoutValue = field()
        XCTAssertNil(rejection(withoutValue, withoutValue))
    }
    func testMarkerMovementOrSelectedRangeChangeRejectsPaste() {
        let original = field()
        let moved = field(selection: .markers(start: Data([1, 2, 4]), end: Data([1, 2, 4])))
        let selected = field(selection: .markers(start: Data([1, 2, 3]), end: Data([1, 2, 5])))
        XCTAssertEqual(rejection(original, moved), .cursorChanged)
        XCTAssertEqual(rejection(original, selected), .cursorChanged)
        XCTAssertEqual(rejection(original, field(selection: .characters(NSRange(location: 0, length: 0)))), .cursorChanged)
    }
    func testRichTextContentAndApplicationChangesRejectPaste() {
        XCTAssertEqual(rejection(field(value: "Hello"), field(value: "Changed")), .textChanged)
        XCTAssertEqual(rejection(field(), field(value: "Now exposed")), .textChanged)
        XCTAssertEqual(rejection(field(), field(pid: 456)), .applicationChanged)
        XCTAssertEqual(rejection(field(), field(), sameElement: false), .focusChanged)
    }
    func testRichTextFocusReturnAndSecureFieldsStayRejected() {
        var focus = InsertionFocusTracker()
        focus.reportedFocus(sameElement: false)
        focus.reportedFocus(sameElement: true)
        XCTAssertEqual(rejection(field(), field(), focusStayed: focus.focusStayed), .focusChanged)
        XCTAssertEqual(rejection(field(secure: true), field(secure: true)), .secureField)
        XCTAssertEqual(rejection(field(), field(secure: true)), .secureField)
    }
    func testEmptyAndOversizedMarkersNeverPermitPaste() {
        for cursor in [PasteSelection.markers(start: Data(), end: Data([1])),
                       .markers(start: Data([1]), end: Data()),
                       .markers(start: Data(repeating: 1, count: 4097), end: Data([1]))] {
            let original = field(selection: cursor)
            XCTAssertEqual(rejection(original, original), .invalidSelection)
        }
    }
    func testOffsetCursorWithoutValueUsesPasteWithoutFullValueWrite() {
        let original = field(selection: .characters(NSRange(location: 42, length: 0)))
        XCTAssertNil(rejection(original, original))
        XCTAssertNil(original.plainTextSnapshot)
        XCTAssertEqual(rejection(original, field(selection: .characters(NSRange(location: 43, length: 0)))), .cursorChanged)
        for range in [NSRange(location: NSNotFound, length: 0), NSRange(location: 1, length: Int.max)] {
            let invalid = field(selection: .characters(range))
            XCTAssertEqual(rejection(invalid, invalid), .invalidSelection)
        }
    }
    func testPlainTextStillSupportsUnicodeReplacementAndBounds() {
        let original = field(value: "👋 hello", selection: .characters(NSRange(location: 3, length: 5)))
        XCTAssertNil(rejection(original, original))
        XCTAssertEqual(InsertionPolicy.replacingSelection(in: original.plainTextSnapshot!, with: "Grüße"), "👋 Grüße")
        let invalid = field(value: "Hi", selection: .characters(NSRange(location: 3, length: 0)))
        XCTAssertEqual(rejection(invalid, invalid), .invalidSelection)
    }
}
