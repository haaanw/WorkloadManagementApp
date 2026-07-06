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
/// Cross-modal passes straight through to the gate-guarded engines, which zero it out while
/// `CrossModalShadowGate.crossModalDrivesVerdict` is off (the shipped default). No special-casing here.
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

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.plannedSessionRepository = PlannedSessionRepository(modelContext: modelContext)
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
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> [TodayVerdictEngine.VerdictResult] {
        var results: [TodayVerdictEngine.VerdictResult] = []

        // Match proximity, computed ONCE (expired dates read as absent — the engine never mutates).
        let matchDaysAway = TodayVerdictEngine.matchDaysAway(
            nextMatchDate: nextMatchDate, asOf: asOf, calendar: calendar
        )
        let matchIsNear = TodayVerdictEngine.isMatchNear(daysAway: matchDaysAway)

        for exercise in prescribedWorkout.allExercises {
            // Select the TOP working set = the non-warmup TemplateSet with the max targetWeightKg.
            // Skip exercises with no working weight (leave their slots untouched).
            let working = exercise.sortedSets.filter { !$0.isWarmup && ($0.targetWeightKg ?? 0) > 0 }
            guard let top = working.max(by: { ($0.targetWeightKg ?? 0) < ($1.targetWeightKg ?? 0) }),
                  let plannedKg = top.targetWeightKg else { continue }

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
                        // Keep the microdose framing stable across a post-decision refresh: a frozen
                        // suggestion while the match is still near reads as proximity-shaped.
                        matchProximity: matchIsNear && frozenVerdict == .modify
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

        try? modelContext.save()
        return results
    }
}
