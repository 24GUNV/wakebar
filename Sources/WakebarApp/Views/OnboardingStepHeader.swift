import SwiftUI

/// Matches the header of `ProviderSetupSectionView` so every walkthrough step reads the same.
struct OnboardingStepHeader: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: WakebarDesign.sectionSpacing) {
            HStack(spacing: WakebarDesign.compactSpacing) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)

                Text(title)
                    .font(.title2)
                    .bold()
            }

            Text(detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
