import AppKit
import SwiftUI

public enum PillState: Equatable {
    case idle, preparing, recording, transcribing, success, ready, error
    var busy: Bool { self == .preparing || self == .recording || self == .transcribing }
}

public struct DictationPill: View {
    public static let maximumSize = NSSize(width: 88, height: 28)
    public static func size(for state: PillState) -> NSSize {
        switch state {
        case .recording: return maximumSize
        case .preparing, .transcribing: return NSSize(width: 68, height: 24)
        default: return NSSize(width: 42, height: 18)
        }
    }

    private let state: PillState
    private let levels: [Float]
    private let opacity: Double
    private let action: () -> Void
    private let cancel: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var hovering = false

    public init(state: PillState, levels: [Float] = [], opacity: Double = 0.22,
                action: @escaping () -> Void, cancel: @escaping () -> Void) {
        self.state = state
        self.levels = levels
        self.opacity = opacity
        self.action = action
        self.cancel = cancel
    }

    private var size: NSSize { Self.size(for: state) }
    private var darkness: Double {
        if reduceTransparency { return 1 }
        return state.busy ? 0.95 : 0.60 + max(0.08, min(0.6, opacity)) * 0.30 + (hovering ? 0.04 : 0)
    }

    public var body: some View {
        HStack(spacing: 6) {
            Button(action: action) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(state == .transcribing)
            .accessibilityLabel(state == .recording ? "Stop and transcribe" : "Start dictation")
            if state.busy {
                Button(action: cancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 6.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(hovering ? 0.8 : 0.48))
                        .frame(width: 10, height: size.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel dictation").help("Cancel · Escape")
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .foregroundStyle(.white.opacity(state.busy || hovering ? 0.95 : 0.72))
        .padding(.horizontal, state.busy ? 11 : 10)
        .frame(width: size.width, height: size.height)
        .background {
            if !reduceTransparency { DarkFrost().clipShape(Capsule()) }
            Capsule().fill(Color.black.opacity(darkness))
        }
        .overlay {
            Capsule().strokeBorder(
                LinearGradient(colors: [.white.opacity(state.busy ? 0.19 : 0.14), .white.opacity(0.025)],
                               startPoint: .top, endPoint: .bottom), lineWidth: 0.35)
        }
        .shadow(color: .black.opacity(state.busy ? 0.24 : 0.16), radius: state.busy ? 5 : 3, x: 0, y: 2)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.84), value: state)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: hovering)
        .onHover { hovering = $0 }
    }

    @ViewBuilder private var content: some View {
        if state == .recording {
            HStack(spacing: 6) {
                Image(systemName: "mic.fill").font(.system(size: 10, weight: .medium))
                waveform
            }.transition(.opacity.combined(with: .scale(scale: 0.88)))
        } else if state == .preparing || state == .transcribing {
            ProcessingDots(animate: !reduceMotion)
                .frame(width: 20, height: 12)
                .transition(.opacity)
        } else {
            Image(systemName: state == .success ? "checkmark" : "waveform")
                .font(.system(size: state == .success ? 8 : 10, weight: .medium))
                .overlay(alignment: .topTrailing) {
                    if state == .error {
                        Circle().fill(Color(red: 1, green: 0.62, blue: 0.28))
                            .frame(width: 2.5, height: 2.5).offset(x: 4, y: -1)
                    }
                }
                .transition(.opacity)
        }
    }

    private var waveform: some View {
        HStack(spacing: 1.4) {
            ForEach(0..<9, id: \.self) { index in
                let level = levels.isEmpty ? Float(0.04) : levels[min(index * levels.count / 9, levels.count - 1)]
                Capsule().fill(.white.opacity(0.9))
                    .frame(width: 1.5, height: max(2, min(14, CGFloat(level) * 14)))
            }
        }
        .frame(width: 26, height: 14)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.09), value: levels)
    }
}

private struct ProcessingDots: View {
    let animate: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !animate)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    let pulse = animate ? (sin(time * 5 - Double(index) * 0.9) + 1) / 2 : 0.5
                    Circle().fill(.white.opacity(0.3 + pulse * 0.6)).frame(width: 3, height: 3)
                        .offset(y: animate ? -pulse * 1.5 : 0)
                }
            }
        }
    }
}

private struct DarkFrost: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        view.isEmphasized = false
        view.alphaValue = 0.24
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
