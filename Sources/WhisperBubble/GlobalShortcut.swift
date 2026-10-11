import AppKit
import ApplicationServices
import WhisperCore

@MainActor final class GlobalShortcut {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var state = ShortcutState()
    var onEdge: ((ShortcutEdge) -> Void)?
    var onUnavailable: (() -> Void)?
    var running: Bool { tap != nil }

    func configure(_ preferences: Preferences) {
        state.functionEnabled = preferences.fnEnabled
        state.keyCode = preferences.fallback.keyCode
        state.modifiers = preferences.fallback.modifiers
        state.reset()
    }

    @discardableResult func start() -> Bool {
        guard tap == nil else { return true }
        guard CGPreflightListenEventAccess() else { return false }
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<GlobalShortcut>.fromOpaque(userInfo).takeUnretainedValue()
            // Keep the tap callback small. Keychain and Accessibility work is
            // dispatched after this callback returns, avoiding tap timeouts.
            MainActor.assumeIsolated { monitor.handle(type: type, event: event) }
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                         options: .listenOnly, eventsOfInterest: CGEventMask(mask),
                                         callback: callback,
                                         userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        state.reset()
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            state.reset()
            onUnavailable?()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let edges: [ShortcutEdge]
        switch type {
        case .flagsChanged: edges = state.flagsChanged(event.flags.rawValue)
        case .keyDown:
            edges = state.keyDown(code: code, flags: event.flags.rawValue,
                                  repeating: event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
        case .keyUp: edges = state.keyUp(code: code)
        default: edges = []
        }
        for edge in edges {
            DispatchQueue.main.async { [weak self] in self?.onEdge?(edge) }
        }
    }
}
