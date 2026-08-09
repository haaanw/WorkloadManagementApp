import Foundation
import SwiftData

/// One day's **recovery-score dual-run record** — the v1 score the athlete actually saw beside
/// the v2 score the robust estimator would have produced from the same inputs.
///
/// ## Why it exists
///
/// v1 scores HRV and RHR as `value / flat-7-value-mean` fed through a straight ratio line. v2
/// scores them as a personal z against `BaselineEngine`'s robust baseline (EWMA with a
/// half-life, MAD-based scale with a σ floor, Huber-clipped folding). Swapping that estimator
/// would move every number the athlete has ever seen, so the 2026-05-30 user-approved scope
/// requires it to run dark until parity is reviewed. These rows are that evidence.
///
/// **Nothing here drives the live score.** The fold runs after the live result is final, and no
/// code flips an activation flag from this data — the `CrossModalShadowGate.validationSummary`
/// discipline: report, never decide.
///
/// ## Trend is deliberately excluded from the comparison
///
/// Both stored scores are the **pre-trend base score**. v1's trend modifier is an autoregression
/// on the engine's own past output, so leaving it in would confound a baseline change with
/// accumulated inertia and make the divergence unattributable.
///
/// ## Local-only by omission (hard guardrail)
///
/// Mirrors `SleepShadowNight` / `VerdictEvent` / `BaselineState`: NO `Codable`, no encoder, no
/// `*Row` DTO, no push/pull helper — the type name must appear NOWHERE in `SyncService.swift`
/// (grep-gated by `RecoveryShadowTests`). The inverse to the owning athlete is a bare
/// `var athlete: Athlete?`, with deliberately no array on `Athlete`.
@Model
final class RecoveryShadowDay {

    /// `startOfDay` of the day scored — the upsert key, one row per athlete per day.
    var date: Date = Date()

    // MARK: - Inputs both arms saw (identical by construction)

    /// Today's morning-window HRV (ms); nil when the day had no morning reading.
    var hrvToday: Double?
    /// Today's daily resting HR (bpm); nil when absent.
    var rhrToday: Double?
    /// Sleep minutes attributed to this wake day; nil when the night is not in yet.
    var sleepMinutes: Double?
    /// Wellness check-in score 0–100; nil when not filled in.
    var wellnessScore: Double?
    /// Prior days with an HRV value that were available to build a baseline from.
    var hrvPriorDayCount: Int = 0
    /// Prior days with an RHR value.
    var rhrPriorDayCount: Int = 0

    // MARK: - v1 arm (the number the athlete saw, pre-trend)

    var v1BaseScore: Double = 0
    var v1HrvComponent: Double?
    var v1RhrComponent: Double?
    var v1SleepComponent: Double?
    var v1WellnessComponent: Double?
    var v1HrvBaseline: Double?
    var v1RhrBaseline: Double?

    // MARK: - v2 arm (robust estimator, never shown)

    /// nil when neither HRV nor RHR earned a z and the arm therefore had nothing new to say.
    var v2BaseScore: Double?
    var v2HrvComponent: Double?
    var v2RhrComponent: Double?
    /// Personal z of today's HRV against the robust baseline; nil until the estimator has
    /// enough history to hold an opinion (it returns nil rather than guessing).
    var hrvZ: Double?
    /// Personal z of today's RHR — already sign-corrected, so positive is always "better".
    var rhrZ: Double?
    /// Robust baseline level (μ) each arm settled on, for auditing the divergence.
    var hrvMu: Double?
    var rhrMu: Double?
    /// `BaselineEngine.confidence` for the HRV signal, 0–1.
    var hrvConfidence: Double = 0

    // MARK: - Held-out outcomes (evidence — NEVER inputs to either arm)

    /// Everything below is recorded so the two arms can eventually be GRADED, and none of it
    /// may ever be read by a scoring engine. A source-level fence in `RecoveryShadowTests`
    /// asserts the scoring engines never reference this model at all; that fence is what keeps
    /// the distinction real rather than aspirational.

    /// Overnight wrist temperature (°C). Already collected by the app and scored by nothing —
    /// the one genuinely independent signal that costs the athlete no extra effort.
    var outcomeWristTempC: Double?

    /// Median overnight respiratory rate (breaths/min). Independent of both arms.
    var outcomeRespiratoryRate: Double?

    /// The athlete's own blinded readiness judgement, 1–10 — the primary outcome, because it
    /// is the only measure that targets exactly what the score claims to estimate.
    var outcomePerceivedReadiness: Int?

    /// Best morning handgrip (kg) when the athlete measured it. Optional and equipment-bound,
    /// so expect it to be sparse; when present it is the strongest objective evidence here,
    /// being a performance measurement rather than a physiological proxy.
    var outcomeGripStrengthKg: Double?

    /// Hand the grip reading came from — a series that switches hands is not one series.
    var outcomeGripHandRaw: String?

    /// **False means the probe was answered after a score had already been shown.** Such a row
    /// is still stored, but it is contaminated by expectancy and must be excluded from any
    /// comparison. Storing the flag rather than assuming blinding is the difference between
    /// evidence and wishful thinking.
    var outcomeWasBlinded: Bool = false

    // MARK: - Bookkeeping

    /// Bumped when the recorded fields or their meaning change, so an analysis can refuse to
    /// mix incompatible rows.
    var schemaVersion: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var athlete: Athlete?

    init(
        date: Date,
        hrvToday: Double? = nil,
        rhrToday: Double? = nil,
        sleepMinutes: Double? = nil,
        wellnessScore: Double? = nil,
        hrvPriorDayCount: Int = 0,
        rhrPriorDayCount: Int = 0,
        v1BaseScore: Double,
        v1HrvComponent: Double? = nil,
        v1RhrComponent: Double? = nil,
        v1SleepComponent: Double? = nil,
        v1WellnessComponent: Double? = nil,
        v1HrvBaseline: Double? = nil,
        v1RhrBaseline: Double? = nil,
        v2BaseScore: Double? = nil,
        v2HrvComponent: Double? = nil,
        v2RhrComponent: Double? = nil,
        hrvZ: Double? = nil,
        rhrZ: Double? = nil,
        hrvMu: Double? = nil,
        rhrMu: Double? = nil,
        hrvConfidence: Double = 0,
        outcomeWristTempC: Double? = nil,
        outcomeRespiratoryRate: Double? = nil,
        outcomePerceivedReadiness: Int? = nil,
        outcomeGripStrengthKg: Double? = nil,
        outcomeGripHandRaw: String? = nil,
        outcomeWasBlinded: Bool = false
    ) {
        self.outcomeWristTempC = outcomeWristTempC
        self.outcomeRespiratoryRate = outcomeRespiratoryRate
        self.outcomePerceivedReadiness = outcomePerceivedReadiness
        self.outcomeGripStrengthKg = outcomeGripStrengthKg
        self.outcomeGripHandRaw = outcomeGripHandRaw
        self.outcomeWasBlinded = outcomeWasBlinded
        self.date = date
        self.hrvToday = hrvToday
        self.rhrToday = rhrToday
        self.sleepMinutes = sleepMinutes
        self.wellnessScore = wellnessScore
        self.hrvPriorDayCount = hrvPriorDayCount
        self.rhrPriorDayCount = rhrPriorDayCount
        self.v1BaseScore = v1BaseScore
        self.v1HrvComponent = v1HrvComponent
        self.v1RhrComponent = v1RhrComponent
        self.v1SleepComponent = v1SleepComponent
        self.v1WellnessComponent = v1WellnessComponent
        self.v1HrvBaseline = v1HrvBaseline
        self.v1RhrBaseline = v1RhrBaseline
        self.v2BaseScore = v2BaseScore
        self.v2HrvComponent = v2HrvComponent
        self.v2RhrComponent = v2RhrComponent
        self.hrvZ = hrvZ
        self.rhrZ = rhrZ
        self.hrvMu = hrvMu
        self.rhrMu = rhrMu
        self.hrvConfidence = hrvConfidence
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
