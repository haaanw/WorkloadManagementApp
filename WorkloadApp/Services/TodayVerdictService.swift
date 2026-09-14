import Foundation
import SwiftData

/// Phase 43 Plan 03 — the `@MainActor` orchestration that ties the two pure verdict engines
/// (`TodayVerdictEngine` 43-01, `VerdictReasonBuilder` 43-02) to a real "today's planned session"
/// `PrescribedWorkout` and WRITES the verdict SUGGESTION into the Phase-42 nullable `TemplateSet`
/// verdict slots.
///
/// ## What it writes (a SUGGESTION — never an acceptance)
/// For each exercise's top set it writes `adjustedTargetWeightKg`, `adjustedTargetRPE` (downward-cap
/// only, and ONLY when a planned RPE existed), and `verdictReason`. It NEVER sets `verdictAppliedAt`
/// or `athleteOverrode` — those are the Phase-44 accept/decline action. It mutates ONLY the frozen
/// `PrescribedWorkout`'s working sets; the source authored template was deep-copied at plan time and
/// is never touched.
///
/// ## Sources the LIVE reason path
/// The production wrapper `evaluateTodaysPlannedSession(...)` assembles a REAL
/// `ReasoningEngine.DecisionInput` from `PRSReadinessInputBuilder.buildDetailed` (the fully-fused
/// `ReadinessResult` + `StrainRiskResult`), so the VERDICT-03 reason is honestly sourced — not
/// test-injected-only. On cold-start (`buildDetailed` returns nil) it DEFERS to the plan (the
/// suggestion equals the plan, the reason is the defer copy) — never a fabricated trim.
///
/// ## Cross-modal
/// Cross-modal passes straight through to the gate-guarded engines. When the gate is on, the
/// verdict engine keeps it only-tightening and bounded; when off, it contributes zero.
///
/// Conventions: `@MainActor final class` taking `ModelContext` (mirrors the repository/pipeline
/// convention). Tuwa voice; never frames a trim as harm-forecasting (source-grep fenced).
@MainActor
final class TodayVerdictService {

    private let modelContext: ModelContext
    /// Held as a stored property (NOT a method local). A `@MainActor` repository deallocated
    /// mid-synchronous-test-method trips the iOS 26.1-sim libswift_Concurrency back-deploy deinit
    /// bug (`swift_task_deinitOnExecutorMainActorBackDeploy` → SIGABRT) — owning it for the service's
    /// lifetime (which the caller/test holds as a stored prop) avoids it.
    private let plannedSessionRepository: PlannedSessionRepository
    /// Read-side for the decision-time `VerdictEvent` record — frozen (decided) verdict rendering
    /// sources its match-proximity flag from here, never from the live match date. Stored for the
    /// same iOS 26.1-sim deinit-safety reason as `plannedSessionRepository`.
    private let verdictEventRepository: VerdictEventRepository

    /// v1.7.3 UAT round 3 (U25 / U26) — the session cap the LAST `evaluateAndWrite` produced for a
    /// planned day that carries no weighted top set, or nil when the day had one (the lift path is
    /// untouched). Read by `TodayVerdictViewModel` right after the call, the way `results` is.
    ///
    /// **Nothing about the synced schema changed to carry this.** The cap is a pure function of
    /// today's live signals, so it is recomputed on every refresh and lives only here and on the
    /// in-memory `ResolvedSessionPlan`. What DOES persist is the athlete's DECISION, and that uses
    /// the `TemplateSet` verdict slots that already exist and are already excluded from the synced
    /// payload (`WorkoutTemplate.swift:179-192`).
    private(set) var lastSessionCap: SessionCapEngine.SessionCap?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.plannedSessionRepository = PlannedSessionRepository(modelContext: modelContext)
        self.verdictEventRepository = VerdictEventRepository(modelContext: modelContext)
    }

    // MARK: - Production wrapper (sources the live VERDICT-03 reason path)

    // DEFERRED: periodization-position input is NOT modeled this phase — there is no Phase-42
    // plan-position field to read. The verdict reads periodization position when present; this is
    // a CONSCIOUS deferral (not a silent drop) until plan-position data lands. No scaffolding built.

    /// Read today's planned session for `athleteId`, source the real `DecisionInput` from
    /// `PRSReadinessInputBuilder.buildDetailed`, and write the verdict suggestion into its slots.
    /// Returns nil when there is no planned session for today; otherwise the per-exercise verdict
    /// results. Mirrors `DashboardViewModel.buildDualRunMessage` input sourcing.
    @discardableResult
    func evaluateTodaysPlannedSession(
        athleteId: UUID,
        recentSnapshots: [RecoverySnapshot],
        latestHRV: Double?,
        latestRHR: Double?,
        latestSleepMinutes: Double?,
        allSessions: [WorkoutSession],
        fatigueResult: FatigueIndexEngine.FatigueResult?,
        daysSinceRest: Int,
        acwr: Double,
        acwrZone: ACWRZone,
        asOf: Date = .now,
        calendar: Calendar = .current,
        nextMatchDate: Date? = nil
    ) -> [TodayVerdictEngine.VerdictResult]? {
        guard let plan = plannedSessionRepository
            .fetchTodaysPlannedSession(athleteId: athleteId) else { return nil }

        let built = PRSReadinessInputBuilder.buildDetailed(
            recentSnapshots: recentSnapshots,
            latestHRV: latestHRV,
            latestRHR: latestRHR,
            latestSleepMinutes: latestSleepMinutes,
            allSessions: allSessions,
            fatigueResult: fatigueResult,
            daysSinceRest: daysSinceRest,
            wellnessScore: nil,                 // matches DashboardViewModel.buildDualRunMessage source
            acwr: acwr,
            acwrZone: acwrZone,
            asOf: asOf,
            calendar: calendar
        )

        // Cold-start defer: buildDetailed nil → no real DecisionInput → defer (the nil decisionInput
        // drives deferToPlan inside the seam). No trim on a guess (locked).
        guard let built else {
            return evaluateAndWrite(
                prescribedWorkout: plan,
                decisionInput: nil,
                crossModalResult: nil,
                plateStepKg: TodayVerdictEngine.Constants.plateStepKg,
                nextMatchDate: nextMatchDate,
                fatigueZone: fatigueResult?.zone,
                asOf: asOf,
                calendar: calendar
            )
        }

        let recommendation = AutoregulationEngine.recommendReadiness(input: built.input)
        let decisionInput = makeDecisionInput(built: built, recommendation: recommendation)
        let crossModal = CrossModalFatigueEngine.compute(
            sessions: allSessions,
            systemicReadiness: built.readiness.readiness,
            asOf: asOf,
            calendar: calendar
        )

        return evaluateAndWrite(
            prescribedWorkout: plan,
            decisionInput: decisionInput,
            crossModalResult: crossModal,
            plateStepKg: TodayVerdictEngine.Constants.plateStepKg,
            nextMatchDate: nextMatchDate,
            fatigueZone: fatigueResult?.zone,
            asOf: asOf,
            calendar: calendar
        )
    }

    /// Assemble the real `ReasoningEngine.DecisionInput` from a `BuiltReadiness` + the recommendation.
    /// This is the SEAM that makes the live VERDICT-03 reason path real and unit-testable.
    func makeDecisionInput(
        built: PRSReadinessInputBuilder.BuiltReadiness,
        recommendation: AutoregulationEngine.TrainingRecommendation
    ) -> ReasoningEngine.DecisionInput {
        ReasoningEngine.DecisionInput(
            readiness: built.readiness,
            strainRisk: built.strain,
            recommendation: recommendation,
            personalSleepBaselineMinutes: nil
        )
    }

    // MARK: - Injectable seam: evaluate a plan + write the slots

    /// For each exercise in `prescribedWorkout`, select its top set, run the verdict engines, and
    /// write the SUGGESTION into the top set's slots. `decisionInput == nil` ⇒ cold-start defer
    /// (suggestion equals the plan; defer copy; no RPE cap). Returns the per-exercise verdict results.
    /// `nextMatchDate` (ADR-0002) feeds the engine's match-proximity rule; nil / expired / far ⇒
    /// behavior exactly unchanged. Cold-start still defers even near a match — never trim on a guess.
    @discardableResult
    func evaluateAndWrite(
        prescribedWorkout: PrescribedWorkout,
        decisionInput: ReasoningEngine.DecisionInput?,
        crossModalResult: CrossModalFatigueEngine.CrossModalResult?,
        plateStepKg: Double = 2.5,
        nextMatchDate: Date? = nil,
        fatigueZone: FatigueIndexEngine.FatigueZone? = nil,
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> [TodayVerdictEngine.VerdictResult] {
        var results: [TodayVerdictEngine.VerdictResult] = []
        // v1.7.3 UAT round 3 (U25/U26): a day with no weighted top set used to fall out of every
        // branch below and get NO verdict. This tracks whether the lift path ever engaged, so the
        // session-cap branch after the loop can take the day the lift path could not.
        var sawWeightedTopSet = false

        // Match proximity, computed ONCE (expired dates read as absent — the engine never mutates).
        let matchDaysAway = TodayVerdictEngine.matchDaysAway(
            nextMatchDate: nextMatchDate, asOf: asOf, calendar: calendar
        )
        // FROZEN-render proximity source of truth = the DECISION-TIME record: the flag persisted
        // on the `VerdictEvent` logged with the decision (`matchProximityRaw`), never today's live
        // match date. Adding a match AFTER a plain accepted MODIFY must not retro-label it as a
        // microdose, and clearing the match must not strip microdose framing from a decision that
        // was made under it. No event / pre-v2.1 nil honestly reads as false (mirrors
        // `FeltRightPromptEngine`'s nil-is-not-proximity convention). Live (undecided) verdicts
        // keep computing proximity from the live date via the engine below.
        let decidedMatchProximity = verdictEventRepository
            .mostRecentEvent(prescriptionId: prescribedWorkout.id)?.matchProximityRaw ?? false

        for exercise in prescribedWorkout.allExercises {
            // Select the TOP working set = the non-warmup TemplateSet with the max targetWeightKg.
            // Skip exercises with no working weight (leave their slots untouched).
            let working = exercise.sortedSets.filter { !$0.isWarmup && ($0.targetWeightKg ?? 0) > 0 }
            guard let top = working.max(by: { ($0.targetWeightKg ?? 0) < ($1.targetWeightKg ?? 0) }),
                  let plannedKg = top.targetWeightKg else { continue }
            sawWeightedTopSet = true

            // DECIDED sets are FROZEN: once the athlete has accepted or kept this top set, a later
            // refresh must NOT recompute/overwrite its suggestion — that would silently change an
            // accepted number out from under them. Leave the slots untouched and report a result that
            // reflects the frozen state (keeps `results` index-aligned for the headline capture).
            if top.verdictAppliedAt != nil || top.athleteOverrode {
                let frozenVerdict: TodayVerdictEngine.Verdict =
                    VerdictDecisionApplier.hasSuggestion(top) ? .modify : .go
                results.append(
                    TodayVerdictEngine.VerdictResult(
                        verdict: frozenVerdict,
                        adjustedTopSetKg: top.adjustedTargetWeightKg ?? plannedKg,
                        volumeCutSets: top.adjustedBackoffSetCut,
                        loadFactor: 1.0,
                        // Microdose framing is FROZEN with the decision: read back the flag that was
                        // persisted at decision time (see `decidedMatchProximity` above) — never the
                        // current match date, which may have been added or cleared since.
                        matchProximity: decidedMatchProximity && frozenVerdict == .modify
                    )
                )
                continue
            }

            let region = exercise.muscleGroup?.region ?? .fullBody

            // --- Cold-start defer: suggestion EQUAL to the plan, no trim, no RPE cap. ---------------
            guard let decisionInput else {
                top.adjustedTargetWeightKg = plannedKg
                top.adjustedTargetRPE = nil           // a defer caps nothing (locked)
                top.adjustedBackoffSetCut = nil       // a defer cuts no volume (clears any stale cut)
                top.verdictReason = VerdictReasonBuilder.build(
                    decisionInput: nil,
                    crossModalResult: crossModalResult,
                    plannedRegion: region,
                    deferToPlan: true
                ).reasonLine
                results.append(
                    TodayVerdictEngine.VerdictResult(
                        verdict: .go, adjustedTopSetKg: plannedKg, volumeCutSets: nil, loadFactor: 1.0
                    )
                )
                continue
            }

            // --- Real verdict path. -----------------------------------------------------------------
            let recommendation = decisionInput.recommendation
            let planned = TodayVerdictEngine.PlannedTopSet(
                exerciseName: exercise.exerciseName,
                region: region,
                plannedTopSetKg: plannedKg,
                plannedReps: top.targetReps,
                plannedRPE: top.targetRPE
            )
            let result = TodayVerdictEngine.evaluate(
                recommendation: recommendation,
                plannedTopSet: planned,
                crossModalResult: crossModalResult,
                plateStepKg: plateStepKg,
                matchDaysAway: matchDaysAway,
                plannedWorkingSetCount: working.count
            )
            // Match context ONLY when the proximity rule actually engaged (the reason then LEADS
            // with the match + microdose shape).
            let matchContext: VerdictReasonBuilder.MatchContext? = {
                guard result.matchProximity, let daysAway = matchDaysAway,
                      let matchDate = nextMatchDate else { return nil }
                return VerdictReasonBuilder.MatchContext(daysAway: daysAway, matchDate: matchDate)
            }()
            let reason = VerdictReasonBuilder.build(
                decisionInput: decisionInput,
                crossModalResult: crossModalResult,
                plannedRegion: region,
                deferToPlan: false,
                matchContext: matchContext,
                calendar: calendar
            )

            // --- WRITE the suggestion (never verdictAppliedAt / athleteOverrode). --------------------
            top.adjustedTargetWeightKg = result.adjustedTopSetKg
            // Persist the STRUCTURED back-off cut as the execution source of truth (the reason-text
            // clause below stays only for human explanation). nil here explicitly clears any stale cut
            // from a prior re-evaluation.
            top.adjustedBackoffSetCut = result.volumeCutSets

            // NIL-RPE RULE (WARNING-3): only cap when a planned RPE existed; never emit a bare cap.
            if let plannedRPE = top.targetRPE {
                top.adjustedTargetRPE = Swift.min(plannedRPE, recommendation.intensityCap)  // downward only
            } else {
                top.adjustedTargetRPE = nil
            }

            // Encode any back-off-set guidance as a trailing clause (suggestion only — never delete
            // sets). Skipped for a proximity microdose — its copy already says "skip back-offs"
            // (the structured `adjustedBackoffSetCut` above stays the execution source of truth).
            if let cutSets = result.volumeCutSets, !result.matchProximity {
                let clause = String(
                    localized: "verdict.reason.backoffCut",
                    defaultValue: " — consider dropping \(cutSets) back-off set\(cutSets == 1 ? "" : "s")"
                )
                top.verdictReason = reason.reasonLine + clause
            } else {
                top.verdictReason = reason.reasonLine
            }

            results.append(result)
        }

        // --- Session-cap branch: the planned day with no weighted top set (U25 / U26). -----------
        // A run, a court session, a conditioning block. The lift path above skipped every one of
        // its exercises, so without this the day has no verdict, no brief and no start door.
        lastSessionCap = sawWeightedTopSet
            ? nil
            : writeSessionCap(
                prescribedWorkout: prescribedWorkout,
                decisionInput: decisionInput,
                crossModalResult: crossModalResult,
                fatigueZone: fatigueZone,
                matchDaysAway: matchDaysAway,
                nextMatchDate: nextMatchDate,
                calendar: calendar
            )

        try? modelContext.save()
        return results
    }

    // MARK: - Session cap (the non-strength planned day)

    /// Compute today's `SessionCap` for a plan with no weighted top set and write what PERSISTS of
    /// it into the EXISTING local-only `TemplateSet` verdict slots — the reason line on every
    /// non-warm-up set, and an RPE cap only where the plan itself wrote an RPE (the NIL-RPE rule
    /// holds here exactly as it does on the lift path: a bare cap is never fabricated into a slot).
    /// The duration cap is NOT persisted — it is a pure function of today's live signals and is
    /// recomputed on every refresh, carried in memory on `ResolvedSessionPlan.sessionCap`.
    ///
    /// Returns nil when the day is not a cap day at all: no duration anywhere AND a `.strength`
    /// session type means there is nothing honest to cap (an empty or malformed plan), so the
    /// surface keeps its existing no-card behaviour rather than inventing a session.
    private func writeSessionCap(
        prescribedWorkout: PrescribedWorkout,
        decisionInput: ReasoningEngine.DecisionInput?,
        crossModalResult: CrossModalFatigueEngine.CrossModalResult?,
        fatigueZone: FatigueIndexEngine.FatigueZone?,
        matchDaysAway: Int?,
        nextMatchDate: Date?,
        calendar: Calendar
    ) -> SessionCapEngine.SessionCap? {

        let nonWarmupSets = prescribedWorkout.allExercises
            .flatMap { $0.sortedSets }
            .filter { !$0.isWarmup }
        guard !nonWarmupSets.isEmpty else { return nil }

        let plannedDurationSeconds: Int? = {
            let total = nonWarmupSets.compactMap(\.targetDurationSeconds).reduce(0, +)
            return total > 0 ? total : nil
        }()
        let plannedRPE = nonWarmupSets.compactMap(\.targetRPE).max()
        let sessionType = prescribedWorkout.sessionType

        // The day qualifies when it has a duration OR it is simply not a strength day.
        guard plannedDurationSeconds != nil || sessionType != .strength else { return nil }

        // Cold start defers here exactly as it does on the lift path: no real decision input means
        // no honest cap, so the plan stands and the reason says so. Never trim on a guess.
        guard let decisionInput else {
            let deferReason = VerdictReasonBuilder.build(
                decisionInput: nil,
                crossModalResult: crossModalResult,
                plannedRegion: .fullBody,
                deferToPlan: true
            ).reasonLine
            for set in nonWarmupSets where set.verdictAppliedAt == nil && !set.athleteOverrode {
                set.adjustedTargetRPE = nil
                set.verdictReason = deferReason
            }
            return SessionCapEngine.SessionCap(
                maxRPE: plannedRPE.map { Int($0.rounded(.down)) },
                maxDurationSeconds: plannedDurationSeconds,
                loadBudgetAU: nil,
                shape: .asPlanned
            )
        }

        let cap = SessionCapEngine.evaluate(
            recommendation: decisionInput.recommendation,
            fatigueZone: fatigueZone,
            strainRiskZone: decisionInput.strainRisk.zone,
            matchDaysAway: matchDaysAway,
            plannedDurationSeconds: plannedDurationSeconds,
            plannedRPE: plannedRPE,
            sessionType: sessionType
        )

        // The reason line uses the SAME builder the lift path uses, so a capped run is explained
        // in the same voice as a trimmed squat. A taper leads with the match, as it does there.
        let matchContext: VerdictReasonBuilder.MatchContext? = {
            guard cap.shape == .taper, let daysAway = matchDaysAway,
                  let matchDate = nextMatchDate else { return nil }
            return VerdictReasonBuilder.MatchContext(daysAway: daysAway, matchDate: matchDate)
        }()
        let reason = VerdictReasonBuilder.build(
            decisionInput: decisionInput,
            crossModalResult: crossModalResult,
            plannedRegion: .fullBody,
            deferToPlan: false,
            matchContext: matchContext,
            calendar: calendar
        ).reasonLine

        for set in nonWarmupSets {
            // DECIDED sets stay frozen — the same rule the lift path keeps above.
            guard set.verdictAppliedAt == nil, !set.athleteOverrode else { continue }
            set.verdictReason = reason
            // NIL-RPE RULE: cap only where the plan wrote an RPE (downward only).
            if let plannedSetRPE = set.targetRPE, let maxRPE = cap.maxRPE {
                set.adjustedTargetRPE = Swift.min(plannedSetRPE, Double(maxRPE))
            } else {
                set.adjustedTargetRPE = nil
            }
        }

        return cap
    }
}
