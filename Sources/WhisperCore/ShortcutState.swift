import Foundation

public enum ShortcutEdge: Equatable {
    case functionDown, functionUp, fallbackDown, fallbackUp, cancel
}

/// Key codes and modifier bits are CGEvent's hardware values. This is kept pure
/// so repeat suppression and modifier-release behavior can be tested without TCC.
public struct ShortcutState {
    public static let command: UInt64 = 1 << 20
    public static let shift: UInt64 = 1 << 17
    public static let option: UInt64 = 1 << 19
    public static let control: UInt64 = 1 << 18
    public static let function: UInt64 = 1 << 23
    public static let modifierMask = command | shift | option | control
    public private(set) var functionHeld = false
    public private(set) var fallbackHeld = false
    public var functionEnabled = true
    public var keyCode: UInt16 = 49
    public var modifiers: UInt64 = control | option
    public init() {}

    public mutating func flagsChanged(_ flags: UInt64) -> [ShortcutEdge] {
        var edges: [ShortcutEdge] = []
        let held = functionEnabled && flags & Self.function != 0
        if held != functionHeld {
            functionHeld = held
            edges.append(held ? .functionDown : .functionUp)
        }
        if fallbackHeld && flags & Self.modifierMask != modifiers {
            fallbackHeld = false
            edges.append(.fallbackUp)
        }
        return edges
    }

    public mutating func keyDown(code: UInt16, flags: UInt64, repeating: Bool) -> [ShortcutEdge] {
        if code == 53 { return [.cancel] }
        guard code == keyCode, flags & Self.modifierMask == modifiers,
              !repeating, !fallbackHeld else { return [] }
        fallbackHeld = true
        return [.fallbackDown]
    }

    public mutating func keyUp(code: UInt16) -> [ShortcutEdge] {
        guard code == keyCode, fallbackHeld else { return [] }
        fallbackHeld = false
        return [.fallbackUp]
    }

    public mutating func reset() {
        functionHeld = false
        fallbackHeld = false
    }
}
