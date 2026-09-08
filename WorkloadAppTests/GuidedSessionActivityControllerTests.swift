import XCTest
@testable import workload_management

/// The lock-screen state builder (v1.7.3 feature 9 batch 2, tier 1).
///
/// The builder is pure and static, so the whole card is testable without ActivityKit, a simulator
/// or a running session. What is pinned here is the SHAPES the card can be in — current / next /
/// then / finish / complete — plus the two things a lock screen gets wrong silently: a stale rest
/// clock, and a bar so long its segments vanish.
final class GuidedSessionActivityControllerTests: XCTestCase {

    // MARK: - Fixtures

    private let start = Date(timeIntervalSince1970: 1_756_500_000)
    private let locale = Locale(identifier: "en_US")

    private func makeEntry(
        _ name: String,
        sets: Int,
        group: String? = nil,
        category: ExerciseCategory = .compound,
        weightKg: Double? = 100,
        reps: Int? = 5
    ) -> ExerciseEntryDraft {
        var entry = ExerciseEntryDraft(
            exerciseName: name,
            exerciseCategory: category,
            muscleGroup: nil
        )
        entry.groupName = group
        entry.sets = (0..<sets).map { _ in
            var set = SetDraft()
            set.targetWeightKg = weightKg
            set.targetReps = reps
            return set
        }
        return entry
    }

    private func build(
        _ entries: [ExerciseEntryDraft],
        priority: Int? = nil,
        unit: WeightUnit = .kg
    ) -> GuidedSessionActivityAttributes.ContentState {
        GuidedSessionActivityController.contentState(
            engine: GuidedSessionEngine(entries: entries, priorityEntryIndex: priority),
            entries: entries,
            weightUnit: unit,
            locale: locale,
            startedAt: start
        )
    }

    // MARK: - The current move

    func test_freshSession_showsFirstSetOfFirstMove() {
        let entries = [makeEntry("Back squat", sets: 3), makeEntry("Romanian deadlift", sets: 2)]
        let state = build(entries)

        XCTAssertEqual(state.moveName, "Back squat")
        XCTAssertEqual(state.moveTag, "1")
        XCTAssertEqual(state.movePosition, "1/2")
        XCTAssertEqual(state.targetLine, "100 kg × 5")
        XCTAssertEqual(state.setStates, [.current, .planned, .planned])
        XCTAssertEqual(state.sessionStates, [.current, .planned, .planned, .planned, .planned])
        XCTAssertEqual(state.startedAt, start)
        XCTAssertNil(state.lastLoggedAt, "Nothing is logged, so there is no rest to report")
        XCTAssertEqual(state.loggedCount, 0)
        XCTAssertEqual(state.setsLeft, 5)
        XCTAssertFalse(state.isComplete)
        XCTAssertEqual(state.schemaVersion, GuidedSessionActivityAttributes.ContentState.currentSchemaVersion)
    }

    func test_next_isTheFollowingMove_withItsWholePrescription() {
        let entries = [makeEntry("Back squat", sets: 3), makeEntry("Romanian deadlift", sets: 3, weightKg: 80, reps: 8)]
        let state = build(entries)

        XCTAssertEqual(state.nextKind, .next)
        XCTAssertEqual(state.nextMoveName, "Romanian deadlift")
        XCTAssertEqual(state.nextLine, "3 × 8 · 80 kg", "A fresh move states the whole prescription")
    }

    func test_then_isTheSupersetPartner_asOneSet() {
        // Two consecutive entries sharing a group alternate set by set, so what follows the
        // current set is the PARTNER — mid-flight, which makes one set the honest unit.
        let entries = [
            makeEntry("Bench press", sets: 3, group: "A"),
            makeEntry("Barbell row", sets: 3, group: "A", weightKg: 60, reps: 10),
            makeEntry("Plank", sets: 1)
        ]
        let state = build(entries)

        XCTAssertEqual(state.moveTag, "1A")
        XCTAssertEqual(state.nextKind, .then)
        XCTAssertEqual(state.nextMoveName, "Barbell row")
        XCTAssertEqual(state.nextLine, "Set 1 · 60 kg × 10")
    }

    func test_lastMove_hasNothingAfterIt() {
        var entries = [makeEntry("Back squat", sets: 2)]
        GuidedSessionEngine.log(&entries, slot: .init(entryIndex: 0, setIndex: 0), at: start)
        let state = build(entries)

        XCTAssertEqual(state.nextKind, .finish)
        XCTAssertNil(state.nextMoveName)
        XCTAssertNil(state.nextLine)
        XCTAssertFalse(state.isComplete, "One set still owed — the session is not over")
    }

    // MARK: - Set states

    func test_setStates_trackLoggedSkippedAndTheCursor() {
        var entries = [makeEntry("Back squat", sets: 4), makeEntry("Plank", sets: 1)]
        GuidedSessionEngine.log(&entries, slot: .init(entryIndex: 0, setIndex: 0), at: start)
        entries[0].sets[1].isSkipped = true
        let state = build(entries)

        XCTAssertEqual(state.setStates, [.logged, .skipped, .current, .planned])
        XCTAssertEqual(state.sessionStates, [.logged, .skipped, .current, .planned, .planned])
        XCTAssertEqual(state.loggedCount, 1)
        XCTAssertEqual(state.setsLeft, 3, "Skipped sets are settled — they are not still owed")
    }

    func test_lastLoggedAt_isTheNewestStamp_notTheLastInArrayOrder() {
        // The rest clock anchors on the most RECENT log. A jump, a reopen, or an out-of-order
        // superset means array order and time order are not the same thing.
        var entries = [makeEntry("Bench press", sets: 2, group: "A"), makeEntry("Barbell row", sets: 2, group: "A")]
        let older = start.addingTimeInterval(60)
        let newer = start.addingTimeInterval(240)
        GuidedSessionEngine.log(&entries, slot: .init(entryIndex: 1, setIndex: 0), at: newer)
        GuidedSessionEngine.log(&entries, slot: .init(entryIndex: 0, setIndex: 0), at: older)

        XCTAssertEqual(build(entries).lastLoggedAt, newer)
    }

    // MARK: - The bar

    func test_sessionBar_capsAtFortyKeepingTheTail() {
        let entries = [makeEntry("Back squat", sets: 60)]
        let state = build(entries)

        XCTAssertEqual(state.sessionStates.count, GuidedSessionActivityAttributes.ContentState.sessionBarCap)
        XCTAssertEqual(
            state.sessionStates.last, .planned,
            "The tail survives the cap — what is still owed is what the bar is for"
        )
    }

    // MARK: - Target lines

    func test_bodyweightMove_readsBW() {
        let entries = [makeEntry("Pull-up", sets: 3, category: .bodyweight, weightKg: nil, reps: 8)]
        XCTAssertEqual(build(entries).targetLine, "BW × 8")
    }

    func test_bodyweightMove_withAddedLoad_readsThePlus() {
        var entries = [makeEntry("Pull-up", sets: 3, category: .bodyweight, weightKg: 10, reps: 8)]
        entries[0].sets[0].targetWeightKg = 10
        XCTAssertEqual(build(entries).targetLine, "+10 kg × 8")
    }

    func test_targetLine_followsTheAthletesUnit() {
        let entries = [makeEntry("Back squat", sets: 1, weightKg: 100, reps: 5)]
        XCTAssertEqual(build(entries, unit: .lbs).targetLine, "220.5 lb × 5")
    }

    func test_targetLine_prefersTheEditedValueOverThePlan() {
        var entries = [makeEntry("Back squat", sets: 2, weightKg: 100, reps: 5)]
        entries[0].sets[0].weightKg = 132.5
        entries[0].sets[0].reps = 3
        XCTAssertEqual(build(entries).targetLine, "132.5 kg × 3")
    }

    // MARK: - Completion

    func test_completeSession_dropsTheMoveAndSaysSo() {
        var entries = [makeEntry("Back squat", sets: 2)]
        GuidedSessionEngine.log(&entries, slot: .init(entryIndex: 0, setIndex: 0), at: start)
        GuidedSessionEngine.log(&entries, slot: .init(entryIndex: 0, setIndex: 1), at: start.addingTimeInterval(120))
        let state = build(entries)

        XCTAssertTrue(state.isComplete)
        XCTAssertEqual(state.moveName, "")
        XCTAssertEqual(state.targetLine, "")
        XCTAssertEqual(state.setStates, [])
        XCTAssertEqual(state.nextKind, .finish)
        XCTAssertEqual(state.movePosition, "1/1")
        XCTAssertEqual(state.loggedCount, 2)
        XCTAssertEqual(state.setsLeft, 0)
        XCTAssertEqual(state.sessionStates, [.logged, .logged])
    }

    func test_finishedState_forcesTheSummaryFaceEvenWithSetsLeft() {
        // Finish is reachable at any moment. A card still saying "NEXT · Romanian deadlift" for a
        // session already in the history would describe work that will never happen.
        var entries = [makeEntry("Back squat", sets: 3), makeEntry("Romanian deadlift", sets: 3)]
        GuidedSessionEngine.log(&entries, slot: .init(entryIndex: 0, setIndex: 0), at: start)
        let live = build(entries)
        XCTAssertFalse(live.isComplete)
        XCTAssertEqual(live.nextKind, .next)

        let finished = GuidedSessionActivityController.finishedState(from: live)
        XCTAssertTrue(finished.isComplete)
        XCTAssertEqual(finished.setsLeft, 0)
        XCTAssertEqual(finished.nextKind, .finish)
        XCTAssertNil(finished.nextMoveName)
        XCTAssertNil(finished.nextLine)
        XCTAssertEqual(finished.moveName, "")
        XCTAssertEqual(finished.loggedCount, 1, "The count the summary reports is untouched")
        XCTAssertEqual(
            finished.sessionStates, live.sessionStates,
            "The bar keeps its planned segments — finishing with sets left is the honest picture"
        )
    }

    // MARK: - The jump

    func test_pairJump_movesTheCardToThePartner() {
        // The pair-cell tap pulls the partner forward for ONE set; the lock screen must show the
        // same move the plate does, which is why the priority index feeds the same engine.
        let entries = [
            makeEntry("Bench press", sets: 3, group: "A"),
            makeEntry("Barbell row", sets: 3, group: "A")
        ]
        XCTAssertEqual(build(entries).moveName, "Bench press")
        XCTAssertEqual(build(entries, priority: 1).moveName, "Barbell row")
    }

    // MARK: - Shared formatting

    func test_clock_countsMinutesPastTheHour() {
        // The rest clock never grows an hours field — it is a rest timer, not a duration report.
        XCTAssertEqual(GuidedSessionFormatting.clock(0), "0:00")
        XCTAssertEqual(GuidedSessionFormatting.clock(65), "1:05")
        XCTAssertEqual(GuidedSessionFormatting.clock(3_723), "62:03")
        XCTAssertEqual(GuidedSessionFormatting.clock(-10), "0:00", "A clock never runs backwards")
    }
}
