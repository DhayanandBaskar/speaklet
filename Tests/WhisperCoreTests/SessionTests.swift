import Foundation
import WhisperCore

final class SessionTests {
    func testRecordingSubmissionLifecycle() {
        var machine = SessionMachine()
        let id = machine.begin(.functionKey)!
        XCTAssertEqual(machine.phase, .preparing)
        XCTAssertTrue(machine.owns(.functionKey))
        XCTAssertTrue(machine.recordingBegan(id))
        XCTAssertEqual(machine.phase, .recording)
        XCTAssertEqual(machine.submit(), id)
        XCTAssertEqual(machine.phase, .transcribing)
        XCTAssertTrue(machine.finish(id))
        XCTAssertEqual(machine.phase, .idle)
        XCTAssertNil(machine.sessionID)
    }

    func testOverlappingClickAndShortcutCannotStartTwiceOrChangeOwner() {
        var machine = SessionMachine()
        let id = machine.begin(.bubble)!
        XCTAssertNil(machine.begin(.functionKey))
        XCTAssertNil(machine.begin(.shortcut))
        XCTAssertTrue(machine.owns(.bubble))
        XCTAssertTrue(machine.recordingBegan(id))
        XCTAssertEqual(machine.submit(), id)
        XCTAssertNil(machine.submit())
        XCTAssertNil(machine.begin(.bubble))
    }

    func testReleaseBeforePermissionCompletesCannotStartRecorder() {
        var machine = SessionMachine()
        let old = machine.begin(.functionKey)!
        machine.cancel()
        XCTAssertFalse(machine.recordingBegan(old))
        XCTAssertEqual(machine.phase, .idle)
    }

    func testCancelledNetworkResultCannotFinishNewRecording() {
        var machine = SessionMachine()
        let old = machine.begin(.bubble)!
        XCTAssertTrue(machine.recordingBegan(old))
        XCTAssertEqual(machine.submit(), old)
        machine.cancel()
        let new = machine.begin(.shortcut)!
        XCTAssertFalse(machine.finish(old))
        XCTAssertEqual(machine.sessionID, new)
        XCTAssertEqual(machine.phase, .preparing)
    }

    func testShortAndSilentRecordingsAreRejected() {
        XCTAssertNotNil(AudioValidation.problem(duration: 0.15, peakDB: -10))
        XCTAssertNotNil(AudioValidation.problem(duration: 2, peakDB: -100))
        XCTAssertNotNil(AudioValidation.problem(duration: 2, peakDB: .nan))
        XCTAssertNil(AudioValidation.problem(duration: 2, peakDB: -35))
    }
}
