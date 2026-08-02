import Foundation
import SwiftData

/// Sleep score v2, Phase S3 — the **§6 falsification criteria**, computed on demand from the
/// stored `SleepShadowNight` rows. Pure verdict math: no I/O, no clock, deterministic under a
/// seed. NO UI this phase (PLAN: the analysis struct is the deliverable; a readout can consume
/// `Report` later).
///
/// Statistics reuse (`ShadowMetrics`, per the shadow-infrastructure rule): Spearman ρ comes
/// from `ShadowMetrics.spearmanRho`, and the bootstrap resamples with
/// `ShadowMetrics.SplitMix64` using the same moving-block scheme as
/// `pairedMAEDifferenceBlockBootstrapCI` — contiguous blocks of the time-ordered rows, so
/// nightly autocorrelation is preserved. (§6 criterion 1 needs a CI on a Spearman
/// DIFFERENCE, which the MAE-difference helper cannot express — the resample loop here is the
/// only added machinery, and every statistic inside it is `ShadowMetrics`'s.)
///
/// Every verdict degrades to `.insufficientData` below its gate — never a fabricated pass or
/// fail (the `ShadowMetrics` nil discipline). Per H-33's process guard, the profile-frequency
/// reads (criterion 5 and the per-profile counts) are only meaningful for nights folded AFTER
/// the S3 pass-throughs landed; the caller segments by date if S2-era rows exist.
struct SleepShadowAnalysis {

    // MARK: - Input record

    /// The plain value slice of one `SleepShadowNight` the criteria consume. Tests build
    /// these directly; production maps rows via `records(from:)`.
    struct NightRecord {
        let wakeDate: Date
        /// `SleepScoreEngine.SleepTier` raw value ("A"…"E").
        let tierRaw: String
        let sourceBundleID: String?
        let v2Score: Double?
        /// The v1 sleep component score for the same night.
        let v1Score: Double?
        /// The H-38 sleep-free readiness proxy (the §6 outcome), joined next morning.
        let sleepFreeReadiness: Double?
        let midpointSD14Minutes: Double?
        let deepQ: Double?
        let remQ: Double?
        let needBaseMinutes: Double?
        let tstMinutes: Double

        init(
            wakeDate: Date,
            tierRaw: String,
            sourceBundleID: String? = nil,
            v2Score: Double? = nil,
            v1Score: Double? = nil,
            sleepFreeReadiness: Double? = nil,
            midpointSD14Minutes: Double? = nil,
            deepQ: Double? = nil,
            remQ: Double? = nil,
            needBaseMinutes: Double? = nil,
            tstMinutes: Double = 0
        ) {
            self.wakeDate = wakeDate
            self.tierRaw = tierRaw
            self.sourceBundleID = sourceBundleID
            self.v2Score = v2Score
            self.v1Score = v1Score
            self.sleepFreeReadiness = sleepFreeReadiness
            self.midpointSD14Minutes = midpointSD14Minutes
            self.deepQ = deepQ
            self.remQ = remQ
            self.needBaseMinutes = needBaseMinutes
            self.tstMinutes = tstMinutes
        }
    }

    /// Map stored rows to analysis records.
    static func records(from rows: [SleepShadowNight]) -> [NightRecord] {
        rows.map {
            NightRecord(
                wakeDate: $0.wakeDate,
                tierRaw: $0.tierRaw,
                sourceBundleID: $0.sourceBundleID,
                v2Score: $0.v2Score,
                v1Score: $0.v1SleepComponentScore,
                sleepFreeReadiness: $0.sleepFreeReadiness,
                midpointSD14Minutes: $0.midpointSD14Minutes,
                deepQ: $0.deepQ,
                remQ: $0.remQ,
                needBaseMinutes: $0.needBaseMinutes,
                tstMinutes: $0.tstMinutes
            )
        }
    }

    // MARK: - Verdicts

    enum Verdict: String {
        /// Every arm of the criterion RAN and none found a failure.
        case pass
        /// At least one arm that ran proved a failure.
        case fail
        /// Every arm that ran found no failure, but at least one arm could not run
        /// (below its gate) — never promoted to `.pass`. Criteria 2 and 4 issue this
        /// for their mixed states; the per-arm numbers in the criterion struct say
        /// which arm is missing.
        case partial
        /// Criterion 3 only: the statistical arm found no association (CI straddles
        /// zero). §6 cuts regularity only when this AND HAN's not-actionable report
        /// coincide — the second condition is human, so code alone can never issue
        /// `.fail` for criterion 3.
        case statisticalNull
        /// No arm could run at all.
        case insufficientData
    }

    /// §6 criterion 1 — the whole-v2 test: v2's Spearman ρ against next-day sleep-free
    /// readiness must exceed v1's by a paired-bootstrap margin excluding zero.
    struct WholeV2Criterion {
        let verdict: Verdict
        /// Paired nights used (Tiers A–C only — Tier D is v1 by construction and Tier E has
        /// no score, so both arms are identical there and would only dilute the test; the
        /// engine's own doc says the analysis segments on the tier seam).
        let n: Int
        let rhoV2: Double?
        let rhoV1: Double?
        /// Full-sample Δρ = ρ(v2) − ρ(v1).
        let deltaRhoPoint: Double?
        /// Moving-block bootstrap CI for Δρ; pass ⇔ lower > 0.
        let ciLower: Double?
        let ciUpper: Double?
    }

    /// §6 criterion 2 — stage components are noise if their within-source night-to-night
    /// residual SD (in q) exceeds the q-range over which the stage curves move.
    /// `.pass` requires BOTH stages to clear the `minStagePairs` gate; one measured-calm
    /// stage plus one unmeasured stage is `.partial` (an unmeasured stage is not evidence
    /// of calm). A single measured-noisy stage still fails outright.
    struct StageNoiseCriterion {
        let verdict: Verdict
        /// √(Σd² / 2m) over consecutive-night q differences WITHIN each source's own
        /// subsequence (pooled across sources) — the standard first-difference noise
        /// estimator (removes slow baseline drift).
        let deepResidualSD: Double?
        let remResidualSD: Double?
        let deepPairCount: Int
        let remPairCount: Int
        /// The q-domain span of the engine's stage curve (H-40 mirror constant).
        let curveQRange: Double
    }

    /// §6 criterion 3 — regularity association with next-day readiness. This is the
    /// STATISTICAL arm only: §6 cuts regularity when the association is absent *and* HAN
    /// reports it as not actionable — the second condition is human, so this criterion's
    /// null outcome is `.statisticalNull`, never `.fail` (code alone cannot issue the cut).
    struct RegularityCriterion {
        let verdict: Verdict
        let n: Int
        let rho: Double?
        let ciLower: Double?
        let ciUpper: Double?
    }

    /// §6 criterion 4 — need-estimation guards: bound hit inside the first 90 days, and the
    /// alternating-week split-half disagreement. `.pass` requires BOTH guards to have
    /// actually run (a learned need existed to bound-check AND both halves cleared
    /// `minHalfNights`); one guard clean + one guard never-ran is `.partial`. The
    /// (a)-vs-(b) estimator comparison is not evaluable (estimator (b) was never built —
    /// H-19).
    struct NeedCriterion {
        let verdict: Verdict
        /// First night (if any) whose stored need sat on a §4 bound within 90 days of the
        /// first learned need.
        let boundHitDate: Date?
        /// |p75(odd weeks) − p75(even weeks)| of nightly TST; fail above 30 min.
        let splitHalfDeltaMinutes: Double?
        let oddHalfCount: Int
        let evenHalfCount: Int
        /// Always false this phase: estimator (b) does not exist (H-19).
        let estimatorBEvaluated: Bool
    }

    /// §6 criterion 5 — the per-tier night counts (the Whoop/Garmin coverage read). "Fails"
    /// means a source with real coverage delivers no staged nights — which does NOT kill v2,
    /// but makes Tier C that source's modal path and its weights first-class.
    struct TierCoverageCriterion {
        let verdict: Verdict
        let countsByTier: [String: Int]
        /// source bundle id → (tier raw → count). Unknown sources key as "unknown".
        let countsBySource: [String: [String: Int]]
        let modalTierRaw: String?
        /// Sources with at least `minSourceNights` nights and ZERO Tier A/B nights.
        let stagelessSources: [String]
    }

    struct Report {
        let nightCount: Int
        let wholeV2: WholeV2Criterion
        let stageNoise: StageNoiseCriterion
        let regularity: RegularityCriterion
        let need: NeedCriterion
        let tierCoverage: TierCoverageCriterion
    }

    // MARK: - Gates and constants (H-40 unless §6 names the number)

    /// §6 criterion 1's own night floor ("over ≥60 nights"); also reused as the correlation
    /// gate for criterion 3, which names none.
    static let minNightsForCorrelation: Int = 60
    /// Moving-block bootstrap parameters — the `ShadowAnalyticsService` defaults.
    /// Criterion 1 keeps the 7-night block (its per-night scores decorrelate fast).
    static let bootstrapBlockLength: Int = 7
    /// Criterion 3's OWN block length: its predictor (`midpointSD14`) is a 14-night
    /// rolling SD (lag-1 autocorrelation ≈ 0.93), so the resample block must cover the
    /// predictor's dependence length — 7-night blocks would split dependent runs and
    /// narrow the CI anti-conservatively. H-40.
    static let regularityBootstrapBlockLength: Int = 14
    static let bootstrapResamples: Int = 1000
    /// The q-domain span of `SleepScoreEngine`'s stage curve (anchors 0.40 … 1.30). The
    /// engine's anchor table is private, so this mirrors it by value — H-40 registers the
    /// mirror so an engine retune cannot drift silently.
    static let stageCurveQRange: Double = 0.90
    /// Minimum within-source consecutive-night pairs before a stage residual SD is a
    /// measurement. H-40.
    static let minStagePairs: Int = 30
    /// Minimum nights per split-half before the p75s are compared. H-40.
    static let minHalfNights: Int = 14
    /// Minimum nights from one source before its stage coverage is judged (criterion 5).
    /// H-40.
    static let minSourceNights: Int = 7
    /// §6 criterion 4: split-halves may disagree by at most 30 minutes.
    static let splitHalfMaxDeltaMinutes: Double = 30.0
    /// §6 criterion 4: a bound hit counts within the first 90 days of learned need.
    static let boundHitWindowDays: Int = 90
    /// Equality tolerance for "sits on a bound" (the stored need is clamped INTO the
    /// bounds, so a hit is an exact clamp).
    private static let boundEpsilonMinutes: Double = 0.5

    // MARK: - Entry points

    /// Compute the five §6 criteria over stored rows.
    static func analyze(
        rows: [SleepShadowNight],
        minNights: Int = minNightsForCorrelation,
        seed: UInt64 = 0x5EED
    ) -> Report {
        analyze(nights: records(from: rows), minNights: minNights, seed: seed)
    }

    /// Compute the five §6 criteria over plain records (the testable entry point).
    static func analyze(
        nights: [NightRecord],
        minNights: Int = minNightsForCorrelation,
        seed: UInt64 = 0x5EED
    ) -> Report {
        let ordered = nights.sorted { $0.wakeDate < $1.wakeDate }
        return Report(
            nightCount: ordered.count,
            wholeV2: wholeV2Criterion(ordered, minNights: minNights, seed: seed),
            stageNoise: stageNoiseCriterion(ordered),
            regularity: regularityCriterion(ordered, minNights: minNights, seed: seed),
            need: needCriterion(ordered),
            tierCoverage: tierCoverageCriterion(ordered)
        )
    }

    // MARK: - Criterion 1 (whole v2)

    static func wholeV2Criterion(
        _ ordered: [NightRecord],
        minNights: Int,
        seed: UInt64
    ) -> WholeV2Criterion {
        // Tiers A–C only: on Tier D the two arms are bit-identical by contract and on
        // Tier E neither scores — both would only shrink any real difference.
        let eligible = ordered.filter {
            ["A", "B", "C"].contains($0.tierRaw)
                && $0.v2Score != nil && $0.v1Score != nil && $0.sleepFreeReadiness != nil
        }
        let n = eligible.count
        guard n >= minNights else {
            return WholeV2Criterion(
                verdict: .insufficientData, n: n,
                rhoV2: nil, rhoV1: nil, deltaRhoPoint: nil, ciLower: nil, ciUpper: nil
            )
        }

        let v2 = eligible.compactMap(\.v2Score)
        let v1 = eligible.compactMap(\.v1Score)
        let outcome = eligible.compactMap(\.sleepFreeReadiness)

        func deltaRho(_ indices: [Int]) -> Double? {
            let rho2 = ShadowMetrics.spearmanRho(
                pairs: indices.map { (predicted: v2[$0], actual: outcome[$0]) }
            )
            let rho1 = ShadowMetrics.spearmanRho(
                pairs: indices.map { (predicted: v1[$0], actual: outcome[$0]) }
            )
            guard let rho2, let rho1 else { return nil }
            return rho2 - rho1
        }

        let fullIndices = Array(0..<n)
        let rhoV2 = ShadowMetrics.spearmanRho(
            pairs: fullIndices.map { (predicted: v2[$0], actual: outcome[$0]) }
        )
        let rhoV1 = ShadowMetrics.spearmanRho(
            pairs: fullIndices.map { (predicted: v1[$0], actual: outcome[$0]) }
        )
        let point = deltaRho(fullIndices)
        guard let point,
              let ci = blockBootstrapCI(count: n, seed: seed, statistic: deltaRho) else {
            return WholeV2Criterion(
                verdict: .insufficientData, n: n,
                rhoV2: rhoV2, rhoV1: rhoV1, deltaRhoPoint: point, ciLower: nil, ciUpper: nil
            )
        }

        // §6: v2 must EXCEED v1 by a margin excluding zero — pass ⇔ the CI's lower bound
        // is strictly positive; anything else fails the whole-v2 test.
        return WholeV2Criterion(
            verdict: ci.lower > 0 ? .pass : .fail,
            n: n,
            rhoV2: rhoV2,
            rhoV1: rhoV1,
            deltaRhoPoint: point,
            ciLower: ci.lower,
            ciUpper: ci.upper
        )
    }

    // MARK: - Criterion 2 (stage noise)

    static func stageNoiseCriterion(_ ordered: [NightRecord]) -> StageNoiseCriterion {
        // Consecutive-night q differences WITHIN each source's own time-ordered
        // subsequence, pooled. Pairing physically adjacent rows would yield ZERO pairs
        // forever under strict two-source alternation; within-subsequence pairing keeps
        // every source's own night-to-night read. A skipped night (or an interleaved
        // other-source night) widens one gap — the estimator is a noise read, not a
        // spectral one, so the occasional wider gap only makes it conservative.
        func residual(_ q: (NightRecord) -> Double?) -> (sd: Double?, pairs: Int) {
            var seriesBySource: [String: [Double]] = [:]
            for night in ordered {
                guard let source = night.sourceBundleID, let value = q(night) else {
                    continue
                }
                seriesBySource[source, default: []].append(value)
            }
            var diffs: [Double] = []
            for series in seriesBySource.values where series.count >= 2 {
                for i in 1..<series.count {
                    diffs.append(series[i] - series[i - 1])
                }
            }
            guard diffs.count >= minStagePairs else { return (nil, diffs.count) }
            // Var(first difference of iid noise) = 2σ² ⇒ σ = √(Σd² / 2m).
            let sumSquares = diffs.reduce(0) { $0 + $1 * $1 }
            return ((sumSquares / (2.0 * Double(diffs.count))).squareRoot(), diffs.count)
        }

        let deep = residual { $0.deepQ }
        let rem = residual { $0.remQ }

        // A measured-noisy stage fails outright (§6: the component is noise; drop to
        // Tier C weights). Otherwise `.pass` needs BOTH stages measured — one measured
        // calm + one unmeasured is `.partial` (an unmeasured stage proves nothing).
        let verdict: Verdict
        if (deep.sd ?? 0) > stageCurveQRange || (rem.sd ?? 0) > stageCurveQRange {
            verdict = .fail
        } else if deep.sd != nil && rem.sd != nil {
            verdict = .pass
        } else if deep.sd != nil || rem.sd != nil {
            verdict = .partial
        } else {
            verdict = .insufficientData
        }
        return StageNoiseCriterion(
            verdict: verdict,
            deepResidualSD: deep.sd,
            remResidualSD: rem.sd,
            deepPairCount: deep.pairs,
            remPairCount: rem.pairs,
            curveQRange: stageCurveQRange
        )
    }

    // MARK: - Criterion 3 (regularity association — statistical arm)

    static func regularityCriterion(
        _ ordered: [NightRecord],
        minNights: Int,
        seed: UInt64
    ) -> RegularityCriterion {
        let eligible = ordered.filter {
            $0.midpointSD14Minutes != nil && $0.sleepFreeReadiness != nil
        }
        let n = eligible.count
        guard n >= minNights else {
            return RegularityCriterion(
                verdict: .insufficientData, n: n, rho: nil, ciLower: nil, ciUpper: nil
            )
        }
        let sd = eligible.compactMap(\.midpointSD14Minutes)
        let outcome = eligible.compactMap(\.sleepFreeReadiness)

        func rho(_ indices: [Int]) -> Double? {
            ShadowMetrics.spearmanRho(
                pairs: indices.map { (predicted: sd[$0], actual: outcome[$0]) }
            )
        }
        let point = rho(Array(0..<n))
        // Criterion 3 resamples with its OWN 14-night block (H-40): `midpointSD14`'s
        // dependence length is 14 nights, and a block shorter than the dependence
        // length under-covers the CI.
        guard let point,
              let ci = blockBootstrapCI(
                  count: n,
                  blockLength: regularityBootstrapBlockLength,
                  seed: seed,
                  statistic: rho
              ) else {
            return RegularityCriterion(
                verdict: .insufficientData, n: n, rho: point, ciLower: nil, ciUpper: nil
            )
        }
        // Association present ⇔ the CI excludes zero. The null outcome is
        // `.statisticalNull`, never `.fail`: §6 cuts regularity only when the absent
        // association AND HAN's not-actionable report coincide — code alone cannot
        // issue that cut.
        let associationPresent = ci.lower > 0 || ci.upper < 0
        return RegularityCriterion(
            verdict: associationPresent ? .pass : .statisticalNull,
            n: n,
            rho: point,
            ciLower: ci.lower,
            ciUpper: ci.upper
        )
    }

    // MARK: - Criterion 4 (need estimation)

    /// Day arithmetic uses a UTC-pinned gregorian calendar: the criteria only need elapsed
    /// whole days between stored wake days, and pinning the zone keeps the counts
    /// deterministic across host timezones and DST edges (analysis math, not user-facing
    /// bucketing).
    private static let dayCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    static func needCriterion(_ ordered: [NightRecord]) -> NeedCriterion {
        // (a) Bound hit within the first 90 days of learned need. The stored need is
        // clamped INTO [390, 570] (constants read from the builder, never retyped), so a
        // hit is an exact clamp within tolerance.
        var boundHitDate: Date?
        let needNights = ordered.filter { $0.needBaseMinutes != nil }
        if let firstNeed = needNights.first {
            let calendar = dayCalendar
            for night in needNights {
                let days = calendar.dateComponents(
                    [.day], from: firstNeed.wakeDate, to: night.wakeDate
                ).day ?? 0
                guard days <= boundHitWindowDays else { break }
                let need = night.needBaseMinutes!
                if need <= SleepStateBuilder.needLowerBoundMinutes + boundEpsilonMinutes
                    || need >= SleepStateBuilder.needUpperBoundMinutes - boundEpsilonMinutes {
                    boundHitDate = night.wakeDate
                    break
                }
            }
        }

        // (b) Alternating-week split-half of the p75-TST estimator (H-19's estimator (a),
        // via the builder's own percentile — never re-implemented).
        var odd: [Double] = []
        var even: [Double] = []
        if let first = ordered.first {
            let calendar = dayCalendar
            for night in ordered where night.tstMinutes > 0 {
                let days = calendar.dateComponents(
                    [.day], from: first.wakeDate, to: night.wakeDate
                ).day ?? 0
                if (days / 7) % 2 == 0 {
                    even.append(night.tstMinutes)
                } else {
                    odd.append(night.tstMinutes)
                }
            }
        }
        var splitDelta: Double?
        if odd.count >= minHalfNights && even.count >= minHalfNights {
            let oddP75 = SleepStateBuilder.percentile(odd, SleepStateBuilder.needPercentile)
            let evenP75 = SleepStateBuilder.percentile(even, SleepStateBuilder.needPercentile)
            splitDelta = abs(oddP75 - evenP75)
        }

        // `.pass` only when BOTH guards actually ran: the bound check needs a learned
        // need to inspect, the split-half needs both halves past `minHalfNights`. A
        // never-run guard is not a clean guard — one ran-clean + one never-ran is
        // `.partial`, never promoted to `.pass`.
        let boundArmRan = !needNights.isEmpty
        let splitArmRan = splitDelta != nil
        let verdict: Verdict
        if boundHitDate != nil {
            verdict = .fail
        } else if let splitDelta, splitDelta > splitHalfMaxDeltaMinutes {
            verdict = .fail
        } else if boundArmRan && splitArmRan {
            verdict = .pass
        } else if boundArmRan || splitArmRan {
            verdict = .partial
        } else {
            verdict = .insufficientData
        }
        return NeedCriterion(
            verdict: verdict,
            boundHitDate: boundHitDate,
            splitHalfDeltaMinutes: splitDelta,
            oddHalfCount: odd.count,
            evenHalfCount: even.count,
            estimatorBEvaluated: false
        )
    }

    // MARK: - Criterion 5 (tier coverage)

    static func tierCoverageCriterion(_ ordered: [NightRecord]) -> TierCoverageCriterion {
        guard !ordered.isEmpty else {
            return TierCoverageCriterion(
                verdict: .insufficientData, countsByTier: [:], countsBySource: [:],
                modalTierRaw: nil, stagelessSources: []
            )
        }
        var byTier: [String: Int] = [:]
        var bySource: [String: [String: Int]] = [:]
        for night in ordered {
            byTier[night.tierRaw, default: 0] += 1
            let source = night.sourceBundleID ?? "unknown"
            bySource[source, default: [:]][night.tierRaw, default: 0] += 1
        }
        // Deterministic modal tier: highest count wins, ties break toward the earlier
        // letter (the richer tier).
        let modal = byTier.sorted {
            if $0.value != $1.value { return $0.value > $1.value }
            return $0.key < $1.key
        }.first?.key
        let stageless = bySource
            .filter { source, tiers in
                source != "unknown"
                    && tiers.values.reduce(0, +) >= minSourceNights
                    && (tiers["A"] ?? 0) + (tiers["B"] ?? 0) == 0
            }
            .keys
            .sorted()
        return TierCoverageCriterion(
            verdict: stageless.isEmpty ? .pass : .fail,
            countsByTier: byTier,
            countsBySource: bySource,
            modalTierRaw: modal,
            stagelessSources: Array(stageless)
        )
    }

    // MARK: - Moving-block bootstrap (resampling only — statistics are ShadowMetrics')

    /// Percentile CI of `statistic` over moving-block resamples of `0..<count`, preserving
    /// time order inside each block (the `ShadowMetrics.pairedMAEDifferenceBlockBootstrapCI`
    /// scheme, generalized to an index statistic). Deterministic under `seed`. nil when the
    /// series is shorter than one block or too many resamples degenerate (a constant column
    /// makes Spearman undefined).
    static func blockBootstrapCI(
        count: Int,
        blockLength: Int = bootstrapBlockLength,
        resamples: Int = bootstrapResamples,
        alpha: Double = 0.05,
        seed: UInt64,
        statistic: ([Int]) -> Double?
    ) -> (lower: Double, upper: Double)? {
        guard count >= 2, blockLength >= 1, count >= blockLength,
              resamples >= 1, alpha > 0, alpha < 1 else { return nil }
        let numBlocks = Int(ceil(Double(count) / Double(blockLength)))
        let maxStart = count - blockLength
        var rng = ShadowMetrics.SplitMix64(seed: seed)

        var values: [Double] = []
        values.reserveCapacity(resamples)
        for _ in 0..<resamples {
            var indices: [Int] = []
            indices.reserveCapacity(count)
            for _ in 0..<numBlocks {
                let start = maxStart == 0 ? 0 : Int(rng.next() % UInt64(maxStart + 1))
                for offset in 0..<blockLength where indices.count < count {
                    indices.append(start + offset)
                }
                if indices.count >= count { break }
            }
            if let value = statistic(indices) {
                values.append(value)
            }
        }
        // Degenerate-resample guard: fewer than half the resamples produced a defined
        // statistic ⇒ the CI would be built on a biased subset.
        guard values.count >= resamples / 2 else { return nil }
        values.sort()
        return (
            lower: quantile(sorted: values, p: alpha / 2.0),
            upper: quantile(sorted: values, p: 1.0 - alpha / 2.0)
        )
    }

    /// Linear-interpolated empirical quantile of a pre-sorted array (`p` in [0, 1]) — the
    /// `ShadowMetrics` formula (its own helper is private).
    private static func quantile(sorted: [Double], p: Double) -> Double {
        guard let first = sorted.first else { return .nan }
        if sorted.count == 1 { return first }
        let clamped = min(max(p, 0), 1)
        let position = clamped * Double(sorted.count - 1)
        let low = Int(floor(position))
        let high = Int(ceil(position))
        if low == high { return sorted[low] }
        let fraction = position - Double(low)
        return sorted[low] * (1 - fraction) + sorted[high] * fraction
    }
}
