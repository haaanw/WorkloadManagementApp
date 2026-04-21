# Coding Conventions

**Analysis Date:** 2026-04-20

## Naming Patterns

**Files:**
- PascalCase for all Swift files: `WorkloadApp.swift`, `DashboardViewModel.swift`, `RecoveryScoreEngine.swift`
- Feature-based organization: Views grouped by feature (Dashboard, Recovery, WorkoutLog, Coach, Profile)
- Repository pattern: `*Repository.swift` (AthleteRepository, WorkoutRepository, RecoveryRepository, WorkloadRepository)
- Engine/service pattern: `*Engine.swift` or `*Service.swift` for pure calculation/business logic

**Functions:**
- camelCase for all function names: `sessionTSS()`, `computeHistoryEWMA()`, `fetchCurrentAthlete()`
- Descriptive action verbs: `compute`, `detect`, `fetch`, `classify`, `recommend`, `summarize`
- Static methods on pure engines: `WorkloadCalculator.sessionTSS()`, `RecoveryScoreEngine.compute()`
- Instance methods on repositories/services: `athleteRepository.fetchCurrentAthlete()`

**Variables:**
- camelCase for local variables: `recoveryScore`, `workoutSession`, `modelContext`
- snake_case for JSON decoding keys (conforming to backend convention)
- Abbreviations allowed: `atl` (Acute Training Load), `ctl` (Chronic Training Load), `acwr` (ACWR), `hrv` (Heart Rate Variability), `rhr` (Resting Heart Rate), `tss` (Training Stress Score), `ei` (Efficiency Index)
- Boolean prefix with "is" or verb: `isLoading`, `hasSession`, `hasRealData`, `isScreenshotMode`, `hasSession()`

**Types:**
- PascalCase for all types (classes, structs, enums): `WorkloadCalculator`, `RecoveryScoreEngine`, `DashboardViewModel`, `ACWRZone`
- Nested types define relationships: `RecoveryScoreEngine.RecoveryInput`, `WorkloadCalculator.DailyLoad`, `WorkloadCalculator.WorkloadResult`
- Enum cases in lowercase: `.lifting`, `.running`, `.green`, `.yellow`, `.red`, `.optimal`, `.caution`

## Code Style

**Formatting:**
- 4-space indentation
- No trailing commas in multi-line function calls
- Long parameter lists break at parameter boundaries, each on own line with proper indentation
- Blank lines between logical sections (marked with `// MARK:`)
- No semicolons (Swift style)

**Linting:**
- No explicit linting tool configured in codebase
- Type-checked via Xcode's built-in Swift compiler
- Manual style verification expected through code review (no SwiftLint config present)

## Import Organization

**Order:**
1. Foundation and system frameworks (Foundation, SwiftUI, SwiftData, UIKit, etc.)
2. Third-party frameworks (Supabase, RevenueCat, HealthKit)
3. `@testable import workload_management` in test files

**Example from LoginView.swift:**
```swift
import SwiftUI
import SwiftData
```

**Example from AuthService.swift:**
```swift
import Foundation
import Supabase
```

**Path Aliases:**
- No explicit path aliases configured
- Full paths used throughout: `RecoveryScoreEngine`, `WorkoutRepository`, etc.

## Error Handling

**Patterns:**
- Swift's native `throws`/`try` for error propagation: `try await client.auth.signIn()`
- Custom error enums with `LocalizedError` conformance: `AuthService.AuthError`
- Error suppression with `try?` for non-critical operations: `try? recoveryRepo.fetchTodaySnapshot()`
- Print-based logging on error with `\()` interpolation (not a formal logging framework)
- Example from `DashboardViewModel.load()`:
```swift
do {
    let recoveryResult = try await RecoveryPipeline.run(...)
    recoveryScore = recoveryResult.score
} catch {
    print("Recovery pipeline error: \(error)")
}
```

**Custom Error Types:**
- Located in the type that throws them: `AuthService.AuthError` defined within `AuthService`
- Must conform to `LocalizedError` with `errorDescription` property
- Error cases document why the error occurs: `case noUserReturned`

## Logging

**Framework:** `print()` with string interpolation (no formal logging framework)

**Patterns:**
- Error logging only (no info/debug logging in current codebase)
- Use descriptive context prefix: `"Recovery pipeline error: \(error)"`, `"Workout pipeline error: \(error)"`
- Log in catch blocks when errors cannot be recovered
- Log in assertion failures for DEBUG builds (e.g., font validation)

**When to Log:**
- Catch blocks in async operations (pipelines, ViewModel loads)
- Failed save operations (ActiveWorkoutSheet)
- Non-critical errors that don't crash the app

## Comments

**When to Comment:**
- Class/struct level: Document purpose and key responsibilities (e.g., RecoveryScoreEngine docstring)
- Section headers: Use `// MARK: - Section Name` to organize code blocks
- Algorithm explanation: HRV vs baseline ratio logic, EWMA decay constants
- Data structure fields: Brief notes on input requirements for nested types

**JSDoc/TSDoc:**
- Triple-slash documentation (`///`) for public types and functions
- Minimal but complete: Include purpose, parameters if complex, and return value
- Example from `RecoveryScoreEngine`:
```swift
/// Compute composite recovery score from available inputs.
/// Gracefully handles missing data by redistributing weights.
static func compute(input: RecoveryInput) -> RecoveryResult
```

**Section Comments:**
```swift
// MARK: - EWMA Constants
// MARK: - Session-Level Calculations
// MARK: - Error Handling
```

## Function Design

**Size:**
- Typical range: 3–30 lines
- Engines (pure structs): 1–15 lines, single responsibility
- ViewModel methods: 20–60 lines (load orchestration allowed)
- Repository methods: 3–10 lines (lean, focused queries)

**Parameters:**
- Input structs for multiple related parameters: `RecoveryScoreEngine.RecoveryInput` groups HRV, HR, sleep, baseline
- Named parameters preferred: `detectSessionSpike(sessionTSS:recentSessionTSSValues:threshold:)`
- Default values for optional thresholds: `threshold: Double = 1.5`
- No positional arguments for boolean flags (always named)

**Return Values:**
- Optionals for potentially missing data: `Optional<SpikeAlert>`, `Optional<Baseline>`
- Structs for composite results: `RecoveryResult`, `WorkloadResult`
- nil for "not found" or "no spike"; never return empty collections as "missing"

**Pure Functions Preference:**
- Static methods on engine structs: `WorkloadCalculator.sessionTSS()`, `RecoveryScoreEngine.compute()`
- No instance state, no side effects (except UI updates in ViewModels)
- Deterministic: same input → same output always

## Module Design

**Exports:**
- Classes and structs are implicitly public if defined at module level
- Private properties for internal state: `private let modelContext`
- @MainActor marks thread-safe types (repositories, ViewModels, observable services)
- final keyword on classes to prevent subclassing (all repository and ViewModel classes are final)

**Barrel Files:**
- No barrel/index.swift files in current codebase
- Each feature has own directory with independent files

**Visibility:**
- Repositories: @MainActor final class with private modelContext
- ViewModels: @MainActor @Observable final class
- Engines: struct with static methods only (pure, no instance needed)
- Services: Either pure struct with static methods or @MainActor final class with @Observable if stateful

## Type Organization

**Classes:**
- Used for repositories and stateful services
- Always marked @MainActor (all database/UI operations)
- Always marked final
- Init takes dependencies: `init(modelContext: ModelContext)`
- Example: `AthleteRepository`, `SubscriptionService`, `AuthService`

**Structs:**
- Used for pure engines and pipelines (zero state)
- No @MainActor needed (pure computation)
- All methods static: `struct WorkloadCalculator { static func ... }`
- Example: `WorkloadCalculator`, `RecoveryScoreEngine`, `AutoregulationEngine`, `PRDetector`

**Enums:**
- Used for domain values: `SportType`, `ACWRZone`, `RecoveryZone`, `LoadSource`, `ACWRMethod`
- Conform to `String, Codable, CaseIterable, Identifiable` for UI bindings
- Include `displayName` computed property for UI labels
- Include `systemImage` property for SF Symbols where applicable
- Raw values used only when serializing to backend (Supabase, RevenueCat)

## Architecture Layer Pattern

**Dependency Flow:**
```
Views (@Query, @State, @Bindable)
  → ViewModels (@Observable, @MainActor)
    → Pipelines (static methods, orchestrate engines + repos)
      → Engines (pure structs, zero state)
      → Repositories (@MainActor, SwiftData)
        → Models (@Model SwiftData)
```

**No cross-layer shortcuts:**
- Views never call repositories directly; use ViewModel
- Repositories never call engines; engines are stateless helpers
- Engines never depend on repositories (pure calculation)

## SwiftUI Conventions

**View Modifiers Order:**
1. Content frame/layout (frame, padding, alignment)
2. Appearance (font, foregroundStyle, background)
3. Interaction (onTapGesture, onChange)
4. Lifecycle (.onAppear, .onDisappear)

**Environment Injection:**
- Use `@Environment(AppContainer.self)` for dependency access
- Injected via `.environment(container)` from root
- Example: `@Environment(AppContainer.self) private var container`

**State Management:**
- ViewModels are source of truth (@Observable)
- @State used only for temporary UI state (sheet visibility, text input focus)
- @Query used for direct SwiftData reads when ViewModel not needed
- Example from LoginView: `@State private var email = ""`

**Color System:**
- All colors via `ColorTokens` enum (never hardcoded hex)
- Semantic properties: `ColorTokens.text1`, `ColorTokens.zoneDanger`, `ColorTokens.accent`
- Supports dark/light mode automatically

**Font System:**
- Custom fonts only: `Font.custom("DMSans-Regular", size: 15)` via `Font.Tokens` extension
- No system fonts (`.system()`, `.headline`, etc.)
- Font set: DMSans-Regular + DMSans-Medium only

---

*Convention analysis: 2026-04-20*
