import Foundation

/// Sleep score v2 — the pure scoring engine (research doc `research-sleep-score.md`,
/// §5 components/ladder, §9 context-conditional profiles, §9.5 hypothesis registry;
/// composition per the council ruling `.planning/sleep-v2/council-composition-ruling.md`,
/// 2026-08-02).
///
/// Contract, mirroring `BaselineEngine`:
/// - pure struct, static methods only, no stored state;
/// - **no clock access of any kind** (§5.3) — every timing fact arrives already reduced to
///   minutes or hours by the S2 pipeline, so the engine is deterministic and grep-gated;
/// - no HealthKit, no SwiftData, no pipeline wiring.
///
/// Shape of a night:
/// 1. `tier(for:)` picks the degradation tier from what data is actually usable (§5.2).
/// 2. `detectProfiles(state:wasChronicIrregular:)` names the state the athlete entered
///    sleep in (§9.3).
/// 3. `needTonightMinutes(...)` turns `need_base` plus the profile credits into the number
///    the duration component is scored against (§4).
/// 4. Each component is scored on its own piecewise-linear curve (§5.1, met-anchored at 80).
/// 5. `composePoints(...)` applies the profile point transfers to the 20-point quality pool.
/// 6. The two-part composition is taken (see below).
///
/// **The council composition (H-16, ruling 2026-08-02, superseding S1's H-12 headroom).**
/// HAN's 80/20 rule, visible in the arithmetic rather than derivable from it:
///
///     score = 0.80 × D  +  Σ pᵢ × clamp((Cᵢ − 80) / 20, −1, +1)
///
/// where D is the 0–100 duration-vs-need curve (so duration contributes exactly 0–80),
/// Cᵢ is each quality component's 0–100 curve value, and pᵢ is its point allocation
/// (continuity 8 / regularity 5 / deep 3.5 / REM 3.5 — a 20-point pool). Every quality
/// curve shares one semantic zero: **80 = the athlete's own normal.** A met-everything
/// night lands exactly 80 ("hours get you to 80"); quality visibly earns — or, signed,
/// loses — the last 20. The symmetric ±1 clamp bounds the downside at −20 total, so a
/// need-met night with catastrophic quality floors at 60 (the nocebo guard).
///
/// **Quality points never renormalize over missing components** (epistemic-cap principle):
/// an absent component contributes zero, positive or negative — missing evidence cannot
/// testify. The tier maxima therefore fall out with no new constants: Tier A 100 ·
/// Tier B 92 (no in-bed span, so no continuity) · Tier C 85 timing-only, 93 with
/// continuity (H-17). **Tier D is exempt by contract**: PLAN requires bit-identity with
/// today's duration-only curve, which reaches 100 on a long night. The tier is stored per
/// night, so the shadow analysis segments on it rather than comparing across the seam.
struct SleepScoreEngine {

    // MARK: - Tier

    /// Degradation ladder (§5.2). The raw values are stored on the snapshot for audit
    /// (§9.4 rule 5), so the shadow analysis can segment by tier instead of comparing
    /// across the Tier-D seam.
    ///
    /// **Raw values are deliberately the spec's own vocabulary**, not the implicit lowercase
    /// case names every other domain enum uses (`ACWRZone`, `RecoveryZone`). These strings
    /// are persisted and logged as the §9.4 rule-5 audit record, and an auditor reading a
    /// shadow log against §5.2 must see the letter the table names. Same reasoning for
    /// `SleepProfile`'s SNAKE_CASE.
    enum SleepTier: String, CaseIterable {
        /// Stages + timing + in-bed span. All five components. Max 100.
        case a = "A"
        /// Stages, no in-bed span. **Continuity carries no authority here** (council
        /// ruling 2026-08-02: without the true opportunity window there is no honest
        /// efficiency denominator — §5.2's original "continuity from WASO" is superseded).
        /// Max 92 (H-17).
        case b = "B"
        /// Duration + timing only; stages omitted. 85 timing-only, 93 when the source
        /// also reports an in-bed span (§3: manual and iPhone-only entries write `inBed`).
        case c = "C"
        /// Duration only, or fewer than `minNightsForV2` nights of history.
        /// **Bit-identical to `RecoveryScoreEngine.sleepDurationToScore`.**
        case d = "D"
        /// No sleep data. Component omitted, score nil — today's behaviour, unchanged.
        case e = "E"
    }

    // MARK: - Components

    /// The five scored components (§5.1). Declaration order is the canonical report order.
    enum SleepComponent: String, CaseIterable {
        case duration
        case continuity
        case regularity
        case deep
        case rem

        /// Duration owns the fixed 0.80 share of the composition; the four quality
        /// components carry the 20-point pool (H-16).
        var isQuality: Bool { self != .duration }
    }

    // MARK: - Profiles

    /// Named nightly states (§9.3). Cases are declared in canonical report order.
    /// `.baseline` is emitted only when nothing else fires. Raw values are §9.3's own
    /// SNAKE_CASE names for the same audit reason as `SleepTier`.
    enum SleepProfile: String, CaseIterable {
        case baseline = "BASELINE"
        case highPressure = "HIGH_PRESSURE"
        case highStrainDay = "HIGH_STRAIN_DAY"
        case acuteShift = "ACUTE_SHIFT"
        case chronicIrregular = "CHRONIC_IRREGULAR"
        case debtCarry = "DEBT_CARRY"
        case napDay = "NAP_DAY"
    }

    // MARK: - Quality points value object

    /// One point allocation per quality component, carried unchanged from the base pool
    /// through the profile transfers, the acute stage cap and the zero floor, so every
    /// stage is independently testable. Duration carries no points — its 0.80 share is
    /// fixed by H-16 and no profile may touch it — so the subscript reads 0 for
    /// `.duration` and ignores writes to it.
    struct QualityPoints: Equatable {
        var continuity: Double = 0
        var regularity: Double = 0
        var deep: Double = 0
        var rem: Double = 0

        init(
            continuity: Double = 0,
            regularity: Double = 0,
            deep: Double = 0,
            rem: Double = 0
        ) {
            self.continuity = continuity
            self.regularity = regularity
            self.deep = deep
            self.rem = rem
        }

        subscript(component: SleepComponent) -> Double {
            get {
                switch component {
                case .duration: return 0
                case .continuity: return continuity
                case .regularity: return regularity
                case .deep: return deep
                case .rem: return rem
                }
            }
            set {
                switch component {
                case .duration: break
                case .continuity: continuity = newValue
                case .regularity: regularity = newValue
                case .deep: deep = newValue
                case .rem: rem = newValue
                }
            }
        }

        /// Sum of the four quality allocations. 20 on an unprofiled full Tier A night;
        /// **never renormalized** — a smaller pool is the honest consequence of missing
        /// evidence or a profile transfer, not an error to correct.
        var total: Double {
            continuity + regularity + deep + rem
        }

        /// The quality components that carry any authority tonight. Duration is never
        /// listed — its share is fixed, not pooled.
        var availableComponents: [SleepComponent] {
            SleepComponent.allCases.filter { self[$0] > 0 }
        }
    }

    // MARK: - State vector

    /// The §9.2 nightly state vector, computed by the S2 pipeline from data Tuwa already
    /// has and passed in whole. Every field has a default so a test (or an early pipeline)
    /// can build a partial vector; a nil signal never fires a trigger and is never coerced
    /// to zero.
    /// Fields are `let`, matching `RecoveryScoreEngine.RecoveryInput` — a night's state is a
    /// measured fact, not something a caller edits after the fact. Every field has a default
    /// so a partial vector is one initializer call, never a mutation of a copy.
    struct SleepStateVector {
        /// Hours awake between the previous sleep session end and this one's start.
        /// Direct Process-S proxy; nil when there is no previous night.
        let priorWakeHours: Double?
        /// Prior wake vs the athlete's own 28-night median. Absolute thresholds are wrong
        /// for a night-owl student, so the z is the preferred trigger.
        let priorWakeZ: Double?
        /// SD of the sleep midpoint over the trailing 14 nights, in minutes. Also the
        /// regularity component's input.
        let midpointSD14Minutes: Double?
        /// Tonight's midpoint minus the trailing median midpoint, in minutes (signed).
        let midpointDeviationMinutes: Double?
        /// Nights since the last rhythm break. Separates acute from chronic.
        let daysSinceRhythmBreak: Int?
        /// How many of the trailing 14 nights exceeded the chronic entry SD threshold.
        /// **Addition to §9.2**: the §9.3 CHRONIC_IRREGULAR trigger reads "≥10 of 14
        /// nights", which §9.2's field list has no field for.
        let irregularNightsIn14: Int
        /// Consecutive nights already below the chronic exit SD threshold.
        /// **Addition to §9.2**, for the same reason (the exit rule needs a counter).
        let nightsBelowChronicExitSD: Int
        /// Σ max(0, need − TST) over the trailing 7 nights, capped at 6 h upstream.
        let sleepDebt7Minutes: Double
        /// Yesterday's session load vs the athlete's own 28-day mean.
        let priorDayLoadZ: Double?
        /// Yesterday's HealthKit active energy vs the 28-day mean. Catches unlogged load
        /// such as a tournament day.
        let priorDayActiveEnergyZ: Double?
        /// Daytime asleep minutes since the last main sleep.
        let napMinutes: Double
        /// §9.2's `stagesAvailable`: an explicit veto for stage scoring — the pipeline sets
        /// it false when the dominant source does not deliver staging. Stage minutes are
        /// still required on top of it, and a same-source baseline on top of that before the
        /// stage components actually score.
        let hasStageData: Bool
        /// §9.2's `sourceStable`: false when the dominant sleep source bundle ID changed
        /// recently. Halves confidence rather than blocking the score.
        let isSourceStable: Bool
        /// Nights of sleep history available. Below `minNightsForV2` the tier is D.
        let nightsOfHistory: Int

        init(
            priorWakeHours: Double? = nil,
            priorWakeZ: Double? = nil,
            midpointSD14Minutes: Double? = nil,
            midpointDeviationMinutes: Double? = nil,
            daysSinceRhythmBreak: Int? = nil,
            irregularNightsIn14: Int = 0,
            nightsBelowChronicExitSD: Int = 0,
            sleepDebt7Minutes: Double = 0,
            priorDayLoadZ: Double? = nil,
            priorDayActiveEnergyZ: Double? = nil,
            napMinutes: Double = 0,
            hasStageData: Bool = true,
            isSourceStable: Bool = true,
            nightsOfHistory: Int = 0
        ) {
            self.priorWakeHours = priorWakeHours
            self.priorWakeZ = priorWakeZ
            self.midpointSD14Minutes = midpointSD14Minutes
            self.midpointDeviationMinutes = midpointDeviationMinutes
            self.daysSinceRhythmBreak = daysSinceRhythmBreak
            self.irregularNightsIn14 = irregularNightsIn14
            self.nightsBelowChronicExitSD = nightsBelowChronicExitSD
            self.sleepDebt7Minutes = sleepDebt7Minutes
            self.priorDayLoadZ = priorDayLoadZ
            self.priorDayActiveEnergyZ = priorDayActiveEnergyZ
            self.napMinutes = napMinutes
            self.hasStageData = hasStageData
            self.isSourceStable = isSourceStable
            self.nightsOfHistory = nightsOfHistory
        }
    }

    // MARK: - Input

    /// One night's measurement plus its state. No calendar values — timing arrives already
    /// reduced to minutes and hours (§5.3).
    struct SleepInput {
        /// Total sleep time in minutes. Nil or non-positive means Tier E.
        let tstMinutes: Double?
        /// Deep (slow-wave) minutes for the night.
        let deepMinutes: Double?
        /// REM minutes for the night.
        let remMinutes: Double?
        /// Awake-after-sleep-onset minutes. **Measured and stored for audit (§9.4 rule 5),
        /// but carries no scoring authority** since the council ruling 2026-08-02: an
        /// efficiency computed against TST + WASO is not the true opportunity window, so
        /// continuity scores only against `inBedMinutes` (which is why Tier B tops at 92).
        let awakeMinutes: Double?
        /// In-bed span in minutes. Continuity's only denominator (see `awakeMinutes`).
        let inBedMinutes: Double?
        /// EWMA of deep minutes **from the same source** (H-04).
        let deepBaselineMinutes: Double?
        /// EWMA of REM minutes **from the same source** (H-04).
        let remBaselineMinutes: Double?
        /// The learned personal sleep need in minutes. Nil means the personalization gate
        /// has not opened yet, so the §4 cold start applies (H-09).
        let needBaseMinutes: Double?
        /// The §9.2 state vector.
        let state: SleepStateVector
        /// **Last night's `SleepResult.latchedProfiles`, handed straight back.** The engine
        /// is stateless, so every §9.4 rule-4 entry/exit hysteresis needs the prior verdict
        /// passed to it. It must be the *latched* set, not `activeProfiles`: ACUTE_SHIFT
        /// out-ranks CHRONIC_IRREGULAR in the reported set (§9.4 rule 1) without ending the
        /// chronic state, and feeding `activeProfiles` back would drop the chronic latch on
        /// an acute night and skip its 5-night exit run.
        let previousProfiles: Set<SleepProfile>
        /// Forces a tier instead of deriving one. Used by the S2 pipeline's source-stability
        /// rule and by the Tier-D golden test. A nil or non-positive TST still means Tier E:
        /// the override picks the ladder rung, it does not manufacture a night.
        let tierOverride: SleepTier?

        init(
            tstMinutes: Double? = nil,
            deepMinutes: Double? = nil,
            remMinutes: Double? = nil,
            awakeMinutes: Double? = nil,
            inBedMinutes: Double? = nil,
            deepBaselineMinutes: Double? = nil,
            remBaselineMinutes: Double? = nil,
            needBaseMinutes: Double? = nil,
            state: SleepStateVector = SleepStateVector(),
            previousProfiles: Set<SleepProfile> = [],
            tierOverride: SleepTier? = nil
        ) {
            self.tstMinutes = tstMinutes
            self.deepMinutes = deepMinutes
            self.remMinutes = remMinutes
            self.awakeMinutes = awakeMinutes
            self.inBedMinutes = inBedMinutes
            self.deepBaselineMinutes = deepBaselineMinutes
            self.remBaselineMinutes = remBaselineMinutes
            self.needBaseMinutes = needBaseMinutes
            self.state = state
            self.previousProfiles = previousProfiles
            self.tierOverride = tierOverride
        }
    }

    // MARK: - Need credits

    /// Audit of the §4 nightly-need arithmetic: the raw credits each profile asked for,
    /// and what actually landed after the §9.4 rule-3 clamp.
    struct NeedCredits: Equatable {
        var pressureMinutes: Double = 0
        var strainMinutes: Double = 0
        var debtMinutes: Double = 0
        var napDebitMinutes: Double = 0
        /// `need_tonight − need_base` after clamping. Zero on Tier D and Tier E.
        var appliedMinutes: Double = 0
    }

    // MARK: - Result

    /// Everything §9.4 rule 5 requires stored per night — a score no one can reconstruct
    /// after the fact is not auditable.
    struct SleepResult {
        /// 0–100, or nil at Tier E (component omitted, exactly as
        /// `RecoveryScoreEngine.compute` already treats a nil sleep duration).
        let score: Double?
        let tier: SleepTier
        /// RAW curve values, 0–100, **before** the H-16 point conversion — so they stay
        /// comparable across nights and tiers, and storable. Duration's raw value is the
        /// unscaled D of the composition.
        let componentScores: [SleepComponent: Double]
        /// The final quality point vector actually applied: post-transfer, post-acute-cap,
        /// zeroed where a component is unavailable. Never renormalized.
        let points: QualityPoints
        /// Canonical order; `[.baseline]` when nothing fired. This is the *reported* set —
        /// §9.4 rule 1's acute-wins exclusivity has already been applied to it.
        let activeProfiles: [SleepProfile]
        /// Every state that is ON tonight, **before** the acute-wins exclusivity. The caller
        /// stores this and hands it back as next night's `previousProfiles`; it is what
        /// keeps CHRONIC_IRREGULAR's exit run intact across an ACUTE_SHIFT night.
        let latchedProfiles: Set<SleepProfile>
        /// The need the duration component was scored against. Nil on Tiers D and E.
        let needTonightMinutes: Double?
        let needCredits: NeedCredits
        /// 0–1 (§5.2), mirroring `BaselineEngine.confidence`'s multiplicative honesty.
        let confidence: Double
    }

    /// One point of a piecewise-linear curve table. Tables are declared ascending in `x`.
    typealias Anchor = (x: Double, y: Double)

    // MARK: - The council composition (H-16)

    // H-16 covers the five constants below plus the ±1 clamp in `qualityContribution`:
    // together they are the whole composition, replacing S1's H-12 plateau + met-anchor +
    // headroom-gain machinery (H-12 RETIRED, superseded by the council ruling 2026-08-02).
    // They are the ruling's constants of record, so they are internal, not private: the
    // tests assert each by name and a silent retune fails loudly.

    /// Duration's fixed share of the composite: `0.80 × D` with D on 0–100, so duration
    /// alone contributes exactly 0–80 and "hours get you to 80" is visible arithmetic,
    /// not a derived plateau. H-16.
    static let durationShare: Double = 0.80

    /// The quality point allocations — a 20-point pool. Continuity leads at 8 (Chinoy:
    /// sleep/wake detection is the honest wearable signal; Leeder: athletes are
    /// systematically fragmented); regularity 5 (Windred 2024 is a mortality endpoint and
    /// cannot fund more — the council's registry-hygiene ruling); the stages split the
    /// rest (κ 0.21–0.53 caps stage authority). H-16.
    static let continuityPoints: Double = 8.0
    static let regularityPoints: Double = 5.0
    static let deepPoints: Double = 3.5
    static let remPoints: Double = 3.5

    /// The shared met anchor: every quality curve's "met the athlete's own normal" point
    /// reads exactly this, so met quality adds exactly zero. H-16.
    static let qualityMetAnchor: Double = 80.0

    /// The band a quality component's excursion is measured against: full points at
    /// met + 20 (curve value 100), full negative points at met − 20 or below (the ±1
    /// clamp — sub-baseline quality SUBTRACTS, but the downside is bounded at −20 total,
    /// so a need-met night with catastrophic quality floors at 60). H-16.
    static let qualityBandWidth: Double = 20.0

    // MARK: - Component curves (§5.1, met-anchored at 80)

    /// §5.1 verbatim, on r = TST ÷ need_tonight, unscaled 0–100. The composition takes
    /// `durationShare ×` this, so the old `durationCeiling` scaling is gone (H-16).
    private static let durationAnchors: [Anchor] = [
        (0.60, 10), (0.70, 32), (0.80, 55), (0.85, 68), (0.90, 80), (0.95, 90), (1.00, 100)
    ]

    /// §5.1 verbatim, on efficiency. **Re-anchor audit (council ruling, point 3):** the
    /// athlete-normal met point was already at 85% → 80 (deliberately athlete-shifted;
    /// Leeder: pooled athlete SE ≈ 86%, so 85% is "your normal", not a failure) — under
    /// the shared met anchor of 80 the curve is numerically unchanged, and its
    /// sub-normal anchors (80% → 62, 75% → 45, ≤65% → 20) stay athlete-shifted as
    /// published. Shape kept.
    private static let continuityAnchors: [Anchor] = [
        (0.65, 20), (0.75, 45), (0.80, 62), (0.85, 80), (0.88, 90), (0.92, 100)
    ]

    /// §5.1 verbatim, on the trailing-14-night midpoint SD in minutes. H-06.
    /// **Re-anchor audit (council ruling, point 3):** the normal met point is a 60-minute
    /// midpoint SD → 80 — already so in the published table (SD 60 sits between the
    /// acute-shift stability gate at <60 and the chronic entry at >75, i.e. an ordinary
    /// athlete fortnight), so the curve is numerically unchanged and its sub-normal
    /// anchors (90 → 62, ≥120 → 45) are preserved. Shape kept.
    private static let regularityAnchors: [Anchor] = [
        (30, 100), (45, 90), (60, 80), (90, 62), (120, 45)
    ]

    /// Floored at 45 because the evidence behind regularity is a mortality endpoint, not a
    /// readiness endpoint (§5.1). H-06.
    private static let regularityFloor: Double = 45.0

    /// On q = tonight ÷ the athlete's own same-source EWMA. H-04 for the formulation,
    /// **H-11 (REVISED by the council ruling 2026-08-02) for these anchor values.**
    ///
    /// Re-anchor audit: the met point moves from S1's q = 1.00 → 85 to q = 1.00 → **80**
    /// (the shared met anchor — met must add exactly zero; met-at-85 would silently hand
    /// back a free 5 points), the 0.85 anchor drops 80 → **75** so the curve stays
    /// strictly increasing, and the excellent anchor q ≥ 1.30 → 100 is unchanged. The
    /// sub-baseline anchors (0.40 → 45, 0.55 → 55, 0.70 → 70) and the 45 floor are §5.1
    /// unchanged. §10 publishes these numbers; the registry row carries the
    /// reachability kill test (<2% of nights at q ≥ 1.30 moves the excellent anchor).
    private static let stageAnchors: [Anchor] = [
        (0.40, 45), (0.55, 55), (0.70, 70), (0.85, 75), (1.00, 80), (1.30, 100)
    ]

    /// One noisy staging night must not crater the score (κ 0.21–0.53). §5.1. H-04.
    private static let stageFloor: Double = 45.0

    // MARK: - Profile triggers (§9.3)

    // §9.4 rule 4 — "every state entry/exit has hysteresis except ACUTE_SHIFT, which is
    // single-night by definition." Each persistent state below therefore has an ENTRY
    // threshold and a lower HOLD threshold: a state that is already latched survives until
    // the signal falls under the hold band, so a signal hovering on the entry line cannot
    // flip the weights on and off night after night. The hold bands are H-13, kept exactly
    // as S1 shipped them — the council ruling touches the composition, not the latch.
    //
    // Hysteresis is anti-chatter, not anti-cliff: it does not remove the step in the points
    // at first entry. The *score* discontinuity §9.4 rule 3's need arithmetic used to carry
    // is removed separately, by `needTonightMinutes` computing §4's credits from their
    // continuous formulas for every night instead of gating them on a trigger.

    // HIGH_PRESSURE — direction is evidence-backed (Borbély 2016 two-process model plus the
    // SWS-rebound literature); the magnitudes below are H-02.
    private static let highPressureWakeHours: Double = 18.0
    private static let highPressureWakeZ: Double = 1.5
    private static let highPressureHoldWakeHours: Double = 17.0   // H-13
    private static let highPressureHoldWakeZ: Double = 1.25       // H-13
    private static let pressureCreditBaselineHours: Double = 16.0 // H-02
    private static let pressureCreditPerHourMinutes: Double = 6.0 // H-02
    private static let pressureCreditCapMinutes: Double = 45.0    // H-02

    // HIGH_STRAIN_DAY — H-03 throughout. Kredlow's architecture effects are small and the
    // only direct load→need test found is null; Whoop asserts the link without validation.
    private static let highStrainLoadZ: Double = 1.0
    private static let highStrainEnergyZ: Double = 1.0
    private static let highStrainHoldZ: Double = 0.75        // H-13
    /// §4 caps the strain credit at 30 min, *not* Whoop's unverified 60.
    private static let strainCreditCapMinutes: Double = 30.0 // H-03
    /// The z at which the strain credit saturates. No spec value: chosen so that the §9.3
    /// trigger point (z = +1) earns half the cap and z = +2 earns all of it. Registered as
    /// H-14 in §9.5 — it fixes what a hard day is worth in minutes, which is a product
    /// decision, so it does not get to live as an unnamed literal.
    private static let strainCreditFullZ: Double = 2.0       // H-14

    // ACUTE_SHIFT — the trigger is evidence-backed (first-night-shift studies); the
    // response, including the half-authority stage cap, is H-05. **No hysteresis, by
    // §9.4 rule 4's own exception**: the state is single-night by definition.
    private static let acuteShiftDeviationMinutes: Double = 120.0
    private static let acuteShiftPriorSDMinutes: Double = 60.0
    private static let acuteShiftMaxDaysSinceBreak: Int = 2
    /// "Stage components capped at half authority" (§9.3), translated by the council
    /// ruling (point 5 / H-18): the stage components' POINTS are halved for that night —
    /// 3.5 → 1.75 each — applied as a cap against the tier's base points after the
    /// transfers. H-05.
    private static let acuteShiftStageAuthorityFactor: Double = 0.5  // H-05

    // CHRONIC_IRREGULAR — construct and health risk are evidenced (Roenneberg, Windred);
    // the weighting is H-06. Need learning freezes here, but that is S2's job (§7 Q9).
    private static let chronicEntrySDMinutes: Double = 75.0
    private static let chronicEntryNightsOf14: Int = 10
    private static let chronicExitSDMinutes: Double = 50.0
    private static let chronicExitConsecutiveNights: Int = 5

    // DEBT_CARRY — direction evidence-backed (Van Dongen 2003: deficits accumulate and
    // hours are what repay them); the magnitude of the point shift is H-07.
    private static let debtCarryThresholdMinutes: Double = 180.0
    private static let debtCarryHoldMinutes: Double = 150.0  // H-13
    private static let debtCreditFraction: Double = 0.30     // H-07
    private static let debtCreditCapMinutes: Double = 30.0   // H-07
    /// §9.2 caps the trailing deficit at 6 h upstream; re-applied here defensively.
    private static let debt7CapMinutes: Double = 360.0

    // NAP_DAY — naps aid performance (grade B), but the substitution ratio is unknown, so
    // the whole rule is H-08. Nothing supports Whoop's implied 1:1 substitution.
    private static let napThresholdMinutes: Double = 20.0
    private static let napHoldMinutes: Double = 15.0         // H-13
    private static let napCreditFraction: Double = 0.50      // H-08
    private static let napCreditCapMinutes: Double = 45.0    // H-08

    // MARK: - Need bounds (§4 guardrails, §9.4 rule 3)

    /// [6.5 h, 9.5 h]. `need_base` is bounded by S2; re-clamped here defensively. H-09.
    private static let needLowerBoundMinutes: Double = 390.0
    private static let needUpperBoundMinutes: Double = 570.0
    private static let needNightlyMaxCreditMinutes: Double = 60.0
    private static let needAbsoluteCapMinutes: Double = 600.0

    /// §4 cold start. Read from `RecoveryScoreEngine.sleepTargetHours` and never retyped as
    /// a literal — that constant's own doc comment says the number must not disagree in
    /// three places.
    private static var coldStartNeedMinutes: Double {
        RecoveryScoreEngine.sleepTargetHours * 60.0
    }

    // MARK: - Tier and confidence gates

    /// Below this many nights of history the tier is D (§5.2).
    private static let minNightsForV2: Int = 7

    /// Confidence count ramp, shaped like `BaselineEngine.confidence`'s
    /// `confFloorDays`/`confFullDays`. 28 is §4's personalization gate.
    ///
    /// The ramp starts at **zero** nights, not at `minNightsForV2`. Anchoring the floor on
    /// the tier gate made the first night that is eligible for a v2 score emit confidence
    /// exactly 0, and §5.2 asks confidence to let the verdict layer *down-weight* a thin
    /// signal — 0 is not a down-weight, it is a discard, and it would have silenced the
    /// whole first fortnight of the shadow run.
    private static let confNightsFloor: Int = 0
    private static let confNightsFull: Int = 28

    /// Confidence multiplier when the dominant sleep source changed. No spec value: §5.2
    /// names source stability as a factor but not its weight. Registered as H-15 in §9.5.
    private static let unstableSourceConfidence: Double = 0.5   // H-15

    /// Denominator of the component-count confidence factor (§5.2).
    private static let componentCountFull: Double = 5.0

    // MARK: - Compute

    /// Score one night. The single entry point.
    static func compute(input: SleepInput) -> SleepResult {
        let resolvedTier = tier(for: input)
        let latched = latchedProfiles(
            state: input.state,
            previousProfiles: input.previousProfiles
        )
        let profiles = reportedProfiles(latched: latched)

        // Tier E — no usable sleep data. The component is omitted, not neutralized.
        // `tst > 0` is checked here and not only in `tier(for:)`: a `tierOverride` short-
        // circuits tier derivation, and `SleepInput.tstMinutes` promises that a nil or
        // non-positive TST is Tier E on every path. Without it, an override plus a zero TST
        // would score a night in which nobody slept.
        guard resolvedTier != .e, let tst = input.tstMinutes, tst > 0 else {
            return SleepResult(
                score: nil,
                tier: .e,
                componentScores: [:],
                points: QualityPoints(),
                activeProfiles: profiles,
                latchedProfiles: latched,
                needTonightMinutes: nil,
                needCredits: NeedCredits(),
                confidence: 0
            )
        }

        // Tier D — the frozen compatibility path. The composition, the profile transfers
        // and the need arithmetic are all bypassed: PLAN requires bit-identity with today's
        // curve, and that outranks internal consistency across the tier seam.
        if resolvedTier == .d {
            let legacy = tierDScore(tstMinutes: tst)
            return SleepResult(
                score: legacy,
                tier: .d,
                componentScores: [.duration: legacy],
                points: QualityPoints(),
                activeProfiles: profiles,
                latchedProfiles: latched,
                needTonightMinutes: nil,
                needCredits: NeedCredits(),
                confidence: confidence(
                    nightsOfHistory: input.state.nightsOfHistory,
                    isSourceStable: input.state.isSourceStable,
                    availableComponentCount: 1
                )
            )
        }

        // Tiers A–C.
        let need = needTonightMinutes(
            needBaseMinutes: input.needBaseMinutes,
            state: input.state
        )

        var raw: [SleepComponent: Double] = [:]
        raw[.duration] = durationScore(tstMinutes: tst, needMinutes: need.minutes)
        if let continuity = continuityScore(
            tstMinutes: tst,
            inBedMinutes: input.inBedMinutes
        ) {
            raw[.continuity] = continuity
        }
        if let regularity = regularityScore(midpointSD14Minutes: input.state.midpointSD14Minutes) {
            raw[.regularity] = regularity
        }
        if let deep = stageScore(
            minutes: input.deepMinutes,
            baselineMinutes: input.deepBaselineMinutes
        ) {
            raw[.deep] = deep
        }
        if let rem = stageScore(
            minutes: input.remMinutes,
            baselineMinutes: input.remBaselineMinutes
        ) {
            raw[.rem] = rem
        }

        // A quality component is available only if the tier grants it points AND it is
        // scorable tonight. An unavailable component contributes ZERO — positive or
        // negative — and the pool is never renormalized over what remains (H-16/H-17:
        // missing evidence cannot testify).
        let base = basePoints(for: resolvedTier)
        let available = Set(
            SleepComponent.allCases.filter { $0.isQuality && base[$0] > 0 && raw[$0] != nil }
        )
        let componentScores = raw.filter { $0.key == .duration || available.contains($0.key) }

        let points = composePoints(base: base, profiles: profiles, available: available)

        // The council composition (H-16):
        // score = 0.80 × D + Σ pᵢ × clamp((Cᵢ − 80) / 20, −1, +1).
        var total = durationShare * raw[.duration]!
        for component in SleepComponent.allCases where available.contains(component) {
            total += points[component] * qualityContribution(componentScores[component]!)
        }

        return SleepResult(
            score: clampScore(total),
            tier: resolvedTier,
            componentScores: componentScores,
            points: points,
            activeProfiles: profiles,
            latchedProfiles: latched,
            needTonightMinutes: need.minutes,
            needCredits: need.credits,
            confidence: confidence(
                nightsOfHistory: input.state.nightsOfHistory,
                isSourceStable: input.state.isSourceStable,
                availableComponentCount: available.count + 1
            )
        )
    }

    // MARK: - Tier selection (§5.2)

    /// Pick the degradation tier from what the night's SOURCE actually delivered.
    ///
    /// **The tier names the data grade, never the state of a personal baseline.** §5.2's
    /// column is "Data present". A stage EWMA that has not converged yet is not missing
    /// data — it is an unscorable component, and the composition already says what to do
    /// with one: it contributes zero (H-16). Demoting the night instead would take the
    /// *continuity* component down with it, discarding a measured efficiency — the input
    /// §5.1 calls the most reliably measured of the five (Chinoy: sleep/wake good, stages
    /// poor). The tier is therefore chosen from data presence, and scorability is settled
    /// per component in `compute`.
    ///
    /// The tier is a data grade, so it does not promise that every component in its §5.2 row
    /// scored: a Tier A night with no 14-night midpoint buffer has no regularity component.
    /// What actually carried authority is `SleepResult.points` (and its
    /// `availableComponents`), stored per night with the state vector and the profiles —
    /// which is exactly the §9.4 rule-5 audit record, so nothing is unreconstructable.
    ///
    /// **Departure from the §5.2 table, recorded:** the Tier D row also reads "or need not
    /// yet personalized". Taken literally that pins every athlete to Tier D for 28 nights,
    /// which would starve the §6 shadow dual-run (≥60 nights) of v2 data. Instead the
    /// not-yet-personalized case is honored by scoring duration against §4's cold-start
    /// need of 7.5 h ("no change for new users"), and Tier D fires on the row's other two
    /// clauses: fewer than `minNightsForV2` nights of history, or "duration only" — no
    /// component but duration is scorable.
    ///
    /// **Council-ruling consequence (2026-08-02):** continuity requires the in-bed span
    /// (see `SleepInput.awakeMinutes`), so a stage-less source that reports WASO but no
    /// in-bed span and no timing is now genuinely duration-only — Tier D.
    static func tier(for input: SleepInput) -> SleepTier {
        // The Tier-E test precedes the override: `SleepInput.tstMinutes` promises that a nil
        // or non-positive TST is Tier E, and an override picks a rung of the ladder rather
        // than manufacturing a night that did not happen.
        guard let tst = input.tstMinutes, tst > 0 else { return .e }
        if let forced = input.tierOverride { return forced }

        if input.state.nightsOfHistory < minNightsForV2 { return .d }

        // What the source delivered (§5.2 "Data present").
        let hasStages = input.state.hasStageData
            && input.deepMinutes != nil
            && input.remMinutes != nil
        let hasInBedWindow = (input.inBedMinutes ?? 0) >= tst

        // What is actually scorable tonight — only used to detect the duration-only floor.
        // Stage scorability implies the source veto: a tier that grants stages no points
        // cannot be what keeps a night off the duration-only floor.
        let stagesScorable = hasStages
            && stageScore(minutes: input.deepMinutes, baselineMinutes: input.deepBaselineMinutes) != nil
            && stageScore(minutes: input.remMinutes, baselineMinutes: input.remBaselineMinutes) != nil
        let continuityScorable = continuityScore(
            tstMinutes: tst,
            inBedMinutes: input.inBedMinutes
        ) != nil
        let regularityScorable = input.state.midpointSD14Minutes != nil

        // §5.2 Tier D, "duration only": nothing but duration can be scored, so the v2
        // machinery has nothing to add and the frozen curve is the honest answer.
        if !stagesScorable && !continuityScorable && !regularityScorable { return .d }

        // Tier A wants the true opportunity window; without it stages still score but
        // continuity cannot (Tier B, max 92 — H-17).
        if hasStages { return hasInBedWindow ? .a : .b }
        return .c
    }

    /// The base quality point pool for a tier, before any profile transfer (H-16).
    ///
    /// Tier B lists continuity at its full 8 in principle but the component can never
    /// score there (no in-bed window), so the pool is stated per tier to keep the stage
    /// veto explicit: Tier C grants the stage components no points even when a vetoed
    /// source smuggles stage minutes in. Duration is not in the pool — its 0.80 share is
    /// fixed and no tier or profile touches it.
    static func basePoints(for tier: SleepTier) -> QualityPoints {
        switch tier {
        case .a, .b:
            return QualityPoints(
                continuity: continuityPoints,
                regularity: regularityPoints,
                deep: deepPoints,
                rem: remPoints
            )
        case .c:
            // Stage-less tier: stages get no authority. Continuity and regularity keep
            // their full allocations, so the maxima fall out as 85 timing-only and 93
            // with an in-bed span (H-17) — no renormalization, no new constants.
            return QualityPoints(
                continuity: continuityPoints,
                regularity: regularityPoints
            )
        case .d, .e:
            return QualityPoints()
        }
    }

    // MARK: - Profile detection (§9.3, §9.4 rules 1 and 4)

    /// Every state that is ON tonight, **before** §9.4 rule 1's exclusivity is applied.
    ///
    /// Triggers are evaluated independently against non-nil fields only — a nil z never
    /// fires and is never read as zero. Every persistent state honors §9.4 rule 4: a state
    /// already present in `previousProfiles` stays on until its signal drops below the hold
    /// band, so a signal sitting on the entry line cannot flip the points night after
    /// night. ACUTE_SHIFT is the rule's own stated exception — it is single-night by
    /// definition, so it is re-decided from tonight's facts alone.
    ///
    /// CHRONIC_IRREGULAR is latched here even on a night ACUTE_SHIFT wins, which is what
    /// keeps its 5-night exit run intact; the exclusivity is a reporting and weighting rule
    /// (§9.4 rule 1: "acute wins for its ≤2 nights"), not an exit.
    static func latchedProfiles(
        state: SleepStateVector,
        previousProfiles: Set<SleepProfile>
    ) -> Set<SleepProfile> {
        var profiles: Set<SleepProfile> = []

        /// Entry when not already latched, hold band when latched (§9.4 rule 4).
        func isOn(_ profile: SleepProfile, entry: Bool, hold: Bool) -> Bool {
            previousProfiles.contains(profile) ? hold : entry
        }

        // HIGH_PRESSURE — either the absolute wake span or the personal z.
        let pressureEntry = (state.priorWakeHours.map { $0 >= highPressureWakeHours }) ?? false
            || (state.priorWakeZ.map { $0 >= highPressureWakeZ }) ?? false
        let pressureHold = (state.priorWakeHours.map { $0 >= highPressureHoldWakeHours }) ?? false
            || (state.priorWakeZ.map { $0 >= highPressureHoldWakeZ }) ?? false
        if isOn(.highPressure, entry: pressureEntry, hold: pressureHold) {
            profiles.insert(.highPressure)
        }

        // HIGH_STRAIN_DAY — TSS OR active energy (§7 Q10 as ruled in PLAN), so a tournament
        // day caught only by active energy still counts.
        let strainEntry = (state.priorDayLoadZ.map { $0 >= highStrainLoadZ }) ?? false
            || (state.priorDayActiveEnergyZ.map { $0 >= highStrainEnergyZ }) ?? false
        let strainHold = (state.priorDayLoadZ.map { $0 >= highStrainHoldZ }) ?? false
            || (state.priorDayActiveEnergyZ.map { $0 >= highStrainHoldZ }) ?? false
        if isOn(.highStrainDay, entry: strainEntry, hold: strainHold) {
            profiles.insert(.highStrainDay)
        }

        // ACUTE_SHIFT — all three conditions required, no hysteresis (§9.4 rule 4).
        if let deviation = state.midpointDeviationMinutes,
           let priorSD = state.midpointSD14Minutes,
           let daysSince = state.daysSinceRhythmBreak,
           abs(deviation) > acuteShiftDeviationMinutes,
           priorSD < acuteShiftPriorSDMinutes,
           daysSince <= acuteShiftMaxDaysSinceBreak {
            profiles.insert(.acuteShift)
        }

        // CHRONIC_IRREGULAR — §9.3's own entry threshold and 5-night exit run.
        let chronicEntry = state.irregularNightsIn14 >= chronicEntryNightsOf14
            && ((state.midpointSD14Minutes.map { $0 > chronicEntrySDMinutes }) ?? false)
        let chronicHold = state.nightsBelowChronicExitSD < chronicExitConsecutiveNights
        if isOn(.chronicIrregular, entry: chronicEntry, hold: chronicHold) {
            profiles.insert(.chronicIrregular)
        }

        if isOn(
            .debtCarry,
            entry: state.sleepDebt7Minutes >= debtCarryThresholdMinutes,
            hold: state.sleepDebt7Minutes >= debtCarryHoldMinutes
        ) {
            profiles.insert(.debtCarry)
        }

        if isOn(
            .napDay,
            entry: state.napMinutes >= napThresholdMinutes,
            hold: state.napMinutes >= napHoldMinutes
        ) {
            profiles.insert(.napDay)
        }

        return profiles
    }

    /// The reported profile set: `latchedProfiles` with §9.4 rule 1's exclusivity applied,
    /// in canonical order, `[.baseline]` when nothing fired. This is what carries the point
    /// transfers and what the snapshot shows a human.
    static func reportedProfiles(latched: Set<SleepProfile>) -> [SleepProfile] {
        var reported = latched
        if reported.contains(.acuteShift) { reported.remove(.chronicIrregular) }
        guard !reported.isEmpty else { return [.baseline] }
        return SleepProfile.allCases.filter { reported.contains($0) }
    }

    /// Convenience over the two steps above, for callers that do not keep the latch.
    static func detectProfiles(
        state: SleepStateVector,
        previousProfiles: Set<SleepProfile> = []
    ) -> [SleepProfile] {
        reportedProfiles(
            latched: latchedProfiles(state: state, previousProfiles: previousProfiles)
        )
    }

    /// The point transfers a profile contributes within the 20-point quality pool (H-18).
    /// BASELINE and NAP_DAY contribute none; ACUTE_SHIFT's stage treatment is the
    /// half-authority cap in `composePoints`, not a transfer.
    ///
    /// **Translation of §9.3's weight deltas (council ruling, point 5).** The quality-side
    /// weight pool was 0.50 and maps onto the 20-point pool, so 1 weight unit = 40 points;
    /// each profile's quality deltas are scaled by exactly ×40, preserving its internal
    /// ratios. Duration-side deltas are DROPPED as double-counting — §4's need credits
    /// already move the same lever, and duration's 0.80 share is fixed (H-16).
    ///
    ///   | Profile           | §9.3 quality weight deltas              | ×40 point transfers          |
    ///   |-------------------|-----------------------------------------|------------------------------|
    ///   | HIGH_PRESSURE     | deep +0.04, reg −0.07, REM −0.02        | deep +1.6, reg −2.8, REM −0.8|
    ///   |                   | (duration +0.05 dropped)                |                              |
    ///   | HIGH_STRAIN_DAY   | deep +0.03, reg −0.05                   | deep +1.2, reg −2.0          |
    ///   |                   | (duration +0.02 dropped)                |                              |
    ///   | ACUTE_SHIFT       | cont +0.05, reg −0.10                   | cont +2.0, reg −4.0          |
    ///   |                   | (duration +0.05 dropped; stage −0.03s   | (stages: capped at 1.75 each |
    ///   |                   | subsumed by the half-authority cap,     | in `composePoints` — the cap |
    ///   |                   | which always bound in S1 too)           | is the whole stage response) |
    ///   | CHRONIC_IRREGULAR | reg +0.07, deep −0.02, REM −0.02        | reg +2.8, deep −0.8, REM −0.8|
    ///   |                   | (duration −0.05 dropped)                |                              |
    ///   | DEBT_CARRY        | cont/reg/deep/REM −0.02 each            | −0.8 each                    |
    ///   |                   | (duration +0.08 dropped)                |                              |
    ///   | NAP_DAY, BASELINE | none                                    | none                         |
    static func pointTransfers(for profile: SleepProfile) -> QualityPoints {
        switch profile {
        case .baseline, .napDay:
            return QualityPoints()
        case .highPressure:
            // H-02 magnitudes. Deep goes UP: after long wake a rebound is expected, so a
            // night that should have rebounded and did not is a real signal.
            return QualityPoints(regularity: -2.8, deep: 1.6, rem: -0.8)
        case .highStrainDay:
            // H-03 magnitudes.
            return QualityPoints(regularity: -2.0, deep: 1.2)
        case .acuteShift:
            // H-05. Regularity goes DOWN: the athlete already loses duration and continuity
            // points that night, and penalizing regularity too is triple-counting one event.
            // The stage response is the half-authority cap in `composePoints`.
            return QualityPoints(continuity: 2.0, regularity: -4.0)
        case .chronicIrregular:
            // H-06. Stages go DOWN: REM proportion is circadian-phase-gated, so stages
            // measured at wildly different clock phases would be measuring the clock.
            return QualityPoints(regularity: 2.8, deep: -0.8, rem: -0.8)
        case .debtCarry:
            // H-07. Hours dominate architecture inside a deficit; the duration side of
            // that is carried by §4's debt credit, so here every quality component just
            // cedes authority evenly.
            return QualityPoints(continuity: -0.8, regularity: -0.8, deep: -0.8, rem: -0.8)
        }
    }

    // MARK: - Point composition (H-16 / H-18)

    /// Apply the profile point transfers to the tier's base pool.
    ///
    /// Order is load-bearing: a component that is unavailable tonight holds zero points
    /// and never receives a transfer (missing evidence cannot testify, and cannot absorb
    /// authority either); then the transfers stack; then ACUTE_SHIFT's half-authority
    /// stage cap is measured against the tier's BASE stage points; then each point
    /// allocation is floored at zero — negative points would invert a component's meaning,
    /// turning better-than-normal quality into a penalty. **There is no renormalization**:
    /// the pool total moves with the transfers and with availability, and that movement is
    /// the honest record (stored on the snapshot per §9.4 rule 5).
    static func composePoints(
        base: QualityPoints,
        profiles: [SleepProfile],
        available: Set<SleepComponent>
    ) -> QualityPoints {
        let qualityComponents = SleepComponent.allCases.filter { $0.isQuality }

        var points = QualityPoints()
        for component in qualityComponents where available.contains(component) {
            points[component] = base[component]
        }

        for profile in profiles {
            let transfers = pointTransfers(for: profile)
            for component in qualityComponents where available.contains(component) {
                points[component] += transfers[component]
            }
        }

        if profiles.contains(.acuteShift) {
            for component in [SleepComponent.deep, .rem] where available.contains(component) {
                let cap = base[component] * acuteShiftStageAuthorityFactor
                points[component] = min(points[component], cap)
            }
        }

        for component in qualityComponents where available.contains(component) {
            points[component] = max(0, points[component])
        }
        return points
    }

    /// The clamped excursion factor of one quality component (H-16):
    /// `clamp((raw − 80) / 20, −1, +1)`. Met quality contributes exactly zero; excellent
    /// (curve value 100) earns the component's full points; sub-baseline quality SUBTRACTS,
    /// bounded at the component's full negative points — the symmetric clamp is the nocebo
    /// guard that keeps a need-met catastrophic night at 60, never lower.
    static func qualityContribution(_ raw: Double) -> Double {
        clamp((raw - qualityMetAnchor) / qualityBandWidth, -1.0, 1.0)
    }

    // MARK: - Nightly need (§4, §9.4 rule 3)

    /// Turn `need_base` plus §4's credits into tonight's need.
    ///
    /// **Every credit is computed from its own continuous formula, for every night — none of
    /// them is gated on a profile trigger.** §4 states `need_tonight = clamp(need_base +
    /// strainCredit + debtCredit, …)` unconditionally, and §9.3's need-delta column points
    /// back at §4 rather than redefining it. Gating them on the §9.3 triggers turned §4's
    /// continuous formulas into step functions: one extra minute of trailing deficit crossing
    /// the 3 h line used to add 30 minutes of need at once and cost ~10 points on the
    /// highest-weighted component. Each formula is already zero at zero signal, so applying
    /// it always is both the literal §4 reading and the one without a cliff. The pressure
    /// credit is treated the same way: §9.3 writes it as "+6 min per hour of wake above
    /// 16 h", and honoring it only from 18 h upward would jump 12 minutes at the trigger.
    ///
    /// The profiles still decide the *points* (§9.3 as translated by H-18), and they are
    /// still latched with hysteresis (§9.4 rule 4). What they no longer do is switch the
    /// need arithmetic on.
    ///
    /// §9.4 rule 3 clamps the total to `need_base ≤ need_tonight ≤ min(need_base + 60, 10 h)`.
    /// The lower bound is `need_base` itself, so the nap debit can only offset positive
    /// credits — a nap on an otherwise unremarkable day changes nothing. That is the rule as
    /// written; H-08's falsification test therefore only ever sees movement on nap days that
    /// also carry pressure, strain or debt credits.
    static func needTonightMinutes(
        needBaseMinutes: Double?,
        state: SleepStateVector
    ) -> (minutes: Double, credits: NeedCredits) {
        let base = clamp(
            needBaseMinutes ?? coldStartNeedMinutes,
            needLowerBoundMinutes,
            needUpperBoundMinutes
        )

        var credits = NeedCredits()

        // Pressure: +6 min per hour of wake above 16 h, cap +45 (H-02).
        if let wake = state.priorWakeHours {
            let excessHours = max(0, wake - pressureCreditBaselineHours)
            credits.pressureMinutes = min(
                excessHours * pressureCreditPerHourMinutes,
                pressureCreditCapMinutes
            )
        }

        // Strain: 0–30 min on the stronger of the two load signals (H-03), saturating at
        // z = `strainCreditFullZ` (H-14). Negative z earns nothing rather than a debit.
        let strainZ = max(state.priorDayLoadZ ?? 0, state.priorDayActiveEnergyZ ?? 0)
        credits.strainMinutes = clamp01(strainZ / strainCreditFullZ) * strainCreditCapMinutes

        // Debt: 30% of the trailing deficit, capped (H-07). Now that it is ungated the
        // fraction is a real gradient — it ramps from 0 to the 30 min cap over the first
        // 100 minutes of trailing deficit instead of arriving whole at the 3 h line.
        let debt = min(max(0, state.sleepDebt7Minutes), debt7CapMinutes)
        credits.debtMinutes = min(debt * debtCreditFraction, debtCreditCapMinutes)

        // Nap: −50% of nap minutes, cap −45 (H-08). Nap minutes never enter TST; they act
        // solely as a need debit, or a nap would be credited twice.
        credits.napDebitMinutes = min(
            max(0, state.napMinutes) * napCreditFraction,
            napCreditCapMinutes
        )

        let requested = credits.pressureMinutes
            + credits.strainMinutes
            + credits.debtMinutes
            - credits.napDebitMinutes
        let upper = min(base + needNightlyMaxCreditMinutes, needAbsoluteCapMinutes)
        let applied = clamp(base + requested, base, upper)
        credits.appliedMinutes = applied - base
        return (applied, credits)
    }

    // MARK: - Component curves

    /// Duration vs need (§5.1), unscaled 0–100 — this is the D of the H-16 composition,
    /// so duration's contribution to the composite is `durationShare ×` this, capping at
    /// exactly 80. Flat below r = 0.60 and flat at 100 for every r ≥ 1.00, however long
    /// the night.
    static func durationScore(tstMinutes: Double, needMinutes: Double) -> Double {
        guard needMinutes > 0 else { return durationAnchors[0].y }
        let ratio = tstMinutes / needMinutes
        return piecewise(ratio, durationAnchors)
    }

    /// Continuity (§5.1). **In-bed span only** (council ruling 2026-08-02): efficiency is
    /// TST over the true opportunity window, and without that window there is no honest
    /// denominator — TST ÷ (TST + WASO) measured the staging stream against itself, which
    /// is why Tier B carries no continuity and tops at 92 (H-17). A shorter in-bed span
    /// than TST is a re-binning artifact (§3), not an efficiency above 100%; the component
    /// then drops out rather than lying. Nil when it drops.
    static func continuityScore(
        tstMinutes: Double,
        inBedMinutes: Double?
    ) -> Double? {
        guard let inBed = inBedMinutes, inBed >= tstMinutes, inBed > 0 else { return nil }
        return piecewise(tstMinutes / inBed, continuityAnchors)
    }

    /// Regularity (§5.1) on the trailing-14-night midpoint SD in minutes. H-06.
    /// Floored at `regularityFloor` — the evidence is a mortality endpoint, not readiness.
    static func regularityScore(midpointSD14Minutes: Double?) -> Double? {
        guard let sd = midpointSD14Minutes else { return nil }
        return max(regularityFloor, piecewise(sd, regularityAnchors))
    }

    /// Deep or REM against the athlete's own same-source EWMA (H-04). One curve serves both.
    /// Nil when the night's minutes or a usable baseline are missing.
    static func stageScore(minutes: Double?, baselineMinutes: Double?) -> Double? {
        guard let minutes, let baseline = baselineMinutes, baseline > 0 else { return nil }
        return max(stageFloor, piecewise(minutes / baseline, stageAnchors))
    }

    // MARK: - Tier D (frozen)

    /// The compatibility tier: **exactly** today's curve, by delegation. Two copies of a
    /// scoring function drift, and `RecoveryScoreEngine.sleepDurationToScore`'s own doc
    /// comment says as much — the golden test pins this delegation, not a transcription.
    static func tierDScore(tstMinutes: Double) -> Double {
        RecoveryScoreEngine.sleepDurationToScore(tstMinutes)
    }

    // MARK: - Confidence (§5.2)

    /// Nights of history × source stability × component count, multiplicative like
    /// `BaselineEngine.confidence` — any weak factor pulls the whole thing down, which is
    /// the honest behaviour when the verdict layer is about to down-weight this signal.
    static func confidence(
        nightsOfHistory: Int,
        isSourceStable: Bool,
        availableComponentCount: Int
    ) -> Double {
        guard availableComponentCount > 0 else { return 0 }
        let floorNights = Double(confNightsFloor)
        let fullNights = Double(confNightsFull)
        let cCount = clamp01((Double(nightsOfHistory) - floorNights) / (fullNights - floorNights))
        let cSource = isSourceStable ? 1.0 : unstableSourceConfidence
        let cComponents = clamp01(Double(availableComponentCount) / componentCountFull)
        return cCount * cSource * cComponents
    }

    // MARK: - Helpers

    /// Linear interpolation between ascending anchors; flat outside the table.
    private static func piecewise(_ x: Double, _ anchors: [Anchor]) -> Double {
        guard let first = anchors.first, let last = anchors.last else { return 0 }
        if x <= first.x { return first.y }
        if x >= last.x { return last.y }
        for index in 1..<anchors.count {
            let lower = anchors[index - 1]
            let upper = anchors[index]
            if x <= upper.x {
                let span = upper.x - lower.x
                guard span > 0 else { return upper.y }
                let t = (x - lower.x) / span
                return lower.y + t * (upper.y - lower.y)
            }
        }
        return last.y
    }

    private static func clampScore(_ score: Double) -> Double {
        min(100, max(0, score))
    }

    private static func clamp(_ x: Double, _ lower: Double, _ upper: Double) -> Double {
        min(upper, max(lower, x))
    }

    private static func clamp01(_ x: Double) -> Double {
        min(1.0, max(0.0, x))
    }
}
