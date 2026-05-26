# Phase 14: Sync Hardening - Pattern Map

**Mapped:** 2026-05-10
**Files analyzed:** 7 (3 new, 4 modified)
**Analogs found:** 7 / 7

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `WorkloadApp/Services/SyncEntity.swift` | enum/config | N/A | `WorkloadApp/Models/Enums.swift` (SportType) | exact |
| `WorkloadApp/Services/SyncTimestampStore.swift` | service (observable state) | CRUD (UserDefaults) | `WorkloadApp/Services/SubscriptionService.swift` | role-match |
| `WorkloadApp/Views/Profile/SyncStatusView.swift` | component (detail view) | request-response (read-only) | `WorkloadApp/Views/Profile/ProfileView.swift` (HealthKitPermissionsView, lines 759-838) | exact |
| `WorkloadApp/Services/SyncService.swift` | service | request-response (network sync) | Self (existing file, lines 79-89 for `run()` pattern) | exact |
| `WorkloadApp/Views/Profile/ProfileView.swift` | component | request-response | Self (existing file, NavigationLink pattern lines 202-216) | exact |
| `WorkloadApp/App/AppRouter.swift` | router/coordinator | event-driven | Self (existing file, MainTabView lines 166-189 for TabView) | exact |
| `WorkloadApp/App/AppContainer.swift` | config/DI container | N/A | Self (existing file, signOut lines 80-89) | exact |

## Pattern Assignments

### `WorkloadApp/Services/SyncEntity.swift` (NEW - enum, config)

**Analog:** `WorkloadApp/Models/Enums.swift` — `SportType` enum (lines 5-39)

**Imports pattern** (line 1):
```swift
import Foundation
```

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

**Notes:** SyncEntity follows the same `String, CaseIterable, Identifiable` pattern. Does NOT need `Codable` since it's not persisted as a model field. Include `displayName` computed property for UI display. Also include `SyncDirection` enum (pull/push) in same file.

---

### `WorkloadApp/Services/SyncTimestampStore.swift` (NEW - observable service, UserDefaults CRUD)

**Analog:** `WorkloadApp/Services/SubscriptionService.swift` (lines 1-31)

**Imports + class declaration pattern** (lines 1-6):
```swift
import Foundation
import RevenueCat

@MainActor
@Observable
final class SubscriptionService {
```

**Observable state pattern** (lines 9-14):
```swift
    /// True when the user holds an active Athlete Pro OR Coach entitlement.
    private(set) var isPro: Bool = false

    /// True when the user holds an active Coach entitlement specifically.
    private(set) var isCoach: Bool = false
```

**Notes:** SyncTimestampStore follows the same `@MainActor @Observable final class` pattern. Uses `static let shared` singleton (similar to how SubscriptionService is instantiated once in AppContainer). No external dependencies -- only `Foundation` import needed. Wraps UserDefaults with typed keys derived from `SyncEntity.rawValue`. Error state kept in-memory as `@Observable` property (`lastErrors: [SyncEntity: SyncError]`). `hasAnyFailure` computed property for UI binding (analogous to `isPro`/`isCoach` booleans).

---

### `WorkloadApp/Views/Profile/SyncStatusView.swift` (NEW - detail view, read-only display)

**Analog:** `WorkloadApp/Views/Profile/ProfileView.swift` — `HealthKitPermissionsView` (lines 759-838)

**Imports pattern** (line 1-2 of ProfileView.swift):
```swift
import SwiftUI
import SwiftData
```

**View structure with environment** (lines 759-762):
```swift
struct HealthKitPermissionsView: View {
    @Environment(AppContainer.self) private var container
    @State private var isAuthorizing = false
    @State private var authError: String?
```

**List item with icon + label pattern** (lines 788-802):
```swift
ForEach(dataTypes, id: \.0) { item in
    HStack(spacing: 12) {
        Image(systemName: item.1)
            .font(.system(size: 14))
            .foregroundStyle(ColorTokens.text2)
            .frame(width: 24)
        Text(item.0)
            .font(.Tokens.body)
            .foregroundStyle(ColorTokens.text1)
        Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    Rectangle().fill(ColorTokens.divider).frame(height: 0.5).padding(.leading, 52)
}
```

**Section header pattern** (ProfileView lines 454-463):
```swift
private func sectionHeader(_ title: String) -> some View {
    Text(title)
        .font(.Tokens.micro)
        .foregroundStyle(ColorTokens.text3)
        .tracking(0.88)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 8)
}
```

**Status indicator pattern** (HealthKitPermissionsView lines 822-826):
```swift
Image(systemName: "checkmark.circle.fill")
    .foregroundStyle(ColorTokens.zoneOptimal)
Text("Authorized")
    .font(.Tokens.body)
    .foregroundStyle(ColorTokens.zoneOptimal)
```

**Notes:** SyncStatusView iterates `SyncEntity.allCases`, showing per-entity rows with success/failure indicators. Uses `ColorTokens.zoneOptimal` for success, `ColorTokens.zoneCaution` for failure. Shows relative time since last sync via `RelativeDateTimeFormatter`. Follows same ScrollView + VStack(spacing: 0) layout as HealthKitPermissionsView.

---

### `WorkloadApp/Services/SyncService.swift` (MODIFIED - do/catch hardening, Bool returns)

**Analog:** Self — existing `run()` helper and `pullWorkloadSnapshots` patterns

**Existing `run()` helper** (lines 83-89):
```swift
private func run(_ operation: String, _ action: () async throws -> Void) async {
    do {
        try await action()
    } catch {
        logFailure(operation, error)
    }
}
```

**Existing `logFailure`** (lines 79-81):
```swift
private func logFailure(_ operation: String, _ error: Error) {
    print("SyncService \(operation) error: \(error)")
}
```

**Existing pull pattern to convert** (lines 236-263):
```swift
private func pullWorkloadSnapshots(context: ModelContext, athlete: Athlete) async {
    guard let rows: [WorkloadSnapshotRow] = try? await client
        .from("workload_snapshots")
        .select()
        .eq("athlete_id", value: athlete.id)
        .execute()
        .value
    else { return }
    // ... upsert logic ...
    try? context.save()
}
```

**Existing `pushAll` orchestration** (lines 19-32):
```swift
func pushAll(context: ModelContext) async {
    guard let athlete = try? context.fetch(FetchDescriptor<Athlete>()).first else { return }
    await pushAthlete(athlete)
    await pushWorkloadSnapshots(context: context, athleteId: athlete.id)
    // ... more entities ...
    UserDefaults.standard.set(Date(), forKey: "lastSyncedAt")
}
```

**Existing `shouldForegroundSync`** (lines 74-77):
```swift
var shouldForegroundSync: Bool {
    guard let last = UserDefaults.standard.object(forKey: "lastSyncedAt") as? Date else { return true }
    return Date().timeIntervalSince(last) > 15 * 60
}
```

**Notes:**
1. `run()` changes signature to `-> Bool`, returning true on success, false on catch.
2. `logFailure` changes signature to `(_ entity: SyncEntity, _ direction: SyncDirection, _ error: Error)` with ISO8601 timestamp.
3. Each pull method changes from `async` to `async -> Bool`, replacing `guard let ... try?` with `do/catch`, and wrapping final `context.save()` in its own `do/catch`.
4. `pushAll`/`pullAll` replace sequential await calls with per-entity success check + `SyncTimestampStore.recordSuccess/recordFailure`.
5. Remove global `UserDefaults.standard.set(Date(), forKey: "lastSyncedAt")` at end of pushAll/pullAll.
6. `shouldForegroundSync` rewired to check per-entity timestamps via `SyncTimestampStore`.
7. Add `isSyncing` guard to prevent concurrent sync cycles.

---

### `WorkloadApp/Views/Profile/ProfileView.swift` (MODIFIED - add Sync Status nav row)

**Analog:** Self — existing NavigationLink to HealthKitPermissionsView (lines 202-216)

**NavigationLink row pattern** (lines 202-216):
```swift
NavigationLink {
    HealthKitPermissionsView()
} label: {
    HStack {
        Text("HealthKit Permissions")
            .font(.Tokens.body)
            .foregroundStyle(ColorTokens.text1)
        Spacer()
        Image(systemName: "chevron.right")
            .font(.system(size: 12))
            .foregroundStyle(ColorTokens.text3)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 16)
}
```

**Notes:** Add a "Sync Status" NavigationLink row in a similar section. Include a small colored indicator (dot) inline if `SyncTimestampStore.hasAnyFailure` is true.

---

### `WorkloadApp/App/AppRouter.swift` (MODIFIED - tab badge, updated shouldForegroundSync)

**Analog:** Self — existing MainTabView TabView structure (lines 166-189)

**TabView with tabItem pattern** (lines 175-188):
```swift
ProfileView()
    .tabItem { Label("Profile", systemImage: "person.fill") }
```

**Foreground sync trigger** (lines 196-214):
```swift
.onChange(of: scenePhase) { _, newPhase in
    guard newPhase == .active else { return }
    Task {
        await container.subscriptionService.refreshEntitlementAsync()
        guard container.syncService.shouldForegroundSync else { return }
        if effectiveMode == .coach, let id = athlete?.id {
            // ... coach sync ...
        } else {
            await container.syncService.pushAll(context: modelContext)
            await container.syncService.pullAll(context: modelContext)
        }
    }
}
```

**Notes:** Add `.badge("")` or `.overlay` on Profile tab when `SyncTimestampStore.shared.hasAnyFailure`. The `shouldForegroundSync` call stays but now delegates to per-entity timestamp checks inside SyncService.

---

### `WorkloadApp/App/AppContainer.swift` (MODIFIED - clear sync timestamps on sign-out)

**Analog:** Self — existing `signOut` method (lines 80-89)

**SignOut cleanup pattern** (lines 80-89):
```swift
func signOut(modelContext: ModelContext) async throws {
    try await authService.signOut()
    // Cascade delete: Athlete has deleteRule: .cascade on all relationships
    let athletes = try modelContext.fetch(FetchDescriptor<Athlete>())
    for athlete in athletes {
        modelContext.delete(athlete)
    }
    try modelContext.save()
    isAuthenticated = false
}
```

**Notes:** Add `SyncTimestampStore.shared.clearAll()` call after `try await authService.signOut()` and before deleting athletes. Same addition needed in `deleteAccount` method.

---

## Shared Patterns

### Font and Color Tokens
**Source:** `WorkloadApp/Utilities/ColorTokens.swift`, `Font.Tokens` extension
**Apply to:** `SyncStatusView.swift`
```swift
// Body text
.font(.Tokens.body)
.foregroundStyle(ColorTokens.text1)

// Secondary text
.font(.Tokens.label)
.foregroundStyle(ColorTokens.text2)

// Section headers
.font(.Tokens.micro)
.foregroundStyle(ColorTokens.text3)

// Status colors
ColorTokens.zoneOptimal   // green - success
ColorTokens.zoneCaution   // yellow - warning/failure
```

### 8pt Grid Spacing
**Source:** DESIGN.md, all existing views
**Apply to:** `SyncStatusView.swift`
```swift
.padding(.horizontal, 16)  // 2x base
.padding(.vertical, 12)    // 1.5x base (used in list rows)
.padding(.top, 24)          // 3x base (section headers)
.padding(.bottom, 8)        // 1x base
```

### Divider Pattern
**Source:** `ProfileView.swift` (lines 493-498)
**Apply to:** `SyncStatusView.swift`
```swift
Rectangle()
    .fill(ColorTokens.divider)
    .frame(height: 0.5)
    .padding(.leading, 16)
```

### @MainActor @Observable Service Pattern
**Source:** `SubscriptionService.swift` (lines 4-6)
**Apply to:** `SyncTimestampStore.swift`
```swift
@MainActor
@Observable
final class SyncTimestampStore {
    // private(set) var for observable properties
    // Methods mutate state directly (no Combine)
}
```

### CaseIterable Enum With displayName
**Source:** `Enums.swift` SportType (lines 5-39)
**Apply to:** `SyncEntity.swift`
```swift
enum SyncEntity: String, CaseIterable, Identifiable {
    case workouts
    // ...
    var id: String { rawValue }
    var displayName: String { ... }
}
```

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| (none) | -- | -- | All files have close analogs in the existing codebase |

## Metadata

**Analog search scope:** `WorkloadApp/Services/`, `WorkloadApp/Views/Profile/`, `WorkloadApp/App/`, `WorkloadApp/Models/`
**Files scanned:** 8 source files read in detail
**Pattern extraction date:** 2026-05-10
