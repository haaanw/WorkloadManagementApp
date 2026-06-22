import XCTest
@testable import workload_management

/// Phase 45 Plan 04 (Task 1) — `SeanEllisStore` eligibility + persistence contract.
///
/// Fully deterministic: an isolated `UserDefaults(suiteName:)` is injected into the store (never
/// `.standard`), and the answering date is passed in (never a baked `.now` inside the decision). Proves
/// `shouldPrompt` gates below threshold, fires at/after threshold when never answered, goes quiet right
/// after an answer, and re-qualifies only once another full threshold of new events accrues.
final class SeanEllisStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: SeanEllisStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "SeanEllisStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = SeanEllisStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func test_shouldPrompt_falseBelowThreshold() {
        XCTAssertFalse(store.shouldPrompt(verdictEventCount: 0, threshold: 5))
        XCTAssertFalse(store.shouldPrompt(verdictEventCount: 4, threshold: 5))
    }

    func test_shouldPrompt_trueAtThreshold_whenNeverAnswered() {
        XCTAssertTrue(store.shouldPrompt(verdictEventCount: 5, threshold: 5))
        XCTAssertTrue(store.shouldPrompt(verdictEventCount: 9, threshold: 5))
    }

    func test_shouldPrompt_falseImmediatelyAfterAnswer() {
        store.recordAnswer(.very, atEventCount: 5, on: Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(store.lastAnswer, .very)
        // Same count → already answered, not re-qualified.
        XCTAssertFalse(store.shouldPrompt(verdictEventCount: 5, threshold: 5))
        // A few more events, but not a full threshold's worth → still quiet.
        XCTAssertFalse(store.shouldPrompt(verdictEventCount: 9, threshold: 5))
    }

    func test_shouldPrompt_reQualifiesAfterAnotherThresholdOfEvents() {
        store.recordAnswer(.somewhat, atEventCount: 5, on: Date(timeIntervalSince1970: 1_000))
        // Exactly one more threshold of new events (5 → 10) → re-qualifies.
        XCTAssertTrue(store.shouldPrompt(verdictEventCount: 10, threshold: 5))
        // One short of re-qualifying.
        XCTAssertFalse(store.shouldPrompt(verdictEventCount: 9, threshold: 5))
    }

    func test_recordAnswer_persistsRawAnswer() {
        XCTAssertNil(store.lastAnswer)
        store.recordAnswer(.not, atEventCount: 7, on: Date(timeIntervalSince1970: 2_000))
        // A fresh store reading the same suite sees the persisted answer.
        let reread = SeanEllisStore(defaults: defaults)
        XCTAssertEqual(reread.lastAnswer, .not)
    }
}
