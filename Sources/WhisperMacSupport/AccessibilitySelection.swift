import ApplicationServices
import Foundation
import WhisperCore

/// Decode only public, typed Accessibility values. The caller supplies values
/// already read from the focused editable element.
public enum AccessibilitySelection {
    public static func decode(characterRange: CFTypeRef?, markerRange: CFTypeRef?) -> PasteSelection? {
        if let characterRange, CFGetTypeID(characterRange) == AXValueGetTypeID() {
            let axValue = characterRange as! AXValue
            var range = CFRange()
            if AXValueGetType(axValue) == .cfRange, AXValueGetValue(axValue, .cfRange, &range) {
                return .characters(NSRange(location: range.location, length: range.length))
            }
        }
        guard let markerRange, CFGetTypeID(markerRange) == AXTextMarkerRangeGetTypeID() else { return nil }
        let range = markerRange as! AXTextMarkerRange
        let start = AXTextMarkerRangeCopyStartMarker(range)
        let end = AXTextMarkerRangeCopyEndMarker(range)
        guard let startBytes = bytes(start), let endBytes = bytes(end) else { return nil }
        return .markers(start: startBytes, end: endBytes)
    }

    private static func bytes(_ marker: AXTextMarker) -> Data? {
        let count = AXTextMarkerGetLength(marker)
        guard count > 0, count <= 4096 else { return nil }
        return Data(bytes: AXTextMarkerGetBytePtr(marker), count: count)
    }
}
