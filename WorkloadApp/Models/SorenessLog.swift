import Foundation
import SwiftData

/// Local-only — never syncs to Supabase (P25 D-01).
///
/// A dedicated, on-device self-log for localized niggles (soreness / pain / tweak), **distinct
/// from** the whole-body `WellnessCheckIn.soreness` path (which is left completely untouched —
/// D-01/D-05). One row captures a single self-reported event: which region, what kind, how bad,
/// whether it limited training, and an optional free-text note.
///
/// This is the single source of localized breakdown signal that both downstream halves consume:
/// the `.niggleSeverity` shadow outcome (Plan 02) and the fatigue-input derivation (Plan 03), and
/// it feeds Phase 27's localized Strain-Risk channel.
///
/// **Local-only**, mirroring `CyclePredictionLog` / `ShadowArmPrediction` / `MenstrualCycleSnapshot`:
/// NO `Codable` conformance, no encoder, no `*Row` DTO, no `push*`/`pull*` helper — the type name
/// appears NOWHERE in `SyncService.swift`. This health-adjacent localized pain data NEVER leaves the
/// device (privacy by omission, D-01 / Phase 24 D-14 / Phase 17 D-12).
@Model
final class SorenessLog {
    @Attribute(.unique) var id: UUID

    /// Real timestamp of the self-report (NOT forced to start-of-day; window math applies
    /// `Calendar.startOfDay` at read time in the repository).
    var date: Date

    /// Stored as a `MuscleGroup.rawValue` (taxonomy-aligned for Phase 27, per RESEARCH §2 / D-02).
    /// NOT a `MuscleRegion` and NOT a `BodyRegion`.
    var regionRaw: String

    /// Stored as a `NiggleType.rawValue` ("soreness"/"pain"/"tweak").
    var typeRaw: String

    /// Severity on a 0–10 integer scale (RESEARCH §1; the shadow outcome converts to `Double` at
    /// resolution time — stored as `Int` here).
    var severity: Int

    /// The functional-impact discriminator (D-03): did this niggle limit training? Required, defaults
    /// to `false`.
    var limitedTraining: Bool

    /// Optional local-only free-text note (e.g. "left hamstring").
    var note: String?

    var updatedAt: Date

    /// Bare inverse to the owning athlete — matches `WellnessCheckIn`'s `var athlete: Athlete?`
    /// pattern. Deliberately NO `[SorenessLog]` array on `Athlete`.
    var athlete: Athlete?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        regionRaw: String,
        typeRaw: String,
        severity: Int,
        limitedTraining: Bool = false,
        note: String? = nil,
        athlete: Athlete? = nil
    ) {
        self.id = id
        self.date = date
        self.regionRaw = regionRaw
        self.typeRaw = typeRaw
        self.severity = severity
        self.limitedTraining = limitedTraining
        self.note = note
        self.updatedAt = .now
        self.athlete = athlete
    }
}
