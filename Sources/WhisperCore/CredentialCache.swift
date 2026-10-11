/// Keeps an approved credential in memory for one app session. Failed reads
/// are retried; successful replacement/removal updates the cached value.
public final class CredentialCache {
    private var loaded = false
    private var value: String?
    public init() {}

    public func read(using loader: () throws -> String?) rethrows -> String? {
        if !loaded { store(try loader()) }
        return value
    }

    public func store(_ value: String?) {
        self.value = value
        loaded = true
    }

    public func clear() {
        value = nil
        loaded = false
    }
}
