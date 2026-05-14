import Foundation
import HealthKit

// MARK: - Staleness Detection

/// Tracks freshness of HealthKit data sources. Data older than 24h is considered stale.
struct HealthKitStaleness {
    let lastHRVDate: Date?
    let lastSleepDate: Date?
    let lastRHRDate: Date?

    var isHRVStale: Bool { isStale(lastHRVDate) }
    var isSleepStale: Bool { isStale(lastSleepDate) }
    var isRHRStale: Bool { isStale(lastRHRDate) }
    var hasAnyStaleness: Bool { isHRVStale || isSleepStale || isRHRStale }

    func daysAgo(_ date: Date?) -> Int? {
        guard let date, isStale(date) else { return nil }
        return Calendar.current.dateComponents([.day], from: date, to: .now).day
    }

    private func isStale(_ date: Date?) -> Bool {
        guard let date else { return true }
        return Date.now.timeIntervalSince(date) > 24 * 3600
    }
}

/// Service for reading health and fitness data from HealthKit.
/// All wearable data (Apple Watch, Whoop, Oura, Garmin) flows through HealthKit
/// as the unified API when their companion apps are installed.
@MainActor
@Observable
final class HealthKitService {
    private let store = HKHealthStore()
    private(set) var isAuthorized = false

    /// HealthKit data types we want to read
    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.stepCount),
            HKQuantityType(.vo2Max),
            HKQuantityType(.bodyTemperature),
            HKCategoryType(.sleepAnalysis),
            HKCategoryType(.menstrualFlow),
            HKCategoryType(.contraceptive),
            HKCategoryType(.pregnancy),
            HKCategoryType(.lactation),
            HKCategoryType(.irregularMenstrualCycles),
            HKCategoryType(.ovulationTestResult),
        ]
        // Apple sleeping wrist temperature (iOS 17+)
        if let wristTemp = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
            types.insert(wristTemp)
        }
        // HKWorkout type for auto-importing workouts
        types.insert(HKWorkoutType.workoutType())
        return types
    }

    /// Check if HealthKit is available on this device
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Request read-only authorization for all required data types
    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        isAuthorized = true
    }

    // MARK: - HRV

    /// Fetch the most recent HRV (SDNN) reading, typically from morning/sleep
    func fetchLatestHRV() async throws -> Double? {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let sample = try await fetchMostRecentSample(type: type)
        return sample?.quantity.doubleValue(for: .secondUnit(with: .milli))
    }

    /// Fetch HRV readings for the past N days
    func fetchHRVHistory(days: Int) async throws -> [(date: Date, value: Double)] {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let samples = try await fetchSamples(type: type, days: days)
        return samples.map { sample in
            (date: sample.startDate,
             value: sample.quantity.doubleValue(for: .secondUnit(with: .milli)))
        }
    }

    // MARK: - Resting Heart Rate

    /// Fetch the most recent resting heart rate
    func fetchLatestRestingHR() async throws -> Double? {
        let type = HKQuantityType(.restingHeartRate)
        let sample = try await fetchMostRecentSample(type: type)
        return sample?.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
    }

    // MARK: - Sleep

    /// Fetch last night's sleep duration in minutes
    func fetchLastNightSleep() async throws -> Double? {
        let type = HKCategoryType(.sleepAnalysis)
        let calendar = Calendar.current
        let now = Date.now
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfYesterday,
            end: now,
            options: .strictStartDate
        )

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )

        let samples = try await descriptor.result(for: store)

        // Filter for asleep categories (not inBed or awake)
        let asleepSamples = samples.filter { sample in
            let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            return value == .asleepCore || value == .asleepDeep || value == .asleepREM
        }

        guard !asleepSamples.isEmpty else { return nil }

        let totalSeconds = asleepSamples.reduce(0.0) { sum, sample in
            sum + sample.endDate.timeIntervalSince(sample.startDate)
        }
        return totalSeconds / 60.0
    }

    // MARK: - Workout Heart Rate (for TRIMP)

    /// Fetch heart rate samples during a specific time range (for TRIMP calculation)
    func fetchWorkoutHeartRates(start: Date, end: Date) async throws -> [(date: Date, bpm: Double)] {
        let type = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )

        let samples = try await descriptor.result(for: store)
        return samples.map { ($0.startDate, $0.quantity.doubleValue(for: bpmUnit)) }
    }

    /// Calculate TRIMP from HR samples during a workout
    func calculateTRIMP(start: Date, end: Date, maxHR: Int) async throws -> Double? {
        let hrSamples = try await fetchWorkoutHeartRates(start: start, end: end)
        guard !hrSamples.isEmpty else { return nil }

        // Bucket samples into 5 HR zones and sum durations
        var zoneDurations = [Double](repeating: 0, count: 5)

        for i in 0..<hrSamples.count {
            let zone = WorkloadCalculator.hrZone(heartRate: hrSamples[i].bpm, maxHR: maxHR)
            let duration: TimeInterval
            if i + 1 < hrSamples.count {
                duration = hrSamples[i + 1].date.timeIntervalSince(hrSamples[i].date)
            } else {
                duration = end.timeIntervalSince(hrSamples[i].date)
            }
            let minutes = duration / 60.0
            zoneDurations[zone - 1] += minutes
        }

        return WorkloadCalculator.trimp(zoneDurationsMinutes: zoneDurations)
    }

    // MARK: - Body Temperature

    /// Fetch latest body temperature reading (from Oura Ring or Apple Watch)
    func fetchLatestBodyTemp() async throws -> Double? {
        // Try sleeping wrist temperature first (Apple Watch)
        if let wristTempType = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
            let sample = try await fetchMostRecentSample(type: wristTempType)
            if let value = sample?.quantity.doubleValue(for: .degreeCelsius()) {
                return value
            }
        }
        // Fallback to general body temperature
        let type = HKQuantityType(.bodyTemperature)
        let sample = try await fetchMostRecentSample(type: type)
        return sample?.quantity.doubleValue(for: .degreeCelsius())
    }

    // MARK: - VO2 Max

    /// Fetch latest VO2 Max estimate
    func fetchLatestVO2Max() async throws -> Double? {
        let type = HKQuantityType(.vo2Max)
        let sample = try await fetchMostRecentSample(type: type)
        let unit = HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
        return sample?.quantity.doubleValue(for: unit)
    }

    // MARK: - Auto-Import Workouts

    /// Fetch recent workouts from HealthKit (logged in other apps)
    func fetchRecentWorkouts(days: Int = 7) async throws -> [HKWorkout] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: .now, options: .strictStartDate)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )

        return try await descriptor.result(for: store)
    }

    // MARK: - Staleness-Aware Fetches

    /// Fetch the most recent HRV (SDNN) with its sample date.
    func fetchLatestHRVWithDate() async throws -> (value: Double, date: Date)? {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        guard let sample = try await fetchMostRecentSample(type: type) else { return nil }
        return (sample.quantity.doubleValue(for: .secondUnit(with: .milli)), sample.startDate)
    }

    /// Fetch the most recent resting heart rate with its sample date.
    func fetchLatestRestingHRWithDate() async throws -> (value: Double, date: Date)? {
        let type = HKQuantityType(.restingHeartRate)
        guard let sample = try await fetchMostRecentSample(type: type) else { return nil }
        return (sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())), sample.startDate)
    }

    /// Fetch last night's sleep duration with the latest sample end date.
    func fetchLastNightSleepWithDate() async throws -> (value: Double, date: Date)? {
        let type = HKCategoryType(.sleepAnalysis)
        let calendar = Calendar.current
        let now = Date.now
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfYesterday,
            end: now,
            options: .strictStartDate
        )

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )

        let samples = try await descriptor.result(for: store)

        let asleepSamples = samples.filter { sample in
            let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            return value == .asleepCore || value == .asleepDeep || value == .asleepREM
        }

        guard !asleepSamples.isEmpty else { return nil }

        let totalSeconds = asleepSamples.reduce(0.0) { sum, sample in
            sum + sample.endDate.timeIntervalSince(sample.startDate)
        }
        let latestDate = asleepSamples.map(\.endDate).max() ?? now
        return (totalSeconds / 60.0, latestDate)
    }

    /// Convenience: fetch staleness state for all tracked metrics.
    func fetchStaleness() async -> HealthKitStaleness {
        let hrv = try? await fetchLatestHRVWithDate()
        let rhr = try? await fetchLatestRestingHRWithDate()
        let sleep = try? await fetchLastNightSleepWithDate()
        return HealthKitStaleness(lastHRVDate: hrv?.date, lastSleepDate: sleep?.date, lastRHRDate: rhr?.date)
    }

    // MARK: - Private Helpers

    private func fetchMostRecentSample(type: HKQuantityType) async throws -> HKQuantitySample? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )
        return try await descriptor.result(for: store).first
    }

    private func fetchSamples(type: HKQuantityType, days: Int) async throws -> [HKQuantitySample] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: .now, options: .strictStartDate)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        return try await descriptor.result(for: store)
    }
}
