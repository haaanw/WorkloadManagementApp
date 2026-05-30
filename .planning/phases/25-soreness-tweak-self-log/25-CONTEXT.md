# Phase 25: Soreness / Tweak Self-Log - Context

**Gathered:** 2026-05-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a **dedicated, optional pain/soreness/niggle self-log** (new local-only
SwiftData model + minimal UI) so the future Strain-Risk channel (Phase 27) can be
validated against *real localized breakdown* rather than whole-body daily soreness.
**And** wire the already-existing wellness history + a derived injury count into the
dashboard fatigue path, which currently passes hardcoded `0` / `nil` / empty
(`DashboardViewModel.swift:236` `recentWellnessScores: []`, `:252` `softTissueInjuryCount: 0`,
`daysSinceLastInjury: nil`).

**In scope:** new niggle-log model + entry UI; feeding a new graded validation outcome
into the Phase 24 shadow contract; deriving fatigue-engine injury inputs from logged
niggles; fetching wellness-score history into the fatigue input.

**Out of scope (own phases):** the Strain-Risk model itself (Phase 27), individualized
baselines (Phase 26), readiness fusion / ACWR demotion (Phase 28), any live activation
(Phase 29). No physiotherapy/diagnosis UX. No injury *prediction* claims — honest
"load-tolerance context" framing only. Niggle log NEVER syncs to Supabase.
</domain>

<decisions>
## Implementation Decisions

### Niggle log granularity (Area 1)
- **D-01:** New dedicated local-only `@Model` (working name `SorenessLog` / niggle entry).
  This is DISTINCT from the existing whole-body daily `WellnessCheckIn.soreness` (1–5),
  which stays untouched and keeps feeding the existing `.pain` outcome.
- **D-02:** One entry captures: **body region** (aligned to the existing muscle taxonomy
  from Phase 22), **type** ∈ {soreness, pain, tweak}, **severity 0–10**, **"limited
  training?" flag** (Bool), **optional note** (String?). Plus `id`, `date`/timestamp,
  `athlete` inverse relationship.
- **D-03:** The "limited training?" flag is the load-bearing functional-impact signal that
  separates a real niggle from routine DOMS — it is required (default No), not optional.

### Validation outcome label (Area 2)
- **D-04:** Add ONE new graded outcome to `ShadowPredictor.Outcome` (working name
  `.niggleSeverity`): **max niggle severity (0–10) logged within the outcome window, 0 if
  none.** Dense, degrades gracefully on sparse consumer data, and plugs directly into the
  Phase 24 `ShadowMetrics` MAE/Spearman/calibration surface.
- **D-05:** Do NOT touch the existing `.pain` (whole-body 1–5) outcome. Do NOT add a binary
  breakdown-event outcome in v1 (rare-positive → unstable CI/calibration; deferred).
- **D-06:** Actual-label resolution must respect the Phase 24 date contract
  (predictionDate/targetDate/outcome-window, no same-day leak) — mirror how
  `ShadowAnalyticsService` resolves `painActual` from `WellnessCheckIn.soreness`.

### Entry point / friction (Area 3)
- **D-07:** Primary entry = an **on-demand "Log a niggle" affordance on the Dashboard**.
  No daily nag.
- **D-08:** Secondary = a **non-blocking optional prompt after saving a workout**
  ("anything bother you?") — the highest-signal capture window for training tweaks.
  Must be dismissible/skippable; never blocks the save flow.
- **D-09:** Do NOT fold niggle logging into the once-daily MorningCheckInSheet ritual.

### Injury-count wiring (Area 4)
- **D-10:** Derive `softTissueInjuryCount` = count of **distinct active niggles where
  type ∈ {pain, tweak} AND (limited-training=Yes OR severity ≥ high cut ~7/10)**, within a
  recent window (~28 days). Routine `soreness`-type logs are EXCLUDED so DOMS doesn't
  inflate fatigue.
- **D-11:** `daysSinceLastInjury` = days since the most recent qualifying niggle (per D-10),
  `nil` if none.
- **D-12:** `recentWellnessScores` = fetch last **14 days** of `WellnessCheckIn.wellnessScore`
  (matches the fatigue 14-day window). This is the obvious fix for the empty `[]` at
  `DashboardViewModel.swift:236` — not gray, just wire it.
- **D-13:** Exact threshold constants (severity cut, window length) are tunable — planner
  may pick sane defaults (≥7/10, 28d) and expose as named constants; not user-locked.

### Claude's Discretion
- Final model/type/field names, repository method shape, and whether the dashboard
  affordance is a button vs. row — follow existing conventions.
- Whether niggle region reuses the Phase 22 muscle-taxonomy enum directly or a coarser
  body-region subset — planner decides based on the taxonomy's UX weight, but MUST stay
  taxonomy-aligned for future per-muscle Strain-Risk fusion (Phase 27).
- Severity input control (slider vs. stepper) — reuse DESIGN-compliant primitive.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Algorithm milestone (scope + framing — MANDATORY)
- `.planning/research/algorithm-moat-design.md` — locked v1 scope + codex addenda; Strain-Risk channel definition
- `.planning/research/competitive-algorithm-analysis.md` — honest-framing / no-moat positioning + codex addenda
- `.planning/ROADMAP.md` §"Phase Details — v1.6 Algorithm Moat" (lines 261–270) — Phase 25 scope line + neighbors
- `.planning/RESUME.md` — session handoff; Phase 24→25 contract notes

### Phase 24 data-contract (the harness this phase feeds — MANDATORY)
- `.planning/phases/24-validation-data-contract/24-CONTEXT.md` — date-contract decisions (predictionDate/targetDate/outcome-window)
- `.planning/phases/24-validation-data-contract/24-VERIFICATION.md` — what Phase 24 actually shipped
- `WorkloadApp/Services/ShadowPredictor.swift` — `Outcome` enum (lines ~25–30), `ExperimentalArm` (lines ~147–181)
- `WorkloadApp/Models/ShadowArmPrediction.swift` — outcomeRaw mapping (lines ~55–62); local-only `@Model` exemplar
- `WorkloadApp/Services/ShadowAnalyticsService.swift` — actual-label resolution, `painActual = Double(w.soreness)` (~line 165)
- `WorkloadApp/Services/ShadowMetrics.swift` — MAE/Spearman/calibration surface the new outcome plugs into

### Fatigue path being wired
- `WorkloadApp/ViewModels/DashboardViewModel.swift` — `load()` lines ~64–300; hardcoded inputs at :236, :252
- `WorkloadApp/Services/FatigueIndexEngine.swift` — `FatigueInput` struct (lines ~22–43); soft-tissue injury handling (~327–343)

### Reuse / conventions
- `WorkloadApp/Models/WellnessCheckIn.swift` — existing `soreness:Int` (1–5) + `wellnessScore`; do NOT duplicate
- `WorkloadApp/Models/CyclePredictionLog.swift` — local-only never-synced pattern (no `Codable`, omitted from SyncService)
- `WorkloadApp/Services/SyncService.swift` — `pushAll()`/`pullAll()` exclusion convention
- `WorkloadApp/App/WorkloadApp.swift` — ModelContainer `Schema([...])` (lines ~70–91); new model must be registered
- `WorkloadApp/Components/CardStyle.swift` — `CardStyle`, `SectionHeader`, `SectionContainer`, `RowSeparator`, 8pt grid
- `WorkloadApp/Views/Recovery/MorningCheckInSheet.swift` — `WellnessSlider` + lightweight-sheet pattern to mirror
- `WorkloadApp/Models/Enums.swift` — Phase 22 muscle taxonomy enum (region source)
- `DESIGN.md` — 0pt corners, no shadows, 8pt grid, General Sans, Font/ColorTokens (MANDATORY visual contract)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `CardStyle` / `SectionHeader` / `WellnessSlider` (MorningCheckInSheet) — niggle sheet reuses these; no new primitives.
- `CyclePredictionLog` / `ShadowArmPrediction` — copy the local-only `@Model` shape (no `Codable`, not in SyncService).
- Phase 22 muscle-taxonomy enum (33 values) — source for the region picker; keep taxonomy-aligned for Phase 27.
- `WellnessCheckIn.wellnessScore` — already computed; just fetch a 14-day window for D-12.

### Established Patterns
- Pure-struct engines with static methods (FatigueIndexEngine) — injury-derivation logic should be a pure helper, not stuffed in the ViewModel.
- `ExperimentalArm` registry in ShadowPredictor — new graded outcome registered alongside existing 4; no arch change.
- Shadow harness is gated OFF / local-only — Phase 25 changes stay invisible to users until Phase 29 gates pass.

### Integration Points
- `DashboardViewModel.load()` :236 / :252 — replace the three hardcoded inputs (wellness history, injury count, days-since).
- `ShadowPredictor.Outcome` + `ShadowAnalyticsService` actual-resolution — add `.niggleSeverity` end-to-end, date-contract-safe.
- `WorkloadApp.swift` Schema array — register the new model (migration is additive; SwiftData lightweight).
- Dashboard view — add the on-demand entry affordance; post-workout save flow — add the optional non-blocking nudge.
</code_context>

<specifics>
## Specific Ideas

- Niggle sheet shape approved in discussion (region ▾ / type segmented / 0–10 severity / limited-training Yes-No / optional note / Save) — minimal one-screen sheet, DESIGN-compliant.
- Validation label is **graded max-severity-in-window**, explicitly NOT a binary event in v1.
- Injury qualification is **functional** (type + impact), explicitly NOT severity-only and NOT impact-only.
</specifics>

<deferred>
## Deferred Ideas

- **Binary breakdown-event outcome** (new pain/tweak with limited-training in window) — revisit once enough positives accumulate for stable calibration/CI. (Area 2 alt.)
- **Niggle resolution / healing tracking** (mark a niggle resolved, track duration) — richer injury-recency modeling; future.
- **Per-niggle trend surfacing in UI** (history view of niggles by region over time) — presentation, not validation; future phase.
- **Daily soreness/niggle prompt or reminder** — rejected for v1 (no-nag ethos); reconsider only with explicit user opt-in.
</deferred>
