import Foundation
import SwiftData

/// Handles "today's planned session" persistence for the current (self-coached) athlete.
///
/// Reuse-first (PLAN-10): today's planned session is expressed as an existing `PrescribedWorkout`
/// (NOT a new parallel hierarchy). Two designation paths:
///   - `planFromTemplate` — frozen deep-copy of an existing template (the source template is never mutated)
///   - `planManualLift` — a one-off manual lift entry (templateId nil)
/// plus `fetchTodaysPlannedSession` to read back the athlete's plan for today.
///
/// Self-coached: there is no coach, so the athlete's id is reused as `coachId` (matching the
/// existing prescribe denormalization). `PrescribedWorkout` has NO sync path — this repository
/// never calls any push/sync method. The frozen working sets already carry the Plan-01 verdict
/// slots at default (nil/false), ready for the Phase-43 verdict to write.
///
/// Instantiated at point of use with ModelContext (same pattern as TemplateRepository / WorkoutRepository).
@MainActor
final class PlannedSessionRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Designate today's session from an existing template — frozen deep-copy, source untouched.
    @discardableResult
    func planFromTemplate(
        _ template: WorkoutTemplate,
        athleteId: UUID,
        scheduledDate: Date = .now
    ) -> PrescribedWorkout {
        let prescription = PrescribedWorkout(
            coachId: athleteId,            // self-coached: athlete is their own coach
            athleteId: athleteId,
            templateId: template.id,
            scheduledDate: scheduledDate,
            templateName: template.templateName,
            sportType: template.sportType,
            sessionType: template.sessionType,
            notes: template.notes
        )
        prescription.groups = template.deepCopyGroups()  // frozen snapshot — never mutates the source
        modelContext.insert(prescription)
        try? modelContext.save()
        return prescription
    }

    /// Designate today's session from a one-off manual lift entry (templateId nil).
    @discardableResult
    func planManualLift(
        athleteId: UUID,
        liftName: String,
        targetWeightKg: Double?,
        targetReps: Int?,
        targetRPE: Double? = nil,
        setCount: Int = 3,
        scheduledDate: Date = .now
    ) -> PrescribedWorkout {
        let prescription = PrescribedWorkout(
            coachId: athleteId,            // self-coached
            athleteId: athleteId,
            templateId: nil,               // one-off, not from a saved template
            scheduledDate: scheduledDate,
            templateName: liftName,
            sportType: .lifting,
            sessionType: .strength,
            notes: nil
        )

        let group = ExerciseGroup(groupName: "Group A", orderIndex: 0)
        let exercise = TemplateExercise(exerciseName: liftName, orderIndex: 0)
        exercise.sets = (0..<max(1, setCount)).map { index in
            TemplateSet(
                setIndex: index,
                targetReps: targetReps,
                targetWeightKg: targetWeightKg,
                targetRPE: targetRPE,
                isWarmup: false
            )
        }
        group.exercises = [exercise]
        prescription.groups = [group]

        modelContext.insert(prescription)
        try? modelContext.save()
        return prescription
    }

    /// The most recent non-skipped planned session scheduled for today, or nil.
    /// Fetch-all + Swift filter to avoid the optional-relationship `#Predicate` in-memory trap.
    func fetchTodaysPlannedSession(athleteId: UUID) -> PrescribedWorkout? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return nil }

        let descriptor = FetchDescriptor<PrescribedWorkout>(
            sortBy: [SortDescriptor(\.scheduledDate, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.first { prescription in
            prescription.athleteId == athleteId
                && prescription.status == .assigned   // not skipped, and NOT already completed
                && prescription.scheduledDate >= startOfDay
                && prescription.scheduledDate < endOfDay
        }
    }

    /// Mark the prescription with `prescriptionId` completed and link the saved session, then save.
    /// A focused repository method (keeps the broad fetch out of the view) — fetch-all + Swift filter
    /// to stay consistent with `fetchTodaysPlannedSession` and avoid any `#Predicate` trap.
    ///
    /// Returns `true` only when the prescription was found AND the link persisted. Returns `false`
    /// (never silently swallowed via `try?`) when the prescription is unknown or the save throws — the
    /// caller decides recovery. Doubles as the relink-by-id repair entry point.
    @discardableResult
    func markCompleted(prescriptionId: UUID, completedSessionId: UUID) -> Bool {
        let descriptor = FetchDescriptor<PrescribedWorkout>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        guard let prescription = all.first(where: { $0.id == prescriptionId }) else { return false }
        prescription.markCompleted(sessionId: completedSessionId)
        do {
            try modelContext.save()
            return true
        } catch {
            print("PlannedSessionRepository.markCompleted save failed for \(prescriptionId): \(error)")
            return false
        }
    }
}
