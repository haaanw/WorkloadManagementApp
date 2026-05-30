# Phase 25 Plan Check — Pre-Execution Goal-Backward Review

**Checked:** 2026-05-30
**Plans:** 25-01, 25-02, 25-03, 25-04
**Gate:** Revision Gate (max 3 iterations)
**Verdict:** PASS WITH FLAGS (no blockers — execution may proceed; 3 warnings recommended for revision)

---

## Verdict Summary

| Plan | Wave | Tasks | Files | Status |
|------|------|-------|-------|--------|
| 25-01 (model + enum + repo) | 1 | 2 | 5+pbxproj | PASS |
| 25-02 (.niggleSeverity outcome) | 2 | 2 | 5 | PASS (1 warning) |
| 25-03 (fatigue/wellness wiring) | 2 | 2 | 3+pbxproj | PASS (1 warning) |
| 25-04 (UI sheet + affordance + nudge) | 2 | 3 | 3+pbxproj | PASS (1 warning) |

No BLOCKERS. Three WARNINGs. The phase goal IS achieved by the four plans together.

---

## 1. Goal Coverage — PASS

Every D-01..D-13 traces to a concrete task:

| Decision | Plan/Task | Coverage |
|----------|-----------|----------|
| D-01 new local-only @Model | 25-01 T1 | COVERED (no Codable, absent from SyncService) |
| D-02 fields | 25-01 T1 | COVERED (region/type/severity/limited/note/id/date/athlete) |
| D-03 limitedTraining required default-false | 25-01 T1 | COVERED |
| D-04 .niggleSeverity graded 0-10, 0 if none | 25-02 T1+T2 | COVERED |
| D-05 don't touch .pain, no binary outcome | 25-02 T1 (byte-unchanged .pain assertion) | COVERED |
| D-06 date-contract resolution, no same-day leak | 25-02 T2 (targetDate-only join) | COVERED |
| D-07 on-demand Dashboard affordance | 25-04 T2 | COVERED |
| D-08 non-blocking post-workout nudge | 25-04 T2 | COVERED |
| D-09 separate sheet, not in MorningCheckIn | 25-04 T1 | COVERED |
| D-10 softTissueInjuryCount + DOMS exclusion | 25-03 T1 | COVERED |
| D-11 daysSinceLastInjury | 25-03 T1 | COVERED |
| D-12 14d wellness fetch | 25-03 T2 | COVERED |
| D-13 named tunable constants | 25-03 T1 (qualifyingSeverityCut=7, injuryWindowDays=28) | COVERED |

No deferred ideas leak in (binary outcome explicitly excluded D-05; no resolution tracking; no daily nag; no history view). Both halves of the goal (niggle log + fatigue wiring) and the validation-outcome slot are all delivered.

---

## 2. Atomicity + Ordering — PASS

- Wave 1: 25-01 (model foundation), depends_on [].
- Wave 2: 25-02, 25-03, 25-04 — all depends_on [25-01] only. No cross-dependencies among the three wave-2 plans (verified: 03 and 04 do not depend on 02).
- No cycles, no forward references, wave numbers consistent.

**File-conflict audit (wave 2 parallel writes):**
- 25-02 → ShadowPredictor, ShadowArmPrediction, CyclePredictionLog, ShadowAnalyticsService, ShadowDataContractTests — DISJOINT from 03 and 04.
- 25-03 → NiggleInjuryDeriver, DashboardViewModel, NiggleInjuryDeriverTests.
- 25-04 → NiggleLogSheet, DashboardView, ActiveWorkoutSheet.
- **DashboardViewModel.swift (03) vs DashboardView.swift (04)** — DIFFERENT files; no conflict.
- **Shared write: project.pbxproj** — 25-01, 25-03, 25-04 all add file references. This is the known shared-registry hazard; if executed truly in parallel, concurrent pbxproj edits can clobber. Mitigated because 25-01 is Wave 1 (serial before the others). Among wave-2 plans, 25-03 and 25-04 both touch pbxproj — see WARNING-2.

---

## 3. Date-Contract Safety (.niggleSeverity) — PASS

Verified against actual code (ShadowAnalyticsService.swift:158-173):
- Join uses `let day = calendar.startOfDay(for: row.targetDate)` (line 160) — TARGET day only. 25-02 T2 explicitly forbids any join on row.date/row.predictionDate and adds a no-same-day-leak regression test. CORRECT.
- `painActual` (line 165) is set INSIDE `if let w = wellnessByDay[day]` (requires a check-in). `completionActual` (line 168) is set UNCONDITIONALLY and the row resolves regardless (resolvedAt line 170). 25-02 correctly models `.niggleSeverity` after `completionActual` (`?? 0.0`, always resolvable) — NOT after painActual — giving the dense "0 if none" label per D-04. The plan's placement instruction (sibling of completionActual, not nested in the wellness if-let) is precise and structurally correct.
- Late-day bucketing test (niggle dated late on D+1 still buckets to startOfDay(D+1)) is included.

No leak path. Mirrors painActual's target-day join while correctly diverging on the dense-label resolution.

---

## 4. Local-Only Invariant — PASS

25-01 enforces all four pillars in the Task 1 action + acceptance criteria:
- No Codable on the @Model (grep assertion in acceptance).
- No *Row DTO / push*/pull* / name absent from SyncService.swift (grep assertion).
- Dual-target pbxproj membership (SorenessLog → app target; SorenessLogModelTests → WorkloadAppTests).
- Test-schema registration in the NEW SorenessLogModelTests container.
25-02's new `niggleSeverityActual: Double?` is added to the already-local-only CyclePredictionLog (additive, no Codable) — verified that CyclePredictionLog is absent from SyncService. The repository (25-01 T2) and the UI write path (25-04) introduce no sync surface (re-asserted by grep). PASS.

---

## 5. Honest Framing + DESIGN — PASS

25-04 T1/T2 forbid "injury"/"prediction"/"diagnos" strings (grep assertion in verify + acceptance) and require 0pt corners (no RoundedRectangle), no .shadow(, no .system(, `.toggleStyle(.design)` for the limited-training toggle, Font.Tokens/ColorTokens only. The human checkpoint (T3) re-verifies accent-only-on-hero, square corners, honest copy, and the non-blocking nudge. PASS.

---

## 6. Verification Realism — PASS

Every plan's tasks end with a REAL `xcodebuild test`/`xcodebuild build` on the correct project ("workload management.xcodeproj"), scheme ("workload management"), and a concrete simulator id (8E872500-...). Plans explicitly warn that SourceKit "cannot find type"/"non-exhaustive switch" diagnostics are STALE and only xcodebuild proves green — good discipline. Acceptance criteria are measurable (grep assertions, exit-0, specific test names). Pure-helper tests (25-03) correctly avoid SwiftData to sidestep the iOS 26.1 in-memory `#Predicate` trap. PASS.

---

## 7. FatigueIndexEngine 14-vs-7 Risk — RESOLVED (not a latent bug)

VERIFIED against RecoveryScoreEngine.computeSlope (RecoveryScoreEngine.swift:197-210):
- computeSlope uses x-indices 0,1,2,...,n-1 (day indices) and returns a per-day OLS slope.
- The slope unit is points/day and is mathematically stable regardless of array length (gated on count>=2; FatigueIndexEngine gates the wellness component on count>=3, line 205).
- computeWellnessTrendFatigue (line 317) maps `0.5 - slope/6.0` — a per-day-slope mapping, so a 14-element array yields a steadier trend over a longer window, NOT a corrupted value.

**Conclusion:** passing 14 days (D-12) is SAFE. The 25-03 note to "verify the engine tolerates a 14-element array" is adequate AND now confirmed correct by the checker. Not a latent bug.

---

## Warnings (recommended fixes; non-blocking)

### WARNING-1 [dependency_correctness / task_completeness] — 25-02 test-schema registration gap
25-02 Task 2 writes `.niggleSeverity` resolution tests into `ShadowDataContractTests.swift`, which inserts/fetches SorenessLog rows through that file's ModelContainer (schema at ShadowDataContractTests.swift:18-21). That schema does NOT include `SorenessLog.self`, and NEITHER 25-01 nor 25-02 has an explicit task action to add it there. 25-01 only registers SorenessLog.self in its OWN new SorenessLogModelTests container; 25-01's must_haves claims "every test ModelContainer schema that needs it" but the binding action does not cover ShadowDataContractTests. If the 25-02 test inserts a SorenessLog into a container whose Schema omits SorenessLog.self, SwiftData fatalErrors at runtime ("model not in schema"). The executor will hit the failure and burn a revision cycle.
- **Fix:** Add to 25-02 Task 2 action: "Register `SorenessLog.self` in the `ShadowDataContractTests.swift` Schema array (line ~21) before inserting SorenessLog rows in tests." (Or move the niggle-resolution grouping assertion to a pure helper over `[SorenessLog]` arrays, which avoids needing it in the container at all — already the plan's stated preference, so just make that the REQUIRED path, not an "or".)
- Anchor: 25-02-PLAN.md Task 2 <action>; WorkloadAppTests/ShadowDataContractTests.swift:18-21.

### WARNING-2 [scope_sanity / pbxproj contention] — wave-2 parallel pbxproj writes (03 + 04)
Both 25-03 (adds NiggleInjuryDeriver.swift + test file) and 25-04 (adds NiggleLogSheet.swift) edit `project.pbxproj` in the same wave. Truly-parallel execution can clobber concurrent pbxproj edits (the known shared-registry hazard the user flagged). 25-01's pbxproj edit is safe (Wave 1, serial). 25-02 touches no new files (no pbxproj edit). The collision surface is only 03 vs 04.
- **Fix (orchestrator-level):** Serialize the pbxproj-touching wave-2 plans (run 03 then 04, or have the executor re-read pbxproj before each membership add). No plan-text change strictly required if the orchestrator already serializes pbxproj writes — flag so it is not assumed away.
- Anchor: 25-03-PLAN.md files_modified pbxproj; 25-04-PLAN.md files_modified pbxproj.

### WARNING-3 [scope_sanity] — 25-03 wellness fetch may run during cold-start
DashboardViewModel.swift:236 (`recentWellnessScores`) sits ABOVE the `if isColdStartActive` block (verified). 25-03 T2 says the wellness fetch "may sit just above the if/else ... keep it cheap or guard it." An unguarded 14-day WellnessCheckIn fetch would then execute on every cold-start load, contradicting the plan's own must_have "cold-start does no extra work." Soft wording invites a needless fetch.
- **Fix:** Make 25-03 T2 REQUIRE the wellness fetch be moved INSIDE the non-cold-start `else` branch (alongside the niggle fetch), or explicitly guarded by `!isColdStartActive`. Change "keep it cheap or guard it" to "guard it."
- Anchor: 25-03-PLAN.md Task 2 <action>; DashboardViewModel.swift:236-263.

---

## Context Compliance — PASS
All locked decisions implemented; no deferred ideas present; discretion areas (region granularity, slider-vs-stepper, affordance shape, constant values) handled within bounds. No scope-reduction language ("v1/static/placeholder/stub") used to dodge any decision — the "v1" references are the user's own deferral framing (binary outcome, resolution tracking), not silent simplification.

## Architectural Tier Compliance — PASS
Matches RESEARCH Architectural Responsibility Map: persistence in @Model+repo, outcome resolution in @MainActor service, derivation in pure struct (NiggleInjuryDeriver, NOT in ViewModel), UI in views. Correct.

## CLAUDE.md Compliance — PASS
iOS pbxproj dual-target rule enforced per task; DESIGN.md contract enforced in 25-04; pure-struct-engine + @MainActor-repo conventions followed; HealthKit-raw never synced (niggle local-only).
