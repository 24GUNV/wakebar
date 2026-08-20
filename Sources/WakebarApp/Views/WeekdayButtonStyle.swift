import SwiftUI

struct WeekdayButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .bold(isSelected)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .frame(maxWidth: .infinity, minHeight: 34)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 0 : 1)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(isPressed ? 0.78 : 1)
        }
        return Color.primary.opacity(isPressed ? 0.10 : 0.035)
    }

    private var borderColor: Color {
        isSelected ? .clear : Color.secondary.opacity(0.35)
    }
}
