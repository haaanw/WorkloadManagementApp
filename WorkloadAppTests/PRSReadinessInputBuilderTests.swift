import XCTest
@testable import workload_management

/// Phase 43 Plan 03 (Task 1) — regression + extension tests for `PRSReadinessInputBuilder`.
///
/// Locks the Phase-41 cold-start-nil contract for BOTH `build(...)` and the new `buildDetailed(...)`,
/// and proves the extension is faithful: `build(...)` (the live `DashboardViewModel.buildDualRunMessage`
/// caller's signature) returns the SAME `ReadinessInput` as `buildDetailed(...)?.input`, and the
/// surfaced `readiness` / `strain` results are the REAL fold outputs (not defaulted) so the verdict
/// reason path is honestly sourced.
///
/// Foundation-only value tests — fixed anchor + UTC calendar, no `.now` / `Calendar.current`.
final class PRSReadinessInputBuilderTests: XCTestCase {

    // MARK: - Fixed anchor + calendar

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private var asOf: Date {
        DateComponents(calendar: calendar, year: 2026, month: 3, day: 15).date!
    }

    private func daysAgo(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: -n, to: asOf)!
    }

    private func fatigueResult(index: Double = 40) -> FatigueIndexEngine.FatigueResult {
        FatigueIndexEngine.FatigueResult(
            index: index,
            zone: FatigueIndexEngine.FatigueZone.classify(index: index),
            loadElevation: 0.4,
            sessionDensity: 0.3,
            recoveryTrend: 0.4,
            restDebt: 0.2,
            wellnessTrend: 0.3,
            softTissueRisk: 0.1
        )
    }

    /// Build ~20 days of HRV/RHR/sleep snapshots (ascending or any order — the builder sorts),
    /// so at least HRV yields a usable personal z (non-nil) per the honest-confidence gate.
    private func populatedSnapshots() -> [RecoverySnapshot] {
        (1...20).map { i in
            // Mild deterministic variation so the baseline buffer is valid (MAD > 0).
            let jitter = Double((i % 5)) - 2.0   // -2…2
            return RecoverySnapshot(
                date: daysAgo(i),
                hrvSDNN: 60 + jitter,
                restingHR: 55 + jitter * 0.5,
                sleepDurationMinutes: 420 + jitter * 10,
                recoveryScore: 55
            )
        }
    }

    // MARK: - Cold-start → nil (BOTH build and buildDetailed)

    func test_build_nil_whenNoFatigueResult() {
        let input = PRSReadinessInputBuilder.build(
            recentSnapshots: populatedSnapshots(),
            latestHRV: 58, latestRHR: 56, latestSleepMinutes: 410,
            allSessions: [], fatigueResult: nil, daysSinceRest: 1,
            wellnessScore: nil, acwr: 1.0, acwrZone: .optimal,
            asOf: asOf, calendar: calendar
        )
        XCTAssertNil(input)
    }

    func test_buildDetailed_nil_whenNoFatigueResult() {
        let built = PRSReadinessInputBuilder.buildDetailed(
            recentSnapshots: populatedSnapshots(),
            latestHRV: 58, latestRHR: 56, latestSleepMinutes: 410,
            allSessions: [], fatigueResult: nil, daysSinceRest: 1,
            wellnessScore: nil, acwr: 1.0, acwrZone: .optimal,
            asOf: asOf, calendar: calendar
        )
        XCTAssertNil(built)
    }

    func test_build_nil_whenAllPersonalZNil_pureColdStart() {
        // No history at all → every signal series empty → all three z's nil → defer (nil).
        let input = PRSReadinessInputBuilder.build(
            recentSnapshots: [],
            latestHRV: 58, latestRHR: 56, latestSleepMinutes: 410,
            allSessions: [], fatigueResult: fatigueResult(), daysSinceRest: 1,
            wellnessScore: nil, acwr: 1.0, acwrZone: .optimal,
            asOf: asOf, calendar: calendar
        )
        XCTAssertNil(input)
    }

    func test_buildDetailed_nil_whenAllPersonalZNil_pureColdStart() {
        let built = PRSReadinessInputBuilder.buildDetailed(
            recentSnapshots: [],
            latestHRV: 58, latestRHR: 56, latestSleepMinutes: 410,
            allSessions: [], fatigueResult: fatigueResult(), daysSinceRest: 1,
            wellnessScore: nil, acwr: 1.0, acwrZone: .optimal,
            asOf: asOf, calendar: calendar
        )
        XCTAssertNil(built)
    }

    // MARK: - Populated athlete → non-nil + faithful delegation

    func test_buildDetailed_nonNil_onPopulatedAthlete_surfacesRealResults() {
        let built = PRSReadinessInputBuilder.buildDetailed(
            recentSnapshots: populatedSnapshots(),
            latestHRV: 58, latestRHR: 56, latestSleepMinutes: 410,
            allSessions: [], fatigueResult: fatigueResult(), daysSinceRest: 1,
            wellnessScore: nil, acwr: 1.0, acwrZone: .optimal,
            asOf: asOf, calendar: calendar
        )
        let unwrapped = try? XCTUnwrap(built)
        XCTAssertNotNil(unwrapped)
        guard let b = unwrapped else { return }
        // The surfaced readiness/strain are REAL fold outputs (not defaulted): readiness has factors,
        // and the input's zones match the surfaced results' zones.
        XCTAssertFalse(b.readiness.factors.isEmpty)
        XCTAssertEqual(b.input.readinessZone, b.readiness.zone)
        XCTAssertEqual(b.input.strainRiskZone, b.strain.zone)
        XCTAssertGreaterThanOrEqual(b.readiness.confidence, 0)
    }

    func test_build_equals_buildDetailedInput_faithfulDelegation() {
        let input = PRSReadinessInputBuilder.build(
            recentSnapshots: populatedSnapshots(),
            latestHRV: 58, latestRHR: 56, latestSleepMinutes: 410,
            allSessions: [], fatigueResult: fatigueResult(), daysSinceRest: 1,
            wellnessScore: nil, acwr: 1.0, acwrZone: .optimal,
            asOf: asOf, calendar: calendar
        )
        let built = PRSReadinessInputBuilder.buildDetailed(
            recentSnapshots: populatedSnapshots(),
            latestHRV: 58, latestRHR: 56, latestSleepMinutes: 410,
            allSessions: [], fatigueResult: fatigueResult(), daysSinceRest: 1,
            wellnessScore: nil, acwr: 1.0, acwrZone: .optimal,
            asOf: asOf, calendar: calendar
        )
        XCTAssertNotNil(input)
        XCTAssertNotNil(built)
        // build(...) returns exactly buildDetailed(...)?.input (the same ReadinessInput).
        XCTAssertEqual(input?.readinessZone, built?.input.readinessZone)
        XCTAssertEqual(input?.strainRiskZone, built?.input.strainRiskZone)
        XCTAssertEqual(input?.readiness ?? -1, built?.input.readiness ?? -2, accuracy: 1e-9)
        XCTAssertEqual(input?.acwrContextLabel, built?.input.acwrContextLabel)
        XCTAssertEqual(input?.fatigueIndex ?? -1, built?.input.fatigueIndex ?? -2, accuracy: 1e-9)
    }
}
