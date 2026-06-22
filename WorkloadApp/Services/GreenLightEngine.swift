import Foundation

/// Phase 45 Plan 01 — the pure green-light / activation / retention engine (METRIC-02).
///
/// Static, stateless, no side effects (mirrors `WorkloadCalculator` / `RecoveryScoreEngine`). It reads
/// ONLY the composite fields of `[VerdictEvent]` — never a raw recovery signal. Every date computation
/// is driven by the INJECTED `asOf` + `calendar`; the engine never calls `.now` / `.current` itself,
/// so it is deterministic and unit-testable (the explicit anti-pattern called out in 45-CONTEXT).
struct GreenLightEngine {

    /// The composite measurement readout the Profile surface (Plan 45-03) binds.
    struct GreenLightMetrics: Equatable {
        /// Differing-verdict days where the athlete acted on the suggestion AND reported it was right,
        /// over all differing-verdict days. `nil` when there is no differing day yet (honest "no
        /// signal" — never a fabricated 0).
        let greenLightRate: Double?
        /// Distinct start-of-day days on which the suggestion differed from the plan.
        let differingDays: Int
        /// Events the athlete acted on (action ≠ keptPlan) over all events. `nil` when no events.
        let activationRate: Double?
        let totalEvents: Int
        /// `true` once an event lands on/after firstDay+7d; `false` once that horizon has passed with
        /// no such event; `nil` while the horizon has not yet been reached (cannot know yet).
        let day7Retention: Bool?
        /// Same semantics at the 30-day horizon.
        let day30Retention: Bool?
    }

    private static let actionKeptPlan = "keptPlan"
    private static let outcomeRight = "right"

    static func compute(events: [VerdictEvent], asOf: Date, calendar: Calendar) -> GreenLightMetrics {
        let totalEvents = events.count

        // ACTIVATION: acted (action ≠ keptPlan) over total.
        let activationRate: Double?
        if totalEvents == 0 {
            activationRate = nil
        } else {
            let acted = events.filter { $0.actionRaw != actionKeptPlan }.count
            activationRate = Double(acted) / Double(totalEvents)
        }

        // GREEN-LIGHT: collapse differed events to days; numerator = days whose representative event
        // was acted on AND reported right.
        let differingEvents = events.filter { $0.differed }
        let byDay = Dictionary(grouping: differingEvents) { calendar.startOfDay(for: $0.planDate) }
        let differingDays = byDay.count
        let greenLightRate: Double?
        if differingDays == 0 {
            greenLightRate = nil
        } else {
            let greenDays = byDay.values.filter { dayEvents in
                // Representative = the latest decision of that day.
                guard let rep = dayEvents.max(by: { $0.decidedAt < $1.decidedAt }) else { return false }
                return rep.actionRaw != actionKeptPlan && rep.outcomeRaw == outcomeRight
            }.count
            greenLightRate = Double(greenDays) / Double(differingDays)
        }

        // RETENTION: relative to the first decision day, at the 7- and 30-day horizons.
        let day7Retention = retention(events: events, horizonDays: 7, asOf: asOf, calendar: calendar)
        let day30Retention = retention(events: events, horizonDays: 30, asOf: asOf, calendar: calendar)

        return GreenLightMetrics(
            greenLightRate: greenLightRate,
            differingDays: differingDays,
            activationRate: activationRate,
            totalEvents: totalEvents,
            day7Retention: day7Retention,
            day30Retention: day30Retention
        )
    }

    /// `nil` if no events or the horizon has not been reached as of `asOf`; otherwise `true` iff some
    /// event's `decidedAt` is on/after firstDay+horizon.
    private static func retention(
        events: [VerdictEvent],
        horizonDays: Int,
        asOf: Date,
        calendar: Calendar
    ) -> Bool? {
        guard let firstDecided = events.map(\.decidedAt).min() else { return nil }
        let firstDay = calendar.startOfDay(for: firstDecided)
        guard let horizon = calendar.date(byAdding: .day, value: horizonDays, to: firstDay) else { return nil }
        if asOf < horizon { return nil }   // too early to know
        return events.contains { $0.decidedAt >= horizon }
    }
}
