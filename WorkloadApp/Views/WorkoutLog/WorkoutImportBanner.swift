import SwiftUI
import SwiftData
import HealthKit

/// Banner shown at top of WorkoutLogView when unmatched HealthKit workouts are detected
struct WorkoutImportBanner: View {
    let imports: [WorkoutImportSuggestion]
    let onAccept: (WorkoutImportSuggestion) -> Void
    let onDismiss: (WorkoutImportSuggestion) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Banner stamp — marginalia, so the annotation voice (v6).
            AnnotationLabel(key: "import.watch.header")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.sm)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.xs)

            ForEach(imports) { suggestion in
                ImportSuggestionRow(
                    suggestion: suggestion,
                    onAccept: { onAccept(suggestion) },
                    onDismiss: { onDismiss(suggestion) }
                )
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
            }
        }
        // Grouped region → a single bordered card plane (`CornerTokens.card`, v3 Corner Law);
        // row hairlines inside are clipped by the card shape.
        .background(ColorTokens.surfaceEl)
        .clipShape(RoundedRectangle(cornerRadius: CornerTokens.card))
        .overlay(RoundedRectangle(cornerRadius: CornerTokens.card).stroke(ColorTokens.divider, lineWidth: 0.5))
    }
}

private struct ImportSuggestionRow: View {
    let suggestion: WorkoutImportSuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: suggestion.sportType.systemImage)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                Text(suggestion.name)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                // Timestamp + duration + unitized energy — marginalia (v6).
                HStack(spacing: Spacing.xs) {
                    AnnotationLabel(
                        suggestion.date.relativeString(locale: locale),
                        color: ColorTokens.text2
                    )
                    AnnotationLabel(
                        Date.durationString(seconds: suggestion.durationSeconds, locale: locale),
                        color: ColorTokens.text2
                    )
                    if let cal = suggestion.activeCalories {
                        AnnotationLabel("\(Int(cal)) kcal", color: ColorTokens.text2)
                    }
                }
            }

            Spacer()

            Button {
                Haptics.tap()
                onAccept()
            } label: {
                Text("action.add")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .overlay(RoundedRectangle(cornerRadius: CornerTokens.control).stroke(ColorTokens.dividerStrong, lineWidth: 0.5))
            }
            .buttonStyle(.pressable)

            Button {
                Haptics.tap()
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text3)
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Import Suggestion Model

struct WorkoutImportSuggestion: Identifiable {
    let id: UUID
    let hkWorkoutUUID: UUID
    let name: String
    let sportType: SportType
    let sessionType: SessionType
    let date: Date
    let durationSeconds: Int
    let activeCalories: Double?
    let distanceMeters: Double?
    let averageHR: Double?

    init(from workout: HKWorkout) {
        self.id = UUID()
        self.hkWorkoutUUID = workout.uuid
        self.name = Self.workoutName(for: workout.workoutActivityType)
        self.sportType = Self.mapSportType(workout.workoutActivityType)
        self.sessionType = Self.mapSessionType(workout.workoutActivityType)
        self.date = workout.startDate
        self.durationSeconds = Int(workout.duration)
        self.activeCalories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
        self.distanceMeters = workout.totalDistance?.doubleValue(for: .meter())
        self.averageHR = nil // HR fetched separately if needed
    }

    static func mapSportType(_ activityType: HKWorkoutActivityType) -> SportType {
        switch activityType {
        case .running, .walking, .hiking:
            return .running
        case .cycling:
            return .cycling
        case .swimming:
            return .swimming
        case .basketball, .soccer, .tennis, .volleyball, .baseball, .hockey,
             .rugby, .handball, .lacrosse, .badminton, .tableTennis, .racquetball,
             .squash, .cricket, .softball:
            return .teamSport
        case .crossTraining, .functionalStrengthTraining, .highIntensityIntervalTraining:
            return .crossfit
        case .traditionalStrengthTraining:
            return .lifting
        default:
            return .custom
        }
    }

    static func mapSessionType(_ activityType: HKWorkoutActivityType) -> SessionType {
        switch activityType {
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return .strength
        case .running, .cycling, .swimming, .walking, .hiking, .rowing:
            return .cardio
        case .basketball, .soccer, .tennis, .volleyball, .baseball, .hockey:
            return .skill
        case .highIntensityIntervalTraining, .crossTraining:
            return .cardio
        default:
            return .cardio
        }
    }

    static func workoutName(for activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .running: return "Run"
        case .walking: return "Walk"
        case .hiking: return "Hike"
        case .cycling: return "Ride"
        case .swimming: return "Swim"
        case .basketball: return "Basketball"
        case .soccer: return "Soccer"
        case .tennis: return "Tennis"
        case .volleyball: return "Volleyball"
        case .baseball: return "Baseball"
        case .hockey: return "Hockey"
        case .rugby: return "Rugby"
        case .traditionalStrengthTraining: return "Strength Training"
        case .functionalStrengthTraining: return "Functional Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .crossTraining: return "Cross Training"
        case .rowing: return "Rowing"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .elliptical: return "Elliptical"
        case .stairClimbing: return "Stair Climbing"
        case .dance: return "Dance"
        case .martialArts: return "Martial Arts"
        case .boxing: return "Boxing"
        default: return "Workout"
        }
    }
}

// MARK: - Import Service

@MainActor
enum WorkoutImportService {
    /// Fetch HealthKit workouts not yet logged in the app
    static func findUnmatchedWorkouts(
        healthKit: HealthKitService,
        modelContext: ModelContext
    ) async -> [WorkoutImportSuggestion] {
        guard let hkWorkouts = try? await healthKit.fetchRecentWorkouts(days: 3) else {
            return []
        }

        // Get existing session dates for deduplication
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: .now)!
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.sessionDate >= threeDaysAgo }
        )
        let existingSessions = (try? modelContext.fetch(descriptor)) ?? []

        // Load dismissed import UUIDs from UserDefaults
        let dismissedUUIDs = Set(
            (UserDefaults.standard.array(forKey: "dismissedImportUUIDs") as? [String]) ?? []
        )

        return hkWorkouts.compactMap { hkWorkout in
            // Skip if already dismissed
            if dismissedUUIDs.contains(hkWorkout.uuid.uuidString) {
                return nil
            }

            // Skip if a session exists within 5 minutes of this workout's start time
            let matchTolerance: TimeInterval = 300
            let isMatched = existingSessions.contains { session in
                abs(session.sessionDate.timeIntervalSince(hkWorkout.startDate)) < matchTolerance
            }
            if isMatched { return nil }

            // Skip very short workouts (under 5 minutes)
            if hkWorkout.duration < 300 { return nil }

            return WorkoutImportSuggestion(from: hkWorkout)
        }
    }

    /// Dismiss a suggestion so it won't appear again
    static func dismissSuggestion(_ suggestion: WorkoutImportSuggestion) {
        var dismissed = (UserDefaults.standard.array(forKey: "dismissedImportUUIDs") as? [String]) ?? []
        dismissed.append(suggestion.hkWorkoutUUID.uuidString)
        // Keep only last 100 to avoid unbounded growth
        if dismissed.count > 100 { dismissed = Array(dismissed.suffix(100)) }
        UserDefaults.standard.set(dismissed, forKey: "dismissedImportUUIDs")
    }

    /// Create a WorkoutSession from an import suggestion
    static func createSession(
        from suggestion: WorkoutImportSuggestion,
        sessionRPE: Double,
        athlete: Athlete,
        modelContext: ModelContext
    ) -> WorkoutSession {
        let session = WorkoutSession(
            sessionDate: suggestion.date,
            sessionName: suggestion.name,
            sportType: suggestion.sportType,
            durationSeconds: suggestion.durationSeconds,
            sessionRPE: sessionRPE,
            sessionType: suggestion.sessionType
        )

        // For distance-based workouts, create a single exercise entry
        if let distance = suggestion.distanceMeters, distance > 0 {
            let entry = ExerciseEntry(
                exerciseName: suggestion.name,
                exerciseCategory: .cardio,
                muscleGroup: .fullBody,
                orderIndex: 0
            )
            let setRecord = SetRecord(
                setIndex: 0,
                durationSeconds: suggestion.durationSeconds,
                distanceMeters: distance,
                rpe: sessionRPE
            )
            entry.sets.append(setRecord)
            session.exerciseEntries.append(entry)
        }

        session.recalculateDerivedFields()
        session.athlete = athlete
        return session
    }
}
