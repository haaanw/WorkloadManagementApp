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

/// Everything the recovery pipeline and its view models read from the body.
///
/// This exists so a test can decide what the body reported (v1.7.2 codebase audit). Before
/// it, `RecoveryPipeline.run` took the concrete `HealthKitService` and therefore queried
/// the real HealthKit store inside the test host — where a query on an empty simulator
/// sometimes THREW and sometimes returned an empty result, depending on how far the host
/// app's own dashboard had progressed. `VerdictSurfaceActivationTests` passed only in the
/// throwing case: in the empty case the pipeline's authoritative today-write cleared the
/// seeded signals and the honest-confidence gate correctly deferred. The test was patched
/// to re-assert its seed values; the seam is the real fix (pair board C-v171g-002).
///
/// The protocol is exactly the surface those callers use — no more. It is not an attempt
/// to abstract HealthKit.
@MainActor
protocol HealthDataProviding: AnyObject {
    var isAvailable: Bool { get }
    var hasRequestedAccess: Bool { get }
    var isAuthorized: Bool { get }
    var connectionState: HealthKitConnectionState { get }

    func updateObservedData(_ present: Bool)

    func fetchHRVHistory(days: Int) async throws -> [(date: Date, value: Double)]
    func fetchRestingHRHistory(days: Int) async throws -> [(date: Date, value: Double)]
    func fetchLastNightSleepDetail() async throws -> HealthKitService.LastNightSleepDetail?
    func fetchLatestBodyTemp() async throws -> Double?
    func fetchLatestVO2Max() async throws -> Double?
    func fetchOvernightRespiratoryRate() async throws -> Double?
    func fetchDailyActiveEnergyByDay(days: Int) async throws -> [Date: Double]
}

/// Service for reading health and fitness data from HealthKit.
/// All wearable data (Apple Watch, Whoop, Oura, Garmin) flows through HealthKit
/// as the unified API when their companion apps are installed.
@MainActor
@Observable
final class HealthKitService: HealthDataProviding {
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

    /// Update the "currently has data" signal from a COMPLETE authoritative read cycle.
    ///
    /// Called by `RecoveryPipeline` after it has attempted ALL of its HealthKit reads for the
    /// run — never from a single best-effort read. Passing `false` here means the full read
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
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.vo2Max),
            HKQuantityType(.bodyTemperature),
            // Read purely as a HELD-OUT validation outcome (v1.7.1): overnight respiratory
            // rate is a recognised recovery/illness marker and is deliberately NOT an input to
            // any score, which is exactly what makes it usable as evidence.
            HKQuantityType(.respiratoryRate),
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
        /// The dominant source's NON-main clustered sessions in the fetch window (each
        /// reduced to start / end / unioned asleep minutes) — the H-35 nap candidates
        /// (Phase S3, closing H-33). Which of them count as naps is decided by the pure
        /// `SleepStateBuilder.napMinutes(candidates:mainSessionStart:lastSleepEnd:)`, not
        /// here.
        let napCandidates: [SleepStateBuilder.NapCandidate]
    }

    /// Fetch last night's per-stage sleep detail for the sleep-v2 shadow fold.
    ///
    /// Window: start of yesterday → now, `HKSampleQueryDescriptor`. Reduction rules:
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
    ///   case — must still produce a Tier-C/D night);
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
        // samples starts a new session.
        let asleepIntervals = dominantAsleep.map { DateInterval(start: $0.startDate, end: $0.endDate) }
        let sessions = SleepSessionMath.sessionClusters(
            asleepIntervals,
            gapMinutes: SleepSessionMath.sessionGapMinutes
        )

        // Main-session pick (v1.7.1): plain `.last` inverted nap and night — an afternoon
        // nap is the most recent cluster, so it became "last night" and the real night was
        // demoted to a nap candidate, cratering the live sleep number and score. The night
        // is the LATEST cluster with at least `nightMinimumMinutes` of unioned sleep; when
        // no cluster reaches the floor (a brutally short night), the largest cluster
        // stands in. `.last` among qualifiers still wins so a late run never resurrects
        // the PREVIOUS night over the most recent one.
        let unionByCluster = sessions.map { SleepSessionMath.unionMinutes($0) }
        let chosenIndex: Int
        if let nightIndex = sessions.indices.last(where: {
            unionByCluster[$0] >= SleepSessionMath.nightMinimumMinutes
        }) {
            chosenIndex = nightIndex
        } else if let largestIndex = unionByCluster.indices.max(by: {
            unionByCluster[$0] < unionByCluster[$1]
        }) {
            chosenIndex = largestIndex
        } else {
            return nil
        }
        let session = sessions[chosenIndex]
        guard let firstInterval = session.first else { return nil }
        let sessionStart = firstInterval.start
        let sessionEnd = session.map(\.end).max()!

        // Nap candidates (H-35): every clustered session EXCEPT the chosen main one —
        // before OR after it; `SleepStateBuilder.napMinutes` itself bounds candidates to
        // the [lastSleepEnd, mainSessionStart] window, so a post-night nap passed here is
        // simply ignored until tomorrow's fold. The nap selection rule stays in
        // `SleepStateBuilder.napMinutes` (pure, testable) — this fetch only reports what
        // the window contained.
        let napCandidates: [SleepStateBuilder.NapCandidate] = sessions.indices
            .filter { $0 != chosenIndex }
            .compactMap { index in
                let cluster = sessions[index]
                guard let first = cluster.first, let end = cluster.map(\.end).max() else {
                    return nil
                }
                return SleepStateBuilder.NapCandidate(
                    start: first.start,
                    end: end,
                    asleepMinutes: unionByCluster[index]
                )
            }

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
            dominantSourceID: dominantID,
            napCandidates: napCandidates
        )
    }

    // MARK: - Active energy (sleep v2, Phase S3 — H-37)

    /// Daily `activeEnergyBurned` sums (kilocalories) for the trailing `days` days, keyed by
    /// start-of-day. The `priorDayActiveEnergyZ` input (H-37, closing H-33): §9.2 names
    /// active energy as the load signal that catches an unlogged tournament day.
    ///
    /// Read-only, and the type is ALREADY in `readTypes` (`.activeEnergyBurned`) — no new
    /// permission scope. Uses a statistics-collection descriptor (daily `.cumulativeSum`
    /// buckets computed by HealthKit) rather than fetching thousands of raw samples to sum
    /// client-side. Days with no samples are simply ABSENT from the dictionary — the caller
    /// must not read absence as zero (a watch left on the charger is missing data, not a
    /// rest day).
    func fetchDailyActiveEnergyByDay(days: Int) async throws -> [Date: Double] {
        let calendar = Calendar.current
        let now = Date.now
        let anchor = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -days, to: anchor) else {
            return [:]
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: now,
            options: .strictStartDate
        )
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(
                type: HKQuantityType(.activeEnergyBurned),
                predicate: predicate
            ),
            options: .cumulativeSum,
            anchorDate: anchor,
            intervalComponents: DateComponents(day: 1)
        )

        let collection = try await descriptor.result(for: store)
        var byDay: [Date: Double] = [:]
        collection.enumerateStatistics(from: start, to: now) { statistics, _ in
            if let sum = statistics.sumQuantity() {
                byDay[calendar.startOfDay(for: statistics.startDate)] =
                    sum.doubleValue(for: .kilocalorie())
            }
        }
        return byDay
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

    // MARK: - Respiratory rate (held-out validation outcome)

    /// Median overnight respiratory rate, in breaths per minute, for the night that ended
    /// today — or nil when the night produced no samples.
    ///
    /// **Read only as validation evidence.** No scoring engine consumes it, and that is the
    /// point: an outcome that is also an input cannot grade the thing it feeds. Median rather
    /// than mean because a single disturbed stretch should not move the night's figure.
    ///
    /// The window is the same overnight span the sleep reduction uses (yesterday 18:00 →
    /// now), which keeps a nap or a daytime measurement out of a "last night" number.
    func fetchOvernightRespiratoryRate() async throws -> Double? {
        let type = HKQuantityType(.respiratoryRate)
        let calendar = Calendar.current
        let now = Date.now
        let startOfToday = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .hour, value: -6, to: startOfToday) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: windowStart,
            end: now,
            options: .strictStartDate
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: store)
        let unit = HKUnit.count().unitDivided(by: .minute())
        let values = samples.map { $0.quantity.doubleValue(for: unit) }
        guard !values.isEmpty else { return nil }
        return BaselineEngine.median(values)
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

    /// Fetch last night's sleep duration with the session's end date.
    ///
    /// Delegates to `fetchLastNightSleepDetail()` so the LIVE sleep number rides the same
    /// dominant-source, session-clustered, interval-unioned reduction as the sleep-v2
    /// shadow. The previous implementation summed raw sample durations from every source
    /// across the whole ~24–48 h window — iPhone + Watch double-wrote the night and the
    /// prior night's post-midnight tail joined it (HAN dogfood 2026-08-05: app 12h 45m vs
    /// Health 5h 19m for the same night).
    func fetchLastNightSleepWithDate() async throws -> (value: Double, date: Date)? {
        guard let detail = try await fetchLastNightSleepDetail() else { return nil }
        return (detail.tstMinutes, detail.sessionEnd)
    }

    // MARK: - Sleep night history (v1.7.1 round 2)

    /// Per-night sleep history for the trend charts and the night detail page.
    ///
    /// The trend surfaces used to read persisted `RecoverySnapshot` rows, which rendered
    /// pre-fix inflated values (the 12h45m class, round-tripped through the server) and
    /// nothing for gaps in snapshot history — while HealthKit holds every night on-device.
    /// This is the sleep counterpart of the HRV chart's raw-fetch + `HRVDailyStats`
    /// reduction: one query, then the pure per-wake-day reduction in
    /// `SleepSessionMath.nightSummaries`, which applies the SAME rules as
    /// `fetchLastNightSleepDetail` (dominant source per window, 90-min gap clustering,
    /// 180-min night floor with largest-candidate stand-in, wake-day keying, unioned
    /// stage intervals). Persisted snapshots are untouched — no history rewrite.
    func fetchSleepNights(days: Int) async throws -> [SleepSessionMath.NightSummary] {
        let type = HKCategoryType(.sleepAnalysis)
        let calendar = Calendar.current
        let now = Date.now
        let startOfToday = calendar.startOfDay(for: now)
        // One extra day of margin so the OLDEST wake-day's night (which starts the
        // evening before) is not clipped by the query window.
        guard let queryStart = calendar.date(byAdding: .day, value: -(days + 1), to: startOfToday) else {
            return []
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: queryStart,
            end: now,
            options: .strictStartDate
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: store)

        let staged: [SleepSessionMath.StagedSample] = samples.compactMap { sample in
            let stage: SleepSessionMath.Stage?
            switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
            case .asleepCore: stage = .core
            case .asleepDeep: stage = .deep
            case .asleepREM: stage = .rem
            case .asleepUnspecified: stage = .unspecified
            case .awake: stage = .awake
            case .inBed: stage = .inBed
            default: stage = nil
            }
            guard let stage else { return nil }
            return SleepSessionMath.StagedSample(
                source: sample.sourceRevision.source.bundleIdentifier,
                stage: stage,
                interval: DateInterval(start: sample.startDate, end: sample.endDate)
            )
        }
        return SleepSessionMath.nightSummaries(
            samples: staged,
            days: days,
            now: now,
            calendar: calendar
        )
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

    /// Minimum unioned asleep minutes for a cluster to qualify as the main night (3 h).
    /// Below this every cluster is nap-shaped; the largest one then stands in so a
    /// brutally short night still produces a reading (v1.7.1 main-session pick).
    static let nightMinimumMinutes: Double = 180.0

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

    /// The UNION of the intervals as a merged interval list. `unionMinutes` gives only the
    /// total; awake-EPISODE counting (night detail page) needs the merged list itself.
    static func unionIntervals(_ intervals: [DateInterval]) -> [DateInterval] {
        guard !intervals.isEmpty else { return [] }
        let sorted = intervals.sorted { $0.start < $1.start }
        var merged: [DateInterval] = []
        var currentStart = sorted[0].start
        var currentEnd = sorted[0].end
        for interval in sorted.dropFirst() {
            if interval.start <= currentEnd {
                currentEnd = max(currentEnd, interval.end)
            } else {
                merged.append(DateInterval(start: currentStart, end: currentEnd))
                currentStart = interval.start
                currentEnd = interval.end
            }
        }
        merged.append(DateInterval(start: currentStart, end: currentEnd))
        return merged
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

// MARK: - Sleep night history reduction (v1.7.1 round 2)

/// Pure per-wake-day reduction over a multi-day sample window. Every rule here is the
/// single-night fetch's rule (`fetchLastNightSleepDetail`), applied per day — the two
/// paths must never disagree about what "a night" is, so the constants and the helpers
/// are shared, not copied.
extension SleepSessionMath {

    /// Stage of a source sample, HealthKit-agnostic so the reducer stays pure and the
    /// test suite can drive it with synthetic intervals.
    enum Stage: Equatable {
        case core, deep, rem, unspecified, awake, inBed

        var isAsleep: Bool {
            switch self {
            case .core, .deep, .rem, .unspecified: return true
            case .awake, .inBed: return false
            }
        }
    }

    /// One source-attributed staged interval — the pure input shape (no HealthKit types).
    struct StagedSample {
        let source: String
        let stage: Stage
        let interval: DateInterval
    }

    /// One merged stage interval inside the chosen session — the night timeline's mark.
    struct StageSegment: Identifiable {
        let stage: Stage
        let interval: DateInterval

        var id: String { "\(stage)-\(interval.start.timeIntervalSinceReferenceDate)" }
    }

    /// One reduced night, keyed to the WAKE day (the calendar day the main session ends —
    /// v1.7.1 wake-day keying). Per-stage minutes are nil, never 0, when the dominant
    /// source did not stage. Local-only display material; never appears in `SyncService`.
    struct NightSummary: Identifiable {
        let wakeDay: Date
        let tstMinutes: Double
        let deepMinutes: Double?
        let remMinutes: Double?
        let coreMinutes: Double?
        let awakeMinutes: Double?
        /// Count of merged awake episodes inside the session; nil when the source
        /// reports no awake samples and does not stage.
        let awakeEpisodes: Int?
        let inBedMinutes: Double?
        let sessionStart: Date
        let sessionEnd: Date
        let dominantSourceID: String?
        /// Merged per-stage intervals (chronological) for the night timeline. Contains
        /// `.unspecified` runs for stage-less sources so even a Tier-C night draws a
        /// single-row timeline.
        let segments: [StageSegment]

        var id: Date { wakeDay }
    }

    /// Reduce a sample window into per-night summaries for the trailing `days` calendar
    /// days, ascending by wake day. A day with no qualifying cluster is simply absent —
    /// never fabricated.
    static func nightSummaries(
        samples: [StagedSample],
        days: Int,
        now: Date,
        calendar: Calendar
    ) -> [NightSummary] {
        guard !samples.isEmpty, days > 0 else { return [] }
        let startOfToday = calendar.startOfDay(for: now)
        var result: [NightSummary] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let wakeDay = calendar.date(byAdding: .day, value: -offset, to: startOfToday),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: wakeDay),
                  let windowStart = calendar.date(byAdding: .day, value: -1, to: wakeDay)
            else { continue }
            let windowEnd = min(dayEnd, now)
            guard windowEnd > windowStart else { continue }
            if let night = nightForWakeDay(
                wakeDay: wakeDay,
                dayEnd: dayEnd,
                windowStart: windowStart,
                windowEnd: windowEnd,
                samples: samples
            ) {
                result.append(night)
            }
        }
        return result
    }

    /// The single-night reduction over one 48 h window, claiming only clusters that END
    /// within the wake day (so adjacent windows can never double-claim a night).
    private static func nightForWakeDay(
        wakeDay: Date,
        dayEnd: Date,
        windowStart: Date,
        windowEnd: Date,
        samples: [StagedSample]
    ) -> NightSummary? {
        // Window membership mirrors the live fetch's `.strictStartDate`: sample START
        // inside the window.
        let windowSamples = samples.filter {
            $0.interval.start >= windowStart && $0.interval.start < windowEnd
        }
        let asleep = windowSamples.filter { $0.stage.isAsleep }
        guard !asleep.isEmpty else { return nil }

        // Dominant source: most asleep samples; ties by asleep seconds, then by the id
        // string — the identical deterministic pick the live fetch makes (F5).
        var bySource: [String: (count: Int, seconds: Double)] = [:]
        for sample in asleep {
            var entry = bySource[sample.source] ?? (0, 0)
            entry.count += 1
            entry.seconds += sample.interval.duration
            bySource[sample.source] = entry
        }
        guard let dominantID = bySource.max(by: { lhs, rhs in
            (lhs.value.count, lhs.value.seconds, lhs.key) < (rhs.value.count, rhs.value.seconds, rhs.key)
        })?.key else { return nil }

        let dominant = windowSamples.filter { $0.source == dominantID }
        let dominantAsleep = dominant.filter { $0.stage.isAsleep }
        guard !dominantAsleep.isEmpty else { return nil }

        // H-25 clustering, then candidates = clusters ENDING within the wake day.
        let clusters = sessionClusters(dominantAsleep.map(\.interval), gapMinutes: sessionGapMinutes)
        let clusterEnds = clusters.map { $0.map(\.end).max()! }
        let candidates = clusters.indices.filter {
            clusterEnds[$0] >= wakeDay && clusterEnds[$0] < dayEnd
        }
        guard !candidates.isEmpty else { return nil }

        // v1.7.1 main-session pick: latest candidate with ≥180 unioned minutes; when no
        // candidate reaches the floor the largest stands in (a brutally short night still
        // produces a reading — same behavior the live number shows that morning).
        let unions = clusters.map { unionMinutes($0) }
        let chosenIndex: Int
        if let nightIndex = candidates.last(where: { unions[$0] >= nightMinimumMinutes }) {
            chosenIndex = nightIndex
        } else {
            chosenIndex = candidates.max { unions[$0] < unions[$1] }!
        }
        let session = clusters[chosenIndex]
        guard let sessionStart = session.first?.start,
              let sessionEnd = session.map(\.end).max() else { return nil }

        func overlapsSession(_ interval: DateInterval) -> Bool {
            interval.start < sessionEnd && interval.end > sessionStart
        }
        func stageIntervals(_ stage: Stage) -> [DateInterval] {
            dominant
                .filter { $0.stage == stage && overlapsSession($0.interval) }
                .map(\.interval)
        }
        func minutes(_ stage: Stage) -> Double {
            unionMinutes(stageIntervals(stage))
        }

        let deep = minutes(.deep)
        let rem = minutes(.rem)
        let core = minutes(.core)
        let unspecified = minutes(.unspecified)
        let awakeMerged = unionIntervals(stageIntervals(.awake))
        let awake = awakeMerged.reduce(0.0) { $0 + $1.duration / 60.0 }
        let inBedSum = minutes(.inBed)

        let tst = deep + rem + core + unspecified
        guard tst > 0 else { return nil }
        let hasStages = (deep + rem + core) > 0

        // Opportunity window (H-24): explicit inBed when the source wrote it, else the
        // session's asleep+awake span.
        let sessionSamples = dominant.filter { $0.stage != .inBed && overlapsSession($0.interval) }
        let spanStart = sessionSamples.map(\.interval.start).min() ?? sessionStart
        let spanEnd = sessionSamples.map(\.interval.end).max() ?? sessionEnd
        let inBed: Double? = inBedSum > 0
            ? inBedSum
            : spanEnd.timeIntervalSince(spanStart) / 60.0

        let timelineStages: [Stage] = [.deep, .core, .rem, .unspecified, .awake]
        let segments: [StageSegment] = timelineStages
            .flatMap { stage in
                unionIntervals(stageIntervals(stage)).map {
                    StageSegment(stage: stage, interval: $0)
                }
            }
            .sorted { $0.interval.start < $1.interval.start }

        return NightSummary(
            wakeDay: wakeDay,
            tstMinutes: tst,
            deepMinutes: hasStages ? deep : nil,
            remMinutes: hasStages ? rem : nil,
            coreMinutes: hasStages ? core : nil,
            awakeMinutes: (hasStages || awake > 0) ? awake : nil,
            awakeEpisodes: (hasStages || awake > 0) ? awakeMerged.count : nil,
            inBedMinutes: inBed,
            sessionStart: sessionStart,
            sessionEnd: sessionEnd,
            dominantSourceID: dominantID,
            segments: segments
        )
    }
}
