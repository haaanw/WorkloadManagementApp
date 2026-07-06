import Foundation

/// v2.1 Track 1 item 6 — the pure eligibility + aggregates engine for the n=1 dogfood
/// "felt right?" capture (pre-registered protocol, `.planning/notes/dogfood-protocol-n1.md`).
///
/// Static, stateless, no side effects (mirrors `GreenLightEngine`). It reads ONLY the composite
/// fields of `[VerdictEvent]` — never a raw recovery signal. Every date computation is driven by
/// the INJECTED `asOf` + `calendar`; the engine never calls `.now` / `.current` itself.
///
/// ## Eligibility semantics (criterion 3: judged next-day, logged same-day, never retro-rated)
/// The prompt is eligible for EXACTLY ONE calendar day: the day after a differing-verdict day
/// (verdict ≠ plan-as-written, regardless of whether the athlete followed it).
/// - Same day as the verdict ⇒ NOT eligible (too early to judge).
/// - 2+ days later ⇒ NOT eligible (missed — absence IS the record; no back-fill UI, ever).
/// - Day already answered ⇒ NOT eligible (write-once; the first answer is immutable).
/// One prompt per day: multiple differed decisions on the same `planDate` collapse to the day's
/// representative — the LATEST decision of that day (same collapse rule as `GreenLightEngine`).
struct FeltRightPromptEngine {

    private static let actionKeptPlan = "keptPlan"
    private static let feltRight = "right"

    // MARK: - Next-day prompt eligibility

    /// The single event (yesterday's representative differing-verdict decision) the "felt right?"
    /// prompt should ask about as of `asOf` — or `nil` when nothing is eligible today.
    static func eligibleEvent(
        events: [VerdictEvent],
        asOf: Date,
        calendar: Calendar
    ) -> VerdictEvent? {
        let today = calendar.startOfDay(for: asOf)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return nil }
        let yesterdaysDiffered = events.filter {
            $0.differed && calendar.startOfDay(for: $0.planDate) == yesterday
        }
        // Representative = the latest decision of that day (mirrors GreenLightEngine).
        guard let representative = yesterdaysDiffered.max(by: { $0.decidedAt < $1.decidedAt }) else {
            return nil
        }
        return representative.feltRightRaw == nil ? representative : nil
    }

    // MARK: - Pre-registered criteria aggregates (criteria 1–3)

    /// The founder-readable dogfood readout. Day-level: differed events collapse to days; each
    /// day's representative (latest decision) carries the day's action + felt-right answer.
    struct DogfoodSummary: Equatable {
        /// Criterion 1 (≥8): distinct days where the verdict differed from the plan-as-written.
        let differingDays: Int
        /// Differing days whose representative was acted on (action ≠ keptPlan).
        let followedDays: Int
        /// Criterion 2 (≥60%): followedDays / differingDays. `nil` when no differing day yet
        /// (honest "no signal" — never a fabricated 0).
        let followedRate: Double?
        /// Followed differing days with a recorded next-day "felt right?" answer (any of the three).
        let ratedDays: Int
        /// Followed differing days whose next-day window has fully passed with no answer.
        /// Absence is the record — these never become ratable again.
        let missedDays: Int
        /// Criterion 3 (≥70%): "right" answers / ratedDays. "unsure" and "wrong" count against.
        /// `nil` when nothing has been rated yet.
        let feltRightRate: Double?
    }

    static func summary(
        events: [VerdictEvent],
        asOf: Date,
        calendar: Calendar
    ) -> DogfoodSummary {
        let today = calendar.startOfDay(for: asOf)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        let byDay = Dictionary(grouping: events.filter(\.differed)) {
            calendar.startOfDay(for: $0.planDate)
        }
        let differingDays = byDay.count

        // Per-day representative = the latest decision of that day.
        let representatives: [(day: Date, event: VerdictEvent)] = byDay.compactMap { day, dayEvents in
            dayEvents.max(by: { $0.decidedAt < $1.decidedAt }).map { (day, $0) }
        }

        let followed = representatives.filter { $0.event.actionRaw != actionKeptPlan }
        let followedDays = followed.count
        let followedRate = differingDays == 0 ? nil : Double(followedDays) / Double(differingDays)

        let rated = followed.filter { $0.event.feltRightRaw != nil }
        let ratedDays = rated.count
        // Missed = the next-day window is over (day strictly before yesterday) and no answer landed.
        let missedDays = followed.filter { $0.event.feltRightRaw == nil && $0.day < yesterday }.count
        let feltRightCount = rated.filter { $0.event.feltRightRaw == feltRight }.count
        let feltRightRate = ratedDays == 0 ? nil : Double(feltRightCount) / Double(ratedDays)

        return DogfoodSummary(
            differingDays: differingDays,
            followedDays: followedDays,
            followedRate: followedRate,
            ratedDays: ratedDays,
            missedDays: missedDays,
            feltRightRate: feltRightRate
        )
    }
}
