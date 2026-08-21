import SwiftUI
import WakebarCore

/// The band under the service rows: what each provider says about its own
/// limits, then when the next session goes.
///
/// Observation and plan are kept as separate rows on purpose. Stacking a window
/// under the session time as a subtitle would claim the one caused the other,
/// which is only sometimes true — a window closing this afternoon has nothing
/// to do with a session planned for Monday.
struct RefreshSummaryView: View {
    let nextRefresh: Date?
    let windows: [UsageWindowRow]
    let providerIssues: [ProviderID: UsageWindowProviderIssue]
    /// Set only when nothing reported a session window and the plan fell back
    /// to its fixed cadence.
    let assumedCadenceHour: Int?
    /// False when the hero is already counting down to the next session, where
    /// a second "Next session" carrying the session *after* that one reads as a
    /// contradiction rather than as extra detail.
    var showsNextSession: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(windows) { window in
                row(label: window.label) {
                    windowValue(window)
                }
            }

            ForEach(providerIssues.keys.sorted { $0.rawValue < $1.rawValue }, id: \.self) { provider in
                row(label: "\(provider.displayName) usage") {
                    Text(providerIssues[provider]?.message ?? "")
                        .foregroundStyle(.tertiary)
                }
            }

            if showsNextSession {
                row(label: "Next session") {
                    if let nextRefresh {
                        Text(nextRefresh, format: .dateTime.hour().minute())
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    } else {
                        Text("None before cutoff")
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if let assumedCadenceHour {
                Text("Every 5 hours until \(hourText(assumedCadenceHour))")
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .font(WakebarDesign.detail)
        .foregroundStyle(.secondary)
        .wakebarInset()
        .padding(.vertical, WakebarDesign.bandPadding)
        .accessibilityElement(children: .combine)
    }

    /// A session window resets today, so the hour is the answer. A weekly cap
    /// resets days out, where an hour alone would read as today and be wrong.
    @ViewBuilder
    private func windowValue(_ window: UsageWindowRow) -> some View {
        HStack(spacing: 4) {
            if window.isSessionWindow {
                Text("\(window.isEstimate ? "~" : "")\(window.resetsAt.formatted(.dateTime.hour().minute()))")
                    .monospacedDigit()
            } else {
                Text(window.resetsAt, format: .dateTime.weekday(.abbreviated).hour().minute())
                    .monospacedDigit()
            }

            if let usedFraction = window.usedFraction {
                Text("· \(Int((usedFraction * 100).rounded()))% used")
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func row<Value: View>(
        label: String,
        @ViewBuilder value: () -> Value
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: WakebarDesign.compactSpacing) {
            Text(label)
                .lineLimit(1)

            Spacer(minLength: WakebarDesign.compactSpacing)

            value()
                .lineLimit(1)
        }
    }

    private func hourText(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let reference = Calendar(identifier: .gregorian).date(from: components) ?? .now
        return reference.formatted(.dateTime.hour().minute())
    }
}
