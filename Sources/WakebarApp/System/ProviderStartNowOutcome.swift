import Foundation

enum ProviderStartNowOutcome: Equatable, Sendable {
    case started(Date)
    case unconfirmed
}
