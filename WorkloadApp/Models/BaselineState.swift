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
