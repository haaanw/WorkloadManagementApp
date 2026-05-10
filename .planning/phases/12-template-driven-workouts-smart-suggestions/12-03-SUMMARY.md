---
phase: 12-template-driven-workouts-smart-suggestions
plan: 03
subsystem: views
tags: [template-picker, carousel, dashboard, quick-start, suggestion-badge]
status: complete
started: 2025-05-10
completed: 2025-05-10
---

## Summary

Created TemplatePickerSheet, rewired '+' button to open picker instead of ActiveWorkoutSheet directly, changed carousel tap behavior from preview to start-session, added suggestion badges for Pro users, and added Dashboard QuickStartSection with horizontal template cards.

## Self-Check: PASSED

All acceptance criteria verified:
- TemplatePickerSheet shows template cards with name, sport icon, exercise count, last-used date
- Empty state with "No templates yet" and "Create Template" CTA
- "Start blank workout" always visible
- '+' button opens picker; selecting template opens pre-filled ActiveWorkoutSheet
- Carousel tap starts session; long-press context menu includes Preview
- Suggestion badges ("SUGGESTED" / "RECOVERY-ADJUSTED") for Pro users
- Dashboard QuickStartSection shows horizontal cards below HeroReadinessCard
- QuickStart falls back to recent templates when no favorites exist
- sheet(item:) pattern prevents empty sheet on tap
- Human verification: approved

## Key Files

### Created
- `WorkloadApp/Views/WorkoutLog/TemplatePickerSheet.swift` — Template selection sheet with 2-column grid, empty state, blank workout option

### Modified
- `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift` — '+' button redirected to TemplatePickerSheet, carousel callback renamed
- `WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift` — Tap-to-start, suggestion badges, onStartFromTemplate callback
- `WorkloadApp/Views/Dashboard/DashboardView.swift` — QuickStartSection with favorites/recent fallback, sheet(item:) binding

## Commits
- e1054db: feat(12-03): create TemplatePickerSheet and wire '+' button redirect
- ee11063: feat(12-03): carousel tap-to-start, suggestion badges, dashboard quick-start
- af57fe8: fix(12): show quick-start cards even without favorited templates
- 3f7254a: fix(12): use sheet(item:) for dashboard quick-start to prevent empty sheet

## Deviations
- [Rule 1 - Bug] Fixed RecoverySnapshot field name: `date` instead of `snapshotDate`
- [Rule 1 - Bug] Added explicit SortDescriptor type annotation for Swift type checker
- [Rule 1 - Bug] QuickStartSection: added fallback to recent templates when no favorites
- [Rule 1 - Bug] Dashboard: switched from sheet(isPresented:) to sheet(item:) to fix empty sheet
