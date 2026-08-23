import XCTest
@testable import workload_management

final class ReviewPromptGateTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_755_900_000)

    private func prompt(
        count: Int = 5,
        savedSecondsAgo: TimeInterval? = 10,
        lastPromptDaysAgo: Double? = nil
    ) -> Bool {
        ReviewPromptGate.shouldPrompt(
            completedSessionCount: count,
            latestSessionCreatedAt: savedSecondsAgo.map { now.addingTimeInterval(-$0) },
            lastPromptedAt: lastPromptDaysAgo.map { now.addingTimeInterval(-$0 * 86_400) },
            now: now
        )
    }

    func test_promptsAtThresholds_freshSave_noPriorPrompt() {
        XCTAssertTrue(prompt())
    }

    func test_underMinimumSessions_neverPrompts() {
        XCTAssertFalse(prompt(count: 4))
    }

    func test_noSavedSession_neverPrompts() {
        XCTAssertFalse(prompt(savedSecondsAgo: nil))
    }

    func test_staleDismissal_isNotASave() {
        XCTAssertFalse(prompt(savedSecondsAgo: ReviewPromptGate.freshSaveWindowSeconds + 1))
    }

    func test_saveTimestampInTheFuture_neverPrompts() {
        XCTAssertFalse(prompt(savedSecondsAgo: -30))
    }

    func test_insideCooldown_neverPrompts() {
        XCTAssertFalse(prompt(lastPromptDaysAgo: Double(ReviewPromptGate.cooldownDays) - 1))
    }

    func test_cooldownElapsed_promptsAgain() {
        XCTAssertTrue(prompt(lastPromptDaysAgo: Double(ReviewPromptGate.cooldownDays) + 1))
    }

    func test_windowBoundary_isInclusive() {
        XCTAssertTrue(prompt(savedSecondsAgo: ReviewPromptGate.freshSaveWindowSeconds))
    }
}
