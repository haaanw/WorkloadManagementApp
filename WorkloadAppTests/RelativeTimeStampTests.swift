import XCTest
@testable import workload_management

/// `RelativeDateTimeFormatter` rounds before choosing tense, so a just-written timestamp
/// rendered as the FUTURE — "in 0 sec" on the Sync Status screen, "Last used in 0 seconds"
/// on a template card saved a moment earlier. One floored renderer now serves every stamp.
final class RelativeTimeStampTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")

    func test_present_readsAsJustNow_neverAsFuture() {
        let now = Date()
        let text = RelativeTimeStamp.string(for: now, now: now, locale: locale)
        XCTAssertFalse(text.lowercased().contains("in 0"), "got: \(text)")
        XCTAssertTrue(RelativeTimeStamp.isJustNow(now, now: now))
    }

    func test_slightlyFutureTimestamp_isAlsoJustNow() {
        // Clock skew or a server stamp written a moment ahead must not produce a forward
        // count — the floor is on the ABSOLUTE interval.
        let now = Date()
        let future = now.addingTimeInterval(5)
        XCTAssertTrue(RelativeTimeStamp.isJustNow(future, now: now))
        let text = RelativeTimeStamp.string(for: future, now: now, locale: locale)
        XCTAssertFalse(text.lowercased().contains("in 0"), "got: \(text)")
    }

    func test_justInsideTheFloor_isJustNow_andJustOutsideIsNot() {
        let now = Date()
        XCTAssertTrue(RelativeTimeStamp.isJustNow(now.addingTimeInterval(-59), now: now))
        XCTAssertFalse(RelativeTimeStamp.isJustNow(now.addingTimeInterval(-61), now: now))
    }

    func test_pastBeyondTheFloor_rendersARelativeStamp() {
        let now = Date()
        let earlier = now.addingTimeInterval(-3600)
        let text = RelativeTimeStamp.string(for: earlier, now: now, locale: locale)
        XCTAssertFalse(text.isEmpty)
        XCTAssertFalse(RelativeTimeStamp.isJustNow(earlier, now: now))
    }
}
