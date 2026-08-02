import XCTest
@testable import workload_management

/// Sleep score v2 — the pure engine, under the council composition
/// (`.planning/sleep-v2/council-composition-ruling.md`, 2026-08-02).
///
/// The load-bearing tests here are the two the milestone is contracted on:
/// `test_tierD_isBitIdenticalToRecoveryScoreEngineSleepCurve` (the frozen fallback path)
/// and the H-16 composition group — need-met lands exactly 80, quality earns/loses the
/// last 20, the tier maxima (100 / 92 / 85–93) fall out with no renormalization.
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

    private func allQuality() -> Set<Engine.SleepComponent> {
        [.continuity, .regularity, .deep, .rem]
    }

    // MARK: - Duration curve (§5.1, unscaled — D of the H-16 composition)

    func test_durationCurve_anchors() {
        // §5.1's table verbatim, 0–100. The 0.80 share is applied in the composition,
        // never inside the curve.
        let expected: [(r: Double, y: Double)] = [
            (0.60, 10), (0.70, 32), (0.80, 55),
            (0.85, 68), (0.90, 80), (0.95, 90), (1.00, 100)
        ]
        for point in expected {
            let score = Engine.durationScore(tstMinutes: point.r * 100, needMinutes: 100)
            XCTAssertEqual(score, point.y, accuracy: 0.001, "duration ratio \(point.r)")
        }
    }

    /// HAN's 80/20 rule as arithmetic: D plateaus at 100 however long the night, and its
    /// share of the composite is exactly 0.80 — so hours alone can never beat 80.
    func test_durationCurve_plateausAtOneHundred_andSharesExactlyEighty() {
        XCTAssertEqual(Engine.durationScore(tstMinutes: 450, needMinutes: 450), 100.0, accuracy: 1e-9)
        XCTAssertEqual(Engine.durationScore(tstMinutes: 600, needMinutes: 450), 100.0, accuracy: 1e-9)
        XCTAssertEqual(Engine.durationScore(tstMinutes: 900, needMinutes: 450), 100.0, accuracy: 1e-9)
        XCTAssertEqual(Engine.durationShare, 0.80, accuracy: 1e-12)
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
        XCTAssertEqual(Engine.durationScore(tstMinutes: 30, needMinutes: 100), 10.0, accuracy: 0.001)
        XCTAssertEqual(Engine.durationScore(tstMinutes: 55, needMinutes: 100), 10.0, accuracy: 0.001)
    }

    // MARK: - Continuity curve

    func test_continuityCurve_anchors() {
        let expected: [(efficiency: Double, y: Double)] = [
            (0.65, 20), (0.75, 45), (0.80, 62), (0.85, 80), (0.88, 90), (0.92, 100)
        ]
        for point in expected {
            let score = Engine.continuityScore(
                tstMinutes: point.efficiency * 1000,
                inBedMinutes: 1000
            )
            XCTAssertNotNil(score)
            XCTAssertEqual(score!, point.y, accuracy: 0.001, "efficiency \(point.efficiency)")
        }

        // The met anchor: athlete-normal 85% reads exactly the shared met point of 80
        // (§5.1 rationale, Leeder) — met continuity adds exactly zero to the composite.
        let athleteNormal = Engine.continuityScore(tstMinutes: 850, inBedMinutes: 1000)
        XCTAssertEqual(athleteNormal!, Engine.qualityMetAnchor, accuracy: 0.001)
    }

    /// Council ruling 2026-08-02: efficiency needs the TRUE opportunity window. Without
    /// an in-bed span there is no honest denominator — WASO carries no authority (which
    /// is why Tier B tops at 92).
    func test_continuity_requiresTheInBedWindow() {
        XCTAssertNotNil(Engine.continuityScore(tstMinutes: 420, inBedMinutes: 480))
        XCTAssertNil(Engine.continuityScore(tstMinutes: 420, inBedMinutes: nil))
    }

    /// An in-bed span shorter than TST is a re-binning artifact (§3), not an efficiency
    /// above 100% — the component drops out rather than lying.
    func test_continuity_nilWhenInBedShorterThanTst() {
        XCTAssertNil(Engine.continuityScore(tstMinutes: 420, inBedMinutes: 400))
        XCTAssertNil(Engine.continuityScore(tstMinutes: 420, inBedMinutes: 0))
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
        // The met anchor: a 60-minute midpoint SD is an ordinary athlete fortnight and
        // reads exactly 80 — met regularity adds exactly zero.
        XCTAssertEqual(
            Engine.regularityScore(midpointSD14Minutes: 60)!,
            Engine.qualityMetAnchor,
            accuracy: 0.001
        )
    }

    // MARK: - Stage curve

    /// H-11 (REVISED by the council ruling 2026-08-02): met point q = 1.00 → 80 (the
    /// shared met anchor — met-at-85 would silently hand back a free 5 points), 0.85 → 75
    /// so the curve stays strictly increasing, excellent q ≥ 1.30 → 100 unchanged,
    /// sub-baseline anchors and the 45 floor unchanged.
    func test_stageCurve_anchors() {
        let expected: [(q: Double, y: Double)] = [
            (0.40, 45), (0.55, 55), (0.70, 70), (0.85, 75), (1.00, 80), (1.30, 100)
        ]
        for point in expected {
            let score = Engine.stageScore(minutes: point.q * 100, baselineMinutes: 100)
            XCTAssertNotNil(score)
            XCTAssertEqual(score!, point.y, accuracy: 0.001, "stage ratio \(point.q)")
        }
        // The met point and the excellent point, pinned explicitly.
        XCTAssertEqual(
            Engine.stageScore(minutes: 100, baselineMinutes: 100)!,
            Engine.qualityMetAnchor,
            accuracy: 1e-9
        )
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

    // MARK: - The H-16 composition

    /// "Hours get you to 80." Need met, every quality component at the athlete's own
    /// normal: the score lands EXACTLY 80 — met quality adds exactly zero.
    func test_needMetTypicalNight_landsExactlyEighty() {
        let input = night(
            tst: 425,
            inBed: 500,                 // efficiency 0.85 -> 80, the met anchor
            needBase: 425,              // r = 1.00 -> D = 100
            state: tierAState(midpointSD14: 60)   // SD 60 -> 80, the met anchor
        )
        // Stages at baseline (60/60, 90/90) -> q = 1.00 -> 80, the met anchor.
        let result = Engine.compute(input: input)
        XCTAssertEqual(result.tier, .a)
        XCTAssertEqual(result.activeProfiles, [.baseline])
        XCTAssertNotNil(result.score)
        XCTAssertEqual(result.score!, 80.0, accuracy: 0.001)
    }

    /// A wholly excellent Tier-A night reaches exactly 100: 80 + 8 + 5 + 3.5 + 3.5.
    func test_wholeExcellentTierANight_reachesExactlyOneHundred() {
        let input = night(
            tst: 470,
            deep: 84,                   // q = 1.4 -> 100
            rem: 140,                   // q = 1.4 -> 100
            inBed: 500,                 // efficiency 0.94 -> 100
            remBaseline: 100,
            needBase: 450,              // r > 1.00 -> D = 100
            state: tierAState(midpointSD14: 20)   // -> 100
        )
        let result = Engine.compute(input: input)
        XCTAssertEqual(result.tier, .a)
        XCTAssertNotNil(result.score)
        XCTAssertEqual(result.score!, 100.0, accuracy: 0.001)
    }

    /// The ±1 clamp is the nocebo guard: a need-met night with CATASTROPHIC quality
    /// floors at exactly 60 — each component subtracts its full points and no more.
    func test_needMetNightWithAllQualityAtFloor_landsExactlySixty() {
        let input = night(
            tst: 450,
            deep: 5,                    // q = 0.083 -> floor 45 -> clamped to -1
            rem: 5,                     // q = 0.056 -> floor 45 -> clamped to -1
            inBed: 750,                 // efficiency 0.60 -> 20 -> clamped to -1
            needBase: 450,              // r = 1.00 -> D = 100
            state: tierAState(midpointSD14: 300)  // floor 45 -> clamped to -1
        )
        let result = Engine.compute(input: input)
        XCTAssertEqual(result.tier, .a)
        XCTAssertEqual(result.activeProfiles, [.baseline])
        XCTAssertNotNil(result.score)
        // 80 - 8 - 5 - 3.5 - 3.5 = 60.
        XCTAssertEqual(result.score!, 60.0, accuracy: 0.001)
    }

    /// "100 is never merely long" — doubling the night with identical met quality changes
    /// nothing, and the landing is the 80 hours alone can buy.
    func test_merelyLongNight_cannotBeatEighty() {
        func longNight(tst: Double, inBed: Double) -> Engine.SleepInput {
            night(
                tst: tst,
                inBed: inBed,                       // efficiency 0.85, the met anchor
                needBase: 425,
                state: tierAState(midpointSD14: 60) // met anchor
            )
        }
        // Stages stay at baseline (the helper's 60/60, 90/90) on both nights.
        let atNeed = Engine.compute(input: longNight(tst: 425, inBed: 500))
        let doubled = Engine.compute(input: longNight(tst: 850, inBed: 1000))
        XCTAssertNotNil(atNeed.score)
        XCTAssertNotNil(doubled.score)
        XCTAssertEqual(atNeed.score!, 80.0, accuracy: 0.001)
        XCTAssertEqual(doubled.score!, atNeed.score!, accuracy: 1e-6)
        // Duration's D is pinned flat at 100 on both nights — hours buy nothing past 80.
        XCTAssertEqual(atNeed.componentScores[.duration]!, 100.0, accuracy: 1e-9)
        XCTAssertEqual(doubled.componentScores[.duration]!, 100.0, accuracy: 1e-9)
    }

    /// The clamp itself, pinned at the formula level (H-16).
    func test_qualityContribution_clampsAtPlusMinusOne() {
        XCTAssertEqual(Engine.qualityContribution(80), 0.0, accuracy: 1e-12)
        XCTAssertEqual(Engine.qualityContribution(100), 1.0, accuracy: 1e-12)
        XCTAssertEqual(Engine.qualityContribution(120), 1.0, accuracy: 1e-12)   // clamped
        XCTAssertEqual(Engine.qualityContribution(90), 0.5, accuracy: 1e-12)
        XCTAssertEqual(Engine.qualityContribution(70), -0.5, accuracy: 1e-12)
        XCTAssertEqual(Engine.qualityContribution(60), -1.0, accuracy: 1e-12)
        XCTAssertEqual(Engine.qualityContribution(20), -1.0, accuracy: 1e-12)   // clamped
    }

    /// Missing evidence cannot testify — in EITHER direction. A met component and an
    /// absent component both contribute exactly zero; a sub-met component subtracts.
    func test_missingComponent_contributesZeroEitherDirection() {
        func nightWithSD(_ sd: Double?) -> Engine.SleepInput {
            night(
                tst: 425,
                inBed: 500,                    // efficiency 0.85 -> met
                needBase: 425.0 / 0.9,         // r = 0.90 -> D = 80 -> 0.8 x 80 = 64
                state: tierAState(midpointSD14: sd)
            )
        }
        let met = Engine.compute(input: nightWithSD(60))       // regularity met -> +0
        let missing = Engine.compute(input: nightWithSD(nil))  // regularity absent -> +0
        let subMet = Engine.compute(input: nightWithSD(120))   // floor 45 -> -1 -> -5

        XCTAssertEqual(met.score!, 64.0, accuracy: 0.01)
        XCTAssertEqual(missing.score!, met.score!, accuracy: 0.001)
        XCTAssertEqual(subMet.score!, met.score! - Engine.regularityPoints, accuracy: 0.001)
        // The absent component is zeroed in the audit record, not renormalized away.
        XCTAssertEqual(missing.points.regularity, 0.0, accuracy: 1e-12)
        XCTAssertNil(missing.componentScores[.regularity])
    }

    /// Sub-met continuity SUBTRACTS (signed composition): a fragmented night on real
    /// efficiency data must read worse than its hours alone.
    func test_subMetContinuity_subtracts() {
        let fragmented = night(
            tst: 450,
            inBed: 600,                 // efficiency 0.75 -> 45 -> clamped to -1 -> -8
            needBase: 450,
            state: tierAState(midpointSD14: 60)
        )
        let result = Engine.compute(input: fragmented)
        // 80 (met everything else) - 8.
        XCTAssertEqual(result.score!, 72.0, accuracy: 0.001)
    }

    /// The pool is never renormalized over missing components: excellent-everything with
    /// no regularity buffer reaches 95, not 100.
    func test_pool_doesNotRenormalizeOverMissingComponents() {
        let input = night(
            tst: 470,
            deep: 84,
            rem: 140,
            inBed: 500,
            remBaseline: 100,
            needBase: 450,
            state: tierAState(midpointSD14: nil)
        )
        let result = Engine.compute(input: input)
        XCTAssertEqual(result.tier, .a)
        // 80 + 8 + 3.5 + 3.5; regularity's 5 points are simply absent.
        XCTAssertEqual(result.score!, 95.0, accuracy: 0.001)
        XCTAssertEqual(result.points.regularity, 0.0, accuracy: 1e-12)
    }

    /// The tier maxima are epistemic caps (H-17) and fall out of the composition with no
    /// new constants: A 100 · B 92 (no in-bed span, no continuity) · C 85 timing-only,
    /// 93 with continuity · D exempt by contract (bit-identical legacy, reaches 100).
    func test_tierMaxima_fallOutOfTheComposition() {
        // Tier B best: excellent stages + timing, no in-bed span -> 80 + 5 + 3.5 + 3.5 = 92.
        let tierBBest = Engine.compute(input: Engine.SleepInput(
            tstMinutes: 470,
            deepMinutes: 84,
            remMinutes: 140,
            awakeMinutes: 20,           // WASO present — and worth nothing (council ruling)
            deepBaselineMinutes: 60,
            remBaselineMinutes: 100,
            needBaseMinutes: 450,
            state: Engine.SleepStateVector(
                midpointSD14Minutes: 10,
                hasStageData: true,
                nightsOfHistory: 40
            )
        ))
        XCTAssertEqual(tierBBest.tier, .b)
        XCTAssertEqual(tierBBest.points.continuity, 0.0, accuracy: 1e-12)
        XCTAssertNil(tierBBest.componentScores[.continuity])
        XCTAssertEqual(tierBBest.score!, 92.0, accuracy: 0.001)

        // Tier C timing-only best: 80 + 5 = 85.
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
        XCTAssertEqual(tierCBest.points.continuity, 0.0, accuracy: 1e-12)
        XCTAssertEqual(tierCBest.score!, 85.0, accuracy: 0.001)

        // Tier C with an in-bed span: 80 + 8 + 5 = 93.
        let tierCWithContinuity = Engine.compute(input: Engine.SleepInput(
            tstMinutes: 600,
            inBedMinutes: 620,          // efficiency 0.968 -> 100
            needBaseMinutes: 450,
            state: Engine.SleepStateVector(
                midpointSD14Minutes: 10,
                hasStageData: false,
                nightsOfHistory: 40
            )
        ))
        XCTAssertEqual(tierCWithContinuity.tier, .c)
        XCTAssertEqual(tierCWithContinuity.points.continuity, Engine.continuityPoints, accuracy: 1e-12)
        XCTAssertEqual(tierCWithContinuity.score!, 93.0, accuracy: 0.001)

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
        // All-excellent under a profile stack: transfers shrink the pool, never grow the
        // composite past 100.
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

        // All-worst: 0.8 x 10 - 20 would be -12; the composite floors at 0.
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
        XCTAssertEqual(worstResult.score!, 0.0, accuracy: 1e-9)
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

        // Genuinely duration-only: no stages, no timing, no in-bed span. WASO alone does
        // not rescue the night (council ruling: no in-bed span, no continuity).
        XCTAssertEqual(
            Engine.tier(for: night(
                deep: nil,
                rem: nil,
                awake: 30,
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
    /// contribute zero (H-16); the night must not be demoted to a tier that throws the
    /// measured continuity away — §5.1 calls continuity the most reliably measured of the
    /// five inputs.
    func test_missingStageBaseline_dropsStagesButKeepsContinuity() {
        let input = night(
            tst: 450,
            awake: 30,
            inBed: 500,                 // efficiency 0.90 -> 95 -> +0.75 x 8 = +6
            deepBaseline: nil,          // EWMA not seeded yet
            remBaseline: nil,
            needBase: 450,
            state: tierAState(midpointSD14: 45, nights: 8)   // 90 -> +0.5 x 5 = +2.5
        )
        let result = Engine.compute(input: input)

        XCTAssertEqual(result.tier, .a)
        XCTAssertNil(result.componentScores[.deep])
        XCTAssertNil(result.componentScores[.rem])
        XCTAssertEqual(result.componentScores[.continuity]!, 95.0, accuracy: 0.001)
        XCTAssertEqual(result.points.deep, 0.0, accuracy: 1e-12)
        XCTAssertEqual(result.points.rem, 0.0, accuracy: 1e-12)
        XCTAssertEqual(result.points.continuity, Engine.continuityPoints, accuracy: 1e-12)
        XCTAssertEqual(result.points.regularity, Engine.regularityPoints, accuracy: 1e-12)
        // 80 + 6 + 2.5, with the absent stages contributing zero — not renormalized.
        XCTAssertEqual(result.score!, 88.5, accuracy: 0.001)
    }

    /// Same defect from the other direction: a source that reports no stages at all, but
    /// does report an in-bed span (§3: manual and iPhone-only entries write `inBed`).
    func test_tierC_keepsContinuityWhenTheSourceGivesAnInBedSpan() {
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
        XCTAssertEqual(result.points.continuity, Engine.continuityPoints, accuracy: 1e-12)
        XCTAssertEqual(result.points.regularity, Engine.regularityPoints, accuracy: 1e-12)
        XCTAssertEqual(result.points.deep, 0.0, accuracy: 1e-12)
        XCTAssertEqual(result.points.rem, 0.0, accuracy: 1e-12)
        XCTAssertEqual(result.score!, 88.5, accuracy: 0.001)
    }

    /// The tier names the SOURCE'S data grade; what actually carried authority is
    /// `points` / `componentScores`, which is what §9.4 rule 5 stores. Both partial cases
    /// below are legal and must zero honestly rather than silently pretend.
    func test_tierLabel_doesNotPromiseEveryComponentScored() {
        // Tier A with no 14-night midpoint buffer yet: regularity drops.
        let noTiming = Engine.compute(input: night(
            tst: 430,
            needBase: 430,
            state: tierAState(midpointSD14: nil, nights: 10)
        ))
        XCTAssertEqual(noTiming.tier, .a)
        XCTAssertNil(noTiming.componentScores[.regularity])
        XCTAssertEqual(noTiming.points.regularity, 0.0, accuracy: 1e-12)
        XCTAssertFalse(noTiming.points.availableComponents.contains(.regularity))

        // Tier B has no continuity denominator by definition: continuity drops.
        let noContinuity = Engine.compute(input: night(
            tst: 430,
            awake: nil,
            inBed: nil,
            needBase: 430,
            state: tierAState(midpointSD14: 45, nights: 10)
        ))
        XCTAssertEqual(noContinuity.tier, .b)
        XCTAssertNil(noContinuity.componentScores[.continuity])
        XCTAssertEqual(noContinuity.points.continuity, 0.0, accuracy: 1e-12)
        XCTAssertFalse(noContinuity.points.availableComponents.contains(.continuity))
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

    func test_tierE_returnsNilScoreAndZeroPoints() {
        let result = Engine.compute(input: Engine.SleepInput(tstMinutes: nil))
        XCTAssertNil(result.score)
        XCTAssertEqual(result.tier, .e)
        XCTAssertEqual(result.confidence, 0.0, accuracy: 1e-12)
        XCTAssertEqual(result.points.total, 0.0, accuracy: 1e-12)
        XCTAssertTrue(result.componentScores.isEmpty)
        XCTAssertNil(result.needTonightMinutes)
    }

    /// Tier C timing-only: regularity is the only quality authority, so a met-regularity
    /// need-met night is exactly the 80 hours buy.
    func test_tierC_timingOnly_regularityIsTheOnlyQualityAuthority() {
        let input = Engine.SleepInput(
            tstMinutes: 450,
            needBaseMinutes: 450,
            state: Engine.SleepStateVector(
                midpointSD14Minutes: 60,     // the met anchor
                hasStageData: false,
                nightsOfHistory: 30
            )
        )
        let result = Engine.compute(input: input)
        XCTAssertEqual(result.tier, .c)
        XCTAssertEqual(result.activeProfiles, [.baseline])
        XCTAssertEqual(result.points.regularity, Engine.regularityPoints, accuracy: 1e-12)
        XCTAssertEqual(result.points.continuity, 0.0, accuracy: 1e-12)
        XCTAssertEqual(result.points.deep, 0.0, accuracy: 1e-12)
        XCTAssertEqual(result.points.rem, 0.0, accuracy: 1e-12)
        XCTAssertEqual(result.score!, 80.0, accuracy: 0.001)
    }

    func test_tierD_carriesNoQualityPoints() {
        // A profile-triggering state that must not reach the points on the frozen tier.
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
        XCTAssertEqual(result.points.total, 0.0, accuracy: 1e-12)
        XCTAssertEqual(result.componentScores.count, 1)
        XCTAssertEqual(
            result.componentScores[.duration]!,
            RecoveryScoreEngine.sleepDurationToScore(450),
            accuracy: 1e-12
        )
        XCTAssertTrue(result.activeProfiles.contains(.debtCarry))
    }

    /// The composition deliberately does not apply to the compatibility tier.
    func test_tierD_ignoresNeedAndComposition() {
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
    /// flip the points on and off night after night. H-13, kept exactly as S1 shipped it.
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

    // MARK: - Point composition (H-16 / H-18)

    /// The ruling's constants of record, pinned by name so a silent retune fails loudly.
    func test_pointVector_constantsOfRecord() {
        XCTAssertEqual(Engine.durationShare, 0.80, accuracy: 1e-12)
        XCTAssertEqual(Engine.continuityPoints, 8.0, accuracy: 1e-12)
        XCTAssertEqual(Engine.regularityPoints, 5.0, accuracy: 1e-12)
        XCTAssertEqual(Engine.deepPoints, 3.5, accuracy: 1e-12)
        XCTAssertEqual(Engine.remPoints, 3.5, accuracy: 1e-12)
        XCTAssertEqual(Engine.qualityMetAnchor, 80.0, accuracy: 1e-12)
        XCTAssertEqual(Engine.qualityBandWidth, 20.0, accuracy: 1e-12)

        // The pool is 20 on the full tiers; Tier C grants the stages nothing.
        XCTAssertEqual(Engine.basePoints(for: .a).total, 20.0, accuracy: 1e-12)
        XCTAssertEqual(Engine.basePoints(for: .b).total, 20.0, accuracy: 1e-12)
        XCTAssertEqual(
            Engine.basePoints(for: .c),
            Engine.QualityPoints(continuity: 8.0, regularity: 5.0)
        )
        XCTAssertEqual(Engine.basePoints(for: .d), Engine.QualityPoints())
        XCTAssertEqual(Engine.basePoints(for: .e), Engine.QualityPoints())
    }

    /// H-18: §9.3's quality-side weight deltas scaled by exactly x40 (the 0.50 quality
    /// weight pool maps onto the 20-point pool), preserving each profile's internal
    /// ratios; duration-side deltas DROPPED (§4's need credits already move that lever).
    func test_pointTransfers_translateTheProfileDeltaTable() {
        XCTAssertEqual(Engine.pointTransfers(for: .baseline), Engine.QualityPoints())
        XCTAssertEqual(Engine.pointTransfers(for: .napDay), Engine.QualityPoints())
        // HIGH_PRESSURE: deep +0.04 / reg -0.07 / REM -0.02, ratios 4 : -7 : -2.
        XCTAssertEqual(
            Engine.pointTransfers(for: .highPressure),
            Engine.QualityPoints(regularity: -2.8, deep: 1.6, rem: -0.8)
        )
        // HIGH_STRAIN_DAY: deep +0.03 / reg -0.05.
        XCTAssertEqual(
            Engine.pointTransfers(for: .highStrainDay),
            Engine.QualityPoints(regularity: -2.0, deep: 1.2)
        )
        // ACUTE_SHIFT: cont +0.05 / reg -0.10; the stage response is the half cap.
        XCTAssertEqual(
            Engine.pointTransfers(for: .acuteShift),
            Engine.QualityPoints(continuity: 2.0, regularity: -4.0)
        )
        // CHRONIC_IRREGULAR: reg +0.07 / deep -0.02 / REM -0.02.
        XCTAssertEqual(
            Engine.pointTransfers(for: .chronicIrregular),
            Engine.QualityPoints(regularity: 2.8, deep: -0.8, rem: -0.8)
        )
        // DEBT_CARRY: every quality component cedes 0.02 -> 0.8 points.
        XCTAssertEqual(
            Engine.pointTransfers(for: .debtCarry),
            Engine.QualityPoints(continuity: -0.8, regularity: -0.8, deep: -0.8, rem: -0.8)
        )
    }

    /// Transfers stack and the pool total moves with them — there is NO renormalization
    /// back to 20. The moved total is the honest audit record.
    func test_points_transfersStackWithoutRenormalization() {
        let points = Engine.composePoints(
            base: Engine.basePoints(for: .a),
            profiles: [.highPressure, .debtCarry],
            available: allQuality()
        )
        XCTAssertEqual(points.continuity, 7.2, accuracy: 1e-9)   // 8 - 0.8
        XCTAssertEqual(points.regularity, 1.4, accuracy: 1e-9)   // 5 - 2.8 - 0.8
        XCTAssertEqual(points.deep, 4.3, accuracy: 1e-9)         // 3.5 + 1.6 - 0.8
        XCTAssertEqual(points.rem, 1.9, accuracy: 1e-9)          // 3.5 - 0.8 - 0.8
        XCTAssertEqual(points.total, 14.8, accuracy: 1e-9)
    }

    /// A point allocation floors at zero under a deep stack — negative points would
    /// invert the component's meaning, turning better-than-normal quality into a penalty.
    func test_points_flooredAtZero() {
        let points = Engine.composePoints(
            base: Engine.basePoints(for: .a),
            profiles: [.highPressure, .highStrainDay, .debtCarry],
            available: allQuality()
        )
        // Regularity: 5 - 2.8 - 2.0 - 0.8 = -0.6, floored.
        XCTAssertEqual(points.regularity, 0.0, accuracy: 1e-12)
        XCTAssertEqual(points.deep, 5.5, accuracy: 1e-9)         // 3.5 + 1.6 + 1.2 - 0.8
        XCTAssertEqual(points.continuity, 7.2, accuracy: 1e-9)
        XCTAssertEqual(points.rem, 1.9, accuracy: 1e-9)
    }

    func test_points_droppedComponentNeverReceivesATransfer() {
        // HIGH_PRESSURE carries a deep transfer, but the stages are unavailable here and
        // absent components can neither testify nor absorb authority.
        let points = Engine.composePoints(
            base: Engine.basePoints(for: .c),
            profiles: [.highPressure],
            available: [.regularity]
        )
        XCTAssertEqual(points.deep, 0.0, accuracy: 1e-12)
        XCTAssertEqual(points.rem, 0.0, accuracy: 1e-12)
        XCTAssertEqual(points.continuity, 0.0, accuracy: 1e-12)
        XCTAssertEqual(points.regularity, 2.2, accuracy: 1e-9)   // 5 - 2.8
    }

    /// "Stage components capped at half authority" (§9.3), council-translated: the stage
    /// points are halved for the acute night — 3.5 -> 1.75 each, measured against BASE.
    func test_acuteShift_halvesStagePoints() {
        let points = Engine.composePoints(
            base: Engine.basePoints(for: .a),
            profiles: [.acuteShift],
            available: allQuality()
        )
        XCTAssertEqual(points.deep, 1.75, accuracy: 1e-12)
        XCTAssertEqual(points.rem, 1.75, accuracy: 1e-12)
        XCTAssertEqual(points.continuity, 10.0, accuracy: 1e-9)  // 8 + 2
        XCTAssertEqual(points.regularity, 1.0, accuracy: 1e-9)   // 5 - 4
    }

    /// The half cap holds under stacking: a positive deep transfer from HIGH_PRESSURE
    /// cannot push a stage past half its base authority on an acute night.
    func test_acuteShift_stageCapHoldsUnderStacking() {
        let points = Engine.composePoints(
            base: Engine.basePoints(for: .a),
            profiles: [.highPressure, .acuteShift],
            available: allQuality()
        )
        XCTAssertEqual(points.deep, 1.75, accuracy: 1e-12)       // min(3.5 + 1.6, 1.75)
        XCTAssertEqual(points.rem, 1.75, accuracy: 1e-12)
    }

    /// End to end: a latched profile moves the score by exactly (transfer x contribution),
    /// with the need held equal across the pair so only the points differ.
    func test_profileTransfer_movesScoreByPointsTimesContribution() {
        // Debt 160 sits in DEBT_CARRY's hold band: latched stays on, fresh stays off —
        // while the §4 debt credit (ungated, capped at 30) is identical for both runs.
        func run(previous: Set<Engine.SleepProfile>) -> Engine.SleepResult {
            Engine.compute(input: night(
                tst: 480,
                deep: 69,                  // q = 1.15 -> 90 -> contribution +0.5
                rem: 103.5,                // q = 1.15 -> 90 -> +0.5
                inBed: 480 / 0.88,         // efficiency 0.88 -> 90 -> +0.5
                needBase: 450,             // + debt credit 30 -> need 480 -> D = 100
                state: Engine.SleepStateVector(
                    midpointSD14Minutes: 45,   // 90 -> +0.5
                    sleepDebt7Minutes: 160,
                    hasStageData: true,
                    nightsOfHistory: 30
                ),
                previousProfiles: previous
            ))
        }
        let fresh = run(previous: [])
        let latched = run(previous: [.debtCarry])

        XCTAssertEqual(fresh.activeProfiles, [.baseline])
        XCTAssertTrue(latched.activeProfiles.contains(.debtCarry))
        XCTAssertEqual(fresh.needTonightMinutes!, latched.needTonightMinutes!, accuracy: 1e-9)

        // Fresh: 80 + 0.5 x (8 + 5 + 3.5 + 3.5) = 90.
        XCTAssertEqual(fresh.score!, 90.0, accuracy: 0.01)
        // Latched: every quality point cedes 0.8, so 80 + 0.5 x 16.8 = 88.4 — a delta of
        // exactly (0.8 x 4) x 0.5 = 1.6.
        XCTAssertEqual(latched.score!, 88.4, accuracy: 0.01)
        XCTAssertEqual(latched.points.total, 16.8, accuracy: 1e-9)
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

    /// The residual step at a trigger is the §9.3 point transfer alone — states are
    /// states, not gradients — and under the H-16 composition it is well under a point.
    func test_score_stepAtTheDebtTriggerIsSmall() {
        func scored(debt: Double) -> Double {
            let input = night(
                tst: 450,
                inBed: 450 / 0.865,                    // continuity raw = 85 -> +0.25
                needBase: 450,
                state: Engine.SleepStateVector(
                    midpointSD14Minutes: 52.5,         // regularity raw = 85 -> +0.25
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
        XCTAssertEqual(result.points.total, 20.0, accuracy: 1e-9)
        for component in result.points.availableComponents {
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
                || result.points.total != 0
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
