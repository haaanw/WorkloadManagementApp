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
    let hadAdjustment: Bool
    let reasonLine: String
    let decidedAt: Date
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
}
