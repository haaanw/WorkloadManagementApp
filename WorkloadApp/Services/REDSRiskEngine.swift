import Foundation

/// Pure, deterministic classifier for surfacing a non-diagnostic "cycle pattern change"
/// monitoring state (RED-S adjacent — Relative Energy Deficiency in Sport). Phase 19 D-10/D-11/D-14.
///
/// SAFETY / SCOPE:
/// - The engine NEVER diagnoses and emits NO user-facing string and NO numeric risk score.
///   It returns only a coarse display state (`.none` / `.monitor`); copy lives in the views
///   via localized keys (D-12).
/// - It is a pure struct with static methods only (no HealthKit / SwiftData / Calendar / Date).
///   Callers pass precomputed aggregate Ints + Bool exclusion flags — never raw menstrual
///   records (T-19-02 information-disclosure mitigation).
/// - Exclusions are evaluated FIRST and short-circuit (D-11): an excluded user never sees
///   the monitor state regardless of cycle pattern, because irregular/absent cycles are
///   expected for them and an alert would be a false alarm.
struct REDSRiskEngine {

    /// Coarse, non-diagnostic display state. `.monitor` is a "consider checking", never a diagnosis.
    enum RiskState {
        case none
        case monitor
    }

    /// Aggregate, privacy-preserving input. All values are precomputed by the caller
    /// (view layer) from local-only snapshots; the engine performs no I/O.
    struct CycleHistoryInput {
        /// Computed cycle lengths (day-diffs between consecutive cycle starts), most-recent last.
        let recentCycleLengths: [Int]
        /// Median of historical cycle lengths, if computable.
        let medianCycleLength: Int?
        /// Days elapsed since the most recent detected cycle start, if any.
        let daysSinceLastCycleStart: Int?
        /// True when cycle snapshot data is otherwise present (guards against sparse-data false positives).
        let hasSnapshotData: Bool
        let isPregnant: Bool
        let isLactating: Bool
        let isOnHormonalContraceptive: Bool
        let hasPCOS: Bool
        let isPerimenopausal: Bool
    }

    // MARK: - Thresholds (D-10)

    /// A cycle length above this (days) is considered long / oligomenorrheic.
    private static let longCycleThreshold = 35
    /// Number of consecutive recent cycles that must all be long to trigger the long-cycle rule.
    private static let longCycleRunCount = 3
    /// Conservative floor (days) for the missed-period proxy, regardless of median (D-14).
    private static let missedPeriodFloorDays = 90

    // MARK: - Classification

    /// Classify cycle history into a non-diagnostic monitoring display state.
    ///
    /// Order (D-10/D-11/D-14):
    /// 1. Exclusion gate FIRST — any exclusion -> `.none`.
    /// 2. No snapshot data -> `.none` (never a false positive on absent data).
    /// 3. Long-cycle rule: the 3 most recent cycle lengths all > 35 -> `.monitor`.
    /// 4. Missed-period rule: daysSinceLastCycleStart >= max(3 * median, 90) -> `.monitor`.
    /// 5. Otherwise `.none`.
    static func classify(input: CycleHistoryInput) -> RiskState {
        // 1. Exclusion gate — evaluated first, short-circuits (D-11).
        if input.isPregnant
            || input.isLactating
            || input.isOnHormonalContraceptive
            || input.hasPCOS
            || input.isPerimenopausal {
            return .none
        }

        // 2. No data -> no alert (D-14 conservative).
        guard input.hasSnapshotData else { return .none }

        // 3. Long-cycle rule (D-10): the most recent `longCycleRunCount` lengths all > threshold.
        let recent = input.recentCycleLengths.suffix(longCycleRunCount)
        if recent.count >= longCycleRunCount && recent.allSatisfy({ $0 > longCycleThreshold }) {
            return .monitor
        }

        // 4. Missed-period rule (D-10): conservative 3x-median proxy with a floor.
        if let daysSince = input.daysSinceLastCycleStart,
           let median = input.medianCycleLength,
           median > 0 {
            let threshold = max(3 * median, missedPeriodFloorDays)
            if daysSince >= threshold {
                return .monitor
            }
        }

        // 5. No pattern -> none.
        return .none
    }
}
