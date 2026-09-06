import Foundation

/// Pure computation for the program screen and lifecycle transitions (v1.7.3 feature 6,
/// epics 7+8). No state, no SwiftData — callers pass day→template content resolved
/// through `ProgramRepository`.
///
/// Honesty rules (gated demo §3): the comparison is strength volume against strength
/// volume (kg·week) — planned tonnage vs the athlete's trailing logged tonnage; the
/// eased entry trims BACK-OFF sets only, top sets untouched; the duration suggestion is
/// bounded advice that names its inputs and hands the decision back. Nothing here edits
/// the program's content.
struct ProgramInsightEngine {

    // MARK: - Planned volume

    /// Planned tonnage (kg) of one template: Σ target weight × target reps over working sets.
    /// Sets without both numbers contribute nothing — never a guess.
    static func plannedVolume(of template: WorkoutTemplate) -> Double {
        template.sortedGroups.flatMap(\.sortedExercises).reduce(0) { total, exercise in
            total + exercise.sortedSets.filter { !$0.isWarmup }.reduce(0) { setTotal, set in
                guard let weight = set.targetWeightKg, let reps = set.targetReps else { return setTotal }
                return setTotal + weight * Double(reps)
            }
        }
    }

    /// Planned tonnage of a program week, given the resolved day templates.
    static func weekVolume(
        program: TrainingProgram,
        week: Int,
        templates: [UUID: WorkoutTemplate]
    ) -> Double {
        program.days(inWeek: week).reduce(0) { total, day in
            guard let templateId = day.templateId, let template = templates[templateId] else {
                return total
            }
            return total + plannedVolume(of: template)
        }
    }

    /// The eased (entry-mode) tonnage of a week: per exercise, one back-off working set —
    /// the LAST by set index that is neither a warmup nor the top set — is trimmed.
    /// Exercises with a single working set are untouched (there is nothing to trim but
    /// the top set, and top sets are never trimmed).
    static func easedWeekVolume(
        program: TrainingProgram,
        week: Int,
        templates: [UUID: WorkoutTemplate]
    ) -> Double {
        program.days(inWeek: week).reduce(0) { total, day in
            guard let templateId = day.templateId, let template = templates[templateId] else {
                return total
            }
            let dayVolume = template.sortedGroups.flatMap(\.sortedExercises).reduce(0.0) { sum, exercise in
                let working = exercise.sortedSets.filter { !$0.isWarmup }
                let volumes = working.compactMap { set -> Double? in
                    guard let weight = set.targetWeightKg, let reps = set.targetReps else { return nil }
                    return weight * Double(reps)
                }
                guard volumes.count > 1 else { return sum + (volumes.first ?? 0) }
                // The top set is the heaviest working set; trim the LAST set that is not it.
                let full = volumes.reduce(0, +)
                let topIndex = volumes.firstIndex(of: volumes.max() ?? 0) ?? 0
                let trimIndex = (0..<volumes.count).reversed().first { $0 != topIndex }
                return sum + full - (trimIndex.map { volumes[$0] } ?? 0)
            }
            return total + dayVolume
        }
    }

    // MARK: - Transition comparison (epic 8)

    struct TransitionComparison {
        /// Trailing average logged tonnage per week (kg·wk).
        let chronicWeeklyVolume: Double
        /// The new block's opening-week planned tonnage (kg·wk).
        let openingWeekVolume: Double
        /// Opening week with one back-off trimmed per lift (kg·wk).
        let easedWeekVolume: Double
        /// (opening − chronic) / chronic, e.g. +0.18. nil when there is no history.
        var openingStepFraction: Double? {
            guard chronicWeeklyVolume > 0 else { return nil }
            return (openingWeekVolume - chronicWeeklyVolume) / chronicWeeklyVolume
        }
        var easedStepFraction: Double? {
            guard chronicWeeklyVolume > 0 else { return nil }
            return (easedWeekVolume - chronicWeeklyVolume) / chronicWeeklyVolume
        }
        /// The eased entry is offered only when the opening step is a real jump AND the
        /// trim actually softens it. "As written" is always the equal-weight alternative.
        var suggestsEasedEntry: Bool {
            guard let step = openingStepFraction else { return false }
            return step > 0.10 && easedWeekVolume < openingWeekVolume
        }
    }

    /// Chronic weekly tonnage from logged sessions: total volume over the window,
    /// normalized per week. Court/conditioning sessions carry ~zero tonnage and dilute
    /// nothing — this compares strength volume with strength volume.
    static func chronicWeeklyVolume(
        sessions: [(date: Date, volume: Double)],
        weeks: Int = 4,
        asOf now: Date = .now,
        calendar: Calendar = .current
    ) -> Double {
        guard weeks >= 1 else { return 0 }
        guard let cutoff = calendar.date(byAdding: .day, value: -(weeks * 7), to: now) else { return 0 }
        let total = sessions
            .filter { $0.date >= cutoff && $0.date <= now }
            .reduce(0) { $0 + $1.volume }
        return total / Double(weeks)
    }

    static func transitionComparison(
        program: TrainingProgram,
        templates: [UUID: WorkoutTemplate],
        sessions: [(date: Date, volume: Double)],
        asOf now: Date = .now
    ) -> TransitionComparison {
        TransitionComparison(
            chronicWeeklyVolume: chronicWeeklyVolume(sessions: sessions, asOf: now),
            openingWeekVolume: weekVolume(program: program, week: 1, templates: templates),
            easedWeekVolume: easedWeekVolume(program: program, week: 1, templates: templates)
        )
    }

    // MARK: - Adherence (epic 7)

    struct Adherence {
        let trained: Int
        let planned: Int
    }

    /// Sessions trained vs sessions planned, counting only days up to the position cursor
    /// (future days cannot be adhered to yet). A canceled day leaves the denominator —
    /// the cancellation was the decision, and the record already shows it.
    static func adherence(
        program: TrainingProgram,
        entries: [ScheduleEntry]
    ) -> Adherence {
        let programEntries = entries.filter { $0.programId == program.id && $0.kind == .programSession }
        let due = programEntries.filter { entry in
            guard let day = program.days.first(where: { $0.id == entry.programDayId }) else { return false }
            return (day.weekNumber, day.dayNumber) < (program.positionWeek, program.positionDay)
                && entry.status != .canceled && entry.status != .moved
        }
        let trained = due.filter { $0.status == .completed }.count
        return Adherence(trained: trained, planned: due.count)
    }

    // MARK: - Duration suggestion (epic 8, ladder rung 3 — on request only)

    struct DurationSuggestion {
        let weeks: Int
        let includesLighterWeek: Bool
        /// The named inputs, for the "FROM YOUR HISTORY + THIS PLAN'S STRUCTURE" copy.
        let weeklyVolumeStepFraction: Double?
        let historyWeeks: Int
    }

    /// Suggest a block duration from the plan's own volume step and the athlete's logged
    /// history depth. Bounded advice: 4–12 weeks, a lighter week at the midpoint when the
    /// climb is real, and the caller renders it as a hand-back, never a default.
    static func suggestDuration(
        program: TrainingProgram,
        templates: [UUID: WorkoutTemplate],
        historyWeeks: Int
    ) -> DurationSuggestion {
        // Volume step across the parsed weeks (nil for a flat or single-week file).
        let weekVolumes = (1...max(1, program.durationWeeks)).map {
            weekVolume(program: program, week: $0, templates: templates)
        }.filter { $0 > 0 }
        var stepFraction: Double?
        if weekVolumes.count > 1, let first = weekVolumes.first, first > 0,
           let last = weekVolumes.last {
            let perWeek = (last / first - 1) / Double(weekVolumes.count - 1)
            stepFraction = perWeek.isFinite ? perWeek : nil
        }

        // Deeper history and a steeper climb both argue for a shorter, checkpointed block.
        let base: Int
        switch (stepFraction ?? 0, historyWeeks) {
        case (0.08..., _): base = 6          // steep climb — keep the block short
        case (_, ..<8): base = 6             // thin history — prove it in 6
        case (0.04..., _): base = 8
        default: base = 8
        }
        let lighter = (stepFraction ?? 0) >= 0.04 || base >= 8
        return DurationSuggestion(
            weeks: base,
            includesLighterWeek: lighter,
            weeklyVolumeStepFraction: stepFraction,
            historyWeeks: historyWeeks
        )
    }
}
