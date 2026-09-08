import XCTest
@testable import workload_management

/// Guided session mode's queue (v1.7.3 feature 9).
///
/// The engine is the whole reason the mode can claim "one move at a time" — if the queue is
/// wrong the athlete is told to do the wrong set, which is worse than no guidance at all. These
/// tests pin the order, the superset interleave and its guards, and every mutation the plate's
/// controls perform.
final class GuidedSessionEngineTests: XCTestCase {

    // MARK: - Fixtures

    private func makeEntry(
        _ name: String,
        sets: Int,
        group: String? = nil,
        weightKg: Double? = 100,
        reps: Int? = 5,
        warmups: Int = 0
    ) -> ExerciseEntryDraft {
        var entry = ExerciseEntryDraft(
            exerciseName: name,
            exerciseCategory: .compound,
            muscleGroup: nil
        )
        entry.groupName = group
        entry.sets = (0..<sets).map { index in
            var set = SetDraft()
            set.targetWeightKg = weightKg
            set.targetReps = reps
            set.isWarmup = index < warmups
            return set
        }
        return entry
    }

    private func slotPairs(_ engine: GuidedSessionEngine) -> [[Int]] {
        engine.slots.map { [$0.entryIndex, $0.setIndex] }
    }

    // MARK: - Queue order

    func test_queue_plainMoves_runEntryByEntryThenSetBySet() {
        let entries = [makeEntry("Back squat", sets: 3), makeEntry("Romanian deadlift", sets: 2)]
        let engine = GuidedSessionEngine(entries: entries)

        XCTAssertEqual(
            slotPairs(engine),
            [[0, 0], [0, 1], [0, 2], [1, 0], [1, 1]],
            "Ungrouped moves run one at a time, in entry order"
        )
        XCTAssertEqual(engine.blocks, [[0], [1]])
        XCTAssertEqual(engine.current, GuidedSessionEngine.Slot(entryIndex: 0, setIndex: 0))
        XCTAssertEqual(engine.plannedSetsLeft, 5)
        XCTAssertFalse(engine.isSessionComplete)
    }

    func test_warmupSlots_areOrdinarySlots() {
        // A warm-up is a set the athlete performs; the mode walks it like any other.
        let entries = [makeEntry("Back squat", sets: 3, warmups: 1)]
        let engine = GuidedSessionEngine(entries: entries)

        XCTAssertEqual(engine.slots.count, 3)
        XCTAssertEqual(engine.current, GuidedSessionEngine.Slot(entryIndex: 0, setIndex: 0))
        XCTAssertTrue(entries[0].sets[0].isWarmup)
    }

    // MARK: - Superset interleave

    func test_pairBlock_interleavesSetBySet() {
        // The gated demo's shape: two ungrouped moves, then a grouped pair.
        let entries = [
            makeEntry("Back squat", sets: 2),
            makeEntry("Romanian deadlift", sets: 2),
            makeEntry("Pull-up", sets: 2, group: "B"),
            makeEntry("Dumbbell bench press", sets: 2, group: "B")
        ]
        let engine = GuidedSessionEngine(entries: entries)

        XCTAssertEqual(engine.blocks, [[0], [1], [2, 3]])
        XCTAssertEqual(
            slotPairs(engine).suffix(4).map { $0 },
            [[2, 0], [3, 0], [2, 1], [3, 1]],
            "A pair alternates A1 B1 A2 B2"
        )
        XCTAssertTrue(engine.isPaired(2))
        XCTAssertEqual(engine.tag(for: 2), "3A")
        XCTAssertEqual(engine.tag(for: 3), "3B")
        XCTAssertEqual(engine.tag(for: 0), "1")
        XCTAssertEqual(engine.movePosition(entryIndex: 3).count, 3, "A pair counts as ONE move")
    }

    func test_singleGroupSpanningTheWholeSession_neverInterleaves() {
        // The program importer puts an entire program DAY into one group named after the day.
        // Interleaving that would shuffle a whole session into nonsense.
        let entries = [
            makeEntry("Back squat", sets: 3, group: "Day 2"),
            makeEntry("Romanian deadlift", sets: 3, group: "Day 2"),
            makeEntry("Walking lunge", sets: 2, group: "Day 2")
        ]
        let engine = GuidedSessionEngine(entries: entries)

        XCTAssertEqual(engine.blocks, [[0], [1], [2]], "A session-wide group is a day, not a superset")
        XCTAssertEqual(
            slotPairs(engine),
            [[0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2], [2, 0], [2, 1]]
        )
    }

    func test_runOfFourSameGroupEntries_neverInterleaves() {
        // Four-plus consecutive same-group entries are a day even when other moves follow.
        let entries = [
            makeEntry("A", sets: 1, group: "Day 2"),
            makeEntry("B", sets: 1, group: "Day 2"),
            makeEntry("C", sets: 1, group: "Day 2"),
            makeEntry("D", sets: 1, group: "Day 2"),
            makeEntry("E", sets: 1)
        ]
        let engine = GuidedSessionEngine(entries: entries)

        XCTAssertEqual(engine.blocks, [[0], [1], [2], [3], [4]])
    }

    func test_pairBlock_unevenCounts_longerTailContinuesAlone() {
        let entries = [
            makeEntry("Pull-up", sets: 3, group: "B"),
            makeEntry("Dumbbell bench press", sets: 1, group: "B"),
            makeEntry("Plank", sets: 1)
        ]
        let engine = GuidedSessionEngine(entries: entries)

        XCTAssertEqual(
            slotPairs(engine),
            [[0, 0], [1, 0], [0, 1], [0, 2], [2, 0]],
            "When counts differ the longer movement's tail continues on its own"
        )
    }

    // MARK: - Log

    func test_log_writesValues_stampsLoggedAt_andAdvancesTheCursor() throws {
        var entries = [makeEntry("Back squat", sets: 2)]
        let engine = GuidedSessionEngine(entries: entries)
        let slot = try XCTUnwrap(engine.current)
        let stamp = Date(timeIntervalSince1970: 1_000_000)

        GuidedSessionEngine.log(&entries, slot: slot, weightKg: 132.5, reps: 5, at: stamp)

        XCTAssertTrue(entries[0].sets[0].isDone)
        XCTAssertEqual(entries[0].sets[0].weightKg, 132.5)
        XCTAssertEqual(entries[0].sets[0].reps, 5)
        XCTAssertEqual(entries[0].sets[0].loggedAt, stamp)

        let advanced = GuidedSessionEngine(entries: entries)
        XCTAssertEqual(advanced.current, GuidedSessionEngine.Slot(entryIndex: 0, setIndex: 1))
        XCTAssertEqual(advanced.plannedSetsLeft, 1)
    }

    func test_log_leavesAlreadyMaterializedValuesAlone() {
        // Materialize ≠ log: the editor may have written values long before the athlete taps.
        var entries = [makeEntry("Back squat", sets: 1)]
        entries[0].sets[0].weightKg = 120
        entries[0].sets[0].reps = 8
        let slot = GuidedSessionEngine.Slot(entryIndex: 0, setIndex: 0)

        GuidedSessionEngine.log(&entries, slot: slot)

        XCTAssertEqual(entries[0].sets[0].weightKg, 120)
        XCTAssertEqual(entries[0].sets[0].reps, 8)
        XCTAssertTrue(entries[0].sets[0].isDone)
        XCTAssertNotNil(entries[0].sets[0].loggedAt)
    }

    func test_lastPlannedSetLogged_endsTheMove_withNoDoneButton() {
        var entries = [makeEntry("Back squat", sets: 1), makeEntry("Romanian deadlift", sets: 1)]
        GuidedSessionEngine.log(
            &entries,
            slot: GuidedSessionEngine.Slot(entryIndex: 0, setIndex: 0),
            weightKg: 100,
            reps: 5
        )

        let engine = GuidedSessionEngine(entries: entries)
        XCTAssertEqual(engine.currentEntryIndex, 1, "The move ends when its last planned set logs")
    }

    // MARK: - Skip

    func test_skipMove_marksRemainingPlannedSkipped_andAdvances() {
        var entries = [makeEntry("Back squat", sets: 3), makeEntry("Romanian deadlift", sets: 1)]
        GuidedSessionEngine.log(
            &entries,
            slot: GuidedSessionEngine.Slot(entryIndex: 0, setIndex: 0),
            weightKg: 100,
            reps: 5
        )

        GuidedSessionEngine.skipMove(&entries, entryIndex: 0)

        XCTAssertTrue(entries[0].sets[0].isDone)
        XCTAssertFalse(entries[0].sets[0].isSkipped, "A logged set is never retro-skipped")
        XCTAssertTrue(entries[0].sets[1].isSkipped)
        XCTAssertTrue(entries[0].sets[2].isSkipped)

        let engine = GuidedSessionEngine(entries: entries)
        XCTAssertEqual(engine.currentEntryIndex, 1)
        XCTAssertEqual(engine.plannedSetsLeft, 1, "Skipped sets are no longer owed")
    }

    // MARK: - Extra set

    func test_addExtraSet_plainMove_landsAfterTheEntrysOwnBlock() {
        var entries = [makeEntry("Back squat", sets: 2), makeEntry("Romanian deadlift", sets: 1)]
        for index in 0..<2 {
            GuidedSessionEngine.log(
                &entries,
                slot: GuidedSessionEngine.Slot(entryIndex: 0, setIndex: index),
                weightKg: 100,
                reps: 5
            )
        }

        GuidedSessionEngine.addExtraSet(&entries, entryIndex: 0)

        XCTAssertEqual(entries[0].sets.count, 3)
        XCTAssertTrue(entries[0].sets[2].isExtra)
        XCTAssertFalse(entries[0].sets[2].isDone, "An extra set arrives suggested, never performed")
        XCTAssertEqual(entries[0].sets[2].targetWeightKg, 100, "It carries the last logged numbers as ghosts")
        XCTAssertEqual(entries[0].sets[2].targetReps, 5)

        let engine = GuidedSessionEngine(entries: entries)
        XCTAssertEqual(engine.current, GuidedSessionEngine.Slot(entryIndex: 0, setIndex: 2))
        XCTAssertEqual(
            engine.slots.last,
            GuidedSessionEngine.Slot(entryIndex: 1, setIndex: 0),
            "The extra set stays inside its own move's block"
        )
    }

    func test_addExtraSet_insideAPair_landsAfterThePairsLastSlot() {
        var entries = [
            makeEntry("Pull-up", sets: 2, group: "B"),
            makeEntry("Dumbbell bench press", sets: 2, group: "B"),
            makeEntry("Plank", sets: 1)
        ]

        GuidedSessionEngine.addExtraSet(&entries, entryIndex: 0)
        let engine = GuidedSessionEngine(entries: entries)

        XCTAssertEqual(
            slotPairs(engine),
            [[0, 0], [1, 0], [0, 1], [1, 1], [0, 2], [2, 0]],
            "The pair's extra round runs after the pair's last paired slot, before the next move"
        )
    }

    // MARK: - Reopen

    func test_reopen_unskipsASkippedMove() {
        var entries = [makeEntry("Back squat", sets: 2)]
        GuidedSessionEngine.skipMove(&entries, entryIndex: 0)
        XCTAssertTrue(GuidedSessionEngine(entries: entries).isSessionComplete)

        GuidedSessionEngine.reopen(&entries, entryIndex: 0)

        XCTAssertFalse(entries[0].sets.contains { $0.isSkipped })
        XCTAssertEqual(entries[0].sets.count, 2, "Un-skipping never fabricates a set")
        XCTAssertEqual(
            GuidedSessionEngine(entries: entries).current,
            GuidedSessionEngine.Slot(entryIndex: 0, setIndex: 0)
        )
    }

    func test_reopen_addsAnExtraSetWhenEverythingIsAlreadyLogged() {
        var entries = [makeEntry("Back squat", sets: 1)]
        GuidedSessionEngine.log(
            &entries,
            slot: GuidedSessionEngine.Slot(entryIndex: 0, setIndex: 0),
            weightKg: 100,
            reps: 5
        )

        GuidedSessionEngine.reopen(&entries, entryIndex: 0)

        XCTAssertEqual(entries[0].sets.count, 2)
        XCTAssertTrue(entries[0].sets[1].isExtra)
        XCTAssertFalse(GuidedSessionEngine(entries: entries).isSessionComplete)
    }

    // MARK: - Jump

    func test_jump_bringsThePartnersPlannedSlotToTheFront() {
        // Cursor sits on the pair's A2; tapping the B cell brings B2 forward for one set.
        var entries = [
            makeEntry("Pull-up", sets: 2, group: "B"),
            makeEntry("Dumbbell bench press", sets: 2, group: "B")
        ]
        GuidedSessionEngine.log(
            &entries,
            slot: GuidedSessionEngine.Slot(entryIndex: 0, setIndex: 0),
            weightKg: 0,
            reps: 8
        )
        GuidedSessionEngine.log(
            &entries,
            slot: GuidedSessionEngine.Slot(entryIndex: 1, setIndex: 0),
            weightKg: 30,
            reps: 10
        )
        XCTAssertEqual(
            GuidedSessionEngine(entries: entries).current,
            GuidedSessionEngine.Slot(entryIndex: 0, setIndex: 1)
        )

        let priority = GuidedSessionEngine.jumpTarget(to: 1, in: entries)
        XCTAssertEqual(priority, 1)

        let jumped = GuidedSessionEngine(entries: entries, priorityEntryIndex: priority)
        XCTAssertEqual(jumped.current, GuidedSessionEngine.Slot(entryIndex: 1, setIndex: 1))
        XCTAssertEqual(
            jumped.upNext,
            GuidedSessionEngine.Slot(entryIndex: 0, setIndex: 1),
            "The stepped-over partner is what comes next"
        )
    }

    func test_jump_toTheCurrentOrASettledMove_isANoOp() {
        var entries = [
            makeEntry("Pull-up", sets: 1, group: "B"),
            makeEntry("Dumbbell bench press", sets: 1, group: "B")
        ]
        XCTAssertNil(GuidedSessionEngine.jumpTarget(to: 0, in: entries), "Already current")

        GuidedSessionEngine.skipMove(&entries, entryIndex: 1)
        XCTAssertNil(GuidedSessionEngine.jumpTarget(to: 1, in: entries), "Nothing planned there")
    }

    // MARK: - Up next / positions / completion

    func test_upNext_insideAPair_isThePartner_andOutsideItIsTheNextMove() {
        let entries = [
            makeEntry("Pull-up", sets: 2, group: "B"),
            makeEntry("Dumbbell bench press", sets: 2, group: "B"),
            makeEntry("Plank", sets: 1)
        ]
        let paired = GuidedSessionEngine(entries: entries)
        XCTAssertEqual(paired.upNext, GuidedSessionEngine.Slot(entryIndex: 1, setIndex: 0))

        let plain = GuidedSessionEngine(entries: [makeEntry("A", sets: 2), makeEntry("B", sets: 2)])
        XCTAssertEqual(plain.upNext, GuidedSessionEngine.Slot(entryIndex: 1, setIndex: 0))
    }

    func test_upNext_isNilOnTheLastMove() {
        let engine = GuidedSessionEngine(entries: [makeEntry("A", sets: 2)])
        XCTAssertNil(engine.upNext)
    }

    func test_setPosition_countsWithinTheMove() {
        var entries = [makeEntry("Back squat", sets: 4)]
        GuidedSessionEngine.log(
            &entries,
            slot: GuidedSessionEngine.Slot(entryIndex: 0, setIndex: 0),
            weightKg: 100,
            reps: 5
        )

        let engine = GuidedSessionEngine(entries: entries)
        let position = engine.setPosition(entryIndex: 0)
        XCTAssertEqual(position.index, 2)
        XCTAssertEqual(position.count, 4)
    }

    func test_isSessionComplete_onlyWhenEverySetIsSettled() {
        var entries = [makeEntry("A", sets: 2), makeEntry("B", sets: 1)]
        XCTAssertFalse(GuidedSessionEngine(entries: entries).isSessionComplete)

        for index in 0..<2 {
            GuidedSessionEngine.log(
                &entries,
                slot: GuidedSessionEngine.Slot(entryIndex: 0, setIndex: index),
                weightKg: 100,
                reps: 5
            )
        }
        XCTAssertFalse(GuidedSessionEngine(entries: entries).isSessionComplete)

        GuidedSessionEngine.skipMove(&entries, entryIndex: 1)
        let engine = GuidedSessionEngine(entries: entries)
        XCTAssertTrue(engine.isSessionComplete)
        XCTAssertNil(engine.current)
        XCTAssertEqual(engine.plannedSetsLeft, 0)
    }
}
