import Foundation
import Observation
import WakebarCore

@MainActor
@Observable
final class CodexSetupModel {
    @ObservationIgnored private let planCompiler: CodexTaskPlanCompiler

    init(planCompiler: CodexTaskPlanCompiler = CodexTaskPlanCompiler()) {
        self.planCompiler = planCompiler
    }

    func taskSpecs(for schedule: WakeSchedule) -> [CodexTaskSpec] {
        planCompiler.compile(schedule: schedule)
    }

    func instructions(for schedule: WakeSchedule) -> String {
        taskSpecs(for: schedule).map { spec in
            "Create a scheduled task named “\(spec.name)” that runs \(scheduleDescription(for: spec)). At each run, reply only with “hi”. Keep the recurring task enabled after every run; do not pause, disable, delete, or modify it."
        }.joined(separator: "\n")
    }

    func scheduleDescription(for spec: CodexTaskSpec) -> String {
        let days: String
        if spec.weekdays == Set(Weekday.allCases) {
            days = "every day"
        } else if spec.weekdays == Weekday.workweek {
            days = "every weekday"
        } else {
            let names = Weekday.displayOrder
                .filter(spec.weekdays.contains)
                .map(\.fullLabel)
                .formatted()
            days = "every \(names)"
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: spec.timeZoneIdentifier) ?? .autoupdatingCurrent
        let reference = calendar.date(
            from: DateComponents(year: 2001, month: 1, day: 1, hour: spec.hour, minute: spec.minute)
        ) ?? .now
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = calendar.timeZone
        return "\(days) at \(reference.formatted(style)) in \(spec.timeZoneIdentifier)"
    }

}
