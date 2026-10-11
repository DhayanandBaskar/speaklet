import Foundation

public enum RecordingTrigger: Equatable { case bubble, functionKey, shortcut }
public enum SessionPhase: Equatable { case idle, preparing, recording, transcribing }

/// Only the current session may change state. A cancelled permission callback or
/// network response cannot revive an older recording.
public struct SessionMachine {
    public private(set) var phase: SessionPhase = .idle
    public private(set) var sessionID: UUID?
    public private(set) var owner: RecordingTrigger?
    public init() {}

    public mutating func begin(_ trigger: RecordingTrigger) -> UUID? {
        guard phase == .idle else { return nil }
        let id = UUID()
        sessionID = id
        owner = trigger
        phase = .preparing
        return id
    }

    public mutating func recordingBegan(_ id: UUID) -> Bool {
        guard sessionID == id, phase == .preparing else { return false }
        phase = .recording
        return true
    }

    public func owns(_ trigger: RecordingTrigger) -> Bool { owner == trigger }

    public mutating func submit() -> UUID? {
        guard phase == .recording, let id = sessionID else { return nil }
        phase = .transcribing
        return id
    }

    @discardableResult public mutating func finish(_ id: UUID) -> Bool {
        guard sessionID == id else { return false }
        cancel()
        return true
    }

    public mutating func cancel() {
        phase = .idle
        sessionID = nil
        owner = nil
    }
}

public enum AudioValidation {
    public static let maximumDuration: TimeInterval = 120
    public static func problem(duration: TimeInterval, peakDB: Float) -> String? {
        if duration < 0.4 { return "Recording was too short. Hold the key a little longer." }
        if !peakDB.isFinite || peakDB < -55 { return "No speech was detected. Check your microphone and try again." }
        return nil
    }
}
