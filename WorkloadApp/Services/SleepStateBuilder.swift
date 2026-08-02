import Foundation

/// Sleep score v2 — the stateless state folder (Phase S2).
///
/// `SleepStateBuilder` is to the sleep-v2 sub-state of `BaselineState` what `BaselineEngine`
/// is to the HRV/RHR/sleep robust baselines: **pure static math over a plain value mirror.**
/// It is a separate struct rather than an extension of `BaselineEngine` because the two have
/// different contracts — `BaselineEngine` is the generic per-signal robust estimator
/// (EWMA + Welford + MAD + Huber, grep-gated dateless), while this folder carries the
/// sleep-v2 domain state machine (stage EWMAs keyed to a source, midpoint statistics, debt,
/// §4 need learning, the profile latch). Mixing them would blur both contracts and their
/// test surfaces.
///
/// Contract, mirroring `BaselineEngine` / `DayBucketer`:
/// - pure struct, static methods only, no stored state; the input `State` is never mutated;
/// - **no clock access** — no `Date.now`, no `Calendar.current`; every `Calendar` is
///   injected by the caller (the `DayBucketer` precedent for date arithmetic in pure code);
/// - no HealthKit, no SwiftData — the pipeline maps `BaselineState` ⇄ `State` and owns
///   persistence;
/// - **prequential (no-leak)**: `makeInput` reads the state **through t−1 only**; `fold`
///   advances it. Score-then-fold, exactly like `BaselineEngine.score`/`step`.
/// - **once per night**: `fold` honors the monotonic `lastFoldedDate` cutoff (the W-1
///   idempotency contract) — re-presenting the same or an older wake day is a no-op.
///
/// Spec: `research-sleep-score.md` §3 (HealthKit reality), §4 (personalized need),
/// §9.2 (state vector), §9.3/§9.4 (profiles + latch); invented constants and S2 rulings
/// carry H-IDs in the §9.5 registry (rows H-19…H-33, added by this phase).
struct SleepStateBuilder {

    // MARK: - Value mirror (the builder operates on THIS, never the @Model)

    /// Plain value mirror of `BaselineState`'s `sleepV2*` fields, one-to-one. The pipeline
    /// reads a mirror in, the builder returns a NEW mirror, the pipeline writes it back.
    struct State {
        /// EWMA of nightly deep minutes, same-source only (H-04). nil = no fold yet.
        var deepMu: Double?
        /// Folds into `deepMu` since the last source reset.
        var deepCount: Int
        /// EWMA of nightly REM minutes, same-source only (H-04).
        var remMu: Double?
        var remCount: Int
        /// Bundle id of the dominant sleep source the stage baselines are keyed to.
        var dominantSourceID: String?
        /// Nights since the dominant source changed; nil = never changed.
        var nightsSinceSourceChange: Int?
        /// Trailing ≤14 midpoints, minutes relative to wake-day midnight.
        var midpointBuffer: [Double]
        /// Trailing ≤14 irregularity flags (1.0 = that night's SD14 > 75 min).
        var irregularFlags14: [Double]
        /// Nights since the last rhythm break; nil = none observed.
        var nightsSinceRhythmBreak: Int?
        /// Consecutive nights with SD14 below the chronic exit threshold.
        var nightsBelowChronicExitSD: Int
        /// Trailing ≤7 nightly deficits `max(0, need − TST)` in minutes.
        var deficitBuffer7: [Double]
        /// Trailing ≤90 nightly TSTs — the need estimator's input (H-19).
        var tstBuffer: [Double]
        /// Learned need in minutes; nil = gate closed (cold start 7.5 h applies).
        var needBaseMinutes: Double?
        /// Last weekly need recompute.
        var needUpdatedAt: Date?
        /// Need learning frozen by a latched CHRONIC_IRREGULAR (§7 Q9) — and ONLY by
        /// that. §4's *source-change* "freeze" is deliberately NOT tracked here: it is
        /// implemented as the cleared TST buffer re-closing the 28-night gate (H-28), so
        /// during a re-gate window this flag stays false while updates are still blocked.
        /// Read it as `chronicFreeze`; the persisted `sleepV2NeedFrozen` field keeps its
        /// name for migration safety (SPEC-8 ruling: document, not rename).
        var needFrozen: Bool
        /// Total nights folded (tier gate + confidence).
        var nightsOfHistory: Int
        /// Last night's LATCHED profiles, raw strings (§9.4 rule-4 hysteresis carry).
        var previousProfilesRaw: [String]
        /// End of the previous main-sleep session (priorWakeHours input).
        var lastSleepEndDate: Date?
        /// Monotonic once-per-day fold cutoff (W-1 idempotency).
        var lastFoldedDate: Date?
        /// Trailing ≤28 valid prior-wake spans in hours — the §9.2 `priorWakeZ` input (H-34).
        var priorWakeBuffer: [Double]

        init(
            deepMu: Double? = nil,
            deepCount: Int = 0,
            remMu: Double? = nil,
            remCount: Int = 0,
            dominantSourceID: String? = nil,
            nightsSinceSourceChange: Int? = nil,
            midpointBuffer: [Double] = [],
            irregularFlags14: [Double] = [],
            nightsSinceRhythmBreak: Int? = nil,
            nightsBelowChronicExitSD: Int = 0,
            deficitBuffer7: [Double] = [],
            tstBuffer: [Double] = [],
            needBaseMinutes: Double? = nil,
            needUpdatedAt: Date? = nil,
            needFrozen: Bool = false,
            nightsOfHistory: Int = 0,
            previousProfilesRaw: [String] = [],
            lastSleepEndDate: Date? = nil,
            lastFoldedDate: Date? = nil,
            priorWakeBuffer: [Double] = []
        ) {
            self.deepMu = deepMu
            self.deepCount = deepCount
            self.remMu = remMu
            self.remCount = remCount
            self.dominantSourceID = dominantSourceID
            self.nightsSinceSourceChange = nightsSinceSourceChange
            self.midpointBuffer = midpointBuffer
            self.irregularFlags14 = irregularFlags14
            self.nightsSinceRhythmBreak = nightsSinceRhythmBreak
            self.nightsBelowChronicExitSD = nightsBelowChronicExitSD
            self.deficitBuffer7 = deficitBuffer7
            self.tstBuffer = tstBuffer
            self.needBaseMinutes = needBaseMinutes
            self.needUpdatedAt = needUpdatedAt
            self.needFrozen = needFrozen
            self.nightsOfHistory = nightsOfHistory
            self.previousProfilesRaw = previousProfilesRaw
            self.lastSleepEndDate = lastSleepEndDate
            self.lastFoldedDate = lastFoldedDate
            self.priorWakeBuffer = priorWakeBuffer
        }
    }

    // MARK: - Nap candidate (Phase S3, H-35)

    /// One non-main clustered sleep session from `fetchLastNightSleepDetail`'s window — a
    /// potential nap. Defined here (the consumer of the contract) so the selection rule
    /// (`napMinutes`) stays pure and testable without HealthKit types.
    struct NapCandidate {
        /// First asleep sample start of the candidate session.
        let start: Date
        /// Last asleep sample end of the candidate session.
        let end: Date
        /// Unioned asleep minutes of the candidate session.
        let asleepMinutes: Double

        init(start: Date, end: Date, asleepMinutes: Double) {
            self.start = start
            self.end = end
            self.asleepMinutes = asleepMinutes
        }
    }

    // MARK: - One night's raw observation

    /// One night as the pipeline hands it over (already reduced from HealthKit by
    /// `HealthKitService.fetchLastNightSleepDetail`). Raw stage data stays device-local —
    /// it flows only into the carrier and the engine input, never toward sync.
    struct Night {
        /// `startOfDay` of the WAKE day — the fold's bucket key (W-1 idempotency).
        let bucketedDate: Date
        /// Total sleep time in minutes (> 0; a no-sleep day is not folded).
        let tstMinutes: Double
        /// Deep minutes; nil when the dominant source did not stage.
        let deepMinutes: Double?
        /// REM minutes; nil when the dominant source did not stage.
        let remMinutes: Double?
        /// Awake-after-onset minutes (audit only — no scoring authority, council ruling).
        let awakeMinutes: Double?
        /// In-bed span minutes — continuity's only denominator (H-24 for its derivation).
        let inBedMinutes: Double?
        /// First asleep sample start (midpoint + priorWake input).
        let sessionStart: Date
        /// Last asleep sample end (midpoint input; becomes `lastSleepEndDate`).
        let sessionEnd: Date
        /// Dominant source bundle id; nil when unknown.
        let sourceID: String?

        init(
            bucketedDate: Date,
            tstMinutes: Double,
            deepMinutes: Double? = nil,
            remMinutes: Double? = nil,
            awakeMinutes: Double? = nil,
            inBedMinutes: Double? = nil,
            sessionStart: Date,
            sessionEnd: Date,
            sourceID: String? = nil
        ) {
            self.bucketedDate = bucketedDate
            self.tstMinutes = tstMinutes
            self.deepMinutes = deepMinutes
            self.remMinutes = remMinutes
            self.awakeMinutes = awakeMinutes
            self.inBedMinutes = inBedMinutes
            self.sessionStart = sessionStart
            self.sessionEnd = sessionEnd
            self.sourceID = sourceID
        }
    }

    // MARK: - Constants (each carries its spec citation or H-ID)

    /// Stage EWMA half-life in days. No spec value — §5.1 writes "EWMA(deep min, same
    /// source)" and names no constant, so this reuses the sleep signal's 7-day half-life
    /// from `BaselineEngine.BaselineConstants.sleepHalfLifeDays`. H-21.
    static var stageHalfLifeDays: Double { BaselineEngine.BaselineConstants.sleepHalfLifeDays }
    /// Minimum same-source folds before a stage EWMA carries scoring authority (ruling 3 in
    /// §9.5 says a not-yet-converged EWMA drops the component but names no bound). H-21.
    static let stageBaselineMinNights: Int = 7

    /// Trailing midpoint window (§9.2 `midpointSD14`).
    static let midpointBufferLength: Int = 14
    /// Minimum nights in the midpoint buffer before SD/deviation are meaningful — below it
    /// both read nil (never a fabricated statistic). Mirrors `madMinValid`. H-23.
    static let midpointMinNights: Int = 5
    /// §9.3 CHRONIC_IRREGULAR entry SD threshold (the per-night irregularity flag).
    static let irregularEntrySDMinutes: Double = 75.0
    /// §9.3 chronic EXIT SD threshold (the 5-night exit run counts nights below this).
    static let chronicExitSDMinutes: Double = 50.0
    /// §9.2 rhythm-break rule: |deviation| > max(`rhythmBreakSDMultiple`×SD14, floor).
    static let rhythmBreakSDMultiple: Double = 2.0
    static let rhythmBreakFloorMinutes: Double = 90.0

    /// §4 / §9.2: debt is the trailing 7-night deficit sum, capped at 6 h.
    static let deficitBufferLength: Int = 7
    static let debt7CapMinutes: Double = 360.0

    /// §4 gate window, kept as trailing NIGHTS (≤90) rather than 90 calendar days. H-19.
    static let tstBufferLength: Int = 90
    /// §4 gate: ≥28 nights with sleep data before need personalizes.
    static let needGateNights: Int = 28
    /// §4 estimator (a): the 75th percentile of trailing TST (H-19 for the interim
    /// unfiltered form — the unconstrained-night filter and estimator (b) are Phase S3).
    static let needPercentile: Double = 0.75
    /// §4 bounds: clamp to [6.5 h, 9.5 h].
    static let needLowerBoundMinutes: Double = 390.0
    static let needUpperBoundMinutes: Double = 570.0
    /// §4 deadband: ignore recomputed values within 15 min of the stored need.
    static let needDeadbandMinutes: Double = 15.0
    /// §4 rate limit: at most ±10 min change per weekly update (hysteresis).
    static let needMaxWeeklyStepMinutes: Double = 10.0
    /// §4 cadence: weekly, never nightly.
    static let needUpdateIntervalDays: Int = 7
    /// §4 cold start — read from the engine's single source of truth, never retyped.
    static var coldStartNeedMinutes: Double { RecoveryScoreEngine.sleepTargetHours * 60.0 }

    /// Nights after a dominant-source change during which `isSourceStable` reads false
    /// (H-15 halves confidence there). No spec value — chosen to match H-15's own
    /// kill-test window ("the 14 nights after a source change"). H-20.
    static let sourceInstabilityNights: Int = 14
    /// Prior-wake sanity window: a wake span outside (0, 48 h] is a data gap, not a
    /// 3-day vigil — it reads as missing so no trigger fires on it. No spec value. H-22.
    static let priorWakeMaxHours: Double = 48.0
    /// Completeness hold: a session that ended less than 120 minutes before the run reads
    /// as possibly-ongoing (a 02:00 mid-night open, a mid-sync truncation) and must not
    /// fold — the complete night folds on a later run the same day. H-26.
    static let sessionCompleteHoldMinutes: Double = 120.0

    // MARK: - Phase S3 pass-through constants (closing H-33)

    /// §9.2's own window: `priorWakeZ` is scored against the athlete's 28-night prior-wake
    /// history.
    static let priorWakeBufferLength: Int = 28
    /// Minimum buffered spans before `priorWakeZ` is computable — below it (or when the
    /// buffer's MAD is zero) the z reads nil and the HIGH_PRESSURE z-arm never fires.
    /// Mirrors `madMinValid` ("no fabricated dispersion"). H-34.
    static let priorWakeMinNightsForZ: Int = 5
    /// Minimum asleep minutes for a non-main session to count as a nap. Mirrors §9.3's
    /// NAP_DAY trigger (`napMinutes ≥ 20`) so a sub-trigger doze never even enters the
    /// sum. H-35.
    static let napMinimumMinutes: Double = 20.0
    /// Staleness bound on the carried `lastSleepEndDate` (H-41). After a missed-fold day
    /// the stored end belongs to a night BEFORE the unfolded one: the unfolded previous
    /// night then sits inside the widened gap and would read as a ~400-min "nap", and the
    /// prior-wake span (~39.5 h, inside H-22's 48 h) is a fold-gap artifact, not a vigil.
    /// A `lastSleepEndDate` more than 24 h before tonight's session start therefore reads
    /// as MISSING for the nap sum (→ 0, unknown) and for the H-34 buffer push (no push) —
    /// H-22's gap-not-vigil spirit. The `makeInput` scoring read keeps H-22's own 48 h
    /// bound (that row's kill test governs it).
    static let lastSleepEndStalenessMaxHours: Double = 24.0
    /// §9.2's window for both prior-day z's: yesterday's total vs the trailing 28 days
    /// before it.
    static let priorDayWindowDays: Int = 28
    /// Minimum days with an observed active-energy sum inside the trailing window before
    /// `priorDayActiveEnergyZ` is computable (a watch not worn most days has no
    /// distribution to score against). H-37.
    static let energyZMinPresentDays: Int = 21

    // MARK: - Fold guards (session identity + completeness)

    /// Whether the pipeline may fold this night into `state` at clock time `now`.
    ///
    /// Two guards, both required (the F3 premature-fold fix — together they make a
    /// truncated 02:00 fetch skip AND the full night still fold later that same day):
    /// - **Session identity**: a session ending at or before the stored
    ///   `lastSleepEndDate` is the same physical night re-presented (or an older one) —
    ///   never fold it twice. Day identity alone cannot catch this: a truncated and a
    ///   complete read of one night can carry the same wake day.
    /// - **Completeness (H-26)**: a session that ended less than
    ///   `sessionCompleteHoldMinutes` before `now` may still be ongoing; skip it and let
    ///   a later run fold the finished night.
    ///
    /// `now` is injected — the builder stays clock-free.
    static func shouldFold(night: Night, state: State, now: Date) -> Bool {
        if let lastEnd = state.lastSleepEndDate, night.sessionEnd <= lastEnd {
            return false
        }
        if now.timeIntervalSince(night.sessionEnd) < sessionCompleteHoldMinutes * 60.0 {
            return false
        }
        return true
    }

    // MARK: - Midpoint

    /// The night's sleep midpoint in minutes **relative to the wake-day midnight**
    /// (negative = before midnight), so consecutive nights are comparable without a
    /// modular wrap at 00:00. Roenneberg's midpoint quantity (§9.1), reduced to a signed
    /// scalar — the representation itself is a registered judgment (H-30).
    static func midpointMinutes(
        sessionStart: Date,
        sessionEnd: Date,
        calendar: Calendar
    ) -> Double {
        let midpoint = sessionStart.addingTimeInterval(
            sessionEnd.timeIntervalSince(sessionStart) / 2.0
        )
        let wakeDayMidnight = calendar.startOfDay(for: sessionEnd)
        return midpoint.timeIntervalSince(wakeDayMidnight) / 60.0
    }

    // MARK: - Engine input assembly (prequential: state through t−1 ONLY)

    /// Assemble the engine's `SleepInput` from the PRE-fold state plus tonight's raw night.
    /// No field of `state` reflects tonight — score-then-fold, like `BaselineEngine.score`.
    ///
    /// `priorDayLoadZ` / `priorDayActiveEnergyZ` / `napMinutes` are pass-throughs the S3
    /// pipeline computes (`priorDayLoadZ(dailyTSS:…)` / `priorDayEnergyZ(dailyEnergy:…)` /
    /// `napMinutes(candidates:…)`) and supplies here; `priorWakeZ` is computed internally
    /// from the carried 28-night buffer (H-34). The S2 scope cut that left them absent is
    /// CLOSED (H-33) — but a nil z still never fires a trigger (the engine's own rule), so
    /// a caller without the data degrades exactly as S2 did.
    static func makeInput(
        state: State,
        night: Night,
        priorDayLoadZ: Double? = nil,
        priorDayActiveEnergyZ: Double? = nil,
        napMinutes: Double = 0,
        calendar: Calendar
    ) -> SleepScoreEngine.SleepInput {
        // Prior wake span (Process-S proxy). Outside (0, 48 h] = data gap → nil (H-22).
        let priorWakeHours = validPriorWakeHours(
            lastSleepEnd: state.lastSleepEndDate,
            sessionStart: night.sessionStart
        )
        // priorWakeZ (H-34, closing H-33): robust z of tonight's span against the PRE-fold
        // 28-night buffer. nil below `priorWakeMinNightsForZ` buffered spans or when the
        // buffer's MAD is zero (a perfectly regular sleeper has no dispersion to score
        // against — the HIGH_PRESSURE hours-arm still fires).
        let priorWakeZ = priorWakeHours.flatMap { robustZ($0, buffer: state.priorWakeBuffer) }

        // Midpoint statistics from the PRE-fold buffer (≥ midpointMinNights or nil, H-23;
        // the prequential pre-/post-fold SD split is a registered judgment, H-31).
        let midpoint = midpointMinutes(
            sessionStart: night.sessionStart,
            sessionEnd: night.sessionEnd,
            calendar: calendar
        )
        let sd14 = midpointSD(state.midpointBuffer)
        var deviation: Double?
        if state.midpointBuffer.count >= midpointMinNights {
            deviation = midpoint - BaselineEngine.median(state.midpointBuffer)
        }

        // §9.2 daysSinceRhythmBreak, INCLUDING tonight (registered judgment, H-29): a
        // first shifted night reads 0, so the ACUTE_SHIFT trigger
        // (`daysSinceRhythmBreak ≤ 2`) can fire on the night the break happens — the
        // state it exists to catch. The carried counter is "as of the last folded night",
        // so tonight sits one night later (+1) when tonight itself is not a break.
        let tonightIsBreak = isRhythmBreak(deviation: deviation, sd14: sd14)
        let daysSinceRhythmBreak: Int? = tonightIsBreak
            ? 0
            : state.nightsSinceRhythmBreak.map { $0 + 1 }

        // Same-source discipline (H-04): the carried stage EWMAs speak ONLY for a night
        // whose source is known and matches them. On a source-change night they belong to
        // the OLD source; on a nil-source night the match is unverifiable (SPEC-7 ruling)
        // — either way, no authority tonight.
        let sourceMatchesBaseline = night.sourceID != nil
            && night.sourceID == state.dominantSourceID
        let deepBaseline: Double? = (sourceMatchesBaseline && state.deepCount >= stageBaselineMinNights)
            ? state.deepMu : nil
        let remBaseline: Double? = (sourceMatchesBaseline && state.remCount >= stageBaselineMinNights)
            ? state.remMu : nil
        let sourceChangedTonight = night.sourceID != nil
            && state.dominantSourceID != nil
            && night.sourceID != state.dominantSourceID

        // H-20: unstable for the change night and the following `sourceInstabilityNights`.
        let isSourceStable = !sourceChangedTonight
            && ((state.nightsSinceSourceChange ?? sourceInstabilityNights) >= sourceInstabilityNights)

        let stateVector = SleepScoreEngine.SleepStateVector(
            priorWakeHours: priorWakeHours,
            priorWakeZ: priorWakeZ,
            midpointSD14Minutes: sd14,
            midpointDeviationMinutes: deviation,
            daysSinceRhythmBreak: daysSinceRhythmBreak,
            irregularNightsIn14: Int(state.irregularFlags14.reduce(0, +).rounded()),
            nightsBelowChronicExitSD: state.nightsBelowChronicExitSD,
            sleepDebt7Minutes: min(state.deficitBuffer7.reduce(0, +), debt7CapMinutes),
            priorDayLoadZ: priorDayLoadZ,
            priorDayActiveEnergyZ: priorDayActiveEnergyZ,
            napMinutes: napMinutes,
            hasStageData: night.deepMinutes != nil || night.remMinutes != nil,
            isSourceStable: isSourceStable,
            nightsOfHistory: state.nightsOfHistory
        )

        return SleepScoreEngine.SleepInput(
            tstMinutes: night.tstMinutes,
            deepMinutes: night.deepMinutes,
            remMinutes: night.remMinutes,
            awakeMinutes: night.awakeMinutes,
            inBedMinutes: night.inBedMinutes,
            deepBaselineMinutes: deepBaseline,
            remBaselineMinutes: remBaseline,
            needBaseMinutes: state.needBaseMinutes,
            state: stateVector,
            previousProfiles: Set(
                state.previousProfilesRaw.compactMap(SleepScoreEngine.SleepProfile.init(rawValue:))
            ),
            tierOverride: nil
        )
    }

    // MARK: - Fold one night (pure — returns a NEW State)

    /// Fold one night's observation plus the engine's verdict into the carrier state.
    ///
    /// Order (each step reads what the previous produced, nothing more):
    /// 1. W-1 idempotency guard — same/older wake day is a no-op.
    /// 2. Dominant-source bookkeeping; a change RESTARTS the stage baselines and clears
    ///    the TST buffer so the §4 need gate re-runs on the new source ("freeze need and
    ///    restart the stage baselines" — the cleared gate IS the freeze: the stored need
    ///    keeps serving, un-updated, until 28 new-source nights re-open it; registered
    ///    judgment H-28).
    /// 3. Stage EWMA folds (first fold seeds; then plain EWMA at the H-21 half-life).
    /// 4. Midpoint buffer push → per-night irregularity flag → rhythm-break counter →
    ///    chronic-exit counter.
    /// 5. Deficit + TST buffer pushes; night counters.
    /// 6. §4 weekly need learning (gate / p75 / bounds / deadband / ±10-min hysteresis /
    ///    freeze-in-chronic-irregular).
    /// 7. Profile latch + session-end + fold-cutoff stamps.
    ///
    /// - Parameter needTonightMinutes: `SleepResult.needTonightMinutes` (nil on Tiers D/E —
    ///   the deficit then falls back to the stored need, else the §4 cold start).
    /// - Parameter latchedProfiles: `SleepResult.latchedProfiles` — the LATCHED set, not
    ///   the reported one (the engine's own doc says feeding the reported set back would
    ///   drop the chronic latch on an acute night).
    static func fold(
        state: State,
        night: Night,
        needTonightMinutes: Double?,
        latchedProfiles: Set<SleepScoreEngine.SleepProfile>,
        calendar: Calendar
    ) -> State {
        // 1. Idempotency (W-1): fold only strictly after the last folded wake day.
        let day = calendar.startOfDay(for: night.bucketedDate)
        if let last = state.lastFoldedDate, day <= calendar.startOfDay(for: last) {
            return state
        }

        var next = state

        // 2. Dominant source (§4 reset-on-discontinuity).
        if let source = night.sourceID {
            if next.dominantSourceID == nil {
                next.dominantSourceID = source  // first observation — stable, no reset
            } else if next.dominantSourceID != source {
                next.dominantSourceID = source
                next.deepMu = nil
                next.deepCount = 0
                next.remMu = nil
                next.remCount = 0
                next.tstBuffer = []  // re-gates need learning for 28 new-source nights
                next.nightsSinceSourceChange = 0
            } else if next.nightsSinceSourceChange != nil {
                next.nightsSinceSourceChange! += 1
            }
        } else if next.nightsSinceSourceChange != nil {
            next.nightsSinceSourceChange! += 1
        }

        // 3. Stage EWMAs (H-04 same-source discipline; H-21 half-life). Step 2 makes a
        //    KNOWN source equal to `dominantSourceID` here — but a nil-source night proves
        //    nothing about who wrote it, so it must not fold into the dominant source's
        //    EWMAs (SPEC-7 ruling; the old "same-source by construction" claim was false
        //    exactly for that case).
        let sourceKnownAndDominant = night.sourceID != nil
            && night.sourceID == next.dominantSourceID
        let lambda = BaselineEngine.lambda(halfLifeDays: stageHalfLifeDays)
        if let deep = night.deepMinutes, sourceKnownAndDominant {
            if let mu = next.deepMu {
                next.deepMu = (1.0 - lambda) * mu + lambda * deep
            } else {
                next.deepMu = deep  // seed, like BaselineEngine.step's first fold
            }
            next.deepCount += 1
        }
        if let rem = night.remMinutes, sourceKnownAndDominant {
            if let mu = next.remMu {
                next.remMu = (1.0 - lambda) * mu + lambda * rem
            } else {
                next.remMu = rem
            }
            next.remCount += 1
        }

        // 4. Midpoint statistics. The break test uses PRE-fold stats (tonight measured
        //    against the fortnight before it); the irregularity flag and the exit counter
        //    use the POST-push SD (the fortnight ENDING tonight — what "that night's
        //    midpointSD14" means in the §9.3 trigger). The split is a registered
        //    judgment (H-31).
        let midpoint = midpointMinutes(
            sessionStart: night.sessionStart,
            sessionEnd: night.sessionEnd,
            calendar: calendar
        )
        let preSD = midpointSD(state.midpointBuffer)
        var preDeviation: Double?
        if state.midpointBuffer.count >= midpointMinNights {
            preDeviation = midpoint - BaselineEngine.median(state.midpointBuffer)
        }
        if isRhythmBreak(deviation: preDeviation, sd14: preSD) {
            next.nightsSinceRhythmBreak = 0
        } else if next.nightsSinceRhythmBreak != nil {
            next.nightsSinceRhythmBreak! += 1
        }

        next.midpointBuffer = pushCapped(next.midpointBuffer, midpoint, cap: midpointBufferLength)
        let postSD = midpointSD(next.midpointBuffer)
        let irregularTonight = (postSD ?? 0) > irregularEntrySDMinutes
        next.irregularFlags14 = pushCapped(
            next.irregularFlags14,
            irregularTonight ? 1.0 : 0.0,
            cap: midpointBufferLength
        )
        if let sd = postSD, sd < chronicExitSDMinutes {
            next.nightsBelowChronicExitSD += 1
        } else {
            next.nightsBelowChronicExitSD = 0
        }

        // 5. Debt + TST + counters. The deficit is measured against the need the night was
        //    actually scored against; Tiers D/E carry no needTonight, so the stored need
        //    (else the §4 cold start) stands in.
        let needForDeficit = needTonightMinutes ?? state.needBaseMinutes ?? coldStartNeedMinutes
        next.deficitBuffer7 = pushCapped(
            next.deficitBuffer7,
            max(0, needForDeficit - night.tstMinutes),
            cap: deficitBufferLength
        )
        next.tstBuffer = pushCapped(next.tstBuffer, night.tstMinutes, cap: tstBufferLength)
        next.nightsOfHistory += 1

        // S3 (H-34): push tonight's H-22-valid prior-wake span into the 28-night buffer.
        // Uses the PRE-fold `state.lastSleepEndDate` — the same span `makeInput` scored.
        // H-41 staleness gate: a span past `lastSleepEndStalenessMaxHours` means a
        // missed-fold day sits between the stored end and tonight — a fold-gap artifact
        // (~39.5 h), not a real wake span. It reads as missing and never enters the
        // buffer (a single 39.5 h push would drag the 28-night median/MAD for a month).
        if let wake = validPriorWakeHours(
            lastSleepEnd: state.lastSleepEndDate,
            sessionStart: night.sessionStart
        ), wake <= lastSleepEndStalenessMaxHours {
            next.priorWakeBuffer = pushCapped(
                next.priorWakeBuffer,
                wake,
                cap: priorWakeBufferLength
            )
        }

        // 6. §4 need learning. FROZEN while CHRONIC_IRREGULAR is latched (§7 Q9); frozen
        //    weeks do not stamp `needUpdatedAt`, so the first unfrozen due night updates.
        //    `needFrozen` tracks ONLY the chronic freeze (SPEC-8 ruling — see the State
        //    field doc); a source-change re-gate blocks updates via the cleared TST
        //    buffer below, with this flag false.
        next.needFrozen = latchedProfiles.contains(.chronicIrregular)
        // Cadence: due when ≥7 days have passed since the last update — a rolling week,
        // not §4's literal "same weekday" (registered judgment, H-32).
        let due: Bool
        if let lastUpdate = next.needUpdatedAt {
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: lastUpdate),
                to: day
            ).day ?? 0
            due = days >= needUpdateIntervalDays
        } else {
            due = true
        }
        if due, !next.needFrozen, next.tstBuffer.count >= needGateNights {
            let estimate = clamp(
                percentile(next.tstBuffer, needPercentile),
                needLowerBoundMinutes,
                needUpperBoundMinutes
            )
            if let current = next.needBaseMinutes {
                if abs(estimate - current) > needDeadbandMinutes {
                    let step = min(needMaxWeeklyStepMinutes, abs(estimate - current))
                    next.needBaseMinutes = current + (estimate > current ? step : -step)
                }
                // A deadbanded recompute still counts as this week's update (§4 cadence).
            } else {
                // Gate just opened: no stored need exists to deadband or rate-limit
                // against, so the first learned value is the bounded estimate itself
                // (registered judgment, H-27) — ramping from 7.5 h at 10 min/week
                // would leave a 9 h sleeper mis-targeted for months.
                next.needBaseMinutes = estimate
            }
            next.needUpdatedAt = day
        }

        // 7. Latch + stamps. The latched set (not the reported one) round-trips.
        next.previousProfilesRaw = latchedProfiles.map(\.rawValue).sorted()
        next.lastSleepEndDate = night.sessionEnd
        next.lastFoldedDate = day
        return next
    }

    // MARK: - Pass-through inputs (Phase S3, closing H-33)

    /// The H-22-validated prior-wake span in hours: `sessionStart − lastSleepEnd`, readable
    /// only inside (0, `priorWakeMaxHours`]. nil = data gap (or no previous night), never a
    /// vigil. Shared by `makeInput` (scoring) and `fold` (the H-34 buffer push) so the two
    /// can never disagree.
    static func validPriorWakeHours(lastSleepEnd: Date?, sessionStart: Date) -> Double? {
        guard let lastSleepEnd else { return nil }
        let hours = sessionStart.timeIntervalSince(lastSleepEnd) / 3600.0
        guard hours > 0, hours <= priorWakeMaxHours else { return nil }
        return hours
    }

    /// Robust z of `x` against a buffer: `(x − median) / (madScaleK × MAD)` — §9.2 names
    /// the 28-night MEDIAN as the reference, so the scale is the matching robust one
    /// (`BaselineEngine`'s MAD → σ constant), not a mean/SD pair one outlier can drag.
    /// nil below `priorWakeMinNightsForZ` values or when the MAD is zero. H-34.
    static func robustZ(_ x: Double, buffer: [Double]) -> Double? {
        guard buffer.count >= priorWakeMinNightsForZ else { return nil }
        let med = BaselineEngine.median(buffer)
        let mad = BaselineEngine.median(buffer.map { abs($0 - med) })
        guard mad > 0 else { return nil }
        return (x - med) / (BaselineEngine.BaselineConstants.madScaleK * mad)
    }

    /// Nap minutes for tonight's engine input (H-35): the sum of asleep minutes over the
    /// fetch window's non-main clustered sessions that (a) lie strictly between the previous
    /// main sleep's end and tonight's session start — §9.2's "daytime asleep samples since
    /// last main sleep" — and (b) individually reach `napMinimumMinutes` (§9.3's own NAP_DAY
    /// trigger, so a sub-trigger doze never enters the sum). With no known previous sleep
    /// end a candidate is indistinguishable from an unfolded previous night, so the value
    /// reads 0 (absent — it never fires NAP_DAY). The same reasoning gates a STALE end
    /// (H-41): a `lastSleepEnd` more than `lastSleepEndStalenessMaxHours` before the main
    /// session start means a missed-fold day sits in between, and the "candidates" in
    /// that gap are the unfolded previous night — the value reads 0 (unknown).
    static func napMinutes(
        candidates: [NapCandidate],
        mainSessionStart: Date,
        lastSleepEnd: Date?
    ) -> Double {
        guard let lastSleepEnd else { return 0 }
        let gapHours = mainSessionStart.timeIntervalSince(lastSleepEnd) / 3600.0
        guard gapHours <= lastSleepEndStalenessMaxHours else { return 0 }
        return candidates
            .filter {
                $0.asleepMinutes >= napMinimumMinutes
                    && $0.start > lastSleepEnd
                    && $0.end <= mainSessionStart
            }
            .reduce(0) { $0 + $1.asleepMinutes }
    }

    /// z of the prior day's (wake day − 1) session-TSS sum against the trailing
    /// `priorDayWindowDays` calendar days before it, ZERO-FILLED — a rest day is a genuine
    /// 0-load observation in an athlete's daily-load distribution (H-36). Requires the
    /// observed session history to COVER the whole window (`earliestSessionDay` at or before
    /// its first day): zero-filling days the athlete was not even logging yet would
    /// fabricate a distribution. nil on no coverage or zero variance. `dailyTSS` is keyed by
    /// start-of-day.
    static func priorDayLoadZ(
        dailyTSS: [Date: Double],
        wakeDay: Date,
        earliestSessionDay: Date?,
        calendar: Calendar
    ) -> Double? {
        guard let priorDay = calendar.date(byAdding: .day, value: -1, to: wakeDay),
              let windowStart = calendar.date(
                  byAdding: .day, value: -priorDayWindowDays, to: priorDay
              ),
              let earliest = earliestSessionDay,
              earliest <= windowStart else { return nil }
        var window: [Double] = []
        for offset in 1...priorDayWindowDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: priorDay) else {
                continue
            }
            window.append(dailyTSS[calendar.startOfDay(for: day)] ?? 0)
        }
        let x = dailyTSS[calendar.startOfDay(for: priorDay)] ?? 0
        return sampleZ(x, window: window)
    }

    /// z of the prior day's HealthKit active-energy daily sum against the PRESENT days of
    /// the trailing window (H-37). A day with no recorded sum is MISSING (watch off), never
    /// zero-filled; below `energyZMinPresentDays` present days — or when the prior day
    /// itself has no sum, or the variance is zero — the z reads nil. `dailyEnergy` is keyed
    /// by start-of-day.
    static func priorDayEnergyZ(
        dailyEnergy: [Date: Double],
        wakeDay: Date,
        calendar: Calendar
    ) -> Double? {
        guard let priorDay = calendar.date(byAdding: .day, value: -1, to: wakeDay),
              let x = dailyEnergy[calendar.startOfDay(for: priorDay)] else { return nil }
        var window: [Double] = []
        for offset in 1...priorDayWindowDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: priorDay) else {
                continue
            }
            if let value = dailyEnergy[calendar.startOfDay(for: day)] {
                window.append(value)
            }
        }
        guard window.count >= energyZMinPresentDays else { return nil }
        return sampleZ(x, window: window)
    }

    /// Plain sample z: `(x − mean) / SD(n−1)`. nil when the window is degenerate (fewer
    /// than 2 values, or SD ≤ 0).
    static func sampleZ(_ x: Double, window: [Double]) -> Double? {
        guard window.count >= 2 else { return nil }
        let mean = window.reduce(0, +) / Double(window.count)
        let sumSquares = window.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        let sd = (sumSquares / Double(window.count - 1)).squareRoot()
        guard sd > 0 else { return nil }
        return (x - mean) / sd
    }

    // MARK: - Statistics helpers

    /// Sample SD of the midpoint buffer, or nil below `midpointMinNights` (H-23 — a
    /// 2-night SD is not a regularity measurement).
    static func midpointSD(_ buffer: [Double]) -> Double? {
        guard buffer.count >= midpointMinNights else { return nil }
        let mean = buffer.reduce(0, +) / Double(buffer.count)
        let sumSquares = buffer.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        return (sumSquares / Double(buffer.count - 1)).squareRoot()
    }

    /// §9.2 rhythm-break test: |deviation| > max(2×SD14, 90 min). A nil deviation (thin
    /// buffer) never breaks; a nil SD falls back to the 90-min floor alone.
    static func isRhythmBreak(deviation: Double?, sd14: Double?) -> Bool {
        guard let deviation else { return false }
        let threshold = max(rhythmBreakSDMultiple * (sd14 ?? 0), rhythmBreakFloorMinutes)
        return abs(deviation) > threshold
    }

    /// Linear-interpolated percentile (p in [0, 1]) of an unsorted array. 0 for empty —
    /// callers gate on the §4 night count before this matters.
    static func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        guard sorted.count > 1 else { return sorted[0] }
        let rank = clamp(p, 0, 1) * Double(sorted.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = Int(rank.rounded(.up))
        let t = rank - Double(lower)
        return sorted[lower] + t * (sorted[upper] - sorted[lower])
    }

    /// Append with a rolling cap (drop-oldest), the `madBuffer` ring pattern.
    private static func pushCapped(_ buffer: [Double], _ value: Double, cap: Int) -> [Double] {
        var next = buffer
        next.append(value)
        if next.count > cap {
            next.removeFirst(next.count - cap)
        }
        return next
    }

    private static func clamp(_ x: Double, _ lower: Double, _ upper: Double) -> Double {
        min(upper, max(lower, x))
    }
}
