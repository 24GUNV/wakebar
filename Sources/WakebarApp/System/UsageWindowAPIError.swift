import Foundation

enum UsageWindowAPIError: Error, Equatable, Sendable {
    case network
    /// The credential was rejected outright, which usually means it expired
    /// rather than that it was issued without the usage scope.
    case unauthorized
    /// The provider is turning requests away for now rather than refusing them
    /// outright. Nothing about the credential is wrong and nothing the user can
    /// do will help, so it is not the same failure as the two above.
    case rateLimited
    /// The credential was accepted and the request still refused, which is what
    /// a token missing the usage scope looks like.
    case forbidden
    case invalidResponse
}
