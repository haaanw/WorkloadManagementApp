import Foundation
import SwiftData

/// Phase 44 Plan 01 (Task 2) — the `@MainActor @Observable` orchestration behind the suggest-and-
/// confirm verdict card.
///
/// Responsibilities:
///  1. `refresh(athlete:)` — fetch today's planned session, assemble the REAL readiness inputs from
///     the repositories (mirroring `DashboardViewModel`), drive the Phase-43 `TodayVerdictService`
///     to populate the Phase-42 `TemplateSet` verdict slots, and build a `TodayVerdictDisplay`.
///  2. `accept()` / `keepPlan()` / `feelOverride(_:)` — apply the autonomy-respecting slot mutations
///     via the pure `VerdictDecisionApplier`, persist, rebuild the display, and emit a
///     `VerdictDecision` (Phase 45 wires `onDecisionRecorded` to log it).
///
/// ## Stored-property pattern (iOS-26.1-sim deinit safety)
/// The `TodayVerdictService` + every `@MainActor` repository are STORED properties created in `init`
/// (NOT method locals). A `@MainActor` repository deallocated mid-synchronous-test trips the
/// libswift_Concurrency back-deploy deinit bug (`swift_task_deinitOnExecutorMainActorBackDeploy` →
/// SIGABRT) documented in 42-02/43-03. Owning them for the VM lifetime avoids it.
///
/// ## Honest cold-start
/// When there is no real training/recovery history, `PRSReadinessInputBuilder.buildDetailed` returns
/// nil; the service then DEFERS (suggestion == plan) and the display is `.deferred` with the quiet
/// still-learning note — never a fabricated trim (SC4).
@MainActor
@Observable
final class TodayVerdictViewModel {

    // MARK: - Published state

    /// The value the card renders. `nil` ⇒ no today-plan ⇒ render no card.
    var display: TodayVerdictDisplay?

    /// Phase 45 wires the logger here; nil in Phase 44.
    var onDecisionRecorded: ((VerdictDecision) -> Void)?

    /// The most recent decision (for tests + debug).
    private(set) var lastDecision: VerdictDecision?

    /// Phase 45 — the headline exercise's verdict label ("go"/"modify"/"hold", or "defer" on
    /// cold-start) captured from the last `refresh`, for the logged `VerdictEvent`. Non-visual.
    private(set) var lastHeadlineVerdictRaw: String?

    /// Phase 45 — the headline exercise's muscle REGION label (a `MuscleRegion.rawValue`) captured
    /// from the last `refresh`, for the logged `VerdictEvent`. Non-visual.
    private(set) var lastHeadlineRegionRaw: String?

    // MARK: - Stored dependencies (created once in init — see deinit-safety note)

    private let modelContext: ModelContext
    private let verdictService: TodayVerdictService
    private let plannedSessionRepository: PlannedSessionRepository
    private let recoveryRepository: RecoveryRepository
    private let workloadRepository: WorkloadRepository
    private let workoutRepository: WorkoutRepository
    private let sorenessLogRepository: SorenessLogRepository

    /// The fetched today-plan the decision methods operate on (re-fetched only in `refresh`).
    private var plan: PrescribedWorkout?

    /// True when the last `refresh` deferred (cold-start / honest-confidence) — drives `.deferred`.
    private var deferredToPlan: Bool = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.verdictService = TodayVerdictService(modelContext: modelContext)
        self.plannedSessionRepository = PlannedSessionRepository(modelContext: modelContext)
        self.recoveryRepository = RecoveryRepository(modelContext: modelContext)
        self.workloadRepository = WorkloadRepository(modelContext: modelContext)
        self.workoutRepository = WorkoutRepository(modelContext: modelContext)
        self.sorenessLogRepository = SorenessLogRepository(modelContext: modelContext)
    }

    // MARK: - Refresh: assemble inputs, write slots, build display

    func refresh(athlete: Athlete) {
        guard let plan = plannedSessionRepository.fetchTodaysPlannedSession(athleteId: athlete.id) else {
            self.plan = nil
            display = nil
            return
        }
        self.plan = plan

        // --- Assemble readiness inputs from the repositories (mirrors DashboardViewModel). --------
        let recentSnapshots = (try? recoveryRepository.fetchRecoveryHistory(days: 28, athlete: athlete)) ?? []
        let todaySnapshot: RecoverySnapshot? = {
            if let today = try? recoveryRepository.fetchTodaySnapshot(athlete: athlete) { return today }
            return try? recoveryRepository.fetchLatestSnapshot(athlete: athlete)
        }()
        let latestHRV = todaySnapshot?.hrvSDNN
        let latestRHR = todaySnapshot?.restingHR
        let latestSleep = todaySnapshot?.sleepDurationMinutes

        var acwr = 0.0
        var acwrZone: ACWRZone = .noData
        if let snapshot = try? workloadRepository.fetchLatestSnapshot(athlete: athlete) {
            acwr = snapshot.acwr
            acwrZone = snapshot.zone
        }

        let allSessions = (try? workoutRepository.fetchSessions(last: 90, athlete: athlete)) ?? []
        let daysSinceRest = computeDaysSinceRest(athlete: athlete)
        let fatigueResult = assembleFatigue(
            allSessions: allSessions,
            recentSnapshots: recentSnapshots,
            daysSinceRest: daysSinceRest,
            athlete: athlete
        )

        let built = PRSReadinessInputBuilder.buildDetailed(
            recentSnapshots: recentSnapshots,
            latestHRV: latestHRV,
            latestRHR: latestRHR,
            latestSleepMinutes: latestSleep,
            allSessions: allSessions,
            fatigueResult: fatigueResult,
            daysSinceRest: daysSinceRest,
            wellnessScore: nil,
            acwr: acwr,
            acwrZone: acwrZone,
            asOf: .now,
            calendar: .current
        )

        // --- Write the slots via the service SEAM. ------------------------------------------------
        // crossModalResult is nil: the cross-modal shadow gate is OFF, so cross-modal contributes
        // exactly zero today. THIS is the single line to revisit on a future gate flip.
        let results: [TodayVerdictEngine.VerdictResult]
        if let built {
            let recommendation = AutoregulationEngine.recommendReadiness(input: built.input)
            let decisionInput = verdictService.makeDecisionInput(built: built, recommendation: recommendation)
            results = verdictService.evaluateAndWrite(
                prescribedWorkout: plan,
                decisionInput: decisionInput,
                crossModalResult: nil
            )
        } else {
            results = verdictService.evaluateAndWrite(
                prescribedWorkout: plan,
                decisionInput: nil,            // cold-start ⇒ honest defer (suggestion == plan)
                crossModalResult: nil
            )
        }

        deferredToPlan = (built == nil)
        captureHeadlineVerdict(plan: plan, results: results)
        rebuildDisplay()
    }

    // MARK: - Phase 45: headline verdict/region capture (non-visual, for the logged VerdictEvent)

    /// Capture the headline exercise's verdict label + region from the per-exercise `evaluateAndWrite`
    /// results. `evaluateAndWrite` produces ONE result per exercise that has a working top set, in
    /// `plan.allExercises` order — so the producing-exercise list is index-aligned with `results`.
    /// The session headline is the producing exercise with the max top-set weight; its region + result
    /// are what 45-02 logs. Cold-start defers ⇒ "defer".
    private func captureHeadlineVerdict(plan: PrescribedWorkout, results: [TodayVerdictEngine.VerdictResult]) {
        // Producing exercises = same filter/order evaluateAndWrite uses (skip no-working-weight ones).
        let producing: [(exercise: TemplateExercise, topKg: Double)] = plan.allExercises.compactMap { exercise in
            let working = exercise.sortedSets.filter { !$0.isWarmup && ($0.targetWeightKg ?? 0) > 0 }
            guard let top = working.max(by: { ($0.targetWeightKg ?? 0) < ($1.targetWeightKg ?? 0) }),
                  let kg = top.targetWeightKg else { return nil }
            return (exercise, kg)
        }
        guard let headlineIndex = producing.indices.max(by: { producing[$0].topKg < producing[$1].topKg }) else {
            lastHeadlineVerdictRaw = deferredToPlan ? "defer" : nil
            lastHeadlineRegionRaw = nil
            return
        }
        let headlineExercise = producing[headlineIndex].exercise
        lastHeadlineRegionRaw = (headlineExercise.muscleGroup?.region ?? .fullBody).rawValue
        if deferredToPlan {
            lastHeadlineVerdictRaw = "defer"
        } else if headlineIndex < results.count {
            lastHeadlineVerdictRaw = Self.verdictRaw(results[headlineIndex].verdict)
        } else {
            lastHeadlineVerdictRaw = nil
        }
    }

    private static func verdictRaw(_ verdict: TodayVerdictEngine.Verdict) -> String {
        switch verdict {
        case .go: return "go"
        case .modify: return "modify"
        case .hold: return "hold"
        }
    }

    // MARK: - Decision actions

    /// ACCEPT the suggestion on every exercise's top set. Marks `verdictAppliedAt`; never overwrites
    /// the authored `targetWeightKg`.
    func accept() {
        guard let plan else { return }
        let decidedAt = Date.now
        for top in perExerciseTopSets(in: plan) {
            VerdictDecisionApplier.applyAccept(to: top, appliedAt: decidedAt)
        }
        persistRebuildEmit(action: .accepted, decidedAt: decidedAt)
    }

    /// KEEP-MY-PLAN (one tap, SC3) — records the decline on every top set; planned numbers unchanged.
    func keepPlan() {
        guard let plan else { return }
        let decidedAt = Date.now
        for top in perExerciseTopSets(in: plan) {
            VerdictDecisionApplier.applyKeepPlan(to: top)
        }
        persistRebuildEmit(action: .keptPlan, decidedAt: decidedAt)
    }

    /// FEEL-OVERRIDE (SC2, first-class logged input). Maps the athlete's feel onto a slot outcome,
    /// then emits a `.feel` decision:
    ///   - `.feelingStrong` ⇒ dismiss the suggestion = keep-plan on each top set (feels good → keep).
    ///   - `.feelingRough`  ⇒ conservative = accept on each top set that HAS an adjustment; sets with
    ///     no adjustment are left as-is (NEVER fabricate a trim the engine did not produce).
    func feelOverride(_ feel: FeelOverride) {
        guard let plan else { return }
        let decidedAt = Date.now
        switch feel {
        case .feelingStrong:
            for top in perExerciseTopSets(in: plan) {
                VerdictDecisionApplier.applyKeepPlan(to: top)
            }
        case .feelingRough:
            for top in perExerciseTopSets(in: plan) {
                if hasAdjustment(top) {
                    VerdictDecisionApplier.applyAccept(to: top, appliedAt: decidedAt)
                }
            }
        }
        persistRebuildEmit(action: .feel(feel), decidedAt: decidedAt)
    }

    // MARK: - Decision plumbing

    private func persistRebuildEmit(action: VerdictAction, decidedAt: Date) {
        try? modelContext.save()
        rebuildDisplay()
        emitDecision(action: action, decidedAt: decidedAt)
    }

    private func emitDecision(action: VerdictAction, decidedAt: Date) {
        guard let plan, let headline = sessionHeadline(in: plan) else { return }
        let planned = headline.targetWeightKg ?? 0
        let adjusted = headline.adjustedTargetWeightKg
        let decision = VerdictDecision(
            action: action,
            plannedTopSetKg: planned,
            adjustedTopSetKg: adjusted,
            hadAdjustment: hasAdjustment(headline),
            reasonLine: headline.verdictReason ?? "",
            decidedAt: decidedAt
        )
        lastDecision = decision
        onDecisionRecorded?(decision)
    }

    // MARK: - Display assembly

    private func rebuildDisplay() {
        guard let plan, let headline = sessionHeadline(in: plan) else {
            display = nil
            return
        }
        let plannedTopSetKg = headline.targetWeightKg ?? 0
        let adjustedTopSetKg = headline.adjustedTargetWeightKg ?? plannedTopSetKg
        let adjusted = hasAdjustment(headline)
        let kind: TodayVerdictDisplay.Kind = deferredToPlan
            ? .deferred
            : (adjusted ? .adjusted : .asPlanned)
        let confidenceNote: String? = (kind == .deferred)
            ? String(localized: "verdictCard.confidence.learning", defaultValue: "Still learning your baseline")
            : nil
        let appliedState: TodayVerdictDisplay.AppliedState = {
            if headline.verdictAppliedAt != nil { return .accepted }
            if headline.athleteOverrode { return .keptPlan }
            return .pending
        }()

        display = TodayVerdictDisplay(
            headlineExerciseName: sessionHeadlineName(in: plan) ?? "",
            plannedTopSetKg: plannedTopSetKg,
            adjustedTopSetKg: adjustedTopSetKg,
            hasAdjustment: adjusted,
            reasonLine: headline.verdictReason ?? "",
            kind: kind,
            confidenceNote: confidenceNote,
            appliedState: appliedState
        )
    }

    // MARK: - Headline selection (same rule the Phase-43 service uses)

    /// Per-exercise top working set = the non-warmup set with the max `targetWeightKg > 0`.
    private func perExerciseTopSets(in plan: PrescribedWorkout) -> [TemplateSet] {
        plan.allExercises.compactMap { exercise in
            exercise.sortedSets
                .filter { !$0.isWarmup && ($0.targetWeightKg ?? 0) > 0 }
                .max { ($0.targetWeightKg ?? 0) < ($1.targetWeightKg ?? 0) }
        }
    }

    /// The SESSION headline top set = the per-exercise top set with the max weight across the session.
    private func sessionHeadline(in plan: PrescribedWorkout) -> TemplateSet? {
        perExerciseTopSets(in: plan).max { ($0.targetWeightKg ?? 0) < ($1.targetWeightKg ?? 0) }
    }

    /// The exercise name that owns the session headline top set.
    private func sessionHeadlineName(in plan: PrescribedWorkout) -> String? {
        var best: (name: String, kg: Double)? = nil
        for exercise in plan.allExercises {
            guard let top = exercise.sortedSets
                .filter({ !$0.isWarmup && ($0.targetWeightKg ?? 0) > 0 })
                .max(by: { ($0.targetWeightKg ?? 0) < ($1.targetWeightKg ?? 0) }) else { continue }
            let kg = top.targetWeightKg ?? 0
            if best == nil || kg > best!.kg {
                best = (exercise.exerciseName, kg)
            }
        }
        return best?.name
    }

    /// A real adjustment = the engine wrote an adjusted weight strictly below the authored plan.
    private func hasAdjustment(_ set: TemplateSet) -> Bool {
        guard let planned = set.targetWeightKg else { return false }
        let adjusted = set.adjustedTargetWeightKg ?? planned
        return adjusted < planned - 0.001
    }

    // MARK: - Input assembly helpers (mirror DashboardViewModel)

    /// Build a REAL `FatigueResult` from the athlete's history. Returns nil when there is no real
    /// training history (no sessions) → honest cold-start (never a fabricated fatigue value).
    private func assembleFatigue(
        allSessions: [WorkoutSession],
        recentSnapshots: [RecoverySnapshot],
        daysSinceRest: Int,
        athlete: Athlete
    ) -> FatigueIndexEngine.FatigueResult? {
        guard !allSessions.isEmpty else { return nil }

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

        let wellnessWindowStart = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        let athleteId = athlete.id
        let wellnessDescriptor = FetchDescriptor<WellnessCheckIn>(
            predicate: #Predicate<WellnessCheckIn> { $0.date >= wellnessWindowStart },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let recentWellnessScores: [Double] = ((try? modelContext.fetch(wellnessDescriptor)) ?? [])
            .filter { $0.athlete?.id == athleteId }
            .map(\.wellnessScore)

        let niggleLogs = sorenessLogRepository
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
        return FatigueIndexEngine.compute(input: fatigueInput, cycleContext: nil, cyclesObserved: 0)
    }

    /// Mirror of `DashboardViewModel.computeDaysSinceRest`.
    private func computeDaysSinceRest(athlete: Athlete) -> Int {
        guard let sessions = try? workoutRepository.fetchSessions(last: 14, athlete: athlete) else { return 0 }
        let calendar = Calendar.current
        var days = 0
        var checkDate = calendar.startOfDay(for: .now)

        while days < 14 {
            let dayStart = checkDate
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let hasSession = sessions.contains { session in
                session.sessionDate >= dayStart && session.sessionDate < dayEnd
            }
            if !hasSession { break }
            days += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }
        return days
    }
}
