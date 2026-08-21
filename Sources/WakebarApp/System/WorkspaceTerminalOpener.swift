import AppKit

@MainActor
struct WorkspaceTerminalOpener: TerminalOpening {
    func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}
