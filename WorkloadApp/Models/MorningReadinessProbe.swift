import Foundation
import SwiftData

/// One morning's **held-out outcome measurement** — the evidence a recovery score is graded
/// against, captured before the athlete has seen any score.
///
/// ## Why a separate model, and why "held out"
///
/// Validating one recovery score against another needs something to grade both by, and every
/// obvious candidate is already inside the thing being tested. The wellness check-in is 25% of
/// both scores. A post-session "did that feel right?" is contaminated by the verdict the app
/// showed that morning. Next-day HRV looks independent but is not: HRV is strongly
/// autocorrelated and both arms contain today's value, so whichever arm weights HRV harder
/// would win on arithmetic alone.
///
/// So this model exists to hold measurements that are, by construction:
/// 1. **not inputs** to any score — nothing here may ever be read by a scoring engine, and
///    `RecoveryShadowTests` fences that at source level; and
/// 2. **not influenced by seeing a score** — captured before the dashboard renders, with
///    `wasBlinded` recording whether that actually held on the day.
///
/// ## The measurements
///
/// **Perceived readiness (1–10).** The athlete's own answer to the question the score is
/// trying to answer. Deliberately a *global judgement*, not another symptom rating: the four
/// wellness ratings (sleep quality, soreness, energy, stress) are score INPUTS, so a probe
/// resembling them would leak. This is the human analogue of the score's OUTPUT, which is what
/// makes comparing them a criterion-validity test rather than a circular one. The 1–10 scale
/// is finer than the app's 1–5 rating grammar on purpose — rank correlation over a few dozen
/// days needs the resolution, and the different scale also makes it visibly not a wellness item.
///
/// **Grip strength (optional).** Maximal voluntary handgrip is a long-standing neuromuscular
/// readiness and central-fatigue marker, and unlike everything else here it is a *performance*
/// measurement rather than a physiological proxy — it cannot be talked into a better number by
/// optimism. Optional by design: it needs a dynamometer and the discipline to use it on waking.
/// Honest limits, recorded so nobody over-reads it later: single readings are noisy (best of
/// two or three attempts, same hand, same posture, is the standard protocol), and it indexes
/// neuromuscular readiness specifically, which overlaps with but is not the same as systemic
/// recovery.
///
/// ## Sync
///
/// Athlete-entered rather than raw HealthKit, so there is no privacy bar to syncing it — but
/// it is left local for now, matching the other shadow-era models. Add it to `SyncService`
/// deliberately if a second device ever needs it.
@Model
final class MorningReadinessProbe {

    /// `startOfDay` of the wake day this probe describes — one row per athlete per day.
    var date: Date = Date()

    /// The athlete's own readiness judgement, 1 (wrecked) – 10 (fully ready). Nil when the
    /// probe was skipped.
    var perceivedReadiness: Int?

    /// Best maximal handgrip in **kilograms**, canonical unit regardless of display preference.
    /// Nil whenever the athlete has no dynamometer or skipped it — which is the normal case.
    var gripStrengthKg: Double?

    /// Which hand produced `gripStrengthKg`. Grip differs meaningfully between dominant and
    /// non-dominant hands, so a series that silently switches hands is not a series at all.
    var gripHandRaw: String?

    /// How many attempts the reading is the best of. Protocol expects 2–3; recorded so a
    /// single-attempt day can be down-weighted rather than silently mixed in.
    var gripAttemptCount: Int?

    /// **True only when nothing scored had been shown yet that day.** The whole validity of
    /// this record rests on it, so it is stored rather than assumed: analysis filters to
    /// blinded rows, and an unblinded row is kept as data but must never count as evidence.
    var wasBlinded: Bool = false

    /// When the probe was actually answered — lets an analysis check it really was morning,
    /// and how far from waking.
    var capturedAt: Date = Date()

    var athlete: Athlete?

    init(
        date: Date,
        perceivedReadiness: Int? = nil,
        gripStrengthKg: Double? = nil,
        gripHandRaw: String? = nil,
        gripAttemptCount: Int? = nil,
        wasBlinded: Bool = false,
        capturedAt: Date = Date()
    ) {
        self.date = date
        self.perceivedReadiness = perceivedReadiness
        self.gripStrengthKg = gripStrengthKg
        self.gripHandRaw = gripHandRaw
        self.gripAttemptCount = gripAttemptCount
        self.wasBlinded = wasBlinded
        self.capturedAt = capturedAt
    }

    /// Which hand a grip reading came from.
    enum GripHand: String, CaseIterable, Identifiable {
        case right
        case left

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .right: String(localized: "probe.grip.hand.right", defaultValue: "Right")
            case .left: String(localized: "probe.grip.hand.left", defaultValue: "Left")
            }
        }
    }

    var gripHand: GripHand? {
        get { gripHandRaw.flatMap(GripHand.init(rawValue:)) }
        set { gripHandRaw = newValue?.rawValue }
    }

    /// Bounds for the readiness scale, published so the UI and the analysis cannot drift apart.
    static let readinessMin: Int = 1
    static let readinessMax: Int = 10

    /// Attempts the grip protocol expects a reading to be the best of.
    static let recommendedGripAttempts: Int = 3
}
