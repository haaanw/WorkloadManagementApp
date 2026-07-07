import XCTest
import SwiftData
@testable import workload_management

/// v2.1 Track 1 item 6 — `FeltRightPromptEngine` next-day eligibility + dogfood criteria math.
///
/// Pure over `[VerdictEvent]` with an INJECTED `asOf` + `calendar` (no baked `.now`). VerdictEvent
/// is a `@Model` but is constructed standalone here (no container needed) since the engine only
/// reads its composite fields — mirrors `GreenLightEngineTests`.
final class FeltRightPromptEngineTests: XCTestCase {

    private let cal = Calendar.current

    /// Build a standalone composite event. `dayOffset` is days before `base` for planDate;
    /// decidedAt is that day + `hour` (deterministic intra-day stamp).
    private func event(
        base: Date,
        dayOffset: Int,
        differed: Bool = true,
        action: String = "accepted",
        feltRight: String? = nil,
        matchProximity: Bool? = nil,
        hour: Int = 10
    ) -> VerdictEvent {
        let planDay = cal.date(byAdding: .day, value: -dayOffset, to: base)!
        let decidedAt = cal.date(byAdding: .hour, value: hour, to: cal.startOfDay(for: planDay))!
        return VerdictEvent(
            decidedAt: decidedAt,
            planDate: planDay,
            verdictKindRaw: differed ? "modify" : "go",
            plannedTopSetKg: 100,
            adjustedTopSetKg: differed ? 95 : nil,
            deltaKg: differed ? -5 : 0,
            differed: differed,
            actionRaw: action,
            regionRaw: "legs",
            reasonLine: "x",
            feltRightRaw: feltRight,
            matchProximityRaw: matchProximity
        )
    }

    // MARK: - Eligibility: next calendar day ONLY

    func test_eligible_onNextCalendarDay_afterDifferingDay() {
        let today = cal.startOfDay(for: .now)
        let yesterdays = event(base: today, dayOffset: 1)
        let hit = FeltRightPromptEngine.eligibleEvent(events: [yesterdays], asOf: today, calendar: cal)
        XCTAssertNotNil(hit, "a differing-verdict day is promptable exactly one calendar day later")
        XCTAssertEqual(hit?.id, yesterdays.id)
    }

    func test_notEligible_onSameDay() {
        let today = cal.startOfDay(for: .now)
        let todays = event(base: today, dayOffset: 0)
        XCTAssertNil(
            FeltRightPromptEngine.eligibleEvent(events: [todays], asOf: today, calendar: cal),
            "same-day is too early to judge — criterion 3 is judged next-day"
        )
    }

    func test_notEligible_twoOrMoreDaysLater_noBackfill() {
        let today = cal.startOfDay(for: .now)
        let twoDaysAgo = event(base: today, dayOffset: 2)
        let fiveDaysAgo = event(base: today, dayOffset: 5)
        XCTAssertNil(
            FeltRightPromptEngine.eligibleEvent(events: [twoDaysAgo, fiveDaysAgo], asOf: today, calendar: cal),
            "a missed day records as absent — never retro-rated"
        )
    }

    func test_notEligible_whenYesterdayDidNotDiffer() {
        let today = cal.startOfDay(for: .now)
        let nonDiffering = event(base: today, dayOffset: 1, differed: false)
        XCTAssertNil(
            FeltRightPromptEngine.eligibleEvent(events: [nonDiffering], asOf: today, calendar: cal),
            "only differing-verdict days are judged"
        )
        XCTAssertNil(FeltRightPromptEngine.eligibleEvent(events: [], asOf: today, calendar: cal))
    }

    func test_notEligible_whenAlreadyAnswered_immutable() {
        let today = cal.startOfDay(for: .now)
        let answered = event(base: today, dayOffset: 1, feltRight: "right")
        XCTAssertNil(
            FeltRightPromptEngine.eligibleEvent(events: [answered], asOf: today, calendar: cal),
            "an answered day never re-prompts — the response is recorded once"
        )
    }

    func test_eligibility_promptedRegardlessOfFollowed() {
        // Criterion definition: verdict differed from plan, REGARDLESS of whether followed.
        let today = cal.startOfDay(for: .now)
        let keptPlan = event(base: today, dayOffset: 1, action: "keptPlan")
        let hit = FeltRightPromptEngine.eligibleEvent(events: [keptPlan], asOf: today, calendar: cal)
        XCTAssertEqual(hit?.id, keptPlan.id, "kept-plan differing days are still judged next-day")
    }

    func test_representative_isLatestDecisionOfYesterday() {
        let today = cal.startOfDay(for: .now)
        let morning = event(base: today, dayOffset: 1, hour: 9)
        let evening = event(base: today, dayOffset: 1, hour: 20)
        let hit = FeltRightPromptEngine.eligibleEvent(events: [morning, evening], asOf: today, calendar: cal)
        XCTAssertEqual(hit?.id, evening.id, "multiple decisions collapse to the day's latest")
    }

    // MARK: - Dogfood criteria aggregates

    func test_summary_differingDays_collapseAndCount() {
        let today = cal.startOfDay(for: .now)
        let events = [
            event(base: today, dayOffset: 4),
            event(base: today, dayOffset: 4, hour: 20),          // same day ⇒ collapses
            event(base: today, dayOffset: 3, differed: false),   // excluded
            event(base: today, dayOffset: 2)
        ]
        let s = FeltRightPromptEngine.summary(events: events, asOf: today, calendar: cal)
        XCTAssertEqual(s.differingDays, 2)
    }

    func test_summary_followedRate_overDifferingDays() {
        let today = cal.startOfDay(for: .now)
        let events = [
            event(base: today, dayOffset: 4, action: "accepted"),
            event(base: today, dayOffset: 3, action: "keptPlan"),
            event(base: today, dayOffset: 2, action: "feelRough"),
            event(base: today, dayOffset: 1, action: "accepted")
        ]
        let s = FeltRightPromptEngine.summary(events: events, asOf: today, calendar: cal)
        XCTAssertEqual(s.differingDays, 4)
        XCTAssertEqual(s.followedDays, 3, "acted = action ≠ keptPlan")
        XCTAssertEqual(s.followedRate ?? -1, 0.75, accuracy: 0.0001)
    }

    func test_summary_followedRate_nilWhenNoDifferingDays() {
        let today = cal.startOfDay(for: .now)
        let s = FeltRightPromptEngine.summary(events: [], asOf: today, calendar: cal)
        XCTAssertEqual(s.differingDays, 0)
        XCTAssertNil(s.followedRate, "no differing day ⇒ honest nil, not 0")
        XCTAssertNil(s.feltRightRate)
    }

    func test_summary_feltRightRate_overRatedFollowedDays_unsureCountsAgainst() {
        let today = cal.startOfDay(for: .now)
        let events = [
            event(base: today, dayOffset: 5, action: "accepted", feltRight: "right"),
            event(base: today, dayOffset: 4, action: "accepted", feltRight: "unsure"),
            event(base: today, dayOffset: 3, action: "accepted", feltRight: "right"),
            event(base: today, dayOffset: 2, action: "keptPlan", feltRight: "wrong")  // not followed ⇒ excluded
        ]
        let s = FeltRightPromptEngine.summary(events: events, asOf: today, calendar: cal)
        XCTAssertEqual(s.ratedDays, 3, "kept-plan days are outside criterion 3's denominator")
        XCTAssertEqual(s.feltRightRate ?? -1, 2.0 / 3.0, accuracy: 0.0001, "unsure is not a pass")
    }

    func test_summary_feltRightRate_nilWhenNothingRatedYet() {
        let today = cal.startOfDay(for: .now)
        let unrated = event(base: today, dayOffset: 2, action: "accepted")
        let s = FeltRightPromptEngine.summary(events: [unrated], asOf: today, calendar: cal)
        XCTAssertEqual(s.ratedDays, 0)
        XCTAssertNil(s.feltRightRate, "no ratings ⇒ honest nil, not 0 or 100")
    }

    func test_summary_missedDays_onlyAfterWindowPassed() {
        let today = cal.startOfDay(for: .now)
        let events = [
            event(base: today, dayOffset: 3, action: "accepted"),                     // window passed, unanswered ⇒ missed
            event(base: today, dayOffset: 2, action: "accepted", feltRight: "right"), // answered ⇒ not missed
            event(base: today, dayOffset: 1, action: "accepted")                      // still promptable today ⇒ not missed
        ]
        let s = FeltRightPromptEngine.summary(events: events, asOf: today, calendar: cal)
        XCTAssertEqual(s.missedDays, 1, "only a fully-passed, unanswered next-day window is a miss")
        XCTAssertEqual(s.ratedDays, 1)
    }

    // MARK: - Criterion 4: proximity microdose count

    func test_summary_proximityMicrodoseDays_countsCollapsedDays_andFollowed() {
        let today = cal.startOfDay(for: .now)
        let events = [
            event(base: today, dayOffset: 5, action: "accepted", matchProximity: true),
            event(base: today, dayOffset: 5, action: "accepted", matchProximity: true, hour: 20), // same day ⇒ collapses
            event(base: today, dayOffset: 3, action: "keptPlan", matchProximity: true),           // counted, but not followed
            event(base: today, dayOffset: 2, action: "accepted", matchProximity: false),          // plain modify ⇒ excluded
            event(base: today, dayOffset: 1, action: "accepted")                                  // nil (pre-v2.1) ⇒ excluded
        ]
        let s = FeltRightPromptEngine.summary(events: events, asOf: today, calendar: cal)
        XCTAssertEqual(s.proximityMicrodoseDays, 2, "criterion 4 counts distinct proximity-microdose days")
        XCTAssertEqual(s.proximityMicrodoseFollowedDays, 1, "kept-plan microdose days aren't followed")
    }

    func test_summary_proximityMicrodoseDays_nilFlag_neverFabricated() {
        // Pre-v2.1 rows (nil) honestly read as not-proximity — the count starts at 0, not a guess.
        let today = cal.startOfDay(for: .now)
        let events = [
            event(base: today, dayOffset: 2, action: "accepted"),
            event(base: today, dayOffset: 1, action: "accepted")
        ]
        let s = FeltRightPromptEngine.summary(events: events, asOf: today, calendar: cal)
        XCTAssertEqual(s.proximityMicrodoseDays, 0)
        XCTAssertEqual(s.proximityMicrodoseFollowedDays, 0)
    }

    func test_summary_proximityDay_representativeIsLatestDecision() {
        // Day-collapse uses the SAME representative rule (latest decision of the day): a morning
        // microdose superseded by an evening plain-modify decision is NOT a proximity day.
        let today = cal.startOfDay(for: .now)
        let events = [
            event(base: today, dayOffset: 1, action: "accepted", matchProximity: true, hour: 9),
            event(base: today, dayOffset: 1, action: "accepted", matchProximity: false, hour: 20)
        ]
        let s = FeltRightPromptEngine.summary(events: events, asOf: today, calendar: cal)
        XCTAssertEqual(s.proximityMicrodoseDays, 0, "the day's latest decision carries the day")
    }
}

/// v2.1 Track 1 item 6 — `VerdictEventRepository.recordFeltRight` write-once contract + outcome
/// mirroring.
///
/// IMPORTANT (toolchain note, mirrors `VerdictEventRepositoryTests`): the `@MainActor` repository
/// and its `ModelContext` are released in a plain, non-throwing `tearDown()` — NOT
/// `tearDownWithError()` — to dodge the iOS 26.1 simulator libswift_Concurrency back-deploy deinit
/// SIGABRT.
@MainActor
final class FeltRightRepositoryTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var repo: VerdictEventRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([
            Athlete.self, WorkoutSession.self, ExerciseEntry.self, SetRecord.self,
            WorkloadSnapshot.self, RecoverySnapshot.self, MenstrualCycleSnapshot.self,
            CyclePredictionLog.self, ShadowArmPrediction.self, SorenessLog.self,
            BaselineState.self, WellnessCheckIn.self, PersonalRecord.self,
            CoachAthleteRelationship.self, WorkoutTemplate.self, ExerciseGroup.self,
            TemplateExercise.self, TemplateSet.self, PrescribedWorkout.self,
            CustomExercise.self, BehaviorTag.self, TrainingProfile.self,
            VerdictEvent.self
        ])
        container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        repo = VerdictEventRepository(modelContext: context)
    }

    override func tearDown() {
        repo = nil
        context = nil
        container = nil
        super.tearDown()
    }

    private func loggedEvent() -> VerdictEvent {
        repo.log(
            decidedAt: .now, planDate: .now, verdictKindRaw: "modify",
            plannedTopSetKg: 100, adjustedTopSetKg: 95, deltaKg: -5, differed: true,
            actionRaw: "accepted", regionRaw: MuscleRegion.legs.rawValue,
            reasonLine: "Backed off a touch.", confidenceNote: nil, athlete: nil
        )
    }

    func test_recordFeltRight_setsFields_andMirrorsEmptyOutcome() {
        let event = loggedEvent()
        XCTAssertNil(event.feltRightRaw)
        let stamp = Date()
        let recorded = repo.recordFeltRight("right", for: event, at: stamp)
        XCTAssertTrue(recorded)
        XCTAssertEqual(event.feltRightRaw, "right")
        XCTAssertEqual(event.feltRightRecordedAt, stamp)
        XCTAssertEqual(event.outcomeRaw, "right", "empty Phase 45 outcome is mirrored (one vocabulary)")
        XCTAssertEqual(event.outcomeRecordedAt, stamp)
    }

    func test_recordFeltRight_isWriteOnce_immutable() {
        let event = loggedEvent()
        let first = Date()
        XCTAssertTrue(repo.recordFeltRight("wrong", for: event, at: first))
        let second = repo.recordFeltRight("right", for: event, at: first.addingTimeInterval(60))
        XCTAssertFalse(second, "a second answer is refused")
        XCTAssertEqual(event.feltRightRaw, "wrong", "the first answer stands")
        XCTAssertEqual(event.feltRightRecordedAt, first)
    }

    func test_recordFeltRight_neverOverwritesExistingOutcome() {
        let event = loggedEvent()
        let earlier = Date().addingTimeInterval(-3600)
        repo.recordOutcome("unsure", for: event, at: earlier)
        repo.recordFeltRight("right", for: event, at: .now)
        XCTAssertEqual(event.feltRightRaw, "right")
        XCTAssertEqual(event.outcomeRaw, "unsure", "an already-recorded outcome is left untouched")
        XCTAssertEqual(event.outcomeRecordedAt, earlier)
    }
}
