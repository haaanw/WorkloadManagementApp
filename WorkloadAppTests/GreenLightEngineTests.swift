import XCTest
@testable import workload_management

/// Phase 45 Plan 01 (Task 3) — `GreenLightEngine` green-light / activation / retention math.
///
/// Pure over `[VerdictEvent]` with an INJECTED `asOf` + `calendar` (no baked `.now`). VerdictEvent
/// is a `@Model` but is constructed standalone here (no container needed) since the engine only reads
/// its composite fields. The engine and VerdictEvent are not `@MainActor`, so a plain XCTestCase with
/// method-local events is safe (no deinit-SIGABRT surface).
final class GreenLightEngineTests: XCTestCase {

    private let cal = Calendar.current

    /// Build a standalone composite event. `dayOffset` is days before `base` for planDate; decidedAt
    /// is that day + 10h (deterministic intra-day stamp).
    private func event(
        base: Date,
        dayOffset: Int,
        differed: Bool,
        action: String,
        outcome: String?
    ) -> VerdictEvent {
        let planDay = cal.date(byAdding: .day, value: -dayOffset, to: base)!
        let decidedAt = cal.date(byAdding: .hour, value: 10, to: cal.startOfDay(for: planDay))!
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
            outcomeRaw: outcome
        )
    }

    // MARK: - Green-light rate

    func test_greenLightRate_differingActedRight_overDifferingDays() {
        let base = cal.startOfDay(for: .now)
        let events = [
            event(base: base, dayOffset: 4, differed: false, action: "accepted", outcome: "right"), // excluded (non-differing)
            event(base: base, dayOffset: 3, differed: true, action: "accepted", outcome: "right"),   // green
            event(base: base, dayOffset: 2, differed: true, action: "feelRough", outcome: "right"),  // green (acted ≠ keptPlan)
            event(base: base, dayOffset: 1, differed: true, action: "accepted", outcome: "wrong")    // not green
        ]
        let m = GreenLightEngine.compute(events: events, asOf: base, calendar: cal)
        XCTAssertEqual(m.differingDays, 3, "non-differing event excluded from denominator")
        XCTAssertEqual(m.greenLightRate ?? -1, 2.0 / 3.0, accuracy: 0.0001)
    }

    func test_differingDays_collapseSameStartOfDay() {
        let base = cal.startOfDay(for: .now)
        // Two differed events on the SAME planDate day ⇒ one differing day.
        let events = [
            event(base: base, dayOffset: 3, differed: true, action: "accepted", outcome: "right"),
            event(base: base, dayOffset: 3, differed: true, action: "accepted", outcome: "wrong"),
            event(base: base, dayOffset: 1, differed: true, action: "accepted", outcome: "right")
        ]
        let m = GreenLightEngine.compute(events: events, asOf: base, calendar: cal)
        XCTAssertEqual(m.differingDays, 2, "two differed events on the same day collapse to one day")
    }

    func test_keptPlan_excludedFromGreenNumerator() {
        let base = cal.startOfDay(for: .now)
        let events = [
            event(base: base, dayOffset: 2, differed: true, action: "keptPlan", outcome: "right"), // denom only
            event(base: base, dayOffset: 1, differed: true, action: "accepted", outcome: "right")  // green
        ]
        let m = GreenLightEngine.compute(events: events, asOf: base, calendar: cal)
        XCTAssertEqual(m.differingDays, 2)
        XCTAssertEqual(m.greenLightRate ?? -1, 1.0 / 2.0, accuracy: 0.0001)
    }

    func test_greenLightRate_nilWhenNoDifferingDays() {
        let base = cal.startOfDay(for: .now)
        XCTAssertNil(GreenLightEngine.compute(events: [], asOf: base, calendar: cal).greenLightRate)
        let onlyNonDiffering = [
            event(base: base, dayOffset: 1, differed: false, action: "keptPlan", outcome: "right")
        ]
        let m = GreenLightEngine.compute(events: onlyNonDiffering, asOf: base, calendar: cal)
        XCTAssertNil(m.greenLightRate, "no differing days ⇒ honest nil, not 0")
        XCTAssertEqual(m.differingDays, 0)
    }

    // MARK: - Activation rate

    func test_activationRate_actedOverTotal() {
        let base = cal.startOfDay(for: .now)
        let events = [
            event(base: base, dayOffset: 4, differed: true, action: "accepted", outcome: nil),
            event(base: base, dayOffset: 3, differed: true, action: "feelStrong", outcome: nil),
            event(base: base, dayOffset: 2, differed: false, action: "accepted", outcome: nil),
            event(base: base, dayOffset: 1, differed: true, action: "keptPlan", outcome: nil)
        ]
        let m = GreenLightEngine.compute(events: events, asOf: base, calendar: cal)
        XCTAssertEqual(m.totalEvents, 4)
        XCTAssertEqual(m.activationRate ?? -1, 0.75, accuracy: 0.0001, "3 acted / 4 total")
    }

    func test_activationRate_nilWhenNoEvents() {
        let base = cal.startOfDay(for: .now)
        XCTAssertNil(GreenLightEngine.compute(events: [], asOf: base, calendar: cal).activationRate)
    }

    // MARK: - Retention (injected asOf/calendar)

    func test_day7Retention_trueWhenEventOnOrAfterHorizon() {
        let firstDay = cal.startOfDay(for: cal.date(byAdding: .day, value: -10, to: .now)!)
        let first = event(base: firstDay, dayOffset: 0, differed: true, action: "accepted", outcome: "right")
        // An event exactly 7 days after the first day.
        let atDay7Plan = cal.date(byAdding: .day, value: 7, to: firstDay)!
        let atDay7 = VerdictEvent(
            decidedAt: cal.date(byAdding: .hour, value: 10, to: atDay7Plan)!,
            planDate: atDay7Plan, verdictKindRaw: "go", plannedTopSetKg: 100,
            actionRaw: "accepted", regionRaw: "legs", reasonLine: "x"
        )
        let asOf = cal.date(byAdding: .day, value: 8, to: firstDay)!
        let m = GreenLightEngine.compute(events: [first, atDay7], asOf: asOf, calendar: cal)
        XCTAssertEqual(m.day7Retention, true)
    }

    func test_day7Retention_nilWhenAsOfBeforeHorizon() {
        let firstDay = cal.startOfDay(for: .now)
        let first = event(base: firstDay, dayOffset: 0, differed: true, action: "accepted", outcome: "right")
        let asOf = cal.date(byAdding: .day, value: 3, to: firstDay)! // before first+7d
        let m = GreenLightEngine.compute(events: [first], asOf: asOf, calendar: cal)
        XCTAssertNil(m.day7Retention, "cannot know retention before the horizon is reached")
    }

    func test_day7Retention_falseWhenHorizonPassedButNoLaterEvent() {
        let firstDay = cal.startOfDay(for: cal.date(byAdding: .day, value: -10, to: .now)!)
        let first = event(base: firstDay, dayOffset: 0, differed: true, action: "accepted", outcome: "right")
        let asOf = cal.date(byAdding: .day, value: 9, to: firstDay)! // past horizon, no event ≥ day7
        let m = GreenLightEngine.compute(events: [first], asOf: asOf, calendar: cal)
        XCTAssertEqual(m.day7Retention, false)
    }

    func test_day30Retention_horizonLogic() {
        let firstDay = cal.startOfDay(for: cal.date(byAdding: .day, value: -40, to: .now)!)
        let first = event(base: firstDay, dayOffset: 0, differed: true, action: "accepted", outcome: "right")
        let atDay30Plan = cal.date(byAdding: .day, value: 31, to: firstDay)!
        let atDay30 = VerdictEvent(
            decidedAt: cal.date(byAdding: .hour, value: 10, to: atDay30Plan)!,
            planDate: atDay30Plan, verdictKindRaw: "go", plannedTopSetKg: 100,
            actionRaw: "accepted", regionRaw: "legs", reasonLine: "x"
        )
        // asOf well past 30d horizon, with a later event ⇒ true.
        let asOf = cal.date(byAdding: .day, value: 35, to: firstDay)!
        XCTAssertEqual(GreenLightEngine.compute(events: [first, atDay30], asOf: asOf, calendar: cal).day30Retention, true)
        // asOf before 30d horizon ⇒ nil.
        let early = cal.date(byAdding: .day, value: 20, to: firstDay)!
        XCTAssertNil(GreenLightEngine.compute(events: [first], asOf: early, calendar: cal).day30Retention)
    }
}
