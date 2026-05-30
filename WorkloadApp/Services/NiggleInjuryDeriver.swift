import Foundation

/// Derives the two soft-tissue fatigue inputs (`softTissueInjuryCount` / `daysSinceLastInjury`)
/// that `FatigueIndexEngine.computeSoftTissueRisk` consumes, from the local-only niggle self-log
/// (`SorenessLog`). Pure struct with static methods — no state, no SwiftData/HealthKit import —
/// mirroring `FatigueIndexEngine.baselineSessionsPer14Days` (takes a model array, returns a
/// primitive; Foundation-only).
///
/// ## Qualification rule (D-10 — functional, NOT severity-only and NOT impact-only)
/// A niggle counts as a soft-tissue injury signal iff:
///   1. its type ∈ {`pain`, `tweak`} — routine `soreness` (DOMS) is EXCLUDED, and
///   2. it was functionally impactful: `limitedTraining == true` OR `severity >= qualifyingSeverityCut`, and
///   3. it falls within the last `injuryWindowDays` (inclusive of the day -28 boundary).
///
/// The DOMS exclusion is load-bearing: a routine `soreness`-type log — even at severity 10 with
/// limitedTraining true — NEVER inflates the injury count. This is what separates this honest
/// "load-tolerance context" from spurious fatigue inflation; it is unit-tested.
///
/// ## Framing
/// This produces only an `Int` count + an optional day-diff that feed the fatigue engine locally.
/// It is **load-tolerance context**, never an injury *prediction*. No persistence, no sync.
///
/// ## Window / count semantics (RESEARCH §4 A3, v1)
/// "Distinct active" = qualifying logs within the window — no region-dedup and no resolution
/// tracking in v1 (deferred). Two qualifying logs in the same region count as 2.
struct NiggleInjuryDeriver {

    // MARK: - Tunable named constants (D-13)

    /// Severity (0–10) at or above which a `pain`/`tweak` niggle qualifies even without the
    /// limited-training flag. Tunable, not user-locked (D-13).
    static let qualifyingSeverityCut: Int = 7

    /// Recency window (days) over which qualifying niggles are counted. Inclusive of the
    /// day -`injuryWindowDays` boundary (a log exactly `injuryWindowDays` days ago still counts).
    /// Tunable (D-13); deliberately narrower than the engine doc's "12 months" — the soft-tissue
    /// math is window-agnostic (RESEARCH / interfaces note).
    static let injuryWindowDays: Int = 28

    // MARK: - Public derivations

    /// Count of qualifying niggles within the window (no region-dedup, v1).
    static func softTissueInjuryCount(logs: [SorenessLog], asOf: Date = .now) -> Int {
        logs.filter { isQualifying($0, asOf: asOf) }.count
    }

    /// Whole-day difference from the most recent qualifying niggle to `asOf` (start-of-day on both
    /// ends), or `nil` if there is no qualifying niggle in the window. A qualifying log today → 0.
    static func daysSinceLastInjury(logs: [SorenessLog], asOf: Date = .now) -> Int? {
        let calendar = Calendar.current
        let mostRecent = logs
            .filter { isQualifying($0, asOf: asOf) }
            .map(\.date)
            .max()
        guard let mostRecent else { return nil }
        let from = calendar.startOfDay(for: mostRecent)
        let to = calendar.startOfDay(for: asOf)
        return calendar.dateComponents([.day], from: from, to: to).day
    }

    // MARK: - Qualification predicate (D-10)

    /// Encodes the D-10 rule: type ∈ {pain, tweak} AND (limitedTraining OR severity ≥ cut) AND
    /// within `injuryWindowDays` of `asOf` (boundary day -`injuryWindowDays` inclusive). `soreness`
    /// (DOMS) is excluded by the type gate.
    private static func isQualifying(_ log: SorenessLog, asOf: Date) -> Bool {
        guard let type = NiggleType(rawValue: log.typeRaw),
              type == .pain || type == .tweak else {
            return false  // soreness (DOMS) and any unknown type → excluded
        }
        let functionallyImpactful = log.limitedTraining || log.severity >= qualifyingSeverityCut
        guard functionallyImpactful else { return false }
        return isWithinWindow(log.date, asOf: asOf)
    }

    /// True when `date` falls within the last `injuryWindowDays` of `asOf`, comparing on
    /// `Calendar.startOfDay` so the day -`injuryWindowDays` boundary is inclusive and future-dated
    /// logs (negative diff) are excluded.
    private static func isWithinWindow(_ date: Date, asOf: Date) -> Bool {
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: date)
        let to = calendar.startOfDay(for: asOf)
        guard let days = calendar.dateComponents([.day], from: from, to: to).day else { return false }
        return days >= 0 && days <= injuryWindowDays
    }
}
