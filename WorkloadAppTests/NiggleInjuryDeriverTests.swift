import XCTest
@testable import workload_management

/// Phase 25 Plan 03 — `NiggleInjuryDeriver` pure-helper tests (D-10/D-11/D-13).
///
/// The deriver is a pure static helper over `[SorenessLog]` arrays, so these tests build plain
/// `SorenessLog` instances via the model init (no `ModelContainer`/`ModelContext` needed — nothing
/// is persisted). This sidesteps the iOS 26.1 in-memory SwiftData optional-relationship `#Predicate`
/// trap entirely.
///
/// Highest-value coverage: the DOMS-exclusion (a routine `soreness`-type log NEVER inflates the
/// injury count) and the qualification-rule edges (type / functional-impact / severity / window).
final class NiggleInjuryDeriverTests: XCTestCase {

    // MARK: - Helpers

    /// A fixed reference "now" (start-of-day) so day-diff math is deterministic across runs.
    private let asOf: Date = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))

    /// Build a `SorenessLog` at `daysAgo` from `asOf` (start-of-day anchored).
    private func log(
        type: NiggleType,
        severity: Int,
        limitedTraining: Bool,
        daysAgo: Int
    ) -> SorenessLog {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: asOf) ?? asOf
        return SorenessLog(
            date: date,
            regionRaw: MuscleGroup.legs.rawValue,
            typeRaw: type.rawValue,
            severity: severity,
            limitedTraining: limitedTraining
        )
    }

    // MARK: - Named constants (D-13)

    func test_constants_areNamedAndSane() {
        XCTAssertEqual(NiggleInjuryDeriver.qualifyingSeverityCut, 7)
        XCTAssertEqual(NiggleInjuryDeriver.injuryWindowDays, 28)
    }

    // MARK: - DOMS exclusion (highest-value, D-10)

    /// A `soreness`-type log, severity 10, limitedTraining true, today → NOT counted.
    func test_domsExclusion_sorenessNeverCounts_evenAtMaxSeverityAndLimited() {
        let logs = [log(type: .soreness, severity: 10, limitedTraining: true, daysAgo: 0)]
        XCTAssertEqual(NiggleInjuryDeriver.softTissueInjuryCount(logs: logs, asOf: asOf), 0)
        XCTAssertNil(NiggleInjuryDeriver.daysSinceLastInjury(logs: logs, asOf: asOf))
    }

    // MARK: - Qualification rule (D-10)

    /// impact-only: `pain`, severity 3, limitedTraining true, today → counted.
    func test_impactOnly_painLowSeverityButLimited_counts() {
        let logs = [log(type: .pain, severity: 3, limitedTraining: true, daysAgo: 0)]
        XCTAssertEqual(NiggleInjuryDeriver.softTissueInjuryCount(logs: logs, asOf: asOf), 1)
    }

    /// severity-only: `tweak`, severity 8, limitedTraining false, today → counted.
    func test_severityOnly_tweakHighSeverityNotLimited_counts() {
        let logs = [log(type: .tweak, severity: 8, limitedTraining: false, daysAgo: 0)]
        XCTAssertEqual(NiggleInjuryDeriver.softTissueInjuryCount(logs: logs, asOf: asOf), 1)
    }

    /// neither: `pain`, severity 3, limitedTraining false, today → NOT counted.
    func test_neither_painLowSeverityNotLimited_doesNotCount() {
        let logs = [log(type: .pain, severity: 3, limitedTraining: false, daysAgo: 0)]
        XCTAssertEqual(NiggleInjuryDeriver.softTissueInjuryCount(logs: logs, asOf: asOf), 0)
    }

    /// severity threshold boundary: severity == cut (7) qualifies; severity == cut-1 (6) does not.
    func test_severityThreshold_inclusiveAtCut() {
        let atCut = [log(type: .pain, severity: 7, limitedTraining: false, daysAgo: 0)]
        let belowCut = [log(type: .pain, severity: 6, limitedTraining: false, daysAgo: 0)]
        XCTAssertEqual(NiggleInjuryDeriver.softTissueInjuryCount(logs: atCut, asOf: asOf), 1)
        XCTAssertEqual(NiggleInjuryDeriver.softTissueInjuryCount(logs: belowCut, asOf: asOf), 0)
    }

    // MARK: - Window edge (28d inclusive)

    /// A qualifying `pain` log at day -28 (boundary) → counted; at day -29 (outside) → NOT counted.
    func test_windowEdge_day28Inclusive_day29Excluded() {
        let atBoundary = [log(type: .pain, severity: 8, limitedTraining: false, daysAgo: 28)]
        let outside = [log(type: .pain, severity: 8, limitedTraining: false, daysAgo: 29)]
        XCTAssertEqual(NiggleInjuryDeriver.softTissueInjuryCount(logs: atBoundary, asOf: asOf), 1)
        XCTAssertEqual(NiggleInjuryDeriver.softTissueInjuryCount(logs: outside, asOf: asOf), 0)
    }

    // MARK: - Count (no region-dedup, v1 — RESEARCH §4 A3)

    /// Two qualifying logs (same region) → count 2 (no region-dedup in v1).
    func test_count_twoQualifyingSameRegion_countsBoth() {
        let logs = [
            log(type: .pain, severity: 8, limitedTraining: false, daysAgo: 1),
            log(type: .tweak, severity: 3, limitedTraining: true, daysAgo: 2)
        ]
        XCTAssertEqual(NiggleInjuryDeriver.softTissueInjuryCount(logs: logs, asOf: asOf), 2)
    }

    /// Non-qualifying logs mixed in are ignored; only qualifying ones count.
    func test_count_mixedQualifyingAndNot_onlyQualifyingCount() {
        let logs = [
            log(type: .pain, severity: 9, limitedTraining: false, daysAgo: 0),   // qualifies (severity)
            log(type: .soreness, severity: 10, limitedTraining: true, daysAgo: 0), // DOMS — excluded
            log(type: .pain, severity: 2, limitedTraining: false, daysAgo: 0),   // neither — excluded
            log(type: .tweak, severity: 1, limitedTraining: true, daysAgo: 0)    // qualifies (impact)
        ]
        XCTAssertEqual(NiggleInjuryDeriver.softTissueInjuryCount(logs: logs, asOf: asOf), 2)
    }

    // MARK: - daysSinceLastInjury (D-11)

    /// Returns the start-of-day day-diff to the most recent qualifying log.
    func test_daysSince_mostRecentQualifying() {
        let logs = [
            log(type: .pain, severity: 9, limitedTraining: false, daysAgo: 10),
            log(type: .tweak, severity: 8, limitedTraining: false, daysAgo: 3)   // most recent qualifying
        ]
        XCTAssertEqual(NiggleInjuryDeriver.daysSinceLastInjury(logs: logs, asOf: asOf), 3)
    }

    /// Most-recent NON-qualifying log is ignored; days-since uses the most recent QUALIFYING log.
    func test_daysSince_ignoresMoreRecentNonQualifying() {
        let logs = [
            log(type: .pain, severity: 9, limitedTraining: false, daysAgo: 5),    // qualifying
            log(type: .soreness, severity: 10, limitedTraining: true, daysAgo: 1) // DOMS — ignored
        ]
        XCTAssertEqual(NiggleInjuryDeriver.daysSinceLastInjury(logs: logs, asOf: asOf), 5)
    }

    /// Qualifying log today → days-since 0.
    func test_daysSince_today_isZero() {
        let logs = [log(type: .pain, severity: 8, limitedTraining: false, daysAgo: 0)]
        XCTAssertEqual(NiggleInjuryDeriver.daysSinceLastInjury(logs: logs, asOf: asOf), 0)
    }

    // MARK: - Empty / no-qualifying data

    func test_empty_countZero_daysSinceNil() {
        XCTAssertEqual(NiggleInjuryDeriver.softTissueInjuryCount(logs: [], asOf: asOf), 0)
        XCTAssertNil(NiggleInjuryDeriver.daysSinceLastInjury(logs: [], asOf: asOf))
    }

    func test_onlyNonQualifying_countZero_daysSinceNil() {
        let logs = [
            log(type: .soreness, severity: 10, limitedTraining: true, daysAgo: 0),
            log(type: .pain, severity: 2, limitedTraining: false, daysAgo: 0)
        ]
        XCTAssertEqual(NiggleInjuryDeriver.softTissueInjuryCount(logs: logs, asOf: asOf), 0)
        XCTAssertNil(NiggleInjuryDeriver.daysSinceLastInjury(logs: logs, asOf: asOf))
    }
}
