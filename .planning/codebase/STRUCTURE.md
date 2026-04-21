# Codebase Structure

**Analysis Date:** 2026-04-20

## Directory Layout

```
WorkloadApp/
├── App/                          # Entry point, routing, dependency injection
│   ├── WorkloadApp.swift         # @main app, ModelContainer init
│   ├── AppContainer.swift        # Central dependency hub
│   └── AppRouter.swift           # Auth check, tab navigation
├── Models/                       # SwiftData @Model domain classes
│   ├── Athlete.swift
│   ├── WorkoutSession.swift
│   ├── ExerciseEntry.swift
│   ├── SetRecord.swift
│   ├── WorkloadSnapshot.swift
│   ├── RecoverySnapshot.swift
│   ├── WellnessCheckIn.swift
│   ├── PersonalRecord.swift
│   ├── CoachAthleteRelationship.swift
│   ├── WorkoutTemplate.swift
│   ├── PrescribedWorkout.swift
│   ├── ExerciseGroup.swift
│   ├── TemplateExercise.swift
│   ├── TemplateSet.swift
│   ├── CustomExercise.swift
│   └── Enums.swift               # All domain enums
├── Services/                     # Business logic, orchestration, integrations
│   ├── WorkoutPipeline.swift     # Post-workout flow (PR → workload → sync)
│   ├── RecoveryPipeline.swift    # Recovery data flow (HealthKit → score → snapshot)
│   ├── WorkloadCalculator.swift  # EWMA, TRIMP, ACWR, spike detection
│   ├── RecoveryScoreEngine.swift # HRV/RHR baseline + composite score
│   ├── AutoregulationEngine.swift # Training recommendations
│   ├── PRDetector.swift          # Personal record detection
│   ├── ProgressionEngine.swift   # Rep/weight progression analysis
│   ├── ReasoningEngine.swift     # Recovery score factor transparency
│   ├── AuthService.swift         # Supabase auth wrapper
│   ├── HealthKitService.swift    # HealthKit data fetching
│   ├── SyncService.swift         # Bidirectional Supabase sync
│   ├── SubscriptionService.swift # RevenueCat entitlements
│   ├── InviteService.swift       # Coach invite code handling
│   ├── NFCSessionCoordinator.swift # NFC tap detection
│   └── RevenueCatConfig.swift    # RevenueCat API keys (gitignored)
├── Repositories/                 # SwiftData data access
│   ├── AthleteRepository.swift
│   ├── WorkoutRepository.swift
│   ├── WorkloadRepository.swift
│   └── RecoveryRepository.swift
├── ViewModels/                   # @Observable screen state managers
│   ├── DashboardViewModel.swift
│   ├── WorkoutLogViewModel.swift
│   ├── RecoveryViewModel.swift
│   └── CoachRosterViewModel.swift
├── Views/                        # SwiftUI presentation layer
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   ├── HeroReadinessCard.swift
│   │   ├── MetricsStrip.swift
│   │   ├── TrainingLoadSection.swift
│   │   ├── RecentSessionsSection.swift
│   │   └── ...
│   ├── WorkoutLog/
│   │   ├── WorkoutLogView.swift
│   │   ├── ActiveWorkoutSheet.swift
│   │   ├── SessionDetailView.swift
│   │   ├── ExercisePickerView.swift
│   │   └── ...
│   ├── Recovery/
│   │   ├── RecoveryView.swift
│   │   ├── MorningCheckInSheet.swift
│   │   └── ...
│   ├── Workload/
│   │   ├── WorkloadView.swift
│   │   └── ...
│   ├── Coach/
│   │   ├── CoachRosterView.swift
│   │   ├── ContextSwitcher.swift
│   │   ├── TemplateListView.swift
│   │   └── ...
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   ├── SignUpView.swift
│   │   └── ...
│   ├── Profile/
│   ├── Onboarding/
│   ├── Subscription/
│   │   └── UpgradeSheet.swift
│   ├── Analytics/
│   └── TemplateEditorSheet.swift
├── Components/                   # Reusable UI components
│   ├── MetricTile.swift
│   ├── ZoneBadge.swift
│   ├── HRVTrendChart.swift
│   ├── SleepTrendChart.swift
│   ├── SpikeAlertBanner.swift
│   └── ...
├── Utilities/                    # Helpers and formatters
│   ├── ColorTokens.swift         # Semantic color system
│   ├── FontTokens.swift          # Font configuration
│   ├── DateHelpers.swift         # Date formatting extensions
│   ├── WeightFormatter.swift     # Weight unit conversion
│   └── MockDataSeeder.swift      # Test data generation (DEBUG)
├── Resources/
│   ├── Assets.xcassets/          # App icons, colors
│   └── ...
└── Preview Content/
```

## Directory Purposes

**App/:**
- Purpose: Application bootstrap and routing
- Contains: Entry point, dependency container, authentication gate
- Key files: WorkloadApp.swift (SwiftUI app), AppContainer.swift (services), AppRouter.swift (auth + nav)

**Models/:**
- Purpose: Domain model definitions and persistence schema
- Contains: @Model classes with relationships, enums for all domain types
- Key files: Athlete.swift (root entity), WorkoutSession.swift (session + exercises), Enums.swift (all types)

**Services/:**
- Purpose: Business logic, workflows, and external integrations
- Contains: Pure engines (WorkloadCalculator), orchestration pipelines, service wrappers
- Key files: WorkoutPipeline.swift (post-workout), RecoveryPipeline.swift (recovery), SyncService.swift (backend sync)

**Repositories/:**
- Purpose: Data persistence operations
- Contains: SwiftData fetch/save wrappers with typed predicates
- Key files: WorkoutRepository.swift, RecoveryRepository.swift

**ViewModels/:**
- Purpose: Screen-level state management
- Contains: @Observable classes with async load() methods
- Key files: DashboardViewModel.swift, WorkoutLogViewModel.swift

**Views/:**
- Purpose: SwiftUI presentation organized by feature/tab
- Contains: SwiftUI struct View definitions, sheet overlays
- Key directories: Dashboard (home), WorkoutLog (session logging), Recovery (HRV/RHR/sleep), Coach (coach-only), Auth (login/signup)

**Components/:**
- Purpose: Reusable view components
- Contains: Small, composable UI building blocks
- Key files: MetricTile.swift, HRVTrendChart.swift

**Utilities/:**
- Purpose: Shared helpers and formatting
- Contains: Color/font tokens, date formatting, weight conversion, mock data
- Key files: ColorTokens.swift (semantic colors), DateHelpers.swift (date ext), MockDataSeeder.swift (DEBUG fixtures)

## Key File Locations

**Entry Points:**
- `WorkloadApp/App/WorkloadApp.swift`: @main app, initializes ModelContainer
- `WorkloadApp/App/AppRouter.swift`: Routes to login or main app; checks auth on launch

**Configuration:**
- `WorkloadApp/Models/Enums.swift`: All domain enums (SportType, ACWRZone, RecoveryZone, SessionType, etc.)
- `WorkloadApp/Utilities/ColorTokens.swift`: Semantic color constants
- `WorkloadApp/Utilities/FontTokens.swift`: Font configuration (DM Sans)
- `WorkloadApp/Services/RevenueCatConfig.swift`: RevenueCat API keys (gitignored, not in repo)

**Core Logic:**
- `WorkloadApp/Services/WorkloadCalculator.swift`: EWMA, TRIMP, ACWR, spike detection
- `WorkloadApp/Services/RecoveryScoreEngine.swift`: Baseline computation, composite score
- `WorkloadApp/Services/WorkoutPipeline.swift`: Post-workout orchestration (PR → workload → sync)
- `WorkloadApp/Services/RecoveryPipeline.swift`: Recovery orchestration (HealthKit → baselines → score)

**Persistence:**
- `WorkloadApp/Models/Athlete.swift`: Root entity with cascade relationships
- `WorkloadApp/Repositories/WorkoutRepository.swift`: Session fetch/save
- `WorkloadApp/Repositories/RecoveryRepository.swift`: Snapshot and wellness fetch/save

**Testing:**
- Test files in `/WorkloadAppTests/` (separate Xcode target)
- Key tests: WorkloadCalculatorTests, RecoveryScoreEngineTests, AutoregulationEngineTests, SyncService tests

## Naming Conventions

**Files:**
- Pattern: `PascalCase.swift` for all files
- Examples: `DashboardView.swift`, `WorkoutPipeline.swift`, `ColorTokens.swift`

**Directories:**
- Pattern: `PascalCase` for feature directories (Views/Dashboard, Views/WorkoutLog)
- Pattern: lowercase for utility directories (Utilities, Services, Repositories)

**Types:**
- `struct` for pure logic: WorkloadCalculator, RecoveryScoreEngine, AutoregulationEngine
- `struct` for pipelines: WorkoutPipeline, RecoveryPipeline
- `@Model final class` for domain models: Athlete, WorkoutSession, RecoverySnapshot
- `@MainActor final class` for repositories: WorkoutRepository, RecoveryRepository
- `@MainActor @Observable final class` for ViewModels: DashboardViewModel, WorkoutLogViewModel
- `@MainActor final class` for services: AuthService, HealthKitService, SyncService
- `struct View` for SwiftUI views: DashboardView, WorkoutLogView
- `enum` for all domain types (SportType, ACWRZone, etc.)

**Functions/Methods:**
- camelCase for all function names
- Examples: `processSession()`, `computeHistoryEWMA()`, `detectSessionSpike()`

**Variables:**
- camelCase for all variable names
- Examples: `recoveryScore`, `trainingStress`, `acwr`
- Prefix with underscore for private properties: `_modelContext`

## Where to Add New Code

**New Feature (e.g., fatigue tracking):**
- **Model:** `WorkloadApp/Models/FatigueSnapshot.swift` (add @Model class)
- **Engine:** `WorkloadApp/Services/FatigueEngine.swift` (pure computation)
- **Pipeline:** Update `WorkoutPipeline.swift` or create `FatiguePipeline.swift`
- **Repository:** `WorkloadApp/Repositories/FatigueRepository.swift`
- **ViewModel:** `WorkloadApp/ViewModels/FatigueViewModel.swift`
- **View:** `WorkloadApp/Views/Fatigue/FatigueView.swift`
- **Tests:** `WorkloadAppTests/FatigueEngineTests.swift`, `FatigueRepositoryTests.swift`

**New Component (e.g., custom chart):**
- Location: `WorkloadApp/Components/FatigueChart.swift`
- Pattern: `struct` conforming to `View`, accept data as property, render UI

**New Utility:**
- Location: `WorkloadApp/Utilities/FatigueFormatter.swift` or add extension to `DateHelpers.swift`
- Pattern: Free functions or extensions on existing types

**New Service Integration (e.g., new HealthKit metric):**
- Location: Add method to `WorkloadApp/Services/HealthKitService.swift`
- Pattern: `async func fetchLatestFatigue() throws -> Double?`

**Coach Feature (e.g., athlete detail view):**
- Location: `WorkloadApp/Views/Coach/AthleteDetailView.swift`
- Pattern: `struct View` taking athleteId, fetching data via @Query or ViewModel

## Special Directories

**Resources/Assets.xcassets/:**
- Purpose: App icons, colors, images
- Generated: No (checked into repo)
- Committed: Yes

**Preview Content/:**
- Purpose: SwiftUI previews for Xcode canvas
- Generated: No
- Committed: Yes (mock data for previews)

**WorkloadAppTests/ (separate target):**
- Purpose: Unit and integration tests
- Pattern: `*Tests.swift` files matching source modules
- Key test files: WorkloadCalculatorTests, RecoveryScoreEngineTests, AutoregulationEngineTests, SyncServiceTests

**.planning/codebase/ (this directory):**
- Purpose: Generated architecture and structure documentation
- Generated: Yes (by GSD mapper)
- Committed: Yes (valuable reference for future development)

---

*Structure analysis: 2026-04-20*
