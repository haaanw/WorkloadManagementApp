import XCTest
import SwiftData
@testable import workload_management

/// v2.1 Basketball Beachhead — Track 1 item 4 (ADR-0002): the match-proximity rule in the TODAY
/// verdict + the microdose reason framing.
///
/// The fence under test: ONE date, ONE rule, NO trajectory math.
///  - Day-boundary semantics (documented at `TodayVerdictEngine.Constants.matchProximityDays`):
///    both sides start-of-day normalized; the rule engages on match day itself (0) and the 2
///    calendar days before (1, 2). 3+ days out = ZERO effect. Expired (strictly before today) or
///    nil = ZERO effect. Time-of-day never matters.
///  - Tighten = the MICRODOSE shape: cap the top set (existing bound logic, prefer the STRONGER
///    trim, −10% hard ceiling) and cut ALL back-off sets.
///  - Anti-nocebo: proximity can only move GO → MODIFY. It NEVER produces HOLD.
///  - Reason line LEADS with the match ("Match Saturday — microdose: …").
final class TodayVerdictMatchProximityEngineTests: XCTestCase {

    // MARK: - Fixtures

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// A fixed "now": Thursday 2026-07-09, 14:00 UTC.
    private var asOf: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 9, hour: 14))!
    }

    /// Start-of-day `days` calendar days after `asOf` (mirrors the Stage-1 start-of-day convention).
    private func matchDate(daysFromNow days: Int) -> Date {
        let day = calendar.date(byAdding: .day, value: days, to: asOf)!
        return calendar.startOfDay(for: day)
    }

    private func recommendation(
        cap: Double,
        vol: Double,
        type: AutoregulationEngine.TrainingRecommendation.RecommendedSessionType = .strength
    ) -> AutoregulationEngine.TrainingRecommendation {
        AutoregulationEngine.TrainingRecommendation(
            intensityCap: cap, volumeModifier: vol, sessionType: type,
            warnings: [], headline: "H", detail: "D"
        )
    }

    private func plannedTopSet(kg: Double = 100.0) -> TodayVerdictEngine.PlannedTopSet {
        TodayVerdictEngine.PlannedTopSet(
            exerciseName: "Back Squat", region: .legs,
            plannedTopSetKg: kg, plannedReps: 5, plannedRPE: 8.0
        )
    }

    private let plateStep = 2.5

    // MARK: - matchDaysAway helper (the ONE date read)

    func test_matchDaysAway_nilDate_isNil() {
        XCTAssertNil(TodayVerdictEngine.matchDaysAway(nextMatchDate: nil, asOf: asOf, calendar: calendar))
    }

    func test_matchDaysAway_expiredYesterday_isNil_treatedAsAbsent() {
        // Strictly before today ⇒ absent (mirrors Stage 1; the engine never mutates the model).
        let yesterday = matchDate(daysFromNow: -1)
        XCTAssertNil(TodayVerdictEngine.matchDaysAway(nextMatchDate: yesterday, asOf: asOf, calendar: calendar))
    }

    func test_matchDaysAway_todayTomorrowAndOut() {
        XCTAssertEqual(TodayVerdictEngine.matchDaysAway(nextMatchDate: matchDate(daysFromNow: 0), asOf: asOf, calendar: calendar), 0)
        XCTAssertEqual(TodayVerdictEngine.matchDaysAway(nextMatchDate: matchDate(daysFromNow: 1), asOf: asOf, calendar: calendar), 1)
        XCTAssertEqual(TodayVerdictEngine.matchDaysAway(nextMatchDate: matchDate(daysFromNow: 2), asOf: asOf, calendar: calendar), 2)
        XCTAssertEqual(TodayVerdictEngine.matchDaysAway(nextMatchDate: matchDate(daysFromNow: 3), asOf: asOf, calendar: calendar), 3)
    }

    func test_matchDaysAway_calendarDaySemantics_timeOfDayNeverMatters() {
        // 23:30 Thursday evening, match Saturday 00:00 (< 48 clock-hours OR > — irrelevant):
        // calendar-day distance is 2 either way. Both sides are start-of-day normalized.
        let lateEvening = calendar.date(from: DateComponents(year: 2026, month: 7, day: 9, hour: 23, minute: 30))!
        let earlyMorning = calendar.date(from: DateComponents(year: 2026, month: 7, day: 9, hour: 0, minute: 5))!
        let saturday = matchDate(daysFromNow: 2)
        XCTAssertEqual(TodayVerdictEngine.matchDaysAway(nextMatchDate: saturday, asOf: lateEvening, calendar: calendar), 2)
        XCTAssertEqual(TodayVerdictEngine.matchDaysAway(nextMatchDate: saturday, asOf: earlyMorning, calendar: calendar), 2)
    }

    func test_isMatchNear_boundaries() {
        XCTAssertFalse(TodayVerdictEngine.isMatchNear(daysAway: nil))
        XCTAssertTrue(TodayVerdictEngine.isMatchNear(daysAway: 0))
        XCTAssertTrue(TodayVerdictEngine.isMatchNear(daysAway: 1))
        XCTAssertTrue(TodayVerdictEngine.isMatchNear(daysAway: 2))
        XCTAssertFalse(TodayVerdictEngine.isMatchNear(daysAway: 3))   // the exact boundary
    }

    // MARK: - No-effect regressions (nil / expired / far ⇒ EXACTLY unchanged)

    func test_matchIn3Days_hasZeroEffect_identicalToNoMatch() {
        for (cap, vol, type) in [
            (9.0, 1.0, AutoregulationEngine.TrainingRecommendation.RecommendedSessionType.strength),
            (8.0, 0.90, .hypertrophy),
            (6.0, 0.6, .conditioning)
        ] {
            let rec = recommendation(cap: cap, vol: vol, type: type)
            let baseline = TodayVerdictEngine.evaluate(
                recommendation: rec, plannedTopSet: plannedTopSet(),
                crossModalResult: nil, plateStepKg: plateStep
            )
            let withFarMatch = TodayVerdictEngine.evaluate(
                recommendation: rec, plannedTopSet: plannedTopSet(),
                crossModalResult: nil, plateStepKg: plateStep,
                matchDaysAway: 3, plannedWorkingSetCount: 3
            )
            XCTAssertEqual(withFarMatch, baseline, "match 3 days out must change nothing (vol \(vol))")
            XCTAssertFalse(withFarMatch.matchProximity)
        }
    }

    func test_nilMatchDaysAway_identicalToLegacyCall() {
        let rec = recommendation(cap: 6.0, vol: 0.6, type: .conditioning)
        let legacy = TodayVerdictEngine.evaluate(
            recommendation: rec, plannedTopSet: plannedTopSet(),
            crossModalResult: nil, plateStepKg: plateStep
        )
        let explicitNil = TodayVerdictEngine.evaluate(
            recommendation: rec, plannedTopSet: plannedTopSet(),
            crossModalResult: nil, plateStepKg: plateStep,
            matchDaysAway: nil, plannedWorkingSetCount: 3
        )
        XCTAssertEqual(explicitNil, legacy)
    }

    func test_expiredDate_flowsToNil_andChangesNothing() {
        let expired = TodayVerdictEngine.matchDaysAway(
            nextMatchDate: matchDate(daysFromNow: -2), asOf: asOf, calendar: calendar
        )
        XCTAssertNil(expired)
        let rec = recommendation(cap: 9.0, vol: 1.0)
        let result = TodayVerdictEngine.evaluate(
            recommendation: rec, plannedTopSet: plannedTopSet(),
            crossModalResult: nil, plateStepKg: plateStep,
            matchDaysAway: expired, plannedWorkingSetCount: 3
        )
        XCTAssertEqual(result.verdict, .go)
        XCTAssertEqual(result.adjustedTopSetKg, 100, accuracy: 1e-9)
        XCTAssertFalse(result.matchProximity)
    }

    // MARK: - The tighten (0 / 1 / 2 days ⇒ GO → MODIFY microdose)

    func test_matchNear_goBecomesModify_microdoseShape_allThreeDays() {
        let rec = recommendation(cap: 9.0, vol: 1.0, type: .strength)   // GO as-written
        for daysAway in [0, 1, 2] {
            let result = TodayVerdictEngine.evaluate(
                recommendation: rec, plannedTopSet: plannedTopSet(kg: 100),
                crossModalResult: nil, plateStepKg: plateStep,
                matchDaysAway: daysAway, plannedWorkingSetCount: 3
            )
            XCTAssertEqual(result.verdict, .modify, "day \(daysAway): GO must tighten to MODIFY")
            XCTAssertTrue(result.matchProximity, "day \(daysAway)")
            // Cap the top set: the default −5% trim (100 → 95, an exact plate multiple).
            XCTAssertEqual(result.adjustedTopSetKg, 95, accuracy: 1e-9, "day \(daysAway)")
            XCTAssertEqual(result.loadFactor, 0.95, accuracy: 1e-9, "day \(daysAway)")
            // Cut ALL back-offs: 3 working sets ⇒ keep the top set, cut 2.
            XCTAssertEqual(result.volumeCutSets, 2, "day \(daysAway)")
        }
    }

    func test_matchNear_prefersStrongerTrim_neverBelowCeiling() {
        // vol 0.6 ⇒ the recommendation already implies a trim deeper than −5%; the microdose keeps
        // the STRONGER trim (never loosens), still hard-capped at −10%.
        let rec = recommendation(cap: 6.0, vol: 0.6, type: .conditioning)
        let baseline = TodayVerdictEngine.evaluate(
            recommendation: rec, plannedTopSet: plannedTopSet(kg: 100),
            crossModalResult: nil, plateStepKg: plateStep
        )
        let near = TodayVerdictEngine.evaluate(
            recommendation: rec, plannedTopSet: plannedTopSet(kg: 100),
            crossModalResult: nil, plateStepKg: plateStep,
            matchDaysAway: 1, plannedWorkingSetCount: 3
        )
        XCTAssertEqual(near.verdict, .modify)
        XCTAssertTrue(near.matchProximity)
        XCTAssertLessThanOrEqual(near.loadFactor, baseline.loadFactor + 1e-9)      // never looser
        XCTAssertLessThanOrEqual(near.loadFactor, 1.0 - 0.05 + 1e-9)               // at least −5%
        XCTAssertGreaterThanOrEqual(near.adjustedTopSetKg, 100 * 0.90 - 1e-9)      // −10% ceiling holds
        XCTAssertEqual(near.volumeCutSets, 2)                                       // back-offs cut
    }

    func test_matchNear_volumeCutBranch_alsoCapsTopSet_andCutsAllBackoffs() {
        // vol 0.90 (volume-cut-preferred branch, loadFactor 1.0 without proximity) — near a match
        // the top set is capped too and the cut covers ALL back-offs.
        let rec = recommendation(cap: 8.0, vol: 0.90, type: .hypertrophy)
        let result = TodayVerdictEngine.evaluate(
            recommendation: rec, plannedTopSet: plannedTopSet(kg: 100),
            crossModalResult: nil, plateStepKg: plateStep,
            matchDaysAway: 2, plannedWorkingSetCount: 4
        )
        XCTAssertEqual(result.verdict, .modify)
        XCTAssertTrue(result.matchProximity)
        XCTAssertEqual(result.adjustedTopSetKg, 95, accuracy: 1e-9)
        XCTAssertEqual(result.volumeCutSets, 3)   // 4 working sets ⇒ cut all 3 back-offs
    }

    // MARK: - Anti-nocebo (proximity NEVER produces HOLD)

    func test_matchNear_neverProducesHold_acrossRecommendations() {
        for vol in [1.0, 0.95, 0.90, 0.85, 0.6, 0.3] {
            let rec = recommendation(cap: 7.0, vol: vol, type: .strength)
            let result = TodayVerdictEngine.evaluate(
                recommendation: rec, plannedTopSet: plannedTopSet(),
                crossModalResult: nil, plateStepKg: plateStep,
                matchDaysAway: 0, plannedWorkingSetCount: 3
            )
            XCTAssertNotEqual(result.verdict, .hold, "proximity must never gate (vol \(vol))")
        }
    }

    func test_restRecommendation_holdStaysHold_untouchedByProximity() {
        // An underlying rest/active-recovery HOLD is NOT proximity's doing and stays exactly as-is
        // (planned number carried, no cut) — proximity neither creates nor reshapes HOLD.
        let rec = recommendation(cap: 5.0, vol: 0.0, type: .rest)
        let result = TodayVerdictEngine.evaluate(
            recommendation: rec, plannedTopSet: plannedTopSet(kg: 100),
            crossModalResult: nil, plateStepKg: plateStep,
            matchDaysAway: 1, plannedWorkingSetCount: 3
        )
        XCTAssertEqual(result.verdict, .hold)
        XCTAssertEqual(result.adjustedTopSetKg, 100, accuracy: 1e-9)
        XCTAssertNil(result.volumeCutSets)
        XCTAssertFalse(result.matchProximity)
    }

    // MARK: - Degenerate honesty (nothing to change ⇒ GO, no false precision)

    func test_matchNear_singleWorkingSet_subIncrementTrim_collapsesToGo() {
        // One working set (no back-offs to cut) + a sub-plate-step −5% (20kg → 19, delta 1 < 2.5):
        // the "microdose" would change literally nothing, so the honest verdict stays GO.
        let rec = recommendation(cap: 9.0, vol: 1.0, type: .strength)
        let result = TodayVerdictEngine.evaluate(
            recommendation: rec, plannedTopSet: plannedTopSet(kg: 20),
            crossModalResult: nil, plateStepKg: plateStep,
            matchDaysAway: 0, plannedWorkingSetCount: 1
        )
        XCTAssertEqual(result.verdict, .go)
        XCTAssertEqual(result.adjustedTopSetKg, 20, accuracy: 1e-9)
        XCTAssertFalse(result.matchProximity)
    }
}

// MARK: - Reason framing (item 4 copy + item 5 vocabulary source)

/// The microdose reason line LEADS with the match, using the athlete's actual relative day /
/// match-day name. Without a `MatchContext`, the builder's behavior is exactly unchanged.
final class VerdictReasonMatchFramingTests: XCTestCase {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// Saturday 2026-07-11 (start-of-day UTC).
    private var saturdayMatch: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 11))!
    }

    private func decisionInput() -> ReasoningEngine.DecisionInput {
        let readiness = ReadinessFusionEngine.compute(
            .init(hrvZ: -1.8, rhrZ: -0.4, sleepZ: -0.9, confidence: 0.7)
        )
        let strain = StrainRiskEngine.StrainRiskResult(
            score: 0.4, zone: StrainRiskEngine.zone(for: 0.4),
            factors: [.init(label: "Per-muscle strength-load elevation", contribution: 0.18)],
            confidence: 0.6
        )
        let rec = AutoregulationEngine.TrainingRecommendation(
            intensityCap: 7, volumeModifier: 0.6, sessionType: .conditioning,
            warnings: [], headline: "Stay Controlled", detail: "..."
        )
        return ReasoningEngine.DecisionInput(readiness: readiness, strainRisk: strain, recommendation: rec)
    }

    private func build(daysAway: Int?, matchDate: Date? = nil) -> VerdictReasonBuilder.AssembledReason {
        let context: VerdictReasonBuilder.MatchContext? = daysAway.map {
            VerdictReasonBuilder.MatchContext(daysAway: $0, matchDate: matchDate ?? saturdayMatch)
        }
        return VerdictReasonBuilder.build(
            decisionInput: decisionInput(),
            crossModalResult: nil,
            plannedRegion: .legs,
            deferToPlan: false,
            matchContext: context,
            locale: Locale(identifier: "en_US"),
            calendar: calendar
        )
    }

    func test_matchToday_leadsWithMatch_microdoseCopy() {
        let reason = build(daysAway: 0)
        XCTAssertTrue(reason.reasonLine.hasPrefix("Match today"), reason.reasonLine)
        XCTAssertTrue(reason.reasonLine.lowercased().contains("microdose"))
        XCTAssertFalse(reason.reasonLine.contains("\n"))   // single-line guarantee holds
    }

    func test_matchTomorrow_leadsWithMatch() {
        let reason = build(daysAway: 1)
        XCTAssertTrue(reason.reasonLine.hasPrefix("Match tomorrow"), reason.reasonLine)
        XCTAssertTrue(reason.reasonLine.lowercased().contains("microdose"))
    }

    func test_matchInTwoDays_namesTheActualMatchDay() {
        // 2026-07-11 is a Saturday — the line names the day, not a countdown.
        let reason = build(daysAway: 2, matchDate: saturdayMatch)
        XCTAssertTrue(reason.reasonLine.hasPrefix("Match Saturday"), reason.reasonLine)
        XCTAssertTrue(reason.reasonLine.lowercased().contains("microdose"))
    }

    func test_noMatchContext_behaviorExactlyUnchanged() {
        let reason = build(daysAway: nil)
        XCTAssertFalse(reason.reasonLine.lowercased().contains("microdose"))
        XCTAssertFalse(reason.reasonLine.lowercased().contains("match"))
        // The existing physiology headline still leads (HRV is the top-ranked driver here).
        XCTAssertTrue(reason.reasonLine.contains("Heart Rate Variability"), reason.reasonLine)
    }

    func test_confidence_staysSeparate_underMatchFraming() {
        let reason = build(daysAway: 0)
        XCTAssertFalse(reason.reasonLine.contains("0.7"))
        XCTAssertEqual(reason.confidence, decisionInput().readiness.confidence, accuracy: 1e-9)
    }
}

// MARK: - Service integration (slots + reason writes, end to end)

/// `TodayVerdictService.evaluateAndWrite` with a `nextMatchDate`: near ⇒ microdose slots + the
/// match-led reason (no redundant back-off clause); nil/far ⇒ byte-identical to before; cold-start
/// near a match ⇒ still the honest defer (never trim on a guess).
@MainActor
final class TodayVerdictServiceMatchProximityTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var service: TodayVerdictService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([
            Athlete.self, WorkoutSession.self, ExerciseEntry.self, SetRecord.self,
            WorkloadSnapshot.self, RecoverySnapshot.self, MenstrualCycleSnapshot.self,
            CyclePredictionLog.self, ShadowArmPrediction.self, SorenessLog.self,
            BaselineState.self,
            WellnessCheckIn.self, PersonalRecord.self, CoachAthleteRelationship.self,
            WorkoutTemplate.self, ExerciseGroup.self, TemplateExercise.self, TemplateSet.self,
            PrescribedWorkout.self, CustomExercise.self, BehaviorTag.self, TrainingProfile.self
        ])
        container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        service = TodayVerdictService(modelContext: context)
    }

    override func tearDown() {
        service = nil
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private var asOf: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 9, hour: 14))!
    }

    private func matchDate(daysFromNow days: Int) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: days, to: asOf)!)
    }

    /// One `.legs` exercise: a 100kg top set + a 90kg back-off (2 working sets).
    private func makePrescription(topWeightKg: Double = 100) -> PrescribedWorkout {
        let athleteId = UUID()
        let workout = PrescribedWorkout(
            coachId: athleteId, athleteId: athleteId, templateId: UUID(),
            scheduledDate: asOf, templateName: "Leg Day"
        )
        let group = ExerciseGroup(groupName: "Group A", orderIndex: 0)
        let squat = TemplateExercise(exerciseName: "Back Squat", muscleGroup: .legs, orderIndex: 0)
        squat.sets = [
            TemplateSet(setIndex: 0, targetReps: 5, targetWeightKg: topWeightKg, targetRPE: 8, isWarmup: false),
            TemplateSet(setIndex: 1, targetReps: 5, targetWeightKg: topWeightKg - 10, targetRPE: 8, isWarmup: false)
        ]
        group.exercises = [squat]
        workout.groups = [group]
        context.insert(workout)
        try? context.save()
        return workout
    }

    private func topSet(of workout: PrescribedWorkout) -> TemplateSet {
        workout.allExercises[0].sortedSets.max { ($0.targetWeightKg ?? 0) < ($1.targetWeightKg ?? 0) }!
    }

    /// A GO-as-written decision input (neutral readiness, full-volume recommendation).
    private func goDecisionInput() -> ReasoningEngine.DecisionInput {
        let readiness = ReadinessFusionEngine.compute(.init(hrvZ: 0, rhrZ: 0, sleepZ: 0, confidence: 0.8))
        let strain = StrainRiskEngine.StrainRiskResult(
            score: 0.1, zone: StrainRiskEngine.zone(for: 0.1), factors: [], confidence: 0.7
        )
        let rec = AutoregulationEngine.TrainingRecommendation(
            intensityCap: 9, volumeModifier: 1.0, sessionType: .strength,
            warnings: [], headline: "Full Send", detail: "..."
        )
        return ReasoningEngine.DecisionInput(readiness: readiness, strainRisk: strain, recommendation: rec)
    }

    // MARK: - Tests

    func test_nearMatch_writesMicrodoseSlots_andMatchLedReason() {
        let workout = makePrescription()
        let results = service.evaluateAndWrite(
            prescribedWorkout: workout,
            decisionInput: goDecisionInput(),
            crossModalResult: nil,
            plateStepKg: 2.5,
            nextMatchDate: matchDate(daysFromNow: 1),
            asOf: asOf,
            calendar: calendar
        )
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].verdict, .modify)
        XCTAssertTrue(results[0].matchProximity)

        let top = topSet(of: workout)
        XCTAssertEqual(top.adjustedTargetWeightKg ?? 0, 95, accuracy: 1e-9)   // 100 → −5% cap
        XCTAssertEqual(top.adjustedBackoffSetCut, 1)                          // 2 working sets ⇒ cut 1
        let reason = top.verdictReason ?? ""
        XCTAssertTrue(reason.hasPrefix("Match tomorrow"), reason)             // the match LEADS
        XCTAssertTrue(reason.lowercased().contains("microdose"), reason)
        // No redundant back-off clause — the microdose copy already says "skip back-offs".
        XCTAssertFalse(reason.contains("consider dropping"), reason)
    }

    func test_nilAndFarMatch_identicalToExistingBehavior() {
        let baselineWorkout = makePrescription()
        _ = service.evaluateAndWrite(
            prescribedWorkout: baselineWorkout, decisionInput: goDecisionInput(),
            crossModalResult: nil, plateStepKg: 2.5
        )
        let farWorkout = makePrescription()
        _ = service.evaluateAndWrite(
            prescribedWorkout: farWorkout, decisionInput: goDecisionInput(),
            crossModalResult: nil, plateStepKg: 2.5,
            nextMatchDate: matchDate(daysFromNow: 5), asOf: asOf, calendar: calendar
        )
        let base = topSet(of: baselineWorkout)
        let far = topSet(of: farWorkout)
        XCTAssertEqual(far.adjustedTargetWeightKg, base.adjustedTargetWeightKg)
        XCTAssertEqual(far.adjustedBackoffSetCut, base.adjustedBackoffSetCut)
        XCTAssertEqual(far.verdictReason, base.verdictReason)
    }

    func test_expiredMatch_identicalToNil() {
        let workout = makePrescription()
        let results = service.evaluateAndWrite(
            prescribedWorkout: workout, decisionInput: goDecisionInput(),
            crossModalResult: nil, plateStepKg: 2.5,
            nextMatchDate: matchDate(daysFromNow: -1), asOf: asOf, calendar: calendar
        )
        XCTAssertEqual(results[0].verdict, .go)
        XCTAssertFalse(results[0].matchProximity)
        XCTAssertFalse((topSet(of: workout).verdictReason ?? "").lowercased().contains("microdose"))
    }

    func test_coldStart_nearMatch_stillDefers_neverTrimsOnAGuess() {
        let workout = makePrescription()
        let results = service.evaluateAndWrite(
            prescribedWorkout: workout,
            decisionInput: nil,                                   // cold-start
            crossModalResult: nil,
            plateStepKg: 2.5,
            nextMatchDate: matchDate(daysFromNow: 0), asOf: asOf, calendar: calendar
        )
        XCTAssertEqual(results[0].verdict, .go)
        XCTAssertFalse(results[0].matchProximity)
        let top = topSet(of: workout)
        XCTAssertEqual(top.adjustedTargetWeightKg ?? 0, 100, accuracy: 1e-9)  // suggestion == plan
        XCTAssertNil(top.adjustedBackoffSetCut)
        XCTAssertFalse((top.verdictReason ?? "").lowercased().contains("microdose"))
    }
}
