import Foundation

/// Where the app gets its picture of the open usage windows.
///
/// The implementation lives on the Mac side next to the provider clients and
/// filesystem fallback. Scheduling only ever sees this protocol, which is what
/// lets the planner be tested without credentials or a home directory and what
/// lets the app run when neither CLI has ever been used.
public protocol UsageWindowReading: Sendable {
    func currentWindows(now: Date) async -> [UsageWindow]
}
