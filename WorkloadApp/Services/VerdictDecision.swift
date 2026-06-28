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
    enum Kind { case adjusted, asPlanned, deferred }
    /// Whether the athlete has decided yet (drives the decision-row vs confirmed-line swap).
    enum AppliedState { case pending, accepted, keptPlan }

    let headlineExerciseName: String
    let plannedTopSetKg: Double
    let adjustedTopSetKg: Double
    let hasAdjustment: Bool
    let reasonLine: String
    let kind: Kind
    let confidenceNote: String?
    let appliedState: AppliedState
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
