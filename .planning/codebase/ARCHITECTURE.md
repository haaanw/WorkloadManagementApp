# Architecture

**Analysis Date:** 2026-04-20

## Pattern Overview

**Overall:** Layered Model-View-ViewModel (MVVM) with explicit service orchestration pipelines

**Key Characteristics:**
- **Data persistence** via SwiftData with `@Model` classes and cascade delete relationships
- **View reactivity** via SwiftUI `@Observable` ViewModels and `@Query` for declarative data binding
- **Business logic separation** into pure struct engines (WorkloadCalculator, RecoveryScoreEngine) and stateful pipelines (WorkoutPipeline, RecoveryPipeline)
- **Dependency injection** through `AppContainer` (main dependency hub) passed via `@Environment`
- **Async/await** throughout for HealthKit, Supabase, and background sync operations
- **Main-thread safety** enforced with `@MainActor` on services, ViewModels, and repositories

## Layers

**Presentation (SwiftUI Views):**
- Purpose: Render UI and handle user interaction
- Location: `WorkloadApp/Views/` organized by tab (Dashboard, WorkoutLog, Recovery, Workload, Profile, Coach, Auth, etc.)
- Contains: SwiftUI `struct View` files using `@Observable` ViewModels, `@Query` for SwiftData reads, `@Environment` for container
- Depends on: ViewModels (for state and logic), Models (for data binding), AppContainer (for services)
- Used by: Entry point `AppRouter`

**State Management (ViewModels):**
- Purpose: Manage screen-level state and orchestrate business logic
- Location: `WorkloadApp/ViewModels/` — DashboardViewModel, WorkoutLogViewModel, RecoveryViewModel, CoachRosterViewModel
- Contains: `@MainActor @Observable final class` definitions with load/update methods
- Depends on: Pipelines, Repositories, Services, Models
- Used by: Views via `@State` or `@Environment`

**Service Orchestration (Pipelines):**
- Purpose: Coordinate multi-step workflows (post-workout or recovery data flows)
- Location: `WorkloadApp/Services/` — `WorkoutPipeline.swift`, `RecoveryPipeline.swift`
- Contains: `@MainActor struct` with static methods that compose repositories, engines, and sync
- Depends on: Engines (calculation), Repositories (data access), SyncService (backend sync)
- Used by: ViewModels, AppRouter

**Business Logic (Engines):**
- Purpose: Pure algorithmic computation with no state or side effects
- Location: `WorkloadApp/Services/` — WorkloadCalculator, RecoveryScoreEngine, AutoregulationEngine, PRDetector, ProgressionEngine, ReasoningEngine
- Contains: `struct` with static methods, plain Swift code (no SwiftUI, no async)
- Depends on: Models (domain types), Enums (domain constants)
- Used by: Pipelines

**Data Access (Repositories):**
- Purpose: Encapsulate SwiftData fetch and save operations
- Location: `WorkloadApp/Repositories/` — AthleteRepository, WorkoutRepository, WorkloadRepository, RecoveryRepository
- Contains: `@MainActor final class` taking `ModelContext` in init
- Depends on: Models (for fetch predicates and inserts)
- Used by: Pipelines, ViewModels

**Domain Models (SwiftData):**
- Purpose: Define persistent entities and their relationships
- Location: `WorkloadApp/Models/` — Athlete, WorkoutSession, ExerciseEntry, SetRecord, WorkloadSnapshot, RecoverySnapshot, WellnessCheckIn, PersonalRecord, CoachAthleteRelationship, WorkoutTemplate, PrescribedWorkout, CustomExercise, ExerciseGroup, TemplateExercise, TemplateSet
- Contains: `@Model final class` with `@Relationship(deleteRule: .cascade)` for parent-child links
- Depends on: Enums (for typed fields), nothing else
- Used by: All layers

**Infrastructure (Services):**
- Purpose: Manage external integrations (Supabase, HealthKit, subscriptions, NFC)
- Location: `WorkloadApp/Services/` — AuthService, HealthKitService, SyncService, SubscriptionService, NFCSessionCoordinator, InviteService
- Contains: `@MainActor final class` or `@MainActor struct` wrapping SDK clients
- Depends on: Models (for data shapes), Supabase/HealthKit SDKs
- Used by: AppContainer, Pipelines, ViewModels

**Dependency Container:**
- Purpose: Centralize instantiation and lifecycle of all service instances
- Location: `WorkloadApp/App/AppContainer.swift`
- Contains: SubscriptionService, SupabaseClient, AuthService, HealthKitService, SyncService, plus isAuthenticated state
- Used by: AppRouter via `@State`, injected to all views via `@Environment(AppContainer.self)`

## Data Flow

**Post-Workout:**

1. **ActiveWorkoutSheet** saves WorkoutSession
2. **WorkoutPipeline.processSession()** orchestrates:
   - `PRDetector.detectPRs()` → new PersonalRecords
   - `WorkloadCalculator.computeHistoryEWMA()` → EWMA workload history
   - `WorkoutRepository.upsertSnapshot()` → persists WorkloadSnapshot
   - Session stamped with ATL/CTL values
   - `SyncService.pushWorkloadSnapshots()` → async Supabase push

**Recovery (App Launch / Wellness Check-in):**

1. **DashboardView** or **MorningCheckInSheet** triggers `RecoveryPipeline.run()`
2. **RecoveryPipeline** orchestrates:
   - `HealthKitService.fetchLatestHRV()`, `fetchLatestRestingHR()`, etc. → HealthKit biometrics
   - `RecoveryRepository.fetchRecoveryHistory()` → 7-day history for baselines
   - `RecoveryScoreEngine.computeBaseline()` → individual sensor baselines
   - `RecoveryScoreEngine.compute()` → composite recovery score (0-100)
   - `RecoveryRepository.upsertRecoverySnapshot()` → persists snapshot
   - `SyncService.pushRecoveryAndWellness()` → async sync

**Dashboard Load:**

1. **DashboardView** appears
2. **DashboardViewModel.load()** runs:
   - `RecoveryPipeline.run()` (if not screenshot mode)
   - `RecoveryRepository.fetchTodaySnapshot()` → raw biometric values
   - `AutoregulationEngine.compute()` → training recommendation
   - `ReasoningEngine.computeFactors()` → transparency (why this score)
   - `RecoveryRepository.fetchRecoveryHistory()` → 28-day HRV data for trends

**Auth Check (AppRouter startup):**

1. Check Keychain for existing Supabase session
2. If yes: `SyncService.bootstrapAthlete()` → pull Athlete from Supabase if missing locally
3. If no session or bootstrap failed (zombie account): sign out
4. Link pending invite via deep link if provided
5. Foreground sync on app activation and mode change (AppRouter → MainTabView)

**Coach Mode Data Flow:**

1. **MainTabView.onChange(scenePhase)** when mode == .coach:
   - `SyncService.pullLinkedAthletes()` → fetch all accepted coach-athlete relationships
   - `SyncService.pullAthleteSnapshots(athleteId)` → for each linked athlete, fetch latest snapshots
2. **CoachRosterView** displays list of athletes with latest recovery/load snapshots
3. Coach can view athlete detail, assign prescribed workouts, track progression

## State Management

- **Authentication state:** AppContainer.isAuthenticated (boolean)
- **App mode:** AppContainer.currentMode stored in UserDefaults, synchronized across app
- **Athlete context:** Current athlete fetched via `@Query` in most views, `.first` assumed
- **ViewModel state:** Each screen has dedicated ViewModel (DashboardViewModel, WorkoutLogViewModel, etc.) holding transient UI state (loading flags, detail views, etc.)
- **Recovery/Workload snapshots:** Persisted daily via pipeline, queried via `@Query` for charts and history views
- **Sync state:** SyncService tracks `shouldForegroundSync` (time-based), orchestrates push/pull on foreground or mode change

## Key Abstractions

**Pipeline Pattern:**
- Purpose: Multi-step orchestration with explicit separation of concerns
- Examples: `WorkoutPipeline.processSession()`, `RecoveryPipeline.run()`
- Pattern: Takes athlete + context, runs engines, saves snapshots, triggers async sync

**Engine Pattern:**
- Purpose: Pure, testable computation without state or side effects
- Examples: WorkloadCalculator (EWMA, TRIMP, spike detection), RecoveryScoreEngine (HRV baseline + score), AutoregulationEngine (recommendations), PRDetector (max detection), ProgressionEngine (rep/weight PRs)
- Pattern: `struct` with static methods, no dependencies except Models/Enums, deterministic output

**Repository Pattern:**
- Purpose: Data access abstraction
- Examples: WorkoutRepository, RecoveryRepository, AthleteRepository
- Pattern: `@MainActor final class` wrapping ModelContext, methods for fetch (with predicates) and save

**Observable ViewModel Pattern:**
- Purpose: Bridge between SwiftUI reactivity and business logic
- Examples: DashboardViewModel, WorkoutLogViewModel
- Pattern: `@MainActor @Observable final class` with async `load()` methods, state properties, dependency injection via init

## Entry Points

**App Launch:**
- Location: `WorkloadApp/App/WorkloadApp.swift`
- Triggers: SwiftUI app lifecycle
- Responsibilities: Initialize SwiftData ModelContainer with schema, set up WindowGroup

**Routing & Auth Check:**
- Location: `WorkloadApp/App/AppRouter.swift`
- Triggers: App launch
- Responsibilities: Check Keychain session, bootstrap Athlete if needed, show ProgressView (loading) → LoginView (no auth) → MainTabView (authenticated)

**Tab Navigation:**
- Location: `WorkloadApp/App/AppRouter.swift` (MainTabView struct)
- Triggers: Authenticated app state
- Responsibilities: Render TabView with athlete tabs (Home, Log, Recovery, Load, Profile) or coach tabs (Roster, Templates, Profile); handle mode switching; foreground sync on scenePhase.active

**Dashboard (Athlete Home):**
- Location: `WorkloadApp/Views/Dashboard/DashboardView.swift`
- Responsibilities: Render hero readiness card (recovery score), metrics strip, training load section, recent sessions

**Workout Logging:**
- Location: `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift` + ActiveWorkoutSheet
- Responsibilities: Display session history, allow new session creation, trigger WorkoutPipeline on save

## Error Handling

**Strategy:** Graceful degradation with fallback UI states

**Patterns:**
- **HealthKit authorization missing:** Render EmptyStateCard on Dashboard suggesting permission grant; fetch returns nil, recovery score degrades
- **Supabase sync failures:** Log error, continue local app operation; isSynced flag tracks state for retry
- **Pipeline computation failures:** `try/catch` in ViewModel load methods, errors logged, fallback values used (recovery score defaults to 50, ACWR defaults to .noData)
- **Session spike detection:** Returns nil if insufficient prior data (< 3 sessions), UI renders conditional UI
- **Zombie accounts:** If auth session exists but no Athlete row in Supabase, auto sign-out (resilience in AppRouter)

## Cross-Cutting Concerns

**Logging:** `print()` statements throughout for debug visibility; no external logging service

**Validation:** Input validation in ViewModel `load()` methods before passing to engines; Supabase schema enforces database constraints

**Authentication:** Supabase Auth (email/password) via AuthService; Keychain session persisted by Supabase SDK; AppContainer.isAuthenticated gates MainTabView access

**Sync:** SyncService orchestrates bidirectional push/pull; debounced via `shouldForegroundSync` (time threshold); coach mode pulls athlete snapshots, athlete mode pushes and pulls

**Subscription Gating:** SubscriptionService fetches entitlements from RevenueCat; isProUser and isCoach flags gate feature access (ACWR history, custom exercises, coach UI)

**Design Consistency:** ColorTokens and FontTokens provide semantic color/font constants; all text uses DM Sans font via Font.custom()

---

*Architecture analysis: 2026-04-20*
