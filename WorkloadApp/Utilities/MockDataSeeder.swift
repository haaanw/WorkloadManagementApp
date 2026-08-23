#if DEBUG
import Foundation
import SwiftData

/// Seeds realistic mock data for screenshots and testing.
/// Only available in DEBUG builds.
enum MockDataSeeder {

    /// Days of training history the seed lays down.
    ///
    /// Was 28. `PeriodizationEngine.checkSufficiency` needs **8 weeks** before it will name a
    /// training phase, so a 4-week seed put "Keep logging — periodization insights unlock after
    /// 8 weeks of consistent training" on the Dashboard — inside the App Store screenshot. The
    /// marketing set must show the app working, not the app waiting. 12 weeks also gives the
    /// Load tab's 12W range real data instead of a stub.
    private static let historyDays = 84

    /// Deterministic stand-in for `SystemRandomNumberGenerator`.
    ///
    /// The seed feeds the App Store capture run, which shoots en and zh-Hans as two separate
    /// simulator launches. With `Double.random(in:)` those two runs produced different chart
    /// shapes, different ACWR, and different session durations — two localizations of the same
    /// plate showing different data. SplitMix64 makes every launch identical.
    private struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64

        init(seed: UInt64) { state = seed }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    @MainActor
    static func seed(modelContext: ModelContext, athlete: Athlete) {
        let calendar = Calendar.current
        var rng = SeededGenerator(seed: 0x7577_6120_5345_4544)

        // Screenshot mode needs deterministic data on every launch because UI
        // tests create sessions and templates while exercising the flows.
        let allSnapshots = (try? modelContext.fetch(FetchDescriptor<RecoverySnapshot>())) ?? []
        for snapshot in allSnapshots { modelContext.delete(snapshot) }
        let staleSessions = (try? modelContext.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        for session in staleSessions { modelContext.delete(session) }
        let staleTemplates = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        for template in staleTemplates where template.athleteId == athlete.id || template.coachId == athlete.id {
            modelContext.delete(template)
        }
        let stalePrescriptions = (try? modelContext.fetch(FetchDescriptor<PrescribedWorkout>())) ?? []
        for prescription in stalePrescriptions where prescription.athleteId == athlete.id || prescription.coachId == athlete.id {
            modelContext.delete(prescription)
        }
        let staleWorkloads = (try? modelContext.fetch(FetchDescriptor<WorkloadSnapshot>())) ?? []
        for snap in staleWorkloads { modelContext.delete(snap) }
        let stalePRs = (try? modelContext.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        for pr in stalePRs { modelContext.delete(pr) }
        let staleCheckIns = (try? modelContext.fetch(FetchDescriptor<WellnessCheckIn>())) ?? []
        for ci in staleCheckIns { modelContext.delete(ci) }
        let staleVerdictEvents = (try? modelContext.fetch(FetchDescriptor<VerdictEvent>())) ?? []
        for event in staleVerdictEvents { modelContext.delete(event) }
        try? modelContext.save()

        athlete.displayName = "Alex Chen"
        athlete.sportType = .teamSport
        athlete.trainingFrequency = .fiveToSix
        athlete.experienceLevel = .advanced
        athlete.nextMatchDate = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: 2, to: .now) ?? .now
        )
        athlete.updatedAt = .now

        // Create `historyDays` of workout sessions (12 weeks)
        for dayOffset in stride(from: -(historyDays - 1), through: 0, by: 1) {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: .now) else { continue }

            // Rest days: every 4th day
            if (-dayOffset) % 4 == 3 { continue }

            let weekday = calendar.component(.weekday, from: date)
            let session: WorkoutSession

            switch weekday {
            case 2, 5: // Mon, Thu — strength
                session = createStrengthSession(date: date, weekNumber: (-dayOffset) / 7, rng: &rng)
            case 3, 6: // Tue, Fri — cardio
                session = createCardioSession(date: date, rng: &rng)
            case 4: // Wed — skills
                session = createSkillSession(date: date, rng: &rng)
            case 7: // Sat — long session
                session = createLongSession(date: date, weekNumber: (-dayOffset) / 7, rng: &rng)
            default:
                continue
            }

            session.athlete = athlete
            session.recalculateDerivedFields()
            modelContext.insert(session)
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: .now) {
            let match = createBasketballMatchSession(date: yesterday, tier: .match)
            match.athlete = athlete
            match.recalculateDerivedFields()
            modelContext.insert(match)
        }

        // Create recovery snapshots (daily)
        for dayOffset in stride(from: -(historyDays - 1), through: 0, by: 1) {
            // Floored to the start of the day (v1.7.2 / audit M5). An unfloored seed date
            // does not match the pipeline's own start-of-day upsert key, so a SCREENSHOT_MODE
            // run followed by a real pipeline run produced TWO rows for the same day and the
            // hero score became whichever one the fetch happened to return first.
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: .now)
                .map({ calendar.startOfDay(for: $0) }) else { continue }

            // Non-negative remainder. `dayOffset % 7` keeps the sign of the dividend in Swift, so
            // once the window grew past 28 days the old `(dayOffset + 28) % 7` went negative and
            // drove HRV and sleep BELOW their intended floors — the opposite of what the comment
            // below promises.
            let phase = Double(((dayOffset % 7) + 7) % 7)
            let baseHRV = 48.0 + phase
            let baseRHR = 58.0 - min(phase, 3)
            // Centred ABOVE the 7.5 h target (450 min), not on the old 7 h one: this seed feeds
            // the App Store screenshot run, and a 420-min floor showed a permanently
            // under-target athlete in the marketing set. 456–492 min = 7.6–8.2 h.
            let baseSleep = 456.0 + phase * 6

            let snapshot = RecoverySnapshot(
                date: date,
                hrvSDNN: baseHRV,
                restingHR: baseRHR,
                sleepDurationMinutes: baseSleep,
                sleepScore: min(100, max(20, baseSleep / 4.8)),
                recoveryScore: min(100, max(15, baseHRV * 1.2 + (65 - baseRHR) * 2)),
                hrvBaseline: 48.0,
                restingHRBaseline: 60.0
            )
            snapshot.athlete = athlete
            modelContext.insert(snapshot)
        }

        // Create workload snapshots (compute from sessions)
        seedWorkloadSnapshots(modelContext: modelContext, athlete: athlete)

        // Create some personal records
        let prs = [
            PersonalRecord(exerciseName: "Barbell Back Squat", recordType: .maxWeight, value: 142.5, achievedAt: calendar.date(byAdding: .day, value: -7, to: .now)!),
            PersonalRecord(exerciseName: "Trap Bar Deadlift", recordType: .maxWeight, value: 170.0, achievedAt: calendar.date(byAdding: .day, value: -14, to: .now)!),
            PersonalRecord(exerciseName: "Split Squat", recordType: .maxVolume, value: 1680.0, achievedAt: calendar.date(byAdding: .day, value: -21, to: .now)!),
        ]
        for pr in prs {
            pr.athlete = athlete
            modelContext.insert(pr)
        }

        // Create a wellness check-in
        let wellness = WellnessCheckIn(
            date: .now,
            sleepQuality: 4,
            soreness: 3,
            energy: 4,
            stress: 2
        )
        wellness.athlete = athlete
        modelContext.insert(wellness)

        ensureScreenshotTemplates(modelContext: modelContext, athlete: athlete)
        ensureScreenshotResolvedPlan(modelContext: modelContext, athlete: athlete, calendar: calendar)

        try? modelContext.save()
    }

    private static func ensureScreenshotTemplates(modelContext: ModelContext, athlete: Athlete) {
        let existingTemplates = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        let existingNames = Set(existingTemplates
            .filter { !$0.isArchived && ($0.athleteId == athlete.id || $0.coachId == athlete.id) }
            .map(\.templateName))

        if !existingNames.contains("RIR Strength") {
            let template = WorkoutTemplate(
                coachId: athlete.id,
                templateName: "RIR Strength",
                sportType: .lifting,
                sessionType: .strength
            )
            template.isAthleteOwned = true
            template.athleteId = athlete.id

            let group = ExerciseGroup(groupName: "Main", orderIndex: 0)
            let bench = TemplateExercise(
                exerciseName: "Barbell Bench Press",
                exerciseCategory: .compound,
                muscleGroup: .chest,
                orderIndex: 0
            )
            bench.sets = [
                TemplateSet(setIndex: 0, targetReps: 5, targetWeightKg: 70, targetRIR: 2),
                TemplateSet(setIndex: 1, targetReps: 5, targetWeightKg: 72.5, targetRIR: 1),
                TemplateSet(setIndex: 2, targetReps: 5, targetWeightKg: 75, targetRIR: 1)
            ]

            let row = TemplateExercise(
                exerciseName: "Barbell Row",
                exerciseCategory: .compound,
                muscleGroup: .back,
                orderIndex: 1
            )
            row.sets = [
                TemplateSet(setIndex: 0, targetReps: 8, targetWeightKg: 65, targetRIR: 2),
                TemplateSet(setIndex: 1, targetReps: 8, targetWeightKg: 65, targetRIR: 2),
                TemplateSet(setIndex: 2, targetReps: 8, targetWeightKg: 67.5, targetRIR: 1)
            ]

            let press = TemplateExercise(
                exerciseName: "Overhead Press",
                exerciseCategory: .compound,
                muscleGroup: .shoulders,
                orderIndex: 2
            )
            press.sets = [
                TemplateSet(setIndex: 0, targetReps: 8, targetWeightKg: 45, targetRIR: 2),
                TemplateSet(setIndex: 1, targetReps: 8, targetWeightKg: 45, targetRIR: 2)
            ]

            let pullUp = TemplateExercise(
                exerciseName: "Pull Up",
                exerciseCategory: .bodyweight,
                muscleGroup: .back,
                orderIndex: 3
            )
            pullUp.sets = [
                TemplateSet(setIndex: 0, targetReps: 8, targetRIR: 2),
                TemplateSet(setIndex: 1, targetReps: 8, targetRIR: 1)
            ]

            group.exercises = [bench, row, press, pullUp]
            template.groups = [group]
            modelContext.insert(template)
        }

        if !existingNames.contains("Tempo Run") {
            let template = WorkoutTemplate(
                coachId: athlete.id,
                templateName: "Tempo Run",
                sportType: .running,
                sessionType: .cardio
            )
            template.isAthleteOwned = true
            template.athleteId = athlete.id

            let group = ExerciseGroup(groupName: "Main", orderIndex: 0)
            let warmup = TemplateExercise(
                exerciseName: "Easy Jog",
                exerciseCategory: .cardio,
                muscleGroup: .fullBody,
                orderIndex: 0
            )
            warmup.sets = [
                TemplateSet(setIndex: 0, targetDurationSeconds: 10 * 60, targetDistanceMeters: 1600, targetRPE: 3)
            ]

            let run = TemplateExercise(
                exerciseName: "Tempo Run",
                exerciseCategory: .cardio,
                muscleGroup: .fullBody,
                orderIndex: 1
            )
            run.sets = [
                TemplateSet(setIndex: 0, targetDurationSeconds: 25 * 60, targetDistanceMeters: 5000, targetRPE: 7)
            ]

            let strides = TemplateExercise(
                exerciseName: "Strides",
                exerciseCategory: .interval,
                muscleGroup: .legs,
                orderIndex: 2
            )
            strides.sets = [
                TemplateSet(setIndex: 0, targetDurationSeconds: 20, targetDistanceMeters: 120, targetRPE: 8),
                TemplateSet(setIndex: 1, targetDurationSeconds: 20, targetDistanceMeters: 120, targetRPE: 8),
                TemplateSet(setIndex: 2, targetDurationSeconds: 20, targetDistanceMeters: 120, targetRPE: 8),
                TemplateSet(setIndex: 3, targetDurationSeconds: 20, targetDistanceMeters: 120, targetRPE: 8)
            ]

            group.exercises = [warmup, run, strides]
            template.groups = [group]
            modelContext.insert(template)
        }

        if !existingNames.contains("Bodyweight Circuit") {
            let template = WorkoutTemplate(
                coachId: athlete.id,
                templateName: "Bodyweight Circuit",
                sportType: .custom,
                sessionType: .skill
            )
            template.isAthleteOwned = true
            template.athleteId = athlete.id

            let group = ExerciseGroup(groupName: "Main", orderIndex: 0)
            let pushUp = TemplateExercise(
                exerciseName: "Push Up",
                exerciseCategory: .bodyweight,
                muscleGroup: .chest,
                orderIndex: 0
            )
            pushUp.sets = [
                TemplateSet(setIndex: 0, targetReps: 20, targetRPE: 7),
                TemplateSet(setIndex: 1, targetReps: 15, targetRPE: 8)
            ]

            let splitSquat = TemplateExercise(
                exerciseName: "Split Squat",
                exerciseCategory: .compound,
                muscleGroup: .legs,
                orderIndex: 1
            )
            splitSquat.sets = [
                TemplateSet(setIndex: 0, targetReps: 12, targetRPE: 7),
                TemplateSet(setIndex: 1, targetReps: 12, targetRPE: 8)
            ]

            let plank = TemplateExercise(
                exerciseName: "Plank",
                exerciseCategory: .isolation,
                muscleGroup: .core,
                orderIndex: 2
            )
            plank.sets = [
                TemplateSet(setIndex: 0, targetDurationSeconds: 60, targetRPE: 6),
                TemplateSet(setIndex: 1, targetDurationSeconds: 60, targetRPE: 7)
            ]

            group.exercises = [pushUp, splitSquat, plank]
            template.groups = [group]
            modelContext.insert(template)
        }
    }

    private static func ensureScreenshotResolvedPlan(
        modelContext: ModelContext,
        athlete: Athlete,
        calendar: Calendar
    ) {
        let existingPlans = (try? modelContext.fetch(FetchDescriptor<PrescribedWorkout>())) ?? []
        for plan in existingPlans where plan.templateName == "Adjusted Squat" {
            modelContext.delete(plan)
        }

        let prescription = PrescribedWorkout(
            coachId: athlete.id,
            athleteId: athlete.id,
            templateId: nil,
            scheduledDate: .now,
            templateName: "Adjusted Squat",
            sportType: .lifting,
            sessionType: .strength
        )

        let group = ExerciseGroup(groupName: "Main", orderIndex: 0)
        let squat = TemplateExercise(
            exerciseName: "Barbell Back Squat",
            exerciseCategory: .compound,
            muscleGroup: .legs,
            orderIndex: 0
        )

        let warmup = TemplateSet(setIndex: 0, targetReps: 5, targetWeightKg: 60, targetRPE: 5, isWarmup: true)
        let working = TemplateSet(setIndex: 1, targetReps: 5, targetWeightKg: 140, targetRPE: 8, isWarmup: false)
        let backoff = TemplateSet(setIndex: 2, targetReps: 5, targetWeightKg: 120, targetRPE: 7, isWarmup: false)
        working.adjustedTargetWeightKg = 130
        working.adjustedTargetRPE = 7
        working.adjustedBackoffSetCut = 1
        working.verdictReason = String(
            localized: "mock.verdictReason",
            defaultValue: "Recent court work loaded your legs — microdose before the match."
        )
        VerdictDecisionApplier.applyAccept(to: working, appliedAt: .now)

        squat.sets = [warmup, working, backoff]
        group.exercises = [squat]
        prescription.groups = [group]
        modelContext.insert(prescription)

        let decidedAt = calendar.date(byAdding: .minute, value: -20, to: .now) ?? .now
        let event = VerdictEvent(
            decidedAt: decidedAt,
            planDate: .now,
            verdictKindRaw: "modify",
            plannedTopSetKg: 140,
            adjustedTopSetKg: 130,
            deltaKg: -10,
            differed: true,
            actionRaw: "accepted",
            regionRaw: MuscleRegion.legs.rawValue,
            reasonLine: working.verdictReason ?? "",
            confidenceNote: nil,
            prescriptionId: prescription.id,
            suggestedBackoffSetCut: 1,
            suggestedRPECap: 7,
            matchProximityRaw: true,
            athlete: athlete
        )
        modelContext.insert(event)
    }

    // MARK: - Session Factories

    private static func createStrengthSession(
        date: Date,
        weekNumber: Int,
        rng: inout SeededGenerator
    ) -> WorkoutSession {
        let session = WorkoutSession(
            sessionDate: date,
            sessionName: "Upper Body",
            sportType: .lifting,
            durationSeconds: 3600 + Int.random(in: -600...600, using: &rng),
            sessionRPE: Double.random(in: 6...9, using: &rng),
            sessionType: .strength
        )

        // Progressive overload across weeks: 12 weeks back is the lightest, today the heaviest.
        let baseWeight = 75.0 - Double(weekNumber) * 1.5

        let bench = ExerciseEntry(exerciseName: "Barbell Bench Press", exerciseCategory: .compound, muscleGroup: .chest, orderIndex: 0)
        for i in 0..<4 {
            bench.sets.append(SetRecord(setIndex: i, reps: 8, weightKg: baseWeight + Double(i) * 2.5, rpe: 7))
        }
        session.exerciseEntries.append(bench)

        let row = ExerciseEntry(exerciseName: "Barbell Row", exerciseCategory: .compound, muscleGroup: .back, orderIndex: 1)
        for i in 0..<4 {
            row.sets.append(SetRecord(setIndex: i, reps: 8, weightKg: baseWeight - 5 + Double(i) * 2.5, rpe: 7))
        }
        session.exerciseEntries.append(row)

        let ohp = ExerciseEntry(exerciseName: "Overhead Press", exerciseCategory: .compound, muscleGroup: .shoulders, orderIndex: 2)
        for i in 0..<3 {
            ohp.sets.append(SetRecord(setIndex: i, reps: 10, weightKg: baseWeight * 0.6, rpe: 7))
        }
        session.exerciseEntries.append(ohp)

        return session
    }

    private static func createCardioSession(date: Date, rng: inout SeededGenerator) -> WorkoutSession {
        let session = WorkoutSession(
            sessionDate: date,
            sessionName: "Tempo Conditioning",
            sportType: .teamSport,
            durationSeconds: Int.random(in: 1800...3600, using: &rng),
            sessionRPE: Double.random(in: 4...6, using: &rng),
            sessionType: .cardio
        )

        let run = ExerciseEntry(exerciseName: "Court Intervals", exerciseCategory: .interval, muscleGroup: .legs, orderIndex: 0)
        let dist = Double.random(in: 4000...8000, using: &rng)
        run.sets.append(SetRecord(setIndex: 0, durationSeconds: session.durationSeconds, distanceMeters: dist, rpe: session.sessionRPE))
        session.exerciseEntries.append(run)

        return session
    }

    private static func createSkillSession(date: Date, rng: inout SeededGenerator) -> WorkoutSession {
        let session = WorkoutSession(
            sessionDate: date,
            sessionName: "Shooting + Handles",
            sportType: .teamSport,
            durationSeconds: Int.random(in: 2700...5400, using: &rng),
            sessionRPE: Double.random(in: 5...8, using: &rng),
            sessionType: .skill
        )

        let drills = ExerciseEntry(exerciseName: "Shooting Drills", exerciseCategory: .drill, muscleGroup: .fullBody, orderIndex: 0)
        drills.sets.append(SetRecord(setIndex: 0, durationSeconds: 1200, rpe: 5))
        session.exerciseEntries.append(drills)

        let scrimmage = ExerciseEntry(exerciseName: "Scrimmage", exerciseCategory: .drill, muscleGroup: .fullBody, orderIndex: 1)
        scrimmage.sets.append(SetRecord(setIndex: 0, durationSeconds: 1800, rpe: 8))
        session.exerciseEntries.append(scrimmage)

        return session
    }

    private static func createBasketballMatchSession(date: Date, tier: MatchTier) -> WorkoutSession {
        let session = WorkoutSession(
            sessionDate: date,
            sessionName: "League Match",
            sportType: .teamSport,
            durationSeconds: 48 * 60,
            sessionRPE: 9,
            sessionType: .match
        )
        session.matchTier = tier

        let game = ExerciseEntry(
            exerciseName: "Competitive Minutes",
            exerciseCategory: .drill,
            muscleGroup: .legs,
            orderIndex: 0
        )
        game.sets.append(SetRecord(setIndex: 0, durationSeconds: 48 * 60, rpe: 9))
        session.exerciseEntries.append(game)

        return session
    }

    private static func createLongSession(
        date: Date,
        weekNumber: Int,
        rng: inout SeededGenerator
    ) -> WorkoutSession {
        let session = WorkoutSession(
            sessionDate: date,
            sessionName: "Lower Body Strength",
            sportType: .lifting,
            durationSeconds: 4200 + Int.random(in: -600...600, using: &rng),
            sessionRPE: Double.random(in: 7...9, using: &rng),
            sessionType: .strength
        )

        // The squat top set is `baseWeight + 20`, so this week lands on 140 kg — the same number
        // `ensureScreenshotResolvedPlan` prescribes as today's planned top set and the same ladder
        // the 142.5 kg PR sits on. Before this the history topped out around 115 kg while the
        // store plate advertised a 140 kg plan, which does not survive being read twice.
        let baseWeight = 120.0 - Double(weekNumber) * 2.5

        let squat = ExerciseEntry(exerciseName: "Barbell Back Squat", exerciseCategory: .compound, muscleGroup: .legs, orderIndex: 0)
        for i in 0..<5 {
            squat.sets.append(SetRecord(setIndex: i, reps: 5, weightKg: baseWeight + Double(i) * 5, rpe: 8))
        }
        session.exerciseEntries.append(squat)

        let rdl = ExerciseEntry(exerciseName: "Romanian Deadlift", exerciseCategory: .compound, muscleGroup: .legs, orderIndex: 1)
        for i in 0..<3 {
            rdl.sets.append(SetRecord(setIndex: i, reps: 10, weightKg: baseWeight * 0.7, rpe: 7))
        }
        session.exerciseEntries.append(rdl)

        return session
    }

    // MARK: - Workload Snapshots

    private static func seedWorkloadSnapshots(modelContext: ModelContext, athlete: Athlete) {
        let calendar = Calendar.current

        // Simulate progressive EWMA build-up
        var atl = 20.0
        var ctl = 25.0
        var rng = SeededGenerator(seed: 0x4C4F_4144_5F53_4545)

        for dayOffset in stride(from: -(historyDays - 1), through: 0, by: 1) {
            // Floored — see the recovery seed above (audit M5).
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: .now)
                .map({ calendar.startOfDay(for: $0) }) else { continue }

            // Simulate daily load
            let isRestDay = (-dayOffset) % 4 == 3
            let dailyTSS = isRestDay ? 0.0 : Double.random(in: 30...80, using: &rng)

            atl = atl * 0.86 + dailyTSS * 0.14  // ~7-day half-life
            ctl = ctl * 0.96 + dailyTSS * 0.04  // ~28-day half-life
            let acwr = ctl > 0 ? atl / ctl : 0

            let snapshot = WorkloadSnapshot(
                snapshotDate: date,
                acuteLoad: atl,
                chronicLoad: ctl,
                acwr: acwr,
                tsb: ctl - atl,
                weeklyVolume: dailyTSS * 5,
                loadSource: .srpe
            )
            snapshot.athlete = athlete
            modelContext.insert(snapshot)
        }
    }
}
#endif
