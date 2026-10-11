import WhisperCore

final class CredentialCacheTests {
    func testRepeatedUseNeedsOnlyOneCredentialRead() throws {
        let cache = CredentialCache()
        var reads = 0
        let loader: () -> String? = { reads += 1; return "fixture-key" }
        for _ in 0..<4 { XCTAssertEqual(cache.read(using: loader), "fixture-key") }
        XCTAssertEqual(reads, 1)
        cache.clear()
        XCTAssertEqual(cache.read(using: loader), "fixture-key")
        XCTAssertEqual(reads, 2)
    }

    func testDeniedReadCanRetryWithoutLosingReplacementOrRemoval() throws {
        enum Denied: Error { case access }
        let cache = CredentialCache()
        XCTAssertThrowsError(try cache.read { throw Denied.access }) { _ in }
        XCTAssertEqual(cache.read { "fixture-key" }, "fixture-key")
        cache.store("replacement-fixture")
        XCTAssertEqual(cache.read { XCTFail("Replacement must be used"); return "stale-fixture" }, "replacement-fixture")
        cache.store(nil)
        XCTAssertNil(cache.read { XCTFail("Removed credential must stay removed"); return "stale-fixture" })
    }
}
