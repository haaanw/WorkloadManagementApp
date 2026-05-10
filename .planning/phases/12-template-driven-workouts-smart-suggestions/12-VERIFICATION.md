---
phase: 12-template-driven-workouts-smart-suggestions
verified: 2026-05-10T00:00:00Z
status: human_needed
score: 5/5
overrides_applied: 0
---

# Phase 12: Template-Driven Workouts & Smart Suggestions — Verification Report

**Phase Goal:** Athletes can start sessions from templates in one tap with auto-filled targets, and the app learns their schedule to suggest the right template at the right time
**Verified:** 2026-05-10
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can select a saved template when starting a new session via a template picker accessible from the "+" button | VERIFIED | `WorkoutLogView.swift` toolbar "+" sets `showTemplatePicker = true`; `TemplatePickerSheet.swift` presents template grid with `onSelectTemplate` callback wiring to `ActiveWorkoutSheet(template:)` |
| 2 | Template-loaded session pre-fills exercises with last-used actual values as ghost targets | VERIFIED | `loadFromTemplate()` in `ActiveWorkoutSheet.swift` (line 377) populates `SetDraft.targetReps`/`targetWeightKg`/`targetRPE` from history; actual `reps`/`weightKg`/`rpe` remain nil; `saveSession()` reads only from actual fields — ghost values cannot auto-save |
| 3 | Dashboard and workout log tab show favorite/recent templates as quick-start cards for one-tap session start | VERIFIED | `QuickStartSection` struct added to `DashboardView.swift` (line 593), appears below `HeroReadinessCard`, uses `sheet(item:)` pattern with `ActiveWorkoutSheet(template:)`; `TemplateCarouselSection` has `onStartFromTemplate` callback wired in `WorkoutLogView` |
| 4 | When loading a template, ProgressionEngine overlays recovery-aware suggested targets alongside last-used values (Pro-gated) | VERIFIED | `loadFromTemplate()` calls `ProgressionEngine.suggest()` behind `isPro` guard (line 426); `FillButtonBar` "Fill suggested" button Pro-gated (line 951); `SetEntryRow` renders progression label per exercise |
| 5 | TemplateSuggestionEngine suggests the most likely template based on day-of-week usage patterns when the user opens the app (Pro-gated, requires 2+ weeks of usage data) | VERIFIED | `TemplateSuggestionEngine.swift` is a pure struct with `suggest()` returning nil when < 3 sessions in 14-day window; carousel calls `computeSuggestion()` on appear (Pro-gated); "SUGGESTED"/"RECOVERY-ADJUSTED" badge rendered on carousel card and QuickStartSection |

**Score: 5/5 truths verified**

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `WorkloadApp/Services/TemplateSuggestionEngine.swift` | Day-of-week frequency analysis + recovery-aware template suggestion | VERIFIED | 200-line pure struct; `suggest()`, `isoWeekday()`, `pickByFrequency()`, `findLighterAlternative()` all present; imports only `Foundation` |
| `WorkloadApp/Models/WorkoutSession.swift` | `sourceTemplateId` field for session-template linkage | VERIFIED | Line 15: `var sourceTemplateId: UUID? = nil` |
| `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift` | Template loading, ghost targets, fill buttons, progression overlay, template usage tracking | VERIFIED | `template: WorkoutTemplate?` init param; `loadFromTemplate()` method; `FillButtonBar` struct; `progressionSuggestions` on `ExerciseEntryDraft`; `saveSession()` sets `sourceTemplateId`, updates `lastUsedAt`/`usageCount` |
| `WorkloadApp/Views/WorkoutLog/TemplatePickerSheet.swift` | Template selection sheet opened from '+' button | VERIFIED | `struct TemplatePickerSheet: View` with `onSelectTemplate`/`onStartBlank`/`onCreateTemplate` callbacks; empty state; 2-column grid; "Start blank workout" always visible |
| `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift` | '+' button redirect and template-start wiring | VERIFIED | `showTemplatePicker` state; '+' button sets `showTemplatePicker = true`; `TemplatePickerSheet` sheet binding; `selectedTemplateForSession` passed to `ActiveWorkoutSheet` |
| `WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift` | Tap-to-start behavior and suggestion badges | VERIFIED | `onStartFromTemplate` callback (renamed from `onPreviewTemplate`); `.onTapGesture` calls `onStartFromTemplate`; context menu "Preview" option; `suggestionResult` state; "SUGGESTED"/"RECOVERY-ADJUSTED" badge |
| `WorkloadApp/Views/Dashboard/DashboardView.swift` | Quick-start card section | VERIFIED | `QuickStartSection` inserted after `HeroReadinessCard`; `sheet(item: $quickStartTemplate)`; hidden when no templates via `if !templates.isEmpty` guard inside `QuickStartSection.body` |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `TemplateSuggestionEngine` | `WorkoutTemplate` | `templates` input param | WIRED | `templates: [WorkoutTemplate]` accepted, indexed by `id` in `pickByFrequency` |
| `TemplateSuggestionEngine` | `WorkoutSession` | `sourceTemplateId` | WIRED | `session.sourceTemplateId` read in `pickByFrequency` (line 106) and `findLighterAlternative` (line 144) |
| `ActiveWorkoutSheet.loadFromTemplate` | `ProgressionEngine.fetchHistory` | fetches last-used values per exercise | WIRED | Line 396: `ProgressionEngine.fetchHistory(exerciseName: exercise.exerciseName, modelContext: modelContext)` |
| `ActiveWorkoutSheet.loadFromTemplate` | `ProgressionEngine.suggest` | computes progression suggestions for Pro users | WIRED | Lines 427-437: called when `isPro` and `history` non-empty |
| `ActiveWorkoutSheet.saveSession` | `sourceTemplate.lastUsedAt` | updates template usage on save | WIRED | Lines 516-520: `source.lastUsedAt = .now`, `source.usageCount += 1`, `source.updatedAt = .now` |
| `TemplatePickerSheet` | `ActiveWorkoutSheet(template:)` | `onSelectTemplate` callback | WIRED | `WorkoutLogView` wires `onSelectTemplate` to set `selectedTemplateForSession` then open `showActiveWorkout`; `ActiveWorkoutSheet` receives `template: selectedTemplateForSession` |
| `TemplateCarouselSection` | `ActiveWorkoutSheet(template:)` | `onStartFromTemplate` callback | WIRED | `WorkoutLogView` wires `onStartFromTemplate` to set `selectedTemplateForSession = template` then `showActiveWorkout = true` |
| `DashboardView QuickStartSection` | `ActiveWorkoutSheet(template:)` | `sheet(item:)` with `quickStartTemplate` | WIRED | Line 171-174: `sheet(item: $quickStartTemplate) { template in ActiveWorkoutSheet(template: template) }` |
| `TemplateCarouselSection` | `TemplateSuggestionEngine.suggest` | computes suggested template for badge | WIRED | `computeSuggestion()` called on `.onAppear`; line 398: `TemplateSuggestionEngine.suggest(...)` |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `TemplateSuggestionEngine.suggest()` | `windowSessions` | filtered from `recentSessions` parameter | Yes — caller fetches real SwiftData sessions | FLOWING |
| `loadFromTemplate()` ghost targets | `history` from `ProgressionEngine.fetchHistory` | SwiftData `ExerciseEntry`/`SetRecord` query | Yes — real persisted actuals from prior sessions | FLOWING |
| `QuickStartSection.quickStartTemplates` | `favorites` | `TemplateRepository.fetchFavorites` SwiftData query; fallback to `fetchAthleteTemplates` | Yes — real template records | FLOWING |
| `TemplateCarouselSection` suggestion badge | `suggestionResult` | `TemplateSuggestionEngine.suggest` with live session fetch | Yes — fetches `WorkoutSession` via `modelContext.fetch` | FLOWING |

---

### Behavioral Spot-Checks

| Behavior | Check | Result | Status |
|----------|-------|--------|--------|
| `TemplateSuggestionEngine.suggest()` returns nil with < 3 sessions | Code audit: `guard windowSessions.count >= 3 else { return nil }` (line 43) | Guard present and correct | PASS |
| Ghost targets stored in target fields, not actual fields | `loadFromTemplate()` sets `targetReps`/`targetWeightKg`/`targetRPE`; `reps`/`weightKg`/`rpe` remain nil | SetDraft init with nil actuals confirmed lines 405-410 | PASS |
| `saveSession()` reads actual fields only | `setDraft.reps`, `setDraft.weightKg`, `setDraft.rpe` passed to `SetRecord` — never target fields | Lines 480-487 confirmed | PASS |
| "Fill suggested" is Pro-gated | `if isPro { Button { fillSuggested() } }` in `FillButtonBar` | Line 951 confirmed | PASS |
| Commits exist in git history | All 6 plan commits present | `c6096b4`, `2fe39f9`, `e1054db`, `ee11063`, `af57fe8`, `3f7254a` confirmed | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| TMPL-03 | 12-02, 12-03 | User can select a saved template when starting a new session via template picker from "+" button | SATISFIED | `TemplatePickerSheet` + `WorkoutLogView` '+' redirect |
| TMPL-04 | 12-02 | Template-loaded session pre-fills exercises with last-used actual values as ghost targets | SATISFIED | `loadFromTemplate()` ghost target mechanism in `ActiveWorkoutSheet` |
| TMPL-06 | 12-03 | Dashboard and workout log tab show favorite/recent templates as quick-start cards | SATISFIED | `QuickStartSection` in `DashboardView`; carousel `onStartFromTemplate` |
| TMPL-07 | 12-02 | ProgressionEngine overlays recovery-aware suggested targets alongside last-used values (Pro-gated) | SATISFIED | `ProgressionEngine.suggest()` in `loadFromTemplate()`, `FillButtonBar` "Fill suggested", `SetEntryRow` suggestion label |
| TMPL-08 | 12-01, 12-03 | TemplateSuggestionEngine learns day-of-week patterns and suggests template (Pro-gated, 2+ weeks) | SATISFIED | `TemplateSuggestionEngine.swift`; carousel badge; `QuickStartSection` Pro suggestion card |

All 5 requirements claimed by Phase 12 plans are satisfied. No orphaned requirements found (TMPL-01, TMPL-02, TMPL-05 correctly assigned to Phase 11; no Phase 12 requirement IDs missing from plans).

---

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| None found | — | — | — |

No TODOs, FIXMEs, stub returns, placeholder text, or hardcoded empty collections found in any phase 12 artifacts.

---

### Human Verification Required

Plan 12-03, Task 3 was defined as a `gate: blocking` human-verify checkpoint. The SUMMARY claims "Human verification: approved" but this is self-reported by the executor. Because the phase involves:

1. Visual ghost target rendering in text fields (gray placeholder appearance)
2. Fill button placement and behavior (above exercise list, copies fields correctly)
3. Carousel tap-to-start vs long-press differentiation
4. Dashboard quick-start card layout at 140pt width

These cannot be verified programmatically without running the Simulator.

#### 1. Ghost Target Placeholder Appearance

**Test:** Open app in Simulator. Start a template-loaded session for a template with prior session history. Inspect exercise weight/reps/RPE input fields.
**Expected:** Fields appear empty (no typed value) but show gray placeholder text with last-used values (e.g., placeholder "80" for weight, "5" for reps).
**Why human:** SwiftUI TextField placeholder rendering color and behavior cannot be confirmed from grep/file inspection alone.

#### 2. Fill Last Button Populates All Fields

**Test:** With a template-loaded session showing ghost placeholders, tap "Fill last" button.
**Expected:** All weight/reps/RPE fields across all exercises populate with the ghost values simultaneously.
**Why human:** Functional behavior of `fillLast()` iterating all entries requires runtime verification.

#### 3. Carousel Tap vs Long-Press Behavior

**Test:** Go to Workout Log tab. Tap a carousel card that is centered (not to center it, but the already-centered one). Then long-press a card.
**Expected:** Tap opens `ActiveWorkoutSheet` pre-filled. Long-press shows context menu with "Preview" as first item.
**Why human:** `.onTapGesture` + `.contextMenu` interaction in SwiftUI can conflict; centering state affects which action fires.

#### 4. Dashboard Quick-Start Section Position and Appearance

**Test:** Go to Dashboard tab with at least one template created. Check layout below the readiness hero card.
**Expected:** Horizontal scrollable row of 140pt-wide cards appears immediately below the hero card, hidden if zero templates exist.
**Why human:** VStack ordering, conditional visibility, and card dimensions require visual inspection.

---

### Gaps Summary

No gaps found. All 5 roadmap success criteria are verified against the codebase. All 5 requirement IDs (TMPL-03, TMPL-04, TMPL-06, TMPL-07, TMPL-08) are satisfied. All key artifacts exist, are substantive, and are wired. Data flows from real SwiftData queries through all rendering paths.

Status is `human_needed` because Phase 12 includes a blocking human-verify checkpoint (Plan 03, Task 3) covering visual behavior that cannot be confirmed from static analysis. The executor's summary claims this was approved, but independent verification requires running the Simulator.

---

_Verified: 2026-05-10_
_Verifier: Claude (gsd-verifier)_
