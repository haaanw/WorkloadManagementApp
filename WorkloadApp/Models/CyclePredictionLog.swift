import Foundation
import SwiftData

/// Append-only, **local-only** shadow-mode prediction log (Phase 20, D-01/D-13; Phase 24 data-contract).
///
/// One row per athlete per **prediction day** (the day the prediction is *made*). Each row
/// captures the cycle state at prediction time plus, for each tracked outcome (D-02), the
/// competing predictions of every registered experimental arm — written through the generic
/// `ShadowArmPrediction` child store (Phase 24, D-11/D-12). The legacy hard-coded
/// `*Baseline`/`*CycleAware` columns are RETAINED (parallel) so pre-Phase-24 shadow rows are
/// never lost; the arm store is the new source of truth going forward.
///
/// ## Phase 24 date contract (the same-day-leak fix)
/// A prediction made on day **D** is *about* day **D+1** (default horizon 1). The row therefore
/// carries two explicit dates:
/// - `predictionDate` — start-of-day of the day the prediction is *made* (the upsert key).
/// - `targetDate` — start-of-day of the day the prediction is *about* (`predictionDate +
///   predictionHorizonDays`). Stage-2 resolution joins ALL actuals on `targetDate` only, so a
///   D+1 prediction is scored against D+1's outcomes — never D's (closes codex CRITICAL #3).
/// The legacy `date` field is kept as a stored alias of `predictionDate` for migration safety
/// (additive lightweight migration on the local-only store — see SUMMARY).
///
/// This is the measurement substrate only — it never alters app behavior. It is also a
/// **local-only** model: like `MenstrualCycleSnapshot` it is NEVER added to any Supabase
/// sync payload, has NO `Codable` conformance, and no encoder/sync field (D-13 / Phase 17
/// D-12 privacy). Only derived phase/bucket/confidence/exclusion + already-computed
/// composite scores are stored — no raw menstrual records.
@Model
final class CyclePredictionLog {
    @Attribute(.unique) var id: UUID

    /// Legacy field (Phase 20). Kept as a stored alias of `predictionDate` for migration safety.
    /// Pre-Phase-24 rows populated this with the *prediction* day; it now mirrors `predictionDate`.
    var date: Date

    /// Phase 24, D-01: the day the prediction is *made* (start-of-day). The upsert key.
    var predictionDate: Date
    /// Phase 24, D-01: the day the prediction is *about* (start-of-day) =
    /// `predictionDate + predictionHorizonDays`. Resolution joins actuals on THIS day only (D-03).
    var targetDate: Date
    /// Phase 24, D-01: prediction horizon in days (default 1 = next-day). Stored so a future
    /// phase can log a multi-day-ahead arm without a schema change.
    var predictionHorizonDays: Int

    var updatedAt: Date

    // MARK: - Cycle state at prediction time

    var estimatedPhase: CyclePhase?
    /// "follicular" / "luteal" / nil (derived via RecoveryScoreEngine.bucket(for:)).
    var phaseBucketRaw: String?
    var confidence: Double
    var hadExclusion: Bool

    // MARK: - Per-arm predictions (Phase 24, D-11/D-12 — generic arm store)

    /// Generic per-arm prediction child rows: one per (registered arm × outcome). Replaces the
    /// hard-coded `*Baseline`/`*CycleAware` columns as the source of truth (those are kept in
    /// parallel for migration safety only). Cascade-deletes with the parent log.
    @Relationship(deleteRule: .cascade, inverse: \ShadowArmPrediction.log)
    var armPredictions: [ShadowArmPrediction] = []

    // MARK: - Legacy per-outcome predictions (Phase 20 — RETAINED in parallel, D-12 fallback)

    var recoveryBaseline: Double?
    var recoveryCycleAware: Double?
    var recoveryActual: Double?

    var wellnessBaseline: Double?
    var wellnessCycleAware: Double?
    var wellnessActual: Double?

    var completionBaseline: Double?
    var completionCycleAware: Double?
    var completionActual: Double?

    var painBaseline: Double?
    var painCycleAware: Double?
    var painActual: Double?

    // MARK: - Would-be modifier effects (Plan 02 helpers — recorded, NEVER applied)

    /// AutoregulationEngine.cycleVolumeFactor — would-be soft volume factor in [0.85, 1.0].
    var wouldBeVolumeFactor: Double?
    /// FatigueIndexEngine.lutealDampenedIndex — would-be dampened fatigue index (0-100).
    var wouldBeDampenedFatigueIndex: Double?
    /// ProgressionEngine.wouldBiasToMaintain — would-be late-luteal maintain-bias flag.
    var wouldBiasProgressionToMaintain: Bool?

    // MARK: - Resolution marker (Stage 2)

    /// Non-nil once Stage-2 resolution has filled in the observed actuals.
    var resolvedAt: Date?

    var athlete: Athlete?

    init(
        id: UUID = UUID(),
        predictionDate: Date = .now,
        predictionHorizonDays: Int = 1,
        estimatedPhase: CyclePhase? = nil,
        phaseBucketRaw: String? = nil,
        confidence: Double = 0.0,
        hadExclusion: Bool = false,
        recoveryBaseline: Double? = nil,
        recoveryCycleAware: Double? = nil,
        recoveryActual: Double? = nil,
        wellnessBaseline: Double? = nil,
        wellnessCycleAware: Double? = nil,
        wellnessActual: Double? = nil,
        completionBaseline: Double? = nil,
        completionCycleAware: Double? = nil,
        completionActual: Double? = nil,
        painBaseline: Double? = nil,
        painCycleAware: Double? = nil,
        painActual: Double? = nil,
        wouldBeVolumeFactor: Double? = nil,
        wouldBeDampenedFatigueIndex: Double? = nil,
        wouldBiasProgressionToMaintain: Bool? = nil,
        resolvedAt: Date? = nil
    ) {
        let calendar = Calendar.current
        let predDay = calendar.startOfDay(for: predictionDate)
        let horizon = max(0, predictionHorizonDays)
        self.id = id
        self.predictionDate = predDay
        self.date = predDay  // legacy alias
        self.predictionHorizonDays = horizon
        self.targetDate = calendar.date(byAdding: .day, value: horizon, to: predDay) ?? predDay
        self.updatedAt = .now
        self.estimatedPhase = estimatedPhase
        self.phaseBucketRaw = phaseBucketRaw
        self.confidence = confidence
        self.hadExclusion = hadExclusion
        self.recoveryBaseline = recoveryBaseline
        self.recoveryCycleAware = recoveryCycleAware
        self.recoveryActual = recoveryActual
        self.wellnessBaseline = wellnessBaseline
        self.wellnessCycleAware = wellnessCycleAware
        self.wellnessActual = wellnessActual
        self.completionBaseline = completionBaseline
        self.completionCycleAware = completionCycleAware
        self.completionActual = completionActual
        self.painBaseline = painBaseline
        self.painCycleAware = painCycleAware
        self.painActual = painActual
        self.wouldBeVolumeFactor = wouldBeVolumeFactor
        self.wouldBeDampenedFatigueIndex = wouldBeDampenedFatigueIndex
        self.wouldBiasProgressionToMaintain = wouldBiasProgressionToMaintain
        self.resolvedAt = resolvedAt
    }

    // MARK: - Arm-store helpers (Phase 24)

    /// The predicted value for a given arm + outcome from the generic arm store (nil if absent).
    func armPrediction(armId: String, outcome: ShadowPredictor.Outcome) -> Double? {
        let key = ShadowArmPrediction.outcomeRaw(for: outcome)
        return armPredictions.first { $0.armId == armId && $0.outcomeRaw == key }?.predicted
    }
}
