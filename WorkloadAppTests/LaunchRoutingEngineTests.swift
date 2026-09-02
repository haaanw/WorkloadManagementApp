import XCTest
@testable import workload_management

/// Guards for the v1.7.3 optimistic local-first launch (dogfood B3).
///
/// Two contracts:
/// 1. The routing decision: a RETURNING user (local Athlete + stored session) routes
///    immediately; blocking is reserved for the fresh-install bootstrap, which encodes the
///    zombie and H7 incidents.
/// 2. The deferred zombie check: once the athlete is inside the app, a background task may
///    SURFACE a fault but must never sign out or wipe — the engine's action type has no
///    sign-out case, and a source fence keeps one from growing back in the router.
final class LaunchRoutingEngineTests: XCTestCase {

    // MARK: - Routing decision

    func testNoSessionRoutesToLogin() {
        XCTAssertEqual(
            LaunchRoutingEngine.decide(hasLocalSession: false, hasLocalAthlete: false),
            .showLogin
        )
    }

    func testNoSessionRoutesToLoginEvenWithLocalAthlete() {
        // A local athlete without any stored session (post sign-out edge) must still land
        // on login — the fast path requires BOTH.
        XCTAssertEqual(
            LaunchRoutingEngine.decide(hasLocalSession: false, hasLocalAthlete: true),
            .showLogin
        )
    }

    func testFreshInstallWithSessionBlocksOnBootstrap() {
        XCTAssertEqual(
            LaunchRoutingEngine.decide(hasLocalSession: true, hasLocalAthlete: false),
            .blockingBootstrap,
            "A session with no local Athlete has nothing to paint — the bootstrap chain must stay blocking"
        )
    }

    func testReturningUserRoutesImmediately() {
        XCTAssertEqual(
            LaunchRoutingEngine.decide(hasLocalSession: true, hasLocalAthlete: true),
            .routeImmediately,
            "A returning user must never wait on the network before first paint (dogfood B3)"
        )
    }

    // MARK: - Deferred zombie behavior

    func testAthleteSurvivingPullIsNoAction() {
        XCTAssertEqual(
            LaunchRoutingEngine.deferredZombieAction(athleteCountAfterPull: 1),
            .none
        )
    }

    func testEmptyStoreAfterPullSurfacesInsteadOfSigningOut() {
        XCTAssertEqual(
            LaunchRoutingEngine.deferredZombieAction(athleteCountAfterPull: 0),
            .surfaceFault,
            "A background task must surface the fault — sign-out (and its wipe cascade) stays behind user confirmation"
        )
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
            XCTFail("LAUNCH fence could not resolve source at \(url.path)")
            return ""
        }
        return contents
    }

    /// The launch task must gate on the LOCAL session check. `hasSession()` refreshes an
    /// expired token over the network, and every-morning expiry was half of the observed
    /// ~10 s launch stall — reintroducing it in AppRouter recreates the bug.
    func testRouterNeverBlocksLaunchOnNetworkSessionCheck() {
        let source = readSource("WorkloadApp/App/AppRouter.swift")
        XCTAssertFalse(source.isEmpty)

        XCTAssertFalse(
            source.contains("authService.hasSession()"),
            "AppRouter calls the network-refreshing hasSession() — launch routing must use hasLocalSession"
        )
        XCTAssertTrue(
            source.contains("hasLocalSession"),
            "The local-session fast-path check is missing from AppRouter"
        )
    }

    /// The deferred (post-paint) sync must never sign the athlete out. The sign-out calls
    /// in AppRouter are legitimate ONLY inside the pre-paint blocking bootstrap chain, so
    /// the fence slices out `runDeferredLaunchSync` and asserts it is clean.
    func testDeferredLaunchSyncNeverSignsOutOrWipes() {
        let source = readSource("WorkloadApp/App/AppRouter.swift")
        XCTAssertFalse(source.isEmpty)

        guard let start = source.range(of: "private func runDeferredLaunchSync") else {
            XCTFail("runDeferredLaunchSync not found — the deferred launch sync seam was renamed or removed")
            return
        }
        // The function ends at the next line that is exactly a brace at one indent level.
        let tail = source[start.lowerBound...]
        let body = tail.range(of: "\n    }").map { String(tail[..<$0.lowerBound]) } ?? String(tail)

        XCTAssertFalse(
            body.contains("signOut"),
            "runDeferredLaunchSync signs out — a background task must surface, never destroy a live session"
        )
        XCTAssertFalse(
            body.contains("delete"),
            "runDeferredLaunchSync deletes local data — the wipe stays behind the user-confirmed sign-out path"
        )
        XCTAssertTrue(
            body.contains("deferredZombieAction"),
            "runDeferredLaunchSync no longer consults LaunchRoutingEngine for the zombie decision"
        )
    }
}
