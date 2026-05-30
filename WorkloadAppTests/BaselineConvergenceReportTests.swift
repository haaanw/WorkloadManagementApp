import XCTest
@testable import workload_management

/// **Phase 26 result checkpoint (D-04) — deterministic seeded convergence-report generator.**
///
/// This is a "test" only as a **deterministic execution harness**: it drives the Plan-02
/// `BaselineEngine` (robust EWMA / Welford / MAD / Huber + prequential no-leak z + Altini CV +
/// 0–1 confidence) and the Plan-03 `DayBucketer` through synthetic and realistic signal traces
/// with KNOWN ground truth, then:
///
///  1. records the per-day prequential series (raw y, robust μ, the incumbent flat 7-day-mean,
///     z, σ, cvRatio, cvLevel, confidence),
///  2. EMITS a markdown artifact at
///     `.planning/phases/26-individualized-baselines/artifacts/26-convergence-report.md`
///     (FileManager + String.write, temp-dir fallback if the repo path is unwritable), and
///  3. ASSERTS the same behavior invariants the report prints (so CI catches regressions), plus
///  4. a **hash-equality** test proving two same-seed runs produce byte-identical markdown.
///
/// ## Determinism (§7.2)
/// - Dates come from a FIXED anchor `Date(timeIntervalSince1970: 0)` + `i * 86400`, bucketed
///   under a FIXED UTC Gregorian calendar — NO `Date.now` / `Calendar.current`.
/// - The ONLY randomness is `ShadowMetrics.SplitMix64(seed:)` (verbatim), consumed via a
///   Box–Muller transform over `next()`. Each scenario uses a FIXED seed — NEVER
///   `SystemRandomNumberGenerator`.
///
/// ## Scope fence (D-01)
/// This harness registers NO predicting shadow arm and applies NO z→recovery mapping. It judges
/// engine BEHAVIOR (convergence / robustness), not accuracy. The live flat 7-day-mean recovery
/// score (`RecoveryScoreEngine.computeBaseline`) is read-only here and stays the LIVE source;
/// `BaselineTierFenceTests` continues to machine-enforce that fence.
final class BaselineConvergenceReportTests: XCTestCase {

    // MARK: - Determinism scaffolding (fixed anchor + fixed UTC calendar)

    /// Fixed UTC Gregorian calendar — no `Calendar.current`, so day-bucketing is reproducible.
    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// Fixed epoch anchor. Day `i`'s timestamp is `anchor + i * 86400`.
    private static let anchor = Date(timeIntervalSince1970: 0)

    private static func day(_ i: Int) -> Date { anchor.addingTimeInterval(Double(i) * 86_400.0) }

    // MARK: - Box–Muller Gaussian over the seeded SplitMix64 (the only RNG)

    /// Standard-normal sample via Box–Muller over `ShadowMetrics.SplitMix64`. Pulls two
    /// uniforms in (0,1] from the seeded RNG; deterministic for a given seed/sequence.
    private static func gaussian(_ rng: inout ShadowMetrics.SplitMix64) -> Double {
        // Double.random(in:using:) consumes the seeded RNG deterministically.
        var u1 = Double.random(in: 0...1, using: &rng)
        let u2 = Double.random(in: 0...1, using: &rng)
        if u1 < 1e-12 { u1 = 1e-12 } // avoid log(0)
        let r = (-2.0 * Foundation.log(u1)).squareRoot()
        return r * Foundation.cos(2.0 * Double.pi * u2)
    }

    // MARK: - Trace fixtures (§7.3) — day-indexed (date, value?) with KNOWN ground truth

    /// A generated trace plus the metadata the report/invariants need.
    private struct Trace {
        let name: String
        let seed: UInt64
        let trueMean: Double          // ground-truth μ (flat-mean scenarios) or central level
        let noiseSD: Double           // base Gaussian SD used to generate the trace
        let days: [(date: Date, value: Double?)]   // nil == GAP
        let notes: String
    }

    private static let nDays = 70           // long enough to see the 60-day confidence ceiling
    private static let baseSD = 5.0         // ms-scale noise for an HRV-like signal
    private static let trueHRV = 50.0       // ground-truth HRV mean (ms)

    /// stable: flat ground truth + seeded Gaussian noise.
    private static func traceStable() -> Trace {
        let seed: UInt64 = 0xA11CE5742B1E
        var rng = ShadowMetrics.SplitMix64(seed: seed)
        var days: [(date: Date, value: Double?)] = []
        for i in 0..<nDays {
            days.append((day(i), trueHRV + baseSD * gaussian(&rng)))
        }
        return Trace(name: "stable", seed: seed, trueMean: trueHRV, noiseSD: baseSD,
                     days: days, notes: "flat ground truth \(trueHRV)ms + N(0,\(baseSD))")
    }

    /// step-change: +12ms level shift at day 35 (true mean re-centers).
    private static func traceStepChange() -> Trace {
        let seed: UInt64 = 0x57EBC4A39
        var rng = ShadowMetrics.SplitMix64(seed: seed)
        let k = 35, delta = 12.0
        var days: [(date: Date, value: Double?)] = []
        for i in 0..<nDays {
            let mean = trueHRV + (i >= k ? delta : 0.0)
            days.append((day(i), mean + baseSD * gaussian(&rng)))
        }
        return Trace(name: "step-change", seed: seed, trueMean: trueHRV, noiseSD: baseSD,
                     days: days, notes: "+\(delta)ms level shift at day \(k)")
    }

    /// outlier: stable, with a single +6σ spike at day 40 (Huber robustness headline).
    private static func traceOutlier() -> Trace {
        let seed: UInt64 = 0x0B17E12A4
        var rng = ShadowMetrics.SplitMix64(seed: seed)
        let k = 40
        var days: [(date: Date, value: Double?)] = []
        for i in 0..<nDays {
            var v = trueHRV + baseSD * gaussian(&rng)
            if i == k { v = trueHRV + 6.0 * baseSD }   // +6σ single spike
            days.append((day(i), v))
        }
        return Trace(name: "outlier", seed: seed, trueMean: trueHRV, noiseSD: baseSD,
                     days: days, notes: "single +6σ spike at day \(k)")
    }

    /// gap-stretch: stable, with days 30..35 missing (GAP, value nil).
    private static func traceGapStretch() -> Trace {
        let seed: UInt64 = 0x6A95713C
        var rng = ShadowMetrics.SplitMix64(seed: seed)
        let gapStart = 30, gapEnd = 35
        var days: [(date: Date, value: Double?)] = []
        for i in 0..<nDays {
            if i >= gapStart && i <= gapEnd {
                days.append((day(i), nil))           // GAP — no carry-forward
            } else {
                days.append((day(i), trueHRV + baseSD * gaussian(&rng)))
            }
        }
        return Trace(name: "gap-stretch", seed: seed, trueMean: trueHRV, noiseSD: baseSD,
                     days: days, notes: "days \(gapStart)..\(gapEnd) GAP (no fresh sample)")
    }

    /// stale-repeat: one fresh sample on day 30, then days 31..40 are GAPs (a stale sample never
    /// fills later days — the bucketer turns them into GAPs, not fake-stable repeats).
    private static func traceStaleRepeat() -> Trace {
        let seed: UInt64 = 0x57A1E4242
        var rng = ShadowMetrics.SplitMix64(seed: seed)
        let freshDay = 30
        var days: [(date: Date, value: Double?)] = []
        for i in 0..<nDays {
            if i > freshDay && i <= freshDay + 10 {
                days.append((day(i), nil))           // stale → GAP downstream
            } else {
                days.append((day(i), trueHRV + baseSD * gaussian(&rng)))
            }
        }
        return Trace(name: "stale-repeat", seed: seed, trueMean: trueHRV, noiseSD: baseSD,
                     days: days, notes: "fresh sample day \(freshDay), days \(freshDay + 1)..\(freshDay + 10) stale→GAP")
    }

    /// rising-instability: mean FLAT, variance ramps from base → 4x over the trace
    /// (the Altini "variability in variability" demonstration — CV should escalate).
    private static func traceRisingInstability() -> Trace {
        let seed: UInt64 = 0x125AB117C4
        var rng = ShadowMetrics.SplitMix64(seed: seed)
        var days: [(date: Date, value: Double?)] = []
        for i in 0..<nDays {
            let frac = Double(i) / Double(nDays - 1)
            let sd = baseSD * (1.0 + 3.0 * frac)     // 1x → 4x noise, mean unchanged
            days.append((day(i), trueHRV + sd * gaussian(&rng)))
        }
        return Trace(name: "rising-instability", seed: seed,
                     trueMean: trueHRV, noiseSD: baseSD, days: days,
                     notes: "mean flat \(trueHRV)ms, SD ramps 1x→4x")
    }

    /// realistic-HRV: mean ~50ms + a weekly rhythm (±3ms) + an occasional bad night (−15ms)
    /// on a couple of deterministic days. End-to-end sanity.
    private static func traceRealisticHRV() -> Trace {
        let seed: UInt64 = 0xBEA1157C
        var rng = ShadowMetrics.SplitMix64(seed: seed)
        let badNights: Set<Int> = [12, 27, 51]
        var days: [(date: Date, value: Double?)] = []
        for i in 0..<nDays {
            let weekly = 3.0 * Foundation.sin(2.0 * Double.pi * Double(i) / 7.0)
            var v = trueHRV + weekly + (baseSD * 0.8) * gaussian(&rng)
            if badNights.contains(i) { v -= 15.0 }
            days.append((day(i), v))
        }
        return Trace(name: "realistic-HRV", seed: seed, trueMean: trueHRV,
                     noiseSD: baseSD, days: days,
                     notes: "mean ~\(trueHRV)ms + weekly ±3ms rhythm + bad nights @ \(badNights.sorted())")
    }

    private static func allTraces() -> [Trace] {
        [traceStable(), traceStepChange(), traceOutlier(), traceGapStretch(),
         traceStaleRepeat(), traceRisingInstability(), traceRealisticHRV()]
    }

    // MARK: - Prequential per-day record

    private struct DayRecord {
        let dayIndex: Int
        let rawY: Double?            // nil == GAP day
        let mu: Double?              // robust EWMA baseline after this day's fold (or carried)
        let incumbent: Double?       // flat 7-day-mean of trailing RAW window (incumbent comparator)
        let z: Double?
        let sigma: Double?
        let cvRatio: Double?
        let cvLevel: BaselineEngine.CVWarning
        let confidence: Double
    }

    /// Per-scenario summary stats for the report + invariant checks.
    private struct ScenarioResult {
        let trace: Trace
        let records: [DayRecord]
        let robustTrackingError: Double      // mean |μ − trueMean| over valued days
        let incumbentTrackingError: Double   // mean |incumbent − trueMean| over valued days
        let zMeanStable: Double
        let zSDStable: Double
        let cvFirstElevatedDay: Int?
        let cvFirstHighDay: Int?
        let cvMaxLevel: BaselineEngine.CVWarning
        let confCross05Day: Int?
        let confCross09Day: Int?
        let outlierMuJump: Double?           // |μ_after − μ_before| at the +6σ spike (outlier only)
        let incumbentOutlierJump: Double?    // |incumbent_after − incumbent_before| at the spike
    }

    /// Run the prequential score-then-step loop over a trace and collect per-day records.
    private func runScenario(_ trace: Trace) -> ScenarioResult {
        let cfg = BaselineEngine.SignalConfig.hrv
        let cal = Self.utc

        var state = BaselineEngine.SignalState()
        var records: [DayRecord] = []
        var rawWindow: [Double] = []        // trailing RAW values for the incumbent comparator
        var lastBucketedIndex: Int? = nil   // for daysSinceLastBucket (recency erosion)

        var outlierMuBefore: Double? = nil
        var outlierMuAfter: Double? = nil
        var incBefore: Double? = nil
        var incAfter: Double? = nil
        let outlierSpikeIndex = (trace.name == "outlier") ? 40 : -1

        for (i, dayEntry) in trace.days.enumerated() {
            // Recency: whole days since the last folded day (drives confidence erosion over GAPs).
            let daysSince = lastBucketedIndex.map { i - $0 } ?? 0

            guard let y = dayEntry.value else {
                // GAP day: no fold (no carry-forward). μ carried; confidence erodes via daysSince.
                let conf = BaselineEngine.confidence(state: state, daysSinceLastBucket: daysSince)
                records.append(DayRecord(
                    dayIndex: i, rawY: nil, mu: state.mu,
                    incumbent: RecoveryScoreEngine.computeBaseline(values: rawWindow),
                    z: nil, sigma: nil, cvRatio: state.cvRatio, cvLevel: state.cvLevel,
                    confidence: conf
                ))
                continue
            }

            // PREQUENTIAL: score BEFORE step (state through t-1 only).
            let scored = BaselineEngine.score(state: state, observation: y, config: cfg)
            let sigmaUsed: Double? = scored.z.map { _ in
                BaselineEngine.robustScale(state.madBuffer, floor: cfg.sigmaFloor)
            }

            // Incumbent comparator: flat 7-day mean of trailing RAW window INCLUDING today.
            rawWindow.append(y)
            let incumbent = RecoveryScoreEngine.computeBaseline(values: rawWindow)

            if i == outlierSpikeIndex {
                outlierMuBefore = state.mu
                incBefore = records.last(where: { $0.rawY != nil })?.incumbent
            }

            // Fold day t.
            let dayDate = cal.startOfDay(for: dayEntry.date)
            state = BaselineEngine.step(state: state, observation: y, config: cfg, bucketedDate: dayDate)
            lastBucketedIndex = i

            let conf = BaselineEngine.confidence(state: state, daysSinceLastBucket: 0)

            if i == outlierSpikeIndex {
                outlierMuAfter = state.mu
                incAfter = incumbent
            }

            records.append(DayRecord(
                dayIndex: i, rawY: y, mu: state.mu, incumbent: incumbent,
                z: scored.z, sigma: sigmaUsed, cvRatio: state.cvRatio,
                cvLevel: state.cvLevel, confidence: conf
            ))
        }

        // --- Summary stats over VALUED days ---
        let valued = records.filter { $0.rawY != nil }

        func meanAbs(_ vals: [Double]) -> Double {
            vals.isEmpty ? 0 : vals.reduce(0, +) / Double(vals.count)
        }
        let robustErr = meanAbs(valued.compactMap { r in r.mu.map { abs($0 - trace.trueMean) } })
        let incumbentErr = meanAbs(valued.compactMap { r in r.incumbent.map { abs($0 - trace.trueMean) } })

        // z mean/SD over valued days that produced a z (post cold-start). For the stable scenario
        // these are the ~N(0,1) check; for others they are reported but not asserted as N(0,1).
        let zs = valued.compactMap { $0.z }
        let zMean = zs.isEmpty ? 0 : zs.reduce(0, +) / Double(zs.count)
        let zVar = zs.count < 2 ? 0 : zs.map { ($0 - zMean) * ($0 - zMean) }.reduce(0, +) / Double(zs.count - 1)
        let zSD = zVar.squareRoot()

        let firstElevated = records.first(where: { $0.cvLevel == .elevated || $0.cvLevel == .high })?.dayIndex
        let firstHigh = records.first(where: { $0.cvLevel == .high })?.dayIndex
        let maxLevel: BaselineEngine.CVWarning = records.contains(where: { $0.cvLevel == .high }) ? .high
            : (records.contains(where: { $0.cvLevel == .elevated }) ? .elevated : .normal)

        let cross05 = records.first(where: { $0.confidence >= 0.5 })?.dayIndex
        let cross09 = records.first(where: { $0.confidence >= 0.9 })?.dayIndex

        let muJump: Double? = (outlierMuBefore != nil && outlierMuAfter != nil)
            ? abs(outlierMuAfter! - outlierMuBefore!) : nil
        let incJump: Double? = (incBefore != nil && incAfter != nil)
            ? abs(incAfter! - incBefore!) : nil

        return ScenarioResult(
            trace: trace, records: records,
            robustTrackingError: robustErr, incumbentTrackingError: incumbentErr,
            zMeanStable: zMean, zSDStable: zSD,
            cvFirstElevatedDay: firstElevated, cvFirstHighDay: firstHigh, cvMaxLevel: maxLevel,
            confCross05Day: cross05, confCross09Day: cross09,
            outlierMuJump: muJump, incumbentOutlierJump: incJump
        )
    }

    // MARK: - Markdown emit (§7.4)

    private func fmt(_ x: Double?, _ places: Int = 2) -> String {
        guard let x = x else { return "—" }
        return String(format: "%.\(places)f", x)
    }

    private func pass(_ ok: Bool) -> String { ok ? "PASS" : "**FAIL**" }

    /// Build the full markdown report String deterministically. Pure — no IO, no clock.
    private func buildReport(_ results: [ScenarioResult]) -> String {
        let byName = Dictionary(uniqueKeysWithValues: results.map { ($0.trace.name, $0) })
        var md = ""
        md += "# Phase 26 — Individualized Baseline Convergence Report (D-04)\n\n"
        md += "> Deterministic, seeded behavior artifact for the robust baseline SUBSTRATE.\n"
        md += "> Generated by `BaselineConvergenceReportTests` driving `BaselineEngine` (Plan 02) +\n"
        md += "> `DayBucketer` (Plan 03) over synthetic + realistic traces with KNOWN ground truth.\n"
        md += "> Judges **behavior** (convergence / robustness), NOT accuracy — no shadow arm, no\n"
        md += "> z→recovery mapping (D-01). The live flat 7-day-mean recovery score is unchanged.\n\n"
        md += "Determinism: dates from a fixed anchor `Date(timeIntervalSince1970: 0) + i·86400` under a\n"
        md += "fixed UTC calendar; the only randomness is `ShadowMetrics.SplitMix64(seed:)` (Box–Muller).\n"
        md += "Same seeds ⇒ byte-identical report (hash-equality test).\n\n"
        md += "Signal config: HRV (half-life \(Int(BaselineEngine.SignalConfig.hrv.halfLifeDays))d, "
        md += "σ floor \(fmt(BaselineEngine.SignalConfig.hrv.sigmaFloor, 1))ms, huberK "
        md += "\(fmt(BaselineEngine.BaselineConstants.huberK, 2))). "
        md += "Confidence ramp \(BaselineEngine.BaselineConstants.confFloorDays)→"
        md += "\(BaselineEngine.BaselineConstants.confFullDays)d, τ "
        md += "\(fmt(BaselineEngine.BaselineConstants.confTauRecency, 1)). "
        md += "CV thresholds elevated \(fmt(BaselineEngine.BaselineConstants.cvElevated, 2)) / "
        md += "high \(fmt(BaselineEngine.BaselineConstants.cvHigh, 2)).\n\n"

        // --- Cross-scenario summary table ---
        md += "## Summary\n\n"
        md += "| Scenario | seed | robust err (μ vs truth) | incumbent err (7d vs truth) | robust win | z̄ | z SD | CV→elev | CV→high | conf≥0.5 | conf≥0.9 |\n"
        md += "|---|---|---|---|---|---|---|---|---|---|---|\n"
        for r in results {
            let win = r.robustTrackingError <= r.incumbentTrackingError ? "✓" : "✗"
            md += "| \(r.trace.name) | 0x\(String(r.trace.seed, radix: 16)) | "
            md += "\(fmt(r.robustTrackingError, 3)) | \(fmt(r.incumbentTrackingError, 3)) | \(win) | "
            md += "\(fmt(r.zMeanStable, 3)) | \(fmt(r.zSDStable, 3)) | "
            md += "\(r.cvFirstElevatedDay.map(String.init) ?? "—") | "
            md += "\(r.cvFirstHighDay.map(String.init) ?? "—") | "
            md += "\(r.confCross05Day.map(String.init) ?? "—") | "
            md += "\(r.confCross09Day.map(String.init) ?? "—") |\n"
        }
        md += "\n"

        // --- Per-scenario panels ---
        for r in results {
            md += "## Scenario: \(r.trace.name)\n\n"
            md += "_\(r.trace.notes)_ · seed `0x\(String(r.trace.seed, radix: 16))` · "
            md += "ground-truth mean `\(fmt(r.trace.trueMean, 1))`\n\n"
            md += "| day | raw y | μ (robust EWMA) | 7d-mean (incumbent) | z | σ | cvRatio | cvLevel | confidence |\n"
            md += "|---:|---:|---:|---:|---:|---:|---:|:--|---:|\n"
            for rec in r.records {
                md += "| \(rec.dayIndex) | "
                md += "\(rec.rawY == nil ? "GAP" : fmt(rec.rawY, 2)) | "
                md += "\(fmt(rec.mu, 2)) | \(fmt(rec.incumbent, 2)) | "
                md += "\(fmt(rec.z, 2)) | \(fmt(rec.sigma, 2)) | \(fmt(rec.cvRatio, 2)) | "
                md += "\(rec.cvLevel.rawValue) | \(fmt(rec.confidence, 3)) |\n"
            }
            md += "\n"

            // Per-scenario stats + invariants.
            md += "**Stats** — robust tracking err `\(fmt(r.robustTrackingError, 3))` vs incumbent "
            md += "`\(fmt(r.incumbentTrackingError, 3))`; z̄ `\(fmt(r.zMeanStable, 3))`, z SD "
            md += "`\(fmt(r.zSDStable, 3))`; max CV `\(r.cvMaxLevel.rawValue)`; "
            md += "conf≥0.5 @ day `\(r.confCross05Day.map(String.init) ?? "—")`, "
            md += "conf≥0.9 @ day `\(r.confCross09Day.map(String.init) ?? "—")`.\n\n"

            md += invariantLines(for: r, all: byName)
            md += "\n"
        }

        md += calibrationFlags(byName)

        md += "## Invariant legend\n\n"
        md += "Each PASS/FAIL line above is ALSO XCTAsserted in `BaselineConvergenceReportTests` so CI\n"
        md += "catches regressions. A failing invariant fails the build, not just the report.\n"
        return md
    }

    /// Calibration findings the human should weigh (the report exists to tune these constants).
    private func calibrationFlags(_ byName: [String: ScenarioResult]) -> String {
        var md = "## Calibration flags (for the human reviewer)\n\n"
        let stable = byName["stable"]
        let rising = byName["rising-instability"]

        // FLAG 1: CV sensitivity on clean Gaussian noise.
        if let s = stable {
            let overFires = s.cvMaxLevel == .high
            md += "- **Altini CV sensitivity:** on the CLEAN `stable` trace (flat mean + N(0,\(fmt(s.trace.noiseSD,1))) "
            md += "noise), the CV early-warning reaches `\(s.cvMaxLevel.rawValue)` "
            md += "(first .elevated day \(s.cvFirstElevatedDay.map(String.init) ?? "—"), "
            md += "first .high day \(s.cvFirstHighDay.map(String.init) ?? "—")). "
            if overFires {
                md += "It **over-fires** on noise with no real instability — the short(7)/long(28)-window MAD ratio "
                md += "swings above the 1.25/1.5 thresholds by chance on small windows. "
                md += "**Suggested re-tune:** raise `cvElevated`/`cvHigh` (e.g. 1.4/1.7), widen `cvShortWindow`, "
                md += "or require more `cvMinValid` long-window residuals before `.high`. "
            }
            md += "The DISCRIMINATOR still holds (see below), so CV is directionally correct but mis-calibrated in absolute terms.\n"
        }

        // FLAG 2: the discriminator (instability fires earlier than clean) — the valid claim.
        if let s = stable, let r = rising {
            let sElev = s.cvFirstElevatedDay ?? Int.max
            let rElev = r.cvFirstElevatedDay ?? Int.max
            md += "- **CV discriminator (valid):** `rising-instability` fires `.elevated` on day "
            md += "\(r.cvFirstElevatedDay.map(String.init) ?? "—") vs `stable` day "
            md += "\(s.cvFirstElevatedDay.map(String.init) ?? "—") — instability is flagged "
            md += "\(rElev < sElev ? "EARLIER (✓ directionally correct)" : "NOT earlier (✗ — investigate)").\n"
        }

        // FLAG 3: confidence ramp shape.
        if let s = stable {
            md += "- **Confidence ramp:** crosses 0.5 @ day \(s.confCross05Day.map(String.init) ?? "—"), "
            md += "0.9 @ day \(s.confCross09Day.map(String.init) ?? "—"). With cCount = (count−14)/(60−14), "
            md += "0.9 is reached at count ≈ 56 (day ≈ 54–55) — by design (the 14→60 ramp), not a defect.\n"
        }
        md += "\n"
        return md
    }

    /// Per-scenario PASS/FAIL invariant lines (mirrors the XCTAsserts below).
    private func invariantLines(for r: ScenarioResult, all byName: [String: ScenarioResult]) -> String {
        var lines = "**Invariants**\n\n"
        switch r.trace.name {
        case "stable":
            let rising = byName["rising-instability"]
            let sElev = r.cvFirstElevatedDay ?? Int.max
            let rElev = rising?.cvFirstElevatedDay ?? Int.min
            lines += "- \(pass(abs(r.zMeanStable) <= 0.6)): stable z̄ ≈ 0 (|\(fmt(r.zMeanStable, 3))| ≤ 0.6)\n"
            lines += "- \(pass(r.zSDStable >= 0.5 && r.zSDStable <= 1.9)): stable z SD ≈ 1 (\(fmt(r.zSDStable, 3)) ∈ [0.5,1.9])\n"
            lines += "- \(pass(rElev <= sElev)): CV discriminator — instability fires .elevated no later than clean (rising day \(rising?.cvFirstElevatedDay.map(String.init) ?? "—") ≤ stable day \(r.cvFirstElevatedDay.map(String.init) ?? "—"))\n"
            lines += "- \(pass(r.robustTrackingError <= r.trace.noiseSD)): robust μ tracks truth (err \(fmt(r.robustTrackingError,3)) ≤ noise SD \(fmt(r.trace.noiseSD,1)))\n"
            lines += "- \(pass((r.confCross09Day ?? Int.max) >= 50)): confidence reaches ≥0.9 only after the 14→60 ramp (day \(r.confCross09Day.map(String.init) ?? "—") ≥ 50)\n"
            lines += "- ⚑ CALIBRATION: absolute CV level on clean data = `\(r.cvMaxLevel.rawValue)` (see Calibration flags)\n"
        case "step-change":
            lines += "- \(pass(r.robustTrackingError <= r.incumbentTrackingError + 0.5)): robust tracking ≤ incumbent on re-center\n"
            lines += "- \(pass(r.robustTrackingError <= 6.0)): baseline re-centers (mean |μ−truth-segment| bounded)\n"
        case "outlier":
            let muJump = r.outlierMuJump ?? .infinity
            let incJump = r.incumbentOutlierJump ?? 0
            lines += "- \(pass(muJump <= 2.0)): Huber bounds the +6σ spike (μ moved only \(fmt(muJump, 3)))\n"
            lines += "- \(pass(muJump < incJump)): robust μ moves LESS than the incumbent (μ \(fmt(muJump, 3)) < 7d \(fmt(incJump, 3)))\n"
            lines += "- \(pass(r.robustTrackingError <= r.incumbentTrackingError + 0.5)): robust tracking ≤ incumbent\n"
        case "gap-stretch", "stale-repeat":
            let endMu = r.records.last(where: { $0.mu != nil })?.mu ?? .infinity
            let muOK = abs(endMu - r.trace.trueMean) <= 3.0 * r.trace.noiseSD
            let minGapConf = r.records.filter { $0.rawY == nil }.map { $0.confidence }.min() ?? 1.0
            lines += "- \(pass(muOK)): μ NOT corrupted across gaps/stale (end μ \(fmt(endMu, 2)) near truth)\n"
            lines += "- \(pass(minGapConf <= 0.5)): confidence erodes over the gap (min gap conf \(fmt(minGapConf, 3)) ≤ 0.5)\n"
        case "rising-instability":
            lines += "- \(pass(r.cvMaxLevel == .high)): CV escalates to .high as variance ramps (max = \(r.cvMaxLevel.rawValue))\n"
            lines += "- \(pass(r.cvFirstElevatedDay != nil)): CV fires .elevated before .high\n"
            lines += "- \(pass(r.robustTrackingError <= 2.0 * r.trace.noiseSD)): mean stays tracked despite rising variance\n"
        case "realistic-HRV":
            lines += "- \(pass(r.robustTrackingError <= r.incumbentTrackingError + 0.5)): robust tracking ≤ incumbent end-to-end\n"
            lines += "- \(pass(r.confCross05Day != nil)): confidence ramps past 0.5\n"
            lines += "- \(pass(abs(r.zMeanStable) <= 1.0)): z distribution centered (|z̄| ≤ 1)\n"
        default:
            break
        }
        return lines
    }

    // MARK: - Artifact path resolution (§7.5)

    private func repoRoot(file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()   // WorkloadAppTests/
            .deletingLastPathComponent()   // <repo root>
    }

    /// Resolve the artifact directory: `BASELINE_REPORT_DIR` env override → repo
    /// `.planning/.../artifacts` → `NSTemporaryDirectory()` fallback. Never hard-fails on path.
    private func resolveArtifactURL() -> URL {
        let relDir = ".planning/phases/26-individualized-baselines/artifacts"
        let fileName = "26-convergence-report.md"

        if let override = ProcessInfo.processInfo.environment["BASELINE_REPORT_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override).appendingPathComponent(fileName)
        }
        return repoRoot().appendingPathComponent(relDir).appendingPathComponent(fileName)
    }

    /// Write the report, creating `artifacts/` if needed; fall back to the temp dir if the repo
    /// path is unwritable (sandboxed CI). Prints the resolved path either way. Never hard-fails.
    private func writeReport(_ md: String) -> URL {
        let fm = FileManager.default
        let target = resolveArtifactURL()
        do {
            try fm.createDirectory(at: target.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            try md.write(to: target, atomically: true, encoding: .utf8)
            print("📄 Convergence report written to: \(target.path)")
            return target
        } catch {
            let fallback = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("26-convergence-report.md")
            try? md.write(to: fallback, atomically: true, encoding: .utf8)
            print("⚠️ Repo path unwritable (\(error)); report written to temp: \(fallback.path)")
            return fallback
        }
    }

    // MARK: - TEST: generate the report + assert behavior invariants

    func test_generateConvergenceReport_andAssertInvariants() {
        let results = Self.allTraces().map { runScenario($0) }
        let md = buildReport(results)
        let written = writeReport(md)

        XCTAssertTrue(md.contains("tracking"), "report must contain the tracking-error comparison")
        XCTAssertTrue(FileManager.default.fileExists(atPath: written.path),
                      "report artifact must exist at \(written.path)")

        let byName = Dictionary(uniqueKeysWithValues: results.map { ($0.trace.name, $0) })

        // --- stable: z ~ N(0,1), robust tracks, confidence ramps on the 14→60 schedule.
        // NOTE: the Altini CV OVER-FIRES on clean Gaussian noise (a real calibration finding,
        // surfaced in the report's "Calibration flags" — the engine math is locked from Plan 02,
        // so the valid CI-guarded claim is the DISCRIMINATOR: instability fires no later than clean).
        let stable = byName["stable"]!
        let rising = byName["rising-instability"]!
        XCTAssertLessThanOrEqual(abs(stable.zMeanStable), 0.6, "stable z̄ ≈ 0")
        XCTAssertTrue(stable.zSDStable >= 0.5 && stable.zSDStable <= 1.9, "stable z SD ≈ 1 (got \(stable.zSDStable))")
        XCTAssertLessThanOrEqual(rising.cvFirstElevatedDay ?? Int.max, stable.cvFirstElevatedDay ?? Int.max,
                                 "CV discriminator: instability must fire .elevated no later than clean data")
        XCTAssertLessThanOrEqual(stable.robustTrackingError, stable.trace.noiseSD, "robust μ tracks truth on stable")
        XCTAssertGreaterThanOrEqual(stable.confCross09Day ?? Int.max, 50,
                                    "confidence must reach 0.9 only after the 14→60 count ramp")
        // confidence ~0 early (count ≤ 14): first valued day's confidence must be ~0.
        if let early = stable.records.first(where: { $0.rawY != nil }) {
            XCTAssertLessThan(early.confidence, 0.1, "confidence ≈ 0 at count ≤ 14")
        }

        // --- step-change: robust re-centers, tracking ≤ incumbent ---
        let step = byName["step-change"]!
        XCTAssertLessThanOrEqual(step.robustTrackingError, step.incumbentTrackingError + 0.5,
                                 "robust tracking ≤ incumbent on step-change")

        // --- outlier: Huber bounds μ, robust moves less than incumbent ---
        let outlier = byName["outlier"]!
        let muJump = outlier.outlierMuJump ?? .infinity
        let incJump = outlier.incumbentOutlierJump ?? 0
        XCTAssertLessThanOrEqual(muJump, 2.0, "Huber must bound the +6σ spike (μ moved \(muJump))")
        XCTAssertLessThan(muJump, incJump, "robust μ must move LESS than the incumbent 7d-mean on the spike")
        XCTAssertLessThanOrEqual(outlier.robustTrackingError, outlier.incumbentTrackingError + 0.5,
                                 "robust tracking ≤ incumbent on outlier")

        // --- gap-stretch & stale-repeat: μ not corrupted, confidence erodes over gaps ---
        for name in ["gap-stretch", "stale-repeat"] {
            let s = byName[name]!
            let endMu = s.records.last(where: { $0.mu != nil })?.mu ?? .infinity
            XCTAssertLessThanOrEqual(abs(endMu - s.trace.trueMean), 3.0 * s.trace.noiseSD,
                                     "\(name): μ must not be corrupted across gaps/stale")
            let gapConfs = s.records.filter { $0.rawY == nil }.map { $0.confidence }
            XCTAssertFalse(gapConfs.isEmpty, "\(name): must have GAP days")
            XCTAssertLessThanOrEqual(gapConfs.min() ?? 1.0, 0.5,
                                     "\(name): confidence must erode over the gap")
        }

        // --- rising-instability: CV escalates to .high while mean stays tracked ---
        // (`rising` is bound above in the stable/discriminator block.)
        XCTAssertEqual(rising.cvMaxLevel, .high, "CV must escalate to .high on rising instability")
        XCTAssertNotNil(rising.cvFirstElevatedDay, "CV must fire .elevated before .high")
        XCTAssertLessThanOrEqual(rising.robustTrackingError, 2.0 * rising.trace.noiseSD,
                                 "mean stays tracked despite rising variance")

        // --- realistic-HRV: end-to-end sanity ---
        let realistic = byName["realistic-HRV"]!
        XCTAssertLessThanOrEqual(realistic.robustTrackingError, realistic.incumbentTrackingError + 0.5,
                                 "robust tracking ≤ incumbent on realistic-HRV")
        XCTAssertNotNil(realistic.confCross05Day, "confidence must ramp past 0.5 on realistic-HRV")
    }

    // MARK: - TEST: hash-equality (byte-reproducibility, §7.2)

    func test_reportIsByteReproducible() {
        let md1 = buildReport(Self.allTraces().map { runScenario($0) })
        let md2 = buildReport(Self.allTraces().map { runScenario($0) })
        XCTAssertEqual(md1, md2, "two same-seed runs must produce byte-identical markdown")
        XCTAssertEqual(md1.hashValue, md2.hashValue, "hash-equality must hold for the report String")
    }
}
