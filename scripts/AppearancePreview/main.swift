import AppKit
import SwiftUI
import WhisperMacSupport
import ImageIO
import UniformTypeIdentifiers
import AVFoundation

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

// Render the production view directly at Retina resolution for the website.
// The larger canvas preserves the control's proportions without upscaling pixels.
struct WebPreview: View {
    @ObservedObject var model: PreviewModel
    var body: some View {
        DictationPill(state: model.state, levels: model.levels, action: {}, cancel: {})
            .environment(\.colorScheme, .dark)
            .scaleEffect(4)
            .frame(width: 640, height: 280)
            .background(Color(.sRGB, red: 17 / 255, green: 21 / 255, blue: 30 / 255, opacity: 1))
    }
}

@MainActor func renderWebPreview(to destination: URL) throws {
    let model = PreviewModel()
    let hosting = NSHostingView(rootView: WebPreview(model: model))
    let window = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: 640, height: 280),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.backgroundColor = NSColor(srgbRed: 17 / 255, green: 21 / 255, blue: 30 / 255, alpha: 1)
    window.contentView = hosting
    let frameCount = 180
    let output = destination.appendingPathComponent("bubble-preview-retina.png")
    guard let animation = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, frameCount, nil) else {
        fatalError("Could not create animation")
    }
    CGImageDestinationSetProperties(animation, [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGLoopCount: 0]] as CFDictionary)
    for index in 0..<frameCount {
        let time = Double(index) / 30
        model.state = time < 1 ? .idle : time < 1.3 ? .preparing : time < 3.7 ? .recording : time < 4.5 ? .transcribing : time < 5.1 ? .success : .idle
        if model.state == .recording {
            model.levels = (0..<14).map { Float(0.12 + 0.75 * abs(sin(time * 8 - Double($0) * 0.65))) }
        }
        RunLoop.main.run(until: Date().addingTimeInterval(1.0 / 30))
        hosting.layoutSubtreeIfNeeded()
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            fatalError("Could not render animation frame")
        }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        guard let image = bitmap.cgImage else { fatalError("Missing animation frame") }
        CGImageDestinationAddImage(animation, image, [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGUnclampedDelayTime: 1.0 / 30, kCGImagePropertyAPNGDelayTime: 1.0 / 30]] as CFDictionary)
        if index == 72 {
            try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent("bubble-preview-poster.png"))
            print("Web preview: \(image.width) × \(image.height) pixels; production component at 4× points")
        }
    }
    guard CGImageDestinationFinalize(animation) else { fatalError("Could not finish animation") }
    withExtendedLifetime(window) {}
    print("Rendered a six-second, 30 fps lossless animation with fixture audio levels")
    try encodeWebVideo(in: destination)
}

func encodeWebVideo(in destination: URL) throws {
    let animationURL = destination.appendingPathComponent("bubble-preview-retina.png")
    guard let source = CGImageSourceCreateWithURL(animationURL as CFURL, nil),
          let firstFrame = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Missing rendered frames") }
    let videoURL = destination.appendingPathComponent("bubble-preview-retina.mp4")
    if FileManager.default.fileExists(atPath: videoURL.path) { try FileManager.default.removeItem(at: videoURL) }
    let writer = try AVAssetWriter(outputURL: videoURL, fileType: .mp4)
    writer.shouldOptimizeForNetworkUse = true
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: firstFrame.width, AVVideoHeightKey: firstFrame.height,
        AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 1_600_000,
                                         AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                                         AVVideoMaxKeyFrameIntervalKey: 30]
    ])
    let attributes: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
        kCVPixelBufferWidthKey as String: firstFrame.width, kCVPixelBufferHeightKey as String: firstFrame.height,
        kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true]
    let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
    writer.add(input)
    guard writer.startWriting() else { throw writer.error! }
    writer.startSession(atSourceTime: .zero)
    let frameCount = CGImageSourceGetCount(source)
    for index in 0..<frameCount {
        while !input.isReadyForMoreMediaData {
            if writer.status == .failed { throw writer.error! }
            Thread.sleep(forTimeInterval: 0.002)
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { fatalError("Missing video frame") }
        var buffer: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, image.width, image.height, kCVPixelFormatType_32ARGB, attributes as CFDictionary, &buffer) == kCVReturnSuccess,
              let buffer else { fatalError("Could not allocate video frame") }
        CVPixelBufferLockBaseAddress(buffer, [])
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { fatalError("Could not draw video frame") }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        guard adapter.append(buffer, withPresentationTime: CMTime(value: Int64(index), timescale: 30)) else { throw writer.error! }
    }
    writer.endSession(atSourceTime: CMTime(value: Int64(frameCount), timescale: 30))
    input.markAsFinished()
    let finished = DispatchSemaphore(value: 0)
    writer.finishWriting { finished.signal() }
    guard finished.wait(timeout: .now() + 60) == .success, writer.status == .completed else { fatalError("Could not finish web video: \(String(describing: writer.error))") }
    print("Encoded \(firstFrame.width) × \(firstFrame.height) H.264 video, \(frameCount) frames, no audio")
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
    if CommandLine.arguments.contains("--encode-web-video") {
        try encodeWebVideo(in: destination)
        return
    }
    if CommandLine.arguments.contains("--web") {
        try renderWebPreview(to: destination)
        return
    }
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
