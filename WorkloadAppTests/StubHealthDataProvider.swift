import Foundation
@testable import workload_management

/// A `HealthDataProviding` whose answers the test chooses.
///
/// The pipeline tests used to pass a real `HealthKitService`, so they queried the actual
/// HealthKit store inside the test host. On an empty simulator that query sometimes THREW
/// and sometimes returned an empty result, and which one happened depended on how far the
/// host app's own dashboard had progressed — pure scheduling. `VerdictSurfaceActivationTests`
/// passed only in the throwing case; in the empty case the pipeline's authoritative
/// today-write cleared the seeded signals and the verdict correctly deferred. The failure
/// only ever surfaced when another suite ran first in the same clone (pair board
/// C-v171g-002).
///
/// Two ready-made shapes cover almost every test:
///
/// - `.silent()` — HealthKit is unavailable. The pipeline must not read the body at all, so
///   whatever the test seeded into the store is what the pipeline sees. This is the default
///   and the right choice unless a test is specifically about a HealthKit reading.
/// - `.reporting(...)` — HealthKit is available and returns exactly these values.
@MainActor
final class StubHealthDataProvider: HealthDataProviding {

    var isAvailable: Bool
    var hasRequestedAccess: Bool
    var isAuthorized: Bool { hasRequestedAccess }
    var connectionState: HealthKitConnectionState {
        guard hasRequestedAccess else { return .notRequested }
        return observedData ? .connected : .requestedNoData
    }

    var hrvHistory: [(date: Date, value: Double)] = []
    var restingHRHistory: [(date: Date, value: Double)] = []
    var sleepDetail: HealthKitService.LastNightSleepDetail?
    var bodyTemp: Double?
    var vo2Max: Double?
    var bodyMass: (kilograms: Double, date: Date)?
    var respiratoryRate: Double?
    var activeEnergyByDay: [Date: Double] = [:]

    /// Set when a fetch is asked to fail, so a test can exercise the error path explicitly
    /// instead of relying on an empty simulator to throw for it.
    var fetchError: Error?

    private(set) var observedData = false
    private(set) var fetchCount = 0

    init(isAvailable: Bool, hasRequestedAccess: Bool) {
        self.isAvailable = isAvailable
        self.hasRequestedAccess = hasRequestedAccess
    }

    /// HealthKit is unavailable — the pipeline reads nothing from the body.
    static func silent() -> StubHealthDataProvider {
        StubHealthDataProvider(isAvailable: false, hasRequestedAccess: false)
    }

    /// HealthKit is available and reports exactly what is passed here.
    static func reporting(
        hrv: [(date: Date, value: Double)] = [],
        restingHR: [(date: Date, value: Double)] = [],
        sleep: HealthKitService.LastNightSleepDetail? = nil,
        bodyTemp: Double? = nil,
        vo2Max: Double? = nil,
        bodyMass: (kilograms: Double, date: Date)? = nil,
        respiratoryRate: Double? = nil,
        activeEnergyByDay: [Date: Double] = [:]
    ) -> StubHealthDataProvider {
        let stub = StubHealthDataProvider(isAvailable: true, hasRequestedAccess: true)
        stub.hrvHistory = hrv
        stub.restingHRHistory = restingHR
        stub.sleepDetail = sleep
        stub.bodyTemp = bodyTemp
        stub.vo2Max = vo2Max
        stub.bodyMass = bodyMass
        stub.respiratoryRate = respiratoryRate
        stub.activeEnergyByDay = activeEnergyByDay
        return stub
    }

    func updateObservedData(_ present: Bool) {
        if present { observedData = true }
    }

    func fetchHRVHistory(days: Int) async throws -> [(date: Date, value: Double)] {
        try record()
        return hrvHistory
    }

    func fetchRestingHRHistory(days: Int) async throws -> [(date: Date, value: Double)] {
        try record()
        return restingHRHistory
    }

    func fetchLastNightSleepDetail() async throws -> HealthKitService.LastNightSleepDetail? {
        try record()
        return sleepDetail
    }

    func fetchLatestBodyTemp() async throws -> Double? {
        try record()
        return bodyTemp
    }

    func fetchLatestVO2Max() async throws -> Double? {
        try record()
        return vo2Max
    }

    func fetchLatestBodyMass() async throws -> (kilograms: Double, date: Date)? {
        try record()
        return bodyMass
    }

    func fetchOvernightRespiratoryRate() async throws -> Double? {
        try record()
        return respiratoryRate
    }

    func fetchDailyActiveEnergyByDay(days: Int) async throws -> [Date: Double] {
        try record()
        return activeEnergyByDay
    }

    private func record() throws {
        fetchCount += 1
        if let fetchError { throw fetchError }
    }
}
