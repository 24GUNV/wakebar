import SwiftUI
import WakebarCore

@main
struct WakebarApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: model)
        } label: {
            MenuBarIconView(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("Wakebar", id: "settings") {
            ScheduleSettingsView(model: model)
        }
        .defaultSize(width: WakebarDesign.windowMinimumWidth, height: 520)

        Window("Wakebar Setup", id: "onboarding") {
            OnboardingView(model: model)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

/// The menu bar icon carries one glance of state: filled when a wake is
/// scheduled, outlined when off, badged when setup needs the user. Loading here
/// rather than in the popover means the icon is already right at launch.
private struct MenuBarIconView: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let state = model.menuBarIconState

        icon(for: state)
            .accessibilityLabel(state.accessibilityLabel)
            .task {
                await model.load()
                // The status item is the only view that exists from launch, so
                // it carries the first-run trigger for the setup guide.
                guard model.shouldPresentOnboarding else { return }
                model.beginOnboarding()
                NSApplication.shared.activate()
                openWindow(id: "onboarding")
            }
    }

    @ViewBuilder
    private func icon(for state: MenuBarIconState) -> some View {
        if let badge = state.badgeSymbolName {
            Image(systemName: state.symbolName)
                // The badge needs a knocked-out gap behind it to stay legible
                // over the glyph and any menu-bar background.
                .mask(alignment: .topTrailing) {
                    Rectangle()
                        .overlay(alignment: .topTrailing) {
                            Circle()
                                .frame(width: 10, height: 10)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: badge)
                        .font(.system(size: 8))
                }
        } else {
            Image(systemName: state.symbolName)
        }
    }
}
