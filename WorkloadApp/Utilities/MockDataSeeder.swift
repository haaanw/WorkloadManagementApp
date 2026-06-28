#if DEBUG
import Foundation
import SwiftData

/// Seeds realistic mock data for screenshots and testing.
/// Only available in DEBUG builds.
enum MockDataSeeder {

    @MainActor
    static func seed(modelContext: ModelContext, athlete: Athlete) {
        let calendar = Calendar.current

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
        try? modelContext.save()

        // Create 28 days of workout sessions (4 weeks)
        for dayOffset in stride(from: -27, through: 0, by: 1) {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: .now) else { continue }

            // Rest days: every 4th day
            if (-dayOffset) % 4 == 3 { continue }

            let weekday = calendar.component(.weekday, from: date)
            let session: WorkoutSession

            switch weekday {
            case 2, 5: // Mon, Thu — strength
                session = createStrengthSession(date: date, weekNumber: (-dayOffset) / 7)
            case 3, 6: // Tue, Fri — cardio
                session = createCardioSession(date: date)
            case 4: // Wed — skills
                session = createSkillSession(date: date)
            case 7: // Sat — long session
                session = createLongSession(date: date, weekNumber: (-dayOffset) / 7)
            default:
                continue
            }

            session.athlete = athlete
            session.recalculateDerivedFields()
            modelContext.insert(session)
        }

        // Create recovery snapshots (daily)
        for dayOffset in stride(from: -27, through: 0, by: 1) {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: .now) else { continue }

            let baseHRV = 45.0 + Double.random(in: -10...15)
            let baseRHR = 58.0 + Double.random(in: -5...8)
            let baseSleep = 400.0 + Double.random(in: -60...60)

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
            PersonalRecord(exerciseName: "Barbell Bench Press", recordType: .maxWeight, value: 92.5, achievedAt: calendar.date(byAdding: .day, value: -3, to: .now)!),
            PersonalRecord(exerciseName: "Barbell Back Squat", recordType: .maxWeight, value: 130.0, achievedAt: calendar.date(byAdding: .day, value: -7, to: .now)!),
            PersonalRecord(exerciseName: "Deadlift", recordType: .maxWeight, value: 155.0, achievedAt: calendar.date(byAdding: .day, value: -14, to: .now)!),
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
        ensureScreenshotResolvedPlan(modelContext: modelContext, athlete: athlete)

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
                TemplateSet(setIndex: 1, targetReps: 5, targetWeightKg: 72.5, targetRIR: 1)
            ]
            group.exercises = [bench]
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
            let run = TemplateExercise(
                exerciseName: "Tempo Run",
                exerciseCategory: .cardio,
                muscleGroup: .fullBody,
                orderIndex: 0
            )
            run.sets = [
                TemplateSet(setIndex: 0, targetDurationSeconds: 25 * 60, targetDistanceMeters: 5000, targetRPE: 7)
            ]
            group.exercises = [run]
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
            group.exercises = [pushUp]
            template.groups = [group]
            modelContext.insert(template)
        }
    }

    private static func ensureScreenshotResolvedPlan(modelContext: ModelContext, athlete: Athlete) {
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
        working.adjustedTargetWeightKg = 130
        working.adjustedTargetRPE = 7
        working.verdictReason = "Readiness is lower than baseline, so intensity was trimmed."
        VerdictDecisionApplier.applyAccept(to: working, appliedAt: .now)

        squat.sets = [warmup, working]
        group.exercises = [squat]
        prescription.groups = [group]
        modelContext.insert(prescription)
    }

    // MARK: - Session Factories

    private static func createStrengthSession(date: Date, weekNumber: Int) -> WorkoutSession {
        let session = WorkoutSession(
            sessionDate: date,
            sessionName: "Upper Body",
            sportType: .lifting,
            durationSeconds: 3600 + Int.random(in: -600...600),
            sessionRPE: Double.random(in: 6...9),
            sessionType: .strength
        )

        // Progressive overload across weeks
        let baseWeight = 60.0 + Double(3 - weekNumber) * 2.5

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

    private static func createCardioSession(date: Date) -> WorkoutSession {
        let session = WorkoutSession(
            sessionDate: date,
            sessionName: "Easy Run",
            sportType: .running,
            durationSeconds: Int.random(in: 1800...3600),
            sessionRPE: Double.random(in: 4...6),
            sessionType: .cardio
        )

        let run = ExerciseEntry(exerciseName: "Easy Run", exerciseCategory: .cardio, muscleGroup: .fullBody, orderIndex: 0)
        let dist = Double.random(in: 4000...8000)
        run.sets.append(SetRecord(setIndex: 0, durationSeconds: session.durationSeconds, distanceMeters: dist, rpe: session.sessionRPE))
        session.exerciseEntries.append(run)

        return session
    }

    private static func createSkillSession(date: Date) -> WorkoutSession {
        let session = WorkoutSession(
            sessionDate: date,
            sessionName: "Basketball Skills",
            sportType: .teamSport,
            durationSeconds: Int.random(in: 2700...5400),
            sessionRPE: Double.random(in: 5...8),
            sessionType: .skill
        )

        let drills = ExerciseEntry(exerciseName: "Shooting Drills", exerciseCategory: .drill, muscleGroup: nil, orderIndex: 0)
        drills.sets.append(SetRecord(setIndex: 0, durationSeconds: 1200, rpe: 5))
        session.exerciseEntries.append(drills)

        let scrimmage = ExerciseEntry(exerciseName: "Scrimmage", exerciseCategory: .drill, muscleGroup: .fullBody, orderIndex: 1)
        scrimmage.sets.append(SetRecord(setIndex: 0, durationSeconds: 1800, rpe: 8))
        session.exerciseEntries.append(scrimmage)

        return session
    }

    private static func createLongSession(date: Date, weekNumber: Int) -> WorkoutSession {
        let session = WorkoutSession(
            sessionDate: date,
            sessionName: "Lower Body",
            sportType: .lifting,
            durationSeconds: 4200 + Int.random(in: -600...600),
            sessionRPE: Double.random(in: 7...9),
            sessionType: .strength
        )

        let baseWeight = 80.0 + Double(3 - weekNumber) * 5.0

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

        for dayOffset in stride(from: -27, through: 0, by: 1) {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: .now) else { continue }

            // Simulate daily load
            let isRestDay = (-dayOffset) % 4 == 3
            let dailyTSS = isRestDay ? 0.0 : Double.random(in: 30...80)

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
