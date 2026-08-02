import Foundation
import SwiftData

/// Local-only — never syncs to Supabase (Phase 26, §6).
///
/// Carries the per-athlete **robust-baseline running state** for all three recovery signals
/// (HRV / RHR / sleep). It is the single mutable carrier the stateless `BaselineEngine` (Plan 02)
/// reads into a value mirror and writes back, and that the convergence report (Plan 04) and any
/// future Phase-28 consumer load from.
///
/// ## One row per athlete, flattened sub-states (resolves RESEARCH open-question #2 by decision)
/// Rather than three rows per athlete (one per signal), the three signal sub-states are embedded
/// in a single row keyed by athlete and **flattened** as `hrv*` / `rhr*` / `sleep*`-prefixed scalar
/// fields (SwiftData `@Model` can't nest a Codable sub-struct, and `Codable` is forbidden here).
/// This yields fewer rows and an atomic upsert, mirroring how `CyclePredictionLog` holds many
/// parallel columns.
///
/// ## Engine-stateless invariant (§6.3)
/// This `@Model` is a **dumb carrier** — it holds state but contains NO statistics math. The
/// `BaselineEngine` (Plan 02) does all EWMA / Welford / MAD / Huber computation on a plain value
/// mirror and writes results back here.
///
/// ## Local-only (privacy-by-omission), mirroring `SorenessLog` / `CyclePredictionLog` /
/// `ShadowArmPrediction` / `MenstrualCycleSnapshot`:
/// NO `Codable` conformance, no encoder, no `*Row` DTO, no `push*`/`pull*` helper — the type name
/// appears NOWHERE in `SyncService.swift`. This HealthKit-derived baseline state NEVER leaves the
/// device (HealthKit constraint: only composite scores sync; Phase 17 D-12 / Phase 24 D-14 privacy).
///
/// Additive standalone model with a bare optional `athlete?` inverse ⇒ SwiftData lightweight
/// automatic migration (no `MigrationPlan`), matching the `SorenessLog` / `ShadowArmPrediction`
/// precedent.
@Model
final class BaselineState {
    @Attribute(.unique) var id: UUID

    /// Bare inverse to the owning athlete — matches `SorenessLog.athlete` / `WellnessCheckIn.athlete`.
    /// Deliberately NO `[BaselineState]` array on `Athlete`.
    var athlete: Athlete?

    var updatedAt: Date

    // MARK: - HRV sub-state

    /// EWMA baseline μ — Optional so "no fold yet" (nil) is distinguishable from "μ == 0".
    var hrvMu: Double?
    /// SEPARATE simple running mean for Welford (NOT the EWMA μ; different estimators, §1.2).
    var hrvWelfordMean: Double
    /// Welford sum-of-squared-deviations.
    var hrvM2: Double
    /// Count of valid (non-gap) folds.
    var hrvCount: Int
    /// Last W innovations (SwiftData persists `[Double]` of scalars natively, A7).
    var hrvMadBuffer: [Double]
    /// Monotonic last-bucketed-date cutoff (§2.4 idempotency).
    var hrvLastBucketedDate: Date?
    /// Last §3 dispersion ratio (for hysteresis).
    var hrvCvRatio: Double?
    /// "normal" / "elevated" / "high" hysteresis state.
    var hrvCvLevelRaw: String
    /// Last §4 confidence.
    var hrvConfidence: Double

    // MARK: - RHR sub-state

    var rhrMu: Double?
    var rhrWelfordMean: Double
    var rhrM2: Double
    var rhrCount: Int
    var rhrMadBuffer: [Double]
    var rhrLastBucketedDate: Date?
    var rhrCvRatio: Double?
    var rhrCvLevelRaw: String
    var rhrConfidence: Double

    // MARK: - Sleep sub-state

    var sleepMu: Double?
    var sleepWelfordMean: Double
    var sleepM2: Double
    var sleepCount: Int
    var sleepMadBuffer: [Double]
    var sleepLastBucketedDate: Date?
    var sleepCvRatio: Double?
    var sleepCvLevelRaw: String
    var sleepConfidence: Double

    // MARK: - Sleep v2 sub-state (Phase S2 — research-sleep-score.md §4, §9.2)
    //
    // Same rules as the sub-states above: flattened `sleepV2`-prefixed scalars, NO Codable,
    // NO math in the model — `SleepStateBuilder` (the stateless folder) does every update on
    // a value mirror and the pipeline writes the result back. Every field is Optional or has
    // an inline default so SwiftData lightweight migration succeeds on existing stores.
    // Local-only like the rest of this model: raw stage minutes and timing history NEVER
    // sync (the type stays absent from SyncService.swift — grep-gated by
    // BaselineStateModelTests.test_baselineState_isAbsentFromSyncService).

    /// EWMA baseline of nightly deep-sleep minutes, **same-source only** (H-04). nil = no
    /// fold yet since the last source reset (§4 reset-on-discontinuity).
    var sleepV2DeepMu: Double? = nil
    /// Count of deep-minute folds into `sleepV2DeepMu` since the last source reset. Below
    /// the H-21 minimum the baseline carries no scoring authority.
    var sleepV2DeepCount: Int = 0
    /// EWMA baseline of nightly REM minutes, same-source only (H-04). nil = no fold yet.
    var sleepV2RemMu: Double? = nil
    /// Count of REM folds into `sleepV2RemMu` since the last source reset.
    var sleepV2RemCount: Int = 0
    /// Bundle id of the dominant sleep source the stage baselines are keyed to. A change
    /// here restarts the stage baselines and re-gates need learning (§4 reset rule).
    var sleepV2DominantSourceID: String? = nil
    /// Nights folded since the dominant source last changed; nil = no change ever observed.
    /// Below the H-20 window the engine input reads `isSourceStable == false` (H-15).
    var sleepV2NightsSinceSourceChange: Int? = nil
    /// Trailing ≤14 sleep midpoints, minutes relative to the wake-day midnight (negative =
    /// before midnight). The §9.2 `midpointSD14` / `midpointDeviation` input, kept as a
    /// rolling buffer like the `*MadBuffer` fields above.
    var sleepV2MidpointBuffer: [Double] = []
    /// Trailing ≤14 per-night irregularity flags (1.0 = that night's midpoint SD14 exceeded
    /// the §9.3 chronic entry threshold of 75 min; 0.0 otherwise). Sum = the §9.2
    /// `irregularNightsIn14` counter the CHRONIC_IRREGULAR entry rule reads.
    var sleepV2IrregularFlags14: [Double] = []
    /// Nights since the last rhythm break (|midpoint deviation| > max(2×SD14, 90 min),
    /// §9.2); nil = no break observed yet. Feeds `daysSinceRhythmBreak` (ACUTE_SHIFT).
    var sleepV2NightsSinceRhythmBreak: Int? = nil
    /// Consecutive nights with midpoint SD14 below the §9.3 chronic EXIT threshold (50 min).
    /// The §9.2 `nightsBelowChronicExitSD` counter behind the 5-night exit run.
    var sleepV2NightsBelowChronicExitSD: Int = 0
    /// Trailing ≤7 nightly deficits `max(0, need_tonight − TST)` in minutes (§4 debt
    /// credit input; the sum, capped at 6 h, is §9.2's `sleepDebt7`).
    var sleepV2DeficitBuffer7: [Double] = []
    /// Trailing ≤90 nightly TST minutes — the §4 need estimator's input (H-19). Cleared on
    /// a dominant-source change so the 28-night gate re-runs on the new source's data.
    var sleepV2TSTBuffer: [Double] = []
    /// Learned personal sleep need in minutes, bounded [390, 570] (§4). nil = the
    /// personalization gate has not opened → the engine scores against the 7.5 h cold start.
    var sleepV2NeedBaseMinutes: Double? = nil
    /// Date of the last weekly need recompute (§4 cadence: weekly, never nightly).
    var sleepV2NeedUpdatedAt: Date? = nil
    /// True while need learning is FROZEN by a latched CHRONIC_IRREGULAR state (§7 Q9).
    /// Stored for audit; the builder recomputes it from each night's latch.
    var sleepV2NeedFrozen: Bool = false
    /// Total nights folded into this sub-state (tier gate + confidence input, §5.2).
    var sleepV2NightsOfHistory: Int = 0
    /// Last night's LATCHED profile set, raw `SleepProfile` strings — handed back to the
    /// engine as `previousProfiles` so every §9.4 rule-4 entry/exit hysteresis works.
    var sleepV2PreviousProfilesRaw: [String] = []
    /// End of the previous main-sleep session — the §9.2 `priorWakeHours` input.
    var sleepV2LastSleepEndDate: Date? = nil
    /// Monotonic once-per-day fold cutoff, mirroring the `*LastBucketedDate` fields (§2.4
    /// idempotency): the pipeline folds only when the wake day is strictly after this.
    var sleepV2LastFoldedDate: Date? = nil
    /// Trailing ≤28 valid prior-wake spans in HOURS (the §9.2 `priorWakeZ` input, Phase S3 —
    /// H-34). Only spans inside the H-22 sanity window (0, 48 h] are pushed; the buffer is a
    /// rolling drop-oldest ring like `sleepV2MidpointBuffer`. Additive NON-optional field
    /// with an inline `[]` default (not nullable) — the inline default is what makes the
    /// lightweight migration safe.
    var sleepV2PriorWakeBuffer: [Double] = []

    /// Memberwise init that ZERO-inits every accumulator (cold state). The engine (Plan 02) fills
    /// these in as folds arrive.
    init(id: UUID = UUID(), athlete: Athlete? = nil) {
        self.id = id
        self.athlete = athlete
        self.updatedAt = .now

        // HRV
        self.hrvMu = nil
        self.hrvWelfordMean = 0.0
        self.hrvM2 = 0.0
        self.hrvCount = 0
        self.hrvMadBuffer = []
        self.hrvLastBucketedDate = nil
        self.hrvCvRatio = nil
        self.hrvCvLevelRaw = "normal"
        self.hrvConfidence = 0.0

        // RHR
        self.rhrMu = nil
        self.rhrWelfordMean = 0.0
        self.rhrM2 = 0.0
        self.rhrCount = 0
        self.rhrMadBuffer = []
        self.rhrLastBucketedDate = nil
        self.rhrCvRatio = nil
        self.rhrCvLevelRaw = "normal"
        self.rhrConfidence = 0.0

        // Sleep
        self.sleepMu = nil
        self.sleepWelfordMean = 0.0
        self.sleepM2 = 0.0
        self.sleepCount = 0
        self.sleepMadBuffer = []
        self.sleepLastBucketedDate = nil
        self.sleepCvRatio = nil
        self.sleepCvLevelRaw = "normal"
        self.sleepConfidence = 0.0
    }
}
