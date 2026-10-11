import AppKit
import AVFoundation
import ApplicationServices
import Combine
import SwiftUI
import WhisperCore

@MainActor final class AppController: NSObject, ObservableObject {
    let preferences = Preferences()
    @Published private(set) var phase: SessionPhase = .idle
    @Published private(set) var bars: [Float] = Array(repeating: 0.05, count: 14)
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var notice = ""
    @Published private(set) var noticeIsError = false
    @Published private(set) var lastTranscript = ""
    @Published private(set) var transcriptNotice = ""
    @Published private(set) var transcriptNeedsInsertionHelp = false
    @Published private(set) var keySaved = false
    @Published private(set) var keychainNotice = ""
    @Published private(set) var microphoneGranted = false
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var keyboardGranted = false
    @Published private(set) var shortcutRunning = false

    private var machine = SessionMachine()
    private let audio = AudioCapture()
    private let shortcut = GlobalShortcut()
    private let client = TranscriptionClient()
    private var requestTask: Task<Void, Never>?
    private var target: TextInsertion.Target?
    private var focusTimer: Timer?
    private var permissionTimer: Timer?
    private var clipboardOnlyReason = ""
    private var settingsWindow: NSWindow?
    private var transcriptWindow: NSWindow?
    private var subscriptions = Set<AnyCancellable>()
    private var workspaceObserver: NSObjectProtocol?
    private var bubble: BubblePanel?
    private var statusItem: NSStatusItem?

    func start() {
        refreshPermissions()
        refreshKey()
        bubble = BubblePanel(controller: self)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Whisper Bubble")
        statusItem?.button?.toolTip = "Whisper Bubble"
        statusItem?.button?.target = self
        statusItem?.button?.action = #selector(showMenu)
        audio.onMeter = { [weak self] level, elapsed in
            guard let self else { return }
            self.bars.removeFirst()
            self.bars.append(max(0.04, level))
            self.elapsed = elapsed
        }
        audio.onLimit = { [weak self] in self?.stopAndSubmit() }
        audio.onError = { [weak self] in
            self?.cancel()
            self?.setNotice("The microphone was interrupted. Check your input device and try again.", error: true)
        }
        shortcut.onEdge = { [weak self] in self?.handle($0) }
        shortcut.onUnavailable = { [weak self] in
            guard let self, self.phase == .recording || self.phase == .preparing else { return }
            self.cancel()
            self.setNotice("Keyboard monitoring was interrupted. Recording cancelled.", error: true)
        }
        preferences.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.preferencesChanged() }
        }.store(in: &subscriptions)
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self, let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                if app.processIdentifier != self.target?.snapshot.processID { self.target?.invalidate() }
                TextInsertion.prepareFocusedApplication()
            }
        }
        preferencesChanged()
        let permissionTimer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshPermissions() }
        }
        self.permissionTimer = permissionTimer
        RunLoop.main.add(permissionTimer, forMode: .common)
        if !UserDefaults.standard.bool(forKey: "welcomeShown") {
            UserDefaults.standard.set(true, forKey: "welcomeShown")
            showSettings()
        }
    }

    func shutdown() {
        cancel()
        KeychainStore.clearCache()
        permissionTimer?.invalidate()
        shortcut.stop()
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
    }

    private func syncPhase() { phase = machine.phase }
    private func preferencesChanged() {
        // A shortcut change is only available in our settings, which also cancels
        // any active session before the window gains focus.
        shortcut.configure(preferences)
        shortcutRunning = shortcut.start()
        bubble?.updatePosition(location: preferences.location)
        if preferences.bubbleVisible { bubble?.orderFrontRegardless() } else { bubble?.orderOut(nil) }
    }

    func bubbleClicked() {
        switch phase {
        case .idle: begin(.bubble)
        case .preparing: cancel()
        case .recording: stopAndSubmit()
        case .transcribing: break
        }
    }

    func testTextInsertion() {
        guard phase == .idle else { return }
        target = nil
        switch TextInsertion.capture() {
        case .target(let captured): target = captured
        case .copyOnly(let reason):
            setNotice(reason, error: true)
            bubble?.showFeedback()
            return
        case .secure:
            setNotice("Text insertion is disabled in secure fields.", error: true)
            bubble?.showFeedback()
            return
        }
        guard let id = machine.begin(.bubble) else { return }
        notice = ""
        noticeIsError = false
        syncPhase()
        startFocusChecks()
        requestTask = Task { [weak self] in
            // Exercise the same focus tracking and insertion path after the
            // menu closes. No microphone permission, audio, key, or API call.
            do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
            guard let self, self.machine.sessionID == id, !Task.isCancelled else { return }
            self.requestTask = nil
            self.completeInsertion("Whisper Bubble test.", sessionID: id)
        }
    }

    private func handle(_ edge: ShortcutEdge) {
        switch edge {
        case .functionDown:
            if NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier { begin(.functionKey) }
        case .fallbackDown:
            if NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier { begin(.shortcut) }
        case .functionUp: release(.functionKey)
        case .fallbackUp: release(.shortcut)
        case .cancel: if phase != .idle { cancel() }
        }
    }

    private func release(_ trigger: RecordingTrigger) {
        guard machine.owns(trigger) else { return }
        if phase == .preparing { cancel() }
        else if phase == .recording { stopAndSubmit() }
    }

    private func begin(_ trigger: RecordingTrigger) {
        guard phase == .idle else { return }
        do {
            guard let key = try KeychainStore.read(), !key.isEmpty else {
                setNotice(TranscriptionError.missingKey.localizedDescription, error: true)
                return
            }
        } catch { setNotice(error.localizedDescription, error: true); return }
        let options = TranscriptionOptions(model: preferences.model, language: preferences.language)
        // Validate settings before engaging the microphone, without making a request.
        do { _ = try TranscriptionClient.request(audio: Data([0]), apiKey: "local-validation", options: options) }
        catch { setNotice(error.localizedDescription, error: true); return }
        target = nil
        clipboardOnlyReason = "Automatic insertion is disabled. Transcript ready to copy."
        if preferences.automaticInsertion {
            switch TextInsertion.capture() {
            case .target(let captured): target = captured
            case .copyOnly(let reason): clipboardOnlyReason = reason
            case .secure:
                setNotice("Dictation is disabled in secure fields. Focus a regular text field first.", error: true)
                return
            }
        }
        guard let id = machine.begin(trigger) else { return }
        notice = ""
        noticeIsError = false
        elapsed = 0
        bars = Array(repeating: 0.04, count: 14)
        syncPhase()
        startFocusChecks()
        requestTask = Task { [weak self] in
            let granted = await AudioCapture.requestPermission()
            guard let self, self.machine.sessionID == id, self.phase == .preparing else { return }
            self.requestTask = nil
            self.refreshPermissions()
            guard granted else {
                self.fail(id, "Microphone access is required. Enable Whisper Bubble in macOS Privacy & Security → Microphone.")
                return
            }
            do {
                try self.audio.start()
                guard self.machine.recordingBegan(id) else { self.audio.cancel(); return }
                self.syncPhase()
            } catch {
                self.audio.cancel()
                self.fail(id, "The microphone could not start. Check your input device in macOS Sound settings.")
            }
        }
    }

    private func stopAndSubmit() {
        guard let id = machine.submit() else { return }
        syncPhase()
        guard let recording = audio.stop() else { fail(id, "No audio was recorded. Try again."); return }
        if let problem = AudioValidation.problem(duration: recording.duration, peakDB: recording.peakDB) {
            audio.cleanup()
            fail(id, problem)
            return
        }
        let audioData: Data
        let apiKey: String
        do {
            audioData = try Data(contentsOf: recording.url)
            apiKey = try KeychainStore.read() ?? ""
        } catch {
            audio.cleanup()
            fail(id, "The recording or API key could not be read. Check Settings and try again.")
            return
        }
        audio.cleanup()
        let options = TranscriptionOptions(model: preferences.model, language: preferences.language)
        requestTask = Task { [weak self, client] in
            do {
                let text = try await client.transcribe(audio: audioData, apiKey: apiKey, options: options)
                guard let self, self.machine.sessionID == id, !Task.isCancelled else { return }
                self.requestTask = nil
                self.completeInsertion(text, sessionID: id)
            } catch {
                guard let self, self.machine.sessionID == id else { return }
                self.requestTask = nil
                if Task.isCancelled || (error as? URLError)?.code == .cancelled { self.cancel(); return }
                let message: String
                if let error = error as? TranscriptionError { message = error.localizedDescription }
                else if let error = error as? URLError {
                    message = error.code == .timedOut ? "The request timed out. Check your connection and try again." : "Could not reach OpenAI. Check your internet connection and try again."
                } else { message = "Transcription failed. Check Settings and try again." }
                self.fail(id, message)
            }
        }
    }

    private func completeInsertion(_ text: String, sessionID: UUID) {
        guard machine.sessionID == sessionID else { return }
        lastTranscript = text
        let result = TextInsertion.insert(text, target: target, pasteFallback: preferences.pasteFallback)
        machine.finish(sessionID)
        syncPhase()
        stopFocusChecks()
        transcriptNeedsInsertionHelp = false
        switch result {
        case .inserted:
            transcriptNotice = "Inserted into the original text field."
            setNotice("Inserted", error: false)
        case .pasteSent:
            transcriptNotice = "Paste sent to the original text field."
            setNotice("Paste sent · transcript available in menu", error: false)
        case .copyOnly(let reason):
            transcriptNotice = target == nil ? clipboardOnlyReason : reason
            transcriptNeedsInsertionHelp = true
            setNotice(transcriptNotice, error: false)
            showTranscript()
        }
        target = nil
    }

    private func startFocusChecks() {
        focusTimer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.target?.checkFocus() }
        }
        focusTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    private func stopFocusChecks() { focusTimer?.invalidate(); focusTimer = nil; target?.stopObserving() }
    private func fail(_ id: UUID, _ message: String) {
        guard machine.finish(id) else { return }
        audio.cancel()
        stopFocusChecks()
        target = nil
        syncPhase()
        setNotice(message, error: true)
    }

    func cancel() {
        requestTask?.cancel()
        requestTask = nil
        audio.cancel()
        machine.cancel()
        stopFocusChecks()
        target = nil
        syncPhase()
        setNotice("Cancelled", error: false)
    }

    func dismissNotice() { notice = ""; noticeIsError = false }
    func showBubbleFeedback() { bubble?.showFeedback() }
    private func setNotice(_ message: String, error: Bool) {
        notice = message
        noticeIsError = error
        statusItem?.button?.toolTip = "Whisper Bubble · " + message
        if !error {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                if self?.notice == message { self?.dismissNotice() }
            }
        }
    }

    func refreshPermissions() {
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        accessibilityGranted = AXIsProcessTrusted()
        if accessibilityGranted { TextInsertion.prepareFocusedApplication() }
        keyboardGranted = CGPreflightListenEventAccess()
        if keyboardGranted { shortcutRunning = shortcut.start() }
        else {
            shortcut.stop()
            shortcutRunning = false
            if phase == .recording || phase == .preparing { cancel() }
        }
    }

    func requestMicrophone() {
        Task {
            _ = await AudioCapture.requestPermission()
            refreshPermissions()
            if !microphoneGranted { openPrivacy("Microphone") }
        }
    }
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openPrivacy("Accessibility")
    }
    func requestKeyboard() { _ = CGRequestListenEventAccess(); openPrivacy("ListenEvent") }
    func openPrivacy(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_" + pane) { NSWorkspace.shared.open(url) }
    }

    func refreshKey() {
        do { keySaved = try KeychainStore.isSaved(); keychainNotice = "" }
        catch { keySaved = false; keychainNotice = error.localizedDescription }
    }
    func saveKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { keychainNotice = "Enter a key to save it."; return false }
        do {
            _ = try TranscriptionClient.request(audio: Data([0]), apiKey: trimmed, options: TranscriptionOptions())
            try KeychainStore.save(trimmed)
            keySaved = true
            keychainNotice = "Saved securely in macOS Keychain."
            return true
        } catch { keychainNotice = error.localizedDescription; return false }
    }
    func removeKey() {
        do { try KeychainStore.delete(); keySaved = false; keychainNotice = "API key removed." }
        catch { keychainNotice = error.localizedDescription }
    }

    func showSettings() {
        if phase != .idle { cancel() }
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 570, height: 660),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Whisper Bubble Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(controller: self, preferences: preferences))
            window.center()
            settingsWindow = window
        }
        refreshPermissions()
        refreshKey()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func showTranscript() {
        guard !lastTranscript.isEmpty else { return }
        if transcriptWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 330),
                                  styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Latest Transcript"
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 380, height: 220)
            window.contentView = NSHostingView(rootView: TranscriptView(controller: self))
            window.center()
            transcriptWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        transcriptWindow?.makeKeyAndOrderFront(nil)
    }

    func copyTranscript() {
        guard !lastTranscript.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastTranscript, forType: .string)
    }
    func clearTranscript() {
        lastTranscript = ""
        transcriptNotice = ""
        transcriptNeedsInsertionHelp = false
        transcriptWindow?.close()
    }

    @objc private func showMenu() {
        let menu = NSMenu()
        func item(_ title: String, _ action: Selector?, enabled: Bool = true, key: String = "") {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = self
            item.isEnabled = enabled
            menu.addItem(item)
        }
        menu.autoenablesItems = false
        item("Whisper Bubble", nil, enabled: false)
        if !notice.isEmpty { item(String(notice.prefix(80)), nil, enabled: false) }
        if !notice.isEmpty { item("Dictation Status…", #selector(feedbackFromMenu)) }
        menu.addItem(.separator())
        item(phase == .recording ? "Stop & Transcribe" : "Start Dictation", #selector(toggleFromMenu), enabled: phase == .idle || phase == .recording)
        if phase != .idle { item("Cancel Dictation", #selector(cancelFromMenu)) }
        item("Latest Transcript…", #selector(transcriptFromMenu), enabled: !lastTranscript.isEmpty)
        item("Copy Latest Transcript", #selector(copyFromMenu), enabled: !lastTranscript.isEmpty)
        menu.addItem(.separator())
        item(preferences.bubbleVisible ? "Hide Bubble" : "Show Bubble", #selector(toggleBubble))
        item("Settings…", #selector(settingsFromMenu), key: ",")
        menu.addItem(.separator())
        item("Quit Whisper Bubble", #selector(quit), key: "q")
        if let button = statusItem?.button { menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button) }
    }
    @objc private func toggleFromMenu() { bubbleClicked() }
    @objc private func cancelFromMenu() { cancel() }
    @objc private func settingsFromMenu() { showSettings() }
    @objc private func transcriptFromMenu() { showTranscript() }
    @objc private func feedbackFromMenu() { showBubbleFeedback() }
    @objc private func copyFromMenu() { copyTranscript() }
    @objc private func toggleBubble() { preferences.bubbleVisible.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }
}
