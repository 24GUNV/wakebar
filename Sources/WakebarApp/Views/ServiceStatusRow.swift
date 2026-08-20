import SwiftUI
import WakebarCore

struct ServiceStatusRow: View {
    let title: String
    let status: String
    let kind: ServiceStatusKind

    var body: some View {
        HStack(spacing: WakebarDesign.compactSpacing) {
            Text(title)

            Spacer(minLength: WakebarDesign.compactSpacing)

            Label(status, systemImage: systemImage)
                .font(.footnote)
                .foregroundStyle(foregroundStyle)
        }
        .frame(minHeight: WakebarDesign.statusRowHeight)
        .accessibilityElement(children: .combine)
    }

    private var systemImage: String {
        switch kind {
        case .ready:
            "checkmark.circle.fill"
        case .experimental:
            "flask.fill"
        case .inProgress:
            "clock"
        case .actionRequired:
            "circle.dashed"
        }
    }

    private var foregroundStyle: Color {
        switch kind {
        case .experimental, .actionRequired:
            .orange
        case .ready, .inProgress:
            .secondary
        }
    }
}
