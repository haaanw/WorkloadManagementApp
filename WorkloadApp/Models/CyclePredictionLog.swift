import Foundation
import SwiftData

/// Append-only, **local-only** shadow-mode prediction log (Phase 20, D-01/D-13).
///
/// One row per athlete per prediction-target day. Each row captures the cycle state
/// at prediction time plus, for each of the four tracked outcomes (D-02), a competing
/// pair of predictions — a **baseline** prediction (the model WITHOUT cycle phase) and
/// a **cycle-aware** prediction (the model WITH a fixed literature-derived phase offset).
/// The observed actual for each outcome is filled in later (Stage-2 resolution, D-03),
/// letting `ShadowAnalyticsService` ask "did adding cycle phase reduce prediction error?".
///
/// This is the measurement substrate only — it never alters app behavior. It is also a
/// **local-only** model: like `MenstrualCycleSnapshot` it is NEVER added to any Supabase
/// sync payload, has NO `Codable` conformance, and no encoder/sync field (D-13 / Phase 17
/// D-12 privacy). Only derived phase/bucket/confidence/exclusion + already-computed
/// composite scores are stored — no raw menstrual records.
@Model
final class CyclePredictionLog {
    @Attribute(.unique) var id: UUID
    /// The prediction-target day (the day whose outcomes the predictions are about).
    var date: Date
    var updatedAt: Date

    // MARK: - Cycle state at prediction time

    var estimatedPhase: CyclePhase?
    /// "follicular" / "luteal" / nil (derived via RecoveryScoreEngine.bucket(for:)).
    var phaseBucketRaw: String?
    var confidence: Double
    var hadExclusion: Bool

    // MARK: - Per-outcome predictions + actuals (D-02: recovery, wellness, completion, pain)

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
        date: Date = .now,
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
        self.id = id
        self.date = date
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
}
