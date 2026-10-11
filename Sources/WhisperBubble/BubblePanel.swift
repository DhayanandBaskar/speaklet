import AppKit
import SwiftUI
import WhisperCore
import WhisperMacSupport

@MainActor final class BubblePanel: NSPanel {
    private weak var controller: AppController?
    private var screenObserver: NSObjectProtocol?
    private var location: BubbleLocation = .bottomCenter
    private let feedback = NSPopover()
    private static let panelSize = NSSize(width: 96, height: 50)

    init(controller: AppController) {
        self.controller = controller
        super.init(contentRect: NSRect(origin: .zero, size: Self.panelSize),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        contentView = NSHostingView(rootView: BubbleView(controller: controller, preferences: controller.preferences))
        feedback.behavior = .transient
        feedback.contentSize = NSSize(width: 280, height: 124)
        feedback.contentViewController = NSHostingController(rootView: BubbleFeedbackView(controller: controller))
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.updatePosition(location: self.location)
            }
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func showFeedback() {
        guard let contentView, controller?.notice.isEmpty == false else { return }
        feedback.show(relativeTo: contentView.bounds.insetBy(dx: 12, dy: 12),
                      of: contentView, preferredEdge: location == .topLeft || location == .topRight ? .minY : .maxY)
    }

    func updatePosition(location: BubbleLocation) {
        self.location = location
        guard let screen = NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let size = Self.panelSize
        let margin: CGFloat = 8
        let x: CGFloat
        let y: CGFloat
        switch location {
        case .bottomCenter: x = visible.midX - size.width / 2; y = visible.minY + margin
        case .bottomLeft: x = visible.minX + margin; y = visible.minY + margin
        case .bottomRight: x = visible.maxX - size.width - margin; y = visible.minY + margin
        case .topLeft: x = visible.minX + margin; y = visible.maxY - size.height - margin
        case .topRight: x = visible.maxX - size.width - margin; y = visible.maxY - size.height - margin
        }
        let newFrame = NSRect(origin: NSPoint(x: x, y: y), size: size)
        if frame != newFrame { setFrame(newFrame, display: true) }
    }
}

struct BubbleView: View {
    @ObservedObject var controller: AppController
    @ObservedObject var preferences: Preferences

    var body: some View {
        DictationPill(state: state, levels: controller.bars, opacity: preferences.bubbleOpacity,
                      action: controller.bubbleClicked, cancel: controller.cancel)
            .help(help)
            .contextMenu {
                Button("Test Text Insertion", action: controller.testTextInsertion)
                    .disabled(controller.phase != .idle || !preferences.automaticInsertion)
                Divider()
                if !controller.notice.isEmpty {
                    Button("Dictation status…", action: controller.showBubbleFeedback)
                    if controller.noticeIsError { Button("Dismiss error", action: controller.dismissNotice) }
                    Divider()
                }
                Button("Settings…", action: controller.showSettings)
                Button("Latest Transcript…", action: controller.showTranscript).disabled(controller.lastTranscript.isEmpty)
                Button("Hide Bubble") { preferences.bubbleVisible = false }
                Button("Quit Whisper Bubble") { NSApp.terminate(nil) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var state: PillState {
        switch controller.phase {
        case .preparing: return .preparing
        case .recording: return .recording
        case .transcribing: return .transcribing
        case .idle:
            if controller.noticeIsError && !controller.notice.isEmpty { return .error }
            if controller.notice == "Inserted" { return .success }
            if !controller.notice.isEmpty && controller.notice != "Cancelled" { return .ready }
            return .idle
        }
    }

    private var help: String {
        if controller.phase == .recording {
            return String(format: "Recording %02d:%02d · click to stop · Esc to cancel", Int(controller.elapsed) / 60, Int(controller.elapsed) % 60)
        }
        if controller.phase == .transcribing { return "Transcribing · Esc to cancel" }
        if controller.phase == .preparing { return "Starting microphone · Esc to cancel" }
        return controller.notice.isEmpty ? "Click to dictate · hold Fn / Globe · right-click for settings" : controller.notice
    }
}

private struct BubbleFeedbackView: View {
    @ObservedObject var controller: AppController
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(controller.noticeIsError ? "Dictation needs attention" : "Dictation status",
                  systemImage: controller.noticeIsError ? "exclamationmark.circle" : "waveform")
                .font(.system(size: 12, weight: .semibold))
            Text(controller.notice).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Settings…", action: controller.showSettings).buttonStyle(.link)
                Spacer()
                Button("Dismiss", action: controller.dismissNotice).buttonStyle(.link)
            }.font(.system(size: 11))
        }.padding(16).frame(width: 280)
    }
}
