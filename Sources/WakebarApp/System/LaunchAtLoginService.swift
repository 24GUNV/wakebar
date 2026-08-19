import ServiceManagement

@MainActor
struct LaunchAtLoginService {
    var state: LaunchAtLoginState {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            .off
        case .enabled:
            .on
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .unavailable
        @unknown default:
            .unavailable
        }
    }

    func setEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    func openLoginItemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
