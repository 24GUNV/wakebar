import AppKit
import SwiftUI
import WakebarCore
import XCTest
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

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
            try render(model: divergedModel(), name: "diverged-\(suffix)", scheme: scheme, in: root)
            try render(model: readmeModel(), name: "menu-\(suffix)", scheme: scheme, in: root, framed: true)
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
        return model
    }

    private func setupModel() -> AppModel {
        let model = baseModel(isEnabled: true)
        confirm(model, providers: [.claude])
        return model
    }

    private func stoppedModel() -> AppModel {
        let model = baseModel(isEnabled: false)
        confirm(model, providers: [.claude, .codex])
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
    /// never returned provider usage will show.
    private func assumedModel() -> AppModel { repeatingModel() }

    /// The complete usage summary: Claude's session and weekly limits, plus
    /// Codex's weekly limit.
    private func divergedModel() -> AppModel {
        let model = continuousModel()
        model.usageWindows = [
            UsageWindow(
                provider: .claude,
                duration: 5 * 60 * 60,
                resetsAt: .now.addingTimeInterval(3 * 60 * 60),
                usedFraction: 0.41,
                observedAt: .now,
                confidence: .reported
            ),
            UsageWindow(
                provider: .claude,
                limitKind: .weekly,
                duration: 7 * 24 * 60 * 60,
                resetsAt: .now.addingTimeInterval(4 * 24 * 60 * 60),
                usedFraction: 0.24,
                observedAt: .now,
                confidence: .reported
            ),
            UsageWindow(
                provider: .claude,
                limitKind: .weeklyFable,
                duration: 7 * 24 * 60 * 60,
                resetsAt: .now.addingTimeInterval(5 * 24 * 60 * 60),
                usedFraction: 0.18,
                observedAt: .now,
                confidence: .reported
            ),
            UsageWindow(
                provider: .codex,
                limitKind: .weekly,
                duration: 7 * 24 * 60 * 60,
                resetsAt: .now.addingTimeInterval(6 * 24 * 60 * 60),
                usedFraction: 0.62,
                observedAt: .now,
                confidence: .reported
            ),
        ]
        return model
    }

    /// The README picture: a weekday schedule with every limit reported.
    private func readmeModel() -> AppModel {
        let model = divergedModel()
        model.schedule.cadence = .schedule
        return model
    }

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
        return model
    }

    private func emptyModel() -> AppModel {
        baseModel(isEnabled: false, isValid: false)
    }

    // MARK: - Rendering

    /// `framed` clips the popover to its rounded shape on a transparent
    /// background, which is how the README shows it.
    private func render(
        model: AppModel,
        name: String,
        scheme: ColorScheme,
        in root: URL,
        framed: Bool = false
    ) throws {
        let panel = WakeSummaryView(model: model)
            .frame(width: WakebarDesign.popoverWidth)
            .background(scheme == .dark ? Color(white: 0.12) : Color(white: 0.96))
        let content = Group {
            if framed {
                panel
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(scheme == .dark ? 0.18 : 0.12))
                    )
                    .shadow(color: .black.opacity(scheme == .dark ? 0.5 : 0.22), radius: 18, y: 10)
                    .padding(36)
            } else {
                panel
            }
        }
        .environment(\.colorScheme, scheme)
        .environment(\.timeZone, model.schedule.timeZone)

        // An AppKit-hosted render draws real buttons and SF Symbols, which
        // ImageRenderer leaves as placeholders.
        let hosting = NSHostingView(rootView: content)
        hosting.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        let size = hosting.fittingSize
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.appearance = hosting.appearance
        window.isOpaque = false
        window.backgroundColor = .clear
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()

        let bitmap = try XCTUnwrap(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(size.width) * 2,
                pixelsHigh: Int(size.height) * 2,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ),
            name
        )
        bitmap.size = size
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]), name)
        let image = NSImage(size: size)

        let url = root.appendingPathComponent("\(name).png")
        try png.write(to: url)
        print("snapshot \(name): \(Int(image.size.width))x\(Int(image.size.height))pt -> \(url.path)")
    }
}
