import Foundation
import WhisperCore

final class ShortcutTests {
    func testFunctionKeyEdgesAndRepeatSuppression() {
        var state = ShortcutState()
        XCTAssertEqual(state.flagsChanged(ShortcutState.function), [.functionDown])
        XCTAssertEqual(state.flagsChanged(ShortcutState.function), [])
        XCTAssertEqual(state.flagsChanged(0), [.functionUp])
        XCTAssertEqual(state.flagsChanged(0), [])
    }

    func testFunctionCanBeDisabled() {
        var state = ShortcutState()
        state.functionEnabled = false
        XCTAssertEqual(state.flagsChanged(ShortcutState.function), [])
    }

    func testFallbackHoldAndRelease() {
        var state = ShortcutState()
        let flags = ShortcutState.control | ShortcutState.option
        XCTAssertEqual(state.keyDown(code: 49, flags: flags, repeating: false), [.fallbackDown])
        XCTAssertEqual(state.keyDown(code: 49, flags: flags, repeating: true), [])
        XCTAssertEqual(state.keyDown(code: 49, flags: flags, repeating: false), [])
        XCTAssertEqual(state.keyUp(code: 49), [.fallbackUp])
        XCTAssertEqual(state.keyUp(code: 49), [])
    }

    func testReleasingModifierBeforeSpaceStopsFallback() {
        var state = ShortcutState()
        _ = state.keyDown(code: 49, flags: ShortcutState.control | ShortcutState.option, repeating: false)
        XCTAssertEqual(state.flagsChanged(ShortcutState.control), [.fallbackUp])
        XCTAssertEqual(state.keyUp(code: 49), [])
    }

    func testConfigurableShortcutAndExtraModifiers() {
        var state = ShortcutState()
        state.keyCode = 2
        state.modifiers = ShortcutState.command | ShortcutState.shift
        XCTAssertEqual(state.keyDown(code: 49, flags: state.modifiers, repeating: false), [])
        XCTAssertEqual(state.keyDown(code: 2, flags: state.modifiers | ShortcutState.option, repeating: false), [])
        XCTAssertEqual(state.keyDown(code: 2, flags: state.modifiers, repeating: false), [.fallbackDown])
    }

    func testEscapeCancelsAndResetClearsHeldState() {
        var state = ShortcutState()
        _ = state.flagsChanged(ShortcutState.function)
        XCTAssertEqual(state.keyDown(code: 53, flags: 0, repeating: false), [.cancel])
        state.reset()
        XCTAssertEqual(state.flagsChanged(ShortcutState.function), [.functionDown])
    }
}
