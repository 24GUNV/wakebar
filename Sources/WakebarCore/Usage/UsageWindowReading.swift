import Foundation

/// Where the app gets its picture of the open usage windows.
///
/// The real implementation reads the CLIs' own session logs, so it lives on the
/// Mac side next to the rest of the filesystem work. Scheduling only ever sees
/// this protocol, which is what lets the planner be tested without a home
/// directory and what lets the app run when neither CLI has ever been used.
public protocol UsageWindowReading: Sendable {
    func currentWindows(now: Date) async -> [UsageWindow]
}
