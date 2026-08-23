import AppKit
import Foundation

struct SystemCodexStartRequester: CodexStartRequesting {
    func requestStart(prompt: String) async throws {
        try await MainActor.run {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            guard pasteboard.setString(prompt, forType: .string) else {
                throw ProviderStartNowError.clipboardUnavailable
            }
            guard let url = URL(string: "https://chatgpt.com"),
                  NSWorkspace.shared.open(url)
            else {
                throw ProviderStartNowError.browserUnavailable
            }
        }
    }
}
