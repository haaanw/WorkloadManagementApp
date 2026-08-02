import XCTest
@testable import workload_management

/// Sleep score v2, phase S1 — the pure engine.
///
/// The load-bearing tests here are the two the milestone is contracted on:
/// `test_tierD_isBitIdenticalToRecoveryScoreEngineSleepCurve` (the frozen fallback path)
/// and the Q1 ceiling group (duration alone never beats 85).
final class SleepScoreEngineTests: XCTestCase {

    private typealias Engine = SleepScoreEngine

    // MARK: - Helpers

    /// A state vector rich enough for Tier A, with no profile firing.
    private func tierAState(
        midpointSD14: Double? = 48,
        nights: Int = 30,
        isSourceStable: Bool = true
    ) -> Engine.SleepStateVector {
        Engine.SleepStateVector(
            midpointSD14Minutes: midpointSD14,
            hasStageData: true,
            isSourceStable: isSourceStable,
            nightsOfHistory: nights
        )
    }

    /// A full Tier-A night. `SleepInput`'s fields are `let`, so variants are built by
    /// overriding a parameter here rather than by mutating a copy.
    private func night(
        tst: Double? = 450,
        deep: Double? = 60,
        rem: Double? = 90,
        awake: Double? = nil,
        inBed: Double? = 500,
        deepBaseline: Double? = 60,
        remBaseline: Double? = 90,
        needBase: Double? = nil,
        state: Engine.SleepStateVector? = nil,
        previousProfiles: Set<Engine.SleepProfile> = [],
        tierOverride: Engine.SleepTier? = nil
    ) -> Engine.SleepInput {
        Engine.SleepInput(
            tstMinutes: tst,
            deepMinutes: deep,
            remMinutes: rem,
            awakeMinutes: awake,
            inBedMinutes: inBed,
            deepBaselineMinutes: deepBaseline,
            remBaselineMinutes: remBaseline,
            needBaseMinutes: needBase,
            state: state ?? tierAState(midpointSD14: 45),
            previousProfiles: previousProfiles,
            tierOverride: tierOverride
        )
    }

    private func allComponents() -> Set<Engine.SleepComponent> {
        Set(Engine.SleepComponent.allCases)
    }

    // MARK: - Duration curve (§5.1 + the Q1 re-anchor)

    func test_durationCurve_anchors() {
        // §5.1's table scaled by exactly durationCeiling / 100 = 0.85.
        let expected: [(r: Double, y: Double)] = [
            (0.60, 8.5), (0.70, 27.2), (0.80, 46.75),
            (0.85, 57.8), (0.90, 68.0), (0.95, 76.5), (1.00, 85.0)
        ]
        for point in expected {
            let score = Engine.durationScore(tstMinutes: point.r * 100, needMinutes: 100)
            XCTAssertEqual(score, point.y, accuracy: 0.001, "duration ratio \(point.r)")
        }
    }

    /// The Q1 ruling as arithmetic: extra hours buy nothing above the need.
    func test_durationCurve_plateausAtTheEightyFiveCeiling() {
        XCTAssertEqual(Engine.durationScore(tstMinutes: 450, needMinutes: 450), 85.0, accuracy: 1e-9)
        XCTAssertEqual(Engine.durationScore(tstMinutes: 600, needMinutes: 450), 85.0, accuracy: 1e-9)
        XCTAssertEqual(Engine.durationScore(tstMinutes: 900, needMinutes: 450), 85.0, accuracy: 1e-9)
        XCTAssertEqual(Engine.durationCeiling, 85.0, accuracy: 1e-9)
    }

    func test_durationCurve_isMonotoneNonDecreasing() {
        var previous = -1.0
        for step in 0...400 {
            let ratio = Double(step) * 0.005
            let score = Engine.durationScore(tstMinutes: ratio * 450, needMinutes: 450)
            XCTAssertGreaterThanOrEqual(score, previous, "duration curve dipped at r = \(ratio)")
            previous = score
        }
    }

    func test_durationCurve_floorsBelowSixtyPercent() {
        XCTAssertEqual(Engine.durationScore(tstMinutes: 30, needMinutes: 100), 8.5, accuracy: 0.001)
        XCTAssertEqual(Engine.durationScore(tstMinutes: 55, needMinutes: 100), 8.5, accuracy: 0.001)
    }

    // MARK: - Continuity curve

    func test_continuityCurve_anchors() {
        let expected: [(efficiency: Double, y: Double)] = [
            (0.65, 20), (0.75, 45), (0.80, 62), (0.85, 80), (0.88, 90), (0.92, 100)
        ]
        for point in expected {
            let score = Engine.continuityScore(
                tstMinutes: point.efficiency * 1000,
                awakeMinutes: nil,
                inBedMinutes: 1000
            )
            XCTAssertNotNil(score)
            XCTAssertEqual(score!, point.y, accuracy: 0.001, "efficiency \(point.efficiency)")
        }

        // Athlete-normal 85% must not read as a failure (§5.1 rationale, Leeder).
        let athleteNormal = Engine.continuityScore(tstMinutes: 850, awakeMinutes: nil, inBedMinutes: 1000)
        XCTAssertEqual(athleteNormal!, 80, accuracy: 0.001)
    }

    func test_continuity_prefersInBedDenominator() {
        // inBed 480 -> 0.875; the WASO path would give 420/450 = 0.9333.
        let score = Engine.continuityScore(tstMinutes: 420, awakeMinutes: 30, inBedMinutes: 480)
        let inBedPath = Engine.continuityScore(tstMinutes: 420, awakeMinutes: nil, inBedMinutes: 480)
        let wasoPath = Engine.continuityScore(tstMinutes: 420, awakeMinutes: 30, inBedMinutes: nil)
        XCTAssertNotNil(score)
        XCTAssertEqual(score!, inBedPath!, accuracy: 1e-9)
        XCTAssertNotEqual(score!, wasoPath!, accuracy: 0.001)
    }

    func test_continuity_fallsBackToWasoWhenInBedMissingOrShorterThanTst() {
        let wasoPath = Engine.continuityScore(tstMinutes: 420, awakeMinutes: 30, inBedMinutes: nil)
        XCTAssertNotNil(wasoPath)

        // inBed shorter than TST is a re-binning artifact, not an efficiency above 100%.
        let artifact = Engine.continuityScore(tstMinutes: 420, awakeMinutes: 30, inBedMinutes: 400)
        XCTAssertNotNil(artifact)
        XCTAssertEqual(artifact!, wasoPath!, accuracy: 1e-9)
    }

    func test_continuity_nilWhenNoDenominatorAvailable() {
        XCTAssertNil(Engine.continuityScore(tstMinutes: 420, awakeMinutes: nil, inBedMinutes: nil))
    }

    // MARK: - Regularity curve

    func test_regularityCurve_anchors() {
        let expected: [(sd: Double, y: Double)] = [
            (30, 100), (45, 90), (60, 80), (90, 62), (120, 45)
        ]
        for point in expected {
            let score = Engine.regularityScore(midpointSD14Minutes: point.sd)
            XCTAssertNotNil(score)
            XCTAssertEqual(score!, point.y, accuracy: 0.001, "midpoint SD \(point.sd)")
        }
        XCTAssertEqual(Engine.regularityScore(midpointSD14Minutes: 10)!, 100, accuracy: 0.001)
        XCTAssertEqual(Engine.regularityScore(midpointSD14Minutes: 300)!, 45, accuracy: 0.001)
        XCTAssertNil(Engine.regularityScore(midpointSD14Minutes: nil))
    }

    // MARK: - Stage curve

    /// H-11: this table deliberately diverges from §5.1's published stage curve at q = 0.85
    /// (85 -> 80) and q = 1.00 (100 -> 85), and adds an excellent anchor at q = 1.30. The
    /// registry row carries the reason and the falsification test; this pins the numbers.
    func test_stageCurve_anchors() {
        let expected: [(q: Double, y: Double)] = [
            (0.40, 45), (0.55, 55), (0.70, 70), (0.85, 80), (1.00, 85), (1.30, 100)
        ]
        for point in expected {
            let score = Engine.stageScore(minutes: point.q * 100, baselineMinutes: 100)
            XCTAssertNotNil(score)
            XCTAssertEqual(score!, point.y, accuracy: 0.001, "stage ratio \(point.q)")
        }
        // The met point and the excellent point, pinned explicitly.
        XCTAssertEqual(Engine.stageScore(minutes: 100, baselineMinutes: 100)!, 85, accuracy: 1e-9)
        XCTAssertEqual(Engine.stageScore(minutes: 130, baselineMinutes: 100)!, 100, accuracy: 1e-9)
        XCTAssertEqual(Engine.stageScore(minutes: 200, baselineMinutes: 100)!, 100, accuracy: 1e-9)
    }

    func test_stageCurve_flooredAtFortyFive() {
        XCTAssertEqual(Engine.stageScore(minutes: 5, baselineMinutes: 100)!, 45, accuracy: 0.001)
        XCTAssertEqual(Engine.stageScore(minutes: 0, baselineMinutes: 100)!, 45, accuracy: 0.001)
    }

    func test_stageScore_nilWithoutUsableBaseline() {
        XCTAssertNil(Engine.stageScore(minutes: 60, baselineMinutes: nil))
        XCTAssertNil(Engine.stageScore(minutes: 60, baselineMinutes: 0))
        XCTAssertNil(Engine.stageScore(minutes: nil, baselineMinutes: 60))
    }

    // MARK: - Composite behaviour (§7 Q1)

    /// Need met, everything else merely typical: the score lands ≈85, not 100.
    ///
    /// Worked, with the quality headroom included — it applies to every quality component
    /// whose RAW value clears the 85 met anchor, regularity included:
    /// duration 85 (0.50) + continuity 83.333 (0.15) + regularity 88 raw -> 91 after
    /// headroom (0.15) + deep 85 (0.10) + REM 85 (0.10) = 85.65.
    func test_typicalNightAtNeed_landsAtEightyFive() {
        let input = night(
            tst: 430,
            inBed: 500,                 // efficiency 0.86 -> 83.333
            needBase: 430,              // r = 1.00
            state: tierAState(midpointSD14: 48)
        )
        let result = Engine.compute(input: input)
        XCTAssertEqual(result.tier, .a)
        XCTAssertEqual(result.activeProfiles, [.baseline])
        XCTAssertNotNil(result.score)
        XCTAssertEqual(result.score!, 85.65, accuracy: 0.01)
    }

    /// A genuinely excellent night reaches exactly 100. This pins `qualityHeadroomGain`.
    func test_excellentNight_reachesExactlyOneHundred() {
        let input = night(
            tst: 470,
            deep: 84,                   // q = 1.4
            rem: 140,                   // q = 1.4
            inBed: 500,                 // efficiency 0.94
            remBaseline: 100,
            needBase: 450,              // r > 1.00
            state: tierAState(midpointSD14: 20)
        )
        let result = Engine.compute(input: input)
        XCTAssertEqual(result.tier, .a)
        XCTAssertNotNil(result.score)
        XCTAssertEqual(result.score!, 100.0, accuracy: 0.001)
    }

    /// "100 is never merely long" — doubling the night with identical quality changes nothing.
    func test_merelyLongNight_cannotBeatTheCeiling() {
        func longNight(tst: Double) -> Engine.SleepInput {
            night(
                tst: tst,
                inBed: tst / 0.865,                    // continuity raw = 85, the met anchor
                needBase: 450,
                state: tierAState(midpointSD14: 52.5)  // regularity raw = 85
            )
        }
        let atNeed = Engine.compute(input: longNight(tst: 450))
        let doubled = Engine.compute(input: longNight(tst: 900))
        XCTAssertNotNil(atNeed.score)
        XCTAssertNotNil(doubled.score)
        XCTAssertEqual(atNeed.score!, doubled.score!, accuracy: 1e-6)
        XCTAssertLessThanOrEqual(doubled.score!, 85.5)
    }

    /// The Q1 landing is exact only where all five components score. Fewer quality
    /// components means less headroom to earn, so the reachable maximum falls — stated
    /// here rather than discovered in the shadow run.
    func test_reachableCeiling_fallsWithTheTier() {
        // Tier C, duration + timing only: 0.75 x 85 + 0.25 x 115 = 92.5, never 100.
        let tierCBest = Engine.compute(input: Engine.SleepInput(
            tstMinutes: 600,
            needBaseMinutes: 450,
            state: Engine.SleepStateVector(
                midpointSD14Minutes: 10,
                hasStageData: false,
                nightsOfHistory: 40
            )
        ))
        XCTAssertEqual(tierCBest.tier, .c)
        XCTAssertEqual(tierCBest.weights.continuity, 0.0, accuracy: 1e-12)
        XCTAssertEqual(tierCBest.score!, 92.5, accuracy: 0.001)

        // Tier C that also has a continuity denominator sits between the two.
        let tierCWithContinuity = Engine.compute(input: Engine.SleepInput(
            tstMinutes: 600,
            inBedMinutes: 620,
            needBaseMinutes: 450,
            state: Engine.SleepStateVector(
                midpointSD14Minutes: 10,
                hasStageData: false,
                nightsOfHistory: 40
            )
        ))
        XCTAssertEqual(tierCWithContinuity.tier, .c)
        XCTAssertGreaterThan(tierCWithContinuity.weights.continuity, 0.0)
        XCTAssertGreaterThan(tierCWithContinuity.score!, 92.5)
        XCTAssertLessThan(tierCWithContinuity.score!, 100.0)

        // Tier D is exempt by contract (PLAN: bit-identical to today's curve), and today's
        // curve does reach 100 on a merely long night. Pinned so the exemption is explicit.
        let tierD = Engine.compute(input: Engine.SleepInput(
            tstMinutes: 540,
            state: Engine.SleepStateVector(nightsOfHistory: 3)
        ))
        XCTAssertEqual(tierD.tier, .d)
        XCTAssertEqual(tierD.score!, 100.0, accuracy: 1e-12)
    }

    func test_score_isClampedZeroToOneHundred() {
        // All-excellent under a duration-heavy profile stack.
        let best = Engine.SleepInput(
            tstMinutes: 600,
            deepMinutes: 200,
            remMinutes: 200,
            inBedMinutes: 610,
            deepBaselineMinutes: 60,
            remBaselineMinutes: 90,
            needBaseMinutes: 450,
            state: Engine.SleepStateVector(
                midpointSD14Minutes: 10,
                sleepDebt7Minutes: 300,
                priorDayLoadZ: 2.0,
                hasStageData: true,
                isSourceStable: true,
                nightsOfHistory: 60
            )
        )
        let bestResult = Engine.compute(input: best)
        XCTAssertNotNil(bestResult.score)
        XCTAssertLessThanOrEqual(bestResult.score!, 100.0)

        // All-worst.
        let worst = night(
            tst: 120,
            deep: 1,
            rem: 1,
            inBed: 600,
            needBase: 450,
            state: tierAState(midpointSD14: 400)
        )
        let worstResult = Engine.compute(input: worst)
        XCTAssertNotNil(worstResult.score)
        XCTAssertGreaterThanOrEqual(worstResult.score!, 0.0)
    }

    // MARK: - Tier ladder (§5.2)

    func test_tierSelection_table() {
        XCTAssertEqual(Engine.tier(for: night()), .a)

        // Stages, no in-bed span.
        XCTAssertEqual(Engine.tier(for: night(inBed: nil)), .b)

        // No stages from the source.
        XCTAssertEqual(Engine.tier(for: night(deep: nil, rem: nil)), .c)
        XCTAssertEqual(
            Engine.tier(for: night(state: Engine.SleepStateVector(
                midpointSD14Minutes: 45,
                hasStageData: false,
                nightsOfHistory: 30
            ))),
            .c
        )

        // No stages and no timing, but an in-bed span: continuity still scores, so this is
        // not the "duration only" floor.
        XCTAssertEqual(
            Engine.tier(for: night(deep: nil, rem: nil, state: tierAState(midpointSD14: nil))),
            .c
        )

        // Genuinely duration-only: no stages, no timing, no continuity denominator.
        XCTAssertEqual(
            Engine.tier(for: night(
                deep: nil,
                rem: nil,
                inBed: nil,
                state: tierAState(midpointSD14: nil)
            )),
            .d
        )

        // Short history outranks everything below Tier E.
        XCTAssertEqual(Engine.tier(for: night(state: tierAState(midpointSD14: 45, nights: 6))), .d)

        XCTAssertEqual(Engine.tier(for: night(tst: nil)), .e)
        XCTAssertEqual(Engine.tier(for: night(tst: 0)), .e)
    }

    /// **A missing stage BASELINE is not missing stage DATA.** Nights 7–13 of an Apple Watch
    /// user have staged samples but no converged EWMA yet. The stage components drop out and
    /// the weights renormalize (§5 preamble); the night must not be demoted to a tier that
    /// throws the measured continuity away — §5.1 calls continuity the most reliably
    /// measured of the five inputs.
    func test_missingStageBaseline_dropsStagesButKeepsContinuity() {
        let input = night(
            tst: 450,
            awake: 30,
            inBed: 500,                 // efficiency 0.90 -> 95
            deepBaseline: nil,          // EWMA not seeded yet
            remBaseline: nil,
            needBase: 450,
            state: tierAState(midpointSD14: 45, nights: 8)
        )
        let result = Engine.compute(input: input)

        XCTAssertEqual(result.tier, .a)
        XCTAssertNil(result.componentScores[.deep])
        XCTAssertNil(result.componentScores[.rem])
        XCTAssertEqual(result.componentScores[.continuity]!, 95.0, accuracy: 0.001)
        XCTAssertEqual(result.weights.deep, 0.0, accuracy: 1e-12)
        XCTAssertEqual(result.weights.rem, 0.0, accuracy: 1e-12)
        // 0.50 / 0.15 / 0.15 renormalized over the three that scored.
        XCTAssertEqual(result.weights.duration, 0.50 / 0.80, accuracy: 1e-9)
        XCTAssertEqual(result.weights.continuity, 0.15 / 0.80, accuracy: 1e-9)
        XCTAssertEqual(result.weights.regularity, 0.15 / 0.80, accuracy: 1e-9)
        XCTAssertEqual(result.weights.total, 1.0, accuracy: 1e-9)
    }

    /// Same defect from the other direction: a source that reports no stages at all, but
    /// does report an in-bed span (§3: manual and iPhone-only entries write `inBed`).
    func test_tierC_keepsContinuityWhenTheSourceGivesADenominator() {
        let input = Engine.SleepInput(
            tstMinutes: 450,
            inBedMinutes: 500,
            needBaseMinutes: 450,
            state: Engine.SleepStateVector(
                midpointSD14Minutes: 45,
                hasStageData: false,
                nightsOfHistory: 30
            )
        )
        let result = Engine.compute(input: input)
        XCTAssertEqual(result.tier, .c)
        XCTAssertEqual(result.componentScores[.continuity]!, 95.0, accuracy: 0.001)
        // §5.2's 0.75 / 0.25 pair plus continuity at its own §5.1 weight of 0.15.
        XCTAssertEqual(result.weights.duration, 0.75 / 1.15, accuracy: 1e-9)
        XCTAssertEqual(result.weights.continuity, 0.15 / 1.15, accuracy: 1e-9)
        XCTAssertEqual(result.weights.regularity, 0.25 / 1.15, accuracy: 1e-9)
        XCTAssertEqual(result.weights.total, 1.0, accuracy: 1e-9)
    }

    /// The tier names the SOURCE'S data grade; what actually carried authority is
    /// `weights` / `componentScores`, which is what §9.4 rule 5 stores. Both partial cases
    /// below are legal and must renormalize honestly rather than silently pretend.
    func test_tierLabel_doesNotPromiseEveryComponentScored() {
        // Tier A with no 14-night midpoint buffer yet: regularity drops.
        let noTiming = Engine.compute(input: night(
            tst: 430,
            needBase: 430,
            state: tierAState(midpointSD14: nil, nights: 10)
        ))
        XCTAssertEqual(noTiming.tier, .a)
        XCTAssertNil(noTiming.componentScores[.regularity])
        XCTAssertEqual(noTiming.weights.regularity, 0.0, accuracy: 1e-12)
        XCTAssertEqual(noTiming.weights.duration, 0.50 / 0.85, accuracy: 1e-9)
        XCTAssertEqual(noTiming.weights.total, 1.0, accuracy: 1e-9)
        XCTAssertFalse(noTiming.weights.availableComponents.contains(.regularity))

        // Tier B with neither continuity denominator: continuity drops.
        let noContinuity = Engine.compute(input: night(
            tst: 430,
            awake: nil,
            inBed: nil,
            needBase: 430,
            state: tierAState(midpointSD14: 45, nights: 10)
        ))
        XCTAssertEqual(noContinuity.tier, .b)
        XCTAssertNil(noContinuity.componentScores[.continuity])
        XCTAssertEqual(noContinuity.weights.continuity, 0.0, accuracy: 1e-12)
        XCTAssertEqual(noContinuity.weights.duration, 0.50 / 0.85, accuracy: 1e-9)
        XCTAssertEqual(noContinuity.weights.total, 1.0, accuracy: 1e-9)
        XCTAssertFalse(noContinuity.weights.availableComponents.contains(.continuity))
    }

    func test_tierOverride_wins() {
        let input = night(tst: 540, inBed: 600, tierOverride: .d)
        let result = Engine.compute(input: input)
        XCTAssertEqual(result.tier, .d)
        XCTAssertEqual(result.score!, RecoveryScoreEngine.sleepDurationToScore(540), accuracy: 1e-12)
    }

    /// An override picks a rung of the ladder; it cannot manufacture a night that did not
    /// happen. `SleepInput.tstMinutes` promises nil or non-positive means Tier E.
    func test_tierOverride_cannotScoreANonPositiveNight() {
        for forced in [Engine.SleepTier.a, .b, .c, .d] {
            let zero = Engine.compute(input: night(tst: 0, tierOverride: forced))
            XCTAssertEqual(zero.tier, .e, "override \(forced.rawValue) with TST 0")
            XCTAssertNil(zero.score, "override \(forced.rawValue) with TST 0")

            let negative = Engine.compute(input: night(tst: -1, tierOverride: forced))
            XCTAssertEqual(negative.tier, .e, "override \(forced.rawValue) with TST -1")
            XCTAssertNil(negative.score, "override \(forced.rawValue) with TST -1")
        }
        XCTAssertEqual(Engine.tier(for: night(tst: 0, tierOverride: .d)), .e)
    }

    func test_tierE_returnsNilScoreAndZeroWeights() {
        let result = Engine.compute(input: Engine.SleepInput(tstMinutes: nil))
        XCTAssertNil(result.score)
        XCTAssertEqual(result.tier, .e)
        XCTAssertEqual(result.confidence, 0.0, accuracy: 1e-12)
        XCTAssertEqual(result.weights.total, 0.0, accuracy: 1e-12)
        XCTAssertTrue(result.componentScores.isEmpty)
        XCTAssertNil(result.needTonightMinutes)
    }

    func test_tierC_baseWeightsAreSeventyFiveTwentyFive() {
        // No continuity denominator, so the tier is exactly §5.2's stated pair.
        let input = Engine.SleepInput(
            tstMinutes: 450,
            needBaseMinutes: 450,
            state: Engine.SleepStateVector(
                midpointSD14Minutes: 45,
                hasStageData: false,
                nightsOfHistory: 30
            )
        )
        let result = Engine.compute(input: input)
        XCTAssertEqual(result.tier, .c)
        XCTAssertEqual(result.activeProfiles, [.baseline])
        XCTAssertEqual(result.weights.duration, 0.75, accuracy: 1e-9)
        XCTAssertEqual(result.weights.regularity, 0.25, accuracy: 1e-9)
        XCTAssertEqual(result.weights.continuity, 0.0, accuracy: 1e-12)
        XCTAssertEqual(result.weights.deep, 0.0, accuracy: 1e-12)
        XCTAssertEqual(result.weights.rem, 0.0, accuracy: 1e-12)
        XCTAssertEqual(result.weights.total, 1.0, accuracy: 1e-9)
    }

    func test_tierD_usesSingleComponentWeight() {
        // A profile-triggering state that must not reach the weights on the frozen tier.
        let input = Engine.SleepInput(
            tstMinutes: 450,
            state: Engine.SleepStateVector(
                sleepDebt7Minutes: 300,
                priorDayLoadZ: 2.0,
                nightsOfHistory: 3
            )
        )
        let result = Engine.compute(input: input)
        XCTAssertEqual(result.tier, .d)
        XCTAssertEqual(result.weights.duration, 1.0, accuracy: 1e-12)
        XCTAssertEqual(result.weights.continuity, 0.0, accuracy: 1e-12)
        XCTAssertEqual(result.weights.regularity, 0.0, accuracy: 1e-12)
        XCTAssertEqual(result.weights.deep, 0.0, accuracy: 1e-12)
        XCTAssertEqual(result.weights.rem, 0.0, accuracy: 1e-12)
        XCTAssertTrue(result.activeProfiles.contains(.debtCarry))
    }

    /// The 85 ceiling deliberately does not apply to the compatibility tier.
    func test_tierD_ignoresNeedAndCeiling() {
        for need in [450.0, 570.0] {
            let input = Engine.SleepInput(
                tstMinutes: 540,
                needBaseMinutes: need,
                state: Engine.SleepStateVector(nightsOfHistory: 3)
            )
            XCTAssertEqual(Engine.compute(input: input).score!, 100.0, accuracy: 1e-12)
        }
        let noNeed = Engine.SleepInput(
            tstMinutes: 540,
            state: Engine.SleepStateVector(nightsOfHistory: 3)
        )
        XCTAssertEqual(Engine.compute(input: noNeed).score!, 100.0, accuracy: 1e-12)
    }

    // MARK: - Profile detection (§9.3)

    func test_profile_baseline_whenNothingFires() {
        let profiles = Engine.detectProfiles(state: Engine.SleepStateVector())
        XCTAssertEqual(profiles, [.baseline])
    }

    func test_profile_highPressure_triggersOnHoursOrZ() {
        func detect(hours: Double?, z: Double?) -> [Engine.SleepProfile] {
            Engine.detectProfiles(
                state: Engine.SleepStateVector(priorWakeHours: hours, priorWakeZ: z)
            )
        }
        XCTAssertTrue(detect(hours: 18.0, z: nil).contains(.highPressure))
        XCTAssertFalse(detect(hours: 17.9, z: nil).contains(.highPressure))
        XCTAssertTrue(detect(hours: nil, z: 1.5).contains(.highPressure))
        XCTAssertFalse(detect(hours: nil, z: 1.49).contains(.highPressure))
        XCTAssertFalse(detect(hours: nil, z: nil).contains(.highPressure))
    }

    func test_profile_highStrainDay_triggersOnEitherSignal() {
        func detect(load: Double?, energy: Double?) -> [Engine.SleepProfile] {
            Engine.detectProfiles(
                state: Engine.SleepStateVector(
                    priorDayLoadZ: load,
                    priorDayActiveEnergyZ: energy
                )
            )
        }
        XCTAssertTrue(detect(load: 1.0, energy: nil).contains(.highStrainDay))
        XCTAssertTrue(detect(load: nil, energy: 1.0).contains(.highStrainDay))
        XCTAssertFalse(detect(load: 0.9, energy: 0.9).contains(.highStrainDay))
        // A nil z is never coerced to zero, and never fires.
        XCTAssertFalse(detect(load: nil, energy: nil).contains(.highStrainDay))
    }

    func test_profile_acuteShift_requiresAllThreeConditions() {
        func detect(deviation: Double, sd: Double, daysSince: Int) -> [Engine.SleepProfile] {
            Engine.detectProfiles(
                state: Engine.SleepStateVector(
                    midpointSD14Minutes: sd,
                    midpointDeviationMinutes: deviation,
                    daysSinceRhythmBreak: daysSince
                )
            )
        }
        XCTAssertTrue(detect(deviation: 150, sd: 50, daysSince: 1).contains(.acuteShift))
        XCTAssertFalse(detect(deviation: 110, sd: 50, daysSince: 1).contains(.acuteShift))
        XCTAssertFalse(detect(deviation: 150, sd: 65, daysSince: 1).contains(.acuteShift))
        XCTAssertFalse(detect(deviation: 150, sd: 50, daysSince: 3).contains(.acuteShift))
    }

    /// ACUTE_SHIFT is §9.4 rule 4's own exception: single-night by definition, so it is
    /// re-decided from tonight's facts and never carried by the latch.
    func test_profile_acuteShift_hasNoHysteresis() {
        let profiles = Engine.detectProfiles(
            state: Engine.SleepStateVector(
                midpointSD14Minutes: 50,
                midpointDeviationMinutes: 10,
                daysSinceRhythmBreak: 1
            ),
            previousProfiles: [.acuteShift]
        )
        XCTAssertFalse(profiles.contains(.acuteShift))
    }

    func test_profile_chronicIrregular_entryHysteresis() {
        func detect(nights: Int) -> [Engine.SleepProfile] {
            Engine.detectProfiles(
                state: Engine.SleepStateVector(
                    midpointSD14Minutes: 80,
                    irregularNightsIn14: nights
                )
            )
        }
        XCTAssertTrue(detect(nights: 10).contains(.chronicIrregular))
        XCTAssertFalse(detect(nights: 9).contains(.chronicIrregular))
    }

    func test_profile_chronicIrregular_exitHysteresis() {
        func detect(nightsBelow: Int) -> [Engine.SleepProfile] {
            Engine.detectProfiles(
                state: Engine.SleepStateVector(
                    midpointSD14Minutes: 40,
                    nightsBelowChronicExitSD: nightsBelow
                ),
                previousProfiles: [.chronicIrregular]
            )
        }
        XCTAssertTrue(detect(nightsBelow: 4).contains(.chronicIrregular))
        XCTAssertFalse(detect(nightsBelow: 5).contains(.chronicIrregular))
    }

    func test_profile_acuteAndChronic_areMutuallyExclusive_acuteWins() {
        // Chronic is carried in by hysteresis; the acute trigger fires on top of it.
        let profiles = Engine.detectProfiles(
            state: Engine.SleepStateVector(
                midpointSD14Minutes: 50,
                midpointDeviationMinutes: 150,
                daysSinceRhythmBreak: 1,
                nightsBelowChronicExitSD: 2
            ),
            previousProfiles: [.chronicIrregular]
        )
        XCTAssertTrue(profiles.contains(.acuteShift))
        XCTAssertFalse(profiles.contains(.chronicIrregular))
    }

    /// §9.4 rule 1's exclusivity is a REPORTING rule, not an exit. The chronic state stays
    /// latched through the acute night, so its 5-night exit run (§9.3) is not skipped —
    /// which is why the caller must hand back `latchedProfiles`, not `activeProfiles`.
    func test_chronicLatch_survivesAnAcuteShiftNight() {
        let chronicState = Engine.SleepStateVector(
            midpointSD14Minutes: 80,
            irregularNightsIn14: 11
        )
        let nightN = Engine.compute(input: night(state: chronicState))
        XCTAssertTrue(nightN.activeProfiles.contains(.chronicIrregular))
        XCTAssertTrue(nightN.latchedProfiles.contains(.chronicIrregular))

        // Night N+1: the athlete flies to a tournament. Acute out-ranks chronic in the
        // reported set, and the irregular-night count has dipped below the entry threshold.
        let acuteState = Engine.SleepStateVector(
            midpointSD14Minutes: 50,
            midpointDeviationMinutes: 150,
            daysSinceRhythmBreak: 1,
            irregularNightsIn14: 9,
            nightsBelowChronicExitSD: 1
        )
        let nightN1 = Engine.compute(
            input: night(state: acuteState, previousProfiles: nightN.latchedProfiles)
        )
        XCTAssertEqual(nightN1.activeProfiles, [.acuteShift])
        XCTAssertTrue(nightN1.latchedProfiles.contains(.chronicIrregular))

        // Night N+2: acute is over, entry no longer satisfied, exit run still incomplete.
        let settledState = Engine.SleepStateVector(
            midpointSD14Minutes: 55,
            irregularNightsIn14: 9,
            nightsBelowChronicExitSD: 2
        )
        let nightN2 = Engine.compute(
            input: night(state: settledState, previousProfiles: nightN1.latchedProfiles)
        )
        XCTAssertTrue(
            nightN2.activeProfiles.contains(.chronicIrregular),
            "the chronic latch must survive the acute night and honour its 5-night exit run"
        )

        // Feeding `activeProfiles` back instead is exactly the bug this field prevents.
        let wrongCarry = Engine.compute(
            input: night(state: settledState, previousProfiles: Set(nightN1.activeProfiles))
        )
        XCTAssertFalse(wrongCarry.activeProfiles.contains(.chronicIrregular))

        // And the run does complete: 5 consecutive nights below the exit SD ends the state.
        let exitedState = Engine.SleepStateVector(
            midpointSD14Minutes: 40,
            irregularNightsIn14: 4,
            nightsBelowChronicExitSD: 5
        )
        let exited = Engine.compute(
            input: night(state: exitedState, previousProfiles: nightN2.latchedProfiles)
        )
        XCTAssertFalse(exited.activeProfiles.contains(.chronicIrregular))
        XCTAssertFalse(exited.latchedProfiles.contains(.chronicIrregular))
    }

    func test_profile_debtCarry_triggersAtThreeHours() {
        func detect(debt: Double) -> [Engine.SleepProfile] {
            Engine.detectProfiles(state: Engine.SleepStateVector(sleepDebt7Minutes: debt))
        }
        XCTAssertTrue(detect(debt: 180).contains(.debtCarry))
        XCTAssertFalse(detect(debt: 179).contains(.debtCarry))
    }

    func test_profile_napDay_triggersAtTwentyMinutes() {
        func detect(nap: Double) -> [Engine.SleepProfile] {
            Engine.detectProfiles(state: Engine.SleepStateVector(napMinutes: nap))
        }
        XCTAssertTrue(detect(nap: 20).contains(.napDay))
        XCTAssertFalse(detect(nap: 19).contains(.napDay))
    }

    /// §9.4 rule 4: every state entry/exit has hysteresis except ACUTE_SHIFT. A latched
    /// state survives down to its hold band, so a signal parked on the entry line cannot
    /// flip the weights on and off night after night. H-13.
    func test_profiles_haveEntryExitHysteresis() {
        func held(_ profile: Engine.SleepProfile, _ state: Engine.SleepStateVector) -> Bool {
            Engine.latchedProfiles(state: state, previousProfiles: [profile]).contains(profile)
        }
        func fresh(_ profile: Engine.SleepProfile, _ state: Engine.SleepStateVector) -> Bool {
            Engine.latchedProfiles(state: state, previousProfiles: []).contains(profile)
        }

        // DEBT_CARRY: enter at 180 min, hold to 150.
        XCTAssertFalse(fresh(.debtCarry, Engine.SleepStateVector(sleepDebt7Minutes: 160)))
        XCTAssertTrue(held(.debtCarry, Engine.SleepStateVector(sleepDebt7Minutes: 160)))
        XCTAssertFalse(held(.debtCarry, Engine.SleepStateVector(sleepDebt7Minutes: 149)))

        // HIGH_STRAIN_DAY: enter at z = 1.0, hold to 0.75.
        XCTAssertFalse(fresh(.highStrainDay, Engine.SleepStateVector(priorDayLoadZ: 0.8)))
        XCTAssertTrue(held(.highStrainDay, Engine.SleepStateVector(priorDayLoadZ: 0.8)))
        XCTAssertFalse(held(.highStrainDay, Engine.SleepStateVector(priorDayLoadZ: 0.74)))

        // HIGH_PRESSURE: enter at 18 h (or z 1.5), hold to 17 h (or z 1.25).
        XCTAssertFalse(fresh(.highPressure, Engine.SleepStateVector(priorWakeHours: 17.5)))
        XCTAssertTrue(held(.highPressure, Engine.SleepStateVector(priorWakeHours: 17.5)))
        XCTAssertFalse(held(.highPressure, Engine.SleepStateVector(priorWakeHours: 16.9)))
        XCTAssertTrue(held(.highPressure, Engine.SleepStateVector(priorWakeZ: 1.3)))
        XCTAssertFalse(held(.highPressure, Engine.SleepStateVector(priorWakeZ: 1.2)))

        // NAP_DAY: enter at 20 min, hold to 15.
        XCTAssertFalse(fresh(.napDay, Engine.SleepStateVector(napMinutes: 17)))
        XCTAssertTrue(held(.napDay, Engine.SleepStateVector(napMinutes: 17)))
        XCTAssertFalse(held(.napDay, Engine.SleepStateVector(napMinutes: 14)))
    }

    // MARK: - Weight composition (§9.4 rule 2)

    func test_weights_deltasStackAndSumToOne() {
        let weights = Engine.composeWeights(
            base: Engine.baseWeights(for: .a),
            profiles: [.highPressure, .debtCarry],
            available: allComponents()
        )
        // duration 0.50 + 0.05 + 0.08 = 0.63, clamped to the 0.60 ceiling.
        XCTAssertEqual(weights.total, 1.0, accuracy: 1e-9)
        for component in Engine.SleepComponent.allCases where component != .duration {
            XCTAssertGreaterThan(weights.duration, weights[component])
        }
        // Pre-normalization ceiling of 0.60 over a total of 0.97.
        XCTAssertEqual(weights.duration, 0.60 / 0.97, accuracy: 1e-9)
    }

    func test_weights_clampedToFivePercentFloor() {
        // REM: 0.10 − 0.02 (pressure) − 0.02 (chronic) − 0.02 (debt) = 0.04 -> floored at 0.05.
        // Duration: 0.50 + 0.05 − 0.05 + 0.08 = 0.58 (no clamp).
        let weights = Engine.composeWeights(
            base: Engine.baseWeights(for: .a),
            profiles: [.highPressure, .chronicIrregular, .debtCarry],
            available: allComponents()
        )
        XCTAssertEqual(weights.rem / weights.duration, 0.05 / 0.58, accuracy: 1e-6)
        XCTAssertEqual(weights.total, 1.0, accuracy: 1e-9)
    }

    func test_weights_droppedComponentNeverReceivesADelta() {
        // HIGH_PRESSURE carries a deep delta, but Tier C dropped the stage components.
        let weights = Engine.composeWeights(
            base: Engine.baseWeights(for: .c),
            profiles: [.highPressure],
            available: [.duration, .regularity]
        )
        XCTAssertEqual(weights.deep, 0.0, accuracy: 1e-12)
        XCTAssertEqual(weights.rem, 0.0, accuracy: 1e-12)
        XCTAssertEqual(weights.continuity, 0.0, accuracy: 1e-12)
    }

    func test_weights_renormalizeOverAvailableComponentsOnly() {
        let weights = Engine.composeWeights(
            base: Engine.baseWeights(for: .c),
            profiles: [.highPressure, .debtCarry],
            available: [.duration, .regularity]
        )
        XCTAssertEqual(weights.duration + weights.regularity, 1.0, accuracy: 1e-9)
        XCTAssertEqual(weights.total, 1.0, accuracy: 1e-9)
        XCTAssertEqual(weights.continuity, 0.0, accuracy: 1e-12)
        XCTAssertEqual(weights.deep, 0.0, accuracy: 1e-12)
        XCTAssertEqual(weights.rem, 0.0, accuracy: 1e-12)
        // duration 0.75 + 0.05 + 0.08 -> clamped at max(0.60, base 0.75) = 0.75;
        // regularity 0.25 − 0.07 − 0.02 = 0.16; renormalized over 0.91.
        XCTAssertEqual(weights.duration, 0.75 / 0.91, accuracy: 1e-9)
        XCTAssertEqual(weights.regularity, 0.16 / 0.91, accuracy: 1e-9)
    }

    /// The §9.4-rule-2 ceiling deviation, pinned by value. §9.4 clamps every weight to
    /// [0.05, 0.60]; §5.2 states Tier C duration = 0.75. The ceiling never cuts below the
    /// tier's own base weight — which buys the tier's ratio, NOT a frozen 0.75, because
    /// renormalization still moves the final number whenever a delta fires.
    func test_weights_tierCCeilingNeverCutsBelowItsOwnBaseWeight() {
        let weights = Engine.composeWeights(
            base: Engine.baseWeights(for: .c),
            profiles: [.debtCarry],
            available: [.duration, .regularity]
        )
        // duration 0.75 + 0.08 -> 0.75 after the clamp; regularity 0.25 − 0.02 = 0.23.
        XCTAssertEqual(weights.duration, 0.75 / 0.98, accuracy: 1e-9)
        XCTAssertEqual(weights.regularity, 0.23 / 0.98, accuracy: 1e-9)
        // A literal 0.60 ceiling would have produced 0.706 / 0.294 with no deltas at all.
        XCTAssertGreaterThan(weights.duration, 0.72)
    }

    /// "Stage components capped at half authority" = half of the tier's BASE stage weight,
    /// pinned as a ratio because renormalization moves the absolutes.
    func test_acuteShift_capsStageAuthorityAtHalfBase() {
        let weights = Engine.composeWeights(
            base: Engine.baseWeights(for: .a),
            profiles: [.acuteShift],
            available: allComponents()
        )
        XCTAssertEqual(weights.deep / weights.duration, 0.05 / 0.55, accuracy: 1e-6)
        XCTAssertEqual(weights.rem / weights.duration, 0.05 / 0.55, accuracy: 1e-6)
        XCTAssertEqual(weights.total, 1.0, accuracy: 1e-9)
    }

    // MARK: - Nightly need (§4, §9.4 rule 3)

    func test_needTonight_pressureCredit() {
        func need(hours: Double) -> Double {
            Engine.needTonightMinutes(
                needBaseMinutes: 450,
                state: Engine.SleepStateVector(priorWakeHours: hours)
            ).minutes
        }
        XCTAssertEqual(need(hours: 20), 474, accuracy: 1e-9)   // +24
        XCTAssertEqual(need(hours: 24), 495, accuracy: 1e-9)   // capped at +45, not +48
        XCTAssertEqual(need(hours: 16), 450, accuracy: 1e-9)   // +0
        XCTAssertEqual(need(hours: 10), 450, accuracy: 1e-9)   // never negative
    }

    func test_needTonight_strainCredit() {
        func need(z: Double) -> Double {
            Engine.needTonightMinutes(
                needBaseMinutes: 450,
                state: Engine.SleepStateVector(priorDayLoadZ: z)
            ).minutes
        }
        XCTAssertEqual(need(z: 1.0), 465, accuracy: 1e-9)   // +15
        XCTAssertEqual(need(z: 2.0), 480, accuracy: 1e-9)   // +30
        XCTAssertEqual(need(z: 4.0), 480, accuracy: 1e-9)   // capped
        XCTAssertEqual(need(z: -1.0), 450, accuracy: 1e-9)  // a light day earns nothing
    }

    func test_needTonight_debtCredit() {
        func credits(debt: Double) -> Engine.NeedCredits {
            Engine.needTonightMinutes(
                needBaseMinutes: 450,
                state: Engine.SleepStateVector(sleepDebt7Minutes: debt)
            ).credits
        }
        // 0.30 × 200 = 60, capped at 30.
        XCTAssertEqual(credits(debt: 200).debtMinutes, 30, accuracy: 1e-9)
        // 600 is first re-capped to the §9.2 6 h ceiling, then credited.
        XCTAssertEqual(credits(debt: 600).debtMinutes, 30, accuracy: 1e-9)
        // Ungated, the "+0…30 min" band in §9.3 is a real gradient again: it ramps over the
        // first 100 minutes of trailing deficit instead of arriving whole at the 3 h line.
        XCTAssertEqual(credits(debt: 0).debtMinutes, 0, accuracy: 1e-9)
        XCTAssertEqual(credits(debt: 50).debtMinutes, 15, accuracy: 1e-9)
        XCTAssertEqual(credits(debt: 100).debtMinutes, 30, accuracy: 1e-9)
    }

    /// §4's credits are unconditional, so the need is continuous in every state field. The
    /// old trigger-gated form jumped 30 minutes of need — and ~10 points of score — for one
    /// extra minute of trailing deficit; at 18 h of prior wake it jumped 12 minutes.
    ///
    /// The band is a tenth of a minute: each credit still moves with its signal (the
    /// pressure credit is 6 min per hour, so 0.01 h of wake is worth 0.6 s of need), it just
    /// no longer arrives whole at a threshold.
    func test_needTonight_isContinuousAcrossEveryProfileTrigger() {
        func need(_ state: Engine.SleepStateVector) -> Double {
            Engine.needTonightMinutes(needBaseMinutes: 450, state: state).minutes
        }
        XCTAssertEqual(
            need(Engine.SleepStateVector(sleepDebt7Minutes: 179.99)),
            need(Engine.SleepStateVector(sleepDebt7Minutes: 180.0)),
            accuracy: 0.1
        )
        XCTAssertEqual(
            need(Engine.SleepStateVector(priorDayLoadZ: 0.999)),
            need(Engine.SleepStateVector(priorDayLoadZ: 1.0)),
            accuracy: 0.1
        )
        XCTAssertEqual(
            need(Engine.SleepStateVector(priorWakeHours: 17.99)),
            need(Engine.SleepStateVector(priorWakeHours: 18.0)),
            accuracy: 0.1
        )
        XCTAssertEqual(
            need(Engine.SleepStateVector(priorWakeHours: 20, napMinutes: 19.99)),
            need(Engine.SleepStateVector(priorWakeHours: 20, napMinutes: 20.0)),
            accuracy: 0.1
        )
    }

    /// The residual step at a trigger is the §9.3 weight shift alone — states are states,
    /// not gradients — and it is now under a point instead of six.
    func test_score_stepAtTheDebtTriggerIsSmall() {
        func scored(debt: Double) -> Double {
            let input = night(
                tst: 450,
                inBed: 450 / 0.865,                    // continuity raw = 85
                needBase: 450,
                state: Engine.SleepStateVector(
                    midpointSD14Minutes: 52.5,         // regularity raw = 85
                    sleepDebt7Minutes: debt,
                    hasStageData: true,
                    nightsOfHistory: 30
                )
            )
            return Engine.compute(input: input).score!
        }
        let below = scored(debt: 179.99)
        let above = scored(debt: 180.0)
        XCTAssertLessThan(abs(above - below), 1.0, "below \(below), above \(above)")
    }

    func test_needTonight_totalClampedToBasePlusSixty() {
        let outcome = Engine.needTonightMinutes(
            needBaseMinutes: 450,
            state: Engine.SleepStateVector(
                priorWakeHours: 24,
                sleepDebt7Minutes: 200,
                priorDayLoadZ: 2.0
            )
        )
        // Raw credits 45 + 30 + 30 = 105.
        XCTAssertEqual(outcome.credits.pressureMinutes, 45, accuracy: 1e-9)
        XCTAssertEqual(outcome.credits.strainMinutes, 30, accuracy: 1e-9)
        XCTAssertEqual(outcome.credits.debtMinutes, 30, accuracy: 1e-9)
        XCTAssertEqual(outcome.minutes, 510, accuracy: 1e-9)
        XCTAssertEqual(outcome.credits.appliedMinutes, 60, accuracy: 1e-9)
    }

    func test_needTonight_neverExceedsTenHours() {
        let outcome = Engine.needTonightMinutes(
            needBaseMinutes: 570,
            state: Engine.SleepStateVector(
                priorWakeHours: 24,
                sleepDebt7Minutes: 200,
                priorDayLoadZ: 2.0
            )
        )
        XCTAssertEqual(outcome.minutes, 600, accuracy: 1e-9)
        XCTAssertEqual(outcome.credits.appliedMinutes, 30, accuracy: 1e-9)
    }

    func test_needTonight_napDebitCannotPushBelowBase() {
        let napOnly = Engine.needTonightMinutes(
            needBaseMinutes: 450,
            state: Engine.SleepStateVector(napMinutes: 60)
        )
        XCTAssertEqual(napOnly.credits.napDebitMinutes, 30, accuracy: 1e-9)
        XCTAssertEqual(napOnly.minutes, 450, accuracy: 1e-9)
        XCTAssertEqual(napOnly.credits.appliedMinutes, 0, accuracy: 1e-9)

        let stacked = Engine.needTonightMinutes(
            needBaseMinutes: 450,
            state: Engine.SleepStateVector(priorWakeHours: 24, napMinutes: 60)
        )
        XCTAssertEqual(stacked.minutes, 465, accuracy: 1e-9)
    }

    func test_needTonight_coldStartUsesSevenAndAHalfHours() {
        let outcome = Engine.needTonightMinutes(
            needBaseMinutes: nil,
            state: Engine.SleepStateVector()
        )
        // Read from the shared constant, never a literal.
        XCTAssertEqual(
            outcome.minutes,
            RecoveryScoreEngine.sleepTargetHours * 60.0,
            accuracy: 1e-9
        )
    }

    // MARK: - Confidence (§5.2)

    func test_confidence_factors() {
        // The first night eligible for a v2 score must be down-weighted, never discarded:
        // a confidence of exactly 0 tells the verdict layer to throw the signal away.
        let firstEligible = Engine.confidence(
            nightsOfHistory: 7,
            isSourceStable: true,
            availableComponentCount: 5
        )
        XCTAssertEqual(firstEligible, 0.25, accuracy: 1e-9)
        XCTAssertGreaterThan(firstEligible, 0.0)

        XCTAssertEqual(
            Engine.confidence(nightsOfHistory: 28, isSourceStable: true, availableComponentCount: 5),
            1.0, accuracy: 1e-9
        )
        XCTAssertEqual(
            Engine.confidence(nightsOfHistory: 28, isSourceStable: false, availableComponentCount: 5),
            0.5, accuracy: 1e-9
        )
        XCTAssertEqual(
            Engine.confidence(nightsOfHistory: 28, isSourceStable: true, availableComponentCount: 2),
            0.4, accuracy: 1e-9
        )
        let mid = Engine.confidence(
            nightsOfHistory: 17,
            isSourceStable: true,
            availableComponentCount: 5
        )
        XCTAssertGreaterThan(mid, 0.0)
        XCTAssertLessThan(mid, 1.0)
        XCTAssertEqual(
            Engine.confidence(nightsOfHistory: 60, isSourceStable: true, availableComponentCount: 0),
            0.0, accuracy: 1e-12
        )
    }

    // MARK: - Architectural gates

    /// §5.3: the engine must never read a clock. Same grep gate that guards `BaselineEngine`.
    func test_engine_isDateless() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let engineURL = repoRoot
            .appendingPathComponent("WorkloadApp")
            .appendingPathComponent("Services")
            .appendingPathComponent("SleepScoreEngine.swift")
        let source = try String(contentsOf: engineURL, encoding: .utf8)
        XCTAssertFalse(source.contains("Date("), "SleepScoreEngine must not construct a date")
        XCTAssertFalse(source.contains(".now"), "SleepScoreEngine must not read the clock")
    }

    /// §9.4 rule 5: a score no one can reconstruct after the fact is not auditable.
    func test_result_carriesEverythingTheSnapshotMustStore() {
        let input = night(tst: 430, inBed: 500, needBase: 430, state: tierAState(midpointSD14: 48))
        let result = Engine.compute(input: input)
        XCTAssertEqual(result.tier, .a)
        XCTAssertNotNil(result.score)
        XCTAssertNotNil(result.needTonightMinutes)
        XCTAssertFalse(result.activeProfiles.isEmpty)
        XCTAssertEqual(result.weights.total, 1.0, accuracy: 1e-9)
        for component in result.weights.availableComponents {
            XCTAssertNotNil(
                result.componentScores[component],
                "missing component score for \(component.rawValue)"
            )
        }
        XCTAssertEqual(result.componentScores.count, 5)
        XCTAssertGreaterThan(result.confidence, 0.0)
        XCTAssertLessThanOrEqual(result.confidence, 1.0)
        // `.baseline` is a report label, never a latched state to hand back.
        XCTAssertFalse(result.latchedProfiles.contains(.baseline))
    }

    // MARK: - The Tier-D golden test

    /// **The frozen-fallback gate.** Tier D must be bit-identical to today's curve across
    /// the function's whole domain, and none of the v2 machinery may leak into it.
    ///
    /// `sleepDurationToScore` takes a `Double` and receives HealthKit interval quotients
    /// (seconds ÷ 60), which are essentially never whole minutes — so the sweep steps in
    /// twentieths of a minute (3-second resolution) rather than in integers. An integer-only
    /// sweep passes even if someone prepends `minutes.rounded()` to the curve, or nudges a
    /// knee to 6.005 h, which is precisely the drift this gate exists to catch.
    ///
    /// Two independent checks per sample:
    /// 1. against an independent transcription of the spec — the one with real power, since
    ///    `tierDScore` delegates to `sleepDurationToScore` and would follow it anywhere;
    /// 2. against the live `RecoveryScoreEngine.sleepDurationToScore`, which guards the
    ///    delegation itself: no clamping, rounding or ceiling applied on the way out.
    ///
    /// `bitPattern` comparison rather than `accuracy:` — "bit-identical" is the requirement.
    /// Mismatches are collected instead of asserted per-sample so the sweep stays fast and
    /// reports the first divergences together.
    func test_tierD_isBitIdenticalToRecoveryScoreEngineSleepCurve() {
        let independentTranscription: (Double) -> Double = {
            let h = $0 / 60.0
            if h < 5 { return 10 }
            if h < 6 { return 10 + (h - 5) * 30 }
            if h < 7.5 { return 40 + (h - 6) * 20 }
            if h < 9 { return 70 + (h - 7.5) * 20 }
            return 100
        }

        var specMismatches: [String] = []
        var liveMismatches: [String] = []
        var machineryLeaks: [String] = []

        func check(_ m: Double) {
            let result = Engine.compute(input: Engine.SleepInput(tstMinutes: m, tierOverride: .d))
            guard let actual = result.score else {
                machineryLeaks.append("nil score at \(m)")
                return
            }
            if actual.bitPattern != independentTranscription(m).bitPattern {
                specMismatches.append("\(m): \(actual) vs spec \(independentTranscription(m))")
            }
            if actual.bitPattern != RecoveryScoreEngine.sleepDurationToScore(m).bitPattern {
                liveMismatches.append("\(m): \(actual)")
            }
            if result.tier != .d
                || result.weights.duration != 1.0
                || result.weights.total != 1.0
                || result.needTonightMinutes != nil {
                machineryLeaks.append("v2 machinery leaked at \(m)")
            }
        }

        // 0.05-minute steps from 3 seconds of sleep to 16 h.
        for i in 1...19_200 { check(Double(i) / 20.0) }

        // Fractional minutes around every knee, where a rounded or shifted curve hides.
        for m in [
            0.1, 4.9, 5.05, 299.9, 299.95, 300.05, 300.1,
            359.9, 359.95, 360.05, 360.1, 449.5, 449.9, 450.1,
            539.9, 539.95, 540.05, 540.1, 959.9, 960.1, 1440.0
        ] { check(m) }

        // HealthKit-shaped inputs: whole seconds divided by 60.
        for seconds in [26_983.0, 27_001.0, 21_599.0, 32_401.0, 19_237.0] {
            check(seconds / 60.0)
        }

        XCTAssertTrue(
            specMismatches.isEmpty,
            "Tier D drifted from the spec curve (\(specMismatches.count)): \(specMismatches.prefix(5))"
        )
        XCTAssertTrue(
            liveMismatches.isEmpty,
            "Tier D no longer delegates cleanly (\(liveMismatches.count)): \(liveMismatches.prefix(5))"
        )
        XCTAssertTrue(machineryLeaks.isEmpty, "\(machineryLeaks.prefix(5))")

        // A fractional sample stated by value, so the domain claim is legible without the loop.
        XCTAssertEqual(Engine.tierDScore(tstMinutes: 449.5), 69.83333333333333, accuracy: 1e-9)

        // The shared anchors, by name, so a future move of `sleepTargetHours` or
        // `sleepDeficitFloorHours` fails this test explicitly and not only by minute index.
        XCTAssertEqual(Engine.tierDScore(tstMinutes: 450), 70.0, accuracy: 0.001)
        XCTAssertEqual(Engine.tierDScore(tstMinutes: 480), 80.0, accuracy: 0.001)
        XCTAssertEqual(Engine.tierDScore(tstMinutes: 540), 100.0, accuracy: 0.001)
    }
}
