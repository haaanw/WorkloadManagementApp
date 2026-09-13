import XCTest
@testable import workload_management

/// The orchestration around HealthKit background delivery (v1.7.3 · U4 follow-on), tested
/// through its three seams so no Health store is involved.
///
/// The contract that matters most is the completion handler: HealthKit stops waking an app
/// that leaves three deliveries unacknowledged, so every path — including the ones where the
/// import declines to run or the enable call fails — must call it exactly once, after the
/// import has finished.
@MainActor
final class WatchWorkoutBackgroundDeliveryTests: XCTestCase {

    private struct EnableFailed: Error {}

    /// A registrar that hands the test the handler it was given, so the test can play HealthKit.
    private final class FakeObserver {
        var handler: WatchWorkoutBackgroundDelivery.UpdateHandler?
        var registrations = 0
    }

    private func makeDelivery(
        observer: FakeObserver,
        enableThrows: Bool = false,
        importResult: Int = 0,
        onImport: (@MainActor () async -> Void)? = nil
    ) -> WatchWorkoutBackgroundDelivery {
        WatchWorkoutBackgroundDelivery(hooks: .init(
            registerObserver: { handler in
                observer.registrations += 1
                observer.handler = handler
            },
            enableDelivery: {
                if enableThrows { throw EnableFailed() }
            },
            runImport: { _ in
                await onImport?()
                return importResult
            }
        ))
    }

    // MARK: - The completion contract

    func test_delivery_callsCompletionExactlyOnce_afterTheImport() async {
        var importFinished = false
        var completionCalls = 0
        var completionSawImportFinished = false
        let delivery = makeDelivery(observer: FakeObserver(), importResult: 2, onImport: {
            importFinished = true
        })

        await delivery.handleDelivery {
            completionCalls += 1
            completionSawImportFinished = importFinished
        }

        XCTAssertEqual(completionCalls, 1)
        XCTAssertTrue(completionSawImportFinished, "Completion must fire AFTER the import, not before")
        XCTAssertEqual(delivery.deliveriesHandled, 1)
    }

    func test_delivery_withNothingToImport_stillCompletes() async {
        // The import returning 0 (no athlete yet, not authorized, nothing new) is the common
        // case, and it is the case that would silently switch background delivery off if the
        // handler were skipped.
        var completionCalls = 0
        let delivery = makeDelivery(observer: FakeObserver(), importResult: 0)

        await delivery.handleDelivery { completionCalls += 1 }

        XCTAssertEqual(completionCalls, 1)
    }

    func test_observerCallback_reachesTheFunnel_andCompletes() async throws {
        let observer = FakeObserver()
        let delivery = makeDelivery(observer: observer, importResult: 1)
        delivery.start()

        let handler = try XCTUnwrap(observer.handler, "start() must register the observer")
        let completed = expectation(description: "HealthKit's completion handler is called")
        handler { completed.fulfill() }

        await fulfillment(of: [completed], timeout: 2)
        XCTAssertEqual(delivery.deliveriesHandled, 1)
    }

    // MARK: - Registration

    func test_start_registersOnce() {
        let observer = FakeObserver()
        let delivery = makeDelivery(observer: observer)

        delivery.start()
        delivery.start()

        XCTAssertEqual(observer.registrations, 1)
        XCTAssertTrue(delivery.isObserving)
    }

    // MARK: - The failure path (entitlement absent, simulator, or delivery not firing)

    func test_enableFailure_isRecorded_andNothingElseBreaks() async {
        let observer = FakeObserver()
        let delivery = makeDelivery(observer: observer, enableThrows: true, importResult: 1)

        await delivery.enableDeliveryIfPossible()

        XCTAssertFalse(delivery.isBackgroundDeliveryEnabled)
        XCTAssertNotNil(delivery.lastEnableError)

        // The in-app observer path still works when the entitlement is not honoured…
        var completionCalls = 0
        await delivery.handleDelivery { completionCalls += 1 }
        XCTAssertEqual(completionCalls, 1)
    }

    func test_enableSuccess_isRecorded() async {
        let delivery = makeDelivery(observer: FakeObserver())

        await delivery.enableDeliveryIfPossible()

        XCTAssertTrue(delivery.isBackgroundDeliveryEnabled)
        XCTAssertNil(delivery.lastEnableError)
    }

    func test_deliveryNeverFiring_leavesTheForegroundPathUntouched() {
        // "Entitlement present but delivery not firing" is, from this object's side, a
        // registered observer that is never called. Nothing here runs the import on its own,
        // so the foreground trigger (`AppRouter` / the Log tab) remains the only path — and
        // it is a separate static call this object does not gate, wrap, or replace.
        let observer = FakeObserver()
        let delivery = makeDelivery(observer: observer, importResult: 1)

        delivery.start()

        XCTAssertNotNil(observer.handler)
        XCTAssertEqual(delivery.deliveriesHandled, 0)
    }

    // MARK: - Source fences

    /// The foreground path must not have grown a dependency on the background object: the
    /// router still calls the import service directly, exactly as before this lane.
    func test_fence_foregroundPathStillCallsTheImportServiceDirectly() throws {
        let source = try sourceOf("WorkloadApp/App/AppRouter.swift")
        XCTAssertTrue(source.contains("WatchWorkoutImportService.run("),
                      "AppRouter's foreground handler must still run the import itself")
    }

    /// Registration happens at process start, not from a view: a HealthKit background launch
    /// builds no scene, so an observer registered anywhere later would never exist.
    func test_fence_observerIsInstalledInAppInit() throws {
        let source = try sourceOf("WorkloadApp/App/WorkloadApp.swift")
        XCTAssertTrue(source.contains("WatchWorkoutBackgroundDelivery.install(modelContainer:"),
                      "The observer must be installed from WorkloadApp.init")
    }

    private func sourceOf(_ relativePath: String) throws -> String {
        let thisFile = URL(fileURLWithPath: #filePath)
        let repoRoot = thisFile.deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
