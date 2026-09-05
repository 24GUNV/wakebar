import Foundation
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

final class StubKeychainLookup: @unchecked Sendable {
    private let lock = NSLock()
    private let result: UsageWindowCredentialResolver.KeychainResult
    private var storedAllowUIArguments: [Bool] = []

    init(result: UsageWindowCredentialResolver.KeychainResult) {
        self.result = result
    }

    var lookupCount: Int {
        lock.withLock { storedAllowUIArguments.count }
    }

    var allowUIArguments: [Bool] {
        lock.withLock { storedAllowUIArguments }
    }

    func lookup(allowUI: Bool) -> UsageWindowCredentialResolver.KeychainResult {
        lock.withLock { storedAllowUIArguments.append(allowUI) }
        return result
    }
}
