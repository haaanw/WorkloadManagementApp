import Foundation
import SwiftData

/// Phase 45 Plan 01 — the **composite-only, local-only** measurement record for the v2.0 validation
/// loop (METRIC-01). One row captures a single planned-session verdict decision: what the surface
/// suggested vs. what was planned, whether they DIFFERED, what the athlete chose, the muscle REGION
/// label, the one-line composite reason text, and a later post-session self-reported outcome.
///
/// ## Composite-only privacy (hard guardrail)
/// This model stores ONLY composite scores / labels / deltas — the verdict label, the planned and
/// adjusted top-set kilograms and their delta, a `differed` flag, the action, a `MuscleRegion`
/// label, the already-composed reason line, an optional honest-confidence band, and the outcome.
/// It MUST NEVER store any raw recovery signal (the device-only physiological inputs the recovery
/// engine consumes). A source-grep guard asserts no raw-biometric field name appears here, mirroring
/// the project rule that only composite scores ever leave the raw signal layer.
///
/// ## Local-only by omission
/// Mirroring `SorenessLog` / `CyclePredictionLog` / `ShadowArmPrediction`: NO `Codable` conformance,
/// no encoder, no `*Row` DTO, no `push*`/`pull*` helper — the type name appears NOWHERE in
/// `SyncService.swift`. These records NEVER leave the device (privacy by omission). The inverse to
/// the owning athlete is a bare `var athlete: Athlete?` — deliberately NO `[VerdictEvent]` array on
/// `Athlete`.
///
/// ## Additive schema
/// Registered additively in the app `Schema` array (alongside `SorenessLog.self`) — no migration;
/// every existing row is unaffected.
@Model
final class VerdictEvent {
    @Attribute(.unique) var id: UUID

    /// When the athlete actually decided (real timestamp, not normalized).
    var decidedAt: Date

    /// Start-of-day of the planned session this decision belongs to. Normalized to start-of-day in
    /// `init` so day-collapse math (the green-light signal) is stable.
    var planDate: Date

    /// The headline verdict label, stored as "go" / "modify" / "hold" / "defer".
    var verdictKindRaw: String

    /// The authored planned top-set, in kilograms.
    var plannedTopSetKg: Double

    /// The suggested top-set, in kilograms; nil when the surface made no adjustment.
    var adjustedTopSetKg: Double?

    /// adjusted − planned, in kilograms; 0 when there was no adjustment.
    var deltaKg: Double

    /// True when the suggestion differed from the plan (|deltaKg| beyond a small epsilon).
    var differed: Bool

    /// The athlete's choice, stored as "accepted" / "keptPlan" / "feelStrong" / "feelRough".
    var actionRaw: String

    /// The muscle REGION label (a `MuscleRegion.rawValue`) — never a raw signal.
    var regionRaw: String

    /// The composite one-line reason text already produced by VerdictReasonBuilder (no raw numbers).
    var reasonLine: String

    /// Optional honest-confidence band text.
    var confidenceNote: String?

    /// The frozen `PrescribedWorkout.id` this decision belongs to; nil for legacy rows. A plain UUID
    /// (NOT a raw signal) that makes the loop queryable: verdict → prescription → (via the
    /// prescription's `completedSessionId`) → the completed `WorkoutSession`. Local-only like the rest.
    var prescriptionId: UUID?

    /// Structured non-weight adjustment context (composite-only, nil for legacy rows / not-applicable).
    /// Lets a volume-only or RPE-only suggestion be distinguished in analytics — `differed` is true even
    /// when `deltaKg == 0`. NEVER raw biometrics: just a set count and a target RPE cap.
    var suggestedBackoffSetCut: Int?
    var suggestedRPECap: Double?

    /// Post-session self-report: "right" / "wrong" / "unsure"; nil until reported.
    var outcomeRaw: String?

    /// When the outcome self-report was recorded; nil until reported.
    var outcomeRecordedAt: Date?

    /// v2.1 dogfood (protocol criterion 3) — the STRICT next-calendar-day "felt right?" self-report:
    /// "right" / "wrong" / "unsure"; nil until reported. Unlike `outcomeRaw` (which the looser
    /// post-session sheet may fill days later), this field is only ever written on the day after
    /// `planDate` and is write-once (never retro-rated, never edited). A missed day simply stays
    /// nil — absence IS the record. Additive nullable — no migration.
    var feltRightRaw: String?

    /// When the next-day "felt right?" self-report was recorded; nil until reported / if missed.
    var feltRightRecordedAt: Date?

    var updatedAt: Date

    /// Bare inverse to the owning athlete (mirrors `SorenessLog`). Deliberately NO array on `Athlete`.
    var athlete: Athlete?

    init(
        id: UUID = UUID(),
        decidedAt: Date = .now,
        planDate: Date = .now,
        verdictKindRaw: String,
        plannedTopSetKg: Double,
        adjustedTopSetKg: Double? = nil,
        deltaKg: Double = 0,
        differed: Bool = false,
        actionRaw: String,
        regionRaw: String,
        reasonLine: String,
        confidenceNote: String? = nil,
        prescriptionId: UUID? = nil,
        suggestedBackoffSetCut: Int? = nil,
        suggestedRPECap: Double? = nil,
        outcomeRaw: String? = nil,
        outcomeRecordedAt: Date? = nil,
        feltRightRaw: String? = nil,
        feltRightRecordedAt: Date? = nil,
        athlete: Athlete? = nil
    ) {
        self.id = id
        self.decidedAt = decidedAt
        self.planDate = Calendar.current.startOfDay(for: planDate)
        self.verdictKindRaw = verdictKindRaw
        self.plannedTopSetKg = plannedTopSetKg
        self.adjustedTopSetKg = adjustedTopSetKg
        self.deltaKg = deltaKg
        self.differed = differed
        self.actionRaw = actionRaw
        self.regionRaw = regionRaw
        self.reasonLine = reasonLine
        self.confidenceNote = confidenceNote
        self.prescriptionId = prescriptionId
        self.suggestedBackoffSetCut = suggestedBackoffSetCut
        self.suggestedRPECap = suggestedRPECap
        self.outcomeRaw = outcomeRaw
        self.outcomeRecordedAt = outcomeRecordedAt
        self.feltRightRaw = feltRightRaw
        self.feltRightRecordedAt = feltRightRecordedAt
        self.updatedAt = .now
        self.athlete = athlete
    }
}
