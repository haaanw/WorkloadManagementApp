---
phase: 04-onboarding-polish
reviewed: 2026-04-22T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - WorkloadApp/Models/Enums.swift
  - WorkloadApp/Models/Athlete.swift
  - WorkloadApp/Services/SyncService.swift
  - WorkloadApp/Views/Onboarding/OnboardingView.swift
  - WorkloadApp/App/AppRouter.swift
  - WorkloadApp/Views/Dashboard/WelcomeActionCard.swift
  - WorkloadApp/Views/Dashboard/DashboardView.swift
  - WorkloadApp/Views/Profile/ProfileView.swift
findings:
  critical: 0
  warning: 5
  info: 4
  total: 9
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-04-22T00:00:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Reviewed 8 files spanning the onboarding flow, sync layer, app routing, dashboard, and profile. No critical security or data-loss issues were found. The onboarding flow is generally well structured, but there are five warnings covering a silent completion guard bypass, a fragile swipe-lock mechanism, repeated redundant fetches in AppRouter, an ACWR boundary classification ambiguity, and a sync payload that diverges between two near-identical pull methods. Four info-level items cover dead code, a missing `CodingKeys` risk, and a per-render DateFormatter allocation.

---

## Warnings

### WR-01: `completeOnboarding()` silently no-ops if user bypasses step guards

**File:** `WorkloadApp/Views/Onboarding/OnboardingView.swift:282-292`
**Issue:** `completeOnboarding()` guards on `selectedFrequency != nil && selectedLevel != nil` before writing, and silently calls `onComplete()` — which transitions to the main app — even when the guard fails. On step 3, both the "Connect Health" and "Skip for now" buttons call `completeOnboarding()` directly. If `selectedFrequency` or `selectedLevel` is nil (e.g. user reached step 3 via a programmatic path that bypasses the Continue button gate), the athlete profile is **not** updated but `onComplete()` is still invoked, leaving the athlete without `trainingFrequency`/`experienceLevel` and re-triggering onboarding on next launch.

**Fix:** Separate the save logic from the completion callback so that `onComplete()` is only ever called after a successful save, or assert/log in the nil branch:
```swift
private func completeOnboarding() {
    guard let athlete = athletes.first,
          let freq = selectedFrequency,
          let level = selectedLevel else {
        // Cannot proceed without selections — should not be reachable in normal flow
        assertionFailure("completeOnboarding called without required selections")
        return  // Do NOT call onComplete — stay on screen
    }
    athlete.trainingFrequency = freq
    athlete.experienceLevel = level
    athlete.updatedAt = .now
    try? modelContext.save()
    Task { await container.syncService.pushAthlete(athlete) }
    onComplete()
}
```

---

### WR-02: `.gesture(DragGesture())` swipe suppression is unreliable

**File:** `WorkloadApp/Views/Onboarding/OnboardingView.swift:32`
**Issue:** Using `.gesture(DragGesture())` on a `TabView` with `.page` style is a well-known hack to suppress horizontal swipe navigation. It is not an officially supported API contract and its behavior has changed between iOS releases. On iOS 17 specifically it can interfere with vertical scroll gestures inside embedded `VStack`/`ScrollView` content, causing swipe-to-scroll to be intercepted. Additionally, the `.easeOut` animation on `currentStep += 1` runs while the tab can still be freely swiped between — a fast swipe before the animation settles can leave `currentStep` out of sync with the visible page.

**Fix:** Use a `@Binding`-driven `TabView` but gate forward navigation exclusively through the Continue button. On iOS 16+ you can disable the built-in swipe using `.tabViewStyle(.page(indexDisplayMode: .never))` together with `.interactiveDismissDisabled()` (on sheet), or alternatively replace the `TabView` with a manual `ZStack` + offset animation that you fully control:
```swift
// Instead of TabView paging, render steps with conditional visibility:
ZStack {
    frequencyStep.opacity(currentStep == 0 ? 1 : 0)
    experienceStep.opacity(currentStep == 1 ? 1 : 0)
    healthKitStep.opacity(currentStep == 2 ? 1 : 0)
}
.animation(.easeOut(duration: 0.25), value: currentStep)
```

---

### WR-03: DEBUG mock data seeder runs on every cold launch, not only first-time

**File:** `WorkloadApp/App/AppRouter.swift:101-106`
**Issue:** The DEBUG block at line 101 calls `MockDataSeeder.seed(modelContext:athlete:)` unconditionally on every cold launch for authenticated athletes, including sessions where real workout or recovery data already exists. If `MockDataSeeder.seed` inserts new records without checking for duplicates, this accumulates duplicate mock sessions and snapshots on every app restart during development. This also means any real manual test data entered during debugging is mixed with mock data on the next launch.

**Fix:** Gate the seeder behind a check that no real sessions exist, or use a UserDefaults flag set on first seed:
```swift
#if DEBUG
if let athlete = (try? modelContext.fetch(FetchDescriptor<Athlete>()))?.first,
   athlete.sessions.isEmpty {
    MockDataSeeder.seed(modelContext: modelContext, athlete: athlete)
}
#endif
```

---

### WR-04: ACWR zone boundary at 1.3 is ambiguous — both `.optimal` and `.caution` ranges include it

**File:** `WorkloadApp/Models/Enums.swift:97-103`
**Issue:** The `classify(acwr:ctl:)` switch has overlapping closed ranges:
```swift
case 0.8...1.3: return .optimal   // includes 1.3
case 1.3...1.5: return .caution   // also includes 1.3, but never reached
```
Swift evaluates cases top-to-bottom and stops at the first match. An ACWR of exactly `1.3` will always classify as `.optimal`, never `.caution`. If the domain intent is that 1.3 is the threshold where caution begins, the first case should use a half-open range.

**Fix:**
```swift
case 0.8..<1.3: return .optimal
case 1.3..<1.5: return .caution
default:        return .danger
```

---

### WR-05: `pullCoachPrescriptions` partially syncs records — groups JSON and most fields skipped

**File:** `WorkloadApp/Services/SyncService.swift:802-828`
**Issue:** `pullCoachPrescriptions` (line 802) and `pullPrescribedWorkouts` (line 753) both pull from `prescribed_workouts` but `pullCoachPrescriptions` only updates `status`, `completedSessionId`, and `updatedAt` on existing records, and only sets `id`, `coachId`, `athleteId`, `templateId`, `scheduledDate`, `templateName`, `status`, `completedSessionId` on new ones — omitting `sportType`, `sessionType`, `notes`, `groupsJson`, `createdAt`. Coach-side records created via this path are structurally incomplete (missing exercise groups) and would render incorrectly in any coach UI that shows template detail.

**Fix:** Consolidate both methods into a single private helper that applies the full field set, used by both athlete-pull and coach-pull paths:
```swift
private func applyPrescribedWorkoutRow(_ row: PrescribedWorkoutRow, to rx: PrescribedWorkout, context: ModelContext) {
    rx.id = row.id
    rx.coachId = row.coachId
    rx.athleteId = row.athleteId
    rx.templateId = row.templateId
    rx.scheduledDate = row.scheduledDate
    rx.status = PrescriptionStatus(rawValue: row.status) ?? .assigned
    rx.completedSessionId = row.completedSessionId
    rx.notes = row.notes
    rx.templateName = row.templateName
    rx.sportType = SportType(rawValue: row.sportType) ?? .lifting
    rx.sessionType = SessionType(rawValue: row.sessionType) ?? .strength
    rx.updatedAt = row.updatedAt
    rx.createdAt = row.createdAt
    if let groupsJSON = row.groupsJson {
        for group in rx.groups { context.delete(group) }
        rx.groups = Self.decodeGroups(from: groupsJSON)
    }
}
```

---

## Info

### IN-01: `AthleteRow` has no `CodingKeys` — snake_case mismatch risk

**File:** `WorkloadApp/Services/SyncService.swift:500-515`
**Issue:** `AthleteRow` conforms to `Codable` without a `CodingKeys` enum. Its Swift property names use camelCase (`userId`, `displayName`, `sportType`, `weightUnit`, `acwrMethod`, `loadMetricPreference`, `maxHeartRate`, `dateOfBirth`, `isCoach`, `trainingFrequency`, `experienceLevel`, `createdAt`, `updatedAt`) but Supabase columns are snake_case (`user_id`, `display_name`, etc.). If the Supabase Swift SDK does not apply a `.convertFromSnakeCase` key decoding strategy by default, all `AthleteRow` decodes will silently return `nil` for most fields. Other row structs (e.g. `BehaviorTagRow`) do define explicit `CodingKeys`.

**Fix:** Add explicit `CodingKeys` to `AthleteRow` to match all Supabase column names, consistent with the pattern used in `BehaviorTagRow`:
```swift
enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case displayName = "display_name"
    case sportType = "sport_type"
    case weightUnit = "weight_unit"
    case acwrMethod = "acwr_method"
    case loadMetricPreference = "load_metric_preference"
    case maxHeartRate = "max_heart_rate"
    case dateOfBirth = "date_of_birth"
    case isCoach = "is_coach"
    case trainingFrequency = "training_frequency"
    case experienceLevel = "experience_level"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
}
```

---

### IN-02: `profileRow(_:value:)` helper is defined but never called

**File:** `WorkloadApp/Views/Profile/ProfileView.swift:298-310`
**Issue:** The `profileRow` `@ViewBuilder` helper is defined but has zero call sites in the file. It appears to be a leftover from an earlier read-only profile layout that was replaced by `editableTextField` and `editablePicker`.

**Fix:** Remove the unused helper to reduce dead code:
```swift
// Delete lines 297–310 (profileRow function)
```

---

### IN-03: `removeRelationship(_:)` function is defined but no UI surfaces it

**File:** `WorkloadApp/Views/Profile/ProfileView.swift:422-428`
**Issue:** `removeRelationship(_:)` is fully implemented but there is no button or swipe action in the "MY COACHES" or "MY ATHLETES" sections that calls it. Users currently cannot unlink a coach or athlete from within the app.

**Fix:** Add a swipe-to-delete or contextMenu action on `LinkedPartyRow` entries in both the "MY COACHES" and "MY ATHLETES" sections, or remove the function if relationship removal is intentionally deferred.

---

### IN-04: `DateFormatter` re-allocated on every `HeroReadinessCard` body evaluation

**File:** `WorkloadApp/Views/Dashboard/DashboardView.swift:137-140`
**Issue:** `dateLabel` is a computed property that creates a new `DateFormatter` instance on every call. SwiftUI can re-evaluate `body` frequently. `DateFormatter` is a relatively expensive object to initialize.

**Fix:** Move the formatter to a static property to ensure it is created once:
```swift
private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEE d MMM"
    return f
}()

private var dateLabel: String {
    Self.dateFormatter.string(from: .now).uppercased()
}
```

---

_Reviewed: 2026-04-22T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
