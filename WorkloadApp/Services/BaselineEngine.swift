import Foundation

/// Pure, **stateless**, deterministic robust-baseline estimator (Phase 26, RESEARCH §1–§4).
///
/// Implements, per recovery signal (HRV / RHR / sleep), the full robust per-signal online
/// estimator under strict **prequential (no-leak)** discipline:
/// - EWMA mean with per-signal half-life → λ  (§1.1)
/// - Welford M2 (numerically stable variance) + rolling MAD×1.4826 dispersion  (§1.2)
/// - Huber-clipped bounded update (k ≈ 1.5)  (§1.3)
/// - prequential z-score on the RAW innovation with a σ floor + cold-start nil  (§2)
/// - Altini dispersion-ratio CV early-warning on INNOVATIONS, 3-level hysteresis  (§3)
/// - composite 0–1 confidence with NO population prior — honest-low cold-start  (§4)
///
/// ## Detect-honestly / update-robustly (§1.3, the crux)
/// The z-score (`score`) and CV warning (`cvUpdate`) score the **raw** innovation
/// `r_t = y_t − μ_{t-1}` — we want to *detect* deviation, not hide it. Only the μ-fold in
/// `step` uses the **Huber-clipped** observation `ŷ_t = μ_{t-1} + clamp(r_t, ±k·σ)` — we don't
/// want the baseline to chase a lone aberrant night.
///
/// ## Prequential no-leak is STRUCTURAL (§2, fold-before-score impossible)
/// `score(state:observation:…)` reads σ/μ from `state` through **t-1 only** and is a *separate*
/// method from `step(state:observation:…)` which folds day t. Because scoring and folding live in
/// distinct methods, the "fold-before-score" leak cannot occur by construction; the divergence is
/// also proven by `BaselineEngineTests.test_noLeakOrdering`. This mirrors the live feature-cutoff
/// discipline at `RecoveryPipeline.swift:196-202` and the Phase-24 predictionDate/targetDate contract.
///
/// ## Engine is DATELESS — the day-advance / idempotency guard is the CALLER's contract (PLAN-CHECK W-1)
/// This struct contains **zero** `Date(` / `.now` / `Calendar.current` / system RNG (grep-gated). It
/// does NOT self-guard against double-folding the same day. The single concrete owner of the
/// `lastBucketedDate` monotonic cutoff is the **caller / day-bucketer** (Plan 26-03's `DayBucketer`):
///
///   > **CONTRACT:** `step` MUST be called **exactly once per advanced bucketed day** — i.e. only when
///   > `startOfDay(t) > state.lastBucketedDate` (strictly after, §2.4). The caller advances
///   > `lastBucketedDate` to `startOfDay(t)` on each fold and re-presenting an already-folded day is a
///   > caller-side no-op. The engine trusts this and performs no day arithmetic.
///
/// `step` carries `lastBucketedDate` through unchanged when the caller passes `bucketedDate: nil`,
/// and stamps it when supplied — but it NEVER reads the clock to decide.
///
/// ## TIER FENCE (HIGH-risk — RESEARCH tier map / Pitfall 5)
/// This engine references **no** `RecoveryScoreEngine` / `RecoveryPipeline` / `SyncService` symbol
/// (grep-verified). It runs PARALLEL to and gated OFF from the live recovery score — the flat
/// 7-day mean (`RecoveryScoreEngine.computeBaseline`) stays the LIVE baseline source. This plan
/// touches none of that path.
///
/// All tunables are named constants in `BaselineConstants` / `SignalConfig` — no magic numbers (§8.3).
struct BaselineEngine {

    // MARK: - CV warning level (String round-trips to BaselineState.cvLevelRaw)

    /// 3-level dispersion-ratio early-warning flag (§3.3). A *context* output for Phase 28 —
    /// never a prediction this phase.
    enum CVWarning: String {
        case normal
        case elevated
        case high
    }

    // MARK: - SignalState value mirror (engine operates on THIS, not the @Model — §6.3)

    /// Plain value mirror of one signal's sub-state in `BaselineState`. The engine reads a mirror
    /// in and returns a NEW mirror out (pure — never mutates its input).
    struct SignalState {
        /// EWMA baseline μ — `nil` ⇒ no fold yet (distinct from "μ == 0").
        var mu: Double?
        /// SEPARATE simple running mean for Welford (NOT the EWMA μ — different estimator, §1.2).
        var welfordMean: Double
        /// Welford sum-of-squared-deviations.
        var m2: Double
        /// Count of valid (non-gap) folds.
        var count: Int
        /// Last W raw innovations `r_i = y_i − μ_{i-1}` (pre-update, NOT clipped).
        var madBuffer: [Double]
        /// Monotonic last-bucketed-day cutoff (caller-owned, §2.4 — see W-1 contract above).
        var lastBucketedDate: Date?
        /// Last §3 dispersion ratio (hysteresis carry).
        var cvRatio: Double?
        /// Hysteresis level state.
        var cvLevel: CVWarning
        /// Last §4 confidence.
        var confidence: Double

        init(
            mu: Double? = nil,
            welfordMean: Double = 0.0,
            m2: Double = 0.0,
            count: Int = 0,
            madBuffer: [Double] = [],
            lastBucketedDate: Date? = nil,
            cvRatio: Double? = nil,
            cvLevel: CVWarning = .normal,
            confidence: Double = 0.0
        ) {
            self.mu = mu
            self.welfordMean = welfordMean
            self.m2 = m2
            self.count = count
            self.madBuffer = madBuffer
            self.lastBucketedDate = lastBucketedDate
            self.cvRatio = cvRatio
            self.cvLevel = cvLevel
            self.confidence = confidence
        }
    }

    // MARK: - Named constants (RESEARCH §8.3 — the SINGLE home for every tunable)

    /// All §8.3 tunables. No magic number appears anywhere else in this engine.
    enum BaselineConstants {
        // Half-lives (days) → λ via `lambda(halfLifeDays:)`.
        static let hrvHalfLifeDays: Double = 7.0
        static let rhrHalfLifeDays: Double = 10.0
        static let sleepHalfLifeDays: Double = 7.0

        // Dispersion / robust update.
        /// 1/Φ⁻¹(0.75) ≈ 1.4826 — MAD → σ consistency constant for Gaussian data.
        static let madScaleK: Double = 1.4826
        /// W — rolling innovation buffer length for the MAD scale.
        static let madBufferLength: Int = 21
        /// W_min — below this buffer size, MAD is not yet meaningful (cold-start nil / Welford fill).
        static let madMinValid: Int = 5
        /// Huber bounded-influence tuning constant (≤ k·σ influence per step).
        static let huberK: Double = 1.5

        // Per-signal σ floors (signal's own units) — prevent divide-by-tiny (§2.3).
        static let hrvSigmaFloor: Double = 3.0    // ms
        static let rhrSigmaFloor: Double = 1.5    // bpm
        static let sleepSigmaFloor: Double = 15.0 // minutes

        // Altini CV early-warning (§3).
        static let cvShortWindow: Int = 7
        static let cvLongWindow: Int = 28
        static let cvElevated: Double = 1.25
        static let cvHigh: Double = 1.5
        static let cvClear: Double = 1.10
        /// Min valid residuals in the long window required before HIGH may fire.
        static let cvMinValid: Int = 14
        /// Below this many residuals the CV warning is suppressed to .normal (low-confidence).
        static let cvShortMin: Int = 7

        // Composite confidence (§4).
        static let confFloorDays: Int = 14
        static let confFullDays: Int = 60
        static let confTauRecency: Double = 2.0
        static let confDispSpan: Double = 1.0
        static let staleHardCutDays: Int = 7
    }

    /// Per-signal configuration bundling the signal-specific tunables (half-life, σ floor,
    /// sign convention). Shared constants stay in `BaselineConstants`.
    struct SignalConfig {
        let halfLifeDays: Double
        let sigmaFloor: Double
        /// `true` for HRV/sleep (higher = better), `false` for RHR (lower = better) so +z = better.
        let higherIsBetter: Bool

        static let hrv = SignalConfig(
            halfLifeDays: BaselineConstants.hrvHalfLifeDays,
            sigmaFloor: BaselineConstants.hrvSigmaFloor,
            higherIsBetter: true
        )
        static let rhr = SignalConfig(
            halfLifeDays: BaselineConstants.rhrHalfLifeDays,
            sigmaFloor: BaselineConstants.rhrSigmaFloor,
            higherIsBetter: false
        )
        static let sleep = SignalConfig(
            halfLifeDays: BaselineConstants.sleepHalfLifeDays,
            sigmaFloor: BaselineConstants.sleepSigmaFloor,
            higherIsBetter: true
        )
    }

    // MARK: - λ from half-life (§1.1)

    /// `λ = 1 − 2^(−1/H)`. Returns 0 for an infinite half-life (no decay / no fold weight).
    static func lambda(halfLifeDays H: Double) -> Double {
        guard H.isFinite, H > 0 else { return 0.0 }
        return 1.0 - pow(2.0, -1.0 / H)
    }

    // MARK: - median helper

    /// Median of a value array (sort + mid / avg-of-two). Returns 0 for an empty array
    /// (callers gate on buffer size before this matters).
    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        let sorted = values.sorted()
        let n = sorted.count
        if n % 2 == 1 {
            return sorted[n / 2]
        } else {
            return (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
        }
    }

    // MARK: - Robust scale (§1.2)

    /// Active robust scale `σ = max(1.4826·MAD, floor)` over the innovation buffer.
    /// While the buffer is below `madMinValid`, falls back to the Welford SD (cold-start fill),
    /// still floored. Returns the floor when neither is available.
    static func robustScale(_ innovations: [Double], floor: Double, welfordSD: Double? = nil) -> Double {
        if innovations.count >= BaselineConstants.madMinValid {
            let m = median(innovations)
            let absDev = innovations.map { abs($0 - m) }
            let mad = median(absDev)
            return max(BaselineConstants.madScaleK * mad, floor)
        }
        // Cold-start fill: use Welford SD if we have it, else just the floor.
        if let sd = welfordSD, sd.isFinite, sd > 0 {
            return max(sd, floor)
        }
        return floor
    }

    /// Welford sample SD from carried accumulators, or nil while count < 2.
    private static func welfordSD(_ state: SignalState) -> Double? {
        guard state.count >= 2 else { return nil }
        let variance = state.m2 / Double(state.count - 1)
        guard variance.isFinite, variance >= 0 else { return nil }
        return sqrt(variance)
    }

    // MARK: - Prequential z-score (§2) — RAW innovation, state through t-1 ONLY

    /// Score day `t`'s observation against the baseline **as of t-1**. NO fold happens here —
    /// `step` does the fold. `z = innovation / max(σ_mad, floor)`, negated when `!higherIsBetter`
    /// so +z always means "better". Returns `z == nil` (never inf/NaN) while `count < 2` OR
    /// `madBuffer.count < W_min` (cold-start undefined — §2.3).
    ///
    /// - Returns: `(z, innovation)` where `innovation = y − μ_{t-1}` (sign as-measured, raw).
    static func score(
        state: SignalState,
        observation y: Double,
        config: SignalConfig
    ) -> (z: Double?, innovation: Double) {
        guard let mu = state.mu else {
            // No baseline yet ⇒ innovation undefined; report 0 innovation, nil z.
            return (nil, 0.0)
        }
        let innovation = y - mu  // raw r_t (this is what z AND cvUpdate score on)

        // Cold-start gate: never fabricate a z.
        guard state.count >= 2, state.madBuffer.count >= BaselineConstants.madMinValid else {
            return (nil, innovation)
        }

        let sigma = robustScale(state.madBuffer, floor: config.sigmaFloor, welfordSD: welfordSD(state))
        // floor guarantees sigma > 0, so this is finite by construction.
        let zRaw = innovation / sigma
        let z = config.higherIsBetter ? zRaw : -zRaw
        return (z, innovation)
    }

    // MARK: - Altini CV early-warning (§3) — runs on RAW innovations, 3-level hysteresis

    /// Update the dispersion-ratio early-warning from the current innovation buffer + today's raw
    /// innovation. Compares a short-window robust dispersion to a long-window one (volatility of
    /// volatility). Hysteresis: fire HIGH ≥1.5 (and ≥`cvMinValid` long-window residuals), ELEVATED
    /// ≥1.25, clear to NORMAL ≤1.10; suppressed to .normal while short-window residuals < `cvShortMin`.
    ///
    /// - Parameter previousLevel: the carried hysteresis level (for the clear-gap logic).
    /// - Returns: `(ratio, level)` — `ratio` nil when suppressed (insufficient data).
    static func cvUpdate(
        innovationBuffer: [Double],
        todayInnovation: Double,
        floor: Double,
        previousLevel: CVWarning
    ) -> (ratio: Double?, level: CVWarning) {
        // The residual stream including today (today's raw innovation is the newest residual).
        var residuals = innovationBuffer
        residuals.append(todayInnovation)

        let shortCount = min(residuals.count, BaselineConstants.cvShortWindow)
        // Suppressed: not enough short-window residuals → honest .normal, no ratio.
        guard shortCount >= BaselineConstants.cvShortMin else {
            return (nil, .normal)
        }

        let shortWindow = Array(residuals.suffix(BaselineConstants.cvShortWindow))
        let longWindow = Array(residuals.suffix(BaselineConstants.cvLongWindow))

        let recentScale = BaselineConstants.madScaleK * median(shortWindow.map { abs($0) })
        let baselineScale = BaselineConstants.madScaleK * median(longWindow.map { abs($0) })
        let ratio = recentScale / max(baselineScale, floor)

        let longValid = longWindow.count
        let level = nextCVLevel(ratio: ratio, longValid: longValid, previous: previousLevel)
        return (ratio, level)
    }

    /// Hysteresis state machine for the CV level (§3.3). The clear gap (≤`cvClear`) prevents flapping.
    private static func nextCVLevel(ratio: Double, longValid: Int, previous: CVWarning) -> CVWarning {
        // HIGH requires both a high ratio AND enough long-window evidence.
        if ratio >= BaselineConstants.cvHigh && longValid >= BaselineConstants.cvMinValid {
            return .high
        }
        if ratio >= BaselineConstants.cvElevated {
            return .elevated
        }
        if ratio <= BaselineConstants.cvClear {
            return .normal
        }
        // In the hysteresis dead-band (cvClear < ratio < cvElevated): hold the previous level
        // rather than flapping. A previously-high level steps down to elevated (can't stay high
        // without ≥1.5), a previously-elevated/normal holds.
        switch previous {
        case .high: return .elevated
        case .elevated: return .elevated
        case .normal: return .normal
        }
    }

    // MARK: - Composite confidence (§4) — 0–1, NO population prior

    /// `confidence = c_count · c_recency · c_disp`, each in [0,1] (§4.2). Any one being low pulls
    /// the product down (honest). No sex/age physiology prior — cold-start is genuinely low.
    ///
    /// - Parameter daysSinceLastBucket: `startOfDay(today) − lastBucketedDate` in whole days,
    ///   computed by the CALLER (the engine is dateless). Beyond `staleHardCutDays` ⇒ ~0.
    static func confidence(state: SignalState, daysSinceLastBucket: Int) -> Double {
        let floorDays = Double(BaselineConstants.confFloorDays)
        let fullDays = Double(BaselineConstants.confFullDays)

        let cCount = clamp01((Double(state.count) - floorDays) / (fullDays - floorDays))

        let cRecency: Double
        if daysSinceLastBucket >= BaselineConstants.staleHardCutDays {
            cRecency = 0.0
        } else {
            cRecency = exp(-Double(max(0, daysSinceLastBucket)) / BaselineConstants.confTauRecency)
        }

        let ratio = state.cvRatio ?? 1.0
        let cDisp = clamp01(1.0 - (ratio - 1.0) / BaselineConstants.confDispSpan)

        return cCount * cRecency * cDisp
    }

    private static func clamp01(_ x: Double) -> Double {
        min(1.0, max(0.0, x))
    }

    // MARK: - Fold day t (§1.3 → §1.1 → §1.2) — PURE: returns a NEW SignalState

    /// Advance state by folding day `t`'s observation. Order (mirrors §2.1 steps 4):
    /// Huber-clip the RAW innovation → EWMA-fold the CLIPPED ŷ into μ → advance Welford
    /// mean/M2/count on ŷ → push the RAW r_t into the W-length madBuffer (dropping oldest) →
    /// update CV (hysteresis) from the raw innovation → carry confidence inputs.
    ///
    /// **Caller contract (W-1):** call this **exactly once per advanced bucketed day**; the engine
    /// performs NO day arithmetic and does NOT self-guard against re-presenting a day. Pass
    /// `bucketedDate` (already `startOfDay`) so it is stamped into the returned state's
    /// `lastBucketedDate`; the caller is responsible for only calling when `bucketedDate >
    /// state.lastBucketedDate`.
    ///
    /// - Returns: a NEW `SignalState` (input is never mutated).
    static func step(
        state: SignalState,
        observation y: Double,
        config: SignalConfig,
        bucketedDate: Date? = nil
    ) -> SignalState {
        var next = state  // value copy — input untouched

        let lambdaS = lambda(halfLifeDays: config.halfLifeDays)

        // First fold ever: seed μ with the observation, no clipping (no μ_{t-1} to clip against).
        guard let muPrev = state.mu else {
            next.mu = y
            // Welford seed on the raw observation.
            next.count = 1
            next.welfordMean = y
            next.m2 = 0.0
            next.madBuffer = []  // no innovation defined for the first reading
            next.cvRatio = state.cvRatio
            next.cvLevel = state.cvLevel
            if let d = bucketedDate { next.lastBucketedDate = d }
            return next
        }

        // §1.3 Huber clip of the RAW innovation.
        let rawInnovation = y - muPrev
        let sigma = robustScale(state.madBuffer, floor: config.sigmaFloor, welfordSD: welfordSD(state))
        let bound = BaselineConstants.huberK * sigma
        let clippedInnovation = min(max(rawInnovation, -bound), bound)
        let yHat = muPrev + clippedInnovation  // clipped observation fed to the fold

        // §1.1 EWMA fold of the CLIPPED observation.
        next.mu = (1.0 - lambdaS) * muPrev + lambdaS * yHat

        // §1.2 Welford on the clipped observation (separate running mean — NOT the EWMA μ).
        next.count = state.count + 1
        let delta = yHat - state.welfordMean
        next.welfordMean = state.welfordMean + delta / Double(next.count)
        let delta2 = yHat - next.welfordMean
        next.m2 = state.m2 + delta * delta2

        // §1.2 push the RAW innovation into the W-length ring buffer (drop oldest).
        var buffer = state.madBuffer
        buffer.append(rawInnovation)
        if buffer.count > BaselineConstants.madBufferLength {
            buffer.removeFirst(buffer.count - BaselineConstants.madBufferLength)
        }
        next.madBuffer = buffer

        // §3 CV update from the RAW innovation (state-through-t-1 buffer + today's raw r_t).
        let cv = cvUpdate(
            innovationBuffer: state.madBuffer,
            todayInnovation: rawInnovation,
            floor: config.sigmaFloor,
            previousLevel: state.cvLevel
        )
        next.cvRatio = cv.ratio ?? state.cvRatio
        next.cvLevel = cv.level

        if let d = bucketedDate { next.lastBucketedDate = d }
        return next
    }
}
