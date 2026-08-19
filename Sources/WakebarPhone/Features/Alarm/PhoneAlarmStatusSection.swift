import SwiftUI

struct PhoneAlarmStatusSection: View {
    let status: PhoneCompanionStatus

    var body: some View {
        Section("iPhone alarm") {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(status.title)
                        .bold()
                    Text(status.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: status.systemImage)
                    .foregroundStyle(iconStyle)
                    .accessibilityHidden(true)
            }
        }
    }

    private var iconStyle: Color {
        status == .armed ? PhoneDesign.alarmTint : .secondary
    }
}
