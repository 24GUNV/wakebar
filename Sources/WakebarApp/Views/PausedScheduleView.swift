import SwiftUI

struct DraftScheduleView: View {
    let phoneStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("No wake scheduled", systemImage: "alarm")
                .font(.headline)

            Text("Choose a wake time and which sessions to start.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let phoneStatus {
                Label(phoneStatus, systemImage: "iphone.and.arrow.forward")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, WakebarDesign.compactSpacing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, WakebarDesign.horizontalPadding)
        .padding(.vertical, WakebarDesign.sectionSpacing)
    }
}
