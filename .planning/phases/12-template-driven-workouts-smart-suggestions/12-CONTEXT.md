# Phase 12: Template-Driven Workouts & Smart Suggestions - Context

**Gathered:** 2026-05-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Athletes can start sessions from templates in one tap with auto-filled targets (ghost values from last session + ProgressionEngine overlay for Pro), and the app learns their schedule to suggest the right template at the right time. Includes template picker flow, dashboard quick-start cards, and recovery-aware suggestion engine. No template sharing (v1.3), no LLM import (v1.3), no template creation/CRUD (Phase 11 — done).

</domain>

<decisions>
## Implementation Decisions

### Template Picker Flow
- **D-01:** '+' button opens a template picker sheet (not ActiveWorkoutSheet directly). Picker shows carousel of templates + 'Start blank workout' option. Selecting a template opens ActiveWorkoutSheet pre-filled.
- **D-02:** Carousel cards in Workout Log tab are tap-to-start — tapping a carousel card opens ActiveWorkoutSheet pre-filled from that template. One-tap quick-start replaces Phase 11's tap-to-preview behavior.
- **D-03:** TemplatePreviewSheet moves to long-press context menu (was tap target in Phase 11).
- **D-04:** When user has zero templates, '+' still opens picker sheet with empty state: 'Create your first template' CTA card + 'Start blank workout' button. Picker always shows.

### Ghost Targets (Last-Used Values)
- **D-05:** Template-loaded session shows last-used actual values as gray placeholder text (ghost) in weight/reps/etc. fields. Fields start empty but ghost shows reference value.
- **D-06:** User can accept ghost values via two mechanisms:
  - **Keyboard enter/submit** on any empty field fills the entire set row at once (weight + reps + RPE)
  - **Dedicated 'Fill all' button** fills ALL rows and ALL fields at once with last-session values
- **D-07:** If user doesn't interact with ghost values (no enter, no fill button), fields remain empty — ghost values are NOT auto-saved.

### ProgressionEngine Overlay (Pro-Gated)
- **D-08:** ProgressionEngine suggestions appear as small text below the input fields (e.g., '↑ 85kg suggested') alongside the ghost placeholder. User sees both last-used ghost in field and progression suggestion below.
- **D-09:** Pro users get two fill buttons: 'Fill last' (fills last-used values) and 'Fill suggested' (fills ProgressionEngine values). Free users see only 'Fill last'.
- **D-10:** ProgressionEngine requires exercise history to generate suggestions. For exercises with no prior history, no suggestion text shown — only ghost from template targets.

### Dashboard Quick-Start Cards
- **D-11:** Quick-start cards appear below HeroReadinessCard, above metrics strip. Horizontal scroll, max 3-4 compact cards.
- **D-12:** Card sources: favorited templates first, then TemplateSuggestionEngine's pick for today (Pro + sufficient data). No duplicates.
- **D-13:** Quick-start section hidden entirely when user has zero templates. Appears after first template is created.
- **D-14:** Tapping a dashboard quick-start card opens ActiveWorkoutSheet pre-filled from that template (same as carousel tap).

### TemplateSuggestionEngine
- **D-15:** Suggestion surfaced as highlighted card in Workout Log carousel with 'Suggested' label. Auto-centered in carousel. No separate banner or modal.
- **D-16:** Insufficient data fallback (< 2 weeks or no clear pattern): silent fallback to Phase 11 centering logic (scheduledDays match → most recently used). No 'learning' or 'not enough data' message.
- **D-17:** Engine uses two signals: day-of-week usage frequency (primary) AND current recovery zone (secondary). Recovery-aware: if user is in red/yellow zone, engine suggests lighter template from their library instead of usual heavy pick.
- **D-18:** Recovery conflict resolution: when recovery zone conflicts with usual template, suggest lighter alternative with 'Recovery-adjusted' note on the card. If user has only one template, still suggest it (no alternative available).
- **D-19:** Pro-gated. Free users see carousel centering via scheduledDays/lastUsedAt but no 'Suggested' label or recovery-aware swapping.

### Claude's Discretion
- Template picker sheet layout and visual design (card sizing, spacing)
- 'Fill last' / 'Fill suggested' button placement and styling in ActiveWorkoutSheet
- Ghost placeholder text color/opacity
- How ProgressionEngine suggestion text is styled below fields
- Dashboard quick-start card visual design (compact horizontal cards)
- 'Suggested' and 'Recovery-adjusted' label styling on carousel cards
- How to determine "lighter" template (exercise count, historical TSS, sport type heuristic)
- Animation/transition when pre-filling ActiveWorkoutSheet from template

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Models & Repository
- `WorkloadApp/Models/WorkoutTemplate.swift` — WorkoutTemplate with scheduledDays, isFavorite, lastUsedAt, usageCount fields (Phase 9)
- `WorkloadApp/Repositories/TemplateRepository.swift` — fetchAthleteTemplates, fetchFavorites, CRUD operations

### Existing Views to Modify
- `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift` — Add ghost target display, fill buttons, ProgressionEngine overlay
- `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift` — Modify '+' button to open picker sheet instead of ActiveWorkoutSheet directly
- `WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift` — Change tap action from preview to start-session, add 'Suggested' label support
- `WorkloadApp/Views/WorkoutLog/TemplatePreviewSheet.swift` — Move to long-press context menu trigger
- `WorkloadApp/Views/Dashboard/DashboardView.swift` — Add quick-start card section below HeroReadinessCard

### Engines
- `WorkloadApp/Services/ProgressionEngine.swift` — suggest() method, ExerciseSuggestion/SetSuggestion types, fetchHistory() helper. Already complete, needs integration into ActiveWorkoutSheet.
- `WorkloadApp/Views/WorkoutLog/FinishWorkoutSheet.swift` — Finish workout flow (update lastUsedAt/usageCount on template after session)

### Design System
- `DESIGN.md` — 0pt border radius, no shadows, DM Sans, accent only on readiness score, 8pt grid

### Requirements
- `.planning/REQUIREMENTS.md` — TMPL-03, TMPL-04, TMPL-06, TMPL-07, TMPL-08
- `.planning/ROADMAP.md` — Phase 12 success criteria

### Prior Context
- `.planning/phases/09-foundation-cold-start-engine/09-CONTEXT.md` — Template ownership model, field design
- `.planning/phases/11-template-management-creation/11-CONTEXT.md` — Carousel display, management actions, save-as-template flow

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TemplateCarouselSection` — Full carousel with centering logic (scheduledDays, lastUsedAt), swipe/context menu. Modify tap action and add suggestion label.
- `ProgressionEngine.suggest()` — Takes exerciseName, category, TrainingContext, history. Returns ExerciseSuggestion with SetSuggestion array and rationale.
- `ProgressionEngine.fetchHistory()` — Fetches last 8 sessions for a given exercise from SwiftData.
- `TemplatePreviewSheet` — Template detail view (move from tap to long-press trigger).
- `WelcomeActionCard` / `TrainingProfileCard` — Dashboard card patterns for quick-start section reference.

### Established Patterns
- Carousel centering uses ScrollView(.horizontal) + GeometryReader scale transform
- ActiveWorkoutSheet manages exercises via @State arrays of draft models
- ProgressionEngine is pure struct with static methods — no state, no dependencies
- Dashboard cards follow VStack layout with consistent spacing
- Pro-gating uses `container.subscriptionService.isPro` checks

### Integration Points
- `WorkoutLogView` '+' button → needs to open picker sheet instead of ActiveWorkoutSheet
- `TemplateCarouselSection.onPreviewTemplate` callback → change to `onStartFromTemplate`
- `ActiveWorkoutSheet` init → needs optional `WorkoutTemplate` parameter to pre-fill exercises
- `DashboardView` VStack → insert quick-start section after HeroReadinessCard
- `FinishWorkoutSheet` / session save → update template lastUsedAt and usageCount

</code_context>

<specifics>
## Specific Ideas

- Ghost placeholder uses `ColorTokens.text3` (secondary text color) for gray appearance
- ProgressionEngine suggestion line: '↑ 85kg suggested' or '→ maintain 82.5kg' styled in `ColorTokens.text3` with `Font.Tokens.caption`
- 'Fill last' / 'Fill suggested' buttons could be toolbar items or inline buttons above the exercise list
- 'Suggested' label on carousel card follows same design language as 'Estimated' label from Phase 10 cold-start
- 'Recovery-adjusted' note uses same secondary text treatment
- TemplateSuggestionEngine is a new pure struct with static methods (follows engine pattern)
- Template "lightness" heuristic: compare historical average session TSS per template, pick one with lower TSS when recovery is compromised
- After completing a template-based session, update `lastUsedAt` and increment `usageCount` on the source template

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 12-template-driven-workouts-smart-suggestions*
*Context gathered: 2026-05-09*
