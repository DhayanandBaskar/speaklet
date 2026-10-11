import AppKit
import SwiftUI

public enum PillState: Equatable {
    case idle, preparing, recording, transcribing, success, ready, error
    var busy: Bool { self == .preparing || self == .recording || self == .transcribing }
}

/// The same compact dimensions are used in every state, including errors.
public struct DictationPill: View {
    public static let size = NSSize(width: 72, height: 26)
    private let state: PillState
    private let levels: [Float]
    private let opacity: Double
    private let action: () -> Void
    private let cancel: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovering = false

    public init(state: PillState, levels: [Float] = [], opacity: Double = 0.22,
                action: @escaping () -> Void, cancel: @escaping () -> Void) {
        self.state = state
        self.levels = levels
        self.opacity = opacity
        self.action = action
        self.cancel = cancel
    }

    public var body: some View {
        HStack(spacing: 4) {
            Button(action: action) {
                HStack(spacing: 5) {
                    if state == .recording {
                        Circle().fill(Color.red.opacity(0.9)).frame(width: 4, height: 4)
                        waveform
                    } else if state == .preparing || state == .transcribing {
                        ProgressView().controlSize(.mini).scaleEffect(0.62)
                            .frame(width: 12, height: 12)
                    } else if state == .success {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold))
                    } else {
                        Image(systemName: "waveform").font(.system(size: 12, weight: .medium))
                        if state == .error {
                            Circle().fill(Color.orange).frame(width: 4, height: 4)
                        } else if state == .ready {
                            Circle().fill(Color.accentColor).frame(width: 3, height: 3)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 26)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(state == .transcribing)
            .accessibilityLabel(state == .recording ? "Stop and transcribe" : "Start dictation")
            if state.busy {
                Button(action: cancel) {
                    Image(systemName: "xmark").font(.system(size: 7, weight: .semibold))
                        .frame(width: 12, height: 26).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel dictation").help("Cancel · Escape")
            }
        }
        .foregroundStyle(Color.primary.opacity(hovering ? 0.95 : 0.78))
        .padding(.horizontal, 9)
        .frame(width: Self.size.width, height: Self.size.height)
        .background {
            // Light native blur and a slight tint let the desktop show through.
            LightFrost(opacity: opacity).clipShape(Capsule())
            Capsule().fill((colorScheme == .dark ? Color.black : Color.white)
                .opacity(opacity * 0.34 + (hovering ? 0.04 : 0)))
        }
        .overlay {
            Capsule().strokeBorder(
                LinearGradient(colors: [.white.opacity(hovering ? 0.4 : 0.26),
                                        .white.opacity(0.06), .black.opacity(0.1)],
                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.65)
        }
        .shadow(color: .black.opacity(0.13), radius: 4, x: 0, y: 2)
        .onHover { hovering = $0 }
    }

    private var waveform: some View {
        HStack(spacing: 1.4) {
            ForEach(0..<8, id: \.self) { index in
                let level = levels.isEmpty ? Float(0.08) : levels[min(index * levels.count / 8, levels.count - 1)]
                Capsule().fill(Color.primary.opacity(0.78))
                    .frame(width: 1.5, height: max(2, min(13, CGFloat(level) * 13)))
            }
        }.frame(width: 22, height: 14)
    }
}

private struct LightFrost: NSViewRepresentable {
    var opacity: Double
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.alphaValue = max(0.08, min(0.6, opacity))
    }
}
