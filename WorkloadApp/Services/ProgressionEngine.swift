import Foundation
import SwiftData

/// Computes per-exercise progressive overload suggestions based on training history,
/// recovery state, and detraining detection.
///
/// Principles:
/// 1. Progressive overload: gradually increase weight, reps, or volume over time
/// 2. Recovery-aware: scale suggestions by AutoregulationEngine output
/// 3. Detraining-aware: reduce recommendations for users returning from breaks
/// 4. Exercise-specific: each exercise has its own progression curve
struct ProgressionEngine {

    // MARK: - Types

    struct ExerciseSuggestion {
        let exerciseName: String
        let suggestedSets: [SetSuggestion]
        let rationale: String
        let progressionType: ProgressionType
    }

    struct SetSuggestion {
        let weightKg: Double?
        let reps: Int?
        let rpe: Double?
        let durationSeconds: Int?
        let distanceMeters: Double?
    }

    enum ProgressionType {
        case increase       // Progressive overload — push forward
        case maintain       // Hold current level (recovery limited)
        case deload         // Reduce load (fatigue or detraining)
        case returnFromBreak // Gradual ramp-up after time off
    }

    struct TrainingContext {
        let recoveryZone: RecoveryZone
        let recoveryScore: Double
        let volumeModifier: Double      // from AutoregulationEngine (0.0-1.0)
        let intensityCap: Double         // max RPE from AutoregulationEngine
        let acwrZone: ACWRZone
    }

    // MARK: - Suggest

    /// Generate suggestions for a specific exercise based on history and current recovery
    static func suggest(
        exerciseName: String,
        category: ExerciseCategory,
        context: TrainingContext,
        recentEntries: [ExerciseHistoryRecord]
    ) -> ExerciseSuggestion {

        // No history — return empty suggestion
        guard !recentEntries.isEmpty else {
            return ExerciseSuggestion(
                exerciseName: exerciseName,
                suggestedSets: [],
                rationale: "No previous data — log your first session to get suggestions.",
                progressionType: .maintain
            )
        }

        let lastEntry = recentEntries[0]
        let daysSinceLast = Calendar.current.dateComponents(
            [.day], from: lastEntry.date, to: .now
        ).day ?? 0

        // Detect detraining
        let detrainingLevel = detectDetraining(daysSinceLast: daysSinceLast)

        // Compute progression rate from history
        let progressionRate = computeProgressionRate(
            entries: recentEntries,
            category: category
        )

        // Build suggestion based on category
        switch category.inputMode {
        case .weightReps:
            return suggestWeightReps(
                exerciseName: exerciseName,
                lastEntry: lastEntry,
                context: context,
                detrainingLevel: detrainingLevel,
                progressionRate: progressionRate
            )
        case .repsOnly:
            return suggestRepsOnly(
                exerciseName: exerciseName,
                lastEntry: lastEntry,
                context: context,
                detrainingLevel: detrainingLevel
            )
        case .distanceDuration:
            return suggestDistanceDuration(
                exerciseName: exerciseName,
                lastEntry: lastEntry,
                context: context,
                detrainingLevel: detrainingLevel
            )
        case .durationOnly:
            return suggestDurationOnly(
                exerciseName: exerciseName,
                lastEntry: lastEntry,
                context: context,
                detrainingLevel: detrainingLevel
            )
        }
    }

    // MARK: - Detraining Detection

    enum DetrainingLevel {
        case none           // < 7 days — normal
        case mild           // 7-14 days — slight detraining
        case moderate       // 14-28 days — noticeable strength loss
        case significant    // 28+ days — major detraining

        var volumeMultiplier: Double {
            switch self {
            case .none: return 1.0
            case .mild: return 0.9
            case .moderate: return 0.7
            case .significant: return 0.5
            }
        }

        var weightMultiplier: Double {
            switch self {
            case .none: return 1.0
            case .mild: return 0.95
            case .moderate: return 0.80
            case .significant: return 0.60
            }
        }

        var description: String {
            switch self {
            case .none: return ""
            case .mild: return "Slight break detected — easing back in."
            case .moderate: return "2+ weeks off — reducing load to rebuild safely."
            case .significant: return "Extended break — starting at 60% to prevent injury."
            }
        }
    }

    static func detectDetraining(daysSinceLast: Int) -> DetrainingLevel {
        switch daysSinceLast {
        case 0..<7: return .none
        case 7..<14: return .mild
        case 14..<28: return .moderate
        default: return .significant
        }
    }

    // MARK: - Progression Rate

    /// Compute how fast the user has been progressing on this exercise (kg/week)
    /// by comparing the first and last entries in the window
    static func computeProgressionRate(
        entries: [ExerciseHistoryRecord],
        category: ExerciseCategory
    ) -> Double {
        guard entries.count >= 2,
              category.inputMode == .weightReps else { return 0 }

        let newest = entries[0]
        let oldest = entries[entries.count - 1]

        guard let newestWeight = newest.topSetWeight,
              let oldestWeight = oldest.topSetWeight,
              newestWeight > 0, oldestWeight > 0 else { return 0 }

        let daysBetween = Calendar.current.dateComponents(
            [.day], from: oldest.date, to: newest.date
        ).day ?? 1
        guard daysBetween > 0 else { return 0 }

        let weeksBetween = max(1.0, Double(daysBetween) / 7.0)
        return (newestWeight - oldestWeight) / weeksBetween
    }

    // MARK: - Weight/Reps Suggestions

    private static func suggestWeightReps(
        exerciseName: String,
        lastEntry: ExerciseHistoryRecord,
        context: TrainingContext,
        detrainingLevel: DetrainingLevel,
        progressionRate: Double
    ) -> ExerciseSuggestion {
        guard let lastWeight = lastEntry.topSetWeight, lastWeight > 0 else {
            return ExerciseSuggestion(
                exerciseName: exerciseName,
                suggestedSets: lastEntry.sets.map { set in
                    SetSuggestion(weightKg: set.weightKg, reps: set.reps, rpe: min(set.rpe ?? 7, context.intensityCap), durationSeconds: nil, distanceMeters: nil)
                },
                rationale: "Repeating last session — no weight data to progress from.",
                progressionType: .maintain
            )
        }

        // Determine progression type
        let progressionType: ProgressionType
        var rationale: String

        if detrainingLevel != .none {
            progressionType = .returnFromBreak
            rationale = detrainingLevel.description
        } else if context.recoveryZone == .red || context.volumeModifier < 0.6 {
            progressionType = .deload
            rationale = "Recovery is low — reducing load to protect adaptation."
        } else if context.recoveryZone == .green && context.acwrZone == .optimal {
            progressionType = .increase
            rationale = "Recovery is strong and load is balanced — pushing forward."
        } else {
            progressionType = .maintain
            rationale = "Maintaining current level — recovery or load not ideal for progression."
        }

        // Calculate target weight
        let increment: Double
        switch progressionType {
        case .increase:
            // Use observed progression rate, or default small increment
            if progressionRate > 0 {
                increment = min(progressionRate / 7.0 * 7.0, 5.0) // cap at 5kg/week
            } else {
                // Default: 2.5% or minimum 1.25kg
                increment = max(lastWeight * 0.025, 1.25)
            }
        case .maintain:
            increment = 0
        case .deload:
            increment = -(lastWeight * (1.0 - context.volumeModifier))
        case .returnFromBreak:
            increment = -(lastWeight * (1.0 - detrainingLevel.weightMultiplier))
        }

        let targetWeight = roundToNearest(lastWeight + increment, step: 1.25)

        // Build set suggestions from last session's structure
        let volumeMult = detrainingLevel.volumeMultiplier * context.volumeModifier
        let suggestedSets = lastEntry.sets.map { set in
            let adjWeight = set.weightKg.map { roundToNearest($0 + ($0 / lastWeight) * increment, step: 1.25) }
            let adjReps: Int?
            if progressionType == .increase, let reps = set.reps {
                // Try to add 1 rep if we're not increasing weight significantly
                adjReps = increment < 1.25 ? min(reps + 1, reps + 2) : reps
            } else {
                adjReps = set.reps
            }
            let adjRPE = min(set.rpe ?? 7, context.intensityCap)
            return SetSuggestion(weightKg: adjWeight, reps: adjReps, rpe: adjRPE, durationSeconds: nil, distanceMeters: nil)
        }

        // Trim sets if volume modifier is very low
        let setCount = max(1, Int(Double(suggestedSets.count) * volumeMult))
        let trimmedSets = Array(suggestedSets.prefix(setCount))

        if progressionType == .increase {
            rationale += " Target: \(String(format: "%.1f", targetWeight))kg (+" + String(format: "%.1f", increment) + "kg)."
        }

        return ExerciseSuggestion(
            exerciseName: exerciseName,
            suggestedSets: trimmedSets,
            rationale: rationale,
            progressionType: progressionType
        )
    }

    // MARK: - Reps-Only Suggestions

    private static func suggestRepsOnly(
        exerciseName: String,
        lastEntry: ExerciseHistoryRecord,
        context: TrainingContext,
        detrainingLevel: DetrainingLevel
    ) -> ExerciseSuggestion {
        let volumeMult = detrainingLevel.volumeMultiplier * context.volumeModifier
        let suggestedSets = lastEntry.sets.map { set in
            let reps = set.reps.map { Int(Double($0) * volumeMult) }
            let rpe = min(set.rpe ?? 7, context.intensityCap)
            return SetSuggestion(weightKg: nil, reps: reps, rpe: rpe, durationSeconds: nil, distanceMeters: nil)
        }
        let rationale = detrainingLevel != .none
            ? detrainingLevel.description
            : "Based on last session, adjusted for recovery."
        return ExerciseSuggestion(
            exerciseName: exerciseName,
            suggestedSets: suggestedSets,
            rationale: rationale,
            progressionType: detrainingLevel != .none ? .returnFromBreak : .maintain
        )
    }

    // MARK: - Distance/Duration Suggestions

    private static func suggestDistanceDuration(
        exerciseName: String,
        lastEntry: ExerciseHistoryRecord,
        context: TrainingContext,
        detrainingLevel: DetrainingLevel
    ) -> ExerciseSuggestion {
        let volumeMult = detrainingLevel.volumeMultiplier * context.volumeModifier
        let suggestedSets = lastEntry.sets.map { set in
            let dist = set.distanceMeters.map { $0 * volumeMult }
            let dur = set.durationSeconds.map { Int(Double($0) * volumeMult) }
            let rpe = min(set.rpe ?? 6, context.intensityCap)
            return SetSuggestion(weightKg: nil, reps: nil, rpe: rpe, durationSeconds: dur, distanceMeters: dist)
        }
        let rationale = detrainingLevel != .none
            ? detrainingLevel.description
            : "Adjusted for current recovery."
        return ExerciseSuggestion(
            exerciseName: exerciseName,
            suggestedSets: suggestedSets,
            rationale: rationale,
            progressionType: detrainingLevel != .none ? .returnFromBreak : .maintain
        )
    }

    // MARK: - Duration-Only Suggestions

    private static func suggestDurationOnly(
        exerciseName: String,
        lastEntry: ExerciseHistoryRecord,
        context: TrainingContext,
        detrainingLevel: DetrainingLevel
    ) -> ExerciseSuggestion {
        let volumeMult = detrainingLevel.volumeMultiplier * context.volumeModifier
        let suggestedSets = lastEntry.sets.map { set in
            let dur = set.durationSeconds.map { Int(Double($0) * volumeMult) }
            let rpe = min(set.rpe ?? 6, context.intensityCap)
            return SetSuggestion(weightKg: nil, reps: nil, rpe: rpe, durationSeconds: dur, distanceMeters: nil)
        }
        return ExerciseSuggestion(
            exerciseName: exerciseName,
            suggestedSets: suggestedSets,
            rationale: detrainingLevel != .none ? detrainingLevel.description : "Based on last session.",
            progressionType: detrainingLevel != .none ? .returnFromBreak : .maintain
        )
    }

    // MARK: - Helpers

    private static func roundToNearest(_ value: Double, step: Double) -> Double {
        (value / step).rounded() * step
    }
}

// MARK: - History Record (lightweight struct for engine input)

struct ExerciseHistoryRecord {
    let date: Date
    let sets: [SetHistoryRecord]

    var topSetWeight: Double? {
        sets.compactMap(\.weightKg).max()
    }
}

struct SetHistoryRecord {
    let weightKg: Double?
    let reps: Int?
    let rpe: Double?
    let durationSeconds: Int?
    let distanceMeters: Double?
}

// MARK: - Query Helper

extension ProgressionEngine {
    /// Fetch recent history for a given exercise (last 8 sessions)
    @MainActor
    static func fetchHistory(
        exerciseName: String,
        modelContext: ModelContext
    ) -> [ExerciseHistoryRecord] {
        let name = exerciseName
        let descriptor = FetchDescriptor<ExerciseEntry>(
            predicate: #Predicate { $0.exerciseName == name },
            sortBy: [SortDescriptor(\ExerciseEntry.session?.sessionDate, order: .reverse)]
        )
        guard let entries = try? modelContext.fetch(descriptor) else { return [] }

        return Array(entries.prefix(8)).map { entry in
            ExerciseHistoryRecord(
                date: entry.session?.sessionDate ?? .now,
                sets: entry.sortedSets.map { set in
                    SetHistoryRecord(
                        weightKg: set.weightKg,
                        reps: set.reps,
                        rpe: set.rpe,
                        durationSeconds: set.durationSeconds,
                        distanceMeters: set.distanceMeters
                    )
                }
            )
        }
    }
}
