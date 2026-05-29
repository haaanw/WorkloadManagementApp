import Foundation
import SwiftData
import UserNotifications

/// ViewModel for the Dashboard tab.
/// Runs recovery pipeline and autoregulation engine on appear/foreground.
@MainActor
@Observable
final class DashboardViewModel {
    // Recovery
    var recoveryScore: Double = 50
    var recoveryZone: RecoveryZone = .yellow

    // Latest raw biometric values (for MetricsStrip display)
    var latestHRV: Double?
    var latestRHR: Double?
    var latestSleepMinutes: Double?

    // Workload
    var acwr: Double = 0
    var acwrZone: ACWRZone = .noData
    var tsb: Double = 0
    var atl: Double = 0
    var ctl: Double = 0

    /// True when displaying seeded ATL/CTL from TrainingProfile (cold-start window active)
    var isColdStartActive: Bool = false

    // Recommendation
    var recommendation: AutoregulationEngine.TrainingRecommendation?

    // Fatigue Accumulation Index
    var fatigueIndex: Double?
    var fatigueZone: FatigueIndexEngine.FatigueZone?

    // Periodization
    var trainingPhaseLabel: String?
    var periodizationSufficiency: PeriodizationEngine.SufficiencyResult?

    // Algorithm transparency — why the score is what it is
    var reasoningFactors: [ReasoningEngine.Factor] = []
    var hasRealData: Bool = false

    /// HealthKit connection state, used to route the empty-state UI between the connect CTA,
    /// a benign "connected — no recent data" message, and the normal data view.
    var healthKitState: HealthKitConnectionState = .notRequested

    // Staleness tracking
    var staleness: HealthKitStaleness = HealthKitStaleness(lastHRVDate: nil, lastSleepDate: nil, lastRHRDate: nil)

    // Trend data for progressive disclosure detail views
    var hrv28Days: [(date: Date, value: Double)] = []
    var recentSnapshots: [RecoverySnapshot] = []

    // Weekly summary (ANLYT-02, ANLYT-03)
    var weeklySummary: AnalyticsEngine.WeeklySummary?

    // Streak (STRK-01, STRK-02)
    var currentStreak: Int = 0

    var isLoading = true

    func load(
        athlete: Athlete,
        healthKitService: HealthKitService,
        modelContext: ModelContext,
        syncService: SyncService? = nil,
        cycleTrackingService: CycleTrackingService? = nil
    ) async {
        isLoading = true

        // Capture HealthKit connection state for empty-state routing.
        healthKitState = healthKitService.connectionState

        // Run recovery pipeline
        var fullRecoveryResult: RecoveryScoreEngine.RecoveryResult?
        // Phase 20: cycle context surfaced from the pipeline, passed into the Plan 02 engine
        // overloads below. With CycleModifierActivation.isEnabled == false the engines return
        // their base values, so the dashboard is visually identical (wiring only).
        var cycleContext: CycleContext = .none
        var cyclesObserved = 0
        #if DEBUG
        let isScreenshotMode = ProcessInfo.processInfo.arguments.contains("SCREENSHOT_MODE")
        #else
        let isScreenshotMode = false
        #endif

        if !isScreenshotMode {
            do {
                let recoveryResult = try await RecoveryPipeline.run(
                    athlete: athlete,
                    healthKitService: healthKitService,
                    modelContext: modelContext,
                    syncService: syncService,
                    cycleTrackingService: cycleTrackingService
                )
                recoveryScore = recoveryResult.score
                recoveryZone = recoveryResult.zone
                fullRecoveryResult = recoveryResult.snapshot
                staleness = recoveryResult.staleness
                cycleContext = recoveryResult.cycleContext
                cyclesObserved = recoveryResult.cyclesObserved
            } catch {
                print("Recovery pipeline error: \(error)")
            }
        }

        // Fetch today's recovery snapshot for raw values and baselines
        let recoveryRepo = RecoveryRepository(modelContext: modelContext)
        let todaySnapshot: RecoverySnapshot? = {
            if let today = try? recoveryRepo.fetchTodaySnapshot(athlete: athlete) { return today }
            // Fallback: latest snapshot (for mock data or missed days)
            return try? recoveryRepo.fetchLatestSnapshot(athlete: athlete)
        }()

        // Fetch trend history for detail views
        recentSnapshots = (try? recoveryRepo.fetchRecoveryHistory(days: 28, athlete: athlete)) ?? []
        if isScreenshotMode {
            // SCREENSHOT_MODE: HealthKit unauthorized — derive HRV trend from seeded snapshots
            hrv28Days = recentSnapshots.compactMap { snap in
                snap.hrvSDNN.map { (date: snap.date, value: $0) }
            }
        } else {
            hrv28Days = (try? await healthKitService.fetchHRVHistory(days: 28)) ?? []
        }
        latestHRV = todaySnapshot?.hrvSDNN
        latestRHR = todaySnapshot?.restingHR
        latestSleepMinutes = todaySnapshot?.sleepDurationMinutes

        // hasRealData: true if we have HRV/sleep from pipeline OR existing snapshots with data
        if let result = fullRecoveryResult {
            hasRealData = result.hrvContribution != nil || result.sleepContribution != nil
        }
        // Fallback: check if we have seeded/historical recovery data
        if !hasRealData, let snap = todaySnapshot, snap.recoveryScore != 50 {
            hasRealData = true
            recoveryScore = snap.recoveryScore
            recoveryZone = snap.zone
        }

        // Re-read state after the pipeline — a successful read upgrades it to `.connected`.
        healthKitState = healthKitService.connectionState

        // SCREENSHOT_MODE: synthesize a RecoveryResult from the seeded snapshot so
        // reasoning factors populate the hero card.
        if isScreenshotMode, fullRecoveryResult == nil, let snap = todaySnapshot {
            let input = RecoveryScoreEngine.RecoveryInput(
                hrvSDNN: snap.hrvSDNN,
                restingHR: snap.restingHR,
                sleepDurationMinutes: snap.sleepDurationMinutes,
                wellnessScore: nil,
                hrvBaseline: snap.hrvBaseline,
                restingHRBaseline: snap.restingHRBaseline
            )
            fullRecoveryResult = RecoveryScoreEngine.compute(input: input)
        }

        // Fetch latest workload snapshot
        let workloadRepo = WorkloadRepository(modelContext: modelContext)
        var latestWorkloadSnapshot: WorkloadSnapshot?
        if let snapshot = try? workloadRepo.fetchLatestSnapshot(athlete: athlete) {
            acwr = snapshot.acwr
            acwrZone = snapshot.zone
            tsb = snapshot.tsb
            atl = snapshot.acuteLoad
            ctl = snapshot.chronicLoad
            latestWorkloadSnapshot = snapshot
            isColdStartActive = false
        } else {
            // Cold-start fallback: use seeded values from TrainingProfile (per D-08, COLD-04)
            let profileRepo = TrainingProfileRepository(modelContext: modelContext)
            if let profile = try? profileRepo.fetchProfile(athleteId: athlete.id),
               profile.coldStartCompletedAt == nil {
                atl = profile.seededATL
                ctl = profile.seededCTL
                acwr = profile.seededCTL > 0 ? profile.seededATL / profile.seededCTL : 0
                tsb = profile.seededCTL - profile.seededATL
                acwrZone = ACWRZone.classify(acwr: acwr, ctl: ctl)
                isColdStartActive = true
            } else {
                isColdStartActive = false
            }
        }

        // Periodization detection (INTEL-01, INTEL-02, INTEL-03)
        let workoutRepo = WorkoutRepository(modelContext: modelContext)
        let allSessions = (try? workoutRepo.fetchSessions(last: 90, athlete: athlete)) ?? []
        let allWorkloadSnapshots = (try? workloadRepo.fetchSnapshots(last: 90, athlete: athlete)) ?? []
        let sufficiency = PeriodizationEngine.checkSufficiency(sessions: allSessions)
        periodizationSufficiency = sufficiency
        if sufficiency.isSufficient {
            trainingPhaseLabel = PeriodizationEngine.detectPhase(
                workloadSnapshots: allWorkloadSnapshots,
                sessions: allSessions
            )?.displayLabel
        } else {
            trainingPhaseLabel = nil
        }

        // Weekly summary (ANLYT-02, ANLYT-03)
        let now = Date.now
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let prevWeekStart = Calendar.current.date(byAdding: .day, value: -14, to: now)!

        let currentWeekSessions = (try? workoutRepo.fetchSessions(from: weekStart, to: now, athlete: athlete)) ?? []
        let previousWeekSessions = (try? workoutRepo.fetchSessions(from: prevWeekStart, to: weekStart, athlete: athlete)) ?? []
        let currentRecovery = (try? recoveryRepo.fetchSnapshots(from: weekStart, to: now, athlete: athlete)) ?? []
        let previousRecovery = (try? recoveryRepo.fetchSnapshots(from: prevWeekStart, to: weekStart, athlete: athlete)) ?? []
        let currentWorkload = (try? workloadRepo.fetchSnapshots(from: weekStart, to: now, athlete: athlete)) ?? []

        weeklySummary = AnalyticsEngine.computeWeeklySummary(
            currentWeekSessions: currentWeekSessions,
            previousWeekSessions: previousWeekSessions,
            currentWeekRecoverySnapshots: currentRecovery,
            previousWeekRecoverySnapshots: previousRecovery,
            currentWeekWorkloadSnapshots: currentWorkload
        )

        // Streak computation (STRK-01) — uses all sessions up to 1 year for streak history
        let streakSessions = (try? workoutRepo.fetchSessions(last: 365, athlete: athlete)) ?? []
        currentStreak = StreakEngine.computeStreak(sessions: streakSessions)

        // Compute consecutive training days
        let daysSinceRest = computeDaysSinceRest(workoutRepo: workoutRepo, athlete: athlete)

        // Compute Fatigue Accumulation Index
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        let recentSessions14d = allSessions.filter { $0.sessionDate >= fourteenDaysAgo }
        let recentSessionTSS = recentSessions14d.map(\.trainingStress)
        let baselineTSS: Double? = {
            let allTSS = allSessions.map(\.trainingStress).filter { $0 > 0 }
            guard !allTSS.isEmpty else { return nil }
            return allTSS.reduce(0, +) / Double(allTSS.count)
        }()
        let sessionsIn14Days = recentSessions14d.count
        let baselineSessions14d = FatigueIndexEngine.baselineSessionsPer14Days(sessions: allSessions)
        let recentRecoveryScores = recentSnapshots
            .sorted { $0.date < $1.date }
            .suffix(7)
            .map(\.recoveryScore)
        let recentWellnessScores: [Double] = []  // TODO: fetch from WellnessCheckIn history

        if isColdStartActive {
            // COLD-07: suppress FatigueIndex during cold-start window (D-16, D-17)
            fatigueIndex = nil
            fatigueZone = nil
        } else {
            let fatigueInput = FatigueIndexEngine.FatigueInput(
                recentSessionTSS: recentSessionTSS,
                baselineSessionTSS: baselineTSS,
                sessionsIn14Days: sessionsIn14Days,
                baselineSessionsIn14Days: baselineSessions14d,
                trainingStreakDays: daysSinceRest,
                daysSinceRestPeriod: nil,
                recentRecoveryScores: recentRecoveryScores,
                recentWellnessScores: recentWellnessScores,
                softTissueInjuryCount: 0,
                daysSinceLastInjury: nil
            )
            // Phase 20: pass cycle context (activation off → identical to base, D-06/D-12).
            let fatigueResult = FatigueIndexEngine.compute(
                input: fatigueInput,
                cycleContext: cycleContext.phase == .unknown ? nil : cycleContext,
                cyclesObserved: cyclesObserved
            )
            fatigueIndex = fatigueResult.index
            fatigueZone = fatigueResult.zone
        }

        // Generate recommendation (with fatigue index)
        let autoInput = AutoregulationEngine.DailyInput(
            recoveryZone: recoveryZone,
            recoveryScore: recoveryScore,
            acwrZone: acwrZone,
            acwr: acwr,
            wellnessScore: nil,
            daysSinceLastRest: daysSinceRest,
            fatigueIndex: fatigueIndex
        )
        // Phase 20: pass cycle context (activation off → identical to base, D-06/D-12).
        recommendation = AutoregulationEngine.recommend(
            input: autoInput,
            cycleContext: cycleContext.phase == .unknown ? nil : cycleContext,
            cyclesObserved: cyclesObserved
        )

        // Build reasoning factors (requires real data)
        if hasRealData, let result = fullRecoveryResult {
            let reasoningInput = ReasoningEngine.Input(
                recoveryResult: result,
                workloadSnapshot: latestWorkloadSnapshot,
                rawHRV: latestHRV,
                rawRHR: latestRHR,
                hrvBaseline: todaySnapshot?.hrvBaseline,
                rhrBaseline: todaySnapshot?.restingHRBaseline,
                sleepMinutes: latestSleepMinutes,
                daysSinceRest: daysSinceRest
            )
            reasoningFactors = ReasoningEngine.summarize(input: reasoningInput)
        } else {
            reasoningFactors = []
        }

        isLoading = false
    }

    /// Refresh the pending weekly notification with current summary data (NOTF-01 staleness prevention).
    func refreshNotificationContent(notificationService: NotificationService, modelContext: ModelContext) {
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        guard notificationsEnabled else { return }

        let prCount: Int = {
            let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date.now)!
            let desc = FetchDescriptor<PersonalRecord>(
                predicate: #Predicate<PersonalRecord> { $0.achievedAt >= weekStart }
            )
            return (try? modelContext.fetch(desc).count) ?? 0
        }()

        let day = UserDefaults.standard.integer(forKey: "notificationDay")
        let timeString = UserDefaults.standard.string(forKey: "notificationTime") ?? "19:00"
        let timeParts = timeString.split(separator: ":").compactMap { Int($0) }
        let hour = timeParts.first ?? 19
        let minute = timeParts.count > 1 ? timeParts[1] : 0
        let weekday = day > 0 ? day : 1

        notificationService.scheduleWeeklySummary(
            weekday: weekday,
            hour: hour,
            minute: minute,
            sessionCount: weeklySummary?.sessionCount ?? 0,
            streak: currentStreak,
            prCount: prCount,
            volumeDelta: weeklySummary?.volumeDelta ?? 0
        )
    }

    private func computeDaysSinceRest(workoutRepo: WorkoutRepository, athlete: Athlete) -> Int {
        guard let sessions = try? workoutRepo.fetchSessions(last: 14, athlete: athlete) else { return 0 }
        let calendar = Calendar.current
        var days = 0
        var checkDate = calendar.startOfDay(for: .now)

        while days < 14 {
            let dayStart = checkDate
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let hasSession = sessions.contains { s in
                s.sessionDate >= dayStart && s.sessionDate < dayEnd
            }
            if !hasSession { break }
            days += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }
        return days
    }
}
