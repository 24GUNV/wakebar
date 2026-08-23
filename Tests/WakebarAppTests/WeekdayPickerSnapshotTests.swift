import AppKit
import SwiftUI
import WakebarCore
import XCTest
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

/// The weekday strip is drawn from text and shapes rather than AppKit controls,
/// which is what lets it be rendered offscreen at all — the settings window's
/// toggles and pickers cannot be. Rendering it is the only way to check that
/// selected days actually merge into one run instead of seven pills.
///
/// Skipped unless WAKEBAR_SNAPSHOT_DIR is set.
@MainActor
final class WeekdayPickerSnapshotTests: XCTestCase {
    func testRenderWeekdayStates() throws {
        guard let directory = ProcessInfo.processInfo.environment["WAKEBAR_SNAPSHOT_DIR"] else {
            throw XCTSkip("Set WAKEBAR_SNAPSHOT_DIR to write snapshots.")
        }
        let root = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let cases: [(String, Set<Weekday>)] = [
            ("weekdays", Weekday.workweek),
            ("everyday", Set(Weekday.allCases)),
            ("split", [.monday, .wednesday, .friday]),
            ("none", []),
        ]

        for scheme in [ColorScheme.dark, .light] {
            let suffix = scheme == .dark ? "dark" : "light"
            for (name, selection) in cases {
                try render(selection: selection, name: "week-\(name)-\(suffix)", scheme: scheme, in: root)
            }
        }
    }

    private func render(
        selection: Set<Weekday>,
        name: String,
        scheme: ColorScheme,
        in root: URL
    ) throws {
        let content = WeekdayPicker(selection: .constant(selection))
            .frame(width: 232)
            .padding(12)
            .background(scheme == .dark ? Color(white: 0.14) : Color(white: 0.98))
            .environment(\.colorScheme, scheme)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2

        let image = try XCTUnwrap(renderer.nsImage, name)
        let tiff = try XCTUnwrap(image.tiffRepresentation, name)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiff), name)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]), name)

        try png.write(to: root.appendingPathComponent("\(name).png"))
    }
}
