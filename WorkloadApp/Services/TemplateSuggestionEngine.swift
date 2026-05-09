import Foundation

/// Smart template suggestion engine.
/// Analyzes session history to suggest the most appropriate template for today
/// based on day-of-week frequency patterns, with recovery-aware fallback to
/// lighter alternatives when the athlete is fatigued.
///
/// Pure struct with static methods -- no state, no dependencies beyond Models.
struct TemplateSuggestionEngine {

    // MARK: - Types

    struct SuggestionResult {
        let template: WorkoutTemplate
        let isRecoveryAdjusted: Bool
        let rationale: String
    }

    // MARK: - Primary Method

    /// Suggest a template for today based on training history and recovery state.
    ///
    /// - Parameters:
    ///   - templates: All available (non-archived) templates
    ///   - recentSessions: Recent workout sessions (engine filters to last 14 days)
    ///   - currentRecoveryZone: Athlete's current recovery zone
    ///   - today: Reference date (defaults to now, injectable for testing)
    /// - Returns: A suggestion result, or nil if insufficient data
    static func suggest(
        templates: [WorkoutTemplate],
        recentSessions: [WorkoutSession],
        currentRecoveryZone: RecoveryZone,
        today: Date = .now
    ) -> SuggestionResult? {
        // Guard: need at least one template
        guard !templates.isEmpty else { return nil }

        // Filter sessions to last 14 days
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: today) ?? today
        let windowSessions = recentSessions.filter { $0.sessionDate >= twoWeeksAgo }

        // Insufficient data: need at least 3 sessions in the window
        guard windowSessions.count >= 3 else { return nil }

        let weekday = isoWeekday(from: today)

        // Find the most-used template on today's weekday
        guard let frequencyPick = pickByFrequency(
            templates: templates,
            sessions: windowSessions,
            weekday: weekday
        ) else {
            return nil  // No template used on this weekday -- silent fallback
        }

        // Recovery check: swap to lighter alternative when fatigued
        if currentRecoveryZone == .red || currentRecoveryZone == .yellow {
            if let lighter = findLighterAlternative(
                current: frequencyPick,
                all: templates,
                sessions: windowSessions
            ) {
                return SuggestionResult(
                    template: lighter,
                    isRecoveryAdjusted: true,
                    rationale: "Recovery-adjusted: lighter session suggested"
                )
            }
        }

        let dayName = weekdayName(weekday)
        return SuggestionResult(
            template: frequencyPick,
            isRecoveryAdjusted: false,
            rationale: "Based on your \(dayName) training pattern"
        )
    }

    // MARK: - Helpers

    /// Convert Apple Calendar weekday (1=Sun) to ISO 8601 (1=Mon...7=Sun).
    static func isoWeekday(from date: Date) -> Int {
        let apple = Calendar.current.component(.weekday, from: date)
        return apple == 1 ? 7 : apple - 1
    }

    /// Find the template most frequently used on a given weekday.
    ///
    /// Matches sessions to templates via `sourceTemplateId` (primary) or
    /// `sessionName == templateName` (fallback for pre-linkage sessions).
    private static func pickByFrequency(
        templates: [WorkoutTemplate],
        sessions: [WorkoutSession],
        weekday: Int
    ) -> WorkoutTemplate? {
        // Build frequency map: templateId -> count on target weekday
        var frequencyMap: [UUID: Int] = [:]
        let templateById = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
        let templateByName = Dictionary(grouping: templates, by: { $0.templateName })

        for session in sessions {
            let sessionWeekday = isoWeekday(from: session.sessionDate)
            guard sessionWeekday == weekday else { continue }

            // Primary match: sourceTemplateId
            if let templateId = session.sourceTemplateId, templateById[templateId] != nil {
                frequencyMap[templateId, default: 0] += 1
                continue
            }

            // Fallback match: session name matches template name
            if let name = session.sessionName,
               let matchingTemplates = templateByName[name],
               let first = matchingTemplates.first {
                frequencyMap[first.id, default: 0] += 1
            }
        }

        // Find the template with the highest frequency on this weekday
        guard let bestEntry = frequencyMap.max(by: { $0.value < $1.value }) else {
            return nil
        }

        return templateById[bestEntry.key]
    }

    /// Find a lighter alternative template when recovery is compromised.
    ///
    /// "Lighter" is determined by exercise count (fewer = lighter). When counts
    /// tie, average historical training stress is used as a tiebreaker.
    private static func findLighterAlternative(
        current: WorkoutTemplate,
        all: [WorkoutTemplate],
        sessions: [WorkoutSession]
    ) -> WorkoutTemplate? {
        let candidates = all.filter { $0.id != current.id && !$0.isArchived }
        guard !candidates.isEmpty else { return nil }

        let currentExerciseCount = exerciseCount(for: current)

        // Build average TSS per template from session history
        var tssMap: [UUID: (total: Double, count: Int)] = [:]
        for session in sessions {
            if let templateId = session.sourceTemplateId {
                let existing = tssMap[templateId, default: (total: 0, count: 0)]
                tssMap[templateId] = (total: existing.total + session.trainingStress, count: existing.count + 1)
            }
        }

        // Sort candidates: primary by exercise count (ascending), secondary by avg TSS (ascending)
        let sorted = candidates.sorted { a, b in
            let countA = exerciseCount(for: a)
            let countB = exerciseCount(for: b)
            if countA != countB { return countA < countB }

            let avgA = averageTSS(for: a.id, from: tssMap)
            let avgB = averageTSS(for: b.id, from: tssMap)
            return avgA < avgB
        }

        guard let lightest = sorted.first else { return nil }
        let lightestCount = exerciseCount(for: lightest)

        // Only suggest if strictly lighter than current
        if lightestCount < currentExerciseCount {
            return lightest
        }

        // Tiebreaker: if same exercise count, check TSS
        if lightestCount == currentExerciseCount {
            let currentAvgTSS = averageTSS(for: current.id, from: tssMap)
            let lightestAvgTSS = averageTSS(for: lightest.id, from: tssMap)
            if lightestAvgTSS < currentAvgTSS {
                return lightest
            }
        }

        return nil
    }

    /// Count total exercises across all groups in a template.
    private static func exerciseCount(for template: WorkoutTemplate) -> Int {
        template.sortedGroups.flatMap { $0.sortedExercises }.count
    }

    /// Get average TSS for a template from the precomputed map.
    private static func averageTSS(
        for templateId: UUID,
        from tssMap: [UUID: (total: Double, count: Int)]
    ) -> Double {
        guard let entry = tssMap[templateId], entry.count > 0 else { return 0 }
        return entry.total / Double(entry.count)
    }

    /// Human-readable weekday name from ISO weekday number.
    private static func weekdayName(_ iso: Int) -> String {
        let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return names[max(0, min(6, iso - 1))]
    }
}
