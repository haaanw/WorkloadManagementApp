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

/// Coarse connection state for HealthKit-dependent UI.
///
/// Apple does NOT report READ authorization via `authorizationStatus(for:)`, so we can never
/// prove the user granted (or denied) read access. We can only know whether we have *asked*
/// (`hasRequestedAccess`) and whether reads currently *return data*. These three states are
/// what the UI needs to route between a connect CTA, a benign "no recent data" message, and
/// the normal data view.
enum HealthKitConnectionState: Equatable {
    /// Authorization was never requested → show the "Connect Apple Health" CTA.
    case notRequested
    /// Requested, but no recent samples are visible. Could be a brand-new account with no data
    /// yet, or revoked permissions — we cannot distinguish, so this is NOT an error.
    case requestedNoData
    /// Reads are returning data → normal UI.
    case connected
}

/// Service for reading health and fitness data from HealthKit.
/// All wearable data (Apple Watch, Whoop, Oura, Garmin) flows through HealthKit
/// as the unified API when their companion apps are installed.
@MainActor
@Observable
final class HealthKitService {
    private let store = HKHealthStore()

    /// UserDefaults key persisting that we have completed an authorization request at least once.
    /// NOTE: "requested" ≠ "read-granted". Apple never exposes read-grant status, so this only
    /// records that the system permission sheet was shown and dismissed.
    private static let hasRequestedKey = "hasRequestedHealthKitAccess"

    /// True once the user has been through `requestAuthorization()` (persisted across launches).
    /// Survives cold launch — this is what fixes the "connect CTA every launch" bug.
    private(set) var hasRequestedAccess: Bool {
        didSet { UserDefaults.standard.set(hasRequestedAccess, forKey: Self.hasRequestedKey) }
    }

    /// Whether the most recent authoritative read cycle returned data.
    /// Drives the distinction between `.requestedNoData` and `.connected`.
    ///
    /// This reflects the LATEST full fetch outcome (see `updateObservedData(_:)`) rather than a
    /// one-way session latch, so a user who had data and then revokes Health access in Settings
    /// correctly falls back to `.requestedNoData` ("connected — no recent data") on the next
    /// recovery run instead of being stuck on a stale `.connected`. The persisted
    /// `hasRequestedAccess` flag stays sticky regardless, so we never regress to the connect CTA.
    private(set) var hasObservedData = false

    /// Legacy alias kept for read sites that just need "should we attempt reads / treat as connected".
    /// Now backed by the persisted request flag instead of in-memory-only session state, so it no
    /// longer resets to false on cold launch.
    var isAuthorized: Bool { hasRequestedAccess }

    /// Coarse state for HealthKit-dependent UI surfaces.
    var connectionState: HealthKitConnectionState {
        guard hasRequestedAccess else { return .notRequested }
        return hasObservedData ? .connected : .requestedNoData
    }

    init() {
        self.hasRequestedAccess = UserDefaults.standard.bool(forKey: Self.hasRequestedKey)
    }

    /// Record that a live read returned data (called by the pipeline after a successful fetch).
    /// Idempotent; only ever sets the flag true (empty reads must not clear it — see probe rules).
    func noteObservedData() {
        hasObservedData = true
    }

    /// Update the "currently has data" signal from a COMPLETE authoritative read cycle.
    ///
    /// Unlike `noteObservedData()` (one-way latch, used by the best-effort migration probe which
    /// must never flip the flag to false), this is called by `RecoveryPipeline` after it has
    /// attempted ALL of its HealthKit reads for the run. Passing `false` here means the full read
    /// cycle returned nothing — which legitimately downgrades a previously-`.connected` user to
    /// `.requestedNoData` when they've revoked access (or genuinely have no recent samples).
    /// The persisted `hasRequestedAccess` flag is untouched, so the connect CTA never reappears.
    func updateObservedData(_ present: Bool) {
        hasObservedData = present
    }

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

    /// Request read-only authorization for all required data types.
    /// Persists `hasRequestedAccess` so subsequent cold launches don't re-show the connect CTA.
    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        hasRequestedAccess = true
    }

    /// Non-blocking migration / liveness probe.
    ///
    /// Run AFTER authenticated UI appears (never on the launch critical path). Performs a single
    /// lightweight recent-sample read. If any data returns:
    ///  - sets `hasObservedData = true` → state becomes `.connected`
    ///  - persists `hasRequestedAccess = true` to migrate legacy v1.3 users who granted Health
    ///    access before the persisted flag existed.
    ///
    /// Empty reads are treated as UNKNOWN: we never flip a flag to false here. "No samples" cannot
    /// prove denial (HK may simply have no data yet), and a revoked-permission user keeps their
    /// persisted `hasRequestedAccess` so the UI shows "no recent data", not the connect CTA.
    /// Skips under SCREENSHOT_MODE.
    func runMigrationProbe() async {
        guard isAvailable else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("SCREENSHOT_MODE") { return }
        #endif

        // Reuse existing fetch helpers; any one returning a value is enough to confirm liveness.
        let hrv = try? await fetchLatestHRVWithDate()
        let rhr = (hrv == nil) ? (try? await fetchLatestRestingHRWithDate()) : nil
        let sleep = (hrv == nil && rhr == nil) ? (try? await fetchLastNightSleepWithDate()) : nil

        if hrv != nil || rhr != nil || sleep != nil {
            hasObservedData = true
            hasRequestedAccess = true   // migrate legacy granters
        }
        // else: UNKNOWN — leave flags untouched (do not flip to false).
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

    /// Fetch resting heart rate readings for the past N days.
    ///
    /// Additive mirror of `fetchHRVHistory(days:)` so RHR day-buckets uniformly with HRV via
    /// `DayBucketer` (Phase 26 open-question #1). Reuses the shared `fetchSamples(type:days:)`
    /// helper and the bpm unit already used by `fetchLatestRestingHRWithDate`. Does NOT alter
    /// any existing fetch — the live recovery path's HealthKit reads are unchanged.
    func fetchRestingHRHistory(days: Int) async throws -> [(date: Date, value: Double)] {
        let type = HKQuantityType(.restingHeartRate)
        let samples = try await fetchSamples(type: type, days: days)
        return samples.map { sample in
            (date: sample.startDate,
             value: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
        }
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

    // MARK: - Sleep stages (sleep v2, Phase S2)

    /// One night's per-stage sleep detail, reduced to scalars for the sleep-v2 shadow path
    /// (research-sleep-score.md §3). **Raw stage data never leaves the device** — this value
    /// flows only into `BaselineState`'s local sleep-v2 carrier and the engine input; it has
    /// no Codable conformance and must never appear in `SyncService`.
    ///
    /// All scalars describe **one session**: the most recent gap-clustered session of the
    /// dominant source (H-25) — never the whole fetch window, which can span two nights
    /// plus naps when the pipeline runs late.
    struct LastNightSleepDetail {
        /// Total sleep minutes = deep + REM + core + unspecified (dominant source, chosen
        /// session only; per-stage intervals are unioned before summing so overlapping
        /// same-source samples never double-count).
        let tstMinutes: Double
        /// Deep minutes; nil when the dominant source wrote no staged samples.
        let deepMinutes: Double?
        /// REM minutes; nil when the dominant source wrote no staged samples.
        let remMinutes: Double?
        /// Core (light) minutes; nil when unstaged.
        let coreMinutes: Double?
        /// Awake-after-onset minutes; nil when the source reports no awake samples and
        /// does not stage (an unstaged source's wakings are simply unknown).
        let awakeMinutes: Double?
        /// The opportunity window in minutes: the dominant source's explicit `inBed`
        /// samples overlapping the chosen session when present, else the span of the
        /// session's asleep+awake samples (H-24).
        let inBedMinutes: Double?
        /// First asleep sample start of the chosen session (dominant source).
        let sessionStart: Date
        /// Last asleep sample end of the chosen session (dominant source).
        let sessionEnd: Date
        /// Bundle id of the dominant source — the one writing the most asleep samples
        /// (ties broken by asleep minutes, then by the bundle id string itself so the
        /// pick is deterministic — a nondeterministic flip would trigger a full §4
        /// source reset).
        let dominantSourceID: String?
    }

    /// Fetch last night's per-stage sleep detail for the sleep-v2 shadow fold.
    ///
    /// Same window and query pattern as `fetchLastNightSleep()` (start of yesterday → now,
    /// `HKSampleQueryDescriptor`), but:
    /// - samples are grouped by writing source, and ONLY the dominant source's samples are
    ///   aggregated — mixing sources double-counts overlapping sessions (iPhone + Watch both
    ///   write) and breaks the same-source baseline discipline (H-04);
    /// - the dominant source's asleep samples are **clustered into sessions by gap** —
    ///   a gap > `SleepSessionMath.sessionGapMinutes` (90, H-25) starts a new session —
    ///   and only the MOST RECENT session is reduced. Without this, the up-to-~32 h window
    ///   merges two post-midnight nights (run at 08:00) and daytime naps into one "night"
    ///   with a garbage TST and midpoint;
    /// - per-stage minutes union their intervals before summing, so overlapping same-source
    ///   samples (re-binned or duplicated writes) never double-count;
    /// - `asleepUnspecified` counts toward TST (a stage-less source — the §3 Whoop/manual
    ///   case — must still produce a Tier-C/D night; the v1 fetch ignores it deliberately
    ///   and is left untouched);
    /// - per-stage minutes are nil, not 0, when the source did not stage.
    ///
    /// Returns nil when no asleep samples exist in the window (Tier E — no night).
    func fetchLastNightSleepDetail() async throws -> LastNightSleepDetail? {
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

        func stage(_ sample: HKCategorySample) -> HKCategoryValueSleepAnalysis? {
            HKCategoryValueSleepAnalysis(rawValue: sample.value)
        }
        func isAsleep(_ sample: HKCategorySample) -> Bool {
            switch stage(sample) {
            case .asleepCore, .asleepDeep, .asleepREM, .asleepUnspecified: return true
            default: return false
            }
        }

        let asleepSamples = samples.filter(isAsleep)
        guard !asleepSamples.isEmpty else { return nil }

        // Dominant source: most asleep samples; ties broken by total asleep seconds, then
        // by the bundle id string itself (F5) — the pick must be deterministic because a
        // flip triggers a full §4 source reset.
        var bySource: [String: (count: Int, seconds: Double)] = [:]
        for sample in asleepSamples {
            let id = sample.sourceRevision.source.bundleIdentifier
            var entry = bySource[id] ?? (0, 0)
            entry.count += 1
            entry.seconds += sample.endDate.timeIntervalSince(sample.startDate)
            bySource[id] = entry
        }
        let dominantID = bySource.max { lhs, rhs in
            (lhs.value.count, lhs.value.seconds, lhs.key) < (rhs.value.count, rhs.value.seconds, rhs.key)
        }?.key

        let dominantSamples = samples.filter {
            $0.sourceRevision.source.bundleIdentifier == dominantID
        }
        let dominantAsleep = dominantSamples.filter(isAsleep)
        guard !dominantAsleep.isEmpty else { return nil }

        // Session clustering (H-25): a gap > 90 min between the dominant source's asleep
        // samples starts a new session; only the MOST RECENT session is last night.
        let asleepIntervals = dominantAsleep.map { DateInterval(start: $0.startDate, end: $0.endDate) }
        let sessions = SleepSessionMath.sessionClusters(
            asleepIntervals,
            gapMinutes: SleepSessionMath.sessionGapMinutes
        )
        guard let session = sessions.last, let firstInterval = session.first else { return nil }
        let sessionStart = firstInterval.start
        let sessionEnd = session.map(\.end).max()!

        // A sample belongs to the chosen session by overlap with its asleep span. Earlier
        // sessions' samples end > 90 min before `sessionStart`, so they never overlap.
        func overlapsSession(_ sample: HKCategorySample) -> Bool {
            sample.startDate < sessionEnd && sample.endDate > sessionStart
        }

        // Per-stage minutes: union the stage's intervals before summing (F6) — same-source
        // overlapping samples (re-binned or duplicated writes) must count once.
        func minutes(of value: HKCategoryValueSleepAnalysis) -> Double {
            SleepSessionMath.unionMinutes(
                dominantSamples
                    .filter { stage($0) == value && overlapsSession($0) }
                    .map { DateInterval(start: $0.startDate, end: $0.endDate) }
            )
        }

        let deep = minutes(of: .asleepDeep)
        let rem = minutes(of: .asleepREM)
        let core = minutes(of: .asleepCore)
        let unspecified = minutes(of: .asleepUnspecified)
        let awake = minutes(of: .awake)
        let inBedSum = minutes(of: .inBed)

        let tst = deep + rem + core + unspecified
        guard tst > 0 else { return nil }
        let hasStages = (deep + rem + core) > 0

        // Opportunity window (H-24): explicit inBed samples (session-overlapping) when the
        // dominant source wrote them; else the first-to-last span of the session's
        // asleep+awake samples (a staged source's session span includes the wakings, which
        // is the honest in-bed window a watch gives us — Apple Watch stages but rarely
        // writes `inBed`; the iPhone's cross-source `inBed` is deliberately NOT borrowed).
        let sessionSamples = dominantSamples.filter { stage($0) != .inBed && overlapsSession($0) }
        let spanStart = sessionSamples.map(\.startDate).min() ?? sessionStart
        let spanEnd = sessionSamples.map(\.endDate).max() ?? sessionEnd
        let inBed: Double? = inBedSum > 0
            ? inBedSum
            : spanEnd.timeIntervalSince(spanStart) / 60.0

        return LastNightSleepDetail(
            tstMinutes: tst,
            deepMinutes: hasStages ? deep : nil,
            remMinutes: hasStages ? rem : nil,
            coreMinutes: hasStages ? core : nil,
            awakeMinutes: (hasStages || awake > 0) ? awake : nil,
            inBedMinutes: inBed,
            sessionStart: sessionStart,
            sessionEnd: sessionEnd,
            dominantSourceID: dominantID
        )
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

// MARK: - Sleep session interval math (sleep v2, Phase S2)

/// Pure interval arithmetic for `fetchLastNightSleepDetail` — file-level and nonisolated
/// (no HealthKit types) so the pure-math test suite can drive it directly, the
/// `SleepStateBuilder` discipline.
enum SleepSessionMath {

    /// H-25: a gap of MORE than 90 minutes between the dominant source's consecutive
    /// asleep samples starts a new sleep session (two nights and naps must never merge
    /// into one Night); a gap of exactly 90 minutes still bridges.
    static let sessionGapMinutes: Double = 90.0

    /// Cluster asleep-sample intervals into sessions. Intervals are sorted by start; a new
    /// session begins when an interval starts more than `gapMinutes` after the running
    /// end of the current session. Sessions are returned in chronological order — the
    /// caller takes `.last` as the most recent (last night).
    static func sessionClusters(
        _ intervals: [DateInterval],
        gapMinutes: Double
    ) -> [[DateInterval]] {
        guard !intervals.isEmpty else { return [] }
        let sorted = intervals.sorted { $0.start < $1.start }
        var clusters: [[DateInterval]] = [[sorted[0]]]
        var runningEnd = sorted[0].end
        for interval in sorted.dropFirst() {
            if interval.start.timeIntervalSince(runningEnd) > gapMinutes * 60.0 {
                clusters.append([interval])
                runningEnd = interval.end
            } else {
                clusters[clusters.count - 1].append(interval)
                runningEnd = max(runningEnd, interval.end)
            }
        }
        return clusters
    }

    /// Total minutes covered by the UNION of the intervals (F6): same-source overlapping
    /// samples (re-binned or duplicated writes) count each minute once, never twice.
    static func unionMinutes(_ intervals: [DateInterval]) -> Double {
        guard !intervals.isEmpty else { return 0 }
        let sorted = intervals.sorted { $0.start < $1.start }
        var total: TimeInterval = 0
        var currentStart = sorted[0].start
        var currentEnd = sorted[0].end
        for interval in sorted.dropFirst() {
            if interval.start <= currentEnd {
                currentEnd = max(currentEnd, interval.end)
            } else {
                total += currentEnd.timeIntervalSince(currentStart)
                currentStart = interval.start
                currentEnd = interval.end
            }
        }
        total += currentEnd.timeIntervalSince(currentStart)
        return total / 60.0
    }
}
