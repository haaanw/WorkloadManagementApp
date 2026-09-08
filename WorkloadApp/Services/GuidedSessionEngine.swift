import Foundation

/// Guided session mode's queue (v1.7.3 feature 9, HAN-gated demo round 3 "Plate").
///
/// A guided session is one move at a time: the athlete never scrolls a list, never picks which
/// row to fill, never recalls a number. That requires ONE ordered queue of set slots and a
/// cursor, which is all this engine is — a pure derivation over the sheet's existing
/// `[ExerciseEntryDraft]` state, plus the small set of mutations the plate's controls perform.
///
/// **Pure and derived, deliberately.** The queue is recomputed from the drafts on every read
/// rather than stored, so voice ingest, the finish sheet, and the plate can all write the same
/// `entries` array without a second source of truth going stale behind them. The one thing that
/// is NOT derivable from the drafts is a jump — "do the partner now" reorders execution without
/// changing any set — so that lives as the caller-held `priorityEntryIndex` (see `jumpTarget`).
///
/// **Superset interleaving.** Two or three consecutive entries sharing one non-nil `groupName`
/// are a pair block and alternate set by set (A1 B1 A2 B2 …); when the counts differ the longer
/// tail continues alone. The guard that matters is the program importer: it puts an entire
/// program DAY into one group named after the day (`WorkoutLLMImportService`), and interleaving a
/// whole day would shuffle a session into nonsense. So a pair block never spans the entire
/// session, and never exceeds three entries — a run of four-plus consecutive same-group entries
/// is a day, not a superset.
///
/// (The build brief phrased that guard as "only when the session holds ≥2 distinct group names".
/// Taken literally it would have refused the gated demo's own superset, which pairs two grouped
/// moves with two ungrouped ones — one distinct name in the whole session. The rule below keeps
/// the intent, which is that a session-wide group is a day, and matches the demo.)
struct GuidedSessionEngine {

    // MARK: - Slot

    /// One set, addressed by where it lives in the drafts. Queue position is the array order of
    /// `slots`; this is deliberately NOT an index into the queue, so a slot survives a requeue.
    struct Slot: Equatable, Hashable {
        let entryIndex: Int
        let setIndex: Int
    }

    /// A superset alternates at most three movements. Beyond that it is a program day.
    static let maxPairBlockSize = 3

    // MARK: - Derived state

    let entries: [ExerciseEntryDraft]
    /// The entry the athlete pulled forward with a pair-cell tap, honored for ONE set (the
    /// caller clears it on the next log/skip, exactly as the demo's splice behaves).
    let priorityEntryIndex: Int?
    /// Every set of the session in execution order.
    let slots: [Slot]
    /// Execution blocks: one entry index for a plain move, two or three for a superset pair.
    let blocks: [[Int]]

    init(entries: [ExerciseEntryDraft], priorityEntryIndex: Int? = nil) {
        self.entries = entries
        self.priorityEntryIndex = priorityEntryIndex
        let blocks = Self.blocks(in: entries)
        self.blocks = blocks
        self.slots = Self.queue(entries: entries, blocks: blocks, priorityEntryIndex: priorityEntryIndex)
    }

    // MARK: - Queue construction

    /// Group name, normalized: an empty or whitespace-only name is no group at all.
    private static func group(_ entry: ExerciseEntryDraft) -> String? {
        guard let name = entry.groupName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }
        return name
    }

    /// The session's execution blocks, in order.
    static func blocks(in entries: [ExerciseEntryDraft]) -> [[Int]] {
        var result: [[Int]] = []
        var index = 0
        while index < entries.count {
            if let name = group(entries[index]) {
                // The FULL run first, then the size tests — capping before testing would turn a
                // five-exercise program day into a three-way superset plus two strays.
                var end = index + 1
                while end < entries.count, group(entries[end]) == name { end += 1 }
                let length = end - index
                let spansSession = length == entries.count
                if length >= 2, length <= maxPairBlockSize, !spansSession {
                    result.append(Array(index..<end))
                } else {
                    // A rejected run is rejected WHOLE. Advancing by one instead would rescan
                    // the same run from its second entry — and a four-deep program day would
                    // come back as a three-way superset with one stray in front of it.
                    for member in index..<end { result.append([member]) }
                }
                index = end
                continue
            }
            result.append([index])
            index += 1
        }
        return result
    }

    private static func queue(
        entries: [ExerciseEntryDraft],
        blocks: [[Int]],
        priorityEntryIndex: Int?
    ) -> [Slot] {
        var queue: [Slot] = []
        for block in blocks {
            if block.count == 1 {
                let entryIndex = block[0]
                for setIndex in entries[entryIndex].sets.indices {
                    queue.append(Slot(entryIndex: entryIndex, setIndex: setIndex))
                }
            } else {
                // A1 B1 A2 B2 … ; when the counts differ the longer tail continues alone.
                let longest = block.map { entries[$0].sets.count }.max() ?? 0
                for round in 0..<longest {
                    for entryIndex in block where round < entries[entryIndex].sets.count {
                        queue.append(Slot(entryIndex: entryIndex, setIndex: round))
                    }
                }
            }
        }

        guard let priority = priorityEntryIndex,
              let cursor = queue.firstIndex(where: { isPlanned($0, in: entries) }),
              let target = queue.firstIndex(where: {
                  $0.entryIndex == priority && isPlanned($0, in: entries)
              }),
              target > cursor
        else { return queue }

        var reordered = queue
        let slot = reordered.remove(at: target)
        reordered.insert(slot, at: cursor)
        return reordered
    }

    // MARK: - Reading the queue

    /// A slot still to be done: neither logged nor skipped.
    private static func isPlanned(_ slot: Slot, in entries: [ExerciseEntryDraft]) -> Bool {
        guard entries.indices.contains(slot.entryIndex),
              entries[slot.entryIndex].sets.indices.contains(slot.setIndex) else { return false }
        let set = entries[slot.entryIndex].sets[slot.setIndex]
        return !set.isDone && !set.isSkipped
    }

    func isPlanned(_ slot: Slot) -> Bool { Self.isPlanned(slot, in: entries) }

    /// Queue position of the cursor — the first slot still to be done.
    var cursorIndex: Int? {
        slots.firstIndex { Self.isPlanned($0, in: entries) }
    }

    /// The set the plate is showing.
    var current: Slot? {
        guard let cursorIndex else { return nil }
        return slots[cursorIndex]
    }

    var currentEntryIndex: Int? { current?.entryIndex }

    /// The move the plate is showing.
    var currentMove: ExerciseEntryDraft? {
        guard let index = currentEntryIndex, entries.indices.contains(index) else { return nil }
        return entries[index]
    }

    /// The next slot belonging to a DIFFERENT entry than the current one. Inside a pair block
    /// that is the partner, which is why callers label it THEN there and NEXT everywhere else.
    var upNext: Slot? {
        guard let cursorIndex, let current else { return nil }
        for position in (cursorIndex + 1)..<slots.count {
            let slot = slots[position]
            if slot.entryIndex != current.entryIndex, Self.isPlanned(slot, in: entries) {
                return slot
            }
        }
        return nil
    }

    /// How many sets the session still owes.
    var plannedSetsLeft: Int {
        slots.filter { Self.isPlanned($0, in: entries) }.count
    }

    /// Nothing left to do: every set is logged or skipped. A move ends when its last planned set
    /// logs, or on Skip — there is no Done button anywhere in the mode.
    var isSessionComplete: Bool { current == nil }

    /// Where an entry stands in its own sets: the 1-based position of its next set still to do
    /// (or its last set once everything is settled) and how many sets it holds.
    func setPosition(entryIndex: Int) -> (index: Int, count: Int) {
        guard entries.indices.contains(entryIndex) else { return (0, 0) }
        let sets = entries[entryIndex].sets
        if let next = sets.firstIndex(where: { !$0.isDone && !$0.isSkipped }) {
            return (next + 1, sets.count)
        }
        return (sets.count, sets.count)
    }

    // MARK: - Blocks

    func blockIndex(of entryIndex: Int) -> Int? {
        blocks.firstIndex { $0.contains(entryIndex) }
    }

    /// The entries executed together with this one — itself alone for a plain move, the pair for
    /// a superset.
    func block(containing entryIndex: Int) -> [Int] {
        guard let index = blockIndex(of: entryIndex) else { return [entryIndex] }
        return blocks[index]
    }

    func isPaired(_ entryIndex: Int) -> Bool { block(containing: entryIndex).count > 1 }

    /// Position of the move in the session, counting a pair block as ONE move.
    func movePosition(entryIndex: Int) -> (index: Int, count: Int) {
        guard let index = blockIndex(of: entryIndex) else { return (0, blocks.count) }
        return (index + 1, blocks.count)
    }

    /// The move's tag: "2" for a plain move, "3A" / "3B" for the members of a pair block.
    func tag(for entryIndex: Int) -> String {
        guard let index = blockIndex(of: entryIndex) else { return "" }
        let block = blocks[index]
        let ordinal = String(index + 1)
        guard block.count > 1, let position = block.firstIndex(of: entryIndex) else { return ordinal }
        let letters = ["A", "B", "C"]
        return ordinal + letters[min(position, letters.count - 1)]
    }

    // MARK: - Mutations

    /// Record the slot as performed. Values already materialized by the editor stay; anything the
    /// caller passes wins over them. `loggedAt` is stamped here and nowhere else in the mode, so
    /// the SINCE SET clock and the saved `completedAt` cannot disagree.
    static func log(
        _ entries: inout [ExerciseEntryDraft],
        slot: Slot,
        weightKg: Double? = nil,
        reps: Int? = nil,
        rpe: Double? = nil,
        rir: Int? = nil,
        durationSeconds: Int? = nil,
        distanceMeters: Double? = nil,
        at date: Date = .now
    ) {
        guard entries.indices.contains(slot.entryIndex),
              entries[slot.entryIndex].sets.indices.contains(slot.setIndex) else { return }
        if let weightKg { entries[slot.entryIndex].sets[slot.setIndex].weightKg = weightKg }
        if let reps { entries[slot.entryIndex].sets[slot.setIndex].reps = reps }
        if let rpe { entries[slot.entryIndex].sets[slot.setIndex].rpe = rpe }
        if let rir { entries[slot.entryIndex].sets[slot.setIndex].rir = rir }
        if let durationSeconds {
            entries[slot.entryIndex].sets[slot.setIndex].durationSeconds = durationSeconds
        }
        if let distanceMeters {
            entries[slot.entryIndex].sets[slot.setIndex].distanceMeters = distanceMeters
        }
        entries[slot.entryIndex].sets[slot.setIndex].isSkipped = false
        entries[slot.entryIndex].sets[slot.setIndex].isDone = true
        entries[slot.entryIndex].sets[slot.setIndex].loggedAt = date
    }

    /// The move ends here. Every set of it still to do becomes skipped — never logged, so nothing
    /// the athlete did not perform reaches the record.
    static func skipMove(_ entries: inout [ExerciseEntryDraft], entryIndex: Int) {
        guard entries.indices.contains(entryIndex) else { return }
        for index in entries[entryIndex].sets.indices where !entries[entryIndex].sets[index].isDone {
            entries[entryIndex].sets[index].isSkipped = true
        }
    }

    /// One more set than the plan asked for, carrying the move's last logged numbers as GHOST
    /// targets (materialize ≠ log: the row arrives suggested, not performed). The queue places it
    /// after the entry's block — after the pair's last slot inside a superset — because the
    /// derivation appends an entry's sets in array order.
    @discardableResult
    static func addExtraSet(_ entries: inout [ExerciseEntryDraft], entryIndex: Int) -> Int? {
        guard entries.indices.contains(entryIndex) else { return nil }
        var draft = SetDraft()
        draft.isExtra = true
        if let last = entries[entryIndex].sets.last(where: { $0.isDone }) {
            draft.targetWeightKg = last.weightKg ?? last.targetWeightKg
            draft.targetReps = last.reps ?? last.targetReps
            draft.targetRPE = last.rpe ?? last.targetRPE
            draft.targetDistanceMeters = last.distanceMeters ?? last.targetDistanceMeters
            draft.targetDurationSeconds = last.durationSeconds ?? last.targetDurationSeconds
        } else if let last = entries[entryIndex].sets.last {
            draft.targetWeightKg = last.targetWeightKg
            draft.targetReps = last.targetReps
            draft.targetRPE = last.targetRPE
            draft.targetDistanceMeters = last.targetDistanceMeters
            draft.targetDurationSeconds = last.targetDurationSeconds
        }
        draft.lastSessionWeightKg = entries[entryIndex].sets.last?.lastSessionWeightKg
        draft.lastSessionReps = entries[entryIndex].sets.last?.lastSessionReps
        entries[entryIndex].sets.append(draft)
        return entries[entryIndex].sets.count - 1
    }

    /// A settled move comes back: skipped sets return to planned, and a fully logged move gains
    /// one extra set instead (there is nothing to un-skip).
    static func reopen(_ entries: inout [ExerciseEntryDraft], entryIndex: Int) {
        guard entries.indices.contains(entryIndex) else { return }
        let hasSkipped = entries[entryIndex].sets.contains { $0.isSkipped }
        if hasSkipped {
            for index in entries[entryIndex].sets.indices where entries[entryIndex].sets[index].isSkipped {
                entries[entryIndex].sets[index].isSkipped = false
            }
            return
        }
        if !entries[entryIndex].sets.contains(where: { !$0.isDone }) {
            addExtraSet(&entries, entryIndex: entryIndex)
        }
    }

    /// Bring an entry's first planned slot to the front of the queue — the pair-cell tap.
    ///
    /// Unlike the mutations above this changes no draft: queue order is not a property of the
    /// sets, and expressing it as a reorder of `entries` cannot represent "step over the
    /// partner's planned set just this once". So it returns the `priorityEntryIndex` the caller
    /// holds (for one set) and feeds back into `init`. Returns nil when the jump is a no-op.
    static func jumpTarget(
        to entryIndex: Int,
        in entries: [ExerciseEntryDraft],
        priorityEntryIndex: Int? = nil
    ) -> Int? {
        let engine = GuidedSessionEngine(entries: entries, priorityEntryIndex: priorityEntryIndex)
        guard let current = engine.current, current.entryIndex != entryIndex else { return nil }
        guard engine.slots.contains(where: {
            $0.entryIndex == entryIndex && isPlanned($0, in: entries)
        }) else { return nil }
        return entryIndex
    }
}
