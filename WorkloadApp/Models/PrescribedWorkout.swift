import Foundation
import SwiftData

@Model
final class PrescribedWorkout {
    @Attribute(.unique) var id: UUID
    var coachId: UUID
    var athleteId: UUID
    var templateId: UUID?           // nil if one-off (not from a saved template)
    var scheduledDate: Date
    var statusRawValue: String = "assigned"
    var completedSessionId: UUID?   // links to actual WorkoutSession when done
    var notes: String?
    var isSynced: Bool

    // Denormalized snapshot (frozen at assignment time)
    var templateName: String
    var sportType: SportType
    var sessionType: SessionType

    // Phase 28, Wave 4 (GA-9): PRS-v1 adjustment targets. Additive, local-only — populated ONLY by
    // the flagged `PRSDualRunSurface.adjust(...)` (no-op while PRSActivation.isEnabled == false), so
    // with the flag off they stay nil and nothing about the workout changes. Not part of the synced
    // payload (this @Model is not in SyncService's mapping). `targetRPE` is the cap applied to the
    // session; `targetVolume` is the scaled volume target. nil ⇒ unset (no adjustment yet).
    var targetRPE: Double?
    var targetVolume: Double?

    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ExerciseGroup.prescription)
    var groups: [ExerciseGroup] = []

    /// Typed accessor — not stored by SwiftData
    var status: PrescriptionStatus {
        get { PrescriptionStatus(rawValue: statusRawValue) ?? .assigned }
        set { statusRawValue = newValue.rawValue }
    }

    /// Groups sorted by order index
    var sortedGroups: [ExerciseGroup] {
        groups.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// All exercises across all groups, flattened and ordered by group then exercise order
    var allExercises: [TemplateExercise] {
        sortedGroups.flatMap { $0.sortedExercises }
    }

    init(
        id: UUID = UUID(),
        coachId: UUID,
        athleteId: UUID,
        templateId: UUID? = nil,
        scheduledDate: Date,
        templateName: String,
        sportType: SportType = .lifting,
        sessionType: SessionType = .strength,
        notes: String? = nil
    ) {
        self.id = id
        self.coachId = coachId
        self.athleteId = athleteId
        self.templateId = templateId
        self.scheduledDate = scheduledDate
        self.statusRawValue = PrescriptionStatus.assigned.rawValue
        self.completedSessionId = nil
        self.notes = notes
        self.isSynced = false
        self.templateName = templateName
        self.sportType = sportType
        self.sessionType = sessionType
        self.createdAt = .now
        self.updatedAt = .now
    }

    /// Mark this prescription as completed, linking it to the actual session.
    func markCompleted(sessionId: UUID) {
        statusRawValue = PrescriptionStatus.completed.rawValue
        completedSessionId = sessionId
        updatedAt = .now
    }

    /// Mark this prescription as skipped.
    func markSkipped() {
        statusRawValue = PrescriptionStatus.skipped.rawValue
        updatedAt = .now
    }
}
