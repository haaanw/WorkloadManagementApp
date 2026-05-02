---
phase: 10-cold-start-questionnaire
plan: 01
subsystem: cold-start-questionnaire
tags: [questionnaire, ui, persistence, cold-start]
dependency_graph:
  requires: [TrainingProfile model (09-01), ColdStartEngine (09-01)]
  provides: [TrainingProfileRepository, TrainingProfileCard, TrainingProfileSheet]
  affects: [DashboardView (future wiring), ProfileView (future re-edit entry)]
tech_stack:
  added: []
  patterns: [nil-sentinel form validation, in-memory predicate filtering]
key_files:
  created:
    - WorkloadApp/Repositories/TrainingProfileRepository.swift
    - WorkloadApp/Views/Dashboard/TrainingProfileCard.swift
    - WorkloadApp/Views/Profile/TrainingProfileSheet.swift
  modified:
    - workload management/workload management.xcodeproj/project.pbxproj
    - WorkloadApp/Repositories/TemplateRepository.swift
decisions:
  - "Used nil sentinel (@State Int? = nil) for required field validation instead of default values, ensuring explicit user selection before save enables"
  - "TrainingProfileSheet uses in-memory set membership for multi-select (movement types, injury regions) rather than SwiftData relationships"
  - "syncService called directly (non-optional) instead of optional chaining, matching existing AppContainer pattern"
metrics:
  duration: 10m 17s
  completed: "2026-05-02T14:19:27Z"
  tasks_completed: 3
  tasks_total: 3
  files_created: 3
  files_modified: 2
---

# Phase 10 Plan 01: Cold-Start Questionnaire Form Summary

TrainingProfileRepository with fetch/save/update persistence, TrainingProfileCard dashboard CTA matching WelcomeActionCard pattern, and TrainingProfileSheet scrollable form with 4 required + 4 optional fields calling ColdStartEngine.computeSeed() on save

## Task Execution

### Task 1: Create TrainingProfileRepository and TrainingProfileCard
**Commit:** 62590fb

Created `TrainingProfileRepository` following the `AthleteRepository` pattern -- `@MainActor final class` with `ModelContext` dependency injection and three methods: `fetchProfile(athleteId:)` using `#Predicate`, `saveProfile(_:)` with insert + save, and `updateProfile(_:)` with timestamp update + save.

Created `TrainingProfileCard` matching the `WelcomeActionCard` pattern exactly -- VStack with micro-caps "TRAINING PROFILE" header, title "Set up your training profile", description copy, and a full-width "Complete Profile" CTA button. No rounded corners, no shadows, no accent color. All fonts via `Font.Tokens`, all colors via `ColorTokens`.

Both files registered in Xcode project with 4 pbxproj entries each (PBXBuildFile, PBXFileReference, PBXGroup, PBXSourcesBuildPhase).

### Task 2: Create TrainingProfileSheet questionnaire form
**Commit:** 04a5bf7

Created the complete questionnaire form with:
- 4 required fields using `@State Int? = nil` sentinel pattern: sessions/week (1-14), average duration (preset minutes), typical effort (sRPE 1-10 with labeled options like "5 -- Moderate"), weeks at current level (non-linear preset values)
- 4 optional fields: training age (0-30 years), schedule type (Steady/Periodized), movement types (multi-select from `SportType.allCases`), injury history (expandable `BodyRegion` multi-select + notes TextField)
- `isFormValid` computed property gates the "Save Profile" button via `.disabled(!isFormValid)`
- Save handler calls `ColdStartEngine.computeSeed(input:)`, encodes injury data as JSON, and persists via `TrainingProfileRepository`
- Re-edit support via optional `existingProfile` parameter with `.onAppear` pre-fill
- `interactiveDismissDisabled(hasChanges)` prevents accidental swipe dismissal
- Toolbar: "Discard Changes" (leading, text2) / "Save Profile" (trailing, text1)

All design system constraints enforced: 0pt corners, no shadows, DM Sans fonts only, 8pt spacing grid, ColorTokens throughout.

### Task 3: Build verification
**Commit:** 2b4aac6

xcodebuild BUILD SUCCEEDED with all 3 new files compiling cleanly. Required fixing a pre-existing issue in `TemplateRepository.swift` (see Deviations).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed TemplateRepository #Predicate type-checker timeout**
- **Found during:** Task 3 (build verification)
- **Issue:** `TemplateRepository.fetchFavorites()` had a 4-condition `#Predicate` expression that exceeded the Swift compiler's type-check complexity budget, causing BUILD FAILED. The `fetchAthleteTemplates()` 3-condition predicate had the same issue when compiled in the same batch.
- **Fix:** Simplified both methods to use a single-condition `#Predicate` (athleteId match) with in-memory filtering for `isAthleteOwned`, `isArchived`, and `isFavorite` conditions.
- **Files modified:** `WorkloadApp/Repositories/TemplateRepository.swift`
- **Commit:** 2b4aac6

## Verification Results

1. TrainingProfileRepository exists with fetchProfile/saveProfile/updateProfile -- PASS
2. TrainingProfileCard renders with exact copywriting from UI-SPEC -- PASS
3. TrainingProfileSheet has all 8 form fields (4 required + 4 optional) -- PASS
4. Save button disabled until all 4 required fields are non-nil -- PASS
5. On save, ColdStartEngine.computeSeed() called and TrainingProfile saved -- PASS
6. All 3 files registered in Xcode project (4+ pbxproj entries each) -- PASS
7. No design system violations (no rounded corners, no shadows, no accent color, DM Sans only) -- PASS
8. xcodebuild BUILD SUCCEEDED -- PASS

## Self-Check: PASSED

All 3 created files exist on disk. All 3 task commits (62590fb, 04a5bf7, 2b4aac6) verified in git log.
