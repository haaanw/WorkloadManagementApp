# Testing Patterns

**Analysis Date:** 2026-04-20

## Test Framework

**Runner:**
- XCTest (Apple's native testing framework)
- Integrated into Xcode test target `WorkloadAppTests`
- No external test runners (Nimble, Quick, etc.)

**Assertion Library:**
- XCTest assertions: `XCTAssertEqual()`, `XCTAssertNil()`, `XCTAssertGreaterThan()`, `XCTAssertTrue()`
- Custom accuracy tolerance for floating-point comparisons: `XCTAssertEqual(value, expected, accuracy: epsilon)`

**Run Commands:**
```bash
# Run all tests in Xcode target
xcodebuild test -scheme workload_management -destination 'platform=iOS Simulator'

# Run specific test class
xcodebuild test -scheme workload_management -destination 'platform=iOS Simulator' \
  -only-testing:WorkloadAppTests/WorkloadCalculatorTests

# Run with coverage
xcodebuild test -scheme workload_management -enableCodeCoverage YES
```

## Test File Organization

**Location:**
- Co-located in separate `WorkloadAppTests` target
- One test file per engine/service: `WorkloadCalculatorTests.swift`, `RecoveryScoreEngineTests.swift`
- Repository mirror: Test files alongside implementation, not in parallel directory tree

**Naming:**
- `*Tests.swift` for test classes: `WorkloadCalculatorTests.swift`, `AutoregulationEngineTests.swift`
- Test class: `final class WorkloadCalculatorTests: XCTestCase`
- Test methods: `func test_<subject>_<behavior>()`
  - Example: `test_sessionTSS_oneHourRPE5()`, `test_computeHistoryEWMA_convergence()`
  - Pattern: `test_<functionName>_<inputCondition>_<expectedOutcome>()`

**Structure:**
```
WorkloadAppTests/
├── WorkloadCalculatorTests.swift
├── RecoveryScoreEngineTests.swift
├── AutoregulationEngineTests.swift
├── SubscriptionGatingTests.swift
├── InviteServiceTests.swift
├── CoachRosterViewModelTests.swift
├── CoachRelationshipModelTests.swift
├── ReasoningEngineTests.swift
└── SessionTypeTests.swift
```

## Test Structure

**Suite Organization:**
```swift
final class WorkloadCalculatorTests: XCTestCase {

    private let epsilon = 0.0001

    // MARK: - sessionTSS

    func test_sessionTSS_oneHourRPE5() {
        // arrange
        let tss = WorkloadCalculator.sessionTSS(durationSeconds: 3600, sessionRPE: 5)

        // assert
        XCTAssertEqual(tss, 2.5, accuracy: epsilon)
    }
}
```

**Patterns:**
- No `setUp()` or `tearDown()` (engines are stateless, no shared state)
- No mocks or stubs in test files (engines are pure functions)
- Test epsilon constant defined at class level for floating-point tolerance
- Lightweight test fixtures (simple structs, not database)

**Arrangement Pattern:**
```swift
// Three-part test: arrange, act, assert
func test_spikeDetection_moderateSpike() {
    // Arrange
    let recent = [2.0, 3.0, 4.0, 3.0, 3.0]

    // Act
    let result = WorkloadCalculator.detectSessionSpike(
        sessionTSS: 5.0,
        recentSessionTSSValues: recent
    )

    // Assert
    XCTAssertNotNil(result)
    XCTAssertEqual(result!.ratio, 5.0 / 3.0, accuracy: epsilon)
}
```

## Mocking

**Framework:**
- None used (no external mocking library)
- Manual test data creation via helper functions
- Pure engines eliminate need for mocking

**Patterns:**
```swift
// Helper factory for test data
private func makeSession(daysAgo: Int, from date: Date) -> WorkoutSession {
    WorkoutSession(
        sessionDate: Calendar.current.date(byAdding: .day, value: -daysAgo, to: date)!,
        sportType: .lifting,
        durationSeconds: 3600
    )
}

// Usage in test
func test_filterSessionsForFree_keepsSessionsWithin7Days() {
    let now = Date()
    let recent = makeSession(daysAgo: 3, from: now)
    let old = makeSession(daysAgo: 10, from: now)
    let result = SubscriptionService.filterSessionsForFree([recent, old], relativeTo: now)
    XCTAssertEqual(result.count, 1)
}
```

**What to Mock:**
- Nothing in current test suite (engines are pure, no side effects)
- If testing a service with external dependencies, would manually create test doubles

**What NOT to Mock:**
- Pure calculation engines (test directly with real math)
- Core domain logic (test behavior, not implementation)
- Enum and value type conversions

## Fixtures and Factories

**Test Data:**
```swift
// Factory methods define default test data
private func makeDailyLoads(tss: Double, days: Int, startingFrom base: Date = .now)
    -> [WorkloadCalculator.DailyLoad] {
    (0..<days).map { i in
        let date = Calendar.current.date(byAdding: .day, value: i, to: base)!
        return WorkloadCalculator.DailyLoad(date: date, tss: tss)
    }
}

// Input struct factory for complex test arguments
private func input(
    recovery: RecoveryZone,
    recoveryScore: Double = 70,
    acwr: ACWRZone,
    acwrValue: Double = 1.0,
    wellness: Double? = nil,
    daysSinceRest: Int = 0
) -> AutoregulationEngine.DailyInput {
    AutoregulationEngine.DailyInput(
        recoveryZone: recovery,
        recoveryScore: recoveryScore,
        acwrZone: acwr,
        acwr: acwrValue,
        wellnessScore: wellness,
        daysSinceLastRest: daysSinceRest
    )
}
```

**Location:**
- Private helper methods defined at end of test class after all test methods
- Named `make*()` or `input()` for clarity
- Generic enough to be reused across multiple test methods

## Coverage

**Requirements:**
- No enforced coverage target in CI/CD
- Engines have comprehensive test coverage (95%+): `WorkloadCalculatorTests` covers all public methods
- ViewModels and pipelines have partial coverage (integration testing relied on instead)
- Repositories untested (thin wrappers around SwiftData, covered by integration tests)

**View Coverage Report:**
```bash
# After running tests with code coverage enabled
# Coverage data available in Xcode: Product > Scheme > Edit Scheme > Test > Code Coverage
```

## Test Types

**Unit Tests:**
- Scope: Pure engine functions (single responsibility)
- Approach: Test mathematical correctness and edge cases
- Examples:
  - `WorkloadCalculatorTests`: TSS calculation, EWMA convergence, zone classification
  - `RecoveryScoreEngineTests`: Scoring algorithms, weight redistribution, baseline computation
  - `AutoregulationEngineTests`: Decision matrix (12 recovery × workload combinations)
  - `InviteServiceTests`: Code generation randomness, deep link parsing

**Integration Tests:**
- Not formally separated (no integration test target)
- Test interactions between ViewModel → Pipeline → Engine → Repository
- Tested manually in Xcode via UI or via SCREENSHOT_MODE launch argument

**E2E Tests:**
- Not in current test suite
- UI automation via XCUITest framework available but not yet implemented
- ScreenshotTests target exists for automated screenshot capture (separate from functional tests)

## Common Patterns

**Floating-Point Comparison:**
```swift
private let epsilon = 0.0001

func test_sessionTSS_oneHourRPE5() {
    let tss = WorkloadCalculator.sessionTSS(durationSeconds: 3600, sessionRPE: 5)
    XCTAssertEqual(tss, 2.5, accuracy: epsilon)
}

// Avoid exact equality for floats
// ❌ XCTAssertEqual(result.acwr, 1.0)  // Can fail due to rounding
// ✓ XCTAssertEqual(result.acwr, 1.0, accuracy: epsilon)
```

**Optional/Nil Testing:**
```swift
// Test for nil when no spike detected
func test_spikeDetection_insufficientData_fewerThan3Sessions() {
    let recent = [3.0, 4.0]
    let result = WorkloadCalculator.detectSessionSpike(
        sessionTSS: 20.0,
        recentSessionTSSValues: recent
    )
    XCTAssertNil(result)
}

// Test for non-nil when spike present
func test_spikeDetection_moderateSpike() {
    let recent = [2.0, 3.0, 4.0, 3.0, 3.0]
    let result = WorkloadCalculator.detectSessionSpike(sessionTSS: 5.0, recentSessionTSSValues: recent)
    XCTAssertNotNil(result)
    XCTAssertEqual(result!.severity, .moderate)
}
```

**Range/Boundary Testing:**
```swift
// Test score clamping
func test_score_isClamped_0to100() {
    let input = RecoveryScoreEngine.RecoveryInput(
        hrvSDNN: 35, restingHR: 90, sleepDurationMinutes: 180,
        wellnessScore: 5, hrvBaseline: 50, restingHRBaseline: 55
    )
    let result = RecoveryScoreEngine.compute(input: input)
    XCTAssertGreaterThanOrEqual(result.score, 0)
    XCTAssertLessThanOrEqual(result.score, 100)
}

// Test boundary conditions
func test_hrZone_boundary60pct() {
    XCTAssertEqual(WorkloadCalculator.hrZone(heartRate: 120, maxHR: 200), 2)
}

func test_hrZone_boundary90pct() {
    XCTAssertEqual(WorkloadCalculator.hrZone(heartRate: 180, maxHR: 200), 5)
}
```

**Edge Cases (Empty, Zero, Negative):**
```swift
// Empty input
func test_computeHistoryEWMA_emptyInput() {
    let results = WorkloadCalculator.computeHistoryEWMA(loads: [])
    XCTAssertTrue(results.isEmpty)
}

// Zero values
func test_sessionTSS_zeroDuration() {
    let tss = WorkloadCalculator.sessionTSS(durationSeconds: 0, sessionRPE: 8)
    XCTAssertEqual(tss, 0)
}

// Division by zero protection
func test_computeHistoryEWMA_noDivisionByZero() {
    let loads = makeDailyLoads(tss: 0, days: 10)
    let results = WorkloadCalculator.computeHistoryEWMA(loads: loads)
    for result in results {
        XCTAssertEqual(result.acwr, 0)  // Not NaN or infinity
    }
}
```

**Parametric Variation:**
```swift
// Test matrix: 4 recovery zones × 4 workload zones = 12 cases
func test_greenOptimal_fullSend() {
    let rec = AutoregulationEngine.recommend(input: input(recovery: .green, acwr: .optimal))
    XCTAssertEqual(rec.sessionType, .power)
    XCTAssertEqual(rec.volumeModifier, 1.0)
}

func test_greenCaution_strength85pct() {
    let rec = AutoregulationEngine.recommend(input: input(recovery: .green, acwr: .caution))
    XCTAssertEqual(rec.sessionType, .strength)
    XCTAssertEqual(rec.volumeModifier, 0.85)
}

// ... 10 more decision matrix tests ...
```

## Test Execution Examples

**Run all tests:**
```bash
xcodebuild test -scheme workload_management \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

**Run single test class:**
```bash
xcodebuild test -scheme workload_management \
  -destination 'platform=iOS Simulator' \
  -only-testing:WorkloadAppTests/WorkloadCalculatorTests
```

**Run with verbose output:**
```bash
xcodebuild test -scheme workload_management \
  -destination 'platform=iOS Simulator' \
  -v
```

**Typical Test File Count:**
- 9 test files total
- ~80–350 test methods per file
- ~20–40 lines per test method (includes arrange/act/assert)

## Known Testing Gaps

**Not Yet Tested:**
- ViewModels (DashboardViewModel, WorkoutLogViewModel, RecoveryViewModel, CoachRosterViewModel)
  - Would require @MainActor isolation and async/await testing
  - Partially covered by ScreenshotTests automation
- Repositories (AthleteRepository, WorkoutRepository, etc.)
  - Thin SwiftData wrappers, covered by integration tests
- Pipelines (WorkoutPipeline, RecoveryPipeline)
  - Complex orchestration, tested via ViewModel integration tests
- Views (SwiftUI)
  - Manual testing + ScreenshotTests automation
- Supabase sync logic
  - Requires live backend or mocking network calls

**Priority for Future Testing:**
1. ViewModel async initialization (DashboardViewModel.load())
2. Pipeline orchestration (RecoveryPipeline.run())
3. Sync edge cases (SyncService error handling)
4. Subscription gating logic (paid feature access)

---

*Testing analysis: 2026-04-20*
