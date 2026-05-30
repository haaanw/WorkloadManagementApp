# Phase 25: Soreness / Tweak Self-Log — Research

**Researched:** 2026-05-30
**Domain:** SwiftData local-only model + minimal SwiftUI capture + shadow-harness outcome + fatigue-input wiring (internal-engineering, no web research)
**Confidence:** HIGH (every claim grounded in the actual code with file:line anchors; no external sources)

---

<user_constraints>
## User Constraints (from 25-CONTEXT.md)

### Locked Decisions (D-01..D-13 — DO NOT contradict)
- **D-01:** New dedicated local-only `@Model` (working name `SorenessLog` / niggle entry). DISTINCT from `WellnessCheckIn.soreness` (1–5), which stays untouched and keeps feeding the existing `.pain` outcome.
- **D-02:** One entry captures: **body region** (aligned to existing muscle taxonomy from Phase 22), **type** ∈ {soreness, pain, tweak}, **severity 0–10**, **"limited training?" flag** (Bool), **optional note** (String?). Plus `id`, `date`/timestamp, `athlete` inverse relationship.
- **D-03:** "Limited training?" flag is the load-bearing functional-impact signal separating a real niggle from routine DOMS — required (default No), not optional.
- **D-04:** Add ONE new graded outcome to `ShadowPredictor.Outcome` (working name `.niggleSeverity`): **max niggle severity (0–10) logged within the outcome window, 0 if none.**
- **D-05:** Do NOT touch the existing `.pain` (whole-body 1–5) outcome. Do NOT add a binary breakdown-event outcome in v1 (deferred).
- **D-06:** Actual-label resolution must respect the Phase 24 date contract (predictionDate/targetDate/outcome-window, no same-day leak) — mirror how `ShadowAnalyticsService` resolves `painActual` from `WellnessCheckIn.soreness`.
- **D-07:** Primary entry = on-demand "Log a niggle" affordance on the Dashboard. No daily nag.
- **D-08:** Secondary = non-blocking optional prompt after saving a workout ("anything bother you?"). Dismissible/skippable; never blocks the save flow.
- **D-09:** Do NOT fold niggle logging into the once-daily `MorningCheckInSheet` ritual.
- **D-10:** Derive `softTissueInjuryCount` = count of distinct active niggles where type ∈ {pain, tweak} AND (limited-training=Yes OR severity ≥ high cut ~7/10), within a recent window (~28 days). Routine `soreness`-type logs EXCLUDED.
- **D-11:** `daysSinceLastInjury` = days since most recent qualifying niggle (per D-10), `nil` if none.
- **D-12:** `recentWellnessScores` = fetch last **14 days** of `WellnessCheckIn.wellnessScore`. Fixes the empty `[]` at `DashboardViewModel.swift:236`.
- **D-13:** Exact threshold constants (severity cut, window length) tunable — planner picks sane defaults (≥7/10, 28d) and exposes as named constants; not user-locked.

### Claude's Discretion
- Final model/type/field names, repository method shape, dashboard affordance shape (button vs. row).
- Whether niggle region reuses the Phase 22 muscle-taxonomy enum directly or a coarser body-region subset — planner decides on UX weight, MUST stay taxonomy-aligned for Phase 27 per-muscle Strain-Risk fusion.
- Severity input control (slider vs. stepper) — reuse a DESIGN-compliant primitive.

### Deferred Ideas (OUT OF SCOPE)
- Binary breakdown-event outcome (revisit once enough positives accumulate).
- Niggle resolution / healing tracking (duration modeling).
- Per-niggle trend surfacing in UI (history view).
- Daily soreness/niggle prompt/reminder (no-nag ethos; opt-in only).
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| D-01/D-02/D-03 | New local-only `SorenessLog` @Model | §1 Data Model — exact shape, local-only pattern verified against `ShadowArmPrediction`/`CyclePredictionLog` |
| Region taxonomy | Region aligned to Phase 22 muscle taxonomy | §2 — `MuscleGroup` (33 cases) vs `MuscleRegion` (7); recommend store `MuscleGroup`, pick at `MuscleRegion` UX granularity |
| D-04/D-05/D-06 | `.niggleSeverity` graded outcome, date-contract-safe | §3 — exact enum + resolution slot in `ShadowAnalyticsService.resolveOutcomes` |
| D-10/D-11/D-12 | Fatigue-input derivation | §4 — pure helper + exact `FatigueInput` field types/units/windows |
| D-07/D-08/D-09 | Dashboard affordance + post-workout nudge | §5 — exact view hooks |
| — | Unit tests | §6 — model persistence, derivation rule, no-leak windowing |
</phase_requirements>

---

## Summary

Phase 25 is an internal-engineering phase with two halves that share one new data model. **Half A** adds a dedicated, optional, **local-only** `SorenessLog` SwiftData `@Model` (region + type + 0–10 severity + limited-training flag + optional note), a minimal one-screen capture sheet, and a new **graded** validation outcome `.niggleSeverity` (max severity in the Phase-24 outcome window, 0 if none) that plugs into the existing shadow harness. **Half B** replaces three hardcoded inputs in `DashboardViewModel.load()` (`recentWellnessScores: []`, `softTissueInjuryCount: 0`, `daysSinceLastInjury: nil`) with real derivations.

The codebase has clean, exact precedents for every piece: `ShadowArmPrediction.swift` and `CyclePredictionLog.swift` are the verbatim local-only `@Model` template (no `Codable`, omitted from `SyncService` by construction); `ShadowAnalyticsService.resolveOutcomes` (lines 158–173) is where actuals are joined on `row.targetDate` (the no-leak join); `ShadowPredictor.Outcome` (lines 25–30) is the 4-case enum to extend; `FatigueIndexEngine.FatigueInput` (lines 22–43) gives the exact field types to match; and the Phase 22 `MuscleGroup`/`MuscleRegion` enums (Enums.swift:177–363) supply the taxonomy.

**Primary recommendation:** Build a `SorenessLog` `@Model` storing region as the **specific `MuscleGroup` rawValue** (taxonomy-aligned for Phase 27) but presenting it at the coarser **`MuscleRegion`** picker granularity. Add `.niggleSeverity` as a 5th `Outcome` case; resolve it inside the existing `resolveOutcomes` target-day join; on the predict side return `nil` (no arm predicts it until Phase 27 — the harness already tolerates nil per `arm.predict(...) else { continue }` at `ShadowAnalyticsService.swift:91` and the aggregate/metrics guards). Put the injury-derivation math in a new pure-struct helper (per the `FatigueIndexEngine` convention), called from `DashboardViewModel.load()`. The new model is additive to the `Schema([...])` array (WorkloadApp.swift:70–91) → SwiftData lightweight migration, no destructive change.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Niggle entry persistence | Models (`@Model`) + Repositories (`@MainActor` repo) | — | Mirrors every other SwiftData entity; repo wraps `ModelContext` |
| Niggle capture UI | Views (SwiftUI sheet) | — | One-screen sheet; reuses `CardStyle`/`WellnessSlider` primitives |
| `.niggleSeverity` outcome resolution | Pipeline/Service (`ShadowAnalyticsService`, `@MainActor`) | Models (new outcome enum case) | Resolution is SwiftData orchestration; the enum lives with the predictor |
| Injury-count / days-since derivation | Engines (pure struct, static) | ViewModel (calls it) | Pure deterministic computation → `FatigueIndexEngine`-style helper, NOT stuffed in VM (CONTEXT "Established Patterns") |
| Wellness-history fetch (D-12) | Repositories + ViewModel | — | Plain `WellnessCheckIn` query; VM assembles `FatigueInput` |
| Dashboard affordance + post-workout nudge | Views | — | View-layer wiring of `.sheet`/state flags |

---

## Standard Stack

No external packages. This phase uses only Apple frameworks already in the project (SwiftUI, SwiftData, Foundation, XCTest). **No `npm`/`pip`/`cargo` install. No Package Legitimacy Audit required** (zero external dependencies added).

| Component | Source | Purpose |
|-----------|--------|---------|
| `@Model` / `@Attribute(.unique)` / `@Relationship` | SwiftData (in-project) | New `SorenessLog` entity |
| `FetchDescriptor` / `#Predicate` | SwiftData (in-project) | Windowed niggle + wellness queries |
| `Calendar.startOfDay` / `date(byAdding:)` | Foundation (in-project) | Date-contract windowing (matches existing harness) |
| `CardStyle` / `WellnessSlider` / `SectionHeader` / `DesignToggleStyle` | In-project (`CardStyle.swift`, `MorningCheckInSheet.swift`) | Reused DESIGN-compliant UI primitives |
| XCTest | Apple (in-project) | Unit tests, in-memory `ModelContainer` |

---

## 1. Data Model — `SorenessLog` (D-01/D-02/D-03)

### Local-only `@Model` pattern (verified)

The exact template to copy is `ShadowArmPrediction.swift:16–63` and `CyclePredictionLog.swift:28–160`. The local-only contract is **NOT** a field or flag — it is enforced **by omission**:

- **No `Codable` conformance** on the `@Model` class [VERIFIED: `ShadowArmPrediction.swift` and `CyclePredictionLog.swift` have zero `Codable`; the only `Codable` types in `SyncService.swift` are the `*Row` DTOs at lines 808–1374].
- **No `*Row` DTO struct** in `SyncService.swift`, and **no `push*`/`pull*` method** for the model. `SyncService.pushAll` (line 21) and `pullAll` (line 66) only call per-model helpers that exist (`pushWellnessCheckIns`, etc.). `CyclePredictionLog`, `ShadowArmPrediction`, and `MenstrualCycleSnapshot` appear **nowhere** in `SyncService.swift` — that omission IS the exclusion. [VERIFIED: grep — no match for those types in SyncService.]
- The class doc-comment explicitly declares "**Local-only — never syncs**" (e.g. `ShadowArmPrediction.swift:4`, `CyclePredictionLog.swift:4,23–27`). `SorenessLog` MUST carry the same doc-comment so the convention is self-documenting.

### Recommended shape

```
@Model
final class SorenessLog {            // working name; planner may rename (Discretion)
    @Attribute(.unique) var id: UUID
    var date: Date                   // timestamp = when the niggle was logged (start-of-day used for windowing)
    var regionRaw: String            // MuscleGroup.rawValue — see §2; stored as raw String like phaseBucketRaw
    var typeRaw: String              // NiggleType.rawValue ∈ {soreness, pain, tweak}
    var severity: Int                // 0–10 (D-02)
    var limitedTraining: Bool        // D-03, default false, REQUIRED
    var note: String?                // optional
    var updatedAt: Date
    var athlete: Athlete?            // inverse relationship, like every other entity
    init(...) { ... }                // start-of-day NOT forced in init (it's a real timestamp); window math uses Calendar.startOfDay at read time, matching resolveOutcomes:160
}
```

**Field-type decisions (grounded):**
- **`severity: Int`** not `Double` — it is a 0–10 discrete slider/stepper value; the *outcome* converts to `Double` at resolution time exactly as `painActual = Double(w.soreness)` does (`ShadowAnalyticsService.swift:165`). Keeps storage honest.
- **`regionRaw: String`** not the enum directly — follows the established `phaseBucketRaw: String?` / `outcomeRaw: String` raw-string storage convention (`CyclePredictionLog.swift:50`, `ShadowArmPrediction.swift:23`). Storing the `MuscleGroup.rawValue` makes the value a permanent serialization contract (Enums.swift:219–220 warns these rawValues "must never be renamed") and is migration-proof.
- **`typeRaw: String`** — introduce a new `enum NiggleType: String, Codable, CaseIterable, Identifiable { case soreness, pain, tweak }` in `Enums.swift` (the domain-enum home; matches `PRType`, `RecoveryZone` style at Enums.swift:365,383). Store its rawValue. The enum being `Codable` is harmless — only the `@Model` must avoid `Codable`.
- **`limitedTraining: Bool = false`** — default No per D-03; it is the functional-impact discriminator for D-10.

**New domain enum (add to `Enums.swift`):**
```
enum NiggleType: String, Codable, CaseIterable, Identifiable {
    case soreness   // routine DOMS — EXCLUDED from injury count (D-10)
    case pain
    case tweak
    var id: String { rawValue }
    var displayName: String { ... }   // localized, matches existing enum style
}
```

### SwiftData migration safety [VERIFIED: WorkloadApp.swift:70–91]

Adding `SorenessLog.self` to the `Schema([...])` array (currently 20 entities, WorkloadApp.swift:70–91) is **purely additive**: a brand-new model with no relationship changes to existing entities except a new optional `athlete: Athlete?` inverse (which does not require touching `Athlete`'s existing relationships — SwiftData infers it; the project's other models like `WellnessCheckIn.swift:15` use the same bare `var athlete: Athlete?` without an explicit inverse on `Athlete`). This triggers **SwiftData lightweight (automatic) migration** — the same posture Phase 24 used for `ShadowArmPrediction` ([VERIFIED: `ShadowArmPrediction.self` is already in the Schema at WorkloadApp.swift:80, added in Phase 24 with no `VersionedSchema`/`MigrationPlan`]). The config is `ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)` (WorkloadApp.swift:92) — on-disk store; lightweight migration applies on next launch. **No `MigrationPlan` needed.** The test `ModelContainer` must also register `SorenessLog.self` (the tests build their own in-memory container, e.g. `ShadowAnalyticsServiceTests.swift:20`).

**Risk flag:** adding the optional `athlete: Athlete?` on `SorenessLog` is safe, but if the planner also adds a `var sorenessLogs: [SorenessLog]` **explicit inverse** on `Athlete`, that touches the `Athlete` model and is still lightweight-safe (additive to-many), but unnecessary — the existing `WellnessCheckIn`/`RecoverySnapshot` pattern keeps the inverse implicit. Recommend matching that pattern (bare `var athlete: Athlete?` on `SorenessLog`, no array on `Athlete`).

---

## 2. Region Taxonomy (Discretion — must stay Phase-27-aligned)

Two enums exist in `Enums.swift`:

| Enum | Cases | Count | Purpose |
|------|-------|-------|---------|
| `MuscleRegion` | legs, back, chest, shoulders, arms, core, fullBody | **7** | High-level grouping for the muscle picker (Enums.swift:177–211) |
| `MuscleGroup` | 7 coarse (aliases) + 26 specific = **33** | **33** | Phase 22 anatomical taxonomy; rawValues are permanent serialization contracts (Enums.swift:221–363) |
| `BodyRegion` | shoulder, knee, back, hip, ankle, wrist, elbow, neck | 8 | **JOINT-based injury enum** — explicitly named to NOT collide with `MuscleRegion` (Enums.swift:172–174, 538) |

[VERIFIED: counted directly from Enums.swift — `MuscleRegion` has exactly 7 cases (lines 178–184); `MuscleGroup` has 7 coarse + 26 specific = 33 cases (lines 223–267); `MuscleGroup.region` (lines 318–342) maps every case → a `MuscleRegion`.]

### Recommendation: **store `MuscleGroup.rawValue`, present at `MuscleRegion` granularity**

- **Store** the specific `MuscleGroup` rawValue in `SorenessLog.regionRaw`. This keeps the niggle log **taxonomy-aligned with the Phase 27 per-muscle Strain-Risk fusion** (the Discretion clause's hard requirement). `MuscleGroup.region` (Enums.swift:318) gives free upward roll-up to `MuscleRegion` whenever a coarser view is needed.
- **Present** the picker at the **`MuscleRegion` (7-option) granularity** for v1 capture, optionally with a "specify" affordance using the existing `MuscleGroup.suggestedSpecific(for:)` helper (Enums.swift:350–362). Reasoning: a 33-option flat list is too heavy for a quick post-workout nudge (DESIGN/no-friction ethos, D-08). Seven coarse regions is the right UX weight; storing the coarse-region's `MuscleGroup` alias rawValue (e.g. `MuscleGroup.legs.rawValue`) is still a valid `MuscleGroup` value, so no data is lost and Phase 27 can read it as a `MuscleGroup`.
- **Do NOT use `BodyRegion`** (the joint enum) — it is anatomically orthogonal (joints, not muscles) and not what Phase 27 fuses against.

**Net:** picker yields a `MuscleRegion` (or specific `MuscleGroup`), the model stores a `MuscleGroup.rawValue`. The coarse-region case rawValues (`legs`, `back`, …) are retained `MuscleGroup` cases (Enums.swift:223–229), so `MuscleGroup(rawValue: region.rawValue)` round-trips for the 7 coarse regions. [VERIFIED: `MuscleRegion` and `MuscleGroup` share identical rawValues for the 7 coarse cases — `legs/back/chest/shoulders/arms/core/fullBody`.]

---

## 3. Shadow Outcome `.niggleSeverity` (D-04/D-05/D-06)

### Exact enum addition [target: `ShadowPredictor.swift:25–30`]

Current enum (VERIFIED, ShadowPredictor.swift:25–30):
```
enum Outcome: CaseIterable {
    case recovery     // next-day recovery score (0-100)
    case wellness     // next-day wellness score (0-100)
    case completion   // next-day workout completion (0 or 1) — reframed as ADHERENCE (D-06)
    case pain         // next-day reported soreness (WellnessCheckIn.soreness, 1-5 scale)
}
```
Add one case:
```
    case niggleSeverity   // max SorenessLog severity (0-10) in the outcome window, 0 if none (P25 D-04)
```

**Ripple sites that switch over `Outcome` (every one must add a `.niggleSeverity` branch — VERIFIED via grep on `switch outcome`/`case .pain`):**
1. `ShadowPredictor.phaseOffset(for:outcome:)` — `ShadowPredictor.swift:120–127` (the luteal switch). `.niggleSeverity` returns `0` (no literature-derived cycle offset in v1; cycle-aware = baseline for this outcome).
2. `ShadowAnalyticsService.recordPrediction` `series(for:)` — `ShadowAnalyticsService.swift:65–72`. Needs a `niggleSeverityHistory` series param (can be empty `[]` until a Phase-27 arm wants it; see "predict-side default" below).
3. `ShadowArmPrediction.outcomeRaw(for:)` — `ShadowArmPrediction.swift:55–62`. Add `case .niggleSeverity: return "niggleSeverity"` (stable raw key; permanent contract).
4. `ShadowAnalyticsService.aggregate` `actual(_:_:)` — `ShadowAnalyticsService.swift:214–221`. Add `case .niggleSeverity: return row.niggleSeverityActual`.
5. `ShadowAnalyticsService.metricsReport` `pairs` `actual(_:)` — `ShadowAnalyticsService.swift:264–271`. Same addition.
6. `ShadowAnalyticsService.pairedMAEDifferenceCI` `actual(_:)` — `ShadowAnalyticsService.swift:315–322`. Same addition.

**New stored actual column on `CyclePredictionLog`:** add `var niggleSeverityActual: Double?` alongside `painActual` (`CyclePredictionLog.swift:79`) — additive, lightweight migration. (The per-arm *predictions* go through the generic `ShadowArmPrediction` store, so no new prediction column is needed — only the actual.)

### Date-contract-safe actual resolution (D-06) [slot: `ShadowAnalyticsService.resolveOutcomes`, lines 158–173]

Mirror the `painActual` pattern exactly. Current join (VERIFIED, ShadowAnalyticsService.swift:160–168):
```
let day = calendar.startOfDay(for: row.targetDate)   // D-03: TARGET day, never prediction day
...
if let w = wellnessByDay[day] {
    row.wellnessActual = w.wellness
    row.painActual = Double(w.soreness)
}
```
Add a parallel niggle join keyed on the **same `targetDate` start-of-day**:
```
// Max niggle severity logged ON the target day; 0 if none (D-04). Resolved strictly on
// targetDate (D-06 / no same-day leak), exactly like painActual above.
row.niggleSeverityActual = maxNiggleSeverityByDay[day] ?? 0.0
```
where `maxNiggleSeverityByDay: [Date: Double]` is built once (like `wellnessByDay` at lines 152–155 / `fetchWellnessByDay` at 178–203) from a windowed `SorenessLog` fetch over `[earliestTarget … asOf]`, grouping by `Calendar.startOfDay(for: log.date)` and taking the **max severity** per day.

**Critical "0 if none" subtlety (no-leak + dense-label):** D-04 says the actual is **0 when no niggle was logged on the target day**. Because the join uses `?? 0.0`, every resolvable row gets a `niggleSeverityActual` (never nil) — so unlike `pain`/`wellness` (which require a check-in to exist on the target day), `.niggleSeverity` is **always resolvable once `targetDate` has elapsed**, exactly like `completionActual` (which is `sessionDays.contains(day) ? 1.0 : 0.0`, ShadowAnalyticsService.swift:168 — always observable). This is the intended dense, gracefully-degrading label (D-04). **Confirm with the planner:** the row should be marked resolved on `targetDate` elapse regardless of whether a niggle exists — consistent with how `completionActual` already forces resolution.

**Leak-risk audit (no leak found):**
- The feature cutoff (Phase 24 D-02, enforced at `RecoveryPipeline.swift:196–202,217–219`) governs the *predictor input series*. The `.niggleSeverity` arm predicts `nil` in v1 (no input series consumed), so there is **no feature-cutoff surface to leak through** for this outcome yet.
- The *actual* is joined only on `targetDate` (the corrected D-03 join), so a niggle logged on the prediction day D never scores a D→D+1 prediction. **No same-day leak.**
- **One thing the planner MUST verify:** a niggle logged late on the prediction day D, if it carries a `date` that `Calendar.startOfDay` buckets to D, will (correctly) NOT match the `targetDate = D+1` join. Confirm the post-workout nudge stamps `date = .now` (real timestamp) so windowing is by calendar day — matches `WellnessCheckIn(date: .now)` (MorningCheckInSheet.swift:199) and the `resolveOutcomes` start-of-day bucketing.

### Predict-side default (D-04 — harness tolerates a not-yet-predicting outcome)

[VERIFIED: the harness already tolerates an outcome no arm predicts.]
- `recordPrediction` writes a child row only `guard let predicted = arm.predict(...) else { continue }` (ShadowAnalyticsService.swift:91) — a `nil` prediction simply writes no `ShadowArmPrediction` row.
- `aggregate` requires both arms' predictions AND the actual `else { continue }` (lines 226–228) — so an outcome with no predictions contributes `n=0` and is omitted from the result map (`guard n > 0 else { continue }`, line 233). No crash.
- `metricsReport` builds `pairs` that drop rows missing the arm's prediction (lines 273–277) → empty pairs → `mae = nil`, `calibrationSlope`/`spearmanRho` return `nil` on thin data (lines 288–296). No crash.

**Recommendation:** the two existing arms (`baseline`, `cycleAware`) return `nil` for `.niggleSeverity` in v1 (no series, no model) — they are recovery/wellness-shaped persistence predictors with no niggle history. The `.niggleSeverity` **actual is recorded every resolvable day** (so the validation substrate accumulates), but **no arm predicts it until Phase 27** registers a Strain-Risk arm that does. This is exactly the "contract slot the harness can resolve once Phase 25 ships" that Phase 24 D-07 promised. The cleanest implementation: in `recordPrediction`'s arm loop, pass an **empty `niggleSeverityHistory: [] `** so `baselinePrediction(series: [])` would return `neutralScore (50.0)` — **but that is wrong** for a 0–10 scale. **Better:** have the two existing arms explicitly return `nil` for `.niggleSeverity` (skip it), so no misleading 50.0 prediction is stored. The planner should make `ExperimentalArm.predict` return `nil` for `.niggleSeverity` for both current arms (a one-line guard in the closures at ShadowPredictor.swift:169,176).

---

## 4. Fatigue Wiring (D-10/D-11/D-12)

### Exact `FatigueInput` field types to match [VERIFIED: FatigueIndexEngine.swift:22–43]

| Field | Type | Unit / window the engine assumes |
|-------|------|----------------------------------|
| `recentWellnessScores` | `[Double]` | "Wellness scores for last 7 days (oldest first) for trend" (line 38). Consumed by `computeWellnessTrendFatigue` (needs ≥3 to be non-neutral, line 205). |
| `softTissueInjuryCount` | `Int` | "Number of soft-tissue injuries in last 12 months" (line 40). Consumed by `computeSoftTissueRisk` (line 327): `countScore = 1 - exp(-0.5*n)`. |
| `daysSinceLastInjury` | `Int?` | "Days since most recent soft-tissue injury (nil = none)" (line 42). `nil` → recencyMultiplier 0.5 (line 339); else `exp(-days/120)` (line 337). |

**Unit-match note (IMPORTANT):** the engine doc says `recentWellnessScores` is **7 days** (line 38), but D-12 says fetch **14 days**. The engine only uses the series for a *slope* via `RecoveryScoreEngine.computeSlope` (line 318) and is gated on `count >= 3` (line 205) — it does not hard-require exactly 7. The existing `recentRecoveryScores` is built with `.suffix(7)` (DashboardViewModel.swift:232–235). **Recommendation:** fetch the last 14 days of `WellnessCheckIn` per D-12, then pass them as-is (the slope is well-defined for 14 points; more points = steadier trend). If the planner wants strict parity with the recovery series, apply `.suffix(7)` after fetching — but D-12 explicitly says "matches the fatigue 14-day window," so passing all 14 is the locked intent. **Flag for plan-review:** confirm whether to `.suffix(7)` or pass all 14; D-12 wording favors 14.

Also note the `softTissueInjuryCount` doc says "**last 12 months**" (line 40) but D-10 says a **~28-day** window. These are not contradictory — D-10 deliberately narrows the window for the niggle-derived count (a niggle is a recent functional signal, not a 12-month injury history). The engine's `computeSoftTissueRisk` math is window-agnostic (it just takes a count + recency); feeding it a 28-day-windowed count is valid. **Document the chosen window as a named constant (D-13).**

### Derivation logic — pure helper (per established pattern)

CONTEXT "Established Patterns": *"injury-derivation logic should be a pure helper, not stuffed in the ViewModel."* Create a pure struct (Foundation-only, static methods), e.g. `NiggleInjuryDeriver` or extend a fatigue-helpers struct, mirroring `FatigueIndexEngine.baselineSessionsPer14Days` (a pure static helper that takes pre-fetched models, FatigueIndexEngine.swift:242–256). The ViewModel fetches the `[SorenessLog]` (via a new repo method) and passes them in; the helper computes the three values. Keep SwiftData out of the pure helper (it takes `[SorenessLog]`, returns the derived primitives) — exactly how `baselineSessionsPer14Days(sessions:)` takes `[WorkoutSession]`.

**Recommended signatures (planner finalizes names):**
```
// Pure, Foundation-only, deterministic.
struct NiggleInjuryDeriver {
    static let qualifyingSeverityCut: Int = 7        // D-13 named constant
    static let injuryWindowDays: Int = 28            // D-13 named constant

    // D-10: distinct active qualifying niggles in window.
    static func softTissueInjuryCount(logs: [SorenessLog], asOf: Date = .now) -> Int
    // D-11: days since most recent qualifying niggle, nil if none.
    static func daysSinceLastInjury(logs: [SorenessLog], asOf: Date = .now) -> Int?
}
```

**D-10 qualification rule (exact):** a log qualifies iff
`type ∈ {pain, tweak}` AND (`limitedTraining == true` OR `severity >= qualifyingSeverityCut`) AND `date` within `injuryWindowDays` of `asOf`. **`soreness`-type logs are excluded** (DOMS guard). "distinct active" → for `softTissueInjuryCount`, count distinct qualifying logs in the window (the simplest reading; a future phase adds resolution/dedup-by-region per the deferred "niggle resolution" idea — v1 does NOT dedup by region). **Flag (under-specified):** D-10 says "distinct active niggles" but the model has no `resolved` field (deferred). For v1, "active" = "within the window" (no resolution tracking). Recommend the planner document this explicitly: count = number of qualifying logs in the 28-day window. If multiple logs for the same region inflate the count, that is acceptable for v1 (the soft-tissue weight is only 0.10, FatigueIndexEngine.swift:88, and the count saturates via `1 - exp(-0.5n)`).

**D-11:** `daysSinceLastInjury` = `Calendar.dateComponents([.day], from: startOfDay(mostRecentQualifying.date), to: startOfDay(asOf)).day`, or `nil` if no qualifying log. Mirrors the day-diff math at `resolveOutcomes` (ShadowAnalyticsService.swift:138–139) and `daysSinceRest` (DashboardViewModel.swift:333–350).

### Where it slots in `DashboardViewModel.load()` [VERIFIED: lines 222–263]

Surrounding data already in scope at the wiring point (so the planner knows what's free):
- `recentSnapshots: [RecoverySnapshot]` (line 115) — already fetched (28-day history).
- `allSessions` (line 182), `recentSessions14d` (line 223), `recentSessionTSS`/`baselineTSS`/`sessionsIn14Days`/`baselineSessions14d` (lines 224–231) — all computed.
- `daysSinceRest` (line 219), `recentRecoveryScores` (lines 232–235) — computed.
- `recoveryRepo` (line 107), `workoutRepo` (line 181) — instantiated. **No wellness or niggle repo yet** — the planner adds fetches.

**Three replacements (exact lines):**
- **DashboardViewModel.swift:236** `let recentWellnessScores: [Double] = []  // TODO` → fetch last 14d `WellnessCheckIn.wellnessScore` for the athlete, map `\.wellnessScore`. (D-12.) A new `WellnessRepository`-style fetch or an inline `FetchDescriptor<WellnessCheckIn>` (there is precedent for inline descriptors in the VM, e.g. `PersonalRecord` at lines 308–312). Recommend a small repo method for testability.
- **DashboardViewModel.swift:252** `softTissueInjuryCount: 0` → `NiggleInjuryDeriver.softTissueInjuryCount(logs: niggleLogs)`.
- **DashboardViewModel.swift:253** `daysSinceLastInjury: nil` → `NiggleInjuryDeriver.daysSinceLastInjury(logs: niggleLogs)`.

where `niggleLogs` is fetched once (a new `SorenessLogRepository.fetchRecent(days: 28, athlete:)` returning `[SorenessLog]`).

**Cold-start interaction (VERIFIED, do not break):** the whole `FatigueInput` block is inside `else { ... }` of `if isColdStartActive` (DashboardViewModel.swift:238–263). During cold-start `fatigueIndex = nil` (line 240) — the new inputs are only assembled in the non-cold-start branch, so no extra fetches happen during cold-start. Keep the new fetches inside that `else` branch (or guard them) to avoid needless work.

---

## 5. UI (D-07/D-08/D-09)

### DESIGN contract (MANDATORY)
0pt corners (`Rectangle`, never `RoundedRectangle`), no shadows, 8pt grid (`Spacing` enum, CardStyle.swift:15–26), `Font.Tokens.*` only, `ColorTokens` only, accent only on hero score. Use `DesignToggleStyle` (`.toggleStyle(.design)`, CardStyle.swift:118–143) for the limited-training Bool — the system Toggle's Apple-green violates the accent-only rule.

### Reusable primitives (verified)
- **Capture sheet:** mirror `MorningCheckInSheet` (`NavigationStack` + `ScrollView` + `VStack(spacing:0)` + 0.5pt `Rectangle` dividers + Cancel/Save toolbar; MorningCheckInSheet.swift:27–177). Do NOT add it as a section *inside* `MorningCheckInSheet` (D-09) — it is a **separate** sheet (`NiggleLogSheet`).
- **Severity 0–10 control:** `WellnessSlider` (MorningCheckInSheet.swift:237–301) is a 1–5 segmented-bar control. For 0–10, either (a) generalize `WellnessSlider` to a `range`, or (b) build an analogous 0–10 bar/stepper using the same `Rectangle` segment pattern. Recommend a stepper-or-segmented control reusing the `scoreColor` zone logic. (Discretion: slider vs. stepper — both fine if DESIGN-compliant.)
- **Region picker:** a `Menu`-backed picker with `MenuChevron` (CardStyle.swift:149–155) over the 7 `MuscleRegion` cases (each has `displayName` + `systemImage`, Enums.swift:188–210).
- **Type:** a segmented control over `NiggleType.allCases` (3 options) — DESIGN-compliant segmented styling (reuse the segment `Rectangle` pattern; avoid system `Picker(.segmented)` if it injects non-token color).
- **Note:** `TextField(..., axis: .vertical)` with `SharpTextFieldStyle` (used in MorningCheckInSheet.swift:136–138).

### Hook points (verified)

**D-07 — Dashboard on-demand affordance:** `DashboardView` already owns `@State` sheet flags (`showActiveWorkout`, `showWellnessCheckIn`, `showTrainingProfile`, DashboardView.swift:18–20) and `.sheet` modifiers (lines 215–223). Add `@State private var showNiggleLog = false`, a `.sheet(isPresented: $showNiggleLog) { NiggleLogSheet() }`, and an entry affordance. The affordance can be a toolbar action (like `logWorkout` at DashboardView.swift:207–213) or a dashboard row/button (Discretion). Recommend a low-prominence row/button within an existing section (NOT a second toolbar button, to avoid crowding) — but planner decides per D-07's "button vs row" discretion.

**D-08 — Post-workout non-blocking nudge:** the save flow is `ActiveWorkoutSheet.saveSession()` (ActiveWorkoutSheet.swift:448–539). It already has multiple post-save branches that present sheets/alerts then `return` before `dismiss()` (spike alert at 521–524, PR celebration at 526–530). The nudge MUST be **non-blocking and skippable** (D-08): the cleanest pattern is to present the niggle prompt **after** `dismiss()` (or via a flag the Dashboard reads on the workout's completion), so the save itself is never gated. **Concrete recommendation:** set a `@State showNiggleNudge` and present a lightweight confirmation-style sheet ("Anything bother you?" → "Log a niggle" / "No, skip") that, on confirm, opens `NiggleLogSheet`, and on skip just dismisses — never blocking `saveSession`'s `try modelContext.save()` (line 497) which has already completed. Because `saveSession` already early-`return`s for spike/PR (lines 529–532), the planner should sequence the niggle nudge to NOT collide with those (e.g. show it after PR/spike flows resolve, or only when neither fires). Flag for plan-review: ordering vs. the existing spike/PR `return` branches.

---

## 6. Test Plan

### Conventions (verified)
- XCTest, `@testable import workload_management`, `final class …Tests: XCTestCase` (FatigueIndexEngineCycleTests.swift:1–5).
- Pure-engine tests: in-memory, no container (FatigueIndexEngineCycleTests builds `FatigueInput` structs directly).
- SwiftData-backed tests: build an in-memory `ModelContainer(... isStoredInMemoryOnly: true)` (ShadowAnalyticsServiceTests.swift:20–22) and **register the new `SorenessLog.self`** in that test container's schema.
- **KNOWN TRAP (must replicate):** the in-memory SwiftData store **traps on optional to-one relationship `#Predicate`** on the iOS 26.1 simulator — `ShadowAnalyticsServiceTests` `resolveOutcomes` tests are `XCTSkipIf(true, "SwiftData in-memory store crashes on optional to-one relationship predicate (iOS 26.1 sim)")` (ShadowAnalyticsServiceTests.swift:130,179). Any new test that fetches `SorenessLog` filtered by `athlete?.id` via `#Predicate` (like `fetchWellnessByDay` at ShadowAnalyticsService.swift:184–195) will hit the same trap → use the **same XCTSkip pattern** OR a disk-backed temp store, OR test the pure derivation helper with plain arrays (preferred — no SwiftData predicate needed).

### Tests that prove correctness

| Test | Type | What it proves |
|------|------|----------------|
| `SorenessLog` round-trips (insert/fetch, fields persist, cascade with athlete) | SwiftData in-memory | Model persistence; mirror `ShadowDataContractTests.test_armStore_roundTripsAndCascadeDeletes` (ShadowDataContractTests.swift:68) |
| `NiggleType` rawValue stability | pure | rawValues are permanent serialization contracts |
| `softTissueInjuryCount` — qualifying rule | pure (plain `[SorenessLog]`) | type∈{pain,tweak} AND (limitedTraining OR severity≥7); within 28d |
| **DOMS-exclusion edge case** | pure | a `soreness`-type log with severity 10 + limitedTraining=true is **NOT counted** (the discriminating test) |
| **Impact-only / severity-only edge cases** | pure | pain+severity 5+limitedTraining=true → counted; tweak+severity 8+limitedTraining=false → counted; pain+severity 3+limitedTraining=false → NOT counted |
| **Window edge** | pure | a qualifying log at day -29 (outside 28d) → NOT counted; at day -28 boundary → document inclusive/exclusive |
| `daysSinceLastInjury` | pure | nil when no qualifying log; correct day-diff for most recent qualifying |
| `.niggleSeverity` outcome resolution — max-in-window | SwiftData (skip-pattern) or pure helper | max severity on targetDay; **0 when no niggle** |
| **No-leak windowing** | pure/SwiftData | a niggle logged on `predictionDate` (D) does NOT resolve a row whose `targetDate` is D+1; only a niggle on D+1 does — mirror `ShadowDataContractTests` same-day-leak regression intent |
| `.niggleSeverity` predict-side nil tolerance | pure | both existing arms return `nil` for `.niggleSeverity`; `aggregate`/`metricsReport` omit it gracefully (n=0, no crash) |
| Empty/missing data | pure | no niggle logs → count 0, daysSince nil, outcome actual 0; empty wellness → `recentWellnessScores` empty → fatigue wellness component neutral (0.5) |
| Wellness wiring (D-12) | SwiftData/pure | last-14d wellness scores flow into `FatigueInput.recentWellnessScores` |

**Tip:** make the derivation helper take `[SorenessLog]` (plain array) so the bulk of the logic is testable **without** any SwiftData predicate — sidestepping the iOS 26.1 in-memory trap entirely. Only the repo-fetch path needs the SwiftData-backed (skippable) test.

---

## Runtime State Inventory

This is a greenfield-additive phase (new model + new outcome + new UI). Still, two runtime considerations:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | New `SorenessLog` rows are **local-only**, never synced (by omission from SyncService). No existing stored string is renamed. | None beyond Schema registration. |
| Live service config | None — no external service stores any niggle string. | None. |
| OS-registered state | None. | None. |
| Secrets/env vars | None. | None. |
| Build artifacts | New `.swift` files must be added to the Xcode project (`.pbxproj`) and the **test target** (and the test `ModelContainer` schema). | Verify `.pbxproj` membership + test-target membership per CLAUDE.md iOS rule. |

**Verified:** no existing model/file named soreness/niggle/injury/pain exists in `WorkloadApp/Models/` (grep returned none) — `SorenessLog` is genuinely new, no collision.

---

## Common Pitfalls

### Pitfall 1: Adding `Codable` to the `@Model` (sync leak)
**What goes wrong:** the niggle log accidentally becomes syncable, violating "NEVER syncs to Supabase" (CONTEXT domain) and D-01.
**Why:** copy-paste from a synced model (e.g. `WellnessCheckIn` is synced; its `*Row` DTO is `Codable`).
**Avoid:** copy from `ShadowArmPrediction`/`CyclePredictionLog` instead. No `Codable` on the class, no `*Row` struct, no `push*`/`pull*` method. The model name must NOT appear anywhere in `SyncService.swift`.

### Pitfall 2: Resolving the outcome on `predictionDate` (same-day leak regression)
**What goes wrong:** joining niggle actuals on `row.date`/`row.predictionDate` re-introduces the exact codex CRITICAL #3 bug Phase 24 fixed.
**Avoid:** join on `Calendar.startOfDay(for: row.targetDate)` — the variable is already named `day` at ShadowAnalyticsService.swift:160. Add the niggle join in the same loop, using `day`.

### Pitfall 3: Storing `MuscleRegion` instead of `MuscleGroup` (breaks Phase 27 alignment)
**What goes wrong:** Phase 27 per-muscle Strain-Risk fusion can't roll the niggle up to a `MuscleGroup`.
**Avoid:** store a `MuscleGroup.rawValue`; present at `MuscleRegion` granularity. The 7 coarse `MuscleGroup` cases share rawValues with `MuscleRegion`, so coarse capture still yields a valid `MuscleGroup`.

### Pitfall 4: Counting `soreness`-type logs in the injury count (DOMS inflation)
**What goes wrong:** routine DOMS inflates `softTissueInjuryCount` → fatigue index spuriously high (the exact thing D-10 guards against).
**Avoid:** the qualification predicate MUST exclude `type == .soreness`. This is the highest-value unit test (§6 DOMS-exclusion edge case).

### Pitfall 5: Blocking the workout save (D-08 violation)
**What goes wrong:** the nudge sheet gates `modelContext.save()` or the user can't dismiss the workout without answering.
**Avoid:** present the nudge only after the save has committed (ActiveWorkoutSheet.swift:497) and make "skip" a first-class, one-tap dismissal. Sequence it after the existing spike/PR `return` branches (lines 521–532).

### Pitfall 6: Wrong severity scale unit in the outcome (5 vs 10)
**What goes wrong:** `.niggleSeverity` is 0–10, but `.pain` is 1–5 (`Double(w.soreness)`). Mixing scales corrupts MAE/calibration.
**Avoid:** keep `.niggleSeverity` strictly on its own 0–10 scale; never reuse the `.pain` series or offset. The two outcomes are independent (D-05: don't touch `.pain`).

---

## State of the Art

| Old (current code) | New (this phase) | Impact |
|--------------------|------------------|--------|
| `DashboardViewModel.swift:236` `recentWellnessScores: []` | last-14d `WellnessCheckIn.wellnessScore` | Wellness-trend fatigue component (0.15 weight) becomes real instead of neutral 0.5 |
| `:252` `softTissueInjuryCount: 0`, `:253` `daysSinceLastInjury: nil` | derived from qualifying niggles (28d) | Soft-tissue fatigue component (0.10 weight) becomes real |
| `Outcome` 4 cases (recovery/wellness/completion/pain) | + `.niggleSeverity` (5th, graded 0–10) | Phase-27 Strain-Risk gets a localized validation target; Phase 24 D-07 contract slot filled |
| No niggle model | `SorenessLog` local-only @Model | Localized breakdown capture, never synced |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Adding `SorenessLog` to `Schema([...])` triggers SwiftData lightweight migration with no `MigrationPlan` (matches Phase-24 `ShadowArmPrediction` precedent) | §1 | If destructive, on-disk store fails to open on upgrade — but precedent (ShadowArmPrediction added same way) strongly supports lightweight. [VERIFIED against precedent, ASSUMED for the new model's exact field set] |
| A2 | D-12 intends all 14 days passed to `recentWellnessScores` (engine doc says 7) — slope works for 14 | §4 | Mild: if planner wants strict 7-parity, apply `.suffix(7)`. Confirm at plan-review. [ASSUMED from D-12 wording] |
| A3 | "distinct active niggles" (D-10) = qualifying logs in window, no region-dedup, no resolution tracking (deferred) | §4 | Over-count if same region logged repeatedly; mitigated by 0.10 weight + saturating count. Confirm interpretation. [ASSUMED] |
| A4 | `.niggleSeverity` row resolves (actual=0) even when no niggle exists on targetDay (like `completionActual`) | §3 | If planner wants nil-when-absent, the label becomes sparse not dense (contradicts D-04 "0 if none"). [VERIFIED intent from D-04; ASSUMED on the resolution-marker behavior] |
| A5 | Both existing arms should return `nil` (not 50.0) for `.niggleSeverity` | §3 | Storing a 50.0 prediction on a 0–10 scale would pollute future metrics. Recommend nil. [ASSUMED — planner confirms] |
| A6 | iOS 26.1 in-memory SwiftData optional-to-one-relationship `#Predicate` trap still applies to `SorenessLog` fetches | §6 | If it no longer traps, tests need not skip; if it does and tests don't skip, suite crashes. Mitigate by testing the pure helper with plain arrays. [VERIFIED trap exists for existing tests; ASSUMED it applies to the new model's predicate] |

---

## Open Questions

1. **Severity-control reuse vs. new.** `WellnessSlider` is 1–5 hardcoded. Generalize to a `range`/`ClosedRange<Int>` parameter, or build a separate 0–10 control?
   - Known: the segment-`Rectangle` pattern is reusable.
   - Recommendation: generalize `WellnessSlider` with an optional range param (keeps one primitive). Discretion clause permits slider or stepper.

2. **Nudge ordering vs. spike/PR branches.** `saveSession` early-`return`s for spike (521–524) and PR (526–530). Where does the niggle nudge sit so it never collides and never blocks?
   - Recommendation: trigger after those flows resolve, or only when neither fires; present post-`dismiss`. Confirm at plan-review.

3. **Region capture granularity confirmation.** Recommend 7-region picker storing `MuscleGroup` rawValue. Confirm the planner does NOT want the full 33-option list in the quick nudge (friction).

4. **`recentWellnessScores` 7 vs 14.** D-12 says 14; engine doc says 7. Confirm pass-14 (recommended) vs `.suffix(7)`.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| SwiftUI / SwiftData / Foundation / XCTest | Entire phase | ✓ (in project) | iOS 17+ SDK | — |
| Xcode build + test target | Build, tests | ✓ | latest | — |

No external dependencies. No `npm`/`pip`/`cargo`. No web/network requirement. **Package Legitimacy Audit: N/A (zero external packages).**

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (Apple, in-project) |
| Config file | none — Xcode test target `WorkloadAppTests` |
| Quick run command | `xcodebuild test -scheme "workload management" -only-testing:WorkloadAppTests/<NewTestClass> -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'` |
| Full suite command | `xcodebuild test -scheme "workload management" -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'` |

### Phase Requirements → Test Map
| Req | Behavior | Test Type | File Exists? |
|-----|----------|-----------|-------------|
| D-01/02/03 | `SorenessLog` persists | SwiftData in-mem | ❌ Wave 0 — new `SorenessLogModelTests.swift` |
| D-04/06 | `.niggleSeverity` resolves max-in-window, 0 if none, no leak | pure helper + SwiftData (skip-pattern) | ❌ Wave 0 — extend `ShadowDataContractTests`/new |
| D-10/11 | injury-count + DOMS exclusion + days-since | pure | ❌ Wave 0 — new `NiggleInjuryDeriverTests.swift` |
| D-12 | wellness 14d into FatigueInput | pure/SwiftData | ❌ Wave 0 |

### Wave 0 Gaps
- [ ] `SorenessLogModelTests.swift` — model persistence (register `SorenessLog` in test container schema; use XCTSkip pattern for any optional-relationship predicate)
- [ ] `NiggleInjuryDeriverTests.swift` — pure derivation incl. DOMS-exclusion, severity-only, impact-only, window-edge, empty cases
- [ ] `.niggleSeverity` outcome tests — extend `ShadowDataContractTests.swift` / `ShadowAnalyticsServiceTests.swift` (mirror existing skip pattern)
- [ ] No new framework install needed.

---

## Security Domain

No new authentication, session, access-control, cryptography, or network surface. The new model is **local-only / never-synced** (privacy posture preserved — no HealthKit-raw or PII leaves device; the niggle log stays on-device by SyncService omission). No input is transmitted. `V5 Input Validation`: severity is constrained 0–10 by the UI control; note is an optional free-text String (no injection surface — local SwiftData, no SQL/network). No ASVS category beyond on-device data-minimization applies; this phase strengthens privacy (more sensitive health-adjacent data that explicitly never syncs).

---

## Sources

### Primary (HIGH confidence — direct code reads)
- `WorkloadApp/Services/ShadowPredictor.swift:22–182` — `Outcome` enum (25–30), `ExperimentalArm` (147–155), `registeredArms` (165–181), `phaseOffset` switch (113–128)
- `WorkloadApp/Services/ShadowAnalyticsService.swift:1–336` — `recordPrediction` (41–113), `series(for:)` (65–72), `resolveOutcomes` target-day join (130–176, esp. 160–168 `painActual`), `fetchWellnessByDay` (178–203), `aggregate` (211–238), `metricsReport`/`pairs` (255–299), `pairedMAEDifferenceCI` (305–335)
- `WorkloadApp/Models/CyclePredictionLog.swift:28–160` — local-only @Model, date-contract fields, actual columns (65–79), arm-store helper (156–159)
- `WorkloadApp/Models/ShadowArmPrediction.swift:16–63` — local-only child @Model exemplar, `outcomeRaw(for:)` (55–62)
- `WorkloadApp/Services/SyncService.swift:21,66,295–306,808–1374` — push/pull-by-model + `*Row: Codable` DTO convention; exclusion-by-omission verified (no niggle/cycle/shadow type present)
- `WorkloadApp/Services/FatigueIndexEngine.swift:22–43` (`FatigueInput`), 169–238 (`compute`), 242–256 (pure helper pattern), 327–343 (`computeSoftTissueRisk`)
- `WorkloadApp/ViewModels/DashboardViewModel.swift:64–300` — `load()`, hardcoded inputs 236/252/253, surrounding scope 115/182/219/222–235, cold-start guard 238–263
- `WorkloadApp/App/WorkloadApp.swift:70–93` — `Schema([...])` (20 entities incl. `ShadowArmPrediction`), `ModelConfiguration(isStoredInMemoryOnly: false)`
- `WorkloadApp/Models/WellnessCheckIn.swift:4–43` — existing soreness/wellnessScore (don't duplicate)
- `WorkloadApp/Models/Enums.swift:177–211` (`MuscleRegion`, 7), 221–363 (`MuscleGroup`, 33 + `region`/`suggestedSpecific`), 538–562 (`BodyRegion`, joints)
- `WorkloadApp/Components/CardStyle.swift:15–155` — `Spacing`, `CardStyle`, `SectionHeader`, `SectionContainer`, `RowSeparator`, `DesignToggleStyle`, `MenuChevron`
- `WorkloadApp/Views/Recovery/MorningCheckInSheet.swift:27–301` — sheet pattern + `WellnessSlider`
- `WorkloadApp/Views/Dashboard/DashboardView.swift:18–20,200–223` — sheet flags + `.sheet` hooks
- `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift:448–539` — `saveSession` + post-save branches
- `WorkloadApp/Services/RecoveryPipeline.swift:177–250` — shadow record/resolve call site + feature-cutoff guards
- `WorkloadAppTests/ShadowAnalyticsServiceTests.swift:20–22,130,179`, `ShadowDataContractTests.swift:35–102`, `FatigueIndexEngineCycleTests.swift:1–45` — test conventions + iOS 26.1 in-memory XCTSkip trap

### Secondary
- `.planning/phases/24-validation-data-contract/24-CONTEXT.md` (date-contract D-01..D-03, D-07 injury-slot deferral, D-14 privacy)
- `.planning/phases/25-soreness-tweak-self-log/25-CONTEXT.md` (D-01..D-13)

### Tertiary
- None (no web search; internal phase).

---

## Metadata

**Confidence breakdown:**
- Data model + local-only pattern: HIGH — exact exemplars (`ShadowArmPrediction`, `CyclePredictionLog`) read in full; sync exclusion verified by grep.
- Outcome wiring: HIGH — every `switch outcome` ripple site enumerated with line numbers; nil-tolerance verified in `aggregate`/`metricsReport` guards.
- Fatigue wiring: HIGH — exact `FatigueInput` field types/units read; one units nuance (7 vs 14, 28d vs 12mo) flagged as a confirm-at-plan-review item, not a blocker.
- UI: HIGH — primitives and hook points read directly; nudge-ordering vs. spike/PR branches flagged as an open sequencing question.
- Tests: HIGH — conventions + the iOS 26.1 in-memory trap verified; mitigation (pure-array helper) identified.

**Research date:** 2026-05-30
**Valid until:** 2026-06-29 (stable — internal codebase; revalidate only if Phase 24 harness or `FatigueInput` shape changes before Phase 25 executes)
