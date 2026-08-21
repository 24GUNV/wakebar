import Observation
import WakebarCore

@MainActor
@Observable
final class ClaudeSetupModel {
    var state: ClaudeCLISetupState = .checking

    @ObservationIgnored private let service: ClaudeCLISetupService

    init(service: ClaudeCLISetupService = ClaudeCLISetupService()) {
        self.service = service
    }

    func refresh() async {
        state = .checking
        state = await service.probe()
    }

    func startRoutineSetup(for schedule: WakeSchedule) async {
        state = .launching
        do {
            try await service.launchRoutineSetup(for: schedule)
            state = .launched
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func updateClaudeCode() async {
        do {
            try await service.launchUpdate()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func signIn() async {
        do {
            try await service.launchLogin()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
