import XCTest
import SwiftData
@testable import workload_management

/// The widget snapshot codec + store contract.
///
/// Two of these tests are FENCES, not behavior checks:
/// - `test_compositeOnly_noRawSignalFieldNames` — the on-device raw-data law extends to
///   the App Group container; the snapshot may carry composites only.
/// - `test_zoneKeys_matchEnumRawValues` — the widget extension maps zone keys to colors
///   with string literals (it does not compile `Enums.swift`); this pins the contract
///   so an enum rename cannot silently un-color the widgets.
@MainActor
final class WidgetSnapshotTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "WidgetSnapshotTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Codec

    private func makeFullSnapshot() -> WidgetSnapshot {
        // Whole-second dates: the ISO-8601 codec truncates sub-second precision, so
        // fractional inputs would fail the round-trip equality this test is about.
        let day = Date(timeIntervalSince1970: 1_756_500_000)
        return WidgetSnapshot(
            schemaVersion: WidgetSnapshot.currentSchemaVersion,
            generatedAt: Date(timeIntervalSince1970: 1_756_540_800),
            readinessScore: 82,
            readinessZoneKey: "green",
            readinessZoneLabel: "Go",
            verdictLine: "Recovered and ready. Execute today's plan as written.",
            acwr: 1.08,
            acwrZoneKey: "optimal",
            acwrZoneLabel: "Load Steady",
            dailyLoads: (0..<7).map {
                WidgetSnapshot.DailyLoad(
                    day: day.addingTimeInterval(TimeInterval($0) * 86_400),
                    load: Double($0) * 50
                )
            }
        )
    }

    func test_roundTrip_preservesEveryField() throws {
        let original = makeFullSnapshot()
        let decoded = try WidgetSnapshot.decoded(from: original.encoded())
        XCTAssertEqual(decoded, original)
    }

    func test_decode_ignoresUnknownFields() throws {
        // A NEWER writer may add fields; this binary must render what it understands.
        var object = try jsonObject(from: makeFullSnapshot().encoded())
        object["someFutureField"] = "ignored"
        object["anotherFutureField"] = 42
        let data = try JSONSerialization.data(withJSONObject: object)
        let decoded = try WidgetSnapshot.decoded(from: data)
        XCTAssertEqual(decoded.readinessScore, 82)
        XCTAssertEqual(decoded.dailyLoads.count, 7)
    }

    func test_decode_minimalSnapshot_defaultsMissingFields() throws {
        // An OLDER writer wrote fewer fields — everything except the version is optional.
        let json = #"{"schemaVersion":1}"#
        let decoded = try WidgetSnapshot.decoded(from: Data(json.utf8))
        XCTAssertNil(decoded.readinessScore)
        XCTAssertNil(decoded.verdictLine)
        XCTAssertNil(decoded.acwr)
        XCTAssertEqual(decoded.dailyLoads, [])
    }

    func test_encode_isDeterministic() throws {
        // Sorted keys: two encodes of the same snapshot are byte-identical, so a
        // no-change write cannot look like a change to anything diffing the container.
        let snapshot = makeFullSnapshot()
        XCTAssertEqual(try snapshot.encoded(), try snapshot.encoded())
    }

    // MARK: - Store

    func test_store_writeThenRead_roundTrips() {
        let snapshot = makeFullSnapshot()
        WidgetSnapshotStore.write(snapshot, to: defaults)
        XCTAssertEqual(WidgetSnapshotStore.read(from: defaults), snapshot)
    }

    func test_read_returnsNilWhenNothingStored() {
        XCTAssertNil(WidgetSnapshotStore.read(from: defaults))
    }

    func test_read_rejectsNewerSchemaVersion() {
        var snapshot = makeFullSnapshot()
        snapshot.schemaVersion = WidgetSnapshot.currentSchemaVersion + 1
        WidgetSnapshotStore.write(snapshot, to: defaults)
        // An old widget must not misrender fields whose meaning changed under it.
        XCTAssertNil(WidgetSnapshotStore.read(from: defaults))
    }

    func test_read_returnsNilOnCorruptData() {
        defaults.set(Data("not json".utf8), forKey: WidgetSnapshotStore.snapshotKey)
        XCTAssertNil(WidgetSnapshotStore.read(from: defaults))
    }

    func test_merge_startsFromEmptySnapshot() {
        WidgetSnapshotStore.merge(in: defaults) { snapshot in
            snapshot.readinessScore = 61
        }
        let stored = WidgetSnapshotStore.read(from: defaults)
        XCTAssertEqual(stored?.readinessScore, 61)
        XCTAssertEqual(stored?.schemaVersion, WidgetSnapshot.currentSchemaVersion)
    }

    func test_merge_preservesTheOtherHalf() {
        // The recovery pipeline writes readiness; the workout pipeline writes load.
        // Neither may clobber the other's fields.
        WidgetSnapshotStore.merge(in: defaults) { snapshot in
            snapshot.readinessScore = 74
            snapshot.readinessZoneKey = "green"
            snapshot.verdictLine = "Execute today's plan."
        }
        WidgetSnapshotStore.merge(in: defaults) { snapshot in
            snapshot.acwr = 1.21
            snapshot.acwrZoneKey = "optimal"
        }
        let stored = WidgetSnapshotStore.read(from: defaults)
        XCTAssertEqual(stored?.readinessScore, 74)
        XCTAssertEqual(stored?.verdictLine, "Execute today's plan.")
        XCTAssertEqual(stored?.acwr, 1.21)
        XCTAssertEqual(stored?.acwrZoneKey, "optimal")
    }

    func test_merge_stampsGeneratedAt() {
        let before = Date.now.addingTimeInterval(-1)
        WidgetSnapshotStore.merge(in: defaults) { $0.readinessScore = 50 }
        let stored = WidgetSnapshotStore.read(from: defaults)
        XCTAssertNotNil(stored)
        XCTAssertGreaterThan(stored!.generatedAt, before)
    }

    // MARK: - Fences

    func test_compositeOnly_noRawSignalFieldNames() throws {
        // The App Group container is OFF-STORE territory for raw HealthKit data, same as
        // sync. Scores, zones, verdict text and training loads are composites; a field
        // whose name matches a raw signal is a law violation regardless of intent.
        let forbiddenFragments = [
            "hrv", "sdnn", "restingheart", "rhr", "sleep",
            "temperature", "bodytemp", "vo2", "heartrate", "respiratory"
        ]
        let mirrorLabels = Mirror(reflecting: makeFullSnapshot()).children.compactMap(\.label)
        let jsonKeys = try jsonObject(from: makeFullSnapshot().encoded()).keys.map { $0 }
        for name in (mirrorLabels + jsonKeys) {
            let lowered = name.lowercased()
            for fragment in forbiddenFragments {
                XCTAssertFalse(
                    lowered.contains(fragment),
                    "WidgetSnapshot field '\(name)' matches raw-signal fragment '\(fragment)' — composites only in the App Group container"
                )
            }
        }
    }

    func test_zoneKeys_matchEnumRawValues() {
        // The widget extension's WidgetZonePalette maps these strings to zone colors
        // without compiling Enums.swift. If a raw value changes, this fails HERE
        // instead of the widgets silently falling back to text3.
        XCTAssertEqual(RecoveryZone.green.rawValue, "green")
        XCTAssertEqual(RecoveryZone.yellow.rawValue, "yellow")
        XCTAssertEqual(RecoveryZone.red.rawValue, "red")
        XCTAssertEqual(ACWRZone.undertrained.rawValue, "undertrained")
        XCTAssertEqual(ACWRZone.optimal.rawValue, "optimal")
        XCTAssertEqual(ACWRZone.caution.rawValue, "caution")
        XCTAssertEqual(ACWRZone.danger.rawValue, "danger")
        XCTAssertEqual(ACWRZone.noData.rawValue, "noData")
    }

    // MARK: - Writer helpers (pure parts only — no App Group in the test host)

    func test_dailyLoadSeries_lengthAndOrder() throws {
        // In-memory container: the series builder must produce a CONTIGUOUS 7-day
        // window ending today, zeros for rest days, day totals for session days.
        let context = try makeContext()
        let athlete = Athlete(displayName: "Test")
        context.insert(athlete)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        // Two sessions on the same day (they must SUM), one three days ago.
        // `trainingStress` is set directly — the sRPE derivation is WorkoutSession's
        // concern, not this series builder's.
        let sessionA = WorkoutSession(sessionDate: today)
        sessionA.trainingStress = 300
        let sessionB = WorkoutSession(sessionDate: today)
        sessionB.trainingStress = 120
        let sessionC = WorkoutSession(sessionDate: calendar.date(byAdding: .day, value: -3, to: today)!)
        sessionC.trainingStress = 250
        for session in [sessionA, sessionB, sessionC] {
            session.athlete = athlete
            context.insert(session)
        }
        try context.save()

        let series = WidgetSnapshotWriter.dailyLoadSeries(modelContext: context, athlete: athlete)

        XCTAssertEqual(series.count, WidgetSnapshotWriter.loadSeriesDays)
        XCTAssertEqual(series.last?.day, today)
        for (earlier, later) in zip(series, series.dropFirst()) {
            XCTAssertLessThan(earlier.day, later.day)
        }
        XCTAssertEqual(series.last?.load, sessionA.trainingStress + sessionB.trainingStress)
        XCTAssertEqual(series[series.count - 4].load, sessionC.trainingStress)
        XCTAssertEqual(series[series.count - 2].load, 0, "rest days are honest zeros")
    }

    // MARK: - Helpers

    private func jsonObject(from data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// The full related-model schema, per the `RecoveryPipelineTests` pattern — a
    /// partial schema aborts SwiftData at container creation (Athlete's relationship
    /// graph pulls the rest in).
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Athlete.self,
            WorkoutSession.self,
            ExerciseEntry.self,
            SetRecord.self,
            WorkloadSnapshot.self,
            RecoverySnapshot.self,
            WellnessCheckIn.self,
            PersonalRecord.self,
            BaselineState.self,
            SleepShadowNight.self,
            RecoveryShadowDay.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }
}
