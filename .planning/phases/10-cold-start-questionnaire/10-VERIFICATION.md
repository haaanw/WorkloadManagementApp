---
phase: 10-cold-start-questionnaire
verified: 2026-05-02T15:00:00Z
status: human_needed
score: 5/5
overrides_applied: 0
human_verification:
  - test: "Open app as new user (no WorkloadSnapshot), verify TrainingProfileCard appears on dashboard with correct copy"
    expected: "Dashboard shows card with 'TRAINING PROFILE' micro-caps header, 'Set up your training profile' title, description copy, and 'Complete Profile' button"
    why_human: "Visual layout and text rendering cannot be verified programmatically; card placement between WelcomeActionCard and EmptyStateCard requires live UI inspection"
  - test: "Tap 'Complete Profile', fill 4 required fields, verify Save button enables and saves profile"
    expected: "Save Profile button is disabled until all 4 required fields are non-nil. After saving, sheet dismisses, dashboard shows estimated ATL/CTL/ACWR/TSB with 'EST' label below each value, TrainingProfileCard disappears"
    why_human: "Form interaction state and conditional button enablement require live UI testing; EST annotation rendering requires visual confirmation"
  - test: "Verify 'Building baseline...' appears where FatigueAttentionBanner would normally be during cold-start"
    expected: "When isColdStartActive is true, the area above TrainingLoadSection shows 'Building baseline...' with label font, text2 color, surface background, hairline border — no FatigueAttentionBanner"
    why_human: "Conditional UI placement and visual styling (font size, color, border) require visual inspection"
  - test: "Open ProfileView, verify TRAINING PROFILE section appears between ATHLETE and PREFERENCES"
    expected: "Section shows 4 rows (Sessions / week, Avg duration, Typical effort, Weeks at level) if profile exists, or 'Set up training profile' button if not. 'Edit Profile' opens TrainingProfileSheet with pre-filled values"
    why_human: "Section ordering and pre-fill behavior require live app testing; re-edit flow validation is behavioral"
---

# Phase 10: Cold-Start Questionnaire Verification Report

**Phase Goal:** New athletes can answer a brief training questionnaire and immediately see estimated workload data on their dashboard, with automatic switchover to real data as they log sessions
**Verified:** 2026-05-02T15:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can complete 4 required questions (sessions/week, avg duration, typical sRPE, weeks at current level) via training profile card | VERIFIED | `TrainingProfileSheet.swift`: 4 `@State var?: Int? = nil` sentinel fields, `isFormValid` gates Save button via `.disabled(!isFormValid)`, all 4 picker rows implemented with correct ranges and sRPE labels |
| 2 | User can optionally answer 4 additional questions (training age, periodization preference, movement types, injury history) without blocking progress | VERIFIED | `TrainingProfileSheet.swift`: `trainingAgeYears`, `scheduleType`, `selectedMovementTypes: Set<SportType>`, `selectedBodyRegions: Set<BodyRegion>` + notes TextField — all optional, do not affect `isFormValid` |
| 3 | Dashboard displays estimated ATL/CTL values during cold-start window, and these values never appear on WorkloadSnapshot | VERIFIED | `DashboardViewModel.swift` L154-166: `isColdStartActive=true` branch sets `atl/ctl/acwr/tsb` from `profile.seededATL/seededCTL` for display only. No write to `WorkloadSnapshot`. `DashboardView.swift` L469-485: `isEstimated: viewModel.isColdStartActive` on all 4 `LoadStatCell` calls renders "EST" annotation |
| 4 | Dashboard automatically switches from estimated to real ATL/CTL after 3+ weeks AND 8+ sessions, with no user action required | VERIFIED | `WorkoutPipeline.swift` L87-105: After each session save, checks `weeksSinceSeeded >= 3 && totalSessionCount >= 8`, sets `profile.coldStartCompletedAt = .now` when threshold met. `DashboardViewModel.swift` L156-157: checks `profile.coldStartCompletedAt == nil` to remain in cold-start — once set, falls back to `isColdStartActive = false` |
| 5 | FatigueIndex shows "insufficient data" state during cold-start window instead of computing from incomplete baselines | VERIFIED | `DashboardViewModel.swift` L232-235: `if isColdStartActive { fatigueIndex = nil; fatigueZone = nil }`. `DashboardView.swift` L117-127: when `isColdStartActive`, renders "Building baseline..." card; `FatigueAttentionBanner` only renders when `!viewModel.isColdStartActive` |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|---------|--------|---------|
| `WorkloadApp/Repositories/TrainingProfileRepository.swift` | TrainingProfile CRUD repository | VERIFIED | `@MainActor final class TrainingProfileRepository` with `fetchProfile(athleteId:)`, `saveProfile(_:)`, `updateProfile(_:)`. 4 pbxproj entries confirmed. |
| `WorkloadApp/Views/Dashboard/TrainingProfileCard.swift` | Dashboard CTA card for questionnaire entry | VERIFIED | `struct TrainingProfileCard: View`, `let onComplete: () -> Void`, correct copy: "TRAINING PROFILE", "Set up your training profile", "Complete Profile". No `RoundedRectangle`, no `.shadow`, no `ColorTokens.accent`. 4 pbxproj entries confirmed. |
| `WorkloadApp/Views/Profile/TrainingProfileSheet.swift` | Questionnaire form sheet with 4 required + 4 optional fields | VERIFIED | `struct TrainingProfileSheet: View`, all 8 fields present, `isFormValid` gates Save, `ColdStartEngine.computeSeed(input:)` called on save, `TrainingProfileRepository` used for persistence, `existingProfile` re-edit path with `.onAppear` pre-fill. 4 pbxproj entries confirmed. |
| `WorkloadApp/ViewModels/DashboardViewModel.swift` | Cold-start data path with isColdStartActive flag | VERIFIED | `var isColdStartActive: Bool = false` at L27, cold-start fallback branch at L153-166, FatigueIndex suppression at L232-235. |
| `WorkloadApp/Views/Dashboard/DashboardView.swift` | EST annotations, TrainingProfileCard placement, FatigueIndex suppression, chart gating | VERIFIED | `@Query private var trainingProfiles`, `showTrainingProfileCard` computed property, `TrainingProfileCard` in body, `LoadStatCell.isEstimated` parameter, "Building baseline..." card, sheet presentation for `TrainingProfileSheet`. |
| `WorkloadApp/Services/WorkoutPipeline.swift` | Switchover check and bias capture after session save | VERIFIED | Switchover block at L82-105 sets `coldStartCompletedAt` at `weeksSinceSeeded >= 3 && totalSessionCount >= 8`. Bias block at L107-128 sets bias fields at `daysSinceSeeded >= 56`. `pushTrainingProfile` sync at L135. |
| `WorkloadApp/Views/Profile/ProfileView.swift` | Training Profile section with edit/setup action | VERIFIED | `sectionHeader("TRAINING PROFILE")` at L62, between ATHLETE (L39) and PREFERENCES (L85). Shows 4 summary rows + "Edit Profile" or "Set up training profile". Sheet presentation at L418-421 passes `existingProfile: trainingProfiles.first`. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `TrainingProfileSheet.swift` | `ColdStartEngine.swift` | `ColdStartEngine.computeSeed(input:)` in save handler | WIRED | L412-418: `let input = ColdStartEngine.SeedInput(...)`, `let result = ColdStartEngine.computeSeed(input: input)`, result used to set `seededATL/seededCTL` on profile |
| `TrainingProfileSheet.swift` | `TrainingProfileRepository.swift` | `saveProfile` / `updateProfile` call | WIRED | L435 `let repo = TrainingProfileRepository(...)`, L450 `try repo.updateProfile(existing)`, L475 `try repo.saveProfile(profile)` |
| `TrainingProfileCard.swift` | `TrainingProfileSheet.swift` | `onComplete` closure triggers sheet presentation | WIRED | `DashboardView.swift` L50: `TrainingProfileCard(onComplete: { showTrainingProfile = true })`, L167-169: `.sheet(isPresented: $showTrainingProfile) { TrainingProfileSheet() }` |
| `DashboardViewModel.swift` | `TrainingProfileRepository.swift` | `fetchProfile` in cold-start fallback branch | WIRED | L155-156: `let profileRepo = TrainingProfileRepository(...)`, `if let profile = try? profileRepo.fetchProfile(athleteId: athlete.id)` |
| `DashboardView.swift` | `DashboardViewModel.swift` | `isColdStartActive` drives EST label and chart visibility | WIRED | L117 `if viewModel.isColdStartActive`, L470/475/480/485 `isEstimated: viewModel.isColdStartActive` |
| `WorkoutPipeline.swift` | `TrainingProfile.swift` | Sets `coldStartCompletedAt` and bias fields | WIRED | L101 `profile.coldStartCompletedAt = .now`, L119-124 bias fields all set |
| `ProfileView.swift` | `TrainingProfileSheet.swift` | Presents `TrainingProfileSheet` for re-editing | WIRED | L418-421: `.sheet(isPresented: $showTrainingProfileSheet) { TrainingProfileSheet(existingProfile: trainingProfiles.first).environment(container) }` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| `DashboardView.swift` LoadStatCell | `viewModel.atl / ctl / acwr / tsb` | `DashboardViewModel.load()` → `TrainingProfileRepository.fetchProfile()` → `profile.seededATL/seededCTL` | Yes — seeded from `ColdStartEngine.computeSeed()` result persisted in `TrainingProfile` | FLOWING |
| `DashboardView.swift` "Building baseline..." | `viewModel.isColdStartActive` | `DashboardViewModel.load()` cold-start branch | Yes — boolean reflecting actual `coldStartCompletedAt == nil` check | FLOWING |
| `WorkoutPipeline.swift` switchover | `profile.coldStartCompletedAt` | `modelContext.fetch(profileDescriptor)` | Yes — reads live SwiftData profile | FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED — This phase produces SwiftUI views and pipeline logic requiring a live iOS Simulator to test. No runnable non-GUI entry points to check programmatically.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| COLD-01 | 10-01 | User can complete 4 required questions via training profile card | SATISFIED | `TrainingProfileSheet` has 4 required `@State Int? = nil` fields with `isFormValid` gate; `TrainingProfileCard` is the dashboard entry point |
| COLD-02 | 10-01 | User can optionally answer 4 additional questions | SATISFIED | `TrainingProfileSheet` has `trainingAgeYears`, `scheduleType`, `selectedMovementTypes`, `selectedBodyRegions` — all optional |
| COLD-04 | 10-02 | Estimated ATL/CTL on dashboard during cold-start, never on WorkloadSnapshot | SATISFIED | `DashboardViewModel` cold-start branch sets display properties only; no write to `WorkloadSnapshot`; `LoadStatCell` shows "EST" |
| COLD-05 | 10-03 | Auto-switchover after 3+ weeks AND 8+ sessions | SATISFIED | `WorkoutPipeline.processSession()` checks `weeksSinceSeeded >= 3 && totalSessionCount >= 8`, sets `coldStartCompletedAt = .now` |
| COLD-06 | 10-03 | Bias metric (estimated vs actual load) stored at 8-week mark | SATISFIED | `WorkoutPipeline.processSession()` checks `daysSinceSeeded >= 56`, captures `biasEstimatedATL/CTL` and `biasActualATL/CTL`, idempotent via `biasCapturedAt == nil` guard |
| COLD-07 | 10-02 | FatigueIndex shows "insufficient data" state during cold-start | SATISFIED | `DashboardViewModel` sets `fatigueIndex = nil` when `isColdStartActive`; `DashboardView` renders "Building baseline..." card |

**Note on COLD-03:** Assigned to Phase 9 in REQUIREMENTS.md traceability, not Phase 10. `ColdStartEngine.swift` exists and is called correctly by `TrainingProfileSheet`. This is correctly out of scope for Phase 10 verification.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `WorkloadApp/ViewModels/DashboardViewModel.swift` | 230 | `let recentWellnessScores: [Double] = []  // TODO: fetch from WellnessCheckIn history` | Info | Not introduced by Phase 10 — pre-existing stub for an unimplemented wellness feature. Does not affect cold-start functionality. |

No blockers or warnings found in Phase 10 files. No `RoundedRectangle`, no `.shadow`, no `ColorTokens.accent` in any Phase 10 modified file.

### Human Verification Required

#### 1. TrainingProfileCard visual rendering on dashboard

**Test:** Run app in simulator as a new user (no WorkloadSnapshot data). Navigate to Dashboard tab.
**Expected:** A card appears below any WelcomeActionCard with: "TRAINING PROFILE" in micro-caps (ColorTokens.text3), "Set up your training profile" in body font (ColorTokens.text1), description text in label font (ColorTokens.text2), and a full-width "Complete Profile" button with hairline border. Zero border radius, no shadows, correct 8pt spacing grid.
**Why human:** Visual layout, font rendering, and card placement in the VStack cannot be verified programmatically.

#### 2. Cold-start questionnaire form interaction

**Test:** Tap "Complete Profile" on dashboard (or "Set up training profile" in ProfileView). Observe form state.
**Expected:** (a) "Save Profile" button is disabled (greyed) with no fields selected. (b) After filling all 4 required fields, "Save Profile" becomes enabled. (c) After saving, sheet dismisses and dashboard shows ATL/CTL/ACWR/TSB with small "EST" label below each value. (d) TrainingProfileCard disappears from dashboard.
**Why human:** Button enable/disable transitions, EST annotation rendering below values, and TrainingProfileCard disappearance on profile creation require live UI interaction testing.

#### 3. "Building baseline..." during cold-start

**Test:** With a TrainingProfile saved but no real WorkloadSnapshot, observe the dashboard area above the Training Load section.
**Expected:** "Building baseline..." text appears in label font (ColorTokens.text2) with surface background and hairline border. No FatigueAttentionBanner visible.
**Why human:** Conditional rendering and visual styling of the "Building baseline..." card require live inspection.

#### 4. ProfileView Training Profile section

**Test:** Open Profile tab. Verify section placement and content.
**Expected:** "TRAINING PROFILE" section appears after the ATHLETE section and before the PREFERENCES section. If a profile exists, shows 4 summary rows with correct labels and values, plus "Edit Profile" button. If no profile, shows "Set up training profile" button. Tapping either opens TrainingProfileSheet with pre-filled values for re-edit.
**Why human:** Section ordering, summary row values, and pre-fill correctness require running the app with actual data.

### Gaps Summary

No gaps. All 5 roadmap success criteria are verified by code inspection. All 6 requirement IDs (COLD-01, COLD-02, COLD-04, COLD-05, COLD-06, COLD-07) have implementation evidence. All artifacts exist, are substantive, and are wired. Data flows from `ColdStartEngine` through `TrainingProfile` to dashboard display.

The only outstanding items are 4 human verification tasks requiring live simulator testing to confirm visual rendering, form interaction correctness, and conditional UI behavior. These are normal for a SwiftUI UI phase and do not indicate code deficiencies.

**ROADMAP status note:** The ROADMAP.md shows plan 10-02 as `[ ]` (not checked), but the SUMMARY and code confirm it was executed (commits `4eefbb7` and `e761003` match the described changes). The ROADMAP tracking appears stale and should be updated to `[x]` for 10-02 to reflect 3/3 plans complete.

---

_Verified: 2026-05-02T15:00:00Z_
_Verifier: Claude (gsd-verifier)_
