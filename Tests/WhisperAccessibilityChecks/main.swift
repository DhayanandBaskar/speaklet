import ApplicationServices
import Foundation
import WhisperCore
import WhisperMacSupport

var checks = 0
var failures = 0
func check(_ name: String, _ condition: Bool) {
    checks += 1
    if !condition { failures += 1 }
    print("\(condition ? "PASS" : "FAIL") \(name)")
}
func markerRange(_ start: Data, _ end: Data) -> AXTextMarkerRange {
    start.withUnsafeBytes { startBytes in
        end.withUnsafeBytes { endBytes in
            AXTextMarkerRangeCreateWithBytes(nil, startBytes.bindMemory(to: UInt8.self).baseAddress!, start.count,
                                             endBytes.bindMemory(to: UInt8.self).baseAddress!, end.count)
        }
    }
}
var range = CFRange(location: 3, length: 5)
let characterValue = AXValueCreate(.cfRange, &range)!
let start = Data([1, 2, 3, 4])
let end = Data([1, 2, 3, 5])
let markers = markerRange(start, end)
check("typed character range decoding", AccessibilitySelection.decode(characterRange: characterValue, markerRange: nil) == .characters(NSRange(location: 3, length: 5)))
check("standard selection preferred when both are exposed", AccessibilitySelection.decode(characterRange: characterValue, markerRange: markers) == .characters(NSRange(location: 3, length: 5)))
check("public native marker range decoding", AccessibilitySelection.decode(characterRange: nil, markerRange: markers) == .markers(start: start, end: end))
check("independent marker objects preserve cursor equality", AccessibilitySelection.decode(characterRange: nil, markerRange: markers) == AccessibilitySelection.decode(characterRange: nil, markerRange: markerRange(start, end)))
check("changed marker endpoint is distinguishable", AccessibilitySelection.decode(characterRange: nil, markerRange: markers) != AccessibilitySelection.decode(characterRange: nil, markerRange: markerRange(start, Data([1, 2, 3, 6]))))
check("unsupported CF types are rejected without unsafe casts", AccessibilitySelection.decode(characterRange: "wrong" as CFString, markerRange: "wrong" as CFString) == nil)
var point = CGPoint(x: 1, y: 2)
let wrongValueType = AXValueCreate(.cgPoint, &point)!
check("non-range AXValue falls back to native marker range", AccessibilitySelection.decode(characterRange: wrongValueType, markerRange: markers) == .markers(start: start, end: end))
check("oversized native markers rejected", AccessibilitySelection.decode(characterRange: nil, markerRange: markerRange(Data(repeating: 1, count: 4097), end)) == nil)
print("\(checks) native accessibility-value checks, \(failures) failures; no other app inspected or modified")
exit(failures == 0 ? 0 : 1)
