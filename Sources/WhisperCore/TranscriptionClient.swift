import Foundation

public enum TranscriptionError: LocalizedError, Equatable {
    case missingKey, invalidKey, invalidLanguage, emptyAudio, fileTooLarge, emptyTranscript
    case invalidResponse, unauthorized, rateLimited, rejected(Int), unavailable
    public var errorDescription: String? {
        switch self {
        case .missingKey: return "Add your OpenAI API key in Settings before recording."
        case .invalidKey: return "The API key contains invalid characters. Re-enter it in Settings."
        case .invalidLanguage: return "Use a two-letter language code, such as en or de, or choose Auto."
        case .emptyAudio: return "The microphone did not produce an audio file. Try again."
        case .fileTooLarge: return "This recording exceeds OpenAI’s 25 MB upload limit. Record a shorter message."
        case .emptyTranscript: return "No words were returned. Check the microphone and try again."
        case .invalidResponse: return "OpenAI returned an unexpected response. Try again."
        case .unauthorized: return "OpenAI rejected this API key. Update it in Settings."
        case .rateLimited: return "OpenAI’s rate or billing limit was reached. Check your API account and try later."
        case .rejected(let status): return "OpenAI could not transcribe this recording (HTTP \(status)). Try another model or a shorter recording."
        case .unavailable: return "OpenAI is temporarily unavailable. Try again shortly."
        }
    }
}

public struct TranscriptionOptions {
    public var model: String
    public var language: String
    public init(model: String = "gpt-4o-mini-transcribe", language: String = "") {
        self.model = model
        self.language = language
    }
}

public struct TranscriptionClient {
    public static let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    public static let maximumBytes = 25_000_000
    private let session: URLSession

    public init(session: URLSession? = nil) {
        if let session { self.session = session }
        else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 60
            configuration.timeoutIntervalForResource = 120
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            self.session = URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
        }
    }

    public static func request(audio: Data, apiKey: String, options: TranscriptionOptions,
                               boundary: String = "WhisperBubble-" + UUID().uuidString) throws -> URLRequest {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw TranscriptionError.missingKey }
        guard key.unicodeScalars.allSatisfy({ $0.value > 32 && $0.value < 127 }) else {
            throw TranscriptionError.invalidKey
        }
        guard !audio.isEmpty else { throw TranscriptionError.emptyAudio }
        guard audio.count <= maximumBytes else { throw TranscriptionError.fileTooLarge }
        let language = options.language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard language.isEmpty || language.range(of: "^[a-z]{2}$", options: .regularExpression) != nil else {
            throw TranscriptionError.invalidLanguage
        }
        // The allowlist also prevents multipart header/field injection from preferences.
        let models = ["gpt-4o-mini-transcribe", "gpt-4o-transcribe", "whisper-1"]
        let model = models.contains(options.model) ? options.model : models[0]
        var body = Data()
        func append(_ value: String) { body.append(Data(value.utf8)) }
        func field(_ name: String, _ value: String) {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        field("model", model)
        field("response_format", "json")
        if !language.isEmpty { field("language", language) }
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"dictation.m4a\"\r\nContent-Type: audio/mp4\r\n\r\n")
        body.append(audio)
        append("\r\n--\(boundary)--\r\n")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    public func transcribe(audio: Data, apiKey: String, options: TranscriptionOptions) async throws -> String {
        let request = try Self.request(audio: audio, apiKey: apiKey, options: options)
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw TranscriptionError.invalidResponse }
        switch http.statusCode {
        case 200..<300: break
        case 401, 403: throw TranscriptionError.unauthorized
        case 429: throw TranscriptionError.rateLimited
        case 500...599: throw TranscriptionError.unavailable
        default: throw TranscriptionError.rejected(http.statusCode)
        }
        struct Response: Decodable { let text: String }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else {
            throw TranscriptionError.invalidResponse
        }
        let text = decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranscriptionError.emptyTranscript }
        return text
    }
}

/// Never forward the Authorization header or the user's audio to a redirect host.
private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
