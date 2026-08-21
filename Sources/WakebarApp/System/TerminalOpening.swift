import Foundation

@MainActor
protocol TerminalOpening: Sendable {
    func open(_ url: URL) -> Bool
}
