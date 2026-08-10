import XCTest
@testable import workload_management

/// Guards born from the 2026-08-10 incident: SCREENSHOT_MODE ran on a physical device,
/// wiped the local store, and seeded a mock athlete whose pushes were all RLS-rejected
/// while the Sync Status screen stayed green (the pull that followed each failed push
/// cleared the shared per-entity error slot).
///
/// Three fences here:
/// 1. `SyncTimestampStore` keeps push and pull failures in separate slots — a pull
///    success must never clear a push failure.
/// 2. The store exposes `hasPushRisk`, which gates the sign-out wipe.
/// 3. Source fences: the AppRouter screenshot branch is compiled only for the simulator,
///    and every public SyncService push/pull seam runs the identity guard.
@MainActor
final class SyncGuardTests: XCTestCase {

    private var store: SyncTimestampStore { SyncTimestampStore.shared }

    override func setUp() async throws {
        try await super.setUp()
        store.clearAll()
    }

    override func tearDown() async throws {
        store.clearAll()
        try await super.tearDown()
    }

    // MARK: - Per-direction error state

    func testPullSuccessDoesNotClearPushFailure() {
        store.recordFailure(for: .workouts, direction: .push, error: "Sync error", detail: "RLS")
        store.recordSuccess(for: .workouts, direction: .pull)

        XCTAssertNotNil(store.lastError(for: .workouts),
                        "A pull success cleared a push failure — the 2026-08-10 masking defect")
        XCTAssertTrue(store.hasAnyFailure)
        XCTAssertTrue(store.hasPushRisk)
    }

    func testPushSuccessClearsPushFailure() {
        store.recordFailure(for: .workouts, direction: .push, error: "Sync error")
        store.recordSuccess(for: .workouts, direction: .push)

        XCTAssertNil(store.lastError(for: .workouts))
        XCTAssertFalse(store.hasPushRisk)
    }

    func testPushFailureOutranksPullFailureForDisplay() {
        store.recordFailure(for: .workouts, direction: .pull, error: "Data format error")
        store.recordFailure(for: .workouts, direction: .push, error: "Sync error", detail: "RLS")

        XCTAssertEqual(store.lastError(for: .workouts)?.message, "Sync error",
                       "The push failure is the data-loss scenario; it must win the row display")
    }

    func testPullFailureAloneIsNotPushRisk() {
        store.recordFailure(for: .recoverySnapshots, direction: .pull, error: "Data format error")

        XCTAssertTrue(store.hasAnyFailure)
        XCTAssertFalse(store.hasPushRisk,
                       "A pull failure loses no local data; it must not trip the sign-out guard")
    }

    // MARK: - Identity fault

    func testIdentityFaultTripsBothFlags() {
        store.recordIdentityFault(.accountMismatch)

        XCTAssertTrue(store.hasAnyFailure)
        XCTAssertTrue(store.hasPushRisk)

        store.clearIdentityFault()
        XCTAssertFalse(store.hasAnyFailure)
        XCTAssertFalse(store.hasPushRisk)
    }

    func testClearAllClearsEverything() {
        store.recordFailure(for: .workouts, direction: .push, error: "Sync error")
        store.recordFailure(for: .templates, direction: .pull, error: "Sync error")
        store.recordIdentityFault(.unlinkedAthlete)

        store.clearAll()

        XCTAssertFalse(store.hasAnyFailure)
        XCTAssertFalse(store.hasPushRisk)
        XCTAssertNil(store.lastError(for: .workouts))
        XCTAssertNil(store.lastError(for: .templates))
    }

    // MARK: - Source fences

    private func repoRoot(file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()   // WorkloadAppTests/
            .deletingLastPathComponent()   // <repo root>
    }

    private func readSource(_ relativePath: String) -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("SYNC-GUARD fence could not resolve source at \(url.path)")
            return ""
        }
        return contents
    }

    /// The screenshot branch wipes the local store and seeds mock data. On a physical
    /// device that destroys real training data (it did, 2026-08-10). Every DEBUG block
    /// in AppRouter that can reach `resetScreenshotData` or `MockDataSeeder` must be
    /// compiled for the simulator only.
    func testScreenshotModeIsSimulatorOnly() {
        let source = readSource("WorkloadApp/App/AppRouter.swift")
        XCTAssertFalse(source.isEmpty)

        XCTAssertFalse(
            source.contains("#if DEBUG\n"),
            "AppRouter contains a bare `#if DEBUG` block — the screenshot/wipe paths must use `#if DEBUG && targetEnvironment(simulator)`"
        )
        XCTAssertTrue(
            source.contains("#if DEBUG && targetEnvironment(simulator)"),
            "The simulator-only guard on the screenshot branch is missing"
        )
    }

    /// Every public SyncService push/pull seam must verify the local athlete belongs to
    /// the signed-in session before touching the network. Counting call sites keeps a
    /// future seam from shipping unguarded silently.
    func testSyncSeamsRunIdentityGuard() {
        let source = readSource("WorkloadApp/Services/SyncService.swift")
        XCTAssertFalse(source.isEmpty)

        let guardCalls = source.components(separatedBy: "guard await verifyIdentity(").count - 1
        XCTAssertGreaterThanOrEqual(
            guardCalls, 7,
            "Expected the identity guard on pushAll, pullAll, pushAthlete, pushWorkloadSnapshots, pushRecoveryAndWellness, pushWorkoutTemplates, and pushTrainingProfile — found \(guardCalls) call sites"
        )
    }
}
