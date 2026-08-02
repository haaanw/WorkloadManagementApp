import XCTest
@testable import workload_management

/// Sleep v2 Phase S2 — the stateless state folder (`SleepStateBuilder`).
///
/// Pure-math tests only: no HealthKit, no SwiftData — every test drives the builder's
/// static functions over the plain `State` value mirror, the same way `BaselineEngineTests`
/// drives `SignalState`. The load-bearing groups are the §4 need-learning rules (gate /
/// bounds / deadband / hysteresis / freeze / source reset) and the prequential
/// `makeInput` assembly the engine's contract depends on.
final class SleepStateBuilderTests: XCTestCase {

    private typealias Builder = SleepStateBuilder
    private typealias Engine = SleepScoreEngine

    // MARK: - Fixed clock-free scaffolding

    /// Fixed UTC gregorian calendar (the DayBucketer test precedent) — no local-timezone
    /// flakiness, no clock access.
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// Midnight UTC of an arbitrary fixed epoch day (2026-01-01), day 0 of every test.
    private var day0: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 1
        components.timeZone = TimeZone(identifier: "UTC")
        return calendar.date(from: components)!
    }

    private func day(_ index: Int) -> Date {
        calendar.date(byAdding: .day, value: index, to: day0)!
    }

    /// A night that ENDS on the morning of `day(index)`: asleep 23:00 (day index−1) →
    /// 07:00 (day index) by default. Midpoint 03:00 = +180 min from wake-day midnight.
    private func night(
        dayIndex: Int,
        tst: Double = 450,
        deep: Double? = 60,
        rem: Double? = 90,
        awake: Double? = 20,
        inBed: Double? = 480,
        startHourOffset: Double = -1.0,   // hours relative to wake-day midnight (23:00 = −1)
        durationHours: Double = 8.0,
        sourceID: String? = "com.apple.health"
    ) -> Builder.Night {
        let start = day(dayIndex).addingTimeInterval(startHourOffset * 3600)
        let end = start.addingTimeInterval(durationHours * 3600)
        return Builder.Night(
            bucketedDate: day(dayIndex),
            tstMinutes: tst,
            deepMinutes: deep,
            remMinutes: rem,
            awakeMinutes: awake,
            inBedMinutes: inBed,
            sessionStart: start,
            sessionEnd: end,
            sourceID: sourceID
        )
    }

    /// Fold `count` uniform nights starting at `firstDay`, returning the final state.
    private func foldNights(
        into state: Builder.State = Builder.State(),
        count: Int,
        firstDay: Int = 1,
        tst: Double = 450,
        needTonight: Double? = 450,
        latched: Set<Engine.SleepProfile> = []
    ) -> Builder.State {
        var current = state
        for i in 0..<count {
            current = Builder.fold(
                state: current,
                night: night(dayIndex: firstDay + i, tst: tst),
                needTonightMinutes: needTonight,
                latchedProfiles: latched,
                calendar: calendar
            )
        }
        return current
    }

    // MARK: - Midpoint reduction

    func test_midpointMinutes_isRelativeToWakeDayMidnight() {
        // 23:00 → 07:00: midpoint 03:00 = +180 min.
        let n = night(dayIndex: 1)
        XCTAssertEqual(
            Builder.midpointMinutes(
                sessionStart: n.sessionStart,
                sessionEnd: n.sessionEnd,
                calendar: calendar
            ),
            180,
            accuracy: 1e-9
        )
    }

    func test_midpointMinutes_handlesMidnightStraddle_withoutWrap() {
        // 21:00 → 01:00: midpoint 23:00 = −60 min relative to the wake-day midnight —
        // continuous (negative), never a 1380-style modular wrap.
        let start = day(1).addingTimeInterval(21 * 3600)
        let end = day(2).addingTimeInterval(1 * 3600)
        XCTAssertEqual(
            Builder.midpointMinutes(sessionStart: start, sessionEnd: end, calendar: calendar),
            -60,
            accuracy: 1e-9
        )
        // 23:00 → 01:00 → midpoint exactly midnight = 0.
        let start2 = day(1).addingTimeInterval(23 * 3600)
        let end2 = day(2).addingTimeInterval(1 * 3600)
        XCTAssertEqual(
            Builder.midpointMinutes(sessionStart: start2, sessionEnd: end2, calendar: calendar),
            0,
            accuracy: 1e-9
        )
    }

    // MARK: - Stage EWMA fold math (H-21: BaselineEngine's sleep half-life)

    func test_stageEWMA_firstFoldSeeds() {
        let folded = Builder.fold(
            state: Builder.State(),
            night: night(dayIndex: 1, deep: 62, rem: 95),
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        XCTAssertEqual(folded.deepMu, 62)
        XCTAssertEqual(folded.deepCount, 1)
        XCTAssertEqual(folded.remMu, 95)
        XCTAssertEqual(folded.remCount, 1)
    }

    func test_stageEWMA_foldMatchesLambdaFormula() {
        let seeded = Builder.fold(
            state: Builder.State(),
            night: night(dayIndex: 1, deep: 60, rem: 90),
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        let folded = Builder.fold(
            state: seeded,
            night: night(dayIndex: 2, deep: 80, rem: 70),
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        let lambda = BaselineEngine.lambda(halfLifeDays: Builder.stageHalfLifeDays)
        XCTAssertEqual(folded.deepMu!, (1 - lambda) * 60 + lambda * 80, accuracy: 1e-9)
        XCTAssertEqual(folded.remMu!, (1 - lambda) * 90 + lambda * 70, accuracy: 1e-9)
        XCTAssertEqual(folded.deepCount, 2)
    }

    func test_stageEWMA_unstagedNightDoesNotFold() {
        let seeded = Builder.fold(
            state: Builder.State(),
            night: night(dayIndex: 1, deep: 60, rem: 90),
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        let folded = Builder.fold(
            state: seeded,
            night: night(dayIndex: 2, deep: nil, rem: nil),
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        XCTAssertEqual(folded.deepMu, 60)
        XCTAssertEqual(folded.deepCount, 1)
        XCTAssertEqual(folded.remCount, 1)
    }

    // MARK: - Midpoint SD window (H-23)

    func test_midpointSD_nilBelowMinimumNights() {
        XCTAssertNil(Builder.midpointSD([180, 190, 200, 170]))  // 4 < 5
        XCTAssertNotNil(Builder.midpointSD([180, 190, 200, 170, 210]))
    }

    func test_midpointSD_isSampleSD() {
        // [0, 30, 60, 90, 120]: mean 60, SS = 9000, sample variance 2250.
        XCTAssertEqual(Builder.midpointSD([0, 30, 60, 90, 120])!, 2250.0.squareRoot(), accuracy: 1e-9)
    }

    func test_midpointBuffer_capsAtFourteenNights() {
        let state = foldNights(count: 20)
        XCTAssertEqual(state.midpointBuffer.count, Builder.midpointBufferLength)
        XCTAssertEqual(state.irregularFlags14.count, Builder.midpointBufferLength)
    }

    func test_makeInput_midpointStats_arePreFold_andNilOnThinBuffer() {
        // 3 folded nights: below the 5-night minimum → SD and deviation nil.
        let thin = foldNights(count: 3)
        let thinInput = Builder.makeInput(state: thin, night: night(dayIndex: 4), calendar: calendar)
        XCTAssertNil(thinInput.state.midpointSD14Minutes)
        XCTAssertNil(thinInput.state.midpointDeviationMinutes)

        // 6 folded identical nights: SD 0, deviation of an identical night 0.
        let full = foldNights(count: 6)
        let input = Builder.makeInput(state: full, night: night(dayIndex: 7), calendar: calendar)
        XCTAssertEqual(input.state.midpointSD14Minutes!, 0, accuracy: 1e-9)
        XCTAssertEqual(input.state.midpointDeviationMinutes!, 0, accuracy: 1e-9)
    }

    // MARK: - Rhythm break (§9.2) and the chronic counters

    func test_rhythmBreak_firesOnLargeDeviation_andReadsZeroDaysSince() {
        let stable = foldNights(count: 6)  // midpoints all +180
        // Tonight shifted +4 h: midpoint 420, deviation 240 > max(2×0, 90).
        let shifted = night(dayIndex: 7, startHourOffset: 3.0)
        let input = Builder.makeInput(state: stable, night: shifted, calendar: calendar)
        XCTAssertEqual(input.state.daysSinceRhythmBreak, 0)

        // Folding the shifted night records the break; the next ordinary night reads 1.
        let folded = Builder.fold(
            state: stable,
            night: shifted,
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        XCTAssertEqual(folded.nightsSinceRhythmBreak, 0)
        let nextInput = Builder.makeInput(state: folded, night: night(dayIndex: 8), calendar: calendar)
        XCTAssertEqual(nextInput.state.daysSinceRhythmBreak, 1)
    }

    func test_rhythmBreak_neverFiresWithoutDeviation() {
        XCTAssertFalse(Builder.isRhythmBreak(deviation: nil, sd14: nil))
        XCTAssertFalse(Builder.isRhythmBreak(deviation: 89, sd14: nil))   // under the 90 floor
        XCTAssertTrue(Builder.isRhythmBreak(deviation: 91, sd14: nil))
        // With a wide SD the threshold is 2×SD, not the floor.
        XCTAssertFalse(Builder.isRhythmBreak(deviation: 110, sd14: 60))   // 110 < 120
        XCTAssertTrue(Builder.isRhythmBreak(deviation: 130, sd14: 60))
    }

    func test_chronicExitCounter_incrementsBelowExitSD_resetsAbove() {
        // Six tight nights: SD14 ≈ 0 < 50 → the counter grows once SD becomes valid.
        let tight = foldNights(count: 6)
        XCTAssertGreaterThan(tight.nightsBelowChronicExitSD, 0)

        // A wildly shifted night pushes the post-fold SD over 50 → reset to 0.
        let broken = Builder.fold(
            state: tight,
            night: night(dayIndex: 7, startHourOffset: 4.0),
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        XCTAssertEqual(broken.nightsBelowChronicExitSD, 0)
    }

    func test_irregularFlags_setWhenSDExceedsEntryThreshold() {
        // Alternate ±4 h so the running SD14 exceeds 75 min once enough nights exist.
        var state = Builder.State()
        for i in 1...10 {
            let offset = (i % 2 == 0) ? 3.0 : -5.0
            state = Builder.fold(
                state: state,
                night: night(dayIndex: i, startHourOffset: offset),
                needTonightMinutes: 450,
                latchedProfiles: [],
                calendar: calendar
            )
        }
        let irregularCount = Int(state.irregularFlags14.reduce(0, +).rounded())
        XCTAssertGreaterThan(irregularCount, 0)
        let input = Builder.makeInput(state: state, night: night(dayIndex: 11), calendar: calendar)
        XCTAssertEqual(input.state.irregularNightsIn14, irregularCount)
    }

    // MARK: - Debt accumulation (§4 / §9.2)

    func test_deficitBuffer_recordsShortfall_capsAtSevenNights() {
        let state = foldNights(count: 9, tst: 400, needTonight: 480)
        XCTAssertEqual(state.deficitBuffer7.count, Builder.deficitBufferLength)
        XCTAssertEqual(state.deficitBuffer7.last!, 80, accuracy: 1e-9)
    }

    func test_deficit_zeroWhenNeedMet_andDebtCappedAtSixHours() {
        let met = foldNights(count: 3, tst: 500, needTonight: 450)
        XCTAssertEqual(met.deficitBuffer7.reduce(0, +), 0, accuracy: 1e-9)

        // Seven 100-min deficits = 700 min raw; the engine input caps at 360 (§9.2).
        let indebted = foldNights(count: 7, tst: 350, needTonight: 450)
        let input = Builder.makeInput(state: indebted, night: night(dayIndex: 8), calendar: calendar)
        XCTAssertEqual(input.state.sleepDebt7Minutes, Builder.debt7CapMinutes, accuracy: 1e-9)
    }

    func test_deficit_fallsBackToStoredNeed_thenColdStart_whenEngineGaveNoNeed() {
        // Tier D/E night (needTonightMinutes nil) + stored need 480 → deficit vs 480.
        var state = Builder.State(needBaseMinutes: 480)
        state = Builder.fold(
            state: state,
            night: night(dayIndex: 1, tst: 400),
            needTonightMinutes: nil,
            latchedProfiles: [],
            calendar: calendar
        )
        XCTAssertEqual(state.deficitBuffer7.last!, 80, accuracy: 1e-9)

        // No stored need → §4 cold start (7.5 h = 450).
        var cold = Builder.State()
        cold = Builder.fold(
            state: cold,
            night: night(dayIndex: 1, tst: 400),
            needTonightMinutes: nil,
            latchedProfiles: [],
            calendar: calendar
        )
        XCTAssertEqual(cold.deficitBuffer7.last!, 50, accuracy: 1e-9)
    }

    // MARK: - Need learning: the 28-night gate (§4)

    func test_needGate_noPersonalizationBeforeTwentyEightNights() {
        let below = foldNights(count: Builder.needGateNights - 1, tst: 480)
        XCTAssertNil(below.needBaseMinutes)

        let atGate = foldNights(count: Builder.needGateNights, tst: 480)
        XCTAssertNotNil(atGate.needBaseMinutes)
        XCTAssertEqual(atGate.needBaseMinutes!, 480, accuracy: 1e-9)  // p75 of uniform 480s
    }

    // MARK: - Need learning: bounds (§4)

    func test_needBounds_clampToSixPointFiveAndNinePointFiveHours() {
        let long = foldNights(count: Builder.needGateNights, tst: 620)
        XCTAssertEqual(long.needBaseMinutes!, Builder.needUpperBoundMinutes, accuracy: 1e-9)

        let short = foldNights(count: Builder.needGateNights, tst: 300)
        XCTAssertEqual(short.needBaseMinutes!, Builder.needLowerBoundMinutes, accuracy: 1e-9)
    }

    // MARK: - Need learning: deadband (§4)

    func test_needDeadband_ignoresRecomputeWithinFifteenMinutes() {
        // Stored 450, estimate 460: |Δ| = 10 ≤ 15 → unchanged, but the weekly recompute
        // still stamps (§4 cadence).
        let state = Builder.State(
            tstBuffer: Array(repeating: 460, count: Builder.needGateNights),
            needBaseMinutes: 450,
            needUpdatedAt: day(-10)
        )
        let folded = Builder.fold(
            state: state,
            night: night(dayIndex: 1, tst: 460),
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        XCTAssertEqual(folded.needBaseMinutes!, 450, accuracy: 1e-9)
        XCTAssertEqual(folded.needUpdatedAt, day(1))
    }

    func test_needDeadband_boundary_fifteenInside_sixteenOutside() {
        // §4: "ignore recomputed values WITHIN 15 min" — |Δ| = 15 is inside (no move).
        let atBoundary = Builder.State(
            tstBuffer: Array(repeating: 465, count: Builder.needGateNights),
            needBaseMinutes: 450,
            needUpdatedAt: day(-10)
        )
        let inside = Builder.fold(
            state: atBoundary,
            night: night(dayIndex: 1, tst: 465),
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        XCTAssertEqual(inside.needBaseMinutes!, 450, accuracy: 1e-9)

        // |Δ| = 16 is outside — moves by the 10-min hysteresis step.
        let pastBoundary = Builder.State(
            tstBuffer: Array(repeating: 466, count: Builder.needGateNights),
            needBaseMinutes: 450,
            needUpdatedAt: day(-10)
        )
        let outside = Builder.fold(
            state: pastBoundary,
            night: night(dayIndex: 1, tst: 466),
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        XCTAssertEqual(outside.needBaseMinutes!, 460, accuracy: 1e-9)
    }

    // MARK: - Need learning: ±10 min/week hysteresis (§4)

    func test_needHysteresis_movesAtMostTenMinutesPerUpdate() {
        // Stored 450, estimate 480: |Δ| = 30 > 15 → move exactly +10.
        let state = Builder.State(
            tstBuffer: Array(repeating: 480, count: Builder.needGateNights),
            needBaseMinutes: 450,
            needUpdatedAt: day(-10)
        )
        let folded = Builder.fold(
            state: state,
            night: night(dayIndex: 1, tst: 480),
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        XCTAssertEqual(folded.needBaseMinutes!, 460, accuracy: 1e-9)

        // Downward mirror: stored 480, estimate 450 → −10.
        let down = Builder.State(
            tstBuffer: Array(repeating: 450, count: Builder.needGateNights),
            needBaseMinutes: 480,
            needUpdatedAt: day(-10)
        )
        let foldedDown = Builder.fold(
            state: down,
            night: night(dayIndex: 1, tst: 450),
            needTonightMinutes: 480,
            latchedProfiles: [],
            calendar: calendar
        )
        XCTAssertEqual(foldedDown.needBaseMinutes!, 470, accuracy: 1e-9)
    }

    // MARK: - Need learning: weekly cadence (§4)

    func test_needCadence_updatesWeekly_notNightly() {
        let state = Builder.State(
            tstBuffer: Array(repeating: 480, count: Builder.needGateNights),
            needBaseMinutes: 450,
            needUpdatedAt: day(1)
        )
        // 3 days later: not due — no movement, no re-stamp.
        let early = Builder.fold(
            state: state,
            night: night(dayIndex: 4, tst: 480),
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        XCTAssertEqual(early.needBaseMinutes!, 450, accuracy: 1e-9)
        XCTAssertEqual(early.needUpdatedAt, day(1))

        // 7 days later: due — moves by the hysteresis step and re-stamps.
        let weekly = Builder.fold(
            state: state,
            night: night(dayIndex: 8, tst: 480),
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        XCTAssertEqual(weekly.needBaseMinutes!, 460, accuracy: 1e-9)
        XCTAssertEqual(weekly.needUpdatedAt, day(8))
    }

    // MARK: - Need learning: freeze in CHRONIC_IRREGULAR (§7 Q9)

    func test_needLearning_freezesWhileChronicIrregularLatched() {
        let state = Builder.State(
            tstBuffer: Array(repeating: 480, count: Builder.needGateNights),
            needBaseMinutes: 450,
            needUpdatedAt: day(-10)
        )
        let frozen = Builder.fold(
            state: state,
            night: night(dayIndex: 1, tst: 480),
            needTonightMinutes: 450,
            latchedProfiles: [.chronicIrregular],
            calendar: calendar
        )
        XCTAssertTrue(frozen.needFrozen)
        XCTAssertEqual(frozen.needBaseMinutes!, 450, accuracy: 1e-9)
        // Frozen weeks do NOT stamp — the first unfrozen due night updates immediately.
        XCTAssertEqual(frozen.needUpdatedAt, day(-10))

        let thawed = Builder.fold(
            state: frozen,
            night: night(dayIndex: 2, tst: 480),
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        XCTAssertFalse(thawed.needFrozen)
        XCTAssertEqual(thawed.needBaseMinutes!, 460, accuracy: 1e-9)
    }

    // MARK: - Source-change reset (§4 reset-on-discontinuity, H-20)

    func test_sourceChange_restartsStageBaselines_andRegatesNeed() {
        var state = foldNights(count: 30)  // converged on com.apple.health
        XCTAssertNotNil(state.needBaseMinutes)
        XCTAssertGreaterThanOrEqual(state.deepCount, 30)

        let learnedNeed = state.needBaseMinutes
        state = Builder.fold(
            state: state,
            night: night(dayIndex: 31, deep: 40, rem: 70, sourceID: "com.ouraring.oura"),
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        XCTAssertEqual(state.dominantSourceID, "com.ouraring.oura")
        // Stage baselines restarted, then seeded by the new-source night.
        XCTAssertEqual(state.deepMu!, 40, accuracy: 1e-9)
        XCTAssertEqual(state.deepCount, 1)
        XCTAssertEqual(state.remCount, 1)
        // Need FROZEN via the re-gated buffer: only the new-source night remains, so the
        // 28-night gate blocks updates while the stored value keeps serving.
        XCTAssertEqual(state.tstBuffer.count, 1)
        XCTAssertEqual(state.needBaseMinutes, learnedNeed)
        XCTAssertEqual(state.nightsSinceSourceChange, 0)
    }

    func test_sourceChangeNight_vetoesCarriedBaselines_andReadsUnstable() {
        let state = foldNights(count: 20)  // deep baseline converged on com.apple.health
        let switched = night(dayIndex: 21, sourceID: "com.ouraring.oura")
        let input = Builder.makeInput(state: state, night: switched, calendar: calendar)
        XCTAssertNil(input.deepBaselineMinutes)   // old-source EWMA carries no authority
        XCTAssertNil(input.remBaselineMinutes)
        XCTAssertFalse(input.state.isSourceStable)
    }

    func test_nilSourceNight_neverFoldsStageEWMAs_norReceivesBaselineAuthority() {
        // SPEC-7: an unknown writer proves nothing about who wrote the night — it must not
        // fold into the dominant source's stage EWMAs nor borrow their authority.
        let seeded = foldNights(count: 10)  // com.apple.health, deep 60 / rem 90, counts 10
        let anonymous = night(dayIndex: 11, deep: 30, rem: 40, sourceID: nil)

        let input = Builder.makeInput(state: seeded, night: anonymous, calendar: calendar)
        XCTAssertNil(input.deepBaselineMinutes)
        XCTAssertNil(input.remBaselineMinutes)

        let folded = Builder.fold(
            state: seeded,
            night: anonymous,
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        XCTAssertEqual(folded.deepMu!, 60, accuracy: 1e-9)  // untouched by the 30-min night
        XCTAssertEqual(folded.deepCount, 10)
        XCTAssertEqual(folded.remMu!, 90, accuracy: 1e-9)
        XCTAssertEqual(folded.remCount, 10)
        XCTAssertEqual(folded.dominantSourceID, "com.apple.health")
        // The night itself still counts — TST/debt/midpoint are source-agnostic.
        XCTAssertEqual(folded.nightsOfHistory, 11)
    }

    func test_sourceStability_recoversAfterFourteenNights() {
        var state = foldNights(count: 20)
        state = Builder.fold(
            state: state,
            night: night(dayIndex: 21, sourceID: "com.ouraring.oura"),
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        // 13 more new-source nights → nightsSinceSourceChange 13 → still unstable.
        for i in 0..<13 {
            state = Builder.fold(
                state: state,
                night: night(dayIndex: 22 + i, sourceID: "com.ouraring.oura"),
                needTonightMinutes: 450,
                latchedProfiles: [],
                calendar: calendar
            )
        }
        XCTAssertEqual(state.nightsSinceSourceChange, 13)
        let unstable = Builder.makeInput(
            state: state,
            night: night(dayIndex: 35, sourceID: "com.ouraring.oura"),
            calendar: calendar
        )
        XCTAssertFalse(unstable.state.isSourceStable)

        state = Builder.fold(
            state: state,
            night: night(dayIndex: 35, sourceID: "com.ouraring.oura"),
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        let stable = Builder.makeInput(
            state: state,
            night: night(dayIndex: 36, sourceID: "com.ouraring.oura"),
            calendar: calendar
        )
        XCTAssertTrue(stable.state.isSourceStable)
    }

    // MARK: - SleepInput assembly

    func test_makeInput_fieldsLandWhereTheEngineExpects() {
        let state = Builder.State(
            deepMu: 55,
            deepCount: Builder.stageBaselineMinNights,
            remMu: 92,
            remCount: Builder.stageBaselineMinNights,
            dominantSourceID: "com.apple.health",
            deficitBuffer7: [30, 40],
            needBaseMinutes: 470,
            nightsOfHistory: 12,
            previousProfilesRaw: ["DEBT_CARRY"],
            lastSleepEndDate: day(0).addingTimeInterval(7 * 3600)  // woke 07:00 day 0
        )
        let n = night(dayIndex: 1, tst: 440, deep: 65, rem: 88, awake: 25, inBed: 490)
        let input = Builder.makeInput(
            state: state,
            night: n,
            priorDayLoadZ: 1.2,
            priorDayActiveEnergyZ: 0.4,
            napMinutes: 30,
            calendar: calendar
        )

        XCTAssertEqual(input.tstMinutes, 440)
        XCTAssertEqual(input.deepMinutes, 65)
        XCTAssertEqual(input.remMinutes, 88)
        XCTAssertEqual(input.awakeMinutes, 25)
        XCTAssertEqual(input.inBedMinutes, 490)
        XCTAssertEqual(input.deepBaselineMinutes, 55)
        XCTAssertEqual(input.remBaselineMinutes, 92)
        XCTAssertEqual(input.needBaseMinutes, 470)
        XCTAssertNil(input.tierOverride)

        // State vector: prior wake from 07:00 day 0 to 23:00 day 0 = 16 h.
        XCTAssertEqual(input.state.priorWakeHours!, 16, accuracy: 1e-9)
        XCTAssertNil(input.state.priorWakeZ)  // not carried in S2
        XCTAssertEqual(input.state.sleepDebt7Minutes, 70, accuracy: 1e-9)
        XCTAssertEqual(input.state.priorDayLoadZ, 1.2)
        XCTAssertEqual(input.state.priorDayActiveEnergyZ, 0.4)
        XCTAssertEqual(input.state.napMinutes, 30)
        XCTAssertTrue(input.state.hasStageData)
        XCTAssertTrue(input.state.isSourceStable)
        XCTAssertEqual(input.state.nightsOfHistory, 12)
        XCTAssertEqual(input.previousProfiles, [.debtCarry])
    }

    func test_makeInput_stageBaselinesGatedOnMinimumFolds() {
        // 6 folds < the H-21 minimum of 7 → no stage authority yet.
        let state = Builder.State(deepMu: 55, deepCount: 6, remMu: 92, remCount: 6)
        let input = Builder.makeInput(state: state, night: night(dayIndex: 1), calendar: calendar)
        XCTAssertNil(input.deepBaselineMinutes)
        XCTAssertNil(input.remBaselineMinutes)
    }

    func test_makeInput_priorWake_sanityWindow() {
        // Negative span (overlapping data) → nil.
        let overlapping = Builder.State(lastSleepEndDate: day(1).addingTimeInterval(2 * 3600))
        let overlapInput = Builder.makeInput(
            state: overlapping,
            night: night(dayIndex: 1),  // starts 23:00 day 0, BEFORE the stored end
            calendar: calendar
        )
        XCTAssertNil(overlapInput.state.priorWakeHours)

        // A 3-day gap (> 48 h) is a data gap, not a vigil → nil (H-22).
        let gap = Builder.State(lastSleepEndDate: day(-3))
        let gapInput = Builder.makeInput(state: gap, night: night(dayIndex: 1), calendar: calendar)
        XCTAssertNil(gapInput.state.priorWakeHours)
    }

    func test_makeInput_hasStageData_tracksNightStaging() {
        let unstaged = Builder.makeInput(
            state: Builder.State(),
            night: night(dayIndex: 1, deep: nil, rem: nil),
            calendar: calendar
        )
        XCTAssertFalse(unstaged.state.hasStageData)
    }

    // MARK: - Profile-latch round-trip (§9.4 rule 4)

    func test_profileLatch_roundTripsThroughTheCarrier() {
        let folded = Builder.fold(
            state: Builder.State(),
            night: night(dayIndex: 1),
            needTonightMinutes: 450,
            latchedProfiles: [.chronicIrregular, .debtCarry],
            calendar: calendar
        )
        // Stored sorted for determinism, as raw §9.3 names.
        XCTAssertEqual(folded.previousProfilesRaw, ["CHRONIC_IRREGULAR", "DEBT_CARRY"])

        let input = Builder.makeInput(state: folded, night: night(dayIndex: 2), calendar: calendar)
        XCTAssertEqual(input.previousProfiles, [.chronicIrregular, .debtCarry])
    }

    // MARK: - Idempotency (W-1)

    func test_fold_samePresentedDayIsANoOp() {
        let once = Builder.fold(
            state: Builder.State(),
            night: night(dayIndex: 1),
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        let twice = Builder.fold(
            state: once,
            night: night(dayIndex: 1),
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        XCTAssertEqual(twice.nightsOfHistory, 1)
        XCTAssertEqual(twice.midpointBuffer.count, 1)
        XCTAssertEqual(twice.deficitBuffer7.count, 1)

        // Older days are also no-ops.
        let older = Builder.fold(
            state: once,
            night: night(dayIndex: 0),
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        XCTAssertEqual(older.nightsOfHistory, 1)
    }

    // MARK: - Fold guards: session identity + completeness (F3, H-26)

    func test_prematureMidNightFetch_skipped_thenFullNightFoldsLaterSameDay() {
        // The F3 scenario: a 02:00 pipeline run sees a truncated open night; it must NOT
        // fold. The 09:00 run the SAME day sees the complete session and must fold it.
        let seeded = foldNights(count: 5)  // last night ended 07:00 day 5

        // 02:00 run, day 6: session 23:00 (day 5) → 01:45 (day 6) = a 165-min "night".
        let truncatedStart = day(5).addingTimeInterval(23 * 3600)
        let truncated = Builder.Night(
            bucketedDate: day(6),
            tstMinutes: 165,
            sessionStart: truncatedStart,
            sessionEnd: truncatedStart.addingTimeInterval(165 * 60),
            sourceID: "com.apple.health"
        )
        let twoAM = day(6).addingTimeInterval(2 * 3600)
        // Ended 15 min before the run < the 120-min completeness hold (H-26) → skip.
        XCTAssertFalse(Builder.shouldFold(night: truncated, state: seeded, now: twoAM))

        // 09:00 run, same day: the full session 23:00 → 07:00 (ended exactly 120 min
        // before the run — the hold's own boundary) folds.
        let full = night(dayIndex: 6)  // 23:00 day 5 → 07:00 day 6, tst 450
        let nineAM = day(6).addingTimeInterval(9 * 3600)
        XCTAssertTrue(Builder.shouldFold(night: full, state: seeded, now: nineAM))
        let folded = Builder.fold(
            state: seeded,
            night: full,
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        // The buffers contain ONLY the full night — the 165-min read never poisoned them.
        XCTAssertEqual(folded.nightsOfHistory, 6)
        XCTAssertEqual(folded.tstBuffer.count, 6)
        XCTAssertEqual(folded.tstBuffer.last!, 450, accuracy: 1e-9)
        XCTAssertFalse(folded.tstBuffer.contains(165))
        XCTAssertEqual(folded.lastSleepEndDate, full.sessionEnd)
        XCTAssertEqual(folded.lastFoldedDate, day(6))
    }

    func test_foldGuard_sessionIdentity_blocksRefoldOfSameSession() {
        // After the morning fold, an evening run re-presenting the SAME session must not
        // fold again — session identity (sessionEnd advances), not just day identity.
        var state = foldNights(count: 5)
        let full = night(dayIndex: 6)
        state = Builder.fold(
            state: state,
            night: full,
            needTonightMinutes: 450,
            latchedProfiles: [],
            calendar: calendar
        )
        let sixPM = day(6).addingTimeInterval(18 * 3600)
        // Completeness passes (ended 11 h ago) but sessionEnd == stored end → skip.
        XCTAssertFalse(Builder.shouldFold(night: full, state: state, now: sixPM))

        // A genuinely NEW session (ends later) passes the identity guard.
        let nextNight = night(dayIndex: 7)
        let nextMorning = day(7).addingTimeInterval(9 * 3600)
        XCTAssertTrue(Builder.shouldFold(night: nextNight, state: state, now: nextMorning))
    }

    func test_completenessHold_boundary_oneMinuteShortSkips() {
        let state = foldNights(count: 5)
        let full = night(dayIndex: 6)  // ends 07:00 day 6
        // 119 min after session end → still possibly-ongoing → skip (H-26).
        let early = full.sessionEnd.addingTimeInterval(119 * 60)
        XCTAssertFalse(Builder.shouldFold(night: full, state: state, now: early))
        // 120 min after session end → complete → fold.
        let onTime = full.sessionEnd.addingTimeInterval(120 * 60)
        XCTAssertTrue(Builder.shouldFold(night: full, state: state, now: onTime))
    }

    // MARK: - Session clustering + interval union (F2/F6 — SleepSessionMath)

    /// A `DateInterval` starting `startMinutes` after day-0 midnight, lasting `duration` min.
    private func interval(_ startMinutes: Double, _ durationMinutes: Double) -> DateInterval {
        DateInterval(
            start: day0.addingTimeInterval(startMinutes * 60),
            duration: durationMinutes * 60
        )
    }

    func test_sessionClustering_twoNightsInOneWindow_mostRecentWins() {
        // The F2 concrete: run at 08:00 → the [startOfYesterday, now] window holds BOTH
        // post-midnight nights. Clustering must keep them apart and pick the latest.
        let nightA = [interval(30, 210), interval(270, 210)]        // 00:30–04:00, 04:30–08:00 day 1 (gap 30)
        let dayOffset = 24 * 60.0
        let nightB = [interval(dayOffset + 15, 450)]                // 00:15–07:45 day 2
        let clusters = SleepSessionMath.sessionClusters(
            nightA + nightB,
            gapMinutes: SleepSessionMath.sessionGapMinutes
        )
        XCTAssertEqual(clusters.count, 2)
        let chosen = clusters.last!
        XCTAssertEqual(chosen.first!.start, nightB[0].start)
        // The chosen session's TST ≈ 450, never the merged ~870.
        XCTAssertEqual(SleepSessionMath.unionMinutes(chosen), 450, accuracy: 1e-9)
    }

    func test_sessionClustering_gapBoundary_ninetyBridges_ninetyOneSplits() {
        // H-25: a gap of EXACTLY 90 min still bridges; > 90 starts a new session.
        let bridged = SleepSessionMath.sessionClusters(
            [interval(0, 60), interval(150, 60)],   // ends 60, next starts 150 → gap 90
            gapMinutes: SleepSessionMath.sessionGapMinutes
        )
        XCTAssertEqual(bridged.count, 1)

        let split = SleepSessionMath.sessionClusters(
            [interval(0, 60), interval(151, 60)],   // gap 91
            gapMinutes: SleepSessionMath.sessionGapMinutes
        )
        XCTAssertEqual(split.count, 2)
    }

    func test_sessionClustering_napSplitsFromMainSleep() {
        // Main sleep 23:00 day 0 → 07:00 day 1, nap 15:00–16:00 day 1: two sessions.
        let main = interval(23 * 60, 480)
        let nap = interval((24 + 15) * 60, 60)
        let clusters = SleepSessionMath.sessionClusters(
            [main, nap],
            gapMinutes: SleepSessionMath.sessionGapMinutes
        )
        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(clusters[0].first!, main)
    }

    func test_unionMinutes_overlapsCountOnce_disjointSum() {
        // F6: same-source overlapping samples must not double-count.
        XCTAssertEqual(
            SleepSessionMath.unionMinutes([interval(0, 60), interval(30, 60)]),
            90, accuracy: 1e-9
        )
        // Exact duplicates collapse.
        XCTAssertEqual(
            SleepSessionMath.unionMinutes([interval(0, 60), interval(0, 60)]),
            60, accuracy: 1e-9
        )
        // Disjoint intervals sum.
        XCTAssertEqual(
            SleepSessionMath.unionMinutes([interval(0, 60), interval(120, 60)]),
            120, accuracy: 1e-9
        )
        // Containment collapses to the container.
        XCTAssertEqual(
            SleepSessionMath.unionMinutes([interval(0, 120), interval(30, 30)]),
            120, accuracy: 1e-9
        )
        XCTAssertEqual(SleepSessionMath.unionMinutes([]), 0, accuracy: 1e-9)
    }

    // MARK: - TST buffer + counters

    func test_tstBuffer_capsAtNinety_andHistoryKeepsCounting() {
        let state = foldNights(count: 95)
        XCTAssertEqual(state.tstBuffer.count, Builder.tstBufferLength)
        XCTAssertEqual(state.nightsOfHistory, 95)
        XCTAssertEqual(state.lastFoldedDate, day(95))
        XCTAssertEqual(state.lastSleepEndDate, night(dayIndex: 95).sessionEnd)
    }

    // MARK: - Percentile helper

    func test_percentile_linearInterpolation() {
        XCTAssertEqual(Builder.percentile([10, 20, 30, 40], 0.75), 32.5, accuracy: 1e-9)
        XCTAssertEqual(Builder.percentile([10, 20, 30, 40, 50], 0.5), 30, accuracy: 1e-9)
        XCTAssertEqual(Builder.percentile([42], 0.75), 42, accuracy: 1e-9)
        XCTAssertEqual(Builder.percentile([], 0.75), 0, accuracy: 1e-9)
    }

    // MARK: - End-to-end: builder + engine agree on a plain night

    func test_builderFedEngine_scoresANeedMetNightAtEighty() {
        // 30 uniform, met-need nights: baselines converge on the night's own values, so
        // every quality component reads its met anchor and the composite is exactly 80.
        var state = Builder.State()
        for i in 1...30 {
            let n = night(dayIndex: i, tst: 450, deep: 60, rem: 90, inBed: 529)
            let input = Builder.makeInput(state: state, night: n, calendar: calendar)
            let result = Engine.compute(input: input)
            state = Builder.fold(
                state: state,
                night: n,
                needTonightMinutes: result.needTonightMinutes,
                latchedProfiles: result.latchedProfiles,
                calendar: calendar
            )
        }
        // 450/529 ≈ 0.8507 efficiency ≈ the 85% met anchor; SD14 = 0 → regularity 100.
        let n = night(dayIndex: 31, tst: 450, deep: 60, rem: 90, inBed: 529)
        let input = Builder.makeInput(state: state, night: n, calendar: calendar)
        let result = Engine.compute(input: input)
        XCTAssertEqual(result.tier, .a)
        XCTAssertEqual(result.activeProfiles, [.baseline])
        // Duration met (learned need ≤ 450 by construction) → D = 100 → 80 points;
        // deep/REM at baseline add 0; regularity (SD 0 → 100) adds its full 5;
        // continuity at met adds ~0. Score ≈ 85, never below 80.
        let score = try! XCTUnwrap(result.score)
        XCTAssertGreaterThanOrEqual(score, 80)
        XCTAssertLessThanOrEqual(score, 86)
    }
}
