---
phase: 17-cycle-data-foundation
reviewed: 2026-05-14T12:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - WorkloadApp/Models/MenstrualCycleSnapshot.swift
  - WorkloadApp/Models/Enums.swift
  - WorkloadApp/Models/Athlete.swift
  - WorkloadApp/Services/CycleTrackingService.swift
  - WorkloadApp/Services/HealthKitService.swift
  - WorkloadApp/Services/SyncService.swift
  - WorkloadApp/App/WorkloadApp.swift
  - WorkloadApp/Views/Dashboard/DashboardView.swift
  - WorkloadApp/Views/Profile/ProfileView.swift
  - migrations/add_cycle_fields_to_athletes.sql
findings:
  critical: 1
  warning: 3
  info: 2
  total: 6
status: issues_found
---

# Phase 17: Code Review Report

**Reviewed:** 2026-05-14T12:00:00Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Phase 17 adds menstrual cycle data foundation: a new `MenstrualCycleSnapshot` model, `CyclePhase` enum, `CycleTrackingService` that reads HealthKit menstrual flow data, cycle/hormone fields on `Athlete`, sync support for the new fields, a dashboard soft prompt, and profile toggles for hormonal states. The SQL migration is minimal and clean.

The most significant issue is that `HealthKitService.readTypes` does not include `HKCategoryType(.menstrualFlow)`, meaning the app never requests authorization to read menstrual data from HealthKit. `CycleTrackingService` creates its own `HKHealthStore` instance and queries menstrual flow directly, which will silently return zero results if the user has not been prompted for that specific data type.

## Critical Issues

### CR-01: Menstrual flow HealthKit authorization never requested

**File:** `WorkloadApp/Services/HealthKitService.swift:38-56`
**Issue:** The `readTypes` set does not include `HKCategoryType(.menstrualFlow)`. The app's centralized `requestAuthorization()` method will never ask the user for permission to read menstrual data. `CycleTrackingService` creates a separate `HKHealthStore` instance (line 19) and calls queries on it directly without ever requesting authorization for menstrual flow. On iOS, HealthKit silently returns empty results for unauthorized types rather than throwing, so the service will appear to work but never return data.

**Fix:**
Add menstrual flow to `readTypes` in `HealthKitService.swift`:
```swift
private var readTypes: Set<HKObjectType> {
    var types: Set<HKObjectType> = [
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.heartRate),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.stepCount),
        HKQuantityType(.vo2Max),
        HKQuantityType(.bodyTemperature),
        HKCategoryType(.sleepAnalysis),
        HKCategoryType(.menstrualFlow),  // Phase 17: cycle tracking
    ]
    // ...
}
```

Additionally, `CycleTrackingService` should use the shared `HealthKitService`'s store or at minimum depend on authorization having been requested, rather than creating its own `HKHealthStore` instance.

## Warnings

### WR-01: CycleTrackingService creates a separate HKHealthStore instance

**File:** `WorkloadApp/Services/CycleTrackingService.swift:19`
**Issue:** `CycleTrackingService` instantiates its own `private let store = HKHealthStore()` rather than receiving the shared store or using `HealthKitService`. While Apple permits multiple `HKHealthStore` instances, this bypasses the centralized authorization flow and makes it unclear whether authorization has been granted. The architecture convention states services should receive dependencies via init.

**Fix:**
Either inject the `HKHealthStore` from `HealthKitService` or have `CycleTrackingService` accept `HealthKitService` as a dependency and delegate HealthKit queries to it.

### WR-02: upsertSnapshot fetches ALL MenstrualCycleSnapshots without predicate

**File:** `WorkloadApp/Services/CycleTrackingService.swift:291-293`
**Issue:** The `upsertSnapshot` method fetches every `MenstrualCycleSnapshot` in the database, then filters in memory to find today's snapshot for this athlete. As cycle data accumulates (365 snapshots/year), this becomes increasingly wasteful. More importantly, if the fetch fails silently (`try?`), a duplicate snapshot will be inserted.

**Fix:**
Use a predicate to narrow the fetch:
```swift
let today = Calendar.current.startOfDay(for: .now)
let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
let athleteId = athlete.id
let predicate = #Predicate<MenstrualCycleSnapshot> {
    $0.date >= today && $0.date < tomorrow
}
let descriptor = FetchDescriptor<MenstrualCycleSnapshot>(predicate: predicate)
let existingSnapshots = (try? context.fetch(descriptor)) ?? []
let todaySnapshot = existingSnapshots.first { $0.athlete?.id == athleteId }
```

### WR-03: Phase estimation edge case when cycleDay exceeds cycleLength

**File:** `WorkloadApp/Services/CycleTrackingService.swift:58, 183-200`
**Issue:** `cycleDay` is computed as days since last detected cycle start plus 1 (line 58). If the user's current cycle is longer than the median, `cycleDay` can exceed `cycleLength`. The `estimatePhase` method's switch statement will fall through to `.lateLuteal` for any `cycleDay` beyond the expected range, which is the correct default. However, there is no guard or confidence reduction for cycle days significantly past the expected length (e.g., cycleDay 40 on a 28-day median), which could produce misleading phase labels.

**Fix:**
Add a guard at the top of `estimatePhase` or reduce confidence when `cycleDay > cycleLength * 1.3`:
```swift
static func estimatePhase(cycleDay: Int, cycleLength: Int) -> CyclePhase {
    guard cycleDay <= cycleLength + 7 else { return .unknown }
    // ... rest of estimation
}
```

## Info

### IN-01: Dashboard cycle prompt links to system Settings, not HealthKit permissions

**File:** `WorkloadApp/Views/Dashboard/DashboardView.swift:88-91`
**Issue:** The "Open Settings" button uses `UIApplication.openSettingsURLString`, which opens the app's settings page in the Settings app. This does not directly take the user to HealthKit permissions. The user would need to navigate to Settings > Privacy > Health > Faros manually. Consider using the in-app `requestAuthorization()` flow instead, which presents the HealthKit permission sheet directly.

**Fix:**
Replace with a direct authorization request:
```swift
Button {
    Task { try? await container.healthKitService.requestAuthorization() }
} label: {
    Text("Enable in Health")
        .font(.Tokens.label)
        .foregroundStyle(ColorTokens.text1)
        .underline()
}
```

### IN-02: ProfileView notification denied message references "Tuwa" instead of "Faros"

**File:** `WorkloadApp/Views/Profile/ProfileView.swift:215`
**Issue:** The notification denied warning text says "Go to Settings > Tuwa to enable them." The app has been renamed to Faros (per project memory).

**Fix:**
```swift
Text("Notifications are disabled in Settings. Go to Settings > Faros to enable them.")
```

---

_Reviewed: 2026-05-14T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
