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

    /// v2.1 (ADR-0002) — whether the headline exercise's verdict was match-proximity-tightened on
    /// the last `refresh`. Drives the card's "microdose" framing (never the numbers).
    private(set) var lastHeadlineMatchProximity: Bool = false

    /// v1.7.3 UAT round 3 (U25) — the readings the pre-session brief opens with. Assembled from
    /// the SAME inputs this refresh already gathered for the verdict; nil before the first refresh.
    private(set) var briefReadings: TodayBriefReadings?

    /// v1.7.3 UAT round 3 (U25 / U26) — today's session cap for a non-strength planned day.
    /// Recomputed on every refresh from live signals and held in memory only; nil on a lift day.
    private(set) var sessionCap: SessionCapEngine.SessionCap?

    /// v1.7.3 UAT round 3 (U25) — the brief's "Your numbers" block, one line per movement.
    /// Empty on a session-cap day, which states the cap instead.
    private(set) var briefExerciseLines: [BriefExerciseLine] = []

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

    // MARK: - Start-ready plan seam (verdict → workout)

    /// The persisted decision state — reconstructed PURELY from the frozen prescription's set markers,
    /// so it survives `refresh`, a tab revisit, or an app relaunch (a brand-new ViewModel over the same
    /// store derives the identical state). This is the AUTHORITATIVE start-readiness source — there is
    /// no transient gating flag.
    var decisionState: PersistedVerdictDecisionState {
        guard let plan else { return .pending }
        return VerdictDecisionApplier.persistedDecisionState(forTopSets: decisionSets(in: plan))
    }

    /// The exact, immutable workout to start — resolved through `VerdictDecisionApplier`:
    ///   - while the persisted state is `.pending` ⇒ nil (nothing to start yet);
    ///   - accepted / mixed ⇒ the adjusted resolved plan (with any accepted volume cut applied);
    ///   - kept ⇒ the authored resolved plan.
    /// Pure read — never mutates the prescription or the source template.
    var resolvedPlanForWorkout: ResolvedSessionPlan? {
        guard let plan, decisionState != .pending else { return nil }
        // The cap rides along in memory (U25/U26) so the guided session can print "planned →
        // capped" without a schema field and without recomputing anything.
        return ResolvedSessionPlan.resolve(from: plan).withSessionCap(sessionCap)
    }

    /// Whether the Start CTA may render: true exactly when a resolved plan can be produced. The card
    /// reads THIS, so the Start button can never appear and then no-op.
    var canStartResolvedWorkout: Bool { resolvedPlanForWorkout != nil }

    /// The frozen prescription's stable id for the current plan (verdict → prescription link key).
    var currentPrescriptionId: UUID? { plan?.id }

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
                crossModalResult: nil,
                nextMatchDate: athlete.nextMatchDate,  // ADR-0002 match-proximity input (nil-safe)
                fatigueZone: fatigueResult?.zone       // U25/U26 session-cap input; nil ⇒ rows idle
            )
        } else {
            results = verdictService.evaluateAndWrite(
                prescribedWorkout: plan,
                decisionInput: nil,            // cold-start ⇒ honest defer (suggestion == plan)
                crossModalResult: nil,
                nextMatchDate: athlete.nextMatchDate,  // zero effect on defer — never trim on a guess
                fatigueZone: fatigueResult?.zone
            )
        }

        deferredToPlan = (built == nil)
        // U25/U26: the cap the service just computed, if today is a non-strength planned day.
        sessionCap = verdictService.lastSessionCap
        briefReadings = assembleBriefReadings(
            built: built,
            fatigueResult: fatigueResult,
            todaySnapshot: todaySnapshot,
            recentSnapshots: recentSnapshots,
            nextMatchDate: athlete.nextMatchDate
        )
        captureHeadlineVerdict(plan: plan, results: results)
        rebuildDisplay()
    }

    // MARK: - Brief readings (U25 — what today looks like, readings only)

    /// Package the inputs this refresh already gathered into the brief's opening block. No second
    /// fetch and no second engine: every field is either a snapshot value the app already prints
    /// or an engine output the verdict itself was built from.
    private func assembleBriefReadings(
        built: PRSReadinessInputBuilder.BuiltReadiness?,
        fatigueResult: FatigueIndexEngine.FatigueResult?,
        todaySnapshot: RecoverySnapshot?,
        recentSnapshots: [RecoverySnapshot],
        nextMatchDate: Date?
    ) -> TodayBriefReadings {
        let sleepSeries = recentSnapshots
            .sorted { $0.date < $1.date }
            .suffix(14)
            .compactMap(\.sleepDurationMinutes)
        let sleepMean: Double? = sleepSeries.isEmpty
            ? nil
            : sleepSeries.reduce(0, +) / Double(sleepSeries.count)

        return TodayBriefReadings(
            readinessScore: built.map { Int($0.readiness.readiness.rounded()) },
            readinessZone: built?.readiness.zone,
            fatigueIndex: fatigueResult?.index,
            fatigueZone: fatigueResult?.zone,
            hrvMs: todaySnapshot?.hrvSDNN,
            hrvBaselineMs: todaySnapshot?.hrvBaseline,
            rhrBpm: todaySnapshot?.restingHR,
            rhrBaselineBpm: todaySnapshot?.restingHRBaseline,
            sleepMinutes: todaySnapshot?.sleepDurationMinutes,
            sleepRecentMeanMinutes: sleepMean,
            matchDaysAway: TodayVerdictEngine.matchDaysAway(
                nextMatchDate: nextMatchDate, asOf: .now, calendar: .current
            ),
            isLearning: built == nil
        )
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
            lastHeadlineMatchProximity = false
            return
        }
        let headlineExercise = producing[headlineIndex].exercise
        lastHeadlineRegionRaw = (headlineExercise.muscleGroup?.region ?? .fullBody).rawValue
        if deferredToPlan {
            lastHeadlineVerdictRaw = "defer"
            lastHeadlineMatchProximity = false
        } else if headlineIndex < results.count {
            lastHeadlineVerdictRaw = Self.verdictRaw(results[headlineIndex].verdict)
            lastHeadlineMatchProximity = results[headlineIndex].matchProximity
        } else {
            lastHeadlineVerdictRaw = nil
            lastHeadlineMatchProximity = false
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
        for top in decisionSets(in: plan) {
            VerdictDecisionApplier.applyAccept(to: top, appliedAt: decidedAt)
        }
        persistRebuildEmit(action: .accepted, decidedAt: decidedAt)
    }

    /// KEEP-MY-PLAN (one tap, SC3) — records the decline on every top set; planned numbers unchanged.
    func keepPlan() {
        guard let plan else { return }
        let decidedAt = Date.now
        for top in decisionSets(in: plan) {
            VerdictDecisionApplier.applyKeepPlan(to: top)
        }
        persistRebuildEmit(action: .keptPlan, decidedAt: decidedAt)
    }

    /// FEEL-OVERRIDE (SC2, first-class logged input). Maps the athlete's feel onto a slot outcome,
    /// then emits a `.feel` decision:
    ///   - `.feelingStrong` ⇒ dismiss the suggestion = keep-plan on each top set (feels good → keep).
    ///   - `.feelingRough`  ⇒ conservative = accept each top set that HAS a suggestion; a top set with
    ///     NO suggestion is recorded as keep-plan (NEVER fabricate a trim). Every top set therefore
    ///     gets a marker, so a feel decision is always reconstructible as decided (mixed when some
    ///     exercises had a suggestion and others didn't), never left looking pending.
    func feelOverride(_ feel: FeelOverride) {
        guard let plan else { return }
        let decidedAt = Date.now
        switch feel {
        case .feelingStrong:
            for top in decisionSets(in: plan) {
                VerdictDecisionApplier.applyKeepPlan(to: top)
            }
        case .feelingRough:
            for top in decisionSets(in: plan) {
                if VerdictDecisionApplier.hasSuggestion(top) {
                    VerdictDecisionApplier.applyAccept(to: top, appliedAt: decidedAt)
                } else {
                    VerdictDecisionApplier.applyKeepPlan(to: top)
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

    /// NOTE (U25/U26): a session-cap day emits NO `VerdictDecision`. The `VerdictEvent` schema is
    /// kilogram-shaped (planned/adjusted top set, delta kg) and the WTP analysis reads it as such;
    /// logging a run as a 0 kg row would corrupt that series to record a decision that is already
    /// persisted on the set markers. Wiring the cap into the event schema is a deliberate deferral,
    /// not an oversight.
    private func emitDecision(action: VerdictAction, decidedAt: Date) {
        guard let plan, let headline = sessionHeadline(in: plan) else { return }
        let planned = headline.targetWeightKg ?? 0
        let adjusted = headline.adjustedTargetWeightKg
        // Structured non-weight context: an RPE cap strictly below the authored RPE, and a positive
        // back-off cut. These make a volume-/RPE-only adjustment honest in analytics (differed == true).
        let rpeCap: Double? = {
            guard let plannedRPE = headline.targetRPE, let adjRPE = headline.adjustedTargetRPE,
                  adjRPE < plannedRPE - 0.001 else { return nil }
            return adjRPE
        }()
        let backoffCut: Int? = (headline.adjustedBackoffSetCut ?? 0) > 0 ? headline.adjustedBackoffSetCut : nil
        let decision = VerdictDecision(
            action: action,
            plannedTopSetKg: planned,
            adjustedTopSetKg: adjusted,
            hadAdjustment: VerdictDecisionApplier.hasSuggestion(headline),
            reasonLine: headline.verdictReason ?? "",
            decidedAt: decidedAt,
            suggestedBackoffSetCut: backoffCut,
            suggestedRPECap: rpeCap
        )
        lastDecision = decision
        onDecisionRecorded?(decision)
    }

    // MARK: - Display assembly

    private func rebuildDisplay() {
        guard let plan else {
            display = nil
            briefExerciseLines = []
            return
        }
        briefExerciseLines = buildBriefExerciseLines(in: plan)
        // U25/U26: the non-strength planned day. There is no headline top set to lead with, so the
        // surface leads with the day's duration + RPE ceiling instead. Before this branch existed
        // the method returned nil here and the day showed NOTHING — no verdict, no start door.
        guard let headline = sessionHeadline(in: plan) else {
            display = sessionCapDisplay(for: plan)
            return
        }
        let plannedTopSetKg = headline.targetWeightKg ?? 0
        let adjustedTopSetKg = headline.adjustedTargetWeightKg ?? plannedTopSetKg
        // Semantic: weight-, RPE-, OR volume-only suggestion all count as an adjustment.
        let adjusted = VerdictDecisionApplier.hasSuggestion(headline)
        let kind: TodayVerdictDisplay.Kind = deferredToPlan
            ? .deferred
            : (adjusted ? .adjusted : .asPlanned)
        let confidenceNote: String? = (kind == .deferred)
            ? String(localized: "verdictCard.confidence.learning", defaultValue: "Still learning your baseline")
            : nil
        // Applied state derives from the SAME persisted source as start-readiness (never a transient
        // flag): a decision recorded anywhere — even one that left the headline slot untouched (mixed
        // feel-rough) — reads as decided, surfacing the start affordance.
        let appliedState: TodayVerdictDisplay.AppliedState = {
            switch decisionState {
            case .pending:  return .pending
            case .keptPlan: return .keptPlan
            case .accepted, .mixed: return .accepted
            }
        }()

        // Epic 9 (adaptive cells): the proposal's structured shape inputs — the suggestion's
        // back-off cut and the headline exercise's working-set count ("ALL 4 SETS").
        let backoffCut = max(0, headline.adjustedBackoffSetCut ?? 0)
        let workingSets = headlineWorkingSetCount(in: plan)

        display = TodayVerdictDisplay(
            headlineExerciseName: sessionHeadlineName(in: plan) ?? "",
            plannedTopSetKg: plannedTopSetKg,
            adjustedTopSetKg: adjustedTopSetKg,
            hasAdjustment: adjusted,
            reasonLine: headline.verdictReason ?? "",
            kind: kind,
            confidenceNote: confidenceNote,
            appliedState: appliedState,
            // Microdose framing ONLY on a real proximity-tightened adjustment (ADR-0002 / item 5).
            isMicrodose: lastHeadlineMatchProximity && kind == .adjusted,
            backoffSetCut: backoffCut,
            workingSetCount: workingSets
        )
    }

    /// The brief's "Your numbers" block: for each movement that has a working top set, the
    /// athlete's planned numbers and the suggestion beside them. Pure read — never mutates the
    /// prescription. Movements without a working weighted set contribute no line (a cap day
    /// therefore produces none, and states the session cap instead).
    private func buildBriefExerciseLines(in plan: PrescribedWorkout) -> [BriefExerciseLine] {
        plan.allExercises.compactMap { exercise in
            let working = exercise.sortedSets.filter { !$0.isWarmup && ($0.targetWeightKg ?? 0) > 0 }
            guard let top = working.max(by: { ($0.targetWeightKg ?? 0) < ($1.targetWeightKg ?? 0) })
            else { return nil }

            let cut = max(0, top.adjustedBackoffSetCut ?? 0)
            let suggestedKg: Double? = {
                guard let planned = top.targetWeightKg, let adjusted = top.adjustedTargetWeightKg,
                      adjusted < planned - 0.001 else { return nil }
                return adjusted
            }()
            return BriefExerciseLine(
                id: exercise.id,
                exerciseName: exercise.exerciseName,
                plannedTopSetKg: top.targetWeightKg,
                suggestedTopSetKg: suggestedKg,
                plannedWorkingSets: working.count,
                suggestedWorkingSets: max(1, working.count - cut),
                plannedRPE: top.targetRPE,
                suggestedRPE: top.adjustedTargetRPE
            )
        }
    }

    /// Build the session-cap display for a non-strength planned day (U25/U26).
    ///
    /// Returns nil — and so keeps the pre-round-3 "no card" behaviour — when the service produced
    /// no cap, which means the day is not honestly a cap day (an empty plan, or a strength day
    /// with neither weights nor duration). Nothing is invented to fill the slot.
    private func sessionCapDisplay(for plan: PrescribedWorkout) -> TodayVerdictDisplay? {
        guard let cap = sessionCap else { return nil }

        let nonWarmupSets = sessionCapSets(in: plan)
        let plannedDuration: Int? = {
            let total = nonWarmupSets.compactMap(\.targetDurationSeconds).reduce(0, +)
            return total > 0 ? total : nil
        }()
        let plannedRPE = nonWarmupSets.compactMap(\.targetRPE).max()
        let reason = nonWarmupSets.compactMap(\.verdictReason).first ?? ""

        let appliedState: TodayVerdictDisplay.AppliedState = {
            switch decisionState {
            case .pending:  return .pending
            case .keptPlan: return .keptPlan
            case .accepted, .mixed: return .accepted
            }
        }()

        return TodayVerdictDisplay(
            // The session name, not an exercise: a court session's identity is the session.
            headlineExerciseName: plan.templateName,
            plannedTopSetKg: 0,
            adjustedTopSetKg: 0,
            hasAdjustment: cap.modulatesPlan,
            reasonLine: reason,
            kind: .sessionCap,
            confidenceNote: deferredToPlan
                ? String(localized: "verdictCard.confidence.learning", defaultValue: "Still learning your baseline")
                : nil,
            appliedState: appliedState,
            isMicrodose: false,
            backoffSetCut: 0,
            workingSetCount: nonWarmupSets.count,
            sessionCap: cap,
            plannedDurationSeconds: plannedDuration,
            plannedSessionRPE: plannedRPE
        )
    }

    // MARK: - Headline selection (same rule the Phase-43 service uses)

    /// The sets a decision is RECORDED on. On a lift day these are the per-exercise top working
    /// sets — unchanged. On a session-cap day (no weighted top set anywhere) there are none, so
    /// the decision is recorded on every non-warm-up set instead: the cap applies to the whole
    /// session, and the accept/keep markers are exactly the same local-only `TemplateSet` slots
    /// the lift path uses, so the decision survives a refresh and a relaunch the same way.
    /// **No new persisted field, no synced-schema change** (U25/U26).
    private func decisionSets(in plan: PrescribedWorkout) -> [TemplateSet] {
        let tops = perExerciseTopSets(in: plan)
        guard tops.isEmpty else { return tops }
        return sessionCapSets(in: plan)
    }

    /// Every non-warm-up set of the plan — the cap day's decision surface.
    private func sessionCapSets(in plan: PrescribedWorkout) -> [TemplateSet] {
        plan.allExercises.flatMap { $0.sortedSets.filter { !$0.isWarmup } }
    }

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

    /// Working (non-warmup) set count of the exercise that owns the headline top set —
    /// the "ALL 4 SETS" number in the adaptive cells (epic 9).
    private func headlineWorkingSetCount(in plan: PrescribedWorkout) -> Int {
        guard let headline = sessionHeadline(in: plan) else { return 0 }
        let owner = plan.allExercises.first { exercise in
            exercise.sets.contains { $0.id == headline.id }
        }
        return owner?.sortedSets.filter { !$0.isWarmup }.count ?? 0
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

    // Adjustment detection now lives in the canonical `VerdictDecisionApplier.hasSuggestion` (semantic:
    // weight OR RPE OR volume) — the kg-only local predicate was removed so there is one source of truth.

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
