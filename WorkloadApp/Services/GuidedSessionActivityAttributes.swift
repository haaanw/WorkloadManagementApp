import ActivityKit
import Foundation

/// The lock-screen Live Activity contract for guided session mode (v1.7.3 feature 9, tier 1) —
/// written by the app while a guided session runs, rendered by `GuidedSessionLiveActivity` in
/// the widget extension.
///
/// **The composite-only law, hardened.** `WidgetSnapshot` carries the same law for the App Group
/// container; here it binds harder, because **the lock screen is a PUBLIC surface**. This state
/// may carry only what the session itself is — movement names, prescriptions the athlete wrote,
/// set counts, clocks. It may NEVER carry a readiness or recovery score, an HRV, a resting or
/// working heart rate, a sleep duration, a body temperature, a VO2 max, a respiratory rate or any
/// other physiological reading, raw or composite. A body number a stranger can read over your
/// shoulder is a body number that left the device. `GuidedSessionActivityAttributesTests` fences
/// the field names.
///
/// **Membership:** this file compiles in BOTH the app target and the widget extension target (it
/// is the shared contract, exactly like `WidgetSnapshot.swift`). It therefore imports Foundation
/// and ActivityKit only — no SwiftUI, no SwiftData, no app model types.
///
/// **Everything is PRE-RESOLVED.** Every string here arrives already formatted and already
/// localized by the app: the extension cannot read the in-app language override, and it cannot
/// reach `WeightFormatter`, the athlete's unit, or the suggestion engine. So `targetLine` is
/// "132.5 kg × 5", not a weight plus a unit enum; `movePosition` is "1/4", not two integers. The
/// composition rules live in `GuidedSessionFormatting` (app side), shared with the plate so the
/// lock screen and the screen never disagree about the same set.
///
/// **What is NOT pre-resolved: the two clocks.** `startedAt` and `lastLoggedAt` cross as dates so
/// the extension can hand them to `Text(timerInterval:)`, which ticks on the render server with no
/// activity update at all. That is the whole reason tier 1 needs no background refresh: the app
/// pushes state only on log / skip / advance / finish.
struct GuidedSessionActivityAttributes: ActivityAttributes {

    /// The session's name, fixed for the life of the activity (attributes never change).
    /// Pre-localized; falls back to the sport's display name when the athlete named nothing.
    let sessionName: String

    /// One set's standing in the queue — the vocabulary the plate's set blocks and the lock
    /// card's segmented bar both speak.
    enum SetState: String, Codable, Hashable {
        case logged
        case current
        case planned
        case skipped
    }

    /// What follows the set on screen. Inside a superset the next slot is the PARTNER, which the
    /// mode labels THEN rather than NEXT; when nothing is left the label is FINISH.
    enum NextKind: String, Codable, Hashable {
        case next
        case then
        case finish
    }

    struct ContentState: Codable, Hashable {

        /// Bump when a field changes meaning. An activity outlives an app update only until the
        /// next launch, so this is a diagnostic rather than a gate — but a state and a renderer
        /// that disagree silently is exactly what versioning exists to make visible.
        static let currentSchemaVersion = 1

        /// The segmented bar draws every set of the session. A 40-set session is already an
        /// outlier; beyond that the segments fall below a hairline and the bar stops being
        /// readable, so the state carries the most RECENT 40 (see `capped(_:)` — the front is
        /// dropped, because what is coming matters more than what is long finished).
        static let sessionBarCap = 40

        // MARK: The move on screen

        /// The movement's name, verbatim from the draft.
        var moveName: String
        /// The move's tag in the session — "1" for a plain move, "3A" / "3B" inside a superset.
        var moveTag: String
        /// Pre-formatted position of the move among the session's moves, e.g. "1/4".
        var movePosition: String
        /// The current set's prescription as one line: "132.5 kg × 5", "BW × 8", "20:00".
        var targetLine: String
        /// Every set of the CURRENT move, in order — the card's row of mini set blocks.
        var setStates: [SetState]

        // MARK: What follows

        var nextKind: NextKind
        /// nil when `nextKind == .finish`.
        var nextMoveName: String?
        /// The next move's prescription: "3 × 8 · 100 kg", or "Set 2 · 30 kg × 10" for a superset
        /// partner already mid-flight. nil when `nextKind == .finish`.
        var nextLine: String?

        // MARK: The session

        /// Every set of the whole session, in execution order — the card's bottom bar.
        /// At most `sessionBarCap` entries: the cap is an INVARIANT, not an argument check, so it
        /// survives a later mutation (`finishedState(from:)` edits a state in place) and not only
        /// the initializer. Re-assigning inside `didSet` does not recurse in Swift.
        var sessionStates: [SetState] {
            didSet { sessionStates = ContentState.capped(sessionStates) }
        }
        /// When the session started. Feeds `Text(timerInterval:)`, so ELAPSED ticks untouched.
        var startedAt: Date
        /// The newest `loggedAt` in the session — the SINCE SET clock's anchor. nil before the
        /// first set lands, which the card renders as "—".
        var lastLoggedAt: Date?
        var loggedCount: Int
        var setsLeft: Int
        /// Every set is logged or skipped; the card shows the completion face.
        var isComplete: Bool

        var schemaVersion: Int

        init(
            moveName: String,
            moveTag: String,
            movePosition: String,
            targetLine: String,
            setStates: [SetState],
            nextKind: NextKind,
            nextMoveName: String? = nil,
            nextLine: String? = nil,
            sessionStates: [SetState],
            startedAt: Date,
            lastLoggedAt: Date? = nil,
            loggedCount: Int,
            setsLeft: Int,
            isComplete: Bool,
            schemaVersion: Int = ContentState.currentSchemaVersion
        ) {
            self.moveName = moveName
            self.moveTag = moveTag
            self.movePosition = movePosition
            self.targetLine = targetLine
            self.setStates = setStates
            self.nextKind = nextKind
            self.nextMoveName = nextMoveName
            self.nextLine = nextLine
            self.sessionStates = ContentState.capped(sessionStates)
            self.startedAt = startedAt
            self.lastLoggedAt = lastLoggedAt
            self.loggedCount = loggedCount
            self.setsLeft = setsLeft
            self.isComplete = isComplete
            self.schemaVersion = schemaVersion
        }

        /// Keep the TAIL of the bar: a long session's early sets are settled history, while the
        /// cursor and everything still owed live at the end.
        static func capped(_ states: [SetState]) -> [SetState] {
            guard states.count > sessionBarCap else { return states }
            return Array(states.suffix(sessionBarCap))
        }
    }
}
