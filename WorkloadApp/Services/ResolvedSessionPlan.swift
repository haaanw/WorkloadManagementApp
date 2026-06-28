import Foundation

/// The **canonical, immutable resolved plan** — the single source of truth for the exact workout an
/// accepted (or kept) TODAY verdict turns into. It freezes, at the moment of an explicit decision, the
/// numbers the athlete will actually train: weight + RPE resolved through `VerdictDecisionApplier`
/// (accept ⇒ adjusted, keep/pending ⇒ authored), with reps/RIR/duration/distance/warm-up carried
/// straight from the authored frozen prescription.
///
/// ## Why a separate value type
/// `ActiveWorkoutSheet` must launch from a verdict WITHOUT consulting history or `ProgressionEngine`
/// (those would overwrite the verdict's numbers). Resolving once into a plain value — no SwiftData, no
/// engine, no fetch — lets the sheet populate its drafts verbatim and keeps the resolution rule in ONE
/// pure, testable place. Resolution NEVER mutates the prescription or the source template.
///
/// ## Resolution rules (mirrors `VerdictDecisionApplier`)
///  - `weightKg` uses `VerdictDecisionApplier.effectiveTargetKg` — adjusted only once accepted, else authored.
///  - `rpe` uses `VerdictDecisionApplier.effectiveTargetRPE` — same accept/keep semantics; authored when
///    no accepted adjustment exists (and there is no adjusted RPE to surface unless one was authored).
///  - `reps` / `rir` / `durationSeconds` / `distanceMeters` / `isWarmup` are always the authored values.
struct ResolvedSessionPlan: Equatable {

    /// Stable identity of the frozen prescription this plan resolves (the verdict → session link key).
    let prescriptionID: UUID
    /// The source template the prescription was frozen from, or nil for a one-off manual lift.
    let sourceTemplateID: UUID?

    let sessionName: String
    let sportType: SportType
    let sessionType: SessionType

    /// Ordered exercises (group order → exercise order), each with its ordered resolved sets.
    let exercises: [ResolvedExercise]

    struct ResolvedExercise: Equatable {
        /// Stable identity of the authored frozen `TemplateExercise` (traceability).
        let sourceExerciseID: UUID
        let exerciseName: String
        let exerciseCategory: ExerciseCategory
        let muscleGroup: MuscleGroup?
        let groupName: String?
        let sets: [ResolvedSet]
    }

    struct ResolvedSet: Equatable {
        /// Stable identity of the authored frozen `TemplateSet` (traceability + deterministic order).
        let sourceSetID: UUID
        /// Authored set index — preserves deterministic order after a volume cut filters rows out.
        let setIndex: Int
        let reps: Int?
        /// Authored planned weight before verdict resolution. Used only for display/audit copy.
        let plannedWeightKg: Double?
        /// Resolved training weight (kg) — `effectiveTargetKg` of the authored set.
        let weightKg: Double?
        /// Authored planned RPE before verdict resolution. Used only for display/audit copy.
        let plannedRPE: Double?
        /// Resolved RPE — `effectiveTargetRPE` of the authored set.
        let rpe: Double?
        /// Authored planned RIR target (carried as a target, never an achieved value).
        let rir: Int?
        let durationSeconds: Int?
        let distanceMeters: Double?
        let isWarmup: Bool
        /// True when this row is the accepted verdict suggestion rather than a plain authored target.
        let isSuggestedAdjustment: Bool
        /// Composite-only reason text written by the verdict service. Never contains raw HealthKit.
        let verdictReason: String?
    }
}

extension ResolvedSessionPlan {

    /// Pure resolver: snapshot the frozen prescription into an immutable plan, resolving weight + RPE
    /// at read time through `VerdictDecisionApplier` and applying any ACCEPTED back-off volume cut.
    /// Reads only — never mutates the prescription, its sets, or the source template (the cut filters
    /// the immutable value, it does NOT delete SwiftData rows).
    static func resolve(from prescription: PrescribedWorkout) -> ResolvedSessionPlan {
        let exercises: [ResolvedExercise] = prescription.sortedGroups.flatMap { group in
            group.sortedExercises.map { exercise in
                resolveExercise(exercise, groupName: group.groupName)
            }
        }

        return ResolvedSessionPlan(
            prescriptionID: prescription.id,
            sourceTemplateID: prescription.templateId,
            sessionName: prescription.templateName,
            sportType: prescription.sportType,
            sessionType: prescription.sessionType,
            exercises: exercises
        )
    }

    /// Resolve one exercise, applying an accepted volume cut by FILTERING out the lowest-priority
    /// back-off sets (never the top set, never warm-ups). Deterministic: candidates are removed by
    /// descending authored `setIndex`, and the cut clamps to the available candidate count.
    private static func resolveExercise(_ exercise: TemplateExercise, groupName: String?) -> ResolvedExercise {
        let authoredSets = exercise.sortedSets

        // Owning top working set — the SAME rule TodayVerdictService uses (non-warm-up, max weight).
        let working = authoredSets.filter { !$0.isWarmup && ($0.targetWeightKg ?? 0) > 0 }
        let topSet = working.max { ($0.targetWeightKg ?? 0) < ($1.targetWeightKg ?? 0) }

        // Determine which authored sets to drop: only when the top set is ACCEPTED and carries a cut.
        var droppedIDs: Set<UUID> = []
        if let topSet, let cut = VerdictDecisionApplier.effectiveBackoffSetCut(topSet) {
            let candidates = authoredSets
                .filter { !$0.isWarmup && $0.id != topSet.id }   // never warm-ups, never the top set
                .sorted { $0.setIndex > $1.setIndex }            // lowest priority first (highest index)
            droppedIDs = Set(candidates.prefix(cut).map { $0.id }) // prefix clamps to available count
        }

        let resolvedSets: [ResolvedSet] = authoredSets
            .filter { !droppedIDs.contains($0.id) }
            .map { set in
                ResolvedSet(
                    sourceSetID: set.id,
                    setIndex: set.setIndex,
                    reps: set.targetReps,
                    plannedWeightKg: set.targetWeightKg,
                    weightKg: VerdictDecisionApplier.effectiveTargetKg(set),
                    plannedRPE: set.targetRPE,
                    rpe: VerdictDecisionApplier.effectiveTargetRPE(set),
                    rir: set.targetRIR,
                    durationSeconds: set.targetDurationSeconds,
                    distanceMeters: set.targetDistanceMeters,
                    isWarmup: set.isWarmup,
                    isSuggestedAdjustment: set.verdictAppliedAt != nil && VerdictDecisionApplier.hasSuggestion(set),
                    verdictReason: set.verdictReason
                )
            }

        return ResolvedExercise(
            sourceExerciseID: exercise.id,
            exerciseName: exercise.exerciseName,
            exerciseCategory: exercise.exerciseCategory,
            muscleGroup: exercise.muscleGroup,
            groupName: groupName,
            sets: resolvedSets
        )
    }
}
