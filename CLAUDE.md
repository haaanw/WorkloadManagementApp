# WorkloadApp

Athlete workload management iOS app built with SwiftUI + SwiftData. Tracks training load (ACWR), recovery scoring, autoregulation recommendations, and personal records.

## Architecture

**Layer stack:**
1. **Views** (SwiftUI) → **ViewModels** (`@Observable`) → **Pipeline Services** → **Engines** (pure structs) → **Repositories** (SwiftData) → **Models** (`@Model`)

**Key directories:**
- `App/` — Entry point (`WorkloadApp.swift`), dependency container (`AppContainer.swift`), routing (`AppRouter.swift`)
- `Models/` — SwiftData `@Model` classes: Athlete, WorkoutSession, ExerciseEntry, SetRecord, WorkloadSnapshot, RecoverySnapshot, WellnessCheckIn, PersonalRecord
- `Models/Enums.swift` — All domain enums (SportType, ACWRZone, RecoveryZone, ExerciseCategory, etc.)
- `Services/` — Business logic engines (WorkloadCalculator, RecoveryScoreEngine, AutoregulationEngine, PRDetector) and orchestration pipelines (WorkoutPipeline, RecoveryPipeline)
- `Repositories/` — SwiftData persistence (AthleteRepository, WorkoutRepository, WorkloadRepository, RecoveryRepository)
- `ViewModels/` — `@Observable` classes: DashboardViewModel, WorkoutLogViewModel, RecoveryViewModel
- `Views/` — SwiftUI views organized by tab (Dashboard, WorkoutLog, Recovery, Workload, Profile, Onboarding, Auth)
- `Components/` — Reusable UI (MetricTile, ZoneBadge, HRVTrendChart, SleepTrendChart)
- `Utilities/` — ColorTokens, DateHelpers, WeightFormatter

## Data flow

- **Post-workout:** ActiveWorkoutSheet saves session → `WorkoutPipeline.processSession()` → detects PRs, computes EWMA workload, upserts WorkloadSnapshot, stamps session ATL/CTL
- **Recovery:** App launch / wellness check-in → `RecoveryPipeline.run()` → fetches HealthKit (HRV, RHR, sleep), computes baselines, runs RecoveryScoreEngine, upserts RecoverySnapshot
- **Dashboard:** `DashboardViewModel.load()` → runs RecoveryPipeline + AutoregulationEngine → exposes recovery score, ACWR, recommendation

## Conventions

- All engines (WorkloadCalculator, RecoveryScoreEngine, AutoregulationEngine, PRDetector) are **pure structs with static methods** — no state, no dependencies
- Repositories are `@MainActor final class` taking `ModelContext` in init
- ViewModels are `@MainActor @Observable final class`
- Pipeline services are `@MainActor struct` with static methods
- Views use `@Query` for reactive SwiftData reads and ViewModels for orchestration
- `AppContainer` is injected via `@Environment(AppContainer.self)`
- Current athlete is fetched via `@Query private var athletes: [Athlete]` then `.first`
- Color system uses `ColorTokens` enum with static properties
- Date formatting uses extensions in `DateHelpers.swift`

## Current status

- **Phase 1 (local wiring): Complete** — app works end-to-end locally
- **Phase 2 (Supabase backend): Complete** — auth, sync, PostgreSQL schema
- **Phase 3 (coach+athlete multi-user): RETIRED** — coach mode DROPPED as of v1.6 (user decision 2026-07-18): the app is **athlete-only**. Coach UI is unreachable (Views/Coach/ compiles but is unmounted; will be deleted with the retired UIKit shell after v1.6 validates). Coach @Model classes (CoachAthleteRelationship, PrescribedWorkout) are retained for data/schema compatibility only. Do NOT build or port coach surfaces.
- **Phase 4 (subscriptions): Complete** — RevenueCat two-tier (Athlete Pro + Coach), all features gated
- **Phase 5 (App Store readiness): In progress** — legal pages done, screenshots in progress
- **v1.6 "Ink & Grain" (UI polish + rehost): Machine-complete 2026-07-18** — SwiftUI tree is the live app, DESIGN.md v3 applied app-wide, custom InkTabBar, full suite green (782 tests). Awaiting on-device dogfood → version bump → shell deletion.
- **Movement Bank: Complete 2026-07-18** — 1,324-exercise preset catalog (`Resources/ExerciseCatalog.json`, MIT data from hasaneyldrm/exercises-dataset; Gym visual GIFs NOT licensed — data-only, never bundle the media). `ExerciseCatalogStore` (decode + search index), `ExerciseOverride` @Model (local-only hide/remap, purged on sign-out/account-deletion), search-first `ExercisePickerView`, `MovementBankView` in Profile (add/modify/hide entries). Exercise identity = name string; legacy curated names win dedupe so history/PRs stay continuous. Regenerate catalog: `scripts/generate_exercise_catalog.py`.

## Auth

Supabase Auth (email/password). `AppRouter` checks Keychain for existing session, bootstraps local Athlete from Supabase if missing. `LoginView` / `SignUpView` handle auth. `SCREENSHOT_MODE` launch argument bypasses auth in DEBUG builds.

## Subscriptions

Two-tier model via RevenueCat:
- `isPro` (athlete_pro OR coach entitlement) — gates history, overload suggestions, custom exercises, PRs
- `isCoach` (coach entitlement only) — legacy entitlement; coach mode was DROPPED in v1.6 (athlete-only app). No UI is gated on it anymore except the coach-trigger paywall variant in export flows. Existing coach subscribers keep `isPro` via the OR above.
- `SubscriptionService` in `AppContainer`, `UpgradeSheet` for paywall
- `RevenueCatConfig.swift` is gitignored — never commit API keys

## Dependencies

- SwiftUI, SwiftData, HealthKit, Charts (Apple frameworks)
- Supabase Swift SDK (auth + sync)
- RevenueCat (subscriptions)

## HealthKit

- Read-only access (HRV, RHR, sleep, workout HR, body temp, VO2 Max)
- Requires HealthKit capability + `NSHealthShareUsageDescription` in Info.plist
- Raw HealthKit data must never be uploaded to Supabase — only composite scores

## Design System

Always read `DESIGN.md` before making any visual or UI decisions.
All font choices, colors, spacing, and aesthetic direction are defined there.
Do not deviate from the design system without explicit user approval.

Key constraints to enforce (DESIGN.md v3 "Ink & Grain", 2026-07-14):
- **Corners come from `CornerTokens` only** — card 12pt / control 8pt / pill (`Capsule()`); the old 0pt-everywhere rule is retired; never a hand-typed radius literal
- **No shadows** — remove any `.shadow()` modifiers; elevation is plane + hairline borders
- **Two-voice type law** — General Sans (Regular + Medium) everywhere via `Font.Tokens.*`; Source Serif 4 ONLY via `Font.Tokens.displayScore` / `.displayVerdict` (hero readiness score + verdict headline, app-authored strings only, never user content); never `.system()` or semantic styles
- **Accent Rule v3 (`ColorTokens.accent`)** — hero readiness score, verdict CTA fill (pill), the halftone signature, and v2 live-state semantics (progress fills, active/selected, emphasis top rule); never decorative
- **Halftone texture only via `HalftoneField`** — hero plane only, at most one per screen
- **All spacing must be multiples of 8pt** — no magic numbers (4pt only as the sanctioned `baselinePair` micro-gap)
- **Zone states communicated through text labels + optional colored border** — never color alone
- **Light-only appearance** via `ColorTokens` semantic tokens; never hardcode hex values in views; no dark-mode branches
- In QA mode, flag any code that deviates from DESIGN.md

<!-- GSD:project-start source:PROJECT.md -->
## Project

**Tuwa** — official product name. (Faros, Tonus, Tutrice are all dead/abandoned names; never use them in user-facing copy. Bundle ID remains `com.tonus.app`. Repo dir is still `Tonus/` for historical reasons.)

**The sports-science staff layer for self-coached athletes.** The athlete (or their coach) authors the training program; Tuwa ingests it whole — blocks, weeks, periodization position — fuses it with physiology (HRV, sleep, RHR, training history), and supports decisions at three horizons: today (concrete number adjustments + go/modify/hold verdicts), mid-term (fatigue trajectory, overreach forecast), long-term (response profiling). Built on recovery scoring + unified hybrid load tracking (one fatigue budget across sport skill, strength, conditioning). It never writes the program. It never makes you chat with it (LLM = engine for plan parsing and reasoned structured outputs, not a chat UI).

**Core Value (redefined 2026-06-12):** Readiness-driven modulation of a *user-authored* hybrid plan with periodization-position awareness — the validated open market gap: every competitor that modulates owns the program; every competitor that accepts your plan refuses to modulate it. Anti-positioning: Whoop/Bevel = scores without your plan; AI-coach apps = their plan, not yours; TrainingPeaks = your plan, no decisions; **Tuwa = your plan, made safe and optimal.** Full statement: `.planning/notes/core-redefinition-plan-aware-engine.md`.

**Core target users (narrowed 2026-05-30, sharpened 2026-06-12, beachhead 2026-07-07):** Amateur *serious* **self-coached sport-skill-primary athletes** — train sport skill + strength + conditioning in parallel, hard, by themselves, with **no access to professional coaching, physiotherapy, or sports-science support** today; may bring a professional coach's plan later (app stays the decision/data layer either way). The founder is the reference user. **Launch beachhead (v2.1, `docs/adr/0001`): amateur competitive basketball players who also strength-train.** Avoid the market term "hybrid athlete" in positioning — it means endurance+strength (Hyrox/run+lift), a different body and community. Canonical vocabulary (match tier, microdose, match proximity, strike zone) lives in `CONTEXT.md`. The product replaces the pro team's back room — turning plan + body signals into daily decisions — and must be measurably better than generic competitor apps for THIS group. All algorithm, UX, and copy decisions optimize for this group.

### Constraints

- **Platform**: iOS 17+ only, SwiftUI + SwiftData
- **HealthKit**: Read-only access, raw data must never leave device (only composite scores sync)
- **Subscriptions**: RevenueCat handles StoreKit; API keys gitignored
- **Backend**: Supabase PostgreSQL with RLS; no local fallback for sync
- **Design**: Must follow DESIGN.md v3 "Ink & Grain" — CornerTokens (card 12 / control 8 / pill), no shadows, two-voice type (General Sans + Source Serif 4 display-only), 8pt grid, halftone on hero plane only
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Swift (iOS app codebase) - All application logic, UI, and business engines
## Runtime
- iOS 17+ (target deployment minimum implied by API usage: `HKQuantityType.appleSleepingWristTemperature`, iOS 17+ feature)
- Xcode (build environment)
- iPhone (tested on iPhone 17 Pro Max simulator)
- Apple Watch (HealthKit data via companion apps)
## Frameworks
- SwiftUI - Declarative UI framework
- SwiftData - Local ORM/persistence (replaces CoreData)
- Charts - Apple framework for data visualization (used in `WorkloadView.swift`)
- HealthKit - Read-only health and fitness data (HRV, RHR, sleep, workout data, VO2 Max, body temperature)
- UIKit - Required for font management (`UIFont` assertions in `WorkloadApp.swift`)
- CoreNFC - NFC session coordination (see `NFCSessionCoordinator.swift`)
- XCTest - Apple's native testing framework
- XCUITest - UI automation (used in `ScreenshotTests`)
- Xcode (implied, standard iOS development)
- xcparse - CLI tool for extracting screenshots from xcresult bundles (optional, used in screenshot automation)
## Key Dependencies
- Supabase Swift SDK - Backend auth + PostgreSQL sync
- RevenueCat SDK - Subscription management
- SwiftData models bridge (JSON encoding/decoding for Supabase sync)
## Configuration
- `SupabaseConfig.swift` (committed, contains publishable key)
- `RevenueCatConfig.swift` (gitignored — DO NOT commit API keys)
- `Info.plist` (in `workload management/workload-management-Info.plist`)
- `PrivacyInfo.xcprivacy` - App Store Privacy Manifest
- `SCREENSHOT_MODE` - DEBUG build flag that bypasses authentication and seeds mock data for automated screenshots (see `AppRouter.swift`)
## Fonts
- `GeneralSans-Variable.ttf` (110.8 KB) - Variable font covering Regular (400) through Bold (700)
## Platform Requirements
- Xcode (latest, tested with iPhone 17 Pro Max simulator)
- iOS 17+ SDK
- Apple device or simulator with HealthKit support
- Deployment target: iOS 17+
- App Store distribution (Phase 5 in progress)
- Requires user to grant HealthKit permissions (prompted via `NSHealthShareUsageDescription`)
- Requires in-app purchase capability (RevenueCat SDK handles StoreKit integration)
- Supabase PostgreSQL backend (always available, no local fallback)
- RevenueCat cloud configuration (subscription offerings must be configured in dashboard)
- Apple Health app or compatible wearable (Apple Watch, Oura, Whoop, Garmin) for HealthKit data
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- PascalCase for all Swift files: `WorkloadApp.swift`, `DashboardViewModel.swift`, `RecoveryScoreEngine.swift`
- Feature-based organization: Views grouped by feature (Dashboard, Recovery, WorkoutLog, Coach, Profile)
- Repository pattern: `*Repository.swift` (AthleteRepository, WorkoutRepository, RecoveryRepository, WorkloadRepository)
- Engine/service pattern: `*Engine.swift` or `*Service.swift` for pure calculation/business logic
- camelCase for all function names: `sessionTSS()`, `computeHistoryEWMA()`, `fetchCurrentAthlete()`
- Descriptive action verbs: `compute`, `detect`, `fetch`, `classify`, `recommend`, `summarize`
- Static methods on pure engines: `WorkloadCalculator.sessionTSS()`, `RecoveryScoreEngine.compute()`
- Instance methods on repositories/services: `athleteRepository.fetchCurrentAthlete()`
- camelCase for local variables: `recoveryScore`, `workoutSession`, `modelContext`
- snake_case for JSON decoding keys (conforming to backend convention)
- Abbreviations allowed: `atl` (Acute Training Load), `ctl` (Chronic Training Load), `acwr` (ACWR), `hrv` (Heart Rate Variability), `rhr` (Resting Heart Rate), `tss` (Training Stress Score), `ei` (Efficiency Index)
- Boolean prefix with "is" or verb: `isLoading`, `hasSession`, `hasRealData`, `isScreenshotMode`, `hasSession()`
- PascalCase for all types (classes, structs, enums): `WorkloadCalculator`, `RecoveryScoreEngine`, `DashboardViewModel`, `ACWRZone`
- Nested types define relationships: `RecoveryScoreEngine.RecoveryInput`, `WorkloadCalculator.DailyLoad`, `WorkloadCalculator.WorkloadResult`
- Enum cases in lowercase: `.lifting`, `.running`, `.green`, `.yellow`, `.red`, `.optimal`, `.caution`
## Code Style
- 4-space indentation
- No trailing commas in multi-line function calls
- Long parameter lists break at parameter boundaries, each on own line with proper indentation
- Blank lines between logical sections (marked with `// MARK:`)
- No semicolons (Swift style)
- No explicit linting tool configured in codebase
- Type-checked via Xcode's built-in Swift compiler
- Manual style verification expected through code review (no SwiftLint config present)
## Import Organization
- No explicit path aliases configured
- Full paths used throughout: `RecoveryScoreEngine`, `WorkoutRepository`, etc.
## Error Handling
- Swift's native `throws`/`try` for error propagation: `try await client.auth.signIn()`
- Custom error enums with `LocalizedError` conformance: `AuthService.AuthError`
- Error suppression with `try?` for non-critical operations: `try? recoveryRepo.fetchTodaySnapshot()`
- Print-based logging on error with `\()` interpolation (not a formal logging framework)
- Example from `DashboardViewModel.load()`:
- Located in the type that throws them: `AuthService.AuthError` defined within `AuthService`
- Must conform to `LocalizedError` with `errorDescription` property
- Error cases document why the error occurs: `case noUserReturned`
## Logging
- Error logging only (no info/debug logging in current codebase)
- Use descriptive context prefix: `"Recovery pipeline error: \(error)"`, `"Workout pipeline error: \(error)"`
- Log in catch blocks when errors cannot be recovered
- Log in assertion failures for DEBUG builds (e.g., font validation)
- Catch blocks in async operations (pipelines, ViewModel loads)
- Failed save operations (ActiveWorkoutSheet)
- Non-critical errors that don't crash the app
## Comments
- Class/struct level: Document purpose and key responsibilities (e.g., RecoveryScoreEngine docstring)
- Section headers: Use `// MARK: - Section Name` to organize code blocks
- Algorithm explanation: HRV vs baseline ratio logic, EWMA decay constants
- Data structure fields: Brief notes on input requirements for nested types
- Triple-slash documentation (`///`) for public types and functions
- Minimal but complete: Include purpose, parameters if complex, and return value
- Example from `RecoveryScoreEngine`:
## Function Design
- Typical range: 3–30 lines
- Engines (pure structs): 1–15 lines, single responsibility
- ViewModel methods: 20–60 lines (load orchestration allowed)
- Repository methods: 3–10 lines (lean, focused queries)
- Input structs for multiple related parameters: `RecoveryScoreEngine.RecoveryInput` groups HRV, HR, sleep, baseline
- Named parameters preferred: `detectSessionSpike(sessionTSS:recentSessionTSSValues:threshold:)`
- Default values for optional thresholds: `threshold: Double = 1.5`
- No positional arguments for boolean flags (always named)
- Optionals for potentially missing data: `Optional<SpikeAlert>`, `Optional<Baseline>`
- Structs for composite results: `RecoveryResult`, `WorkloadResult`
- nil for "not found" or "no spike"; never return empty collections as "missing"
- Static methods on engine structs: `WorkloadCalculator.sessionTSS()`, `RecoveryScoreEngine.compute()`
- No instance state, no side effects (except UI updates in ViewModels)
- Deterministic: same input → same output always
## Module Design
- Classes and structs are implicitly public if defined at module level
- Private properties for internal state: `private let modelContext`
- @MainActor marks thread-safe types (repositories, ViewModels, observable services)
- final keyword on classes to prevent subclassing (all repository and ViewModel classes are final)
- No barrel/index.swift files in current codebase
- Each feature has own directory with independent files
- Repositories: @MainActor final class with private modelContext
- ViewModels: @MainActor @Observable final class
- Engines: struct with static methods only (pure, no instance needed)
- Services: Either pure struct with static methods or @MainActor final class with @Observable if stateful
## Type Organization
- Used for repositories and stateful services
- Always marked @MainActor (all database/UI operations)
- Always marked final
- Init takes dependencies: `init(modelContext: ModelContext)`
- Example: `AthleteRepository`, `SubscriptionService`, `AuthService`
- Used for pure engines and pipelines (zero state)
- No @MainActor needed (pure computation)
- All methods static: `struct WorkloadCalculator { static func ... }`
- Example: `WorkloadCalculator`, `RecoveryScoreEngine`, `AutoregulationEngine`, `PRDetector`
- Used for domain values: `SportType`, `ACWRZone`, `RecoveryZone`, `LoadSource`, `ACWRMethod`
- Conform to `String, Codable, CaseIterable, Identifiable` for UI bindings
- Include `displayName` computed property for UI labels
- Include `systemImage` property for SF Symbols where applicable
- Raw values used only when serializing to backend (Supabase, RevenueCat)
## Architecture Layer Pattern
- Views never call repositories directly; use ViewModel
- Repositories never call engines; engines are stateless helpers
- Engines never depend on repositories (pure calculation)
## SwiftUI Conventions
- Use `@Environment(AppContainer.self)` for dependency access
- Injected via `.environment(container)` from root
- Example: `@Environment(AppContainer.self) private var container`
- ViewModels are source of truth (@Observable)
- @State used only for temporary UI state (sheet visibility, text input focus)
- @Query used for direct SwiftData reads when ViewModel not needed
- Example from LoginView: `@State private var email = ""`
- All colors via `ColorTokens` enum (never hardcoded hex)
- Semantic properties: `ColorTokens.text1`, `ColorTokens.zoneDanger`, `ColorTokens.accent`
- Light-only appearance (ColorTokens forces light; no dark-mode branches)
- Custom fonts only: `Font.Tokens.*` (General Sans Variable instrument voice + Source Serif 4 display voice)
- No system fonts (`.system()`, `.headline`, etc.)
- Font set: General Sans Regular + Medium everywhere; Source Serif 4 (400) only for `displayScore` / `displayVerdict` (DESIGN.md v3 Two-Voice Type Law)
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- **Data persistence** via SwiftData with `@Model` classes and cascade delete relationships
- **View reactivity** via SwiftUI `@Observable` ViewModels and `@Query` for declarative data binding
- **Business logic separation** into pure struct engines (WorkloadCalculator, RecoveryScoreEngine) and stateful pipelines (WorkoutPipeline, RecoveryPipeline)
- **Dependency injection** through `AppContainer` (main dependency hub) passed via `@Environment`
- **Async/await** throughout for HealthKit, Supabase, and background sync operations
- **Main-thread safety** enforced with `@MainActor` on services, ViewModels, and repositories
## Layers
- Purpose: Render UI and handle user interaction
- Location: `WorkloadApp/Views/` organized by tab (Dashboard, WorkoutLog, Recovery, Workload, Profile, Coach, Auth, etc.)
- Contains: SwiftUI `struct View` files using `@Observable` ViewModels, `@Query` for SwiftData reads, `@Environment` for container
- Depends on: ViewModels (for state and logic), Models (for data binding), AppContainer (for services)
- Used by: Entry point `AppRouter`
- Purpose: Manage screen-level state and orchestrate business logic
- Location: `WorkloadApp/ViewModels/` — DashboardViewModel, WorkoutLogViewModel, RecoveryViewModel, CoachRosterViewModel
- Contains: `@MainActor @Observable final class` definitions with load/update methods
- Depends on: Pipelines, Repositories, Services, Models
- Used by: Views via `@State` or `@Environment`
- Purpose: Coordinate multi-step workflows (post-workout or recovery data flows)
- Location: `WorkloadApp/Services/` — `WorkoutPipeline.swift`, `RecoveryPipeline.swift`
- Contains: `@MainActor struct` with static methods that compose repositories, engines, and sync
- Depends on: Engines (calculation), Repositories (data access), SyncService (backend sync)
- Used by: ViewModels, AppRouter
- Purpose: Pure algorithmic computation with no state or side effects
- Location: `WorkloadApp/Services/` — WorkloadCalculator, RecoveryScoreEngine, AutoregulationEngine, PRDetector, ProgressionEngine, ReasoningEngine
- Contains: `struct` with static methods, plain Swift code (no SwiftUI, no async)
- Depends on: Models (domain types), Enums (domain constants)
- Used by: Pipelines
- Purpose: Encapsulate SwiftData fetch and save operations
- Location: `WorkloadApp/Repositories/` — AthleteRepository, WorkoutRepository, WorkloadRepository, RecoveryRepository
- Contains: `@MainActor final class` taking `ModelContext` in init
- Depends on: Models (for fetch predicates and inserts)
- Used by: Pipelines, ViewModels
- Purpose: Define persistent entities and their relationships
- Location: `WorkloadApp/Models/` — Athlete, WorkoutSession, ExerciseEntry, SetRecord, WorkloadSnapshot, RecoverySnapshot, WellnessCheckIn, PersonalRecord, CoachAthleteRelationship, WorkoutTemplate, PrescribedWorkout, CustomExercise, ExerciseGroup, TemplateExercise, TemplateSet
- Contains: `@Model final class` with `@Relationship(deleteRule: .cascade)` for parent-child links
- Depends on: Enums (for typed fields), nothing else
- Used by: All layers
- Purpose: Manage external integrations (Supabase, HealthKit, subscriptions, NFC)
- Location: `WorkloadApp/Services/` — AuthService, HealthKitService, SyncService, SubscriptionService, NFCSessionCoordinator, InviteService
- Contains: `@MainActor final class` or `@MainActor struct` wrapping SDK clients
- Depends on: Models (for data shapes), Supabase/HealthKit SDKs
- Used by: AppContainer, Pipelines, ViewModels
- Purpose: Centralize instantiation and lifecycle of all service instances
- Location: `WorkloadApp/App/AppContainer.swift`
- Contains: SubscriptionService, SupabaseClient, AuthService, HealthKitService, SyncService, plus isAuthenticated state
- Used by: AppRouter via `@State`, injected to all views via `@Environment(AppContainer.self)`
## Data Flow
## State Management
- **Authentication state:** AppContainer.isAuthenticated (boolean)
- **App mode:** AppContainer.currentMode stored in UserDefaults, synchronized across app
- **Athlete context:** Current athlete fetched via `@Query` in most views, `.first` assumed
- **ViewModel state:** Each screen has dedicated ViewModel (DashboardViewModel, WorkoutLogViewModel, etc.) holding transient UI state (loading flags, detail views, etc.)
- **Recovery/Workload snapshots:** Persisted daily via pipeline, queried via `@Query` for charts and history views
- **Sync state:** SyncService tracks `shouldForegroundSync` (time-based), orchestrates push/pull on foreground or mode change
## Key Abstractions
- Purpose: Multi-step orchestration with explicit separation of concerns
- Examples: `WorkoutPipeline.processSession()`, `RecoveryPipeline.run()`
- Pattern: Takes athlete + context, runs engines, saves snapshots, triggers async sync
- Purpose: Pure, testable computation without state or side effects
- Examples: WorkloadCalculator (EWMA, TRIMP, spike detection), RecoveryScoreEngine (HRV baseline + score), AutoregulationEngine (recommendations), PRDetector (max detection), ProgressionEngine (rep/weight PRs)
- Pattern: `struct` with static methods, no dependencies except Models/Enums, deterministic output
- Purpose: Data access abstraction
- Examples: WorkoutRepository, RecoveryRepository, AthleteRepository
- Pattern: `@MainActor final class` wrapping ModelContext, methods for fetch (with predicates) and save
- Purpose: Bridge between SwiftUI reactivity and business logic
- Examples: DashboardViewModel, WorkoutLogViewModel
- Pattern: `@MainActor @Observable final class` with async `load()` methods, state properties, dependency injection via init
## Entry Points
- Location: `WorkloadApp/App/WorkloadApp.swift`
- Triggers: SwiftUI app lifecycle
- Responsibilities: Initialize SwiftData ModelContainer with schema, set up WindowGroup
- Location: `WorkloadApp/App/AppRouter.swift`
- Triggers: App launch
- Responsibilities: Check Keychain session, bootstrap Athlete if needed, show ProgressView (loading) → LoginView (no auth) → MainTabView (authenticated)
- Location: `WorkloadApp/App/AppRouter.swift` (MainTabView struct)
- Triggers: Authenticated app state
- Responsibilities: Render the five athlete tabs (Home, Log, Recovery, Load, Profile) via the custom InkTabBar (stock tab bar stripped transparent but kept for safe-area insets); foreground sync on scenePhase.active. Athlete-only — there is NO coach mode or mode switching (dropped v1.6).
- Location: `WorkloadApp/Views/Dashboard/DashboardView.swift`
- Responsibilities: Render hero readiness card (recovery score), metrics strip, training load section, recent sessions
- Location: `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift` + ActiveWorkoutSheet
- Responsibilities: Display session history, allow new session creation, trigger WorkoutPipeline on save
## Error Handling
- **HealthKit authorization missing:** Render EmptyStateCard on Dashboard suggesting permission grant; fetch returns nil, recovery score degrades
- **Supabase sync failures:** Log error, continue local app operation; isSynced flag tracks state for retry
- **Pipeline computation failures:** `try/catch` in ViewModel load methods, errors logged, fallback values used (recovery score defaults to 50, ACWR defaults to .noData)
- **Session spike detection:** Returns nil if insufficient prior data (< 3 sessions), UI renders conditional UI
- **Zombie accounts:** If auth session exists but no Athlete row in Supabase, auto sign-out (resilience in AppRouter)
## Cross-Cutting Concerns
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
