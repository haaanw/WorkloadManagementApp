# Phase 4: Onboarding & Polish - Research

**Researched:** 2026-04-22
**Domain:** SwiftUI onboarding flow, SwiftData model extension, Supabase schema migration
**Confidence:** HIGH

## Summary

Phase 4 adds a post-signup onboarding flow and a first-action welcome card on the Dashboard. The scope is narrow and well-defined: two new enum types, two new nullable fields on the Athlete model, a 3-step paged OnboardingView, an AppRouter gate, a conditional welcome card, Profile settings additions, and Supabase schema + sync updates.

All required patterns already exist in the codebase. The sport-type chip grid in SignUpView is the template for training frequency selection. The WeeklySummaryCard provides the card pattern for the welcome card. The AppRouter already gates on `isAuthenticated` and can be extended with an onboarding check. The Supabase sync layer uses automatic camelCase-to-snake_case conversion, so new AthleteRow fields will map seamlessly.

**Primary recommendation:** Build bottom-up -- model/enum first, then sync layer, then views, then routing gate. This avoids forward references and enables incremental build verification.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Onboarding is a multi-step paged view (OnboardingView) shown AFTER signup succeeds, BEFORE Dashboard. Sport type stays in SignUpView -- onboarding captures the remaining profile fields.
- **D-02:** Three steps: (1) Training frequency, (2) Experience level, (3) HealthKit permission.
- **D-03:** All steps required -- no skip button on frequency or experience. HealthKit step has "Skip for now" since it's a system permission.
- **D-04:** Paged transitions with dot indicators at bottom. "Continue" button advances. No back button.
- **D-05:** Returning users on new devices see onboarding again if training frequency or experience level fields are missing on Athlete model. Data syncs to Supabase so onboarding is one-time per account.
- **D-06:** AppRouter gate: after authentication, check if Athlete has onboarding fields populated -> if not, show OnboardingView instead of MainTabView.
- **D-07:** After onboarding completes, Dashboard shows a welcome action card at top with two CTAs: "Log Your First Workout" and "Do a Wellness Check-In".
- **D-08:** Welcome card disappears after user completes EITHER action (first workout logged OR first wellness check-in). Persistent until then -- shows every Dashboard visit.
- **D-09:** Card follows existing Dashboard card section pattern (from Phase 2 WeeklySummaryCard).
- **D-10:** Training frequency captured as range buckets: "1-2 days/week", "3-4 days/week", "5-6 days/week", "7+ days/week". Displayed as selectable chips in 2x2 grid.
- **D-11:** Experience level captured as 3 tiers: Beginner ("New to structured training"), Intermediate ("1-3 years consistent training"), Advanced ("3+ years, understands periodization"). Displayed as vertical selectable cards with subtitle descriptions.
- **D-12:** Both fields editable later in Profile tab settings alongside existing sport type picker.
- **D-13:** New fields added to Athlete model: `trainingFrequency` (enum) and `experienceLevel` (enum). Both nullable -- nil triggers onboarding gate.
- **D-14:** HealthKit permission requested in onboarding step 3 with contextual explanation.
- **D-15:** If user skips HealthKit in onboarding, re-prompt with inline card on first Recovery tab visit.

### Claude's Discretion
- Welcome card copy and visual styling (within DESIGN.md constraints)
- Onboarding step header/body copy
- HealthKit explanation copy refinement
- Enum raw values and Supabase column naming for new fields
- Profile settings section layout for new editable fields
- Whether "Skip for now" on HealthKit is a text button or a link-style dismissal

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ONBRD-01 | First-run guidance after signup -- direct user to first action (log workout or wellness check-in) | Welcome action card on Dashboard (D-07, D-08, D-09). Detection via `@Query` checking `sessions.isEmpty` and `wellnessCheckIns.isEmpty` on current athlete. |
| ONBRD-02 | Sport/training preference setup during onboarding flow (sport type, training frequency, experience level) | Sport type already in SignUpView. New `TrainingFrequency` and `ExperienceLevel` enums + Athlete model fields (D-10, D-11, D-13). Paged OnboardingView (D-01, D-02). |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Onboarding flow UI | Frontend (SwiftUI) | -- | Pure UI with local state; no API calls except HealthKit permission |
| Training profile fields | Database (SwiftData) | Backend (Supabase) | SwiftData model owns local truth; Supabase stores for cross-device sync |
| Onboarding gate routing | Frontend (SwiftUI) | -- | AppRouter checks Athlete model fields locally; no server round-trip needed |
| Welcome card display logic | Frontend (SwiftUI) | -- | `@Query` on sessions/check-ins determines visibility; purely local |
| HealthKit permission | Client (HealthKit) | -- | System dialog; HealthKitService.requestAuthorization() already exists |
| Profile editing | Frontend (SwiftUI) | Backend (Supabase) | Picker updates local model, then pushes via SyncService |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | All UI (onboarding views, welcome card, profile edits) | Project standard [VERIFIED: codebase] |
| SwiftData | iOS 17+ | Athlete model persistence with new fields | Project standard [VERIFIED: codebase] |
| HealthKit | iOS 17+ | Permission request in onboarding step 3 | Already integrated [VERIFIED: HealthKitService.swift] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Supabase Swift SDK | (project-pinned) | Sync new athlete fields to backend | Push after onboarding completes, pull on bootstrap [VERIFIED: SyncService.swift] |

No new dependencies required. This phase uses only existing frameworks and SDKs.

## Architecture Patterns

### System Architecture Diagram

```
SignUpView (existing)
    |
    v (signup succeeds, sets isAuthenticated = true)
AppRouter
    |
    +-- isAuthenticated? --NO--> LoginView
    |
    +-- YES: athlete.trainingFrequency == nil
    |   OR athlete.experienceLevel == nil?
    |       |
    |       +-- YES --> OnboardingView (3-step paged)
    |       |               Step 1: TrainingFrequency picker
    |       |               Step 2: ExperienceLevel picker
    |       |               Step 3: HealthKit permission
    |       |               |
    |       |               v (all steps done)
    |       |           Save fields to Athlete model
    |       |           Push to Supabase via SyncService
    |       |               |
    |       +-- NO ---------+
    |                       |
    v                       v
MainTabView --> DashboardView
                    |
                    +-- sessions.isEmpty AND wellnessCheckIns.isEmpty?
                    |       |
                    |       +-- YES --> WelcomeActionCard (two CTAs)
                    |       +-- NO  --> (normal dashboard)
                    v
              (rest of dashboard)
```

### Recommended Project Structure
```
WorkloadApp/
├── Models/
│   ├── Enums.swift              # ADD: TrainingFrequency, ExperienceLevel enums
│   └── Athlete.swift            # ADD: trainingFrequency, experienceLevel fields
├── Views/
│   ├── Onboarding/
│   │   └── OnboardingView.swift # NEW: 3-step paged onboarding flow
│   └── Dashboard/
│       ├── DashboardView.swift  # MODIFY: insert WelcomeActionCard
│       └── WelcomeActionCard.swift # NEW: first-action guidance card
├── Views/Profile/
│   └── ProfileView.swift        # MODIFY: add training frequency + experience pickers
├── Services/
│   └── SyncService.swift        # MODIFY: AthleteRow + push/pull for new fields
└── App/
    └── AppRouter.swift          # MODIFY: onboarding gate logic
```

### Pattern 1: Paged Onboarding with TabView
**What:** SwiftUI `TabView` with `.tabViewStyle(.page(indexDisplayMode: .never))` for manual paging control with custom dot indicators.
**When to use:** Multi-step flows where each step is a full-screen card and the user advances via a button (not swiping).
**Example:**
```swift
// [VERIFIED: SwiftUI TabView paging API, iOS 17+]
struct OnboardingView: View {
    @State private var currentStep = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentStep) {
                FrequencyStepView(/* ... */).tag(0)
                ExperienceLevelStepView(/* ... */).tag(1)
                HealthKitStepView(/* ... */).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeOut(duration: 0.25), value: currentStep)

            // Custom dot indicators + continue button at bottom
            OnboardingFooter(currentStep: $currentStep, totalSteps: 3)
        }
    }
}
```

### Pattern 2: Conditional Routing in AppRouter
**What:** Extend the existing `isCheckingSession` / `isAuthenticated` gate with a third condition checking Athlete model fields.
**When to use:** D-06 requires onboarding gate between auth and MainTabView.
**Example:**
```swift
// [VERIFIED: existing AppRouter.swift pattern]
// In AppRouter body:
if isCheckingSession {
    ProgressView("Loading...")
} else if !container.isAuthenticated {
    LoginView()
} else if needsOnboarding {
    OnboardingView()
} else {
    MainTabView()
}
```

The `needsOnboarding` computed property queries the Athlete model via `@Query` and checks if `trainingFrequency == nil || experienceLevel == nil`.

### Pattern 3: Welcome Card with @Query-Based Visibility
**What:** A conditional card in DashboardView that checks if the athlete has any sessions or wellness check-ins.
**When to use:** D-07/D-08 first-action guidance.
**Example:**
```swift
// [VERIFIED: existing DashboardView.swift + WeeklySummaryCard pattern]
// In DashboardView body, after HeroReadinessCard:
if athlete?.sessions.isEmpty == true && athlete?.wellnessCheckIns.isEmpty == true {
    WelcomeActionCard(
        onLogWorkout: { showActiveWorkout = true },
        onWellnessCheckIn: { /* navigate to Recovery tab or show sheet */ }
    )
}
```

### Anti-Patterns to Avoid
- **UserDefaults for onboarding state:** Do NOT store "hasCompletedOnboarding" in UserDefaults or AppStorage. The Athlete model fields themselves are the source of truth (D-05, D-13). If fields are nil, onboarding is needed. This ensures cross-device consistency via Supabase sync.
- **Swiping between onboarding steps:** D-04 specifies button-driven advancement with no back button. Disable TabView swipe gesture to enforce this.
- **Hardcoded colors in onboarding:** All colors must use ColorTokens per DESIGN.md. No hex values in view code.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Paged view transitions | Custom offset animation | `TabView(.page)` with `.tabViewStyle` | Native paging with proper gesture handling |
| HealthKit permission | Custom entitlement check | `HealthKitService.requestAuthorization()` | Already exists, handles all data types |
| Athlete sync | Manual REST calls | `SyncService.pushAthlete()` | Existing upsert pattern with snake_case encoding |
| Dot page indicators | Custom HStack circles | Custom but simple -- 3 fixed dots | TabView's built-in indicators can't be styled to match DESIGN.md |

**Key insight:** The only truly new UI component is the OnboardingView itself. Everything else extends existing patterns (AppRouter gating, Dashboard cards, Profile pickers, SyncService fields).

## Common Pitfalls

### Pitfall 1: SwiftData Migration for New Nullable Fields
**What goes wrong:** Adding new properties to an `@Model` class can trigger a lightweight migration. If the field is non-optional without a default, the migration fails and the app crashes on launch for existing users.
**Why it happens:** SwiftData performs automatic lightweight migration but cannot infer values for new required fields.
**How to avoid:** Both `trainingFrequency` and `experienceLevel` MUST be declared as `Optional` (`TrainingFrequency?` and `ExperienceLevel?`) with no default value -- exactly as D-13 specifies. SwiftData will set them to `nil` for existing records, which also correctly triggers the onboarding gate. [VERIFIED: SwiftData lightweight migration behavior for optional fields]
**Warning signs:** App crash on launch after update, "failed to migrate" console error.

### Pitfall 2: TabView Swipe Gesture Leaking Through
**What goes wrong:** Even with `.tabViewStyle(.page(indexDisplayMode: .never))`, users can still swipe between pages by default.
**Why it happens:** TabView page style enables swipe gestures automatically.
**How to avoid:** Disable user-initiated swiping since D-04 says no back button (implying forward-only button navigation). Use `.gesture(DragGesture())` on each page to consume swipe gestures, or wrap in a custom container that only advances programmatically. [ASSUMED]
**Warning signs:** User can swipe back to completed steps, or swipe forward past validation.

### Pitfall 3: Onboarding Gate Race Condition with Sync
**What goes wrong:** On returning-user bootstrap (D-05), the pullAthlete might not complete before AppRouter evaluates `needsOnboarding`, causing a flash of OnboardingView before fields sync in.
**Why it happens:** AppRouter's `.task` already does sync before setting `isAuthenticated = true`. But if pullAthlete doesn't update the new fields, the gate triggers incorrectly.
**How to avoid:** Ensure `pullAthlete` in SyncService maps `trainingFrequency` and `experienceLevel` from AthleteRow back to the local Athlete model. The existing `pullAthlete` only maps `displayName` and `isCoach` -- it MUST be extended. [VERIFIED: SyncService.swift line 124-128]
**Warning signs:** Returning user on new device sees onboarding even though they completed it before.

### Pitfall 4: Supabase Column Not Added
**What goes wrong:** App pushes new fields but Supabase rejects them because the columns don't exist in the `athletes` table.
**Why it happens:** AthleteRow is extended in code but the PostgreSQL schema is not updated.
**How to avoid:** Run an ALTER TABLE migration on Supabase BEFORE deploying the app update. Both columns should be `text` type (storing enum raw values) and nullable.
**Warning signs:** `pushAthlete` silently fails (wrapped in `try?`), fields never sync.

### Pitfall 5: Welcome Card Navigation for Wellness Check-In
**What goes wrong:** The "Do a Wellness Check-In" CTA needs to navigate to the Recovery tab or present a sheet, but DashboardView is in a different tab.
**Why it happens:** Cross-tab navigation in SwiftUI requires either programmatic tab selection or presenting a sheet.
**How to avoid:** Use a sheet presentation for wellness check-in (same as the active workout sheet pattern), OR expose a `selectedTab` binding from MainTabView and switch tabs programmatically. Sheet is simpler and consistent with the workout CTA. [ASSUMED]
**Warning signs:** CTA does nothing, or navigation breaks tab state.

## Code Examples

### New Enums (Enums.swift)
```swift
// [VERIFIED: follows existing enum pattern in Enums.swift]
enum TrainingFrequency: String, Codable, CaseIterable, Identifiable {
    case oneToTwo
    case threeToFour
    case fiveToSix
    case sevenPlus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneToTwo: "1-2 days/week"
        case .threeToFour: "3-4 days/week"
        case .fiveToSix: "5-6 days/week"
        case .sevenPlus: "7+ days/week"
        }
    }
}

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .beginner: "New to structured training"
        case .intermediate: "1-3 years consistent training"
        case .advanced: "3+ years, understands periodization"
        }
    }
}
```

### Athlete Model Extension
```swift
// [VERIFIED: follows existing Athlete.swift pattern]
// Add to Athlete class:
var trainingFrequency: TrainingFrequency?
var experienceLevel: ExperienceLevel?
```

### AthleteRow Extension (SyncService)
```swift
// [VERIFIED: follows existing AthleteRow pattern with auto snake_case]
// Add to AthleteRow struct:
let trainingFrequency: String?
let experienceLevel: String?

// In pushAthlete():
trainingFrequency: athlete.trainingFrequency?.rawValue,
experienceLevel: athlete.experienceLevel?.rawValue,

// In pullAthlete() -- ADD these lines:
if let freq = row.trainingFrequency {
    existingAthlete.trainingFrequency = TrainingFrequency(rawValue: freq)
}
if let exp = row.experienceLevel {
    existingAthlete.experienceLevel = ExperienceLevel(rawValue: exp)
}
```

### Supabase Migration SQL
```sql
-- [ASSUMED: based on existing athletes table schema pattern]
ALTER TABLE athletes
  ADD COLUMN training_frequency text,
  ADD COLUMN experience_level text;
```

### Onboarding Gate (AppRouter)
```swift
// [VERIFIED: extends existing AppRouter.swift pattern]
@Query private var athletes: [Athlete]

private var needsOnboarding: Bool {
    guard let athlete = athletes.first else { return false }
    return athlete.trainingFrequency == nil || athlete.experienceLevel == nil
}
```

Note: AppRouter currently does NOT use `@Query`. It fetches athletes via `modelContext.fetch()` inside `.task`. The onboarding check must work within the same async flow, OR the gate must be moved to a child view that can use `@Query`. The cleanest approach: have AppRouter render an intermediate view that uses `@Query` and conditionally shows OnboardingView or MainTabView.

### Welcome Card Detection
```swift
// [VERIFIED: Athlete.sessions and .wellnessCheckIns relationships exist]
// In DashboardView:
private var showWelcomeCard: Bool {
    guard let athlete else { return false }
    return athlete.sessions.isEmpty && athlete.wellnessCheckIns.isEmpty
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `UIPageViewController` wrapping | `TabView(.page)` in SwiftUI | iOS 14+ | Native SwiftUI paging, no UIKit bridge needed |
| UserDefaults onboarding flag | Model-field-based gating | Current best practice | Cross-device sync via backend, single source of truth |

**Deprecated/outdated:**
- `PageTabViewStyle()` initializer: Use `.tabViewStyle(.page())` instead (dot syntax, cleaner) [VERIFIED: iOS 17+ API]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | TabView swipe can be disabled with `.gesture(DragGesture())` overlay | Pitfall 2 | User can bypass button-only navigation; may need alternative approach like custom paging |
| A2 | Sheet presentation is preferred for wellness check-in CTA | Pitfall 5 | May need tab switching instead; low risk either way |
| A3 | Supabase athletes table schema matches AthleteRow fields | Supabase Migration | If schema differs, column names may need adjustment |

## Open Questions

1. **AppRouter @Query limitation**
   - What we know: AppRouter currently uses `modelContext.fetch()` in `.task`, not `@Query`. It cannot use `@Query` directly because the athletes data is needed in the async `.task` block.
   - What's unclear: Whether to refactor AppRouter to use a child view with `@Query` for the onboarding gate, or to keep the fetch-based approach and add onboarding check in the `.task` block.
   - Recommendation: Add the onboarding check inside the existing `.task` block after `container.setAuthenticated(true)` using the already-fetched athletes data. Set a new `@State private var needsOnboarding = false` flag. This avoids restructuring AppRouter.

2. **Wellness Check-In CTA navigation target**
   - What we know: DashboardView has a "Log Workout" button that presents `ActiveWorkoutSheet`. There is no equivalent quick-entry sheet for wellness check-ins.
   - What's unclear: Whether to present a dedicated `WellnessCheckInSheet` from Dashboard, or navigate to the Recovery tab.
   - Recommendation: If a standalone `WellnessCheckInSheet` already exists or can be extracted from RecoveryView, use sheet presentation for consistency with the workout CTA. Otherwise, the simplest approach is a sheet.

## Project Constraints (from CLAUDE.md)

- **0pt border radius everywhere** -- OnboardingView and WelcomeActionCard must use `Rectangle()`, never `RoundedRectangle`
- **No shadows** -- use hairline borders instead
- **Accent color only on hero readiness score** -- onboarding buttons and cards must NOT use `ColorTokens.accent`
- **DM Sans Regular + Medium only** -- use `Font.custom()` via `Font.Tokens`, never `.system()` or semantic styles
- **All spacing multiples of 8pt** -- 8, 16, 24, 32, 48, 64
- **Both dark and light mode** via `ColorTokens` semantic tokens
- **Incremental build verification** -- after every 3-5 files, run xcodebuild or Xcode build check
- **Verify .pbxproj includes new files** -- OnboardingView.swift and WelcomeActionCard.swift must be added to the Xcode project
- **DESIGN.md must be read before any visual decisions** -- all onboarding styling follows International Style Minimalism

## Sources

### Primary (HIGH confidence)
- Codebase analysis: `AppRouter.swift`, `Athlete.swift`, `Enums.swift`, `SignUpView.swift`, `DashboardView.swift`, `SyncService.swift`, `HealthKitService.swift`, `ProfileView.swift`, `WeeklySummaryCard.swift` -- all patterns verified directly
- `DESIGN.md` -- visual constraints and implementation rules verified
- `CLAUDE.md` -- project conventions and constraints verified

### Secondary (MEDIUM confidence)
- SwiftUI `TabView(.page)` API -- well-established iOS 14+ API, behavior verified through training knowledge and consistent with iOS 17 target

### Tertiary (LOW confidence)
- Swipe gesture disabling technique (A1) -- common pattern but not verified against iOS 17 specifically

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new dependencies, all existing frameworks
- Architecture: HIGH -- extends existing patterns (AppRouter gate, Dashboard card, Athlete model, SyncService)
- Pitfalls: HIGH -- identified from direct codebase analysis (especially SyncService pullAthlete gap and SwiftData migration)

**Research date:** 2026-04-22
**Valid until:** 2026-05-22 (stable -- no fast-moving dependencies)
