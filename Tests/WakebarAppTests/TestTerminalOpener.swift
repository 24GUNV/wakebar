import Foundation
@testable import Wakebar

@MainActor
final class TestTerminalOpener: TerminalOpening {
    let shouldOpen: Bool
    private(set) var openedURLs: [URL] = []

    init(shouldOpen: Bool = true) {
        self.shouldOpen = shouldOpen
    }

    func open(_ url: URL) -> Bool {
        openedURLs.append(url)
        return shouldOpen
    }
}
