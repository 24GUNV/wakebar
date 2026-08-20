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
        case .inProgress:
            "clock"
        case .actionRequired:
            "circle.dashed"
        }
    }

    private var foregroundStyle: Color {
        kind == .actionRequired ? .orange : .secondary
    }
}
