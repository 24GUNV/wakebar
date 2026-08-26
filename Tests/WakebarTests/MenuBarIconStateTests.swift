import XCTest
@testable import WakebarCore

final class MenuBarIconStateTests: XCTestCase {
    func testDisabledScheduleIsOffRegardlessOfMenuState() {
        let menuStates: [ScheduleMenuState] = [.draft, .ready, .inProgress, .actionRequired]

        for menuState in menuStates {
            XCTAssertEqual(
                MenuBarIconState.resolve(isScheduleEnabled: false, menuState: menuState),
                .off
            )
        }
    }

    func testEnabledActionRequiredNeedsAttention() {
        XCTAssertEqual(
            MenuBarIconState.resolve(isScheduleEnabled: true, menuState: .actionRequired),
            .attention
        )
    }

    func testEnabledNonActionStatesAreActive() {
        let menuStates: [ScheduleMenuState] = [.draft, .ready, .inProgress]

        for menuState in menuStates {
            XCTAssertEqual(
                MenuBarIconState.resolve(isScheduleEnabled: true, menuState: menuState),
                .active
            )
        }
    }

    func testOnlyOffUsesTheOutlineGlyph() {
        XCTAssertEqual(MenuBarIconState.active.symbolName, "sunrise.fill")
        XCTAssertEqual(MenuBarIconState.attention.symbolName, "sunrise.fill")
        XCTAssertEqual(MenuBarIconState.off.symbolName, "sunrise")
    }

    func testOnlyAttentionCarriesABadge() {
        XCTAssertEqual(MenuBarIconState.attention.badgeSymbolName, "exclamationmark.circle.fill")
        XCTAssertNil(MenuBarIconState.active.badgeSymbolName)
        XCTAssertNil(MenuBarIconState.off.badgeSymbolName)
    }

    func testAccessibilityLabelsNameEachState() {
        XCTAssertEqual(MenuBarIconState.active.accessibilityLabel, "Wakebar, wake scheduled")
        XCTAssertEqual(MenuBarIconState.attention.accessibilityLabel, "Wakebar, needs attention")
        XCTAssertEqual(MenuBarIconState.off.accessibilityLabel, "Wakebar, off")
    }
}
