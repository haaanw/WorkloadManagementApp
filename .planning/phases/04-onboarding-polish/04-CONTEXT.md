# Phase 4: Onboarding & Polish - Context

**Gathered:** 2026-04-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a post-signup onboarding flow that captures training preferences (frequency, experience level) and requests HealthKit access, plus a first-action guidance card on the Dashboard that directs new users to their first workout or wellness check-in. No new analytics, no new features — purely guiding new users through setup and first interaction.

</domain>

<decisions>
## Implementation Decisions

### Onboarding Flow Structure
- **D-01:** Onboarding is a multi-step paged view (OnboardingView) shown AFTER signup succeeds, BEFORE Dashboard. Sport type stays in SignUpView — onboarding captures the remaining profile fields.
- **D-02:** Three steps: (1) Training frequency, (2) Experience level, (3) HealthKit permission.
- **D-03:** All steps required — no skip button on frequency or experience. HealthKit step has "Skip for now" since it's a system permission.
- **D-04:** Paged transitions with dot indicators at bottom. "Continue" button advances. No back button.
- **D-05:** Returning users on new devices see onboarding again if training frequency or experience level fields are missing on Athlete model. Data syncs to Supabase so onboarding is one-time per account.
- **D-06:** AppRouter gate: after authentication, check if Athlete has onboarding fields populated → if not, show OnboardingView instead of MainTabView.

### First-Action Guidance
- **D-07:** After onboarding completes, Dashboard shows a welcome action card at top with two CTAs: "Log Your First Workout" and "Do a Wellness Check-In".
- **D-08:** Welcome card disappears after user completes EITHER action (first workout logged OR first wellness check-in). Persistent until then — shows every Dashboard visit.
- **D-09:** Card follows existing Dashboard card section pattern (from Phase 2 WeeklySummaryCard).

### Training Profile Fields
- **D-10:** Training frequency captured as range buckets: "1–2 days/week", "3–4 days/week", "5–6 days/week", "7+ days/week". Displayed as selectable chips in 2x2 grid.
- **D-11:** Experience level captured as 3 tiers: Beginner ("New to structured training"), Intermediate ("1–3 years consistent training"), Advanced ("3+ years, understands periodization"). Displayed as vertical selectable cards with subtitle descriptions.
- **D-12:** Both fields editable later in Profile tab settings alongside existing sport type picker.
- **D-13:** New fields added to Athlete model: `trainingFrequency` (enum) and `experienceLevel` (enum). Both nullable — nil triggers onboarding gate.

### HealthKit Permission
- **D-14:** HealthKit permission requested in onboarding step 3 with contextual explanation: "Tonus uses your HRV, resting heart rate, and sleep data to calculate your daily recovery score."
- **D-15:** If user skips HealthKit in onboarding, re-prompt with inline card on first Recovery tab visit. Same behavior as current fallback but only triggers if skipped during onboarding.

### Claude's Discretion
- Welcome card copy and visual styling (within DESIGN.md constraints)
- Onboarding step header/body copy
- HealthKit explanation copy refinement
- Enum raw values and Supabase column naming for new fields
- Profile settings section layout for new editable fields
- Whether "Skip for now" on HealthKit is a text button or a link-style dismissal

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design System
- `DESIGN.md` — Visual constraints (0pt corners, DM Sans, 8pt grid, no shadows, accent only on readiness score)

### Requirements
- `REQUIREMENTS.md` §ONBRD-01 — First-run guidance after signup
- `REQUIREMENTS.md` §ONBRD-02 — Sport/training preference setup during onboarding

### Auth & Routing
- `WorkloadApp/App/AppRouter.swift` — Current auth gate logic (Loading → Login → MainTabView). Onboarding gate inserts between auth and MainTabView.
- `WorkloadApp/Views/Auth/SignUpView.swift` — Existing signup flow with SportType picker. Onboarding starts after this succeeds.

### Data Model
- `WorkloadApp/Models/Athlete.swift` — Athlete model needs new `trainingFrequency` and `experienceLevel` fields
- `WorkloadApp/Models/Enums.swift` — New enums: `TrainingFrequency`, `ExperienceLevel`

### Existing Patterns
- `WorkloadApp/Views/Dashboard/DashboardView.swift` — Dashboard layout where welcome card inserts at top
- `WorkloadApp/Services/HealthKitService.swift` — HealthKit authorization request logic to reuse in onboarding
- `WorkloadApp/Services/SyncService.swift` — Athlete sync for new fields to Supabase

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `InputField` / `SecureInputField` in SignUpView — reusable form components for consistent styling
- SportType grid picker in SignUpView — same chip/grid pattern for training frequency
- `ColorTokens` — all colors for onboarding screens
- `Font.Tokens` — DM Sans font extensions
- `HealthKitService.requestAuthorization()` — existing method to trigger system permission dialog
- `WeeklySummaryCard` — collapsible card pattern to follow for welcome action card

### Established Patterns
- SignUpView uses ScrollView + VStack with divider separators — onboarding can follow different pattern (paged, not scrolling)
- AppRouter checks `isAuthenticated` boolean — extend with `hasCompletedOnboarding` check on Athlete fields
- Athlete model uses SwiftData `@Model` with Supabase sync — new fields follow same pattern

### Integration Points
- AppRouter: insert onboarding check between auth success and MainTabView
- Athlete model: add `trainingFrequency: TrainingFrequency?` and `experienceLevel: ExperienceLevel?`
- Enums.swift: add `TrainingFrequency` and `ExperienceLevel` enums
- SyncService: include new fields in athlete push/pull
- DashboardView: add conditional welcome card section at top
- ProfileView: add training frequency and experience level settings rows
- Supabase `athletes` table: add columns for new fields

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches for paged onboarding, chip selection components, and welcome card design within DESIGN.md constraints.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 04-onboarding-polish*
*Context gathered: 2026-04-22*
