import Foundation

/// Phase 44 Plan 01 — the **state + decision layer** for the suggest-and-confirm verdict surface.
///
/// Pure value / decision logic (Foundation only — NO SwiftUI). It defines:
///  - `FeelOverride` — the athlete's first-class "how I actually feel" input (MOD-11).
///  - `VerdictAction` / `VerdictDecision` — the accept/keep/feel EVENT, shaped so Phase 45 logs it by
///    wiring a single closure (composite-only: kg + reason text, NEVER raw HealthKit).
///  - `TodayVerdictDisplay` — the pure value type the card (Plan 44-02) renders.
///  - `VerdictDecisionApplier` — static slot mutations that honor the autonomy invariants.

// MARK: - FeelOverride (MOD-11: the athlete's first-class feel input)

/// The athlete's own feel, a first-class LOGGED input that nudges (rough) or dismisses (strong) the
/// suggestion. Codable so Phase 45 can persist the decision verbatim.
enum FeelOverride: String, Codable, CaseIterable {
    case feelingStrong
    case feelingRough
}

// MARK: - VerdictAction / VerdictDecision (the Phase-45 loggable event)

/// What the athlete decided about today's suggestion.
enum VerdictAction: Equatable {
    case accepted
    case keptPlan
    case feel(FeelOverride)
}

/// The decision EVENT Phase 45 logs. Composite-only (kg + reason text; no raw HealthKit, no PII) and
/// `Equatable` so tests can assert the emitted action precisely.
struct VerdictDecision: Equatable {
    let action: VerdictAction
    let plannedTopSetKg: Double
    let adjustedTopSetKg: Double?
    /// True when the suggestion differed in ANY dimension (weight, RPE cap, or back-off volume) — not
    /// kg-only. Drives `VerdictEvent.differed` so volume-/RPE-only changes are honestly logged.
    let hadAdjustment: Bool
    let reasonLine: String
    let decidedAt: Date
    /// Structured non-weight context (additive; nil when not applicable) so a volume-/RPE-only
    /// adjustment is distinguishable in analytics without any raw biometric data.
    let suggestedBackoffSetCut: Int?
    let suggestedRPECap: Double?
}

// MARK: - PersistedVerdictDecisionState (the AUTHORITATIVE start-readiness source of truth)

/// The decision state reconstructed PURELY from the frozen prescription's persisted set markers
/// (`verdictAppliedAt` / `athleteOverrode`) — NOT from any transient session flag. This is what makes
/// an accepted/kept verdict survive a refresh, a tab revisit, or an app relaunch: a brand-new
/// `TodayVerdictViewModel` over the same store derives the identical state.
enum PersistedVerdictDecisionState: Equatable {
    /// No decision markers anywhere — the athlete has not decided. The only non-start-ready state.
    case pending
    /// At least one top set accepted its suggestion; none declined.
    case accepted
    /// At least one top set declined (keep-plan); none accepted.
    case keptPlan
    /// A legitimate mix (e.g. feeling-rough accepted a trim on one exercise, kept another) — an
    /// explicit completed decision, start-ready, never pending.
    case mixed
}

// MARK: - TodayVerdictDisplay (the pure value the card renders)

/// The presentational value type the verdict card (Plan 44-02) renders. No SwiftUI, no data logic —
/// the ViewModel builds it from the slots the Phase-43 service wrote.
struct TodayVerdictDisplay: Equatable {
    /// What the surface is leading with — never a bare readiness number.
    ///
    /// `.sessionCap` (v1.7.3 UAT round 3 · U25/U26) is the non-strength planned day: a run, a
    /// court session, conditioning. It leads with the day's DURATION and its RPE ceiling instead
    /// of a top-set weight, because those are the units that day actually has. Everything else
    /// about the surface — the reason line, the equal-weight Accept / Keep as planned pair, the
    /// nocebo guard — is identical.
    enum Kind { case adjusted, asPlanned, deferred, sessionCap }
    /// Whether the athlete has decided yet (drives the decision-row vs confirmed-line swap).
    enum AppliedState { case pending, accepted, keptPlan }

    /// The proposal's actual SHAPE (v1.7.3 feature 6, epic 9 — frozen S4 spec). Drives the
    /// accept cell's verb + sublabel so the two cells read as a choice between two concrete
    /// sessions: kg for load, sets for volume, percent as annotation.
    enum ProposalShape: Equatable {
        /// Nothing to decide — one "Got it" cell.
        case steady
        /// The top set eases ("Go 5% lighter · 132.5 kg"), possibly with a back-off cut riding.
        case loadTrim
        /// Load holds; back-off volume drops ("Cut the volume · top set + 1 back-off").
        case volumeCut
        /// Match-proximity cap ("Microdose today · 1 top set · ~20 min").
        case microdose
    }

    let headlineExerciseName: String
    let plannedTopSetKg: Double
    let adjustedTopSetKg: Double
    let hasAdjustment: Bool
    let reasonLine: String
    let kind: Kind
    let confidenceNote: String?
    let appliedState: AppliedState
    /// v2.1 (ADR-0002): the adjustment is a match-proximity MICRODOSE — the card swaps its modify
    /// framing to "Microdose" (vocabulary only; the numbers/logic are already in the fields above).
    var isMicrodose: Bool = false

    // MARK: Proposal shape (epic 9)

    /// The suggestion's structured back-off cut (0 = none).
    var backoffSetCut: Int = 0
    /// Working (non-warmup) sets on the headline exercise — the "ALL 4 SETS" number.
    var workingSetCount: Int = 0

    // MARK: Session cap (v1.7.3 UAT round 3 · U25 / U26)

    /// Today's cap for a non-strength planned day. Non-nil exactly when `kind == .sessionCap`.
    /// A pure value recomputed every refresh — no `@Model` carries it, so nothing about the
    /// synced schema changed to make this surface exist.
    var sessionCap: SessionCapEngine.SessionCap? = nil
    /// The plan's own duration in seconds, so the card can say "your 90-minute run, capped at 60".
    /// nil when the plan wrote no duration — the card then states the RPE ceiling alone.
    var plannedDurationSeconds: Int? = nil
    /// The plan's own RPE target, when it wrote one.
    var plannedSessionRPE: Double? = nil

    /// The plan's duration in whole minutes.
    var plannedDurationMinutes: Int? { plannedDurationSeconds.map { $0 / 60 } }

    /// True when the cap actually pulls the day in — the surfaces show the equal-weight
    /// Accept / Keep as planned pair only then, and a single acknowledge otherwise.
    var capModulatesPlan: Bool { sessionCap?.modulatesPlan ?? false }

    /// Derived shape per the frozen S4 spec. Order matters: microdose outranks the others;
    /// a real load ease reads as a load trim (any cut rides in the sublabel); a cut with no
    /// load ease is a volume day; anything else — including an RPE-cap-only nudge, which has
    /// no set-shape of its own — falls back to the load-trim voice via `hasAdjustment`.
    var shape: ProposalShape {
        guard kind == .adjusted, hasAdjustment else { return .steady }
        if isMicrodose { return .microdose }
        if adjustedTopSetKg < plannedTopSetKg - 0.001 { return .loadTrim }
        if backoffSetCut > 0 { return .volumeCut }
        return .loadTrim
    }

    /// The load ease as a whole percent (annotation voice), nil when load is unchanged.
    var loadTrimPercent: Int? {
        guard plannedTopSetKg > 0, adjustedTopSetKg < plannedTopSetKg - 0.001 else { return nil }
        let percent = Int(((plannedTopSetKg - adjustedTopSetKg) / plannedTopSetKg * 100).rounded())
        return max(percent, 1)
    }
}

// MARK: - TodayBriefReadings (what today looks like — readings only)

/// The pure readings block the pre-session brief opens with (v1.7.3 UAT round 3 · U25).
///
/// Nothing here is a recommendation: it is the evidence the day's verdict was built on, stated
/// once so the athlete can see WHY before they see WHAT. Assembled by `TodayVerdictViewModel`
/// from the exact inputs it already gathers for the verdict — no second fetch, no second engine,
/// and no number that is not already on the Today surface.
///
/// Composite + already-displayed values only. Raw HealthKit never leaves the device and never
/// reaches a log; these three signals are the same ones `MetricsStrip` prints.
struct TodayBriefReadings: Equatable {
    /// 0…100 readiness and its zone, or nil while the baseline is still learning.
    let readinessScore: Int?
    let readinessZone: ReadinessZone?
    let fatigueIndex: Double?
    let fatigueZone: FatigueIndexEngine.FatigueZone?
    /// Today's HRV in ms beside the personal baseline the snapshot carries.
    let hrvMs: Double?
    let hrvBaselineMs: Double?
    let rhrBpm: Double?
    let rhrBaselineBpm: Double?
    let sleepMinutes: Double?
    /// The plain 14-day mean of the athlete's own sleep series — a descriptive statistic,
    /// labelled as such, not a second baseline engine.
    let sleepRecentMeanMinutes: Double?
    /// Calendar days to the next scheduled match; nil when none is scheduled or it has passed.
    let matchDaysAway: Int?
    /// True while the readiness build deferred (cold start) — the brief then says so plainly
    /// rather than printing a number it does not have.
    let isLearning: Bool
}

// MARK: - BriefExerciseLine (your numbers — planned → adjusted, per movement)

/// One movement's line in the pre-session brief's "Your numbers" block (v1.7.3 UAT round 3 · U25).
///
/// It states the athlete's OWN planned number first and the suggestion beside it, so the brief
/// reads as a modulation of their session rather than a session handed to them. Every field is
/// read from the frozen prescription — nothing is recomputed and nothing is written.
struct BriefExerciseLine: Identifiable, Equatable {
    /// The authored `TemplateExercise` id (stable across refreshes).
    let id: UUID
    let exerciseName: String
    let plannedTopSetKg: Double?
    /// The verdict's suggested top-set weight, or nil when it suggested none.
    let suggestedTopSetKg: Double?
    let plannedWorkingSets: Int
    /// Working sets left after an accepted-or-suggested back-off cut.
    let suggestedWorkingSets: Int
    let plannedRPE: Double?
    /// The suggested RPE ceiling, only ever present when the plan wrote an RPE (the NIL-RPE rule).
    let suggestedRPE: Double?

    /// True when any of the three dimensions actually moved — the brief marks only those.
    var hasChange: Bool {
        if let planned = plannedTopSetKg, let suggested = suggestedTopSetKg,
           suggested < planned - 0.001 { return true }
        if let planned = plannedRPE, let suggested = suggestedRPE,
           suggested < planned - 0.001 { return true }
        return suggestedWorkingSets < plannedWorkingSets
    }
}

// MARK: - VerdictDecisionApplier (slot mutations only — the autonomy invariant)

/// Pure static mutations on a FROZEN-prescription `TemplateSet`. These write ONLY the two Phase-44
/// slots (`verdictAppliedAt` / `athleteOverrode`).
///
/// WHY the authored `targetWeightKg` is never written: SC1 requires the surface "never silently
/// overwrites the planned numbers." The number the athlete actually trains is resolved at READ time
/// (`effectiveTargetKg`) from the accept marker — so the authored plan stays intact and a keep-plan is
/// the non-destructive reverse of an accept (SC3). `adjustedTargetWeightKg` (the Phase-43 suggestion)
/// is likewise read-only here. The applier only ever receives a frozen `PrescribedWorkout` working
/// set; the source authored `WorkoutTemplate` is never in scope and is provably never mutated.
enum VerdictDecisionApplier {

    /// ACCEPT the suggestion: mark it applied. Reads resolve to the adjusted number from now on.
    /// Never writes `targetWeightKg` / `adjustedTargetWeightKg`.
    static func applyAccept(to topSet: TemplateSet, appliedAt: Date = .now) {
        topSet.verdictAppliedAt = appliedAt
        topSet.athleteOverrode = false
    }

    /// KEEP-MY-PLAN (decline): record the decline; leave the planned number untouched. The
    /// non-destructive reverse of accept — clears any accept marker.
    static func applyKeepPlan(to topSet: TemplateSet) {
        topSet.athleteOverrode = true
        topSet.verdictAppliedAt = nil
    }

    /// The number the athlete trains, resolved at read time: the adjusted suggestion ONLY once
    /// accepted, otherwise the authored planned number (the plan wins until explicitly accepted).
    static func effectiveTargetKg(_ topSet: TemplateSet) -> Double? {
        if topSet.verdictAppliedAt != nil {
            return topSet.adjustedTargetWeightKg ?? topSet.targetWeightKg
        }
        return topSet.targetWeightKg
    }

    /// The RPE the athlete trains, resolved at read time with the SAME accept/keep semantics as
    /// `effectiveTargetKg`: the accepted adjusted RPE cap ONLY once accepted, otherwise the authored
    /// planned RPE. Because the service only ever writes `adjustedTargetRPE` when a planned RPE existed
    /// (the NIL-RPE rule), an accepted set with no authored RPE resolves to nil — a bare RPE cap is
    /// never fabricated. Keep-plan / pending always resolve to the authored `targetRPE`.
    static func effectiveTargetRPE(_ topSet: TemplateSet) -> Double? {
        if topSet.verdictAppliedAt != nil {
            return topSet.adjustedTargetRPE ?? topSet.targetRPE
        }
        return topSet.targetRPE
    }

    /// The number of back-off sets to omit, resolved at read time: the structured cut ONLY once
    /// accepted, otherwise nil. Mirrors the weight/RPE accept semantics.
    static func effectiveBackoffSetCut(_ topSet: TemplateSet) -> Int? {
        guard topSet.verdictAppliedAt != nil, let cut = topSet.adjustedBackoffSetCut, cut > 0 else { return nil }
        return cut
    }

    /// The ONE canonical "is there a real suggestion?" predicate — semantic, NOT kilogram-only. True
    /// when the verdict differs from the authored plan in ANY executable dimension: a meaningfully
    /// lower weight, a meaningfully lower RPE cap, or a positive back-off-set cut. Used everywhere
    /// (display kind, feel-rough acceptance, decision `hadAdjustment`, event `differed`) so a
    /// volume-only or RPE-only recommendation is never misread as "as planned."
    static func hasSuggestion(_ topSet: TemplateSet) -> Bool {
        if let planned = topSet.targetWeightKg,
           let adjusted = topSet.adjustedTargetWeightKg,
           adjusted < planned - 0.001 {
            return true
        }
        if let plannedRPE = topSet.targetRPE,
           let adjustedRPE = topSet.adjustedTargetRPE,
           adjustedRPE < plannedRPE - 0.001 {
            return true
        }
        if let cut = topSet.adjustedBackoffSetCut, cut > 0 {
            return true
        }
        return false
    }

    /// Reconstruct the decision state from the persisted per-exercise top-set markers — the
    /// AUTHORITATIVE start-readiness source (survives refresh/relaunch). `accepted` ⇒ some top set
    /// has `verdictAppliedAt`; `keptPlan` ⇒ some top set `athleteOverrode`; both ⇒ `mixed`; neither ⇒
    /// `pending`. Only `pending` is non-start-ready.
    static func persistedDecisionState(forTopSets topSets: [TemplateSet]) -> PersistedVerdictDecisionState {
        guard !topSets.isEmpty else { return .pending }
        let anyAccepted = topSets.contains { $0.verdictAppliedAt != nil }
        let anyKept = topSets.contains { $0.athleteOverrode }
        switch (anyAccepted, anyKept) {
        case (false, false): return .pending
        case (true, false):  return .accepted
        case (false, true):  return .keptPlan
        case (true, true):   return .mixed
        }
    }
}
