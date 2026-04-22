---
phase: 04-onboarding-polish
verified: 2026-04-22T06:30:00Z
status: gaps_found
score: 11/13 must-haves verified
overrides_applied: 0
gaps:
  - truth: "After signup, user sees a 3-step onboarding flow before reaching the Dashboard"
    status: failed
    reason: "AppRouter.needsOnboarding is only set inside the .task block, which fires once at app launch. When a new user completes signup via SignUpView.signUp(), it calls container.setAuthenticated(true) directly, which causes AppRouter.body to re-evaluate with needsOnboarding still false. The new Athlete has nil trainingFrequency/experienceLevel but the nil-check never runs. New signups bypass OnboardingView and land directly in MainTabView."
    artifacts:
      - path: "WorkloadApp/App/AppRouter.swift"
        issue: "needsOnboarding check is only in .task block (line 96-99). No onChange(of: container.isAuthenticated) observer triggers the check on signup."
      - path: "WorkloadApp/Views/Auth/SignUpView.swift"
        issue: "After successful signup, calls container.setAuthenticated(true) at line 177 without setting needsOnboarding=true. AppRouter .task has already completed at this point."
    missing:
      - "Add .onChange(of: container.isAuthenticated) to AppRouter body that re-runs the needsOnboarding check when isAuthenticated transitions from false to true — this covers the signup path"
      - "Alternative: SignUpView sets needsOnboarding=true after creating the Athlete (requires passing needsOnboarding binding into SignUpView or using a shared state mechanism)"
  - truth: "Onboarding flow captures sport type, training frequency, and experience level before reaching the dashboard (Roadmap SC #2)"
    status: partial
    reason: "Sport type is captured in SignUpView (intentional per decision D-01: 'Sport type stays in SignUpView — onboarding captures the remaining profile fields'). The literal ROADMAP success criterion says 'Onboarding flow captures sport type, training frequency, and experience level' but the planning context explicitly scoped sport to SignUpView. Sport IS saved to the Athlete model before any Dashboard is shown. This is a partial because the wording gap between ROADMAP and the actual implementation choice exists, even though the functional intent (sport captured before dashboard) is met."
    artifacts:
      - path: "WorkloadApp/Views/Onboarding/OnboardingView.swift"
        issue: "No sport type step — only training frequency, experience level, and HealthKit"
      - path: "WorkloadApp/Views/Auth/SignUpView.swift"
        issue: "Sport type IS captured here (line 166) and saved to Athlete model — this is correct per D-01"
    missing:
      - "Either: accept the deviation (sport in SignUpView satisfies the intent) by adding an override, OR add a note in ROADMAP that sport type is captured at signup not in OnboardingView"
---

# Phase 4: Onboarding & Polish — Verification Report

**Phase Goal:** New users know exactly what to do after signing up and the app captures their training context
**Verified:** 2026-04-22T06:30:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | TrainingFrequency and ExperienceLevel enums exist with correct cases and display names | VERIFIED | `Enums.swift` lines 302-342: both enums with conformances, displayName, subtitle, all expected cases |
| 2 | Athlete model has nullable trainingFrequency and experienceLevel fields | VERIFIED | `Athlete.swift` lines 19-20: both Optional with no default value |
| 3 | SyncService pushes and pulls the new fields to/from Supabase | VERIFIED | 20 matches in SyncService.swift: AthleteRow lines 511-512, push line 113-114, pull lines 134-138, bootstrap lines 88-92, pullLinkedAthleteProfile lines 386-405 |
| 4 | Existing users not broken by model change (fields Optional) | VERIFIED | Both fields are `Optional` with no default — SwiftData lightweight migration sets to nil |
| 5 | After signup, user sees a 3-step onboarding flow before reaching Dashboard | FAILED | needsOnboarding check lives only in .task block (AppRouter line 96-99). New signups call container.setAuthenticated(true) in SignUpView.signUp() — .task has already completed. needsOnboarding stays false. New users bypass OnboardingView. |
| 6 | Step 1 captures training frequency via selectable chip grid | VERIFIED | OnboardingView.swift line 62: `ForEach(TrainingFrequency.allCases)` in `LazyVGrid` |
| 7 | Step 2 captures experience level via selectable vertical cards | VERIFIED | OnboardingView.swift line 107: `ForEach(ExperienceLevel.allCases)` with `.subtitle` property displayed |
| 8 | Step 3 requests HealthKit permission with Skip for now option | VERIFIED | OnboardingView.swift lines 179, 195-199: `healthKitService.requestAuthorization()` + "Skip for now" text button |
| 9 | Returning users on new devices see onboarding again if fields are nil | VERIFIED | AppRouter.swift line 98: `needsOnboarding = (a.trainingFrequency == nil \|\| a.experienceLevel == nil)` — fires on relaunch when .task runs |
| 10 | After completing onboarding, user proceeds to Dashboard | VERIFIED | OnboardingView.swift line 291: `onComplete()` → AppRouter sets `needsOnboarding = false` → body re-evaluates to MainTabView |
| 11 | New user sees welcome card on Dashboard with two CTAs | VERIFIED | WelcomeActionCard.swift exists (62 lines), DashboardView.swift lines 33-37: conditional render with `showWelcomeCard` |
| 12 | Welcome card disappears after user logs first workout or completes first wellness check-in | VERIFIED | DashboardView.swift lines 22-25: `showWelcomeCard` computed property checks `athlete.sessions.isEmpty && athlete.wellnessCheckIns.isEmpty` — reactive via @Query |
| 13 | Training frequency and experience level are editable in Profile settings | VERIFIED | ProfileView.swift lines 40-48: `editablePicker("Training Frequency")` and `editablePicker("Experience Level")` with save+sync on set |

**Score:** 11/13 truths verified (1 failed, 1 partial)

### Roadmap Success Criteria Coverage

| SC | Text | Status | Notes |
|----|------|--------|-------|
| SC-1 | After signup, user sees clear guidance directing them to their first action | FAILED | Welcome card (truth 11) works once on Dashboard, but onboarding gate doesn't fire for new signups — they land directly on Dashboard without going through OnboardingView |
| SC-2 | Onboarding flow captures sport type, training frequency, and experience level before reaching the dashboard | PARTIAL | Training frequency and experience level captured in OnboardingView. Sport type captured in SignUpView per decision D-01. All three fields ARE saved to Athlete model before Dashboard. Wording gap vs implementation decision. |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `WorkloadApp/Models/Enums.swift` | TrainingFrequency and ExperienceLevel enums | VERIFIED | Lines 302-342, correct conformances |
| `WorkloadApp/Models/Athlete.swift` | Nullable onboarding fields | VERIFIED | Lines 19-20, both Optional |
| `WorkloadApp/Services/SyncService.swift` | AthleteRow sync for new fields | VERIFIED | 20 match points across push/pull/bootstrap |
| `WorkloadApp/Views/Onboarding/OnboardingView.swift` | 3-step paged onboarding flow | VERIFIED | 293 lines, all 3 steps implemented |
| `WorkloadApp/App/AppRouter.swift` | Onboarding gate with needsOnboarding | PARTIAL | Gate exists but only fires on relaunch, not fresh signup |
| `WorkloadApp/Views/Dashboard/WelcomeActionCard.swift` | First-action guidance card with two CTAs | VERIFIED | 62 lines, GET STARTED label, Log Workout + Wellness Check-In buttons |
| `WorkloadApp/Views/Dashboard/DashboardView.swift` | Conditional WelcomeActionCard rendering | VERIFIED | showWelcomeCard computed property, conditional render |
| `WorkloadApp/Views/Profile/ProfileView.swift` | Training frequency and experience level pickers | VERIFIED | Lines 40-48, editablePicker with save+sync |
| `.planning/phases/04-onboarding-polish/supabase-migration.sql` | ALTER TABLE migration | VERIFIED | File exists with correct SQL |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| AppRouter.swift | OnboardingView.swift | needsOnboarding conditional render | PARTIAL | Wired correctly for returning users; not triggered for new signups |
| OnboardingView.swift | Athlete.swift | athlete.trainingFrequency = freq (line 286) | VERIFIED | completeOnboarding() saves both fields, calls modelContext.save() |
| OnboardingView.swift | SyncService.swift | pushAthlete(athlete) in Task (line 290) | VERIFIED | Async push after local save |
| DashboardView.swift | WelcomeActionCard.swift | Conditional render at line 33-36 | VERIFIED | showWelcomeCard gates render |
| WelcomeActionCard.swift | ActiveWorkoutSheet | onLogWorkout: { showActiveWorkout = true } | VERIFIED | DashboardView.swift line 35 |
| WelcomeActionCard.swift | MorningCheckInSheet | onWellnessCheckIn: { showWellnessCheckIn = true } | VERIFIED | DashboardView.swift line 36, sheet line 101-102 |
| ProfileView.swift | Athlete.swift | trainingFrequency binding with saveAthlete | VERIFIED | Lines 40-48, Binding get/set pattern |
| SyncService.swift | Enums.swift | TrainingFrequency(rawValue:) in pullAthlete | VERIFIED | Lines 89, 135 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| OnboardingView.swift | selectedFrequency, selectedLevel | User selection (button tap) | Yes — enum selection from allCases | FLOWING |
| WelcomeActionCard.swift | N/A (display-only card) | DashboardView.showWelcomeCard | Yes — athlete.sessions.isEmpty check on real SwiftData query | FLOWING |
| AppRouter.swift | needsOnboarding | modelContext.fetch(Athlete) nil check | Yes — reads real Athlete fields, but only on relaunch | PARTIAL — disconnected for new signup path |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Enums compile and have correct cases | Source grep | `case oneToTwo, threeToFour, fiveToSix, sevenPlus` and `case beginner, intermediate, advanced` confirmed | PASS |
| OnboardingView onComplete closure fires needsOnboarding = false | AppRouter.swift line 23 | `OnboardingView(onComplete: { needsOnboarding = false })` confirmed | PASS |
| Welcome card reactive dismissal | DashboardView.swift line 22-25 | `athlete.sessions.isEmpty && athlete.wellnessCheckIns.isEmpty` checked via @Query | PASS |
| Profile pickers trigger saveAthlete | ProfileView.swift lines 42, 47 | `set: { athlete.trainingFrequency = $0; saveAthlete(athlete) }` | PASS |
| New user signup onboarding gate | AppRouter.swift + SignUpView.swift | SignUpView calls setAuthenticated(true) directly — .task already completed — needsOnboarding stays false | FAIL |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| ONBRD-01 | 04-03 | First-run guidance after signup — direct user to first action | PARTIAL | Welcome card exists and works on Dashboard. However, new users bypass OnboardingView on first signup — onboarding gate only works on relaunch. The welcome card IS shown (correct), but the onboarding capture (frequency/experience) doesn't trigger for new signups. |
| ONBRD-02 | 04-01, 04-02, 04-03 | Sport/training preference setup during onboarding flow (sport type, training frequency, experience level) | PARTIAL | Training frequency and experience level: data model, sync, onboarding UI, and profile editing all implemented correctly. Sport type captured in SignUpView per D-01 (intentional). Onboarding flow not triggered for new signups (same root cause as ONBRD-01 gap). |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| No anti-patterns found | — | — | — | No TODO/FIXME/placeholder comments, no RoundedRectangle, no .shadow(), no ColorTokens.accent in new views |

### Human Verification Required

#### 1. New User Signup Flow (Onboarding Gate)

**Test:** Create a fresh account via the signup flow (or delete and re-install the app). After signup completes, observe whether OnboardingView appears or the app navigates directly to MainTabView.
**Expected:** OnboardingView (step 1: training frequency chips) should appear before Dashboard.
**Why human:** This is a runtime flow — the gap was identified by code-tracing AppRouter's .task lifecycle, but the actual behavior should be confirmed by running the app in Simulator.

#### 2. Welcome Card Dismissal

**Test:** After completing the onboarding flow (if/when the gate is fixed), on the Dashboard verify the "GET STARTED" card is visible. Log a workout or complete a wellness check-in, return to Dashboard.
**Expected:** Welcome card disappears after the first action completes.
**Why human:** Reactive SwiftData dismissal is correct in code but requires runtime verification.

#### 3. Profile Picker Persistence

**Test:** In Profile tab, change Training Frequency to "7+ days/week". Kill and relaunch the app. Navigate back to Profile.
**Expected:** "7+ days/week" is still selected (persisted to SwiftData and synced to Supabase).
**Why human:** Persistence across relaunch requires runtime verification.

### Gaps Summary

**1 critical functional gap** blocks goal achievement:

**Onboarding gate does not fire for new signups.** The `needsOnboarding` flag in `AppRouter` is only evaluated inside the `.task` modifier, which executes once when `AppRouter` first appears. For a new user, the `.task` runs before they sign up, finds no Keychain session, and exits with `needsOnboarding = false`. When `SignUpView.signUp()` completes, it calls `container.setAuthenticated(true)` directly — but no code path re-evaluates the onboarding check at that point. The new user's `Athlete` has `trainingFrequency = nil` and `experienceLevel = nil`, but `needsOnboarding` remains `false`, so `AppRouter` renders `MainTabView` immediately.

The returning-user path (relaunch with existing session) works correctly: `.task` runs, finds the Keychain session, syncs, and checks the Athlete fields for nil — this path is verified.

**Fix:** Add `.onChange(of: container.isAuthenticated)` in AppRouter body (or equivalent) that fires the nil-field check when the user authenticates for the first time in the session. This covers both the signup and login paths symmetrically.

**1 partial gap** on ROADMAP SC wording:

**Sport type not in OnboardingView** — intentional per decision D-01 but the ROADMAP success criterion says "Onboarding flow captures sport type." Sport IS captured in SignUpView before Dashboard, satisfying the functional intent. An override is suggested if the deviation is accepted as-is.

---

_Verified: 2026-04-22T06:30:00Z_
_Verifier: Claude (gsd-verifier)_
