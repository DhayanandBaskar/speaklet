import AppKit
import SwiftUI
import WhisperMacSupport

// Renders the production component with fixture states and meter samples.
// No microphone, credentials, clipboard, or permission requests are involved.
@MainActor final class PreviewModel: ObservableObject {
    @Published var state = PillState.idle
    @Published var levels: [Float] = []
}

struct AnimatedPreview: View {
    @ObservedObject var model: PreviewModel
    var body: some View {
        DictationPill(state: model.state, levels: model.levels, action: {}, cancel: {})
            .environment(\.colorScheme, .dark)
            .frame(width: 112, height: 52)
    }
}

@MainActor func save(_ view: NSView, to url: URL) throws {
    view.layoutSubtreeIfNeeded()
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
        fatalError("Could not create preview")
    }
    view.cacheDisplay(in: view.bounds, to: bitmap)
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

try MainActor.assumeIsolated {
    let application = NSApplication.shared
    application.setActivationPolicy(.prohibited)
    let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    for scheme in [ColorScheme.dark, .light] {
        for (name, state) in [("idle", PillState.idle), ("recording", .recording), ("transcribing", .transcribing), ("error", .error)] {
            let root = DictationPill(state: state, levels: [0.1, 0.3, 0.7, 1, 0.6, 0.4, 0.25, 0.1],
                                     action: {}, cancel: {}).environment(\.colorScheme, scheme)
                .frame(width: 112, height: 52)
            let hosting = NSHostingView(rootView: root)
            let window = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: 112, height: 52),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.contentView = hosting
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            let suffix = scheme == .light ? "-light" : ""
            try save(hosting, to: destination.appendingPathComponent(name + suffix + ".png"))
            let size = DictationPill.size(for: state)
            print("Rendered \(name)\(suffix): \(size.width) × \(size.height) points")
            withExtendedLifetime(window) {}
        }
    }

    let frames = destination.appendingPathComponent("frames", isDirectory: true)
    try FileManager.default.createDirectory(at: frames, withIntermediateDirectories: true)
    let model = PreviewModel()
    let hosting = NSHostingView(rootView: AnimatedPreview(model: model))
    let window = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: 112, height: 52),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.isOpaque = false
    window.backgroundColor = .clear
    window.contentView = hosting
    for index in 0..<108 {
        let time = Double(index) / 30
        let state: PillState = time < 0.6 ? .idle : time < 0.8 ? .preparing : time < 2.0 ? .recording : time < 2.7 ? .transcribing : time < 3.1 ? .success : .idle
        model.state = state
        if state == .recording {
            model.levels = (0..<14).map { Float(0.12 + 0.75 * abs(sin(time * 8 - Double($0) * 0.65))) }
        }
        RunLoop.main.run(until: Date().addingTimeInterval(1.0 / 30))
        try save(hosting, to: frames.appendingPathComponent(String(format: "%03d.png", index)))
    }
    withExtendedLifetime(window) {}
    print("Rendered 108 production-view animation frames with fixture audio levels")
}
