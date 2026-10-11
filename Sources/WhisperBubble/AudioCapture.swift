import AppKit
import AVFoundation
import WhisperCore

@MainActor final class AudioCapture: NSObject, AVAudioRecorderDelegate {
    struct Recording {
        let url: URL
        let duration: TimeInterval
        let peakDB: Float
    }
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var folder: URL?
    private var peakDB: Float = -160
    var onMeter: ((Float, TimeInterval) -> Void)?
    var onLimit: (() -> Void)?
    var onError: (() -> Void)?

    static func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
            }
        default: return false
        }
    }

    func start() throws {
        cancel()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("WhisperBubble-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                              attributes: [.posixPermissions: 0o700])
        folder = directory
        let url = directory.appendingPathComponent("dictation.m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 48_000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        guard recorder.prepareToRecord(), recorder.record() else {
            cancel()
            throw CaptureError.cannotRecord
        }
        self.recorder = recorder
        peakDB = -160
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func sample() {
        guard let recorder else { return }
        recorder.updateMeters()
        peakDB = max(peakDB, recorder.peakPower(forChannel: 0))
        let power = recorder.averagePower(forChannel: 0)
        let normalized = max(0, min(1, (power + 55) / 55))
        onMeter?(normalized, recorder.currentTime)
        if recorder.currentTime >= AudioValidation.maximumDuration { onLimit?() }
    }

    func stop() -> Recording? {
        guard let recorder else { return nil }
        sample()
        timer?.invalidate()
        timer = nil
        let recording = Recording(url: recorder.url, duration: recorder.currentTime, peakDB: peakDB)
        self.recorder = nil
        recorder.stop()
        return recording
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        let recorder = self.recorder
        self.recorder = nil
        recorder?.stop()
        cleanup()
    }

    func cleanup() {
        if let folder { try? FileManager.default.removeItem(at: folder) }
        folder = nil
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.recorder === recorder else { return }
            self.onError?()
        }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.recorder === recorder else { return }
            // An interrupted device must not leave the UI showing a live recording.
            self.onError?()
        }
    }
}

private enum CaptureError: LocalizedError {
    case cannotRecord
    var errorDescription: String? { "The microphone could not start. Check your input device in macOS Sound settings." }
}
