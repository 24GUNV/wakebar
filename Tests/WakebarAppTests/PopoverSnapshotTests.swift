import AppKit
import SwiftUI
import WakebarCore
import XCTest
@testable import Wakebar

/// Renders the menu bar popover offscreen so its layout can be inspected as
/// pixels rather than guessed at. Skipped unless WAKEBAR_SNAPSHOT_DIR is set.
@MainActor
final class PopoverSnapshotTests: XCTestCase {
    func testRenderPopoverStates() throws {
        guard let directory = ProcessInfo.processInfo.environment["WAKEBAR_SNAPSHOT_DIR"] else {
            throw XCTSkip("Set WAKEBAR_SNAPSHOT_DIR to write snapshots.")
        }
        let root = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        for scheme in [ColorScheme.dark, .light] {
            let suffix = scheme == .dark ? "dark" : "light"
            try render(model: readyModel(), name: "ready-\(suffix)", scheme: scheme, in: root)
            try render(model: setupModel(), name: "setup-\(suffix)", scheme: scheme, in: root)
            try render(model: stoppedModel(), name: "stopped-\(suffix)", scheme: scheme, in: root)
            try render(model: emptyModel(), name: "empty-\(suffix)", scheme: scheme, in: root)
            try render(model: chainedModel(), name: "chained-\(suffix)", scheme: scheme, in: root)
            try render(model: assumedModel(), name: "assumed-\(suffix)", scheme: scheme, in: root)
            try render(model: continuousModel(), name: "continuous-\(suffix)", scheme: scheme, in: root)
        }
    }

    // MARK: - States

    /// Mutating `schedule` before `isLoaded` flips true keeps the model's
    /// persist-and-publish side effects out of the snapshot.
    private func baseModel(isEnabled: Bool, isValid: Bool = true) -> AppModel {
        let model = AppModel()
        var schedule = WakeSchedule.default
        schedule.isEnabled = isEnabled
        schedule.hour = 7
        schedule.minute = 0
        if !isValid {
            schedule.includeClaude = false
            schedule.includeCodex = false
        }
        model.schedule = schedule
        model.desiredRevision = schedule.revision
        return model
    }

    private func confirm(_ model: AppModel, providers: [ProviderID]) {
        for provider in providers {
            model.providerDeliveryStates[provider] = ProviderDeliveryState(
                provider: provider,
                desiredRevision: model.desiredRevision,
                appliedRevision: model.desiredRevision,
                phase: .confirmed,
                lastConfirmedAt: .now,
                detail: nil
            )
        }
    }

    private func readyModel() -> AppModel {
        let model = baseModel(isEnabled: true)
        confirm(model, providers: [.claude, .codex])
        model.phoneAlarmPublishState = .confirmed(
            PhoneAlarmAcknowledgement(
                scheduleID: model.schedule.id,
                alarmID: model.schedule.id,
                revision: PhoneScheduleRevision(
                    sequence: 3,
                    modifiedAt: .now,
                    writerID: "mac"
                ),
                confirmedAt: .now
            )
        )
        return model
    }

    private func setupModel() -> AppModel {
        let model = baseModel(isEnabled: true)
        confirm(model, providers: [.claude])
        model.phoneAlarmPublishState = .publishing
        return model
    }

    private func stoppedModel() -> AppModel {
        let model = baseModel(isEnabled: false)
        confirm(model, providers: [.claude, .codex])
        model.phoneAlarmPublishState = .failed("Could not sync the iPhone alarm.")
        return model
    }

    /// Chaining off a window Codex actually reported.
    private func chainedModel() -> AppModel {
        let model = repeatingModel()
        // The real shape as of this writing: Codex reports a weekly cap and no
        // session window, while Claude's block is reconstructed.
        model.usageWindows = [
            UsageWindow(
                provider: .codex,
                duration: 10080 * 60,
                resetsAt: .now.addingTimeInterval(5 * 24 * 60 * 60),
                usedFraction: 0.14,
                observedAt: .now,
                confidence: .reported
            ),
            UsageWindow(
                provider: .claude,
                duration: 5 * 60 * 60,
                resetsAt: .now.addingTimeInterval(2 * 60 * 60),
                usedFraction: 0.07,
                observedAt: .now,
                confidence: .inferred
            ),
        ]
        return model
    }

    /// The same band with nothing to chain to, which is what a machine that has
    /// never run either CLI will show.
    private func assumedModel() -> AppModel { repeatingModel() }

    /// Sessions chained to the window rather than the calendar, which is the
    /// state where the hero counts down hours instead of naming a day.
    private func continuousModel() -> AppModel {
        let model = chainedModel()
        model.schedule.cadence = .continuous
        return model
    }

    private func repeatingModel() -> AppModel {
        let model = AppModel()
        var schedule = WakeSchedule.default
        schedule.isEnabled = true
        schedule.hour = 7
        schedule.minute = 0
        schedule.repeatEveryFiveHours = true
        schedule.repeatUntilHour = 19
        model.schedule = schedule
        model.desiredRevision = schedule.revision
        confirm(model, providers: [.claude, .codex])
        model.phoneAlarmPublishState = .confirmed(
            PhoneAlarmAcknowledgement(
                scheduleID: schedule.id,
                alarmID: schedule.id,
                revision: PhoneScheduleRevision(sequence: 3, modifiedAt: .now, writerID: "mac"),
                confirmedAt: .now
            )
        )
        return model
    }

    private func emptyModel() -> AppModel {
        baseModel(isEnabled: false, isValid: false)
    }

    // MARK: - Rendering

    private func render(
        model: AppModel,
        name: String,
        scheme: ColorScheme,
        in root: URL
    ) throws {
        let content = WakeSummaryView(model: model)
            .frame(width: WakebarDesign.popoverWidth)
            .background(scheme == .dark ? Color(white: 0.12) : Color(white: 0.96))
            .environment(\.colorScheme, scheme)
            .environment(\.timeZone, model.schedule.timeZone)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2

        let image = try XCTUnwrap(renderer.nsImage, name)
        let tiff = try XCTUnwrap(image.tiffRepresentation, name)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiff), name)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]), name)

        let url = root.appendingPathComponent("\(name).png")
        try png.write(to: url)
        print("snapshot \(name): \(Int(image.size.width))x\(Int(image.size.height))pt -> \(url.path)")
    }
}
