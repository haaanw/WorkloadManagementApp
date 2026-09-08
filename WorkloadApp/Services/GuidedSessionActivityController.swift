import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Shared formatting

/// The one place guided mode composes a set into words.
///
/// The plate and the lock screen show the SAME set at the same moment, so a second implementation
/// of "what does 132.5 kg × 5 look like" is a guarantee that the two eventually disagree. These
/// were private helpers inside `GuidedSessionView`; they moved here when the Live Activity became
/// a second reader (v1.7.3 feature 9 batch 2) and the view now calls them too.
///
/// Everything is resolved against an explicit `Locale` because the lock screen's copy is baked at
/// WRITE time — the widget extension cannot see the app's in-app language override.
enum GuidedSessionFormatting {

    /// mm:ss. A session longer than an hour keeps counting minutes rather than growing a third
    /// field — the clock is a rest timer, not a duration report.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// A weight in the athlete's unit: "132.5 kg", "+10 kg" for a loaded bodyweight movement,
    /// "BW" for an unloaded one, "—" when there is no number at all.
    static func weightText(
        _ kg: Double?,
        bodyweight: Bool,
        unit: WeightUnit,
        locale: Locale
    ) -> String {
        guard let kg else { return "—" }
        if bodyweight, kg == 0 {
            return LocalePinnedStrings.localized("setEntry.bw", locale: locale)
        }
        let display = WeightFormatter.displayValue(kg, unit: unit)
        let number = display == display.rounded()
            ? String(format: "%.0f", display)
            : String(format: "%.1f", display)
        let unitLabel = unit == .kg
            ? LocalePinnedStrings.localized("unit.kg", locale: locale)
            : LocalePinnedStrings.localized("unit.lb", locale: locale)
        return bodyweight ? "+\(number) \(unitLabel)" : "\(number) \(unitLabel)"
    }

    /// "Set 2" — the 1-based label for a set inside its move.
    static func setNumber(_ oneBasedIndex: Int, locale: Locale) -> String {
        String(
            format: LocalePinnedStrings.localized(
                "guided.pair.setNumber",
                defaultValue: "Set %d",
                locale: locale
            ),
            oneBasedIndex
        )
    }

    /// The prescription for ONE set, as the plate's hero reading and the lock card's big line:
    /// "132.5 kg × 5", "BW × 8", or a duration/distance line for a non-weight movement.
    ///
    /// Reads the LOGGED value first and the target second, so a set the athlete already edited
    /// shows what they actually chose rather than what the plan asked for.
    static func targetLine(
        entry: ExerciseEntryDraft,
        set: SetDraft,
        unit: WeightUnit,
        locale: Locale
    ) -> String {
        switch entry.exerciseCategory.inputMode {
        case .weightReps, .repsOnly:
            let bodyweight = entry.exerciseCategory == .bodyweight
            let kg = set.weightKg ?? set.targetWeightKg
            let reps = set.reps ?? set.targetReps ?? 0
            // `weightText` says BW for an explicit zero; a bodyweight set with NO number at all
            // is the same statement, not a missing one.
            let weight = bodyweight && (kg ?? 0) == 0
                ? LocalePinnedStrings.localized("setEntry.bw", locale: locale)
                : weightText(kg, bodyweight: bodyweight, unit: unit, locale: locale)
            return "\(weight) × \(reps)"
        case .distanceDuration:
            let meters = set.distanceMeters ?? set.targetDistanceMeters
            let seconds = set.durationSeconds ?? set.targetDurationSeconds
            let parts = [
                meters.map { String(format: "%.1f km", $0 / 1000) },
                seconds.map { clock(TimeInterval($0)) }
            ].compactMap { $0 }
            return parts.isEmpty ? "—" : parts.joined(separator: " · ")
        case .durationOnly:
            guard let seconds = set.durationSeconds ?? set.targetDurationSeconds else { return "—" }
            return clock(TimeInterval(seconds))
        }
    }

    /// The line under NEXT / THEN.
    ///
    /// A fresh move states the whole prescription — "3 × 8 · 100 kg". A superset PARTNER is
    /// already mid-flight, so the honest unit is the single set that is actually next:
    /// "Set 2 · 30 kg × 10".
    static func upNextLine(
        entry: ExerciseEntryDraft,
        set: SetDraft,
        setIndex: Int,
        isPairPartner: Bool,
        unit: WeightUnit,
        locale: Locale
    ) -> String {
        let bodyweight = entry.exerciseCategory == .bodyweight
        let weight = weightText(set.weightKg ?? set.targetWeightKg, bodyweight: bodyweight, unit: unit, locale: locale)
        let reps = set.reps ?? set.targetReps ?? 0
        if isPairPartner {
            return "\(setNumber(setIndex + 1, locale: locale)) · \(weight) × \(reps)"
        }
        let plannedSets = entry.sets.filter { !$0.isSkipped }.count
        return "\(plannedSets) × \(reps) · \(weight)"
    }
}

// MARK: - Controller

/// Owns the guided session's lock-screen Live Activity (v1.7.3 feature 9 batch 2, tier 1).
///
/// **Tier 1 is read-only and push-free.** There is no `LiveActivityIntent` yet (tier 2 needs the
/// draft in a store the extension can reach) and `pushType` is nil — the activity updates only
/// when the app is alive and something happened: a log, a skip, an advance, the finish. The two
/// clocks tick by themselves because the state hands the extension DATES, not strings.
///
/// **Nothing here throws to the caller.** A Live Activity is decoration on top of a session that
/// must save regardless; a denied authorization, a full activity slot or a stale handle must never
/// reach the save path. Failures print, exactly like the rest of the codebase's non-critical paths.
@MainActor
final class GuidedSessionActivityController {

    static let shared = GuidedSessionActivityController()

    private init() {}

    #if canImport(ActivityKit)
    /// The one live activity this controller owns. nil means "not running" — which is also what
    /// makes `end` idempotent, so the sheet's explicit end and its `onDisappear` safety net
    /// cannot fight over the dismissal policy.
    private var activity: Activity<GuidedSessionActivityAttributes>?

    /// Requested once per session start. Cheap, but it also asks the system, so it is not free.
    private var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var isRunning: Bool { activity != nil }

    // MARK: Lifecycle

    /// Begin the activity. A no-op when the athlete has Live Activities switched off.
    ///
    /// Any stale activity of this type is ended first: a crashed or force-quit session leaves its
    /// activity on the lock screen, and starting a second one would show the athlete two guided
    /// sessions at once.
    func start(
        attributes: GuidedSessionActivityAttributes,
        state: GuidedSessionActivityAttributes.ContentState
    ) {
        guard isSupported else { return }
        guard activity == nil else {
            update(state: state)
            return
        }
        endStaleActivities()
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("Guided session Live Activity start failed: \(error)")
        }
    }

    func update(state: GuidedSessionActivityAttributes.ContentState) {
        guard let activity else { return }
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    /// Start if we are not running, update if we are — the single entry point the sheet drives
    /// off one `onChange`.
    func startOrUpdate(
        sessionName: String,
        state: GuidedSessionActivityAttributes.ContentState
    ) {
        if activity == nil {
            start(
                attributes: GuidedSessionActivityAttributes(sessionName: sessionName),
                state: state
            )
        } else {
            update(state: state)
        }
    }

    /// End the activity.
    ///
    /// A FINISHED session leaves its summary on the lock screen for a few minutes — the athlete
    /// walking out of the gym gets to see what the session was without unlocking. A cancelled one
    /// disappears at once: there is nothing to report, and a lingering card about a session that
    /// was never saved is a lie.
    func end(
        finalState: GuidedSessionActivityAttributes.ContentState? = nil,
        dismissAfterMinutes: Int? = nil
    ) {
        guard let activity else { return }
        self.activity = nil
        let policy: ActivityUIDismissalPolicy = dismissAfterMinutes.map {
            .after(Date.now.addingTimeInterval(TimeInterval($0) * 60))
        } ?? .immediate
        let content = finalState.map { ActivityContent(state: $0, staleDate: nil) }
        Task {
            await activity.end(content, dismissalPolicy: policy)
        }
    }

    /// Ended without a save — swipe-to-dismiss, Cancel, the zero-done Discard, a save failure.
    func endImmediately() {
        end(finalState: nil, dismissAfterMinutes: nil)
    }

    /// Sweep activities this process does not hold a handle to (a previous launch's leftovers).
    private func endStaleActivities() {
        for stale in Activity<GuidedSessionActivityAttributes>.activities {
            Task { await stale.end(nil, dismissalPolicy: .immediate) }
        }
    }
    #else
    var isRunning: Bool { false }
    func start(attributes: GuidedSessionActivityAttributes, state: GuidedSessionActivityAttributes.ContentState) {}
    func update(state: GuidedSessionActivityAttributes.ContentState) {}
    func startOrUpdate(sessionName: String, state: GuidedSessionActivityAttributes.ContentState) {}
    func end(finalState: GuidedSessionActivityAttributes.ContentState? = nil, dismissAfterMinutes: Int? = nil) {}
    func endImmediately() {}
    #endif

    // MARK: - The builder

    /// Derive the whole lock-screen state from the same queue the plate is reading.
    ///
    /// Pure and static: it takes an engine and the drafts, and returns a value. That is what makes
    /// the shapes below unit-testable without ActivityKit, a simulator or a running session.
    ///
    /// `entries` is the array the engine was built from — passed explicitly because the state
    /// describes the DRAFTS, and reading them from two places (the parameter here, `engine.slots`
    /// for order) keeps the queue's ownership with the engine.
    nonisolated static func contentState(
        engine: GuidedSessionEngine,
        entries: [ExerciseEntryDraft],
        weightUnit: WeightUnit,
        locale: Locale,
        startedAt: Date
    ) -> GuidedSessionActivityAttributes.ContentState {
        typealias State = GuidedSessionActivityAttributes.ContentState

        let current = engine.current
        let sessionStates = engine.slots.map { slot in
            state(of: slot, in: entries, current: current)
        }
        let lastLoggedAt = entries.flatMap(\.sets).compactMap(\.loggedAt).max()
        let loggedCount = entries.reduce(0) { $0 + $1.sets.filter(\.isDone).count }

        // Session over: no move to show, so the card switches to its completion face and the
        // numbers below carry the whole message.
        guard let current, entries.indices.contains(current.entryIndex) else {
            return State(
                moveName: "",
                moveTag: "",
                movePosition: "\(engine.blocks.count)/\(engine.blocks.count)",
                targetLine: "",
                setStates: [],
                nextKind: .finish,
                sessionStates: sessionStates,
                startedAt: startedAt,
                lastLoggedAt: lastLoggedAt,
                loggedCount: loggedCount,
                setsLeft: 0,
                isComplete: true
            )
        }

        let entry = entries[current.entryIndex]
        let position = engine.movePosition(entryIndex: current.entryIndex)
        let setStates = entry.sets.indices.map { index in
            state(
                of: GuidedSessionEngine.Slot(entryIndex: current.entryIndex, setIndex: index),
                in: entries,
                current: current
            )
        }

        var nextKind: GuidedSessionActivityAttributes.NextKind = .finish
        var nextMoveName: String?
        var nextLine: String?
        if let upNext = engine.upNext, entries.indices.contains(upNext.entryIndex) {
            let nextEntry = entries[upNext.entryIndex]
            let isPartner = engine.block(containing: current.entryIndex).contains(upNext.entryIndex)
            nextKind = isPartner ? .then : .next
            nextMoveName = nextEntry.exerciseName
            nextLine = GuidedSessionFormatting.upNextLine(
                entry: nextEntry,
                set: nextEntry.sets[upNext.setIndex],
                setIndex: upNext.setIndex,
                isPairPartner: isPartner,
                unit: weightUnit,
                locale: locale
            )
        }

        return State(
            moveName: entry.exerciseName,
            moveTag: engine.tag(for: current.entryIndex),
            movePosition: "\(position.index)/\(position.count)",
            targetLine: GuidedSessionFormatting.targetLine(
                entry: entry,
                set: entry.sets[current.setIndex],
                unit: weightUnit,
                locale: locale
            ),
            setStates: setStates,
            nextKind: nextKind,
            nextMoveName: nextMoveName,
            nextLine: nextLine,
            sessionStates: sessionStates,
            startedAt: startedAt,
            lastLoggedAt: lastLoggedAt,
            loggedCount: loggedCount,
            setsLeft: engine.plannedSetsLeft,
            isComplete: false
        )
    }

    /// The state the activity ENDS on.
    ///
    /// A session is saved when the athlete says so, which is not the same as every set being
    /// logged — Finish is reachable at any moment. So the summary face is forced here rather than
    /// inferred: a card still showing "NEXT · Back squat" for a session that is already in the
    /// history would be describing work that will never happen. The bar keeps its planned
    /// segments, because "you finished with three left" is the honest picture.
    nonisolated static func finishedState(
        from state: GuidedSessionActivityAttributes.ContentState
    ) -> GuidedSessionActivityAttributes.ContentState {
        var finished = state
        finished.isComplete = true
        finished.setsLeft = 0
        finished.moveName = ""
        finished.moveTag = ""
        finished.targetLine = ""
        finished.setStates = []
        finished.nextKind = .finish
        finished.nextMoveName = nil
        finished.nextLine = nil
        return finished
    }

    private nonisolated static func state(
        of slot: GuidedSessionEngine.Slot,
        in entries: [ExerciseEntryDraft],
        current: GuidedSessionEngine.Slot?
    ) -> GuidedSessionActivityAttributes.SetState {
        guard entries.indices.contains(slot.entryIndex),
              entries[slot.entryIndex].sets.indices.contains(slot.setIndex) else { return .planned }
        let set = entries[slot.entryIndex].sets[slot.setIndex]
        if set.isDone { return .logged }
        if set.isSkipped { return .skipped }
        return slot == current ? .current : .planned
    }
}
