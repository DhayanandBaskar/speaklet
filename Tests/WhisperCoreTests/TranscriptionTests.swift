import Foundation
import WhisperCore

final class TranscriptionTests {
    func testMultipartRequestUsesExpectedEndpointAndPreservesAudio() throws {
        let bytes = Data([0, 1, 255, 42])
        let request = try TranscriptionClient.request(audio: bytes, apiKey: "fixture-key", options: .init(language: "DE"), boundary: "fixture-boundary")
        XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/audio/transcriptions")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "multipart/form-data; boundary=fixture-boundary")
        let body = request.httpBody!
        let header = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(header.contains("name=\"model\"\r\n\r\ngpt-4o-mini-transcribe\r\n"))
        XCTAssertTrue(header.contains("name=\"response_format\"\r\n\r\njson\r\n"))
        XCTAssertTrue(header.contains("name=\"language\"\r\n\r\nde\r\n"))
        XCTAssertTrue(header.contains("filename=\"dictation.m4a\"\r\nContent-Type: audio/mp4"))
        XCTAssertNotNil(body.range(of: bytes))
        XCTAssertEqual(body.suffix(22), Data("--fixture-boundary--\r\n".utf8))
    }

    func testAutoLanguageOmitsFieldAndUnknownModelUsesAllowlist() throws {
        let request = try TranscriptionClient.request(audio: Data([0]), apiKey: "fixture-key", options: .init(model: "unsafe\r\nmodel"))
        let body = String(decoding: request.httpBody!, as: UTF8.self)
        XCTAssertFalse(body.contains("name=\"language\""))
        XCTAssertFalse(body.contains("unsafe"))
        XCTAssertTrue(body.contains("gpt-4o-mini-transcribe"))
    }

    func testInvalidKeyLanguageAndAudioRejectedLocally() {
        XCTAssertThrowsError(try TranscriptionClient.request(audio: Data([0]), apiKey: "", options: .init())) { XCTAssertEqual($0 as? TranscriptionError, .missingKey) }
        XCTAssertThrowsError(try TranscriptionClient.request(audio: Data([0]), apiKey: "fixture\r\nkey", options: .init())) { XCTAssertEqual($0 as? TranscriptionError, .invalidKey) }
        XCTAssertThrowsError(try TranscriptionClient.request(audio: Data([0]), apiKey: "fixture-key", options: .init(language: "German"))) { XCTAssertEqual($0 as? TranscriptionError, .invalidLanguage) }
        XCTAssertThrowsError(try TranscriptionClient.request(audio: Data(), apiKey: "fixture-key", options: .init())) { XCTAssertEqual($0 as? TranscriptionError, .emptyAudio) }
        XCTAssertThrowsError(try TranscriptionClient.request(audio: Data(repeating: 0, count: 25_000_001), apiKey: "fixture-key", options: .init())) { XCTAssertEqual($0 as? TranscriptionError, .fileTooLarge) }
    }

    func testSuccessfulResponseAndUnicode() async throws {
        let client = mockClient(status: 200, body: "{\"text\":\"  Grüße aus Berlin 👋  \"}")
        let text = try await client.transcribe(audio: Data([0]), apiKey: "fixture-key", options: .init())
        XCTAssertEqual(text, "Grüße aus Berlin 👋")
    }

    func testAPIErrorStatusMappingWithoutExposingServerBody() async {
        for (status, expected) in [(401, TranscriptionError.unauthorized), (403, .unauthorized), (429, .rateLimited), (503, .unavailable), (400, .rejected(400)), (302, .rejected(302))] {
            do {
                _ = try await mockClient(status: status, body: "private fixture response").transcribe(audio: Data([0]), apiKey: "fixture-key", options: .init())
                XCTFail("Expected failure for \(status)")
            } catch { XCTAssertEqual(error as? TranscriptionError, expected) }
        }
    }

    func testMalformedAndEmptyResponses() async {
        for (body, expected) in [("not json", TranscriptionError.invalidResponse), ("{\"text\":\"  \"}", .emptyTranscript), ("{}", .invalidResponse)] {
            do {
                _ = try await mockClient(status: 200, body: body).transcribe(audio: Data([0]), apiKey: "fixture-key", options: .init())
                XCTFail("Expected response failure")
            } catch { XCTAssertEqual(error as? TranscriptionError, expected) }
        }
    }

    func testCancellationStopsPendingNetworkRequest() async {
        let client = mockClient(status: 200, body: "{\"text\":\"late result\"}", delay: 2)
        let task = Task { try await client.transcribe(audio: Data([0]), apiKey: "fixture-key", options: .init()) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled request returned text") }
        catch { XCTAssertTrue(error is CancellationError || (error as? URLError)?.code == .cancelled) }
    }

    private func mockClient(status: Int, body: String, delay: TimeInterval = 0) -> TranscriptionClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureProtocol.self]
        configuration.httpAdditionalHeaders = ["Fixture-Status": String(status), "Fixture-Body": body, "Fixture-Delay": String(delay)]
        return TranscriptionClient(session: URLSession(configuration: configuration))
    }
}

private final class FixtureProtocol: URLProtocol {
    private var work: DispatchWorkItem?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let status = Int(request.value(forHTTPHeaderField: "Fixture-Status") ?? "200")!
        let body = request.value(forHTTPHeaderField: "Fixture-Body") ?? "{}"
        let delay = Double(request.value(forHTTPHeaderField: "Fixture-Delay") ?? "0")!
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let response = HTTPURLResponse(url: self.request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: Data(body.utf8))
            self.client?.urlProtocolDidFinishLoading(self)
        }
        self.work = work
        DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: work)
    }
    override func stopLoading() { work?.cancel(); work = nil }
}
