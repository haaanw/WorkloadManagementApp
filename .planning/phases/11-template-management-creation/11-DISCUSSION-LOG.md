# Phase 11: Template Management & Creation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-09
**Phase:** 11-template-management-creation
**Areas discussed:** Template management location, Save-as-template flow, Template editor adaptations, Management actions UX

---

## Template Management Location

| Option | Description | Selected |
|--------|-------------|----------|
| Inside Workout Log tab | Templates section at top of workout log, natural proximity to workouts | ✓ |
| Dedicated nav destination | Separate 'Templates' screen accessible from Profile or toolbar button | |
| New tab | Separate 'Templates' tab in tab bar (6th tab) | |

**User's choice:** Inside Workout Log tab
**Notes:** None

## Template Display Style

| Option | Description | Selected |
|--------|-------------|----------|
| Hero card + scroll row | Today's template as prominent hero card, others in horizontal scroll below | |
| Centered carousel | Horizontal carousel auto-scrolled so today's template is centered and enlarged | ✓ |
| Smart list with pinned top | Vertical list with today's template pinned to top with TODAY badge | |

**User's choice:** Centered carousel
**Notes:** User specifically wants schedule-aware display where today's template gets priority placement based on scheduledDays weekday match. When it's Wednesday, Wednesday's workout should be centered/easiest to access.

## No-Schedule Fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Most recently used | Center on template with latest lastUsedAt | ✓ (initial) |
| First favorite | Center on first favorited template | |
| First in list | No special centering | |
| You decide | Claude picks | |

**User's choice:** Most recently used initially, then learn user's pattern over time
**Notes:** User wants the system to start with most-recently-used fallback, then adapt to user preferences over time. The pattern-learning component maps to Phase 12's TemplateSuggestionEngine.

## Save-as-Template Timing

| Option | Description | Selected |
|--------|-------------|----------|
| In finish confirmation | Toggle/checkbox in existing finish workout alert alongside RPE | ✓ |
| Post-save sheet | Separate sheet after session saves asking to save as template | |
| Session detail action | Button on session detail view in history | |

**User's choice:** In finish confirmation
**Notes:** None

## Save-as-Template Confirmation Step

| Option | Description | Selected |
|--------|-------------|----------|
| Quick save, edit later | Auto-creates template using session name + exercises in single group | |
| Confirmation sheet | Opens TemplateEditorSheet pre-filled with session data for editing | |
| You decide | Claude picks | ✓ |

**User's choice:** You decide
**Notes:** Claude has discretion on whether to quick-save or show editor sheet.

## Schedule Picker in Editor

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, in editor | Weekday toggle row (M T W T F S S) in template editor | ✓ |
| Defer to Phase 12 | Skip schedule picker, add in Phase 12 | |
| You decide | Claude picks | |

**User's choice:** Yes, in editor
**Notes:** None

## Editor Differentiation

| Option | Description | Selected |
|--------|-------------|----------|
| Same editor + schedule | Reuse coach TemplateEditorSheet + add schedule picker + favorite toggle | ✓ |
| Simplified athlete version | Stripped down editor with fewer fields | |
| You decide | Claude picks | |

**User's choice:** Same editor + schedule
**Notes:** None

## Management Actions UX

| Option | Description | Selected |
|--------|-------------|----------|
| Swipe + long-press | Swipe left for destructive actions, long-press for full context menu | ✓ |
| Tap opens detail view | Card tap opens detail screen with action buttons | |
| Full management screen | Carousel is display-only, separate management view | |

**User's choice:** Swipe + long-press
**Notes:** None

## Carousel Card Tap Action

| Option | Description | Selected |
|--------|-------------|----------|
| Start workout directly | Tap opens ActiveWorkoutSheet pre-filled with template exercises | |
| Preview then start | Tap shows read-only preview with Start button | |
| You decide | Claude picks | ✓ |

**User's choice:** You decide
**Notes:** Claude has discretion.

---

## Claude's Discretion

- Carousel card tap action (start workout directly vs. preview-then-start)
- Save-as-template confirmation step (quick save vs. editor sheet)
- Carousel card visual design
- Empty state for zero templates
- Whether "New Template" is a carousel card or separate button

## Deferred Ideas

- Pattern-based template suggestion learning — Phase 12 TemplateSuggestionEngine
- Template-driven workout launching — Phase 12
- Dashboard quick-start cards — Phase 12
- ProgressionEngine overlay — Phase 12
