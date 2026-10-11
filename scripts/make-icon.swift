import AppKit
import Foundation

let directory = CommandLine.arguments[1]
let iconset = URL(fileURLWithPath: directory).appendingPathComponent("WhisperBubble.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for (name, size) in [("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64), ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512), ("icon_512x512", 512), ("icon_512x512@2x", 1024)] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB,
                                  bytesPerRow: size * 4, bitsPerPixel: 32)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))
    let scale = CGFloat(size) / 1024
    let rect = NSRect(x: 60 * scale, y: 60 * scale, width: 904 * scale, height: 904 * scale)
    let path = NSBezierPath(roundedRect: rect, xRadius: 212 * scale, yRadius: 212 * scale)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 30 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -8 * scale)
    shadow.set()
    NSColor(calibratedRed: 0.16, green: 0.21, blue: 0.32, alpha: 1).setFill()
    path.fill()
    NSShadow().set()
    let gradient = NSGradient(starting: NSColor(calibratedRed: 0.31, green: 0.40, blue: 0.59, alpha: 1), ending: NSColor(calibratedRed: 0.13, green: 0.17, blue: 0.28, alpha: 1))!
    gradient.draw(in: path, angle: -75)
    let heights: [CGFloat] = [118, 242, 374, 474, 338, 218, 112]
    for (i, height) in heights.enumerated() {
        let bar = NSRect(x: (236 + CGFloat(i) * 79) * scale, y: (512 - height / 2) * scale,
                         width: 39 * scale, height: height * scale)
        NSColor(calibratedRed: 0.83, green: 0.92, blue: 1, alpha: 1).setFill()
        NSBezierPath(roundedRect: bar, xRadius: 19.5 * scale, yRadius: 19.5 * scale).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name + ".png"))
}

// Pack the standard PNG-based ICNS elements directly. This works with Command
// Line Tools installations whose iconutil encoder rejects otherwise valid PNGs.
func lengthBytes(_ length: Int) -> Data {
    var value = UInt32(length).bigEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}
var elements = Data()
for (type, name) in [("icp4", "icon_16x16"), ("icp5", "icon_32x32"), ("icp6", "icon_32x32@2x"),
                      ("ic07", "icon_128x128"), ("ic08", "icon_256x256"), ("ic09", "icon_512x512"),
                      ("ic10", "icon_512x512@2x"), ("ic11", "icon_16x16@2x"),
                      ("ic12", "icon_32x32@2x"), ("ic13", "icon_128x128@2x"), ("ic14", "icon_256x256@2x")] {
    let png = try Data(contentsOf: iconset.appendingPathComponent(name + ".png"))
    elements.append(Data(type.utf8))
    elements.append(lengthBytes(png.count + 8))
    elements.append(png)
}
var container = Data("icns".utf8)
container.append(lengthBytes(elements.count + 8))
container.append(elements)
let iconURL = URL(fileURLWithPath: directory).appendingPathComponent("WhisperBubble.icns")
try container.write(to: iconURL)
guard let decoded = NSImage(contentsOf: iconURL), !decoded.representations.isEmpty else {
    fatalError("Generated ICNS could not be decoded by AppKit")
}
print("AppKit verified icon: \(decoded.representations.count) representations")
