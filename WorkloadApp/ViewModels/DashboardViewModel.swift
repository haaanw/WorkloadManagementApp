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

    // Phase 28 Wave 4 — FLAGGED dual-run "method updated" surface. Default nil; only ever assigned
    // non-nil inside the `if PRSActivation.isEnabled` guard at the end of load(). With the flag OFF
    // (default, production) this stays nil → PRSDualRunCard renders EmptyView → Dashboard
    // byte-unchanged.
    var dualRunMessage: PRSDualRunSurface.DualRunMessage?

    // ACT-01 — stored inputs for the verdict-surface dual-run build. `load()` snapshots the three
    // locals the build needs (it no longer builds the message itself); the View's explicit
    // production opt-in `activateVerdictSurface()` then re-supplies them to `buildDualRunMessage`
    // inside `VerdictSurfaceActivation.withEnabled(true)`. Default-empty/nil so a never-loaded VM
    // (or a cold-start opt-in) honestly defers.
    private var lastDualRunSessions: [WorkoutSession] = []
    private var lastDualRunFatigue: FatigueIndexEngine.FatigueResult? = nil
    private var lastDualRunDaysSinceRest: Int = 0

    // Fatigue Accumulation Index
    var fatigueIndex: Double?
    var fatigueZone: FatigueIndexEngine.FatigueZone?

    // Periodization
    var trainingPhaseLabel: String?
    var periodizationSufficiency: PeriodizationEngine.SufficiencyResult?

    // Algorithm transparency — why the score is what it is
    var reasoningFactors: [ReasoningEngine.Factor] = []
    /// "Based on 3 of 4 signals" when a signal is missing from today's score, else nil.
    /// Since v1.7.1 HRV counts only on days with a morning reading, so coverage genuinely
    /// varies — and a coverage change must not be mistaken for a physiological one.
    var recoveryCoverageNote: String?
    var hasRealData: Bool = false

    // NOTE: HealthKit connection state is intentionally NOT cached on the ViewModel.
    // The Dashboard reads `container.healthKitService.connectionState` LIVE in its view body
    // so SwiftUI's Observation tracking re-renders when the async migration probe or a Connect
    // tap updates the service. A cached copy here would go stale (the original bug).

    // Staleness tracking
    var staleness: HealthKitStaleness = HealthKitStaleness(lastHRVDate: nil, lastSleepDate: nil, lastRHRDate: nil)

    // Trend data for progressive disclosure detail views. The 28-day arrays feed the
    // glance charts (frozen paths); the 90-day arrays feed the pinch-zoomable detail
    // screens (v1.7.1) and are the single fetch the 28-day arrays derive from.
    var hrv28Days: [(date: Date, value: Double)] = []
    var recentSnapshots: [RecoverySnapshot] = []
    var hrv90Days: [(date: Date, value: Double)] = []
    var recentSnapshots90: [RecoverySnapshot] = []
    /// Raw sample count behind `hrv90Days`, so the HRV surfaces can tell "no HRV at all"
    /// apart from "HRV exists, but none in the morning window" (`HRVDailyStats`).
    var hrvRawSampleCount: Int = 0

    // Weekly summary (ANLYT-02, ANLYT-03)
    var weeklySummary: AnalyticsEngine.WeeklySummary?

    // Streak (STRK-01, STRK-02)
    var currentStreak: Int = 0

    var isLoading = true
    /// True once the first `load()` has completed. The Dashboard shows its calm skeleton
    /// placeholders only BEFORE the first load resolves — foreground reloads never flash
    /// skeletons over already-rendered content.
    var hasLoadedOnce = false

    func load(
        athlete: Athlete,
        healthKitService: any HealthDataProviding,
        modelContext: ModelContext,
        syncService: SyncService? = nil
    ) async {
        isLoading = true

        // Run recovery pipeline
        var fullRecoveryResult: RecoveryScoreEngine.RecoveryResult?
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
                    syncService: syncService
                )
                recoveryScore = recoveryResult.score
                recoveryZone = recoveryResult.zone
                fullRecoveryResult = recoveryResult.snapshot
                staleness = recoveryResult.staleness
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

        // Fetch trend history for detail views: one 90-day fetch, 28-day glance windows
        // derived from it.
        let cutoff28 = Calendar.current.date(
            byAdding: .day, value: -28,
            to: Calendar.current.startOfDay(for: .now)
        )!
        recentSnapshots90 = (try? recoveryRepo.fetchRecoveryHistory(days: 90, athlete: athlete)) ?? []
        recentSnapshots = recentSnapshots90.filter { $0.date >= cutoff28 }
        if isScreenshotMode {
            // SCREENSHOT_MODE: HealthKit unauthorized — derive HRV trend from seeded
            // snapshots, which are already one value per day (no bucketing needed).
            hrv90Days = recentSnapshots90.compactMap { snap in
                snap.hrvSDNN.map { (date: snap.date, value: $0) }
            }
            hrvRawSampleCount = hrv90Days.count
        } else {
            // Day-bucket to the morning window BEFORE anything reads it: a Watch writes
            // several SDNN samples a day, so raw-sample statistics called ~1–2 days of
            // data "7-day" (v1.7.1). See `HRVDailyStats` for the reduction and its limits.
            let rawSamples = (try? await healthKitService.fetchHRVHistory(days: 90)) ?? []
            hrvRawSampleCount = rawSamples.count
            hrv90Days = HRVDailyStats
                .dailyValues(samples: rawSamples, days: 90)
                .map { (date: $0.date, value: $0.value) }
        }
        hrv28Days = hrv90Days.filter { $0.date >= cutoff28 }
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

        // Phase 28 Wave 4: hoist the REAL FatigueResult so the flag-gated dual-run build below can
        // reuse it (cold-start leaves it nil → builder returns nil → dualRunMessage stays nil). This
        // does NOT change any existing published property or the fatigueIndex/fatigueZone assignments.
        var fatigueResultForReadiness: FatigueIndexEngine.FatigueResult? = nil

        if isColdStartActive {
            // COLD-07: suppress FatigueIndex during cold-start window (D-16, D-17).
            // Cold-start does NO extra work: the 14d wellness fetch, the 28d niggle fetch,
            // and both NiggleInjuryDeriver derivations are gated inside the else branch below.
            fatigueIndex = nil
            fatigueZone = nil
        } else {
            // P25 D-12: last 14 days of WellnessCheckIn.wellnessScore (oldest-first), passed in
            // full — the FatigueIndexEngine wellness-trend slope is gated on count>=3, so 14
            // points are valid (RESEARCH §4 A2). Fetched ONLY here (non-cold-start) so cold-start
            // does no extra work; athlete filtered in Swift to avoid the optional-relationship
            // #Predicate trap (mirrors SorenessLogRepository / PersonalRecord precedent).
            let wellnessWindowStart = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
            let wellnessDescriptor = FetchDescriptor<WellnessCheckIn>(
                predicate: #Predicate<WellnessCheckIn> { $0.date >= wellnessWindowStart },
                sortBy: [SortDescriptor(\.date, order: .forward)]
            )
            let athleteId = athlete.id
            let recentWellnessScores: [Double] = ((try? modelContext.fetch(wellnessDescriptor)) ?? [])
                .filter { $0.athlete?.id == athleteId }
                .map(\.wellnessScore)

            // P25 D-10/D-11: derive soft-tissue injury inputs from logged niggles over a 28d window.
            // Fetched ONLY here (non-cold-start). The deriver excludes routine soreness (DOMS) so
            // it never inflates fatigue — honest load-tolerance context, NOT injury prediction.
            let niggleLogs = SorenessLogRepository(modelContext: modelContext)
                .fetchRecent(days: NiggleInjuryDeriver.injuryWindowDays, athlete: athlete)

            let fatigueInput = FatigueIndexEngine.FatigueInput(
                recentSessionTSS: recentSessionTSS,
                baselineSessionTSS: baselineTSS,
                sessionsIn14Days: sessionsIn14Days,
                baselineSessionsIn14Days: baselineSessions14d,
                trainingStreakDays: daysSinceRest,
                daysSinceRestPeriod: nil,
                recentRecoveryScores: recentRecoveryScores,
                recentWellnessScores: recentWellnessScores,
                softTissueInjuryCount: NiggleInjuryDeriver.softTissueInjuryCount(logs: niggleLogs),
                daysSinceLastInjury: NiggleInjuryDeriver.daysSinceLastInjury(logs: niggleLogs)
            )
            let fatigueResult = FatigueIndexEngine.compute(
                input: fatigueInput,
                cycleContext: nil,
                cyclesObserved: 0
            )
            fatigueIndex = fatigueResult.index
            fatigueZone = fatigueResult.zone
            fatigueResultForReadiness = fatigueResult
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
        recommendation = AutoregulationEngine.recommend(
            input: autoInput,
            cycleContext: nil,
            cyclesObserved: 0
        )

        // ACT-01 — DO NOT build the dual-run message here. `load()` only SNAPSHOTS the three inputs
        // the build needs; a BARE `load()` therefore leaves `dualRunMessage` nil (keeping the
        // `DashboardViewModelDualRunTests.test_flagOff_dualRunMessage_nilAfterLoad` fence green
        // unchanged). The PRODUCTION dashboard path activates the verdict surface explicitly via
        // `DashboardView.loadData()` → `activateVerdictSurface()` AFTER this `await load()` returns.
        lastDualRunSessions = allSessions
        lastDualRunFatigue = fatigueResultForReadiness
        lastDualRunDaysSinceRest = daysSinceRest

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
            recoveryCoverageNote = ReasoningEngine.coverageNote(for: result)
        } else {
            reasoningFactors = []
            recoveryCoverageNote = nil
        }

        isLoading = false
        hasLoadedOnce = true
    }

    /// ACT-01 — build the dual-run "method updated" message, gated by the OR of the surface flag and
    /// the app-wide swap flag (`VerdictSurfaceActivation.isEnabled || PRSActivation.isEnabled`). With
    /// BOTH flags OFF (a bare call) the guard body is skipped in full: NO `PRSReadinessInputBuilder` /
    /// `ReadinessFusionEngine` / `StrainRiskEngine` / `recommendReadiness` call occurs,
    /// `dualRunMessage` stays nil, and no other published property changes — the byte-identical
    /// guarantee. When EITHER flag is on it recomputes a REAL `ReadinessInput` (no live source exists
    /// to reuse — see `PRSReadinessInputBuilder`) and emits the legacy + updated headlines via
    /// `PRSDualRunSurface`. In production this runs via `activateVerdictSurface()` (surface flag on);
    /// the existing flag-on unit tests still satisfy the OR via `PRSActivation.withEnabled(true)`.
    ///
    /// Synchronous on purpose: `withEnabled(_:)` restores the override via `defer` the instant its
    /// closure returns, so the flag-gated build must run inside a SYNC scope to be exercisable under
    /// the override (it cannot straddle an `await`).
    func buildDualRunMessage(
        allSessions: [WorkoutSession],
        fatigueResult: FatigueIndexEngine.FatigueResult?,
        daysSinceRest: Int
    ) {
        if VerdictSurfaceActivation.isEnabled || PRSActivation.isEnabled {
            // FLAG ON ONLY — recompute readiness/strain with the real engines over real history.
            if let legacy = recommendation,
               let readinessInput = PRSReadinessInputBuilder.build(
                   recentSnapshots: recentSnapshots,
                   latestHRV: latestHRV,
                   latestRHR: latestRHR,
                   latestSleepMinutes: latestSleepMinutes,
                   allSessions: allSessions,
                   fatigueResult: fatigueResult,
                   daysSinceRest: daysSinceRest,
                   wellnessScore: nil,           // matches the legacy autoInput.wellnessScore source today
                   acwr: acwr,
                   acwrZone: acwrZone,
                   asOf: .now,
                   calendar: .current
               ) {
                let updated = AutoregulationEngine.recommendReadiness(input: readinessInput)
                dualRunMessage = PRSDualRunSurface.dualRunMessage(legacy: legacy, updated: updated)
            }
        }
    }

    /// ACT-01 — the PRODUCTION opt-in that activates the verdict-feeding dashboard surface.
    ///
    /// Called by `DashboardView.loadData()` synchronously AFTER `await load(...)` returns. It runs the
    /// gated dual-run build inside `VerdictSurfaceActivation.withEnabled(true)` over the inputs `load()`
    /// snapshotted, making the live PRS readiness/strain pipeline run in production on this surface —
    /// no longer tests-only. This does NOT flip `PRSActivation` / `PRSMasterActivation` (their defaults
    /// stay false → the app-wide legacy-byte-identical fences are untouched), and it does NOT change
    /// the legacy recovery score or legacy recommendation (both computed earlier and independently in
    /// `load()`).
    ///
    /// Synchronous on purpose: `withEnabled` restores the override via `defer` the instant its closure
    /// returns, so the gated build runs fully inside the sync override scope with no `await` straddle.
    ///
    /// Honest-confidence deferral is inherited: on cold-start / low confidence
    /// `PRSReadinessInputBuilder.build(...)` returns nil, so `buildDualRunMessage` leaves
    /// `dualRunMessage` nil — no fabricated verdict.
    func activateVerdictSurface() {
        VerdictSurfaceActivation.withEnabled(true) {
            self.buildDualRunMessage(
                allSessions: lastDualRunSessions,
                fatigueResult: lastDualRunFatigue,
                daysSinceRest: lastDualRunDaysSinceRest
            )
        }
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
