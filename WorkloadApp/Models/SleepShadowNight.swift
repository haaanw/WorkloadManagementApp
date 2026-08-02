import Foundation
import SwiftData

/// Sleep score v2, Phase S3 — the **§6 per-night shadow dual-run record**. One row per folded
/// night (the same fold `RecoveryPipeline.runSleepV2Shadow` performs): the night's measurement,
/// the v2 engine's full audit output (tier, per-component curve values, points, profiles, need
/// arithmetic, confidence), the v1 sleep component computed over the same morning, and the two
/// deferred §6 joins — next-morning physiology + the sleep-free readiness proxy, and the
/// next-evening session RPE / felt-right / verdict-issued triple. `SleepShadowAnalysis` computes
/// the five §6 falsification criteria on demand from these rows; nothing here drives the live
/// recovery score.
///
/// ## Local-only by omission (hard guardrail)
/// Raw-adjacent sleep data (stage minutes, session timing, midpoint statistics) is device-local
/// by HAN's Q2 ruling. Mirroring `VerdictEvent` / `BaselineState` / `SorenessLog`: NO `Codable`
/// conformance, no encoder, no `*Row` DTO, no `push*`/`pull*` helper — the type name appears
/// NOWHERE in `SyncService.swift` (grep-gated by
/// `SleepShadowTests.test_syncFence_sleepShadowNightAbsentFromSyncService`). The inverse to the
/// owning athlete is a bare `var athlete: Athlete?` — deliberately NO array on `Athlete`.
///
/// ## Sign-out / account-deletion
/// Matches the `VerdictEvent` / `BaselineState` precedent for athlete-scoped local-only models:
/// no explicit purge in `AppContainer.signOut` / `deleteAccount` (only the non-athlete-scoped
/// `ExerciseOverride` is purged there). Every read filters by the current athlete's id, so rows
/// of a signed-out athlete are unreachable, exactly like the sleep-v2 carrier state already
/// living in `BaselineState`.
///
/// ## Additive schema
/// Registered additively in the app `Schema` array; bare optional inverse ⇒ SwiftData
/// lightweight migration, the `ShadowArmPrediction` precedent. No migration plan needed.
@Model
final class SleepShadowNight {
    @Attribute(.unique) var id: UUID

    // MARK: - Identity

    /// `startOfDay` of the WAKE day — the same fold key `runSleepV2Shadow` uses (F3a). One row
    /// per athlete per wake day; the pipeline upserts on this key.
    var wakeDate: Date
    /// Bundle id of the dominant sleep source (§6 "source bundle IDs"); nil when unknown.
    var sourceBundleID: String?

    // MARK: - The night as measured (§6 log list)

    /// Total sleep time in minutes (dominant source, clustered session).
    var tstMinutes: Double
    /// Deep minutes; nil when the source did not stage.
    var deepMinutes: Double?
    /// REM minutes; nil when the source did not stage.
    var remMinutes: Double?
    /// Core (light) minutes; nil when the source did not stage.
    var coreMinutes: Double?
    /// WASO — awake-after-onset minutes (audit only; no scoring authority since the council
    /// ruling).
    var wasoMinutes: Double?
    /// In-bed span minutes (H-24 derivation).
    var inBedMinutes: Double?
    /// First asleep sample start of the session.
    var sessionStart: Date
    /// Last asleep sample end of the session.
    var sessionEnd: Date

    // MARK: - v2 verdict (§9.4 rule 5 audit)

    /// `SleepScoreEngine.SleepTier` raw value ("A"…"E").
    var tierRaw: String
    /// RAW per-component curve values (0–100, pre-point-conversion), nil where unscored.
    var componentDuration: Double?
    var componentContinuity: Double?
    var componentRegularity: Double?
    var componentDeep: Double?
    var componentRem: Double?
    /// The applied quality point vector (post-transfer, post-cap, zero-floored).
    var pointsContinuity: Double
    var pointsRegularity: Double
    var pointsDeep: Double
    var pointsRem: Double
    /// The stored learned need the night was scored against; nil = gate closed (7.5 h cold
    /// start applied).
    var needBaseMinutes: Double?
    /// `need_tonight` after the §4 credits and the §9.4 rule-3 clamp; nil on Tiers D/E.
    var needTonightMinutes: Double?
    /// The §4 credit audit (`SleepScoreEngine.NeedCredits`).
    var creditPressureMinutes: Double
    var creditStrainMinutes: Double
    var creditDebtMinutes: Double
    var creditNapDebitMinutes: Double
    var creditAppliedMinutes: Double
    /// The REPORTED profile set (post acute-wins exclusivity), raw strings, canonical order.
    var activeProfilesRaw: [String]
    /// The LATCHED profile set (pre-exclusivity — what round-trips as `previousProfiles`).
    var latchedProfilesRaw: [String]
    /// v2 composite score; nil only at Tier E (which never persists a row in practice).
    var v2Score: Double?
    /// Engine confidence 0–1 (§5.2).
    var confidence: Double

    // MARK: - v1 dual-run arm (§6 "compute v1 and v2 every night, store both")

    /// The minutes the LIVE v1 sleep component consumed that morning
    /// (`fetchLastNightSleepWithDate` — all-source, unclustered; deliberately not the v2 TST).
    var v1SleepMinutes: Double?
    /// `RecoveryScoreEngine.sleepDurationToScore(v1SleepMinutes)` — the v1 sleep component
    /// score for the same night. Nil when v1 saw no sleep.
    var v1SleepComponentScore: Double?

    // MARK: - State-vector audit (composites only — §9.4 rule 5)

    var midpointSD14Minutes: Double?
    var midpointDeviationMinutes: Double?
    var priorWakeHours: Double?
    var priorWakeZ: Double?
    var priorDayLoadZ: Double?
    var priorDayActiveEnergyZ: Double?
    var napMinutes: Double
    var sleepDebt7Minutes: Double
    /// q = tonight ÷ same-source EWMA per stage — the H-11 kill-test read ("distribution of
    /// nightly q per athlete per source") and criterion 2's residual input. Nil when the stage
    /// or its baseline was unavailable.
    var deepQ: Double?
    var remQ: Double?

    // MARK: - Next-morning join (§6; filled by the pipeline once the wake day has elapsed)

    /// "Next morning" = the morning the athlete woke FROM this night, i.e. this row's wake
    /// day. Values are joined from the wake day's persisted `RecoverySnapshot` /
    /// `WellnessCheckIn` on a later day (H-39 — the `ShadowAnalyticsService.resolveOutcomes`
    /// target-day discipline, D-03), never from a live fetch, so the day's wellness check-in
    /// (entered any time that day) is complete when joined. Nil-and-stamped when the wake day
    /// produced no snapshot — absence is the record.
    var nextMorningHRV: Double?
    var nextMorningRHR: Double?
    var nextMorningWellness: Double?
    /// The sleep-free readiness proxy (H-38): the wake day's `RecoveryScoreEngine.baseScore`
    /// with the sleep component omitted (weights renormalize over HRV/RHR/wellness) and the
    /// trend modifier zeroed (trend history contains sleep — it would leak the thing being
    /// tested back into the outcome). The wellness arm is the check-in's SLEEP-FREE
    /// reconstruction (soreness + energy + stress rescaled to 0–100), never the composite
    /// `wellnessScore` — the composite is 25% `sleepQuality`, a subjective rating of the
    /// tested night (H-38 revision; `nextMorningWellness` above keeps the full composite
    /// as audit). Nil when no sleep-free component existed (never a fabricated neutral 50).
    var sleepFreeReadiness: Double?
    /// When the morning join ran; nil until joined. Stamped even when the joined values are
    /// nil, so a data-less day is not re-joined forever.
    var morningJoinedAt: Date?

    // MARK: - Next-evening join (§6; filled once wakeDate + 1 has also elapsed)

    /// RPE of the wake day's highest-`trainingStress` session; nil if no session or no RPE.
    var eveningSessionRPE: Double?
    /// `VerdictEvent.feltRightRaw` for the wake day's plan ("right"/"wrong"/"unsure"). The
    /// felt-right self-report is write-once on the NEXT calendar day, so this join waits until
    /// wakeDate + 2 (H-39); a missed report stays nil — absence is the record.
    var eveningFeltRightRaw: String?
    /// Whether a verdict was issued for the wake day (a `VerdictEvent` with that `planDate`
    /// exists). Nil until the evening join runs.
    var eveningVerdictIssued: Bool?
    /// When the evening join ran; nil until joined.
    var eveningJoinedAt: Date?

    var updatedAt: Date

    /// The pass-through wiring generation this row was recorded under (the H-33 boundary,
    /// persisted). 2 = the S3 wiring (priorWakeZ / naps / prior-day z's all live). Future
    /// profile-frequency reads segment on THIS field, not on dates reconstructed after the
    /// fact; a later wiring change bumps the default. Inline default ⇒ additive lightweight
    /// migration (any pre-existing dev rows read 2 — acceptable: no pre-S3 rows exist in
    /// the wild, the S2 shadow was print-only).
    var schemaVersion: Int = 2

    /// Bare inverse to the owning athlete (mirrors `VerdictEvent`). Deliberately NO array on
    /// `Athlete`.
    var athlete: Athlete?

    init(
        id: UUID = UUID(),
        wakeDate: Date,
        sourceBundleID: String? = nil,
        tstMinutes: Double,
        deepMinutes: Double? = nil,
        remMinutes: Double? = nil,
        coreMinutes: Double? = nil,
        wasoMinutes: Double? = nil,
        inBedMinutes: Double? = nil,
        sessionStart: Date,
        sessionEnd: Date,
        tierRaw: String,
        componentDuration: Double? = nil,
        componentContinuity: Double? = nil,
        componentRegularity: Double? = nil,
        componentDeep: Double? = nil,
        componentRem: Double? = nil,
        pointsContinuity: Double = 0,
        pointsRegularity: Double = 0,
        pointsDeep: Double = 0,
        pointsRem: Double = 0,
        needBaseMinutes: Double? = nil,
        needTonightMinutes: Double? = nil,
        creditPressureMinutes: Double = 0,
        creditStrainMinutes: Double = 0,
        creditDebtMinutes: Double = 0,
        creditNapDebitMinutes: Double = 0,
        creditAppliedMinutes: Double = 0,
        activeProfilesRaw: [String] = [],
        latchedProfilesRaw: [String] = [],
        v2Score: Double? = nil,
        confidence: Double = 0,
        v1SleepMinutes: Double? = nil,
        v1SleepComponentScore: Double? = nil,
        midpointSD14Minutes: Double? = nil,
        midpointDeviationMinutes: Double? = nil,
        priorWakeHours: Double? = nil,
        priorWakeZ: Double? = nil,
        priorDayLoadZ: Double? = nil,
        priorDayActiveEnergyZ: Double? = nil,
        napMinutes: Double = 0,
        sleepDebt7Minutes: Double = 0,
        deepQ: Double? = nil,
        remQ: Double? = nil,
        athlete: Athlete? = nil
    ) {
        self.id = id
        self.wakeDate = wakeDate
        self.sourceBundleID = sourceBundleID
        self.tstMinutes = tstMinutes
        self.deepMinutes = deepMinutes
        self.remMinutes = remMinutes
        self.coreMinutes = coreMinutes
        self.wasoMinutes = wasoMinutes
        self.inBedMinutes = inBedMinutes
        self.sessionStart = sessionStart
        self.sessionEnd = sessionEnd
        self.tierRaw = tierRaw
        self.componentDuration = componentDuration
        self.componentContinuity = componentContinuity
        self.componentRegularity = componentRegularity
        self.componentDeep = componentDeep
        self.componentRem = componentRem
        self.pointsContinuity = pointsContinuity
        self.pointsRegularity = pointsRegularity
        self.pointsDeep = pointsDeep
        self.pointsRem = pointsRem
        self.needBaseMinutes = needBaseMinutes
        self.needTonightMinutes = needTonightMinutes
        self.creditPressureMinutes = creditPressureMinutes
        self.creditStrainMinutes = creditStrainMinutes
        self.creditDebtMinutes = creditDebtMinutes
        self.creditNapDebitMinutes = creditNapDebitMinutes
        self.creditAppliedMinutes = creditAppliedMinutes
        self.activeProfilesRaw = activeProfilesRaw
        self.latchedProfilesRaw = latchedProfilesRaw
        self.v2Score = v2Score
        self.confidence = confidence
        self.v1SleepMinutes = v1SleepMinutes
        self.v1SleepComponentScore = v1SleepComponentScore
        self.midpointSD14Minutes = midpointSD14Minutes
        self.midpointDeviationMinutes = midpointDeviationMinutes
        self.priorWakeHours = priorWakeHours
        self.priorWakeZ = priorWakeZ
        self.priorDayLoadZ = priorDayLoadZ
        self.priorDayActiveEnergyZ = priorDayActiveEnergyZ
        self.napMinutes = napMinutes
        self.sleepDebt7Minutes = sleepDebt7Minutes
        self.deepQ = deepQ
        self.remQ = remQ
        self.nextMorningHRV = nil
        self.nextMorningRHR = nil
        self.nextMorningWellness = nil
        self.sleepFreeReadiness = nil
        self.morningJoinedAt = nil
        self.eveningSessionRPE = nil
        self.eveningFeltRightRaw = nil
        self.eveningVerdictIssued = nil
        self.eveningJoinedAt = nil
        self.updatedAt = .now
        self.athlete = athlete
    }
}
