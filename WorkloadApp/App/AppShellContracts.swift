import Foundation

enum AppContext: String, CaseIterable, Codable, Hashable {
    case athlete
    case coach

    var displayName: String {
        switch self {
        case .athlete: "Athlete"
        case .coach: "Coach"
        }
    }
}

enum AthleteTab: String, CaseIterable, Identifiable, Hashable {
    case today
    case train
    case insights
    case profile

    var id: Self { self }

    var localizationKey: String.LocalizationValue {
        switch self {
        case .today: "tab.athlete.today"
        case .train: "tab.athlete.train"
        case .insights: "tab.athlete.insights"
        case .profile: "tab.athlete.profile"
        }
    }

    func titleText(locale: Locale) -> String {
        UIKitStrings.localized(localizationKey, locale: locale)
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .train: "figure.strengthtraining.traditional"
        case .insights: "chart.xyaxis.line"
        case .profile: "person.crop.circle"
        }
    }

    var accessibilityIdentifier: String {
        "tab.athlete.\(rawValue)"
    }
}

enum CoachTab: String, CaseIterable, Identifiable, Hashable {
    case roster
    case plans
    case reports
    case profile

    var id: Self { self }

    var localizationKey: String.LocalizationValue {
        switch self {
        case .roster: "tab.coach.roster"
        case .plans: "tab.coach.plans"
        case .reports: "tab.coach.reports"
        case .profile: "tab.coach.profile"
        }
    }

    func titleText(locale: Locale) -> String {
        UIKitStrings.localized(localizationKey, locale: locale)
    }

    var systemImage: String {
        switch self {
        case .roster: "person.2"
        case .plans: "calendar.badge.clock"
        case .reports: "doc.text.magnifyingglass"
        case .profile: "person.crop.circle"
        }
    }

    var accessibilityIdentifier: String {
        "tab.coach.\(rawValue)"
    }
}

enum AppDestination: Hashable {
    case athleteTab(AthleteTab)
    case coachTab(CoachTab)
}

@MainActor
@Observable
final class NavigationState {
    var athleteTab: AthleteTab = .today
    var coachTab: CoachTab = .roster

    func reset(for context: AppContext) {
        switch context {
        case .athlete:
            athleteTab = .today
        case .coach:
            coachTab = .roster
        }
    }
}

struct TodayViewState: Equatable {
    enum PrimaryAction: Equatable {
        case workout
        case connectHealth
    }

    struct Metric: Equatable {
        var label: String
        var value: String
        var detail: String
    }

    struct SessionRow: Equatable {
        var title: String
        var subtitle: String
    }

    var heroKicker: String
    var heroTitle: String
    var heroBody: String
    var primaryActionTitle: String
    var primaryAction: PrimaryAction
    var signalMetrics: [Metric]
    var loadMetrics: [Metric]
    var recentSessions: [SessionRow]
    var statusTitle: String?
    var statusBody: String?

    static func make(
        recoveryScore: Double,
        hasRealData: Bool,
        recommendation: AutoregulationEngine.TrainingRecommendation?,
        isLoading: Bool,
        healthConnectionState: HealthKitConnectionState,
        latestHRV: Double?,
        latestSleepMinutes: Double?,
        acwr: Double,
        acwrZone: ACWRZone,
        atl: Double,
        ctl: Double,
        tsb: Double,
        recentSessions: [WorkoutSession],
        locale: Locale,
        date: Date = .now
    ) -> TodayViewState {
        let needsHealthConnection = !hasRealData && healthConnectionState == .notRequested
        let status: (title: String?, body: String?)
        if !hasRealData && healthConnectionState == .requestedNoData {
            status = ("Apple Health connected", "No recent recovery samples are visible yet.")
        } else {
            status = (nil, nil)
        }

        return TodayViewState(
            heroKicker: dateLabel(date, locale: locale),
            heroTitle: hasRealData ? "\(Int(recoveryScore))" : "Today",
            heroBody: heroBody(recommendation: recommendation, isLoading: isLoading),
            primaryActionTitle: needsHealthConnection ? "Connect Apple Health" : workoutActionTitle(recommendation: recommendation),
            primaryAction: needsHealthConnection ? .connectHealth : .workout,
            signalMetrics: [
                Metric(label: "HRV", value: latestHRV.map { "\(Int($0))" } ?? "--", detail: "ms"),
                Metric(label: "Sleep", value: latestSleepMinutes.map { String(format: "%.1f", $0 / 60) } ?? "--", detail: "hours"),
                Metric(label: "Load", value: acwr > 0 ? String(format: "%.2f", acwr) : "--", detail: acwrZone.displayName)
            ],
            loadMetrics: [
                Metric(label: "ATL", value: String(format: "%.0f", atl), detail: "Acute"),
                Metric(label: "CTL", value: String(format: "%.0f", ctl), detail: "Chronic"),
                Metric(label: "TSB", value: String(format: "%.0f", tsb), detail: "Balance")
            ],
            recentSessions: recentSessions.prefix(5).map { session in
                SessionRow(
                    title: session.sessionName ?? session.sportType.displayName,
                    subtitle: "\(session.sessionDate.relativeString(locale: locale)) · \(Int(session.trainingStress)) load"
                )
            },
            statusTitle: status.title,
            statusBody: status.body
        )
    }

    private static func heroBody(
        recommendation: AutoregulationEngine.TrainingRecommendation?,
        isLoading: Bool
    ) -> String {
        if let recommendation {
            return "\(recommendation.headline)\n\(recommendation.detail)"
        } else if isLoading {
            return "Loading today’s readiness and training load."
        } else {
            return "Log training and connect recovery signals to build a reliable daily read."
        }
    }

    private static func dateLabel(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEEdMMM")
        let text = formatter.string(from: date)
        return locale.language.languageCode?.identifier == "en" ? text.uppercased() : text
    }

    private static func workoutActionTitle(recommendation: AutoregulationEngine.TrainingRecommendation?) -> String {
        switch recommendation?.sessionType {
        case .rest:
            return "Log Rest Day"
        case .activeRecovery:
            return "Log Light Session"
        case .power, .strength, .hypertrophy, .conditioning:
            return "Start Session"
        case nil:
            return "Log Workout"
        }
    }
}

struct TrainHomeViewState: Equatable {
    struct TodayPlan: Equatable {
        var title: String
        var subtitle: String
        var actionTitle: String
    }

    struct ProgramRow: Equatable {
        var title: String
        var subtitle: String
        var trailing: String
    }

    struct SessionRow: Equatable {
        var title: String
        var subtitle: String
    }

    var heroTitle: String
    var heroBody: String
    var primaryActionTitle: String
    var todayPlan: TodayPlan?
    var emptyTodayTitle: String
    var emptyTodayBody: String
    var programRows: [ProgramRow]
    var emptyProgramsTitle: String
    var emptyProgramsBody: String
    var sessionRows: [SessionRow]

    static func make(
        summary: (
            athlete: Athlete?,
            sessions: [WorkoutSession],
            templates: [WorkoutTemplate],
            prescriptions: [PrescribedWorkout]
        ),
        locale: Locale
    ) -> TrainHomeViewState {
        let todayPlan = todayPrescription(from: summary.prescriptions)
        let heroTitle: String
        let heroBody: String

        if let todayPlan {
            heroTitle = todayPlan.templateName
            heroBody = "\(todayPlan.sessionType.displayName) · \(todayPlan.sportType.displayName)"
        } else if summary.templates.isEmpty {
            heroTitle = "Start from blank"
            heroBody = "Start a blank workout, pick a program, or plan today’s session."
        } else {
            heroTitle = "Choose your session"
            if let last = summary.sessions.first {
                heroBody = "Last session: \(last.sessionName ?? last.sportType.displayName), \(last.sessionDate.relativeString(locale: locale))."
            } else {
                heroBody = "Start a blank workout, pick a program, or plan today’s session."
            }
        }

        return TrainHomeViewState(
            heroTitle: heroTitle,
            heroBody: heroBody,
            primaryActionTitle: "Start Workout",
            todayPlan: todayPlan.map {
                TodayPlan(
                    title: $0.templateName,
                    subtitle: "\($0.sessionType.displayName) · \($0.sportType.displayName)",
                    actionTitle: "Start"
                )
            },
            emptyTodayTitle: "No plan assigned today",
            emptyTodayBody: "Use Start Workout for an immediate session or Plan today to prepare one.",
            programRows: summary.templates.prefix(4).map { template in
                ProgramRow(
                    title: template.templateName,
                    subtitle: "\(template.sessionType.displayName) · \(template.sortedGroups.flatMap(\.sortedExercises).count) exercises",
                    trailing: "Start"
                )
            },
            emptyProgramsTitle: "No saved programs yet",
            emptyProgramsBody: "Start blank now, or create a reusable program from the template picker.",
            sessionRows: summary.sessions.prefix(5).map { session in
                SessionRow(
                    title: session.sessionName ?? session.sportType.displayName,
                    subtitle: "\(session.sessionDate.relativeString(locale: locale)) · \(Int(session.trainingStress)) load"
                )
            }
        )
    }

    private static func todayPrescription(from prescriptions: [PrescribedWorkout]) -> PrescribedWorkout? {
        let calendar = Calendar.current
        return prescriptions.first {
            calendar.isDateInToday($0.scheduledDate) && $0.status == .assigned
        }
    }
}

// MARK: - Active Workout Draft Models

struct ExerciseEntryDraft: Identifiable {
    let id = UUID()
    var exerciseName: String
    var exerciseCategory: ExerciseCategory
    var muscleGroup: MuscleGroup?
    var groupName: String?
    var sets: [SetDraft] = [SetDraft()]
    var suggestionRationale: String?
    var progressionType: ProgressionEngine.ProgressionType?
    var progressionSuggestions: [ProgressionEngine.SetSuggestion]?
}

struct SetDraft: Identifiable {
    let id = UUID()
    var reps: Int? = nil
    var weightKg: Double? = nil
    var durationSeconds: Int? = nil
    var distanceMeters: Double? = nil
    var rpe: Double? = nil
    var rir: Int? = nil
    var isWarmup: Bool = false
    var targetReps: Int? = nil
    var targetWeightKg: Double? = nil
    var targetRPE: Double? = nil
    var targetRIR: Int? = nil
    var targetDistanceMeters: Double? = nil
    var targetDurationSeconds: Int? = nil
    var plannedWeightKg: Double? = nil
    var plannedRPE: Double? = nil
    var isSuggestedAdjustment: Bool = false
    var verdictReason: String? = nil
    var lastSessionWeightKg: Double? = nil
    var lastSessionReps: Int? = nil
    var lastSessionDistanceMeters: Double? = nil
    var lastSessionDurationSeconds: Int? = nil
    var isFromHistory: Bool = false
    var isDone: Bool = false
    var isSkipped: Bool = false
}

struct ActiveWorkoutViewState: Equatable {
    var heroKicker: String
    var sessionTitle: String
    var heroBody: String
    var completedSetCount: Int
    var totalSetCount: Int
    var exerciseCount: Int
    var hasUnsavedChanges: Bool
    var isSaving: Bool
    var finishActionTitle: String
    var finishAccessibilityValue: String
    var addExerciseActionTitle: String
    var addExerciseAccessibilityIdentifier: String
    var emptyTitle: String
    var emptyBody: String

    var hasExercises: Bool {
        exerciseCount > 0
    }

    static func make(
        sessionTitle: String,
        sessionRPE: Double,
        entries: [ExerciseEntryDraft],
        hasUnsavedChanges: Bool,
        isSaving: Bool
    ) -> ActiveWorkoutViewState {
        let totalSetCount = entries.reduce(0) { $0 + $1.sets.count }
        let completedSetCount = entries.reduce(0) { $0 + $1.sets.filter(\.isDone).count }

        return ActiveWorkoutViewState(
            heroKicker: "Active Workout",
            sessionTitle: sessionTitle,
            heroBody: "\(completedSetCount) / \(totalSetCount) sets done · RPE \(Int(sessionRPE))",
            completedSetCount: completedSetCount,
            totalSetCount: totalSetCount,
            exerciseCount: entries.count,
            hasUnsavedChanges: hasUnsavedChanges,
            isSaving: isSaving,
            finishActionTitle: isSaving ? "Saving..." : "Finish · \(completedSetCount)/\(totalSetCount) sets",
            finishAccessibilityValue: "\(completedSetCount) of \(totalSetCount) sets completed",
            addExerciseActionTitle: "Add Exercise",
            addExerciseAccessibilityIdentifier: "activeWorkout.addExercise",
            emptyTitle: "No exercises yet",
            emptyBody: "Add an exercise, enter the work that was actually completed, then finish the session."
        )
    }
}

struct ActiveWorkoutSessionState: Equatable {
    var sectionTitle: String
    var sessionNameTitle: String
    var sessionNamePlaceholder: String
    var sessionNameValue: String
    var elapsedLabel: String
    var elapsedValue: String
    var elapsedDetail: String
    var settingsTitle: String
    var settingsValue: String
    var settingsAccessibilityIdentifier: String

    static func make(
        sessionName: String,
        sportType: SportType,
        sessionType: SessionType,
        elapsedSeconds: Int,
        locale: Locale
    ) -> ActiveWorkoutSessionState {
        ActiveWorkoutSessionState(
            sectionTitle: "Session",
            sessionNameTitle: "Session Name",
            sessionNamePlaceholder: "Optional",
            sessionNameValue: sessionName,
            elapsedLabel: "Elapsed",
            elapsedValue: Date.durationString(seconds: elapsedSeconds, locale: locale),
            elapsedDetail: "Session time",
            settingsTitle: "Session Settings",
            settingsValue: "\(sportType.displayName) · \(sessionType.displayName)",
            settingsAccessibilityIdentifier: "activeWorkout.sessionSettings"
        )
    }
}

struct ActiveWorkoutExerciseBlockState: Equatable {
    struct Action: Equatable {
        var title: String
        var accessibilityIdentifier: String
    }

    var title: String
    var detail: String
    var progressText: String
    var progressAccessibilityIdentifier: String
    var actions: [Action]

    static func make(entry: ExerciseEntryDraft, entryIndex: Int) -> ActiveWorkoutExerciseBlockState {
        let detailParts = [
            entry.exerciseCategory.displayName,
            entry.muscleGroup?.displayName,
            entry.groupName
        ]
            .compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
        let completedSetCount = entry.sets.filter(\.isDone).count

        return ActiveWorkoutExerciseBlockState(
            title: entry.exerciseName,
            detail: detailParts.isEmpty ? entry.exerciseCategory.displayName : detailParts.joined(separator: " · "),
            progressText: "\(completedSetCount) / \(entry.sets.count) sets",
            progressAccessibilityIdentifier: "activeWorkout.exerciseProgress.\(entryIndex)",
            actions: [
                Action(
                    title: "Add Set",
                    accessibilityIdentifier: "activeWorkout.addSet.\(entryIndex)"
                ),
                Action(
                    title: "Repeat Last",
                    accessibilityIdentifier: "activeWorkout.repeatLast.\(entryIndex)"
                ),
                Action(
                    title: "Remove",
                    accessibilityIdentifier: "activeWorkout.removeExercise.\(entryIndex)"
                )
            ]
        )
    }
}

struct ActiveWorkoutSetRowState: Equatable {
    var setLabel: String
    var stateText: String
    var doneActionTitle: String
    var completedSummaryText: String
    var skippedSummaryText: String
    var showsCollapsedCompletedSummary: Bool
    var showsSkippedSummary: Bool
    var showsInputFields: Bool

    static func make(
        set: SetDraft,
        setIndex: Int,
        category: ExerciseCategory,
        weightUnit: WeightUnit,
        isCompletedExpanded: Bool
    ) -> ActiveWorkoutSetRowState {
        let showsCollapsedCompletedSummary = set.isDone && !isCompletedExpanded
        let showsSkippedSummary = !showsCollapsedCompletedSummary && set.isSkipped
        return ActiveWorkoutSetRowState(
            setLabel: "Set \(setIndex + 1)",
            stateText: setStateText(for: set, weightUnit: weightUnit),
            doneActionTitle: set.isDone ? "Done" : "Mark Done",
            completedSummaryText: loggedSetSummary(for: set, category: category, weightUnit: weightUnit),
            skippedSummaryText: "Skipped set · Not logged",
            showsCollapsedCompletedSummary: showsCollapsedCompletedSummary,
            showsSkippedSummary: showsSkippedSummary,
            showsInputFields: !showsCollapsedCompletedSummary && !showsSkippedSummary
        )
    }

    private static func setStateText(for set: SetDraft, weightUnit: WeightUnit) -> String {
        var parts = [baseSetStateText(for: set)]
        if set.isWarmup {
            parts.append("Warm-up")
        }
        if set.isSuggestedAdjustment && !parts.contains("Suggested adjustment") {
            parts.append("Suggested adjustment")
        }
        if let adjustment = adjustmentSummaryText(for: set, weightUnit: weightUnit) {
            parts.append(adjustment)
        }
        if set.isSuggestedAdjustment, let reason = set.verdictReason, !reason.isEmpty {
            parts.append(reason)
        }
        return parts.joined(separator: " · ")
    }

    private static func baseSetStateText(for set: SetDraft) -> String {
        if set.isSkipped {
            return "Skipped"
        }
        if set.isDone {
            return "Completed"
        }
        if hasPerformedInput(set) {
            return "Edited"
        }
        if set.isSuggestedAdjustment {
            return "Suggested adjustment"
        }
        if hasTargetInput(set) {
            return "Planned"
        }
        return "Empty"
    }

    private static func adjustmentSummaryText(for set: SetDraft, weightUnit: WeightUnit) -> String? {
        guard set.isSuggestedAdjustment else { return nil }
        var parts: [String] = []
        if let planned = displayWeight(set.plannedWeightKg, weightUnit: weightUnit),
           let resolved = displayWeight(set.targetWeightKg, weightUnit: weightUnit),
           abs(planned - resolved) > 0.001 {
            parts.append("\(formatNumber(planned)) \(weightUnit.displayName) -> \(formatNumber(resolved)) \(weightUnit.displayName)")
        }
        if let plannedRPE = set.plannedRPE,
           let resolvedRPE = set.targetRPE,
           abs(plannedRPE - resolvedRPE) > 0.001 {
            parts.append("RPE \(formatNumber(plannedRPE)) -> \(formatNumber(resolvedRPE))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private static func loggedSetSummary(
        for set: SetDraft,
        category: ExerciseCategory,
        weightUnit: WeightUnit
    ) -> String {
        var parts: [String] = []
        switch category.inputMode {
        case .weightReps:
            if let weight = displayWeight(set.weightKg, weightUnit: weightUnit) {
                parts.append("\(formatNumber(weight)) \(weightUnit.displayName)")
            }
            if let reps = set.reps {
                parts.append("\(reps) reps")
            }
        case .repsOnly:
            if let reps = set.reps {
                parts.append("\(reps) reps")
            }
        case .distanceDuration:
            if let distanceMeters = set.distanceMeters {
                parts.append("\(formatNumber(distanceMeters / 1000)) km")
            }
            if let durationSeconds = set.durationSeconds {
                parts.append("\(durationSeconds / 60) min")
            }
        case .durationOnly:
            if let durationSeconds = set.durationSeconds {
                parts.append("\(durationSeconds / 60) min")
            }
        }

        if let rpe = set.rpe {
            parts.append("RPE \(formatNumber(rpe))")
        } else if let rir = set.rir {
            parts.append("RIR \(rir)")
        }

        return parts.isEmpty ? "Completed set" : parts.joined(separator: " · ")
    }

    private static func hasPerformedInput(_ set: SetDraft) -> Bool {
        set.reps != nil ||
            set.weightKg != nil ||
            set.durationSeconds != nil ||
            set.distanceMeters != nil ||
            set.rpe != nil ||
            set.rir != nil
    }

    private static func hasTargetInput(_ set: SetDraft) -> Bool {
        set.targetReps != nil ||
            set.targetWeightKg != nil ||
            set.targetRPE != nil ||
            set.targetRIR != nil ||
            set.targetDistanceMeters != nil ||
            set.targetDurationSeconds != nil
    }

    private static func displayWeight(_ weightKg: Double?, weightUnit: WeightUnit) -> Double? {
        weightKg.map { $0 / weightUnit.conversionToKg }
    }

    private static func formatNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

struct ActiveWorkoutSetInputFieldsState: Equatable {
    struct Field: Equatable {
        enum Kind: Equatable {
            case weight
            case reps
            case distance
            case duration
            case rpe
            case rir
        }

        enum Value: Equatable {
            case decimal(value: Double?, placeholder: Double?, step: Double?, closedRange: ClosedRange<Double>?)
            case integer(value: Int?, placeholder: Int?, step: Int?, closedRange: ClosedRange<Int>?)
        }

        var kind: Kind
        var title: String
        var accessibilityIdentifier: String
        var value: Value
    }

    var fields: [Field]

    static func make(
        set: SetDraft,
        category: ExerciseCategory,
        weightUnit: WeightUnit,
        entryIndex: Int,
        setIndex: Int
    ) -> ActiveWorkoutSetInputFieldsState {
        var fields: [Field] = []

        switch category.inputMode {
        case .weightReps:
            fields.append(Field(
                kind: .weight,
                title: weightUnit.displayName,
                accessibilityIdentifier: identifier("weight", entryIndex: entryIndex, setIndex: setIndex),
                value: .decimal(
                    value: displayWeight(set.weightKg, weightUnit: weightUnit),
                    placeholder: displayWeight(set.targetWeightKg, weightUnit: weightUnit),
                    step: weightUnit == .kg ? 2.5 : 5,
                    closedRange: nil
                )
            ))
            fields.append(repsField(set: set, entryIndex: entryIndex, setIndex: setIndex))
        case .repsOnly:
            fields.append(repsField(set: set, entryIndex: entryIndex, setIndex: setIndex))
        case .distanceDuration:
            fields.append(Field(
                kind: .distance,
                title: "Km",
                accessibilityIdentifier: identifier("distance", entryIndex: entryIndex, setIndex: setIndex),
                value: .decimal(
                    value: set.distanceMeters.map { $0 / 1000 },
                    placeholder: set.targetDistanceMeters.map { $0 / 1000 },
                    step: 0.5,
                    closedRange: nil
                )
            ))
            fields.append(Field(
                kind: .duration,
                title: "Min",
                accessibilityIdentifier: identifier("duration", entryIndex: entryIndex, setIndex: setIndex),
                value: .integer(
                    value: set.durationSeconds.map { $0 / 60 },
                    placeholder: set.targetDurationSeconds.map { $0 / 60 },
                    step: 5,
                    closedRange: nil
                )
            ))
        case .durationOnly:
            fields.append(Field(
                kind: .duration,
                title: "Min",
                accessibilityIdentifier: identifier("duration", entryIndex: entryIndex, setIndex: setIndex),
                value: .integer(
                    value: set.durationSeconds.map { $0 / 60 },
                    placeholder: set.targetDurationSeconds.map { $0 / 60 },
                    step: 5,
                    closedRange: nil
                )
            ))
        }

        fields.append(effortField(set: set, entryIndex: entryIndex, setIndex: setIndex))
        return ActiveWorkoutSetInputFieldsState(fields: fields)
    }

    private static func repsField(set: SetDraft, entryIndex: Int, setIndex: Int) -> Field {
        Field(
            kind: .reps,
            title: "Reps",
            accessibilityIdentifier: identifier("reps", entryIndex: entryIndex, setIndex: setIndex),
            value: .integer(
                value: set.reps,
                placeholder: set.targetReps,
                step: 1,
                closedRange: nil
            )
        )
    }

    private static func effortField(set: SetDraft, entryIndex: Int, setIndex: Int) -> Field {
        if set.targetRIR != nil && set.targetRPE == nil {
            return Field(
                kind: .rir,
                title: "RIR",
                accessibilityIdentifier: identifier("rir", entryIndex: entryIndex, setIndex: setIndex),
                value: .integer(
                    value: set.rir,
                    placeholder: set.targetRIR,
                    step: 1,
                    closedRange: 0...10
                )
            )
        }

        return Field(
            kind: .rpe,
            title: "RPE",
            accessibilityIdentifier: identifier("rpe", entryIndex: entryIndex, setIndex: setIndex),
            value: .decimal(
                value: set.rpe,
                placeholder: set.targetRPE,
                step: 0.5,
                closedRange: 1...10
            )
        )
    }

    private static func displayWeight(_ weightKg: Double?, weightUnit: WeightUnit) -> Double? {
        weightKg.map { $0 / weightUnit.conversionToKg }
    }

    private static func identifier(_ field: String, entryIndex: Int, setIndex: Int) -> String {
        "activeWorkout.field.\(field).\(entryIndex).\(setIndex)"
    }
}

struct FinishWorkoutViewState: Equatable {
    var navigationTitle: String
    var keepEditingTitle: String
    var keepEditingAccessibilityIdentifier: String
    var commitActionTitle: String
    var commitAccessibilityIdentifier: String
    var commitAccessibilityValue: String
    var heroKicker: String
    var heroTitle: String
    var heroBody: String
    var stateText: String
    var stateAccessibilityIdentifier: String
    var rpeLabel: String
    var rpeAccessibilityIdentifier: String
    var saveAsTemplateTitle: String
    var saveAsTemplateAccessibilityIdentifier: String
    var showsTemplateName: Bool
    var templateNameTitle: String
    var templateNameValue: String
    var templateNamePlaceholder: String
    var templateNameAccessibilityIdentifier: String

    static func make(
        sessionName: String,
        sportType: SportType,
        rpe: Double,
        saveAsTemplate: Bool,
        templateName: String
    ) -> FinishWorkoutViewState {
        let target = saveAsTemplate ? "workout and template" : "workout"
        return FinishWorkoutViewState(
            navigationTitle: "Finish Workout",
            keepEditingTitle: "Keep Editing",
            keepEditingAccessibilityIdentifier: "finishWorkout.keepEditing",
            commitActionTitle: "Finish Workout",
            commitAccessibilityIdentifier: "finishWorkout.commit",
            commitAccessibilityValue: "Ready to save \(target) at RPE \(Int(rpe))",
            heroKicker: sportType.displayName,
            heroTitle: "RPE \(Int(rpe))",
            heroBody: sessionName,
            stateText: "Ready to save \(target) at RPE \(Int(rpe))",
            stateAccessibilityIdentifier: "finishWorkout.state",
            rpeLabel: "Session RPE",
            rpeAccessibilityIdentifier: "finishWorkout.rpe",
            saveAsTemplateTitle: "Save as Template",
            saveAsTemplateAccessibilityIdentifier: "finishWorkout.saveAsTemplate",
            showsTemplateName: saveAsTemplate,
            templateNameTitle: "Template Name",
            templateNameValue: templateName,
            templateNamePlaceholder: sessionName,
            templateNameAccessibilityIdentifier: "finishWorkout.templateName"
        )
    }
}

struct WorkoutPostSaveFeedback: Equatable {
    struct Item: Equatable {
        let identifier: String
        let title: String
        let detail: String
        let isWarning: Bool
    }

    let navigationTitle: String
    let heroKicker: String
    let title: String
    let summary: String
    let doneActionTitle: String
    let doneAccessibilityIdentifier: String
    let doneAccessibilityValue: String
    let warningLabel: String
    let items: [Item]

    var hasWarning: Bool {
        items.contains { $0.isWarning }
    }

    static func make(
        result: WorkoutPipeline.PipelineResult? = nil,
        templateSaved: Bool
    ) -> WorkoutPostSaveFeedback {
        var items: [Item] = [
            Item(
                identifier: "workoutPostSave.item.saved",
                title: "Workout logged",
                detail: "Your completed sets were saved and workload was updated.",
                isWarning: false
            )
        ]

        if templateSaved {
            items.append(Item(
                identifier: "workoutPostSave.item.template",
                title: "Template saved",
                detail: "This session is available from the template picker.",
                isWarning: false
            ))
        }

        if let result {
            if !result.newPRs.isEmpty {
                let count = result.newPRs.count
                let suffix = count == 1 ? "" : "s"
                items.append(Item(
                    identifier: "workoutPostSave.item.pr",
                    title: "\(count) new PR\(suffix)",
                    detail: result.newPRs.map(\.exerciseName).prefix(3).joined(separator: " · "),
                    isWarning: false
                ))
            }

            if let spike = result.spikeAlert {
                items.append(Item(
                    identifier: "workoutPostSave.item.spike",
                    title: "Load spike",
                    detail: "Session load \(Int(spike.sessionTSS)) vs recent \(Int(spike.averageTSS)). Add recovery if needed.",
                    isWarning: true
                ))
            }
        }

        let summary: String
        if items.contains(where: { $0.identifier == "workoutPostSave.item.spike" }) {
            summary = "Saved with a load warning."
        } else if items.count > 1 {
            summary = "Saved with follow-up notes."
        } else {
            summary = "Saved and ready for your next session."
        }

        return WorkoutPostSaveFeedback(
            navigationTitle: "Saved",
            heroKicker: "Workout",
            title: "Session Saved",
            summary: summary,
            doneActionTitle: "Done",
            doneAccessibilityIdentifier: "workoutPostSave.done",
            doneAccessibilityValue: "Workout saved",
            warningLabel: "Warning",
            items: items
        )
    }
}

struct ActiveWorkoutSessionSettingsViewState: Equatable {
    struct Row: Equatable {
        var title: String
        var value: String
        var accessibilityIdentifier: String
        var accessibilityLabel: String
    }

    var navigationTitle: String
    var cancelTitle: String
    var cancelAccessibilityIdentifier: String
    var doneActionTitle: String
    var doneAccessibilityIdentifier: String
    var heroKicker: String
    var heroTitle: String
    var heroBody: String
    var stateText: String
    var stateAccessibilityIdentifier: String
    var sportChoiceTitle: String
    var sessionTypeChoiceTitle: String
    var sportRow: Row
    var sessionTypeRow: Row

    static func make(
        sportType: SportType,
        sessionType: SessionType
    ) -> ActiveWorkoutSessionSettingsViewState {
        let stateText = "\(sportType.displayName) - \(sessionType.displayName)"
        return ActiveWorkoutSessionSettingsViewState(
            navigationTitle: "Session Settings",
            cancelTitle: "Cancel",
            cancelAccessibilityIdentifier: "activeWorkout.settings.cancel",
            doneActionTitle: "Done",
            doneAccessibilityIdentifier: "activeWorkout.settings.done",
            heroKicker: "Session",
            heroTitle: "Settings",
            heroBody: "Sport and session type live here so the workout stays focused.",
            stateText: stateText,
            stateAccessibilityIdentifier: "activeWorkout.settings.state",
            sportChoiceTitle: "Sport",
            sessionTypeChoiceTitle: "Session Type",
            sportRow: Row(
                title: "Sport",
                value: sportType.displayName,
                accessibilityIdentifier: "activeWorkout.settings.sport",
                accessibilityLabel: "Sport, \(sportType.displayName)"
            ),
            sessionTypeRow: Row(
                title: "Type",
                value: sessionType.displayName,
                accessibilityIdentifier: "activeWorkout.settings.type",
                accessibilityLabel: "Type, \(sessionType.displayName)"
            )
        )
    }
}

struct ExercisePickerViewState: Equatable {
    struct Row: Equatable {
        var title: String
        var detail: String
        var accessibilityIdentifier: String
        var accessibilityLabel: String
    }

    var navigationTitle: String
    var cancelTitle: String
    var cancelAccessibilityIdentifier: String
    var heroKicker: String
    var heroTitle: String
    var heroBody: String
    var stateText: String
    var stateAccessibilityIdentifier: String
    var rows: [Row]

    static func make(
        sportType: SportType,
        exercises: [ExerciseDefinition]
    ) -> ExercisePickerViewState {
        ExercisePickerViewState(
            navigationTitle: "Exercise",
            cancelTitle: "Cancel",
            cancelAccessibilityIdentifier: "exercisePicker.cancel",
            heroKicker: sportType.displayName,
            heroTitle: "Add exercise",
            heroBody: "Choose the next movement for this session.",
            stateText: "\(exercises.count) movements available",
            stateAccessibilityIdentifier: "exercisePicker.state",
            rows: exercises.map { exercise in
                Row(
                    title: exercise.name,
                    detail: exerciseDetail(exercise),
                    accessibilityIdentifier: "exercisePicker.exercise",
                    accessibilityLabel: exercise.name
                )
            }
        )
    }

    private static func exerciseDetail(_ exercise: ExerciseDefinition) -> String {
        [
            exercise.category.displayName,
            exercise.muscleGroup?.displayName,
            exercise.isCustom ? "Custom" : nil
        ]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

struct ActiveWorkoutAlertState: Equatable {
    enum ActionRole: Equatable {
        case normal
        case cancel
        case destructive
    }

    struct Action: Equatable {
        var title: String
        var role: ActionRole
    }

    var title: String
    var message: String?
    var actions: [Action]

    static func unsavedChanges(locale: Locale) -> ActiveWorkoutAlertState {
        ActiveWorkoutAlertState(
            title: UIKitStrings.localized(
                "workout.unsaved.title",
                defaultValue: "Unsaved workout",
                locale: locale
            ),
            message: UIKitStrings.localized(
                "workout.unsaved.message",
                defaultValue: "Your changes have not been saved. Keep editing or discard this workout.",
                locale: locale
            ),
            actions: [
                Action(
                    title: UIKitStrings.localized(
                        "action.keepEditing",
                        defaultValue: "Keep Editing",
                        locale: locale
                    ),
                    role: .cancel
                ),
                Action(
                    title: UIKitStrings.localized(
                        "action.discardChanges",
                        defaultValue: "Discard Changes",
                        locale: locale
                    ),
                    role: .destructive
                )
            ]
        )
    }

    static func noCompletedSets(locale: Locale) -> ActiveWorkoutAlertState {
        ActiveWorkoutAlertState(
            title: UIKitStrings.localized(
                "workout.save.noDone.title",
                defaultValue: "No sets marked done",
                locale: locale
            ),
            message: UIKitStrings.localized(
                "workout.save.noDone.message",
                defaultValue: "Nothing will be logged. Mark sets done to record them, or discard this session?",
                locale: locale
            ),
            actions: [
                Action(
                    title: UIKitStrings.localized(
                        "action.cancel",
                        defaultValue: "Cancel",
                        locale: locale
                    ),
                    role: .cancel
                ),
                Action(
                    title: UIKitStrings.localized(
                        "workout.save.noDone.discard",
                        defaultValue: "Discard session",
                        locale: locale
                    ),
                    role: .destructive
                )
            ]
        )
    }

    static func saveFailure(errorDescription: String, locale: Locale) -> ActiveWorkoutAlertState {
        ActiveWorkoutAlertState(
            title: UIKitStrings.localized(
                "workout.save.failed.title",
                defaultValue: "Could not save session",
                locale: locale
            ),
            message: errorDescription,
            actions: [
                Action(
                    title: UIKitStrings.localized(
                        "action.ok",
                        defaultValue: "OK",
                        locale: locale
                    ),
                    role: .normal
                )
            ]
        )
    }
}

struct InsightsOverviewViewState: Equatable {
    struct Metric: Equatable {
        var label: String
        var value: String
        var detail: String
    }

    struct Insight: Equatable {
        var identifier: String
        var title: String
        var whatChanged: String
        var whyItMatters: String
        var watchNext: String
    }

    var heroKicker: String
    var headline: String
    var body: String
    var signalMetrics: [Metric]
    var insights: [Insight]

    static func make(
        recoverySnapshots: [RecoverySnapshot],
        workloadSnapshots: [WorkloadSnapshot],
        sessions: [WorkoutSession],
        locale: Locale
    ) -> InsightsOverviewViewState {
        let latestRecovery = recoverySnapshots.first
        let latestWorkload = workloadSnapshots.first
        let latestSession = sessions.first

        return InsightsOverviewViewState(
            heroKicker: "Cross-signal read",
            headline: headline(recovery: latestRecovery, workload: latestWorkload),
            body: meaning(recovery: latestRecovery, workload: latestWorkload),
            signalMetrics: [
                Metric(
                    label: "Recovery",
                    value: latestRecovery.map { "\(Int($0.recoveryScore))" } ?? "--",
                    detail: latestRecovery?.zone.displayName ?? "No data"
                ),
                Metric(
                    label: "Load",
                    value: latestWorkload.map { String(format: "%.2f", $0.acwr) } ?? "--",
                    detail: latestWorkload?.zone.displayName ?? "No data"
                ),
                Metric(
                    label: "Last session",
                    value: latestSession.map { String(format: "%.0f", $0.trainingStress) } ?? "--",
                    detail: latestSession?.sessionDate.relativeString(locale: locale) ?? "No sessions"
                )
            ],
            insights: insights(
                recoverySnapshots: recoverySnapshots,
                workloadSnapshots: workloadSnapshots,
                sessions: sessions
            )
        )
    }

    private static func insights(
        recoverySnapshots: [RecoverySnapshot],
        workloadSnapshots: [WorkloadSnapshot],
        sessions: [WorkoutSession]
    ) -> [Insight] {
        var rows: [Insight] = []
        if let recovery = recoveryInsight(from: recoverySnapshots) {
            rows.append(recovery)
        }
        if let workload = workloadInsight(from: workloadSnapshots) {
            rows.append(workload)
        }
        if let relationship = relationshipInsight(recovery: recoverySnapshots.first, workload: workloadSnapshots.first) {
            rows.append(relationship)
        }
        if let session = sessionInsight(from: sessions) {
            rows.append(session)
        }
        if rows.isEmpty {
            rows.append(Insight(
                identifier: "baseline",
                title: "Baseline is still forming",
                whatChanged: "There is not enough recent recovery or load history to compare yet.",
                whyItMatters: "The overview becomes useful when it can compare body state with training stress.",
                watchNext: "Connect recovery signals and log the next few sessions."
            ))
        }
        return Array(rows.prefix(4))
    }

    private static func recoveryInsight(from snapshots: [RecoverySnapshot]) -> Insight? {
        guard let latest = snapshots.first else { return nil }
        let comparison = average(snapshots.dropFirst().prefix(7).map(\.recoveryScore))
        let changeText: String
        if let comparison {
            let delta = latest.recoveryScore - comparison
            if abs(delta) < 3 {
                changeText = "Recovery is stable at \(Int(latest.recoveryScore)) versus the recent baseline."
            } else if delta > 0 {
                changeText = "Recovery is up \(Int(delta.rounded())) points versus the recent baseline."
            } else {
                changeText = "Recovery is down \(Int(abs(delta).rounded())) points versus the recent baseline."
            }
        } else {
            changeText = "Recovery is \(latest.zone.displayName.lowercased()) at \(Int(latest.recoveryScore))."
        }

        let why: String
        switch latest.zone {
        case .green:
            why = "This supports normal training if load is also controlled."
        case .yellow:
            why = "This is a caution state: training can continue, but intensity should earn its place."
        case .red:
            why = "This raises injury and under-recovery risk when paired with hard training."
        }

        return Insight(
            identifier: "recovery",
            title: "Recovery trend",
            whatChanged: changeText,
            whyItMatters: why,
            watchNext: recoveryWatchText(latest)
        )
    }

    private static func workloadInsight(from snapshots: [WorkloadSnapshot]) -> Insight? {
        guard let latest = snapshots.first else { return nil }
        let comparison = average(snapshots.dropFirst().prefix(7).map(\.acuteLoad))
        let changeText: String
        if let comparison, comparison > 0 {
            let percent = ((latest.acuteLoad - comparison) / comparison) * 100
            if abs(percent) < 8 {
                changeText = "Acute load is steady versus the recent week."
            } else if percent > 0 {
                changeText = "Acute load is up \(Int(percent.rounded()))% versus the recent week."
            } else {
                changeText = "Acute load is down \(Int(abs(percent).rounded()))% versus the recent week."
            }
        } else {
            changeText = "ACWR is \(String(format: "%.2f", latest.acwr)) in the \(latest.zone.displayName.lowercased()) range."
        }

        let why: String
        switch latest.zone {
        case .danger:
            why = "High acute load can outpace chronic capacity and increase fatigue cost."
        case .caution:
            why = "Load is building; progression is useful only if recovery keeps up."
        case .optimal:
            why = "Acute and chronic load are balanced enough for normal progression."
        case .undertrained:
            why = "Load is light relative to recent capacity, which may reduce readiness for harder work."
        case .noData:
            why = "Load balance needs more completed sessions before it can guide decisions."
        }

        return Insight(
            identifier: "load",
            title: "Load trend",
            whatChanged: changeText,
            whyItMatters: why,
            watchNext: workloadWatchText(latest)
        )
    }

    private static func relationshipInsight(recovery: RecoverySnapshot?, workload: WorkloadSnapshot?) -> Insight? {
        guard let recovery, let workload else { return nil }
        let title: String
        let changed: String
        let why: String
        let next: String

        if recovery.zone == .green && workload.zone == .optimal {
            title = "Recovery and load are aligned"
            changed = "Recovery is green while ACWR is in the steady range."
            why = "That pairing usually supports planned work without forcing extra constraint."
            next = "Keep the next hard session close to plan and watch for sleep or HRV drift."
        } else if recovery.zone == .red || workload.zone == .danger {
            title = "Stress signals are elevated"
            changed = "At least one primary signal is in a high-attention state."
            why = "Hard work has a higher cost when readiness is low or acute load is high."
            next = "Favor reduced volume, lower intensity, or recovery work until the pairing improves."
        } else {
            title = "Signals are mixed"
            changed = "Recovery and load are not pointing in the same direction."
            why = "Mixed states need smaller decisions because one system may be absorbing the cost of the other."
            next = "Use the next session result to confirm whether this is adaptation or accumulating fatigue."
        }

        return Insight(identifier: "relationship", title: title, whatChanged: changed, whyItMatters: why, watchNext: next)
    }

    private static func sessionInsight(from sessions: [WorkoutSession]) -> Insight? {
        guard let session = sessions.first else { return nil }
        let loadText = session.trainingStress > 0
            ? "\(Int(session.trainingStress.rounded())) load"
            : "no computed load"
        let effortText = session.sessionRPE.map { "RPE \(Int($0.rounded()))" } ?? "no session RPE"
        return Insight(
            identifier: "session",
            title: "Latest session context",
            whatChanged: "\(session.sessionName ?? session.sportType.displayName) added \(loadText) with \(effortText).",
            whyItMatters: "Recent session cost explains whether today’s recovery and ACWR moved for training reasons.",
            watchNext: "If the next recovery score drops, compare it with this session’s load and effort."
        )
    }

    private static func recoveryWatchText(_ snapshot: RecoverySnapshot) -> String {
        if let sleep = snapshot.sleepDurationMinutes, sleep < 390 {
            return "Sleep is below 6.5 hours; treat it as the first lever to restore."
        }
        if let hrv = snapshot.hrvSDNN, let baseline = snapshot.hrvBaseline, hrv < baseline * 0.9 {
            return "HRV is materially below baseline; avoid stacking another hard day."
        }
        if let rhr = snapshot.restingHR, let baseline = snapshot.restingHRBaseline, rhr > baseline + 5 {
            return "Resting heart rate is elevated; watch illness, heat, stress, or poor sleep."
        }
        return "Watch whether the next recovery score confirms this trend or snaps back."
    }

    private static func workloadWatchText(_ snapshot: WorkloadSnapshot) -> String {
        switch snapshot.zone {
        case .danger:
            return "Look for a load spike before adding intensity."
        case .caution:
            return "Keep volume increases small until ACWR returns toward steady."
        case .optimal:
            return "Use session quality and recovery to decide whether to progress."
        case .undertrained:
            return "Build gradually rather than jumping straight back to high load."
        case .noData:
            return "Log completed sessions to build a reliable load baseline."
        }
    }

    private static func average<S: Sequence>(_ values: S) -> Double? where S.Element == Double {
        let array = Array(values)
        guard !array.isEmpty else { return nil }
        return array.reduce(0, +) / Double(array.count)
    }

    private static func headline(recovery: RecoverySnapshot?, workload: WorkloadSnapshot?) -> String {
        if let recovery, let workload {
            if recovery.zone == .red || workload.zone == .danger {
                return "Attention is warranted"
            }
            if recovery.zone == .green && workload.zone == .optimal {
                return "Your signals are aligned"
            }
            return "Your state is mixed"
        }
        return "Build the baseline"
    }

    private static func meaning(recovery: RecoverySnapshot?, workload: WorkloadSnapshot?) -> String {
        if recovery == nil && workload == nil {
            return "Log training and connect recovery signals to make trend interpretation reliable."
        }
        if recovery == nil {
            return "Training load is visible. Recovery context will sharpen this once recent Health data arrives."
        }
        if workload == nil {
            return "Recovery is visible. Load context will sharpen this once you log training."
        }
        return "Use Recovery and Load inside Insights for the method, history, and supporting evidence."
    }
}

struct RecoveryInsightsViewState: Equatable {
    struct Metric: Equatable {
        var label: String
        var value: String
        var detail: String
    }

    struct TrendRow: Equatable {
        var title: String
        var subtitle: String
        var trailing: String
    }

    var heroKicker: String
    var scoreText: String
    var body: String
    var signalMetrics: [Metric]
    var trendRows: [TrendRow]
    var emptyTrendTitle: String
    var emptyTrendBody: String

    static func make(snapshots: [RecoverySnapshot], locale: Locale) -> RecoveryInsightsViewState {
        let latest = snapshots.first
        return RecoveryInsightsViewState(
            heroKicker: "Recovery",
            scoreText: latest.map { "\(Int($0.recoveryScore))" } ?? "No data",
            body: recoveryBody(latest: latest, locale: locale),
            signalMetrics: [
                Metric(
                    label: "HRV",
                    value: latest?.hrvSDNN.map { "\(Int($0))" } ?? "--",
                    detail: latest?.hrvBaseline.map { "Baseline \(Int($0))" } ?? "No baseline"
                ),
                Metric(
                    label: "RHR",
                    value: latest?.restingHR.map { "\(Int($0))" } ?? "--",
                    detail: latest?.restingHRBaseline.map { "Baseline \(Int($0))" } ?? "No baseline"
                ),
                Metric(
                    label: "Sleep",
                    value: latest?.sleepDurationMinutes.map { String(format: "%.1f", $0 / 60) } ?? "--",
                    detail: "hours"
                )
            ],
            trendRows: snapshots.prefix(5).map { snapshot in
                TrendRow(
                    title: snapshot.date.relativeString(locale: locale),
                    subtitle: snapshot.zone.displayName,
                    trailing: "\(Int(snapshot.recoveryScore))"
                )
            },
            emptyTrendTitle: "No recovery trend yet",
            emptyTrendBody: "Recent HRV, resting heart rate, and sleep will appear here once available."
        )
    }

    private static func recoveryBody(latest: RecoverySnapshot?, locale: Locale) -> String {
        guard let latest else {
            return "Connect recovery signals and keep logging to build a useful baseline."
        }
        return "\(latest.zone.displayName) · Updated \(latest.date.relativeString(locale: locale))"
    }
}

struct LoadInsightsViewState: Equatable {
    struct Metric: Equatable {
        var label: String
        var value: String
        var detail: String
    }

    struct VolumeRow: Equatable {
        var title: String
        var subtitle: String
        var trailing: String
    }

    var heroKicker: String
    var acwrText: String
    var body: String
    var balanceMetrics: [Metric]
    var volumeRows: [VolumeRow]
    var emptyVolumeTitle: String
    var emptyVolumeBody: String

    static func make(snapshots: [WorkloadSnapshot], locale: Locale) -> LoadInsightsViewState {
        let latest = snapshots.first
        return LoadInsightsViewState(
            heroKicker: "Load",
            acwrText: latest.map { String(format: "%.2f", $0.acwr) } ?? "No data",
            body: loadBody(latest: latest, locale: locale),
            balanceMetrics: [
                Metric(
                    label: "ATL",
                    value: latest.map { String(format: "%.0f", $0.acuteLoad) } ?? "--",
                    detail: "Acute"
                ),
                Metric(
                    label: "CTL",
                    value: latest.map { String(format: "%.0f", $0.chronicLoad) } ?? "--",
                    detail: "Chronic"
                ),
                Metric(
                    label: "TSB",
                    value: latest.map { String(format: "%.0f", $0.tsb) } ?? "--",
                    detail: "Balance"
                )
            ],
            volumeRows: snapshots.prefix(5).map { snapshot in
                VolumeRow(
                    title: snapshot.snapshotDate.relativeString(locale: locale),
                    subtitle: snapshot.zone.displayName,
                    trailing: String(format: "%.0f", snapshot.weeklyVolume)
                )
            },
            emptyVolumeTitle: "No workload trend yet",
            emptyVolumeBody: "Workout volume, ACWR, ATL, CTL, and TSB will appear here after logging."
        )
    }

    private static func loadBody(latest: WorkloadSnapshot?, locale: Locale) -> String {
        guard let latest else {
            return "Log sessions to build acute and chronic workload history."
        }
        return "\(latest.zone.displayName) · Updated \(latest.snapshotDate.relativeString(locale: locale))"
    }
}

struct ProfileOverviewViewState: Equatable {
    var heroKicker: String
    var athleteName: String
    var contextText: String
    var showsCoachContext: Bool
    var coachModeTrailing: String
    var syncStatusText: String
    var languageText: String
    var subscriptionText: String

    static func make(
        athlete: Athlete?,
        isCoachEntitled: Bool,
        isProEntitled: Bool,
        hasSyncFailure: Bool,
        locale: Locale
    ) -> ProfileOverviewViewState {
        ProfileOverviewViewState(
            heroKicker: UIKitStrings.localized("profile.nav.title", locale: locale),
            athleteName: athlete?.displayName ?? UIKitStrings.localized("profile.section.athlete", locale: locale),
            contextText: "\(athlete.map { sportDisplayName($0.sportType, locale: locale) } ?? UIKitStrings.localized("profile.section.training", locale: locale)) · \(UIKitStrings.localized("profile.context.athlete", locale: locale))",
            showsCoachContext: athlete?.isCoach == true && athlete?.isCoachOnly == false,
            coachModeTrailing: isCoachEntitled
                ? UIKitStrings.localized("profile.context.open", locale: locale)
                : UIKitStrings.localized("profile.subscription.coach", locale: locale),
            syncStatusText: hasSyncFailure
                ? UIKitStrings.localized("profile.sync.issues", locale: locale)
                : UIKitStrings.localized("profile.sync.allSynced", locale: locale),
            languageText: locale.language.languageCode?.identifier == "zh" ? "中文" : "English",
            subscriptionText: subscriptionText(
                isCoachEntitled: isCoachEntitled,
                isProEntitled: isProEntitled,
                locale: locale
            )
        )
    }

    private static func subscriptionText(
        isCoachEntitled: Bool,
        isProEntitled: Bool,
        locale: Locale
    ) -> String {
        if isCoachEntitled {
            return UIKitStrings.localized("profile.subscription.coach", locale: locale)
        }
        if isProEntitled {
            return UIKitStrings.localized("profile.subscription.athletePro", locale: locale)
        }
        return UIKitStrings.localized("profile.subscription.free", locale: locale)
    }

    private static func sportDisplayName(_ sport: SportType, locale: Locale) -> String {
        switch sport {
        case .lifting:
            return UIKitStrings.localized("sport.lifting", defaultValue: "Lifting", locale: locale)
        case .running:
            return UIKitStrings.localized("sport.running", defaultValue: "Running", locale: locale)
        case .cycling:
            return UIKitStrings.localized("sport.cycling", defaultValue: "Cycling", locale: locale)
        case .teamSport:
            return UIKitStrings.localized("sport.teamSport", defaultValue: "Team Sport", locale: locale)
        case .crossfit:
            return UIKitStrings.localized("sport.crossfit", defaultValue: "CrossFit", locale: locale)
        case .swimming:
            return UIKitStrings.localized("sport.swimming", defaultValue: "Swimming", locale: locale)
        case .custom:
            return UIKitStrings.localized("sport.custom", defaultValue: "Custom", locale: locale)
        }
    }
}

struct CoachRosterViewState: Equatable {
    struct AthleteRow: Equatable {
        var athleteID: UUID
        var name: String
        var sportText: String
        var rosterText: String
        var accessibilityText: String
    }

    var clientCount: Int
    var heroKicker: String
    var countText: String
    var statusText: String
    var rows: [AthleteRow]
    var emptyTitle: String
    var emptyBody: String

    static func make(
        linkedAthletes: [Athlete],
        recovery: [RecoverySnapshot],
        workload: [WorkloadSnapshot],
        sessions: [WorkoutSession],
        prescriptions: [PrescribedWorkout],
        locale: Locale
    ) -> CoachRosterViewState {
        CoachRosterViewState(
            clientCount: linkedAthletes.count,
            heroKicker: "Roster",
            countText: "\(linkedAthletes.count)",
            statusText: "Accepted athlete connections in the coach context.",
            rows: linkedAthletes.map { athlete in
                let summary = athleteSummary(
                    athlete: athlete,
                    recovery: recovery,
                    workload: workload,
                    sessions: sessions,
                    prescriptions: prescriptions,
                    locale: locale
                )
                return AthleteRow(
                    athleteID: athlete.id,
                    name: athlete.displayName,
                    sportText: athlete.sportType.displayName,
                    rosterText: summary.rosterText,
                    accessibilityText: summary.accessibilityText
                )
            },
            emptyTitle: "No athletes yet",
            emptyBody: "Invite athletes from Profile, then return here to monitor recovery, load, and assigned plans."
        )
    }

    private static func athleteSummary(
        athlete: Athlete,
        recovery: [RecoverySnapshot],
        workload: [WorkloadSnapshot],
        sessions: [WorkoutSession],
        prescriptions: [PrescribedWorkout],
        locale: Locale
    ) -> (rosterText: String, accessibilityText: String) {
        let athleteId = athlete.id
        let latestRecovery = recovery.first { $0.athlete?.id == athleteId }
        let latestWorkload = workload.first { $0.athlete?.id == athleteId }
        let latestSession = sessions.first { $0.athlete?.id == athleteId }
        let athletePrescriptions = prescriptions.filter { $0.athleteId == athleteId }
        let pendingCount = athletePrescriptions.filter { $0.status == .assigned }.count
        let todayPlan = athletePrescriptions.first {
            Calendar.current.isDateInToday($0.scheduledDate) && $0.status == .assigned
        }

        let today = todayPlan.map { "Today: \($0.templateName) assigned" } ?? "Today: No assigned plan"
        let last = latestSession.map {
            "Last session: \($0.sessionName ?? $0.sportType.displayName), \($0.sessionDate.relativeString(locale: locale))"
        } ?? "Last session: No sessions"
        let attention = "Attention: \(latestRecovery?.zone.displayName ?? "No recovery") · \(latestWorkload?.zone.displayName ?? "No load")"
        let pending = pendingCount > 0 ? "Pending plan: \(pendingCount)" : "Pending plan: None"
        let parts = [today, last, attention, pending]
        return (parts.joined(separator: "  "), parts.joined(separator: ", "))
    }
}
