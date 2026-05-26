# Phase 17: Cycle Data Foundation - Pattern Map

**Mapped:** 2026-05-14
**Files analyzed:** 8 (new/modified)
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `WorkloadApp/Models/MenstrualCycleSnapshot.swift` | model | CRUD | `WorkloadApp/Models/RecoverySnapshot.swift` | exact |
| `WorkloadApp/Models/Enums.swift` (add CyclePhase) | model | transform | `WorkloadApp/Models/Enums.swift` (SportType) | exact |
| `WorkloadApp/Services/CycleTrackingService.swift` | service | request-response | `WorkloadApp/Services/HealthKitService.swift` | role-match |
| `WorkloadApp/Services/HealthKitService.swift` (extend readTypes) | service | request-response | self (existing readTypes pattern) | exact |
| `WorkloadApp/Models/Athlete.swift` (add fields) | model | CRUD | self (existing optional Bool fields) | exact |
| `WorkloadApp/Views/Profile/ProfileView.swift` (add section) | component | request-response | self (Training Profile section) | exact |
| `WorkloadApp/Services/SyncService.swift` (extend AthleteRow) | service | CRUD | self (existing AthleteRow + pushAthlete) | exact |
| `WorkloadApp/App/WorkloadApp.swift` (register model) | config | -- | self (existing schema array) | exact |

## Pattern Assignments

### `WorkloadApp/Models/MenstrualCycleSnapshot.swift` (model, CRUD)

**Analog:** `WorkloadApp/Models/RecoverySnapshot.swift`

**Imports pattern** (lines 1-2):
```swift
import Foundation
import SwiftData
```

**Core @Model pattern** (lines 4-54):
```swift
@Model
final class RecoverySnapshot {
    @Attribute(.unique) var id: UUID
    var date: Date
    var hrvSDNN: Double?
    var restingHR: Double?
    var sleepDurationMinutes: Double?
    var sleepScore: Double?
    var bodyTemp: Double?
    var vo2Max: Double?
    var recoveryScore: Double
    var hrvBaseline: Double?
    var restingHRBaseline: Double?
    var dataSource: RecoveryDataSource
    var updatedAt: Date

    var athlete: Athlete?

    var zone: RecoveryZone {
        RecoveryZone.classify(score: recoveryScore)
    }

    init(
        id: UUID = UUID(),
        date: Date = .now,
        hrvSDNN: Double? = nil,
        restingHR: Double? = nil,
        sleepDurationMinutes: Double? = nil,
        sleepScore: Double? = nil,
        bodyTemp: Double? = nil,
        vo2Max: Double? = nil,
        recoveryScore: Double = 50,
        hrvBaseline: Double? = nil,
        restingHRBaseline: Double? = nil,
        dataSource: RecoveryDataSource = .healthKit
    ) {
        self.id = id
        self.date = date
        // ... all field assignments
        self.updatedAt = .now
    }
}
```

**Key rules for MenstrualCycleSnapshot:**
- `@Attribute(.unique) var id: UUID` is required
- `var athlete: Athlete?` relationship (inverse registered on Athlete via `@Relationship(deleteRule: .cascade)`)
- All fields optional or with defaults in init (SwiftData migration safety per Pitfall 4)
- `var updatedAt: Date` timestamp
- NO SyncService integration (D-12: local-only)

---

### `WorkloadApp/Models/Enums.swift` — add CyclePhase (model, transform)

**Analog:** `WorkloadApp/Models/Enums.swift` — SportType enum (lines 5-39)

**Core enum pattern** (lines 5-39):
```swift
enum SportType: String, Codable, CaseIterable, Identifiable {
    case lifting
    case running
    case cycling
    case teamSport
    case crossfit
    case swimming
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lifting: "Lifting"
        case .running: "Running"
        case .cycling: "Cycling"
        case .teamSport: "Team Sport"
        case .crossfit: "CrossFit"
        case .swimming: "Swimming"
        case .custom: "Custom"
        }
    }
}
```

**Key rules for CyclePhase:**
- Conform to `String, Codable, CaseIterable, Identifiable`
- `var id: String { rawValue }`
- `var displayName: String` computed property with switch
- Cases: `earlyFollicular`, `lateFollicular`, `ovulatory`, `earlyLuteal`, `lateLuteal`, `unknown` (D-10)

---

### `WorkloadApp/Services/CycleTrackingService.swift` (service, request-response)

**Analog:** `WorkloadApp/Services/HealthKitService.swift`

**Imports pattern** (lines 1-2):
```swift
import Foundation
import HealthKit
```

**Class declaration pattern** (lines 33-35):
```swift
@MainActor
@Observable
final class HealthKitService {
    private let store = HKHealthStore()
    private(set) var isAuthorized = false
```

**Category sample fetch pattern** — use for `.menstrualFlow` (lines 100-132, sleep analysis pattern):
```swift
func fetchLastNightSleep() async throws -> Double? {
    let type = HKCategoryType(.sleepAnalysis)
    let calendar = Calendar.current
    let now = Date.now
    let startOfToday = calendar.startOfDay(for: now)
    let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!

    let predicate = HKQuery.predicateForSamples(
        withStart: startOfYesterday,
        end: now,
        options: .strictStartDate
    )

    let descriptor = HKSampleQueryDescriptor(
        predicates: [.categorySample(type: type, predicate: predicate)],
        sortDescriptors: [SortDescriptor(\.startDate)]
    )

    let samples = try await descriptor.result(for: store)
    // ... process samples
}
```

**Quantity sample fetch pattern** — use for wrist temp history (lines 287-296):
```swift
private func fetchSamples(type: HKQuantityType, days: Int) async throws -> [HKQuantitySample] {
    let startDate = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: .now, options: .strictStartDate)

    let descriptor = HKSampleQueryDescriptor(
        predicates: [.quantitySample(type: type, predicate: predicate)],
        sortDescriptors: [SortDescriptor(\.startDate)]
    )
    return try await descriptor.result(for: store)
}
```

**Key rules for CycleTrackingService:**
- `@MainActor @Observable final class` (D-11, needs HKHealthStore)
- Holds `private let store = HKHealthStore()` (or receives HealthKitService via init)
- Use `HKSampleQueryDescriptor` with `.categorySample()` for menstrual flow
- Read `sample.metadata?[HKMetadataKeyMenstrualCycleStart] as? Bool` for cycle start detection
- Phase estimation can be a static method or separate engine struct
- `CycleContext` struct returned for downstream consumption (D-09)

---

### `WorkloadApp/Services/HealthKitService.swift` — extend readTypes (service, request-response)

**Analog:** self — existing `readTypes` computed property (lines 38-56)

**readTypes extension pattern** (lines 38-56):
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
    ]
    // Apple sleeping wrist temperature (iOS 17+)
    if let wristTemp = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
        types.insert(wristTemp)
    }
    // HKWorkout type for auto-importing workouts
    types.insert(HKWorkoutType.workoutType())
    return types
}
```

**Add these 6 types to the `types` set (D-01):**
```swift
HKCategoryType(.menstrualFlow),
HKCategoryType(.contraceptive),
HKCategoryType(.pregnancy),
HKCategoryType(.lactation),
HKCategoryType(.irregularMenstrualCycles),
HKCategoryType(.ovulationTestResult),
```

---

### `WorkloadApp/Models/Athlete.swift` — add fields (model, CRUD)

**Analog:** self — existing optional fields pattern (lines 17-19)

**Optional field pattern** (lines 17-19):
```swift
var trainingFrequency: TrainingFrequency?
var experienceLevel: ExperienceLevel?
```

**Add three optional Bool fields (D-07):**
```swift
var isOnHormonalContraceptive: Bool?
var isPregnant: Bool?
var isLactating: Bool?
```

**Key rule:** These are optional Bools (not `Bool = false`) so SwiftData lightweight migration adds them as nil for existing users without schema issues. Do NOT add them to the existing `init()` as required params — add as optional params with `nil` defaults.

**Also add `@Relationship` for MenstrualCycleSnapshot:**
```swift
@Relationship(deleteRule: .cascade, inverse: \MenstrualCycleSnapshot.athlete)
var menstrualCycleSnapshots: [MenstrualCycleSnapshot] = []
```

---

### `WorkloadApp/Views/Profile/ProfileView.swift` — add section (component, request-response)

**Analog:** self — Training Profile section pattern (lines 62-82)

**Section structure pattern** (lines 62-82):
```swift
// Training Profile (D-03)
sectionHeader("TRAINING PROFILE")
if let profile = trainingProfiles.first {
    // Profile exists: show summary rows
    profileRow("Sessions / week", value: "\(profile.sessionsPerWeek)")
    divider()
    profileRow("Avg duration", value: "\(profile.avgDurationMinutes) min")
    divider()
    // ...
    actionButton("Edit Profile") {
        showTrainingProfileSheet = true
    }
} else {
    // No profile: show setup prompt
    actionButton("Set up training profile") {
        showTrainingProfileSheet = true
    }
}
sectionDivider()
```

**Toggle row pattern** (lines 106-138, Coach Enable toggle):
```swift
HStack {
    Text("Enable Coach Mode")
        .font(.Tokens.body)
        .foregroundStyle(ColorTokens.text1)
    Spacer()
    Toggle("", isOn: Binding(
        get: { athlete.isCoach },
        set: { newValue in
            athlete.isCoach = newValue
            athlete.updatedAt = .now
            try? modelContext.save()
            Task { await container.syncService.pushAthlete(athlete) }
        }
    ))
    .labelsHidden()
}
.padding(.horizontal, 16)
.padding(.vertical, 12)
```

**Picker row pattern** (lines 45-48):
```swift
editablePicker("Sport", selection: Binding(
    get: { athlete.sportType },
    set: { athlete.sportType = $0; saveAthlete(athlete) }
), options: SportType.allCases) { $0.displayName }
```

**Helper methods used** (lines 486-586):
- `sectionHeader(_ title: String)` — uppercase label
- `profileRow(_ label: String, value: String)` — read-only key-value row
- `divider()` — 0.5pt divider with leading padding
- `sectionDivider()` — full-width divider
- `editablePicker(...)` — picker with menu

**Save pattern** (lines 600-604):
```swift
private func saveAthlete(_ athlete: Athlete) {
    athlete.updatedAt = .now
    try? modelContext.save()
    Task { await container.syncService.pushAthlete(athlete) }
}
```

**Key rules for "Cycle & Hormones" section:**
- Insert after the TRAINING PROFILE section and before PREFERENCES
- Visible only when HealthKit menstrual data exists or permissions granted (D-03)
- Use Toggle for `isOnHormonalContraceptive`, `isPregnant`, `isLactating`
- Call `saveAthlete(athlete)` on each toggle change to sync to Supabase
- Use `editablePicker` or `Toggle` with `Binding(get:set:)` pattern

---

### `WorkloadApp/Services/SyncService.swift` — extend AthleteRow (service, CRUD)

**Analog:** self — AthleteRow struct + pushAthlete method

**AthleteRow pattern** (lines 808-823):
```swift
struct AthleteRow: Codable {
    let id: UUID
    let userId: UUID
    let displayName: String?
    let sportType: String?
    let weightUnit: String?
    let acwrMethod: String?
    let loadMetricPreference: String?
    let maxHeartRate: Int?
    let dateOfBirth: Date?
    let isCoach: Bool?
    let trainingFrequency: String?
    let experienceLevel: String?
    let createdAt: Date
    let updatedAt: Date
}
```

**Add to AthleteRow:**
```swift
let isOnHormonalContraceptive: Bool?
let isPregnant: Bool?
let isLactating: Bool?
```

**pushAthlete pattern** (lines 217-240):
```swift
func pushAthlete(_ athlete: Athlete) async {
    guard let userId = athlete.supabaseUserId else { return }
    let row = AthleteRow(
        id: athlete.id,
        userId: userId,
        displayName: athlete.displayName,
        sportType: athlete.sportType.rawValue,
        // ... existing fields
        isCoach: athlete.isCoach,
        trainingFrequency: athlete.trainingFrequency?.rawValue,
        experienceLevel: athlete.experienceLevel?.rawValue,
        createdAt: athlete.createdAt,
        updatedAt: athlete.updatedAt
    )
    do {
        _ = try await client.from("athletes").upsert(row).execute()
    } catch {
        logFailure("push athlete", error)
    }
}
```

**pullAthlete pattern** (lines 242-271) — add field merge:
```swift
// After existing field merges:
existingAthlete.isOnHormonalContraceptive = row.isOnHormonalContraceptive ?? existingAthlete.isOnHormonalContraceptive
existingAthlete.isPregnant = row.isPregnant ?? existingAthlete.isPregnant
existingAthlete.isLactating = row.isLactating ?? existingAthlete.isLactating
```

---

### `WorkloadApp/App/WorkloadApp.swift` — register model (config)

**Analog:** self — schema array (lines 18-36)

**Schema registration pattern** (lines 18-36):
```swift
let schema = Schema([
    Athlete.self,
    WorkoutSession.self,
    ExerciseEntry.self,
    SetRecord.self,
    WorkloadSnapshot.self,
    RecoverySnapshot.self,
    WellnessCheckIn.self,
    PersonalRecord.self,
    CoachAthleteRelationship.self,
    WorkoutTemplate.self,
    ExerciseGroup.self,
    TemplateExercise.self,
    TemplateSet.self,
    PrescribedWorkout.self,
    CustomExercise.self,
    BehaviorTag.self,
    TrainingProfile.self,
])
```

**Add `MenstrualCycleSnapshot.self` to the array.** Place after `RecoverySnapshot.self` for logical grouping.

---

## Shared Patterns

### Athlete Save + Sync
**Source:** `WorkloadApp/Views/Profile/ProfileView.swift` lines 600-604
**Apply to:** ProfileView "Cycle & Hormones" section toggle handlers
```swift
private func saveAthlete(_ athlete: Athlete) {
    athlete.updatedAt = .now
    try? modelContext.save()
    Task { await container.syncService.pushAthlete(athlete) }
}
```

### HealthKit Category Sample Query
**Source:** `WorkloadApp/Services/HealthKitService.swift` lines 100-132
**Apply to:** CycleTrackingService menstrual flow fetch
```swift
let type = HKCategoryType(.sleepAnalysis)  // change to .menstrualFlow
let predicate = HKQuery.predicateForSamples(withStart: startDate, end: .now, options: .strictStartDate)
let descriptor = HKSampleQueryDescriptor(
    predicates: [.categorySample(type: type, predicate: predicate)],
    sortDescriptors: [SortDescriptor(\.startDate)]
)
let samples = try await descriptor.result(for: store)
```

### @Model with Optional Fields + Defaults
**Source:** `WorkloadApp/Models/RecoverySnapshot.swift` lines 4-54
**Apply to:** MenstrualCycleSnapshot
- `@Attribute(.unique) var id: UUID`
- All domain-specific fields optional or with sensible defaults
- `var athlete: Athlete?` inverse relationship
- `var updatedAt: Date`

### ProfileView Section Layout
**Source:** `WorkloadApp/Views/Profile/ProfileView.swift` lines 39-100
**Apply to:** "Cycle & Hormones" section
- `sectionHeader("SECTION NAME")` for header
- `editablePicker(...)` or Toggle for input rows
- `divider()` between rows
- `sectionDivider()` after section
- Binding(get:set:) with `saveAthlete()` call in setter

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `CycleContext` struct (in CycleTrackingService) | utility | transform | No existing lightweight context struct in codebase, but pattern is trivial (plain Swift struct with computed properties). Use RESEARCH.md code example directly. |

## Supabase Migration

**Not a code file but required:** SQL migration to add columns to `athletes` table.

**Analog:** `migrations/delete_own_account.sql` (existing migration pattern)

```sql
ALTER TABLE athletes ADD COLUMN is_on_hormonal_contraceptive BOOLEAN;
ALTER TABLE athletes ADD COLUMN is_pregnant BOOLEAN;
ALTER TABLE athletes ADD COLUMN is_lactating BOOLEAN;
```

Nullable columns, no default needed, no backfill required.

## Metadata

**Analog search scope:** `WorkloadApp/Models/`, `WorkloadApp/Services/`, `WorkloadApp/Views/Profile/`, `WorkloadApp/App/`
**Files scanned:** 8 analog files read
**Pattern extraction date:** 2026-05-14
