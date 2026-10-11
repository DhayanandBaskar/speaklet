import AppKit
import ApplicationServices
import WhisperCore
import WhisperMacSupport

@MainActor enum TextInsertion {
    enum Capture {
        case target(Target), copyOnly(String), secure
    }
    enum Result { case inserted, pasteSent, copyOnly(String) }

    @MainActor final class Target {
        let element: AXUIElement
        let snapshot: PasteFieldSnapshot
        private(set) var invalidReason = "The original text field lost focus."
        private var focus = InsertionFocusTracker()
        var focusStayed: Bool { focus.focusStayed }
        private var observer: AXObserver?

        init(element: AXUIElement, snapshot: PasteFieldSnapshot) {
            self.element = element
            self.snapshot = snapshot
            var observer: AXObserver?
            let callback: AXObserverCallback = { _, reportedElement, notification, context in
                guard let context else { return }
                let target = Unmanaged<Target>.fromOpaque(context).takeUnretainedValue()
                MainActor.assumeIsolated {
                    if notification as String == kAXFocusedUIElementChangedNotification {
                        // This notification carries the newly focused element.
                        // Some apps announce the same field more than once.
                        // A report of any other element remains irreversible,
                        // even if focus has already returned by callback time.
                        target.focus.reportedFocus(sameElement: CFEqual(target.element, TextInsertion.editableElement(reportedElement)))
                        target.checkFocus()
                    } else if notification as String == kAXValueChangedNotification && target.snapshot.value == nil {
                        // No readable baseline text: a content-change report
                        // cannot be verified by comparing snapshots.
                        target.invalidate("The text in the original field changed.")
                    } else { target.checkFocus() }
                }
            }
            if AXObserverCreate(snapshot.processID, callback, &observer) == .success, let observer {
                self.observer = observer
                let context = Unmanaged.passUnretained(self).toOpaque()
                AXObserverAddNotification(observer, AXUIElementCreateApplication(snapshot.processID),
                                          kAXFocusedUIElementChangedNotification as CFString, context)
                AXObserverAddNotification(observer, element, kAXSelectedTextChangedNotification as CFString, context)
                AXObserverAddNotification(observer, element, kAXValueChangedNotification as CFString, context)
                CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
            }
        }

        func invalidate(_ reason: String = "The original text field lost focus.") {
            if focusStayed { invalidReason = reason }
            focus.invalidate()
        }
        func checkFocus() {
            guard focusStayed else { return }
            guard let current = TextInsertion.focusedElement() else {
                invalidate("The editor's focused text field could no longer be read.")
                return
            }
            do {
                let currentSnapshot = try TextInsertion.snapshot(current)
                if let rejection = InsertionPolicy.pasteRejection(original: snapshot, current: currentSnapshot,
                                                                  sameElement: CFEqual(element, current), focusStayed: focusStayed) {
                    invalidate(rejection.message)
                }
            } catch let problem as InspectionError {
                invalidate(problem.message)
            } catch {
                invalidate("The editor's cursor could no longer be read.")
            }
        }

        func stopObserving() {
            if let observer {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
            }
            observer = nil
        }

        deinit {
            if let observer {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
            }
        }
    }

    static func capture() -> Capture {
        guard AXIsProcessTrusted() else { return .copyOnly("Enable Accessibility in Settings to insert into other apps.") }
        prepareFocusedApplication()
        guard let element = focusedElement() else { return .copyOnly("No editable text field was focused. Your transcript will be ready to copy.") }
        if isSecure(element) { return .secure }
        do {
            let snapshot = try snapshot(element)
            if let rejection = InsertionPolicy.pasteRejection(original: snapshot, current: snapshot, sameElement: true, focusStayed: true) {
                return .copyOnly(rejection.message + " Your transcript will be ready to copy.")
            }
            return .target(Target(element: element, snapshot: snapshot))
        } catch let problem as InspectionError {
            return .copyOnly(problem.message + " Your transcript will be ready to copy.")
        } catch {
            return .copyOnly("The editor's cursor could not be read. Your transcript will be ready to copy.")
        }
    }

    static func insert(_ text: String, target: Target?, pasteFallback: Bool) -> Result {
        guard let target else { return .copyOnly("Transcript ready to copy. No supported text field was captured.") }
        target.checkFocus()
        guard target.focusStayed else {
            return .copyOnly(target.invalidReason + " Your transcript is ready to copy.")
        }
        // Stop observers before our own write; they are no longer needed after
        // the final identity, role, text, and caret checks below.
        target.stopObserving()
        guard let current = focusedElement(), let currentSnapshot = try? snapshot(current),
              InsertionPolicy.pasteRejection(original: target.snapshot, current: currentSnapshot,
                                            sameElement: CFEqual(target.element, current), focusStayed: target.focusStayed) == nil else {
            return .copyOnly("The focused field changed. Your transcript is ready to copy.")
        }
        let application = NSRunningApplication(processIdentifier: target.snapshot.processID)
        let terminal = InsertionTransportPolicy.isTerminal(bundleIdentifier: application?.bundleIdentifier,
                                                           terminalSurface: isTerminalSurface(target.element))
        let transport = InsertionTransportPolicy.transport(isTerminal: terminal,
            isMultiline: attribute(target.element, kAXRoleAttribute) as? String == kAXTextAreaRole,
            pasteEnabled: pasteFallback)
        if transport == .copyOnly {
            return .copyOnly("Terminal insertion requires clipboard paste. Enable it in Settings or copy the transcript.")
        }
        if transport == .direct, isSettable(target.element, kAXSelectedTextAttribute),
           AXUIElementSetAttributeValue(target.element, kAXSelectedTextAttribute as CFString, text as CFString) == .success {
            moveCaretAfterInsertion(text, snapshot: target.snapshot, element: target.element)
            return .inserted
        }
        if transport == .direct, isSettable(target.element, kAXValueAttribute),
           let plainSnapshot = target.snapshot.plainTextSnapshot,
           let value = InsertionPolicy.replacingSelection(in: plainSnapshot, with: text),
           AXUIElementSetAttributeValue(target.element, kAXValueAttribute as CFString, value as CFString) == .success {
            moveCaretAfterInsertion(text, snapshot: target.snapshot, element: target.element)
            return .inserted
        }
        guard pasteFallback else { return .copyOnly("This app requires paste insertion. Enable it in Settings or copy the transcript.") }
        target.checkFocus()
        guard target.focusStayed, AXIsProcessTrusted(),
              let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return .copyOnly("Automatic insertion was unavailable. Your transcript is ready to copy.")
        }
        let lease = ClipboardLease(text: terminal ? InsertionTransportPolicy.terminalText(text) : text)
        // Recheck after copying clipboard data, which can invoke slow providers.
        target.checkFocus()
        guard target.focusStayed else {
            lease.restoreIfUnchanged()
            return .copyOnly("The focused field changed. Your transcript is ready to copy.")
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Never overwrite something the user copied in the meantime.
            lease.restoreIfUnchanged()
        }
        return .pasteSent
    }

    private static func moveCaretAfterInsertion(_ text: String, snapshot: PasteFieldSnapshot, element: AXUIElement) {
        guard case let .characters(selection) = snapshot.selection,
              isSettable(element, kAXSelectedTextRangeAttribute) else { return }
        let (location, overflow) = selection.location.addingReportingOverflow((text as NSString).length)
        guard !overflow else { return }
        var caret = CFRange(location: location, length: 0)
        if let range = AXValueCreate(.cfRange, &caret) {
            AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, range)
        }
    }

    private static func isTerminalSurface(_ element: AXUIElement) -> Bool {
        var current = element
        for _ in 0..<8 {
            // Semantic accessibility labels can identify an integrated terminal
            // without treating the entire editor application as a terminal.
            for name in [kAXIdentifierAttribute, kAXRoleDescriptionAttribute, kAXDescriptionAttribute] {
                if let label = attribute(current, name) as? String,
                   label.lowercased().split(whereSeparator: { !$0.isLetter }).contains("terminal") { return true }
            }
            guard let parent = elementAttribute(current, kAXParentAttribute),
                  attribute(parent, kAXRoleAttribute) as? String != kAXWindowRole else { break }
            current = parent
        }
        return false
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
        return result
    }

    private static func focusedElement() -> AXUIElement? {
        // Application-level focus is useful for web editors whose system-wide
        // focus object is a container rather than their editable text element.
        var applicationCandidate: AXUIElement?
        if let app = NSWorkspace.shared.frontmostApplication {
            let application = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(application, 0.25)
            if let focused = elementAttribute(application, kAXFocusedUIElementAttribute) {
                AXUIElementSetMessagingTimeout(focused, 0.25)
                let candidate = editableElement(focused)
                if isSecure(candidate) || editableRoles.contains(attribute(candidate, kAXRoleAttribute) as? String ?? "") { return candidate }
                applicationCandidate = candidate
            }
        }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.25)
        guard let result = attribute(system, kAXFocusedUIElementAttribute),
              CFGetTypeID(result) == AXUIElementGetTypeID() else { return applicationCandidate }
        let element = result as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.25)
        return editableElement(element)
    }

    private static let editableRoles = [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole]
    private static var preparedApplications = Set<pid_t>()

    static func prepareFocusedApplication() {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              !preparedApplications.contains(app.processIdentifier) else { return }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.25)
        // Electron documents this attribute for third-party assistive apps.
        // Other apps simply report unsupported. No system setting is changed.
        AXUIElementSetAttributeValue(application, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        preparedApplications.insert(app.processIdentifier)
    }

    private static func elementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let result = attribute(element, name), CFGetTypeID(result) == AXUIElementGetTypeID() else { return nil }
        return (result as! AXUIElement)
    }

    private static func editableElement(_ element: AXUIElement) -> AXUIElement {
        if isSecure(element) { return element }
        if let role = attribute(element, kAXRoleAttribute) as? String, editableRoles.contains(role) { return element }
        if let ancestor = elementAttribute(element, kAXEditableAncestorAttribute),
           let role = attribute(ancestor, kAXRoleAttribute) as? String, editableRoles.contains(role) { return ancestor }
        // A web editor can focus a child of its text area. Only walk upward;
        // never pick another text field elsewhere in a window or web page.
        var node = element
        for _ in 0..<8 {
            guard let parent = elementAttribute(node, kAXParentAttribute) else { break }
            if let role = attribute(parent, kAXRoleAttribute) as? String {
                if editableRoles.contains(role) { return parent }
                if role == kAXWindowRole || role == kAXApplicationRole { break }
            }
            node = parent
        }
        return element
    }

    private static func isSecure(_ element: AXUIElement) -> Bool {
        var current: AXUIElement? = element
        for _ in 0..<8 {
            guard let node = current else { break }
            if attribute(node, kAXSubroleAttribute) as? String == kAXSecureTextFieldSubrole { return true }
            if attribute(node, "AXProtectedContent") as? Bool == true { return true }
            guard let parent = attribute(node, kAXParentAttribute),
                  CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
            current = (parent as! AXUIElement)
        }
        return false
    }

    private enum InspectionError: Error {
        case notEditable, secure, disabled, ownApp, switchedApp, cursorUnavailable
        var message: String {
            switch self {
            case .notEditable: return "The focused item is not an editable text field."
            case .secure: return "Automatic insertion is disabled in secure fields."
            case .disabled: return "The original text field is disabled."
            case .ownApp: return "Focus the text box where you want to write, then start dictation."
            case .switchedApp: return "The app receiving the text changed."
            case .cursorUnavailable: return "This editor does not expose a readable cursor or text selection."
            }
        }
    }

    private static func snapshot(_ element: AXUIElement) throws -> PasteFieldSnapshot {
        guard let role = attribute(element, kAXRoleAttribute) as? String, editableRoles.contains(role) else { throw InspectionError.notEditable }
        guard !isSecure(element) else { throw InspectionError.secure }
        guard attribute(element, kAXEnabledAttribute) as? Bool != false else { throw InspectionError.disabled }
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { throw InspectionError.switchedApp }
        guard pid != ProcessInfo.processInfo.processIdentifier else { throw InspectionError.ownApp }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { throw InspectionError.switchedApp }
        guard let selection = AccessibilitySelection.decode(characterRange: attribute(element, kAXSelectedTextRangeAttribute),
                                                             markerRange: attribute(element, "AXSelectedTextMarkerRange")) else {
            throw InspectionError.cursorUnavailable
        }
        return PasteFieldSnapshot(processID: pid, value: attribute(element, kAXValueAttribute) as? String,
                                  selection: selection, secure: false)
    }

    private static func isSettable(_ element: AXUIElement, _ name: String) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, name as CFString, &settable) == .success && settable.boolValue
    }
}
