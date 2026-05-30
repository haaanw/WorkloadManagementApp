import XCTest
@testable import workload_management

/// Phase 26 Plan 02 — `BaselineEngine` numerics-vs-oracle tests.
///
/// Proves the robust-baseline math against HAND-COMPUTED oracles to 1e-9: λ formula, EWMA fold,
/// Welford-vs-two-pass (numerical stability), MAD×1.4826, Huber clamp (strictly < unclipped),
/// the prequential **no-leak** ordering (fold-before-score would change z), σ-floor + cold-start nil,
/// confidence ramp + stale collapse, CV firing + hysteresis no-flap, and the caller-owned
/// idempotency cutoff contract (W-1).
///
/// Pure engine ⇒ no @MainActor, no SwiftData. All dates derive from a fixed anchor (NO `.now`).
final class BaselineEngineTests: XCTestCase {

    typealias State = BaselineEngine.SignalState
    typealias Config = BaselineEngine.SignalConfig
    typealias CV = BaselineEngine.CVWarning

    // Fixed anchor — never `.now` (determinism / no-leak discipline).
    private let anchor = Date(timeIntervalSince1970: 1_700_000_000)  // 2023-11-14T22:13:20Z
    private func day(_ offset: Int) -> Date {
        anchor.addingTimeInterval(Double(offset) * 86_400.0)
    }

    // MARK: - λ formula

    func test_lambdaMatchesFormula() {
        XCTAssertEqual(
            BaselineEngine.lambda(halfLifeDays: 7.0),
            1.0 - pow(2.0, -1.0 / 7.0),
            accuracy: 1e-9
        )
        // ≈ 0.0943 sanity (loose — the 1e-9 formula assert above is the real oracle).
        XCTAssertEqual(BaselineEngine.lambda(halfLifeDays: 7.0), 0.0943, accuracy: 1e-3)
        // Infinite / non-positive half-life ⇒ no decay weight.
        XCTAssertEqual(BaselineEngine.lambda(halfLifeDays: .infinity), 0.0, accuracy: 1e-12)
        XCTAssertEqual(BaselineEngine.lambda(halfLifeDays: 0.0), 0.0, accuracy: 1e-12)
    }

    // MARK: - EWMA fold oracle

    func test_ewmaFoldOracle() {
        // Fixed λ via a chosen half-life; feed a sequence whose innovations stay WITHIN the Huber
        // bound so no clipping fires (ŷ == y) → μ is a pure EWMA of the raw values.
        let config = Config.hrv  // λ = 1 - 2^(-1/7)
        let lambda = BaselineEngine.lambda(halfLifeDays: config.halfLifeDays)

        // Build a long stable warm-up so σ_mad is large enough that small steps never clip,
        // then a few measured folds we oracle exactly.
        let seq: [Double] = [50, 51, 49, 50, 52, 48, 50, 51, 49, 50]
        var state = State()
        var muOracle: Double? = nil

        for (i, y) in seq.enumerated() {
            // Compute the would-be clipped observation the SAME way the engine does, so the oracle
            // matches exactly even if a step happened to clip.
            let yHat: Double
            if let muPrev = state.mu {
                let sigma = BaselineEngine.robustScale(
                    state.madBuffer, floor: config.sigmaFloor,
                    welfordSD: nil)  // welfordSD path not needed; engine recomputes internally
                // We recompute σ exactly as the engine: robustScale uses Welford fallback only when
                // buffer < W_min, and here floors dominate early — fold the engine's own result back.
                _ = sigma
                let actualSigma = engineSigma(state, config: config)
                let bound = BaselineEngine.BaselineConstants.huberK * actualSigma
                let r = y - muPrev
                let rHat = min(max(r, -bound), bound)
                yHat = muPrev + rHat
            } else {
                yHat = y
            }

            if muOracle == nil {
                muOracle = yHat
            } else {
                muOracle = (1.0 - lambda) * muOracle! + lambda * yHat
            }
            state = BaselineEngine.step(state: state, observation: y, config: config, bucketedDate: day(i))
            XCTAssertEqual(state.mu!, muOracle!, accuracy: 1e-9, "EWMA μ diverged at fold \(i)")
        }
    }

    /// Mirror of the engine's internal σ for a given state (robustScale with the Welford fallback).
    private func engineSigma(_ state: State, config: Config) -> Double {
        let welfordSD: Double?
        if state.count >= 2 {
            let v = state.m2 / Double(state.count - 1)
            welfordSD = (v.isFinite && v >= 0) ? sqrt(v) : nil
        } else {
            welfordSD = nil
        }
        return BaselineEngine.robustScale(state.madBuffer, floor: config.sigmaFloor, welfordSD: welfordSD)
    }

    // MARK: - Welford vs two-pass (W-2: center on welfordMean accumulator, NOT EWMA μ)

    func test_welfordVsTwoPass() {
        // Mean ≫ variance array to exercise numerical stability (the whole point of Welford M2).
        // Choose values whose innovations never clip so the engine's Welford accumulator tracks the
        // RAW values; then two-pass over those SAME raw values, centered on their MEAN.
        let config = Config.sleep  // floor 15 → generous Huber bound, no clipping for these steps
        let values: [Double] = [1_000_000.0, 1_000_004.0, 999_998.0, 1_000_002.0,
                                1_000_000.0, 1_000_006.0, 999_996.0, 1_000_001.0]

        var state = State()
        for (i, y) in values.enumerated() {
            state = BaselineEngine.step(state: state, observation: y, config: config, bucketedDate: day(i))
        }
        // Verify no clipping happened so welfordMean == mean(values) (raw).
        XCTAssertEqual(state.count, values.count)

        // W-2 ORACLE: center the two-pass variance on the WELFORD running mean accumulator
        // (state.welfordMean), NOT on the EWMA μ. They differ; centering on μ would spuriously fail.
        let welfordMean = state.welfordMean
        let twoPassMean = values.reduce(0, +) / Double(values.count)
        // W-2 sanity: the Welford accumulator IS the simple running mean of the (unclipped) values,
        // a SEPARATE accumulator from the EWMA μ. The variance oracle below MUST center on this
        // welfordMean, not on state.mu (centering on μ would spuriously fail the assert).
        XCTAssertEqual(welfordMean, twoPassMean, accuracy: 1e-6,
                       "welfordMean must equal the simple mean of the raw values (no clipping path)")

        let twoPassM2 = values.reduce(0.0) { $0 + ($1 - twoPassMean) * ($1 - twoPassMean) }
        let twoPassVar = twoPassM2 / Double(values.count - 1)

        let welfordVar = state.m2 / Double(state.count - 1)
        XCTAssertEqual(welfordVar, twoPassVar, accuracy: 1e-9,
                       "Welford M2/(n-1) must equal two-pass variance centered on welfordMean")
        XCTAssertEqual(sqrt(welfordVar), sqrt(twoPassVar), accuracy: 1e-9)
    }

    // MARK: - MAD oracle

    func test_madOracle() {
        // robustScale over a KNOWN buffer (≥ W_min) = 1.4826 × median(|r − median(r)|).
        let buffer: [Double] = [2.0, -1.0, 4.0, 0.0, -3.0, 1.0, 5.0]  // 7 ≥ W_min(5)
        let floor = 0.0001  // tiny floor so MAD dominates

        // Hand oracle:
        // sorted = [-3,-1,0,1,2,4,5] → median = 1
        // |r-1| = [1,2,3,1,4,0,4] → sorted [0,1,1,2,3,4,4] → median = 2
        // σ = 1.4826 × 2 = 2.9652
        let expected = BaselineEngine.BaselineConstants.madScaleK * 2.0
        let scale = BaselineEngine.robustScale(buffer, floor: floor, welfordSD: nil)
        XCTAssertEqual(scale, expected, accuracy: 1e-9)
        XCTAssertEqual(scale, 2.9652, accuracy: 1e-9)
    }

    // MARK: - Huber clamp (strictly less than un-clipped)

    func test_huberClampsOutlier() {
        let config = Config.hrv

        // Warm up to a steady μ and a small, well-defined σ_mad with low-variance data.
        var state = State()
        let warm: [Double] = [50, 50.5, 49.5, 50, 50.2, 49.8, 50.1, 49.9, 50, 50.3]
        for (i, y) in warm.enumerated() {
            state = BaselineEngine.step(state: state, observation: y, config: config, bucketedDate: day(i))
        }
        let muPrev = state.mu!
        let sigma = engineSigma(state, config: config)
        let k = BaselineEngine.BaselineConstants.huberK
        let lambda = BaselineEngine.lambda(halfLifeDays: config.halfLifeDays)

        // A massive +6σ-ish outlier.
        let outlier = muPrev + 6.0 * max(sigma, 1.0) + 40.0
        let rawInnovation = outlier - muPrev

        // Un-clipped EWMA delta (what an un-robust fold WOULD move μ by).
        let unclippedDelta = lambda * rawInnovation

        // Clipped delta: influence bounded to ±k·σ.
        let bound = k * sigma
        let clipped = min(max(rawInnovation, -bound), bound)
        let clippedDeltaOracle = lambda * clipped

        let after = BaselineEngine.step(state: state, observation: outlier, config: config, bucketedDate: day(warm.count))
        let actualDelta = after.mu! - muPrev

        XCTAssertEqual(actualDelta, clippedDeltaOracle, accuracy: 1e-9,
                       "μ move must equal the Huber-clipped EWMA delta")
        XCTAssertLessThan(actualDelta, unclippedDelta,
                          "clipped μ move must be STRICTLY less than the un-clipped EWMA move")
        // Influence bounded by k·σ folded through λ.
        XCTAssertLessThanOrEqual(actualDelta, lambda * bound + 1e-9)
    }

    // MARK: - Prequential no-leak ordering

    func test_noLeakOrdering() {
        let config = Config.hrv

        // Build a state with a clean baseline, buffer ≥ W_min, count ≥ 2.
        var state = State()
        let warm: [Double] = [50, 51, 49, 50, 52, 48, 50, 51]
        for (i, y) in warm.enumerated() {
            state = BaselineEngine.step(state: state, observation: y, config: config, bucketedDate: day(i))
        }

        // Today's observation — a deviation.
        let y = 62.0

        // No-leak (correct): score against state THROUGH t-1.
        let muPrev = state.mu!
        let sigmaPrev = engineSigma(state, config: config)
        let zCorrect = (y - muPrev) / sigmaPrev  // higherIsBetter → no negation
        let scored = BaselineEngine.score(state: state, observation: y, config: config)
        XCTAssertNotNil(scored.z)
        XCTAssertEqual(scored.z!, zCorrect, accuracy: 1e-9,
                       "score() must use μ/σ through t-1 (no-leak)")

        // Leaked (wrong): fold first, THEN score — μ and σ have already absorbed today's value,
        // shrinking the innovation and hence |z|.
        let folded = BaselineEngine.step(state: state, observation: y, config: config, bucketedDate: day(warm.count))
        let leaked = BaselineEngine.score(state: folded, observation: y, config: config)
        XCTAssertNotNil(leaked.z)

        // The two orders DIVERGE, and folding-first shrinks |z| (the leak hides the deviation).
        XCTAssertNotEqual(scored.z!, leaked.z!, accuracy: 1e-6,
                          "fold-before-score must change z (otherwise no-leak isn't demonstrated)")
        XCTAssertGreaterThan(abs(scored.z!), abs(leaked.z!),
                             "the leaked (folded-first) z must be SMALLER — the fold absorbs the deviation")
    }

    // MARK: - σ floor + cold-start nil

    func test_sigmaFloorAndColdNil() {
        let config = Config.hrv

        // count < 2 ⇒ z == nil (after the first fold, count == 1).
        var state = State()
        state = BaselineEngine.step(state: state, observation: 50.0, config: config, bucketedDate: day(0))
        XCTAssertEqual(state.count, 1)
        XCTAssertNil(BaselineEngine.score(state: state, observation: 52.0, config: config).z,
                     "count < 2 ⇒ z nil")

        // buffer < W_min ⇒ z == nil even with count ≥ 2.
        state = BaselineEngine.step(state: state, observation: 50.0, config: config, bucketedDate: day(1))
        state = BaselineEngine.step(state: state, observation: 50.0, config: config, bucketedDate: day(2))
        XCTAssertGreaterThanOrEqual(state.count, 2)
        XCTAssertLessThan(state.madBuffer.count, BaselineEngine.BaselineConstants.madMinValid)
        XCTAssertNil(BaselineEngine.score(state: state, observation: 52.0, config: config).z,
                     "buffer < W_min ⇒ z nil")

        // Identical readings (σ → 0) ⇒ floored σ ⇒ z FINITE (never inf/NaN) once gates pass.
        var flat = State()
        for i in 0..<8 {
            flat = BaselineEngine.step(state: flat, observation: 50.0, config: config, bucketedDate: day(i))
        }
        let z = BaselineEngine.score(state: flat, observation: 53.0, config: config).z
        XCTAssertNotNil(z)
        XCTAssertTrue(z!.isFinite, "σ floor must keep z finite when dispersion ≈ 0")
        // innovation 3 / floor 3 = 1.0 exactly (σ_mad is 0 → floor dominates).
        XCTAssertEqual(z!, 3.0 / config.sigmaFloor, accuracy: 1e-9)
    }

    // MARK: - Confidence ramp + stale collapse

    func test_confidenceRamp() {
        let config = Config.hrv

        // count ≤ floorDays ⇒ confidence ≈ 0.
        var state = State()
        for i in 0..<BaselineEngine.BaselineConstants.confFloorDays {
            // Stable, small jitter so cvRatio stays ≈ 1 (c_disp ≈ 1).
            let y = 50.0 + Double(i % 3 - 1) * 0.5
            state = BaselineEngine.step(state: state, observation: y, config: config, bucketedDate: day(i))
        }
        XCTAssertEqual(BaselineEngine.confidence(state: state, daysSinceLastBucket: 0), 0.0, accuracy: 1e-9,
                       "confidence ≈ 0 at count ≤ floorDays")

        // Ramp to count ≥ fullDays on fresh stable data ⇒ confidence ≈ 1.
        for i in BaselineEngine.BaselineConstants.confFloorDays..<(BaselineEngine.BaselineConstants.confFullDays + 5) {
            let y = 50.0 + Double(i % 3 - 1) * 0.5
            state = BaselineEngine.step(state: state, observation: y, config: config, bucketedDate: day(i))
        }
        let cFull = BaselineEngine.confidence(state: state, daysSinceLastBucket: 0)
        XCTAssertGreaterThan(cFull, 0.9, "confidence ≈ 1 by count ≥ fullDays on stable data")
        XCTAssertLessThanOrEqual(cFull, 1.0)

        // Monotonicity: a mid count is between the floor and the full confidence.
        var mid = State()
        let midCount = (BaselineEngine.BaselineConstants.confFloorDays + BaselineEngine.BaselineConstants.confFullDays) / 2
        for i in 0..<midCount {
            mid = BaselineEngine.step(state: mid, observation: 50.0 + Double(i % 3 - 1) * 0.5, config: config, bucketedDate: day(i))
        }
        let cMid = BaselineEngine.confidence(state: mid, daysSinceLastBucket: 0)
        XCTAssertGreaterThan(cMid, 0.0)
        XCTAssertLessThan(cMid, cFull, "confidence must be monotone increasing in count")

        // Stale collapse: a large daysSinceLastBucket cuts c_recency toward 0 regardless of count.
        let cStale = BaselineEngine.confidence(state: state, daysSinceLastBucket: 6)
        XCTAssertLessThan(cStale, cFull, "a 6-day-stale baseline must be lower-confidence than fresh")
        // Beyond the hard cut ⇒ ≈ 0.
        let cDead = BaselineEngine.confidence(
            state: state, daysSinceLastBucket: BaselineEngine.BaselineConstants.staleHardCutDays)
        XCTAssertEqual(cDead, 0.0, accuracy: 1e-12, "beyond staleHardCutDays ⇒ confidence 0")
    }

    // MARK: - CV fires on instability + hysteresis no-flap

    func test_cvFiresOnInstability() {
        // Use a tiny floor so the MAD-dispersion RATIO drives the test (the σ_floor is a
        // divide-by-tiny guard; here we want the median-of-|r| ratio to dominate, not the floor).
        let floor = 0.001

        // Clean, low-variance residual series → ratio ≈ 1 → stays .normal.
        let calm: [Double] = Array(repeating: 2.0, count: 15) + Array(repeating: -2.0, count: 15)
        // |r| is uniformly 2.0 in both windows → ratio = 1.0 → normal.
        let calmResult = BaselineEngine.cvUpdate(
            innovationBuffer: Array(calm.dropLast()),
            todayInnovation: calm.last!,
            floor: floor, previousLevel: .normal)
        XCTAssertEqual(calmResult.ratio!, 1.0, accuracy: 1e-9)
        XCTAssertEqual(calmResult.level, .normal, "clean equal-dispersion residuals stay normal")

        // Flat-mean RISING-variance: baseline |r| = 2.0 over the long window, recent |r| = 16.0
        // over the short window → ratio = 8.0 ≫ 1.5, with ≥ cvMinValid long-window residuals → HIGH.
        let rising: [Double] = Array(repeating: 2.0, count: 21) + Array(repeating: 16.0, count: 7)
        let highResult = BaselineEngine.cvUpdate(
            innovationBuffer: Array(rising.dropLast()),
            todayInnovation: rising.last!,
            floor: floor, previousLevel: .normal)
        XCTAssertEqual(highResult.level, .high, "flat-mean rising-variance residuals fire HIGH")
        XCTAssertNotNil(highResult.ratio)
        XCTAssertGreaterThanOrEqual(highResult.ratio!, BaselineEngine.BaselineConstants.cvHigh)

        // Hysteresis no-flap: a ratio in the dead-band (cvClear < ratio < cvElevated). Build it so
        // short-window |r| = 1.18 vs long-window |r| = 1.0 → ratio = 1.18.
        let deadband: [Double] = Array(repeating: 1.0, count: 21) + Array(repeating: 1.18, count: 7)
        let heldNormal = BaselineEngine.cvUpdate(
            innovationBuffer: Array(deadband.dropLast()),
            todayInnovation: deadband.last!,
            floor: floor, previousLevel: .normal)
        XCTAssertEqual(heldNormal.ratio!, 1.18, accuracy: 1e-9)
        XCTAssertGreaterThan(heldNormal.ratio!, BaselineEngine.BaselineConstants.cvClear)
        XCTAssertLessThan(heldNormal.ratio!, BaselineEngine.BaselineConstants.cvElevated)
        XCTAssertEqual(heldNormal.level, .normal, "dead-band ratio must NOT flap up from normal")
        // previous .elevated → holds elevated (does not drop until ≤ cvClear).
        let heldElevated = BaselineEngine.cvUpdate(
            innovationBuffer: Array(deadband.dropLast()),
            todayInnovation: deadband.last!,
            floor: floor, previousLevel: .elevated)
        XCTAssertEqual(heldElevated.level, .elevated, "dead-band ratio must hold previous elevated (no flap)")
    }

    // MARK: - Idempotency cutoff (W-1 — caller-owned contract)

    func test_idempotencyCutoff() {
        let config = Config.hrv

        // The engine is DATELESS and does NOT self-guard: calling step twice DOES advance state.
        // This is by design — the CALLER (DayBucketer) gates on lastBucketedDate. We prove the
        // contract two ways:

        // (1) The engine stamps lastBucketedDate when given a bucketedDate (caller's cutoff source).
        var state = State()
        state = BaselineEngine.step(state: state, observation: 50.0, config: config, bucketedDate: day(5))
        XCTAssertEqual(state.lastBucketedDate, day(5),
                       "step stamps lastBucketedDate — the caller's monotonic cutoff source")

        // (2) The caller-side guard (startOfDay(t) > lastBucketedDate) makes re-presenting a no-op.
        //     We emulate the contract: only fold when strictly after lastBucketedDate.
        func callerFold(_ s: State, _ y: Double, _ t: Date) -> State {
            guard let last = s.lastBucketedDate else {
                return BaselineEngine.step(state: s, observation: y, config: config, bucketedDate: t)
            }
            guard t > last else { return s }  // idempotent no-op for an already-folded day
            return BaselineEngine.step(state: s, observation: y, config: config, bucketedDate: t)
        }

        let countBefore = state.count
        let muBefore = state.mu
        // Re-present the SAME day → caller guard makes it a no-op.
        let rePresented = callerFold(state, 99.0, day(5))
        XCTAssertEqual(rePresented.count, countBefore, "re-presenting the same day must NOT advance count")
        XCTAssertEqual(rePresented.mu, muBefore, "re-presenting the same day must NOT move μ")

        // Advancing to a strictly-later day DOES fold.
        let advanced = callerFold(state, 52.0, day(6))
        XCTAssertEqual(advanced.count, countBefore + 1, "a strictly-later day advances the fold")
        XCTAssertEqual(advanced.lastBucketedDate, day(6))
    }
}
