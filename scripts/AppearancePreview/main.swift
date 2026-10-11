import AppKit
import SwiftUI
import WhisperMacSupport

// Offscreen previews use the app's real SwiftUI component. No recording, API,
// credentials, clipboard, or permission requests are involved.
try MainActor.assumeIsolated {
    let application = NSApplication.shared
    application.setActivationPolicy(.prohibited)
    let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    for (name, state) in [("idle", PillState.idle), ("recording", .recording), ("transcribing", .transcribing), ("error", .error)] {
        let root = DictationPill(state: state, levels: [0.1, 0.3, 0.7, 1, 0.6, 0.4, 0.25, 0.1],
                                 action: {}, cancel: {}).environment(\.colorScheme, .dark)
            .frame(width: 96, height: 50)
        let hosting = NSHostingView(rootView: root)
        let window = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: 96, height: 50),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            fatalError("Could not create \(name) preview")
        }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent(name + ".png"))
        print("Rendered \(name): visible pill \(DictationPill.size.width) × \(DictationPill.size.height) points")
        // Keep the hosting view and its offscreen window alive during capture.
        withExtendedLifetime(window) {}
    }
}
