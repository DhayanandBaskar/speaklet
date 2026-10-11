import Foundation
import Combine
import WhisperCore

enum BubbleLocation: String, CaseIterable, Identifiable {
    case bottomCenter, bottomLeft, bottomRight, topLeft, topRight
    var id: String { rawValue }
    var title: String {
        switch self {
        case .bottomCenter: return "Bottom center · above the Dock"
        case .bottomLeft: return "Bottom left"
        case .bottomRight: return "Bottom right"
        case .topLeft: return "Top left"
        case .topRight: return "Top right"
        }
    }
}

enum FallbackShortcut: String, CaseIterable, Identifiable {
    case controlOptionSpace, controlShiftSpace, commandShiftD, controlOptionD
    var id: String { rawValue }
    var title: String {
        switch self {
        case .controlOptionSpace: return "⌃ ⌥ Space"
        case .controlShiftSpace: return "⌃ ⇧ Space"
        case .commandShiftD: return "⌘ ⇧ D"
        case .controlOptionD: return "⌃ ⌥ D"
        }
    }
    var keyCode: UInt16 { self == .controlOptionSpace || self == .controlShiftSpace ? 49 : 2 }
    var modifiers: UInt64 {
        switch self {
        case .controlOptionSpace, .controlOptionD: return ShortcutState.control | ShortcutState.option
        case .controlShiftSpace: return ShortcutState.control | ShortcutState.shift
        case .commandShiftD: return ShortcutState.command | ShortcutState.shift
        }
    }
}

@MainActor final class Preferences: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var location: BubbleLocation { didSet { defaults.set(location.rawValue, forKey: "bubbleLocation") } }
    @Published var model: String { didSet { defaults.set(model, forKey: "transcriptionModel") } }
    @Published var language: String { didSet { defaults.set(language, forKey: "transcriptionLanguage") } }
    @Published var fnEnabled: Bool { didSet { defaults.set(fnEnabled, forKey: "fnEnabled") } }
    @Published var fallback: FallbackShortcut { didSet { defaults.set(fallback.rawValue, forKey: "fallbackShortcut") } }
    @Published var automaticInsertion: Bool { didSet { defaults.set(automaticInsertion, forKey: "automaticInsertion") } }
    @Published var pasteFallback: Bool { didSet { defaults.set(pasteFallback, forKey: "pasteFallback") } }
    @Published var bubbleVisible: Bool { didSet { defaults.set(bubbleVisible, forKey: "bubbleVisible") } }
    @Published var bubbleOpacity: Double { didSet { defaults.set(bubbleOpacity, forKey: "bubbleOpacity") } }

    init() {
        let d = UserDefaults.standard
        location = BubbleLocation(rawValue: d.string(forKey: "bubbleLocation") ?? "") ?? .bottomCenter
        model = d.string(forKey: "transcriptionModel") ?? "gpt-4o-mini-transcribe"
        language = d.string(forKey: "transcriptionLanguage") ?? ""
        fnEnabled = d.object(forKey: "fnEnabled") as? Bool ?? true
        fallback = FallbackShortcut(rawValue: d.string(forKey: "fallbackShortcut") ?? "") ?? .controlOptionSpace
        automaticInsertion = d.object(forKey: "automaticInsertion") as? Bool ?? true
        pasteFallback = d.object(forKey: "pasteFallback") as? Bool ?? true
        bubbleVisible = d.object(forKey: "bubbleVisible") as? Bool ?? true
        let opacity = d.object(forKey: "bubbleOpacity") as? Double ?? 0.22
        bubbleOpacity = opacity.isFinite ? max(0.08, min(0.6, opacity)) : 0.22
    }
}
