import XCTest
@testable import workload_management

@MainActor
final class SubscriptionGatingTests: XCTestCase {

    // MARK: - filterSessionsForFree

    func test_filterSessionsForFree_keepsSessionsWithin7Days() {
        let now = Date()
        let recent = makeSession(daysAgo: 3, from: now)
        let old = makeSession(daysAgo: 10, from: now)
        let result = SubscriptionService.filterSessionsForFree([recent, old], relativeTo: now)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, recent.id)
    }

    func test_filterSessionsForFree_includesSessionExactly7DaysAgo() {
        let now = Date()
        let boundary = makeSession(daysAgo: 7, from: now)
        let result = SubscriptionService.filterSessionsForFree([boundary], relativeTo: now)
        XCTAssertEqual(result.count, 1)
    }

    func test_filterSessionsForFree_excludesSessionOver7Days() {
        let now = Date()
        let old = makeSession(daysAgo: 8, from: now)
        let result = SubscriptionService.filterSessionsForFree([old], relativeTo: now)
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - lockedWeeks

    func test_lockedWeeks_returnsCorrectCount() {
        XCTAssertEqual(SubscriptionService.lockedWeeks(totalSessions: 30, visibleSessions: 5), 3)
    }

    func test_lockedWeeks_returnsZeroWhenNothingLocked() {
        XCTAssertEqual(SubscriptionService.lockedWeeks(totalSessions: 5, visibleSessions: 5), 0)
    }

    func test_lockedWeeks_returnsZeroWhenVisibleExceedsTotal() {
        XCTAssertEqual(SubscriptionService.lockedWeeks(totalSessions: 3, visibleSessions: 10), 0)
    }

    // MARK: - filterSnapshotsForFree

    func test_filterSnapshotsForFree_keepsSnapshotsWithin7Days() {
        let now = Date()
        let recent = makeSnapshot(daysAgo: 2, from: now)
        let old = makeSnapshot(daysAgo: 14, from: now)
        let result = SubscriptionService.filterSnapshotsForFree([recent, old], relativeTo: now)
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Helpers

    private func makeSession(daysAgo: Int, from date: Date) -> WorkoutSession {
        WorkoutSession(
            sessionDate: Calendar.current.date(byAdding: .day, value: -daysAgo, to: date)!,
            sportType: .lifting,
            durationSeconds: 3600
        )
    }

    private func makeSnapshot(daysAgo: Int, from date: Date) -> WorkloadSnapshot {
        WorkloadSnapshot(
            snapshotDate: Calendar.current.date(byAdding: .day, value: -daysAgo, to: date)!,
            acuteLoad: 50,
            chronicLoad: 45,
            acwr: 1.1,
            tsb: 5
        )
    }
}
