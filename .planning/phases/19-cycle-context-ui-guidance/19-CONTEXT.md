# Phase 19: Cycle Context UI & Guidance - Context

**Gathered:** 2026-05-29
**Status:** Ready for planning
**Mode:** Full-auto (ambiguities resolved against ROADMAP success criteria + Cross-AI consensus + DESIGN.md + verified code)

<domain>
## Phase Boundary

Surface the cycle awareness built in Phases 17-18 to the user as **context and explanations** — never deterministic overrides. Three observable surfaces:

1. **Dashboard cycle day/phase indicator** — unobtrusive, opt-in, invisible without HealthKit menstrual permission.
2. **Recovery card phase context** — a readiness-first explanatory line ("You're in your luteal phase — lower HRV and higher heart rate are expected") shown only when cycle data is high-confidence and influences interpretation.
3. **Guidance prompts** — (a) cycle-aware fueling/recovery tips (avoid fasted hard workouts, post-training protein within 45 min, luteal heat-sensitivity hydration/cooling) per Dr. Sims, and (b) a RED-S monitoring alert (3+ consecutive missed periods OR cycle length >35 days consistently) with clinician-referral, non-diagnostic language and full exclusion handling.

**UI + read-only derivation only.** No new algorithm modifiers (those are Phase 20 shadow mode). No new sync payload. No raw menstrual data leaves the device. The engine math from Phase 18 is unchanged — Phase 19 only *reads* the already-computed `CycleContext` / `MenstrualCycleSnapshot` and renders text.

This phase delivers CYCLE-06 (dashboard indicator + recovery-card context), CYCLE-07 (fueling/recovery prompts), CYCLE-08 (RED-S monitoring).
</domain>

<requirements>
## Requirements (CYCLE-06 / CYCLE-07 / CYCLE-08)

These IDs appear in ROADMAP.md Phase 19 but were never written into `.planning/REQUIREMENTS.md` (its Traceability table stops at v1.3 / LLM-06). The v1.4 requirements live only in the ROADMAP success criteria + the research doc §9.8/§9.9. Derived definitions for this phase, traced to ROADMAP Phase 19 success criteria (SC1-SC6) and research §9.8-§9.9:

- **CYCLE-06 — Cycle context surfacing (read-only):**
  - SC1: Dashboard shows an unobtrusive cycle day/phase indicator when cycle data is available (opt-in HealthKit menstrual permission).
  - SC2: Recovery card includes phase context when the cycle influences interpretation (e.g. "You're in your luteal phase — lower HRV and higher heart rate are expected").
  - SC5: Cycle context is always readiness-first — never "deload because luteal."
  - SC6: All cycle UI is 100% optional and invisible when HealthKit menstrual permission is not granted (no `MenstrualCycleSnapshot` rows).

- **CYCLE-07 — Cycle-aware fueling & recovery prompts (Dr. Sims):**
  - SC3: Suggest avoiding fasted hard workouts; post-training protein within 45 min; hydration/cooling in the luteal heat-sensitivity window.
  - SC5 applies: framed as supportive context, never a training override.

- **CYCLE-08 — RED-S monitoring (safety, non-diagnostic):**
  - SC4: Alert when 3+ consecutive missed periods OR cycle length >35 days consistently, with clinician-referral language and exclusion handling (pregnancy, OC, perimenopause, PCOS).
  - Research §9.8: never diagnose — only surface the pattern; copy: "Your cycle patterns have changed. This can sometimes indicate your body needs more fuel or recovery. Consider speaking with a healthcare provider."

**Action item for the executor of Plan 01:** add CYCLE-06/07/08 (and retroactively CYCLE-01..05) to `.planning/REQUIREMENTS.md` Traceability so coverage is closed. (Documentation-only; does not block UI work.)
</requirements>

<decisions>
## Implementation Decisions

### Visibility & opt-in gating (CYCLE-06 SC6 — the hard constraint)
- **D-01:** Every cycle UI element is gated on the SAME condition the existing Phase 17 soft-prompt uses inverted: visible only when `!cycleSnapshots.isEmpty` AND today's snapshot carries a usable phase. No `MenstrualCycleSnapshot` rows = no HealthKit menstrual permission granted (the snapshot is only ever written by `CycleTrackingService` after a successful HealthKit read) = render nothing. This is the single source of truth for "data available" and requires no new permission API. Confirmed against `DashboardView.showCyclePrompt` (`cycleSnapshots.isEmpty`) and `ProfileView.showCycleSection`.
- **D-02:** Indicator/context use the **latest** `MenstrualCycleSnapshot` (today's, or most-recent if today's not yet computed), read via a `@Query` mirroring the existing `@Query private var cycleSnapshots: [MenstrualCycleSnapshot]` already in DashboardView. No new repository needed for display (CycleSnapshotRepository from Phase 18 exists for the pipeline join; views use `@Query` per project convention).

### Confidence gating for the explanatory context (CYCLE-06 SC2)
- **D-03:** The recovery-card phase-context line and the dashboard indicator's phase label render only when `snapshot.confidence >= 0.7 && snapshot.estimatedPhase != nil && estimatedPhase != .unknown && !hasExclusion`. This mirrors the Phase 18 engine gate (D-04: `confidence >= 0.7 && !hasExclusion && phase != .unknown`) so the *explanation* and the *baseline correction* are consistent — we never tell the user "luteal explains your HRV" in a state where the engine did NOT actually apply the same-phase baseline. Below the gate: show cycle **day** only (a neutral fact), no phase interpretation. Exclusion is derived from the snapshot's `isOnHormonalContraceptive / isPregnant / isLactating` flags (which `CycleTrackingService` already stamps).
- **D-04:** OC users (`isOnHormonalContraceptive == true`): show cycle day if present, but NEVER phase-based interpretation or fueling-by-phase prompts — their phase is `.unknown` by design (CycleTrackingService line 62-63) so D-03 already excludes them. RED-S monitoring is also suppressed for OC users (a suppressed/absent bleed on OC is expected, not a RED-S signal).

### Phase-context copy (CYCLE-06 SC2, SC5 — readiness-first framing)
- **D-05:** Copy is **explanatory, never prescriptive**. Per-bucket templates (2-bucket model from Phase 18 D-01: follicular vs luteal), keyed to the 5-phase enum for nuance:
  - Luteal (earlyLuteal / lateLuteal): "You're in your luteal phase — lower HRV and a higher resting heart rate are expected here. Your readiness score already accounts for this."
  - Follicular (earlyFollicular / lateFollicular / ovulatory): "You're in your follicular phase — HRV and recovery markers tend to run higher. Your readiness score reflects your own same-phase normal."
  - The clause "Your readiness score already accounts for this" is the explicit readiness-first anchor: cycle explains the *number*, it does not change the *recommendation*. NEVER emit "deload", "rest because luteal", "go hard because follicular", etc. (SC5).
- **D-06:** The phase-context line lives **inside `RecoveryScoreCard`** (RecoveryView) as a new optional bottom row, and a one-line condensed variant attaches to the dashboard indicator. The hero readiness card on the Dashboard is NOT modified beyond the small indicator (keeps the accent-on-hero-number rule clean and the hero card uncluttered).

### Dashboard indicator placement & form (CYCLE-06 SC1)
- **D-07:** A compact `CycleStatusStrip` row placed directly under the existing soft-prompt region / above `MetricsStrip`. Form: micro-caps label "CYCLE" + "Day N" + phase displayName (only when D-03 gate passes; otherwise day only). Styled exactly like `MetricStripCell` (micro label + value), flat `ColorTokens.surface`, 0.5pt divider, NO accent color, NO icon emphasis. It reuses the established strip vocabulary so it reads as one more instrument metric, not an alert.

### Fueling / recovery prompts (CYCLE-07)
- **D-08:** A single `CycleFuelingCard` rendered on the **Recovery tab** (not Dashboard — Dashboard stays a reading, per DESIGN.md "the dashboard is a reading, not a data dump"; fueling guidance is recovery-domain content). Shown only when D-03 gate passes. Content is phase-bucket-specific, evidence-tagged to Dr. Sims (research §9.4 evolved position, §6.2, §9.9):
  - Always (both buckets): "Avoid hard sessions fasted — fuel before high-intensity work." + "Aim for protein within ~45 minutes after training."
  - Luteal-only additional: "You may run warmer this phase — prioritize hydration and cooling during hard efforts." (research §2 thermoregulation, §6.2 luteal) + "A little extra protein and complex carbs can offset luteal-phase catabolism."
- **D-09:** Prompts are **suggestions, not commands**, and never reference training prescription (volume/intensity). They use the same flat-card pattern as `InsightCard` / `FatigueAttentionBanner`. No "you must"; phrasing is "Aim for…", "Consider…", "You may…".

### RED-S monitoring (CYCLE-08 — safety, evidence-gated, non-diagnostic)
- **D-10:** New **pure** detector `REDSRiskEngine` (struct, static methods — matches engine convention) that classifies cycle history into `.none` / `.monitor` from `MenstrualCycleSnapshot` history. Trigger logic (research §9.8):
  - **Missed-period rule:** 3+ consecutive expected-but-absent cycle starts. Operationalized as: from the most recent cycle start, days elapsed without a new `isCycleStart` ≥ `3 × medianCycleLength` (clamped to a sane floor, e.g. ≥ 90 days of no detected start while data is otherwise present). Approximation noted in D-14.
  - **Long-cycle rule:** the 3 most recent computed cycle lengths all > 35 days (consistently oligomenorrheic), reusing the cycle-length computation already in `CycleTrackingService`.
- **D-11:** **Exclusions (hard gate, evaluated first):** suppress entirely if `isPregnant || isLactating || isOnHormonalContraceptive`. Perimenopause and PCOS: there is **no model field** for these (verified — `Athlete` has only the three flags). Resolve by adding them as the next decision item rather than blocking:
  - **D-11a:** Add two opt-in profile flags `hasPCOS: Bool?` and `isPerimenopausal: Bool?` to the `Athlete` model (local-only, NOT synced — consistent with Phase 18 CR-01 which removed reproductive flags from sync), surfaced as toggles in the existing ProfileView "Cycle & Hormones" section. When either is set, RED-S monitoring is suppressed (irregular cycles are expected with PCOS/perimenopause and a RED-S alert would be a false alarm). This keeps the exclusion handling the ROADMAP SC4 explicitly requires.
- **D-12:** **Non-diagnostic copy (locked):** title "Cycle pattern change", body uses the research §9.8 wording: "Your cycle patterns have changed recently. This can sometimes mean your body needs more fuel or recovery. It may be worth speaking with a healthcare provider." NEVER the words "RED-S", "amenorrhea", "diagnosis", "disorder", or any risk score shown to the user. The internal type may be named REDSRiskEngine; user-facing text never names it.
- **D-13:** RED-S alert surfaces as a dismissible flat banner on the **Recovery tab** (top, above the score card) — recovery/health domain, and avoids alarming the Dashboard hero area. Dismiss persists via `@AppStorage` keyed to a coarse period (e.g. month) so it can re-surface if the pattern persists across cycles, but does not nag daily. Optional colored left border = `ColorTokens.zoneCaution` (caution, not danger — this is a "consider checking", not an emergency), with the zone communicated through the text label too (DESIGN.md rule 5).

### Engine placement & gating discipline (Phase 20 boundary)
- **D-14:** `REDSRiskEngine` is the ONLY new engine. It is pure (no HealthKit/SwiftData) — the view/viewmodel passes it plain arrays of cycle-start dates + lengths + median, derived from `@Query`'d snapshots. It produces a *display state*, never a training modifier. No `AutoregulationEngine`, `FatigueIndexEngine`, or `ProgressionEngine` changes (those are Phase 20 shadow-mode, explicitly deferred by Cross-AI consensus). Acknowledged approximation: HealthKit gives detected period dates, not "user expected a period and it didn't come"; the 3×median-length heuristic is the best available proxy and is intentionally conservative (long threshold) to minimize false positives on a safety-adjacent feature.
- **D-15:** Localization: ALL new user-facing strings are added as keys to `WorkloadApp/Resources/Localizable.xcstrings` (project is bilingual EN + zh-Hans since Phase 23). New views must use localized keys + `Font.Tokens.*`, never literals. zh-Hans translations for the new keys are added in the same change (mirrors Phase 23-06 sweep expectation).

### Scope locks (from ROADMAP success criteria / Cross-AI consensus — not re-decided)
- Readiness-first only; cycle is context/explanation (SC5; Sims evolved position §9.4). No deterministic training override anywhere.
- 100% opt-in / invisible without permission (SC6).
- No new Supabase sync fields; no raw menstrual data off-device (Phase 17 D-12, Phase 18 CR-01).
- Engine modifiers (Autoreg/Fatigue/Progression cycle awareness) are Phase 20, NOT here.

### Claude's Discretion (for planner/executor)
- Exact split of work across the 3 plans (proposed below).
- Whether the dashboard condensed phase-context attaches to the indicator strip or is omitted on Dashboard (Recovery card carries the full line regardless).
- Helper location for bucket→copy mapping (a `CyclePhase` extension vs a small `CycleCopy` enum) — prefer a `CyclePhase` extension for displayName-adjacent context strings, consistent with the enum already owning `displayName`.
- Exact `@AppStorage` key/period for RED-S dismissal.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Research
- `.planning/research/female-athlete-optimization-research.md` — §2 (luteal thermoregulation), §6.2 (phase guidelines — guidelines NOT prescriptions), §9.4 (Sims evolved "train by readiness"), §9.8 (RED-S triggers + non-diagnostic copy), §9.9 (UI considerations: opt-in, indicator, phase-context-in-recovery-card copy)

### Phase 17/18 Foundation (depends on)
- `WorkloadApp/Models/MenstrualCycleSnapshot.swift` — `@Model MenstrualCycleSnapshot` (date, cycleDay, estimatedPhase: CyclePhase?, confidence, cycleLength, isCycleStart, isOnHormonalContraceptive/isPregnant/isLactating) AND `struct CycleContext` (phase, confidence, cycleDay, cycleLength, exclusion flags, `hasExclusion`, `.none`). Local-only.
- `WorkloadApp/Models/Enums.swift` §`CyclePhase` (line 380) — 5 cases + `.unknown`, has `displayName` (localized).
- `WorkloadApp/Services/CycleTrackingService.swift` — produces snapshots + `CycleContext`; `computeCycleLengths` / `detectCycleStarts` / `median` logic to mirror for RED-S; OC → phase `.unknown` (line 62).
- `WorkloadApp/Repositories/CycleSnapshotRepository.swift` — `fetchCycleSnapshots(days:athlete:)` (exists; available if a viewmodel prefers it over `@Query`).

### Existing UI to modify / mirror
- `WorkloadApp/Views/Dashboard/DashboardView.swift` — existing soft-prompt block (lines 65-105) shows the established opt-in pattern + flat-card styling; `@Query cycleSnapshots` (line 24); insertion point for `CycleStatusStrip` is just above `MetricsStrip` (line 109).
- `WorkloadApp/Views/Recovery/RecoveryView.swift` — `RecoveryScoreCard` (line 231) gets the phase-context row; top of `body` (line 38) gets the RED-S banner + fueling card.
- `WorkloadApp/Views/Profile/ProfileView.swift` — "Cycle & Hormones" section (lines 93-153) gets the PCOS / perimenopause toggles.
- `WorkloadApp/Components/FatigueAttentionBanner.swift` — EXACT template for the RED-S banner (flat surface, 2pt colored left border, micro-caps label, no shadow/radius).
- `WorkloadApp/Components/MetricTile.swift` / `MetricStripCell` (in DashboardView) — template for the cycle indicator cell.
- `WorkloadApp/Views/Recovery/InsightCard.swift` — template for the fueling card.
- `WorkloadApp/Components/ZoneBadge.swift` — reusable label-with-color badge.

### Data / model
- `WorkloadApp/Models/Athlete.swift` (lines 21-23) — existing `isOnHormonalContraceptive / isPregnant / isLactating: Bool?`; gets additive `hasPCOS / isPerimenopausal: Bool?` (D-11a), local-only.
- `WorkloadApp/Resources/Localizable.xcstrings` — all new strings (EN + zh-Hans). `InfoPlist.xcstrings` unchanged.

### Sync / privacy guardrail (do NOT cross)
- Phase 18 `18-VERIFICATION.md` CR-01: reproductive flags were REMOVED from `AthleteRow` / `pushAthlete` / `pullAthlete`. New `hasPCOS`/`isPerimenopausal` MUST NOT be added to any sync payload. `MenstrualCycleSnapshot` stays local-only.

### Requirements
- ROADMAP.md Phase 19 — CYCLE-06/07/08; 6 success criteria (the WHAT, locked).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `FatigueAttentionBanner` — flat banner with colored left border + micro-caps label + secondary message. Copy its exact structure for the RED-S banner; only swap copy + caution color.
- `MetricStripCell` (DashboardView) — micro-caps label + value cell, flat surface. Template for the cycle indicator.
- `InsightCard` — flat informational card. Template for the fueling card.
- `ZoneBadge` — label+color badge. Reusable for any zone-coded chip.
- `CyclePhase.displayName` — already localized; extend the enum with context-copy helpers.
- `CycleTrackingService.computeCycleLengths / detectCycleStarts / median / coefficientOfVariation` — the math the RED-S engine mirrors (keep RED-S pure; pass arrays in).

### Established Patterns
- Views read SwiftData via `@Query`; current athlete = `athletes.first`. Opt-in gating already done by checking `cycleSnapshots.isEmpty`.
- Engines are pure structs with static methods (no I/O). `REDSRiskEngine` follows this exactly.
- All UI: `ColorTokens` semantic tokens, `Font.Tokens.*`, `Rectangle()` not `RoundedRectangle`, no `.shadow()`, 8pt spacing, localized string keys.
- Flat-card recipe (seen throughout): `.padding(16/24) + .background(ColorTokens.surface) + .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))`.

### Integration Points
- Dashboard: insert `CycleStatusStrip` above `MetricsStrip` (DashboardView line 109), gated by D-01/D-03.
- Recovery: `RecoveryScoreCard` gains an optional phase-context row; `RecoveryView.body` top gains RED-S banner + fueling card.
- Profile: two toggles appended to the existing "Cycle & Hormones" section.
- No ViewModel orchestration strictly required for display (views can read `@Query` snapshots directly + call the pure `REDSRiskEngine`), but a small `CycleContextViewModel` or computed helpers may be used for testability — planner's choice; keep it `@MainActor @Observable` if used.
</code_context>

<specifics>
## Specific Ideas
- Exact recovery-card line (research §9.9 verbatim seed): "You're in your luteal phase — lower HRV and higher heart rate are expected during this phase." Augmented with the readiness anchor (D-05).
- Exact RED-S body (research §9.8 verbatim): "Your cycle patterns have changed recently. This can sometimes mean your body needs more fuel or recovery. It may be worth speaking with a healthcare provider."
- Worked validation cases for RED-S engine:
  - 3 most-recent cycle lengths [38, 41, 37] → `.monitor` (long-cycle rule).
  - No `isCycleStart` for ≥ 3×28 days while snapshots exist → `.monitor` (missed-period rule).
  - Same patterns but `isOnHormonalContraceptive == true` → `.none` (exclusion).
  - `hasPCOS == true` with long cycles → `.none` (exclusion).
  - Regular ~28-day cycles → `.none`.
</specifics>

<deferred>
## Deferred Ideas
- AutoregulationEngine / FatigueIndexEngine / ProgressionEngine cycle-phase awareness → **Phase 20 (shadow mode)**, per Cross-AI consensus (defer modifiers pending shadow-mode validation).
- Contextual ACWR phrasing on the load section (research §9.5) → Phase 20 (it is interpretation of a training metric, borderline modifier territory; keep Phase 19 to recovery/fueling/safety context).
- Stamping cycle day onto WorkoutSession for historical analysis (research §9.7) → Phase 20 (analytics substrate for shadow mode).
</deferred>

## Assumptions (full-auto) — every ambiguity resolved

| # | Ambiguity | Resolution | Basis |
|---|-----------|------------|-------|
| A-1 | CYCLE-06/07/08 are not defined in REQUIREMENTS.md | Derived definitions from ROADMAP Phase 19 SC1-SC6 + research §9.8-§9.9; Plan 01 adds them to the Traceability table | ROADMAP is the authoritative WHAT; REQUIREMENTS.md simply was never updated past v1.3 |
| A-2 | "100% optional / invisible" needs a concrete signal | Gate all cycle UI on `!cycleSnapshots.isEmpty` (+ confidence/exclusion for interpretive text) — snapshots only exist after a successful HealthKit menstrual read | SC6; mirrors existing `DashboardView.showCyclePrompt` / `ProfileView.showCycleSection` |
| A-3 | When exactly to show the phase *interpretation* vs just cycle day | Interpretation only when `confidence >= 0.7 && phase != .unknown && !hasExclusion` (matches Phase 18 engine gate); else day-only | Consistency between explanation and the baseline correction actually applied (Phase 18 D-04); prevents misleading copy |
| A-4 | ROADMAP SC4 requires perimenopause & PCOS exclusions but no model field exists | Add additive local-only `hasPCOS` / `isPerimenopausal: Bool?` to Athlete + Profile toggles; suppress RED-S when set | Verified `Athlete` lacks these; SC4 explicitly lists them; additive + non-synced respects Phase 18 CR-01 |
| A-5 | "3+ consecutive missed periods" is not directly observable from HealthKit | Proxy: days since last `isCycleStart` ≥ 3×median cycle length (conservative floor) while snapshot data otherwise present | HealthKit yields detected period dates, not "expected but absent"; research §9.8 intent; conservative to avoid false positives on a safety feature |
| A-6 | Where fueling prompts + RED-S alert live (Dashboard vs Recovery) | Both on the Recovery tab; Dashboard gets only the unobtrusive indicator | DESIGN.md "dashboard is a reading, not a data dump"; fueling/health is recovery-domain; keeps hero/accent rules clean |
| A-7 | RED-S severity color | `ColorTokens.zoneCaution` + always a text label, never color-only | DESIGN.md rule 5; it's "consider checking", not danger; non-alarmist (research §9.8) |
| A-8 | Plan count | Keep ROADMAP's 3 plans, re-scoped: (1) data/engine/copy foundation, (2) Dashboard + Recovery context surfaces, (3) fueling + RED-S guidance | Clean dependency wave: Plan 1 has no UI, Plans 2/3 depend on its types; matches Phase 17/18 "types first, UI later" rhythm |
| A-9 | New strings + zh-Hans | Add all keys to Localizable.xcstrings with EN + zh-Hans in the same change | Project bilingual since Phase 23; convention enforced (no literals, `Font.Tokens.*`) |
| A-10 | Do views need a ViewModel? | Display can read `@Query` + call pure engine directly; a thin `@Observable` helper is optional for RED-S testability | Project convention allows `@Query` reads in views; engines stay pure & unit-testable independent of UI |

---

*Phase: 19-cycle-context-ui-guidance*
*Context gathered: 2026-05-29 (full-auto)*
