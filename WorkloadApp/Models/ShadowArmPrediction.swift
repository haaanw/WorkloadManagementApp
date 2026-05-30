import Foundation
import SwiftData

/// Generic per-arm shadow prediction (Phase 24, D-11/D-12). **Local-only — never syncs.**
///
/// One row per (prediction-log × experimental arm × outcome). This is the generic store that
/// lets Phases 26–28 register a new candidate predictor (a new `armId`) WITHOUT adding columns
/// to `CyclePredictionLog` — replacing the hard-coded `*Baseline`/`*CycleAware` column pairs.
/// Phase 24 registers exactly two arms (`"baseline"`, `"cycleAware"`); their predictions through
/// this store reproduce the Phase-20 cycle-shadow MAE byte-identically.
///
/// **Local-only** like its parent (`CyclePredictionLog`) and `MenstrualCycleSnapshot`: NO
/// `Codable` conformance, no encoder, no sync field — it is NEVER added to any Supabase push/pull
/// payload (D-14 / Phase 20 D-13 / Phase 17 D-12 privacy). It stores only a derived predicted
/// `Double` — no raw HealthKit or menstrual data.
@Model
final class ShadowArmPrediction {
    @Attribute(.unique) var id: UUID

    /// Stable arm identifier, e.g. `"baseline"`, `"cycleAware"` (future: `"prsBaselineV1"`).
    var armId: String
    /// The outcome this prediction is for, as a stable raw string (see `outcomeRaw(for:)`).
    var outcomeRaw: String
    /// The arm's predicted value for this outcome (units match the outcome's own scale).
    var predicted: Double

    /// Parent prediction log (cascade from the log; deleting a log deletes its arm rows).
    var log: CyclePredictionLog?

    init(
        id: UUID = UUID(),
        armId: String,
        outcomeRaw: String,
        predicted: Double
    ) {
        self.id = id
        self.armId = armId
        self.outcomeRaw = outcomeRaw
        self.predicted = predicted
    }

    convenience init(
        armId: String,
        outcome: ShadowPredictor.Outcome,
        predicted: Double
    ) {
        self.init(
            armId: armId,
            outcomeRaw: ShadowArmPrediction.outcomeRaw(for: outcome),
            predicted: predicted
        )
    }

    /// Stable raw string for an outcome (kept here so storage/query share one mapping).
    static func outcomeRaw(for outcome: ShadowPredictor.Outcome) -> String {
        switch outcome {
        case .recovery:   return "recovery"
        case .wellness:   return "wellness"
        case .completion: return "completion"  // reframed as "adherence" (D-06); raw key unchanged
        case .pain:       return "pain"
        case .niggleSeverity: return "niggleSeverity"  // P25 D-04: stable permanent key
        }
    }
}
