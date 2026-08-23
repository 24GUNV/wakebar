import Foundation

enum ProviderStartNowState: Equatable {
    case idle
    case requested
    case started(Date)
    case unconfirmed
}
