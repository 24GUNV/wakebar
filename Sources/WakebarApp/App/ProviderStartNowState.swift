import Foundation
import WakebarCore

enum ProviderStartNowState: Equatable {
    case idle
    case requested
    /// The provider confirmed this session window after a Start Now request.
    case started(UsageWindow)
    case unconfirmed

    /// When the window a Start Now confirmed began.
    var startedWindowStart: Date? {
        guard case let .started(window) = self else { return nil }
        return window.resetsAt.addingTimeInterval(-window.duration)
    }

    /// The state after a fresh usage reading. A confirmation describes one
    /// window, so it is dropped once that window has closed or a later one has
    /// opened in its place; otherwise "Window started" would keep naming a
    /// window from a day ago under the reading of a new one.
    func reconciled(with windows: [UsageWindow], now: Date) -> ProviderStartNowState {
        guard case let .started(window) = self else { return self }
        guard window.isOpen(at: now) else { return .idle }

        let supersededBySessionWindow = windows.contains { candidate in
            candidate.provider == window.provider
                && candidate.isSessionWindow
                && candidate.isOpen(at: now)
                && candidate.resetsAt > window.resetsAt.addingTimeInterval(60)
        }
        return supersededBySessionWindow ? .idle : self
    }
}
