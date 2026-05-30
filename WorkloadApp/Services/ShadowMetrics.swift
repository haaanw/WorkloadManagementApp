import Foundation

/// Pure validation metrics over resolved shadow predictions (Phase 24, Plan 02, D-09/D-10).
///
/// All math lives here as deterministic static functions — Foundation only, no SwiftData, no
/// HealthKit, no I/O. `ShadowAnalyticsService` extracts paired `(predicted, actual)` values per
/// arm/outcome and calls in; it performs no statistics itself (D-15).
///
/// Every function degrades gracefully: insufficient or degenerate input returns `nil` (or
/// `.insufficientData`) — never a `NaN`, a crash, or a fabricated number (D-10). The numeric
/// activation gates (MAE beat ≥3/4, ρ≥0.50, slope∈[0.8,1.2]) are *applied* in Phase 29 — this
/// phase ships only the machinery.
struct ShadowMetrics {

    // MARK: - Calibration slope (reliability slope)

    /// OLS slope of `actual ~ predicted` = cov(predicted, actual) / var(predicted).
    ///
    /// A perfectly-calibrated arm (`actual == predicted`) returns 1.0; systematic over/under-
    /// confidence shows as a slope below/above 1. Returns `nil` for `n < 2` or zero predictor
    /// variance (a vertical/degenerate fit has no defined slope).
    static func calibrationSlope(pairs: [(predicted: Double, actual: Double)]) -> Double? {
        guard pairs.count >= 2 else { return nil }
        let n = Double(pairs.count)
        let meanP = pairs.reduce(0.0) { $0 + $1.predicted } / n
        let meanA = pairs.reduce(0.0) { $0 + $1.actual } / n
        var cov = 0.0, varP = 0.0
        for p in pairs {
            let dp = p.predicted - meanP
            cov += dp * (p.actual - meanA)
            varP += dp * dp
        }
        guard varP > 0 else { return nil }
        return cov / varP
    }

    // MARK: - Spearman rank correlation

    /// Spearman ρ = Pearson correlation of the average-rank-transformed columns. Robust to the
    /// nonlinearity of self-report scales. Average ranks handle ties. Returns `nil` for `n < 3`
    /// or when either ranked column is constant (no defined correlation).
    static func spearmanRho(pairs: [(predicted: Double, actual: Double)]) -> Double? {
        guard pairs.count >= 3 else { return nil }
        let rankedP = averageRanks(pairs.map(\.predicted))
        let rankedA = averageRanks(pairs.map(\.actual))
        return pearson(rankedP, rankedA)
    }

    /// Average (fractional) ranks of `values` — tied values share the mean of the ranks they span.
    /// 1-based ranks; e.g. [3, 1, 1, 2] → [4, 1.5, 1.5, 3].
    private static func averageRanks(_ values: [Double]) -> [Double] {
        let n = values.count
        let order = Array(0..<n).sorted { values[$0] < values[$1] }
        var ranks = [Double](repeating: 0, count: n)
        var i = 0
        while i < n {
            var j = i
            // Extend over a run of equal values.
            while j + 1 < n && values[order[j + 1]] == values[order[i]] { j += 1 }
            // Ranks i..j (0-based) → 1-based ranks (i+1)...(j+1); average them.
            let avg = Double((i + 1) + (j + 1)) / 2.0
            for k in i...j { ranks[order[k]] = avg }
            i = j + 1
        }
        return ranks
    }

    /// Pearson correlation; `nil` if either input has zero variance.
    private static func pearson(_ xs: [Double], _ ys: [Double]) -> Double? {
        guard xs.count == ys.count, xs.count >= 2 else { return nil }
        let n = Double(xs.count)
        let mx = xs.reduce(0, +) / n
        let my = ys.reduce(0, +) / n
        var cov = 0.0, vx = 0.0, vy = 0.0
        for i in 0..<xs.count {
            let dx = xs[i] - mx, dy = ys[i] - my
            cov += dx * dy
            vx += dx * dx
            vy += dy * dy
        }
        guard vx > 0, vy > 0 else { return nil }
        return cov / (vx.squareRoot() * vy.squareRoot())
    }

    // MARK: - Blocked / purged cross-validation splitter

    /// A single time-ordered CV fold: a contiguous test block and the train indices that remain
    /// after removing the test block AND a `purge`-wide gap on each side of it (no random split).
    struct CVFold: Equatable {
        var test: Range<Int>
        var train: [Int]
    }

    /// Partition `0..<count` into `folds` contiguous, time-ordered test blocks; the train side of
    /// each fold excludes the test block and a `purge`-wide gap (>= prediction horizon) on each
    /// side, so no train row sits within `purge` of any test row (prevents autocorrelation leakage).
    ///
    /// No shuffling — blocks preserve the athlete's day order. Degenerate rule: `folds <= 1`, or a
    /// `count` too small to form the requested folds (`count < folds`), returns a SINGLE full-data
    /// fold `[0..<count, train: []]` (documented, never a crash). `count == 0` returns `[]`.
    static func blockedCVSplits(count: Int, folds: Int, purge: Int = 1) -> [CVFold] {
        guard count > 0 else { return [] }
        guard folds > 1, count >= folds else {
            return [CVFold(test: 0..<count, train: [])]
        }
        let g = max(0, purge)
        let base = count / folds
        let remainder = count % folds
        var result: [CVFold] = []
        var start = 0
        for f in 0..<folds {
            // Distribute the remainder across the first `remainder` blocks (contiguous coverage).
            let size = base + (f < remainder ? 1 : 0)
            let testRange = start..<(start + size)
            let lo = testRange.lowerBound - g
            let hi = testRange.upperBound + g
            let train = (0..<count).filter { $0 < lo || $0 >= hi }
            result.append(CVFold(test: testRange, train: train))
            start += size
        }
        return result
    }

    // MARK: - Deterministic PRNG (SplitMix64)

    /// Small seedable PRNG so the block bootstrap is reproducible (NOT SystemRandomNumberGenerator).
    struct SplitMix64: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { self.state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    // MARK: - Block-bootstrap paired-MAE-difference CI

    /// Empirical confidence interval for the paired MAE difference `mean(errA - errB)` between two
    /// arms, via a **moving-block bootstrap** that resamples CONTIGUOUS blocks of the time-ordered
    /// per-row error differences — preserving daily autocorrelation (resampling individual rows
    /// would understate the CI). A CI that excludes 0 means the arms differ significantly; one that
    /// straddles 0 does not. `point` is the full-sample observed mean difference.
    ///
    /// `armA`/`armB` are aligned `(predicted, actual)` arrays in time order (same length).
    /// Deterministic under `seed`. Returns `nil` if the arrays differ in length, `n < 2`, or
    /// `n < blockLength`.
    static func pairedMAEDifferenceBlockBootstrapCI(
        armA: [(predicted: Double, actual: Double)],
        armB: [(predicted: Double, actual: Double)],
        blockLength: Int,
        resamples: Int,
        alpha: Double = 0.05,
        seed: UInt64
    ) -> (lower: Double, upper: Double, point: Double)? {
        guard armA.count == armB.count, armA.count >= 2, blockLength >= 1,
              armA.count >= blockLength, resamples >= 1, alpha > 0, alpha < 1 else {
            return nil
        }
        let n = armA.count
        // Per-row paired error difference d_i = |predA-actual| - |predB-actual|.
        var d = [Double](repeating: 0, count: n)
        for i in 0..<n {
            let eA = abs(armA[i].predicted - armA[i].actual)
            let eB = abs(armB[i].predicted - armB[i].actual)
            d[i] = eA - eB
        }
        let point = d.reduce(0, +) / Double(n)

        // Moving-block bootstrap: number of blocks needed to reconstruct ~n samples.
        let numBlocks = Int(ceil(Double(n) / Double(blockLength)))
        let maxStart = n - blockLength  // inclusive upper bound for a block start
        var rng = SplitMix64(seed: seed)

        var means = [Double](repeating: 0, count: resamples)
        for r in 0..<resamples {
            var sum = 0.0
            var taken = 0
            for _ in 0..<numBlocks {
                let start = maxStart == 0 ? 0 : Int(rng.next() % UInt64(maxStart + 1))
                for k in 0..<blockLength {
                    if taken >= n { break }
                    sum += d[start + k]
                    taken += 1
                }
                if taken >= n { break }
            }
            means[r] = sum / Double(taken)
        }
        means.sort()

        let lowerQ = quantile(sorted: means, p: alpha / 2.0)
        let upperQ = quantile(sorted: means, p: 1.0 - alpha / 2.0)
        return (lower: lowerQ, upper: upperQ, point: point)
    }

    /// Linear-interpolated empirical quantile of a pre-sorted array (`p` in [0, 1]).
    private static func quantile(sorted: [Double], p: Double) -> Double {
        guard let first = sorted.first else { return .nan }
        if sorted.count == 1 { return first }
        let clampedP = min(max(p, 0), 1)
        let pos = clampedP * Double(sorted.count - 1)
        let lo = Int(floor(pos))
        let hi = Int(ceil(pos))
        if lo == hi { return sorted[lo] }
        let frac = pos - Double(lo)
        return sorted[lo] * (1 - frac) + sorted[hi] * frac
    }
}
