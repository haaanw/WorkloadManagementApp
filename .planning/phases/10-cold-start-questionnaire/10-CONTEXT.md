# Phase 10: Cold-Start Questionnaire - Context

**Gathered:** 2026-05-02
**Status:** Ready for planning

<domain>
## Phase Boundary

New athletes can answer a brief training questionnaire and immediately see estimated workload data on their dashboard, with automatic switchover to real data as they log sessions. Includes bias capture and FatigueIndex cold-start handling.

</domain>

<decisions>
## Implementation Decisions

### Questionnaire Entry Point
- **D-01:** Post-onboarding dashboard card (like WelcomeActionCard) prompts "Set up your training profile". Non-blocking -- user can dismiss and fill later.
- **D-02:** Card reappears each app launch until questionnaire is completed. Dashboard shows workload 'no data' state meanwhile.
- **D-03:** Questionnaire also accessible from Profile screen at any time (for re-editing answers later).

### Questionnaire Form
- **D-04:** Single scrollable sheet with all 4 required questions at top + 4 optional questions below a divider. Not multi-step paged.
- **D-05:** Required: sessions/week (stepper/picker), avg duration minutes (stepper/picker), typical sRPE 1-10 (slider or picker), weeks at current level (stepper/picker).
- **D-06:** Optional: training age years, periodization preference (steady/periodized), movement types (multi-select), injury history (body region picker + notes).
- **D-07:** On submit: call ColdStartEngine.computeSeed(), save TrainingProfile, dismiss sheet. Dashboard immediately reflects estimated values.

### Dashboard Cold-Start Display
- **D-08:** ATL/CTL/ACWR show in existing training load section with a small "Estimated" text label. Same layout, same position -- just annotated.
- **D-09:** Workload trend chart hidden during cold-start window. Only numeric values display. Chart appears when real data exists.
- **D-10:** ACWR bar and zone badge use estimated values but display normally (zone classification still meaningful with estimated data).

### Switchover Behavior
- **D-11:** Silent transition when threshold met (3 weeks + 8 sessions). "Estimated" label disappears, chart appears with real data. No toast, no modal, no celebration.
- **D-12:** No progress indicator toward switchover. User just trains and transition happens invisibly.
- **D-13:** coldStartCompletedAt set on TrainingProfile when switchover triggers. Dashboard reads this to decide display mode.

### Bias Capture
- **D-14:** Completely invisible to user. At 8-week mark, silently snapshot estimated vs actual ATL/CTL onto TrainingProfile bias fields. No UI, no notification.
- **D-15:** Bias ratio computed at read time (not stored). Used for internal analytics and future calibration research only.

### FatigueIndex Cold-Start
- **D-16:** FatigueIndex section shows "Building baseline..." text with no score during cold-start window. Matches DESIGN.md text-label-for-states pattern.
- **D-17:** FatigueIndex begins computing normally after cold-start completes (sufficient HRV/recovery baselines by then).

### Claude's Discretion
- Input control types for questionnaire fields (steppers, sliders, pickers -- whatever fits DESIGN.md best)
- Exact "Estimated" label styling and placement within the metrics section
- "Building baseline..." text styling for FatigueIndex
- DashboardViewModel integration approach for cold-start data path
- Whether to create a dedicated ColdStartService pipeline or integrate into existing RecoveryPipeline/WorkoutPipeline

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Models & Engine (from Phase 9)
- `WorkloadApp/Models/TrainingProfile.swift` -- All questionnaire + seed + bias fields
- `WorkloadApp/Services/ColdStartEngine.swift` -- computeSeed(input:) -> SeedResult
- `WorkloadApp/Models/Enums.swift` -- BodyRegion enum, InjuryEntry struct (for injury history picker)

### Dashboard Integration
- `WorkloadApp/Views/Dashboard/DashboardView.swift` -- Training load section (ATL/CTL/ACWR display, lines 420-445)
- `WorkloadApp/ViewModels/DashboardViewModel.swift` -- load() method, ATL/CTL properties
- `WorkloadApp/Views/Dashboard/WelcomeActionCard.swift` -- Pattern for post-onboarding dashboard cards

### Onboarding Pattern
- `WorkloadApp/Views/Onboarding/OnboardingView.swift` -- Existing 3-step flow, UI pattern reference

### Design System
- `DESIGN.md` -- 0pt corners, no shadows, DM Sans, 8pt grid, text labels for states

### Requirements
- `.planning/REQUIREMENTS.md` -- COLD-01 through COLD-07
- `.planning/ROADMAP.md` -- Phase 10 success criteria

### Phase 9 Context (locked decisions)
- `.planning/phases/09-foundation-cold-start-engine/09-CONTEXT.md` -- D-04 through D-13 (seeding math, field design, switchover threshold)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `WelcomeActionCard` -- Dashboard card pattern for post-onboarding prompts (entry point for questionnaire)
- `OnboardingView` -- Multi-step paged UI with dot indicators (reference for form patterns, but questionnaire uses single sheet)
- `ColdStartEngine.computeSeed()` -- Ready to call from questionnaire submit handler
- `TrainingProfile` model -- All fields ready, registered in schema
- `DashboardViewModel` -- ATL/CTL/ACWR properties already exposed; needs cold-start fallback path

### Established Patterns
- Dashboard cards follow WelcomeActionCard pattern (VStack, title, description, CTA button)
- Sheet presentation via `.sheet(isPresented:)` on dashboard
- `@Query` for reactive SwiftData reads, ViewModel for orchestration
- Form inputs use `Font.Tokens` and `ColorTokens` throughout

### Integration Points
- `DashboardView` -- Add training profile card (similar to WelcomeActionCard placement)
- `DashboardViewModel.load()` -- Add cold-start data path: if no WorkloadSnapshot but TrainingProfile exists with seeded values, use those
- `WorkoutPipeline.processSession()` -- After saving session, check switchover threshold (3wk + 8 sessions since seededAt)
- `ProfileView` -- Add "Training Profile" section for re-editing questionnaire answers
- `FatigueIndexEngine` or dashboard display -- Gate on coldStartCompletedAt to show "Building baseline..."

</code_context>

<specifics>
## Specific Ideas

- Questionnaire card should look similar to WelcomeActionCard -- same spacing, same font hierarchy
- "Estimated" label should be small, secondary text color (ColorTokens.text3), positioned near the ATL/CTL values
- "Building baseline..." for FatigueIndex should use same secondary text treatment
- Switchover check runs inside WorkoutPipeline after each session save -- if threshold met, set coldStartCompletedAt and next dashboard load picks up real data

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 10-cold-start-questionnaire*
*Context gathered: 2026-05-02*
