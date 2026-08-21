import XCTest
import SwiftData
@testable import workload_management

/// v1.7.2 codebase audit — the HealthKit test seam.
///
/// `RecoveryPipeline.run` took the concrete `HealthKitService`, so every pipeline test read
/// the test host's real HealthKit store. On an empty simulator that query sometimes threw
/// and sometimes returned an empty result, depending on how far the host app's own dashboard
/// had progressed. `VerdictSurfaceActivationTests` passed only in the throwing case — in the
/// empty case the pipeline's authoritative today-write cleared the seeded signals and the
/// honest-confidence gate correctly deferred. The failure surfaced only when another suite
/// ran first in the same clone (pair board C-v171g-002).
///
/// These tests pin the seam itself: what the pipeline reads is now a decision the test makes.
@MainActor
final class HealthDataSeamTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Athlete.self, WorkoutSession.self, ExerciseEntry.self, SetRecord.self,
            WorkloadSnapshot.self, RecoverySnapshot.self, WellnessCheckIn.self,
            PersonalRecord.self, BaselineState.self, SleepShadowNight.self,
            RecoveryShadowDay.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    private func makeAthlete(in context: ModelContext) -> Athlete {
        let athlete = Athlete(displayName: "Test", sportType: .lifting)
        context.insert(athlete)
        return athlete
    }

    /// A silent provider must not be read at all. This is what makes every other pipeline
    /// test deterministic: the store is the only source of truth.
    func test_silentProvider_isNeverRead() async throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)
        let health = StubHealthDataProvider.silent()

        _ = try await RecoveryPipeline.run(
            athlete: athlete, healthKitService: health, modelContext: context
        )

        XCTAssertEqual(health.fetchCount, 0,
                       "The pipeline read the body while HealthKit was reported unavailable")
    }

    /// A reporting provider's values reach the stored snapshot verbatim — the property the
    /// old tests could not rely on, because the host's store answered instead.
    func test_reportingProvider_valuesReachTheSnapshot() async throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        // A morning reading on each of the last four days, so the daily reduction has a
        // value for today and a baseline behind it.
        let mornings: [(date: Date, value: Double)] = (0..<4).compactMap { back in
            calendar.date(byAdding: .hour, value: 7, to: calendar.date(byAdding: .day, value: -back, to: today)!)
                .map { (date: $0, value: 60 + Double(back)) }
        }
        let health = StubHealthDataProvider.reporting(
            hrv: mornings,
            restingHR: mornings.map { (date: $0.date, value: 50) },
            bodyTemp: 36.4,
            vo2Max: 51.2
        )

        _ = try await RecoveryPipeline.run(
            athlete: athlete, healthKitService: health, modelContext: context
        )

        let snapshot = try XCTUnwrap(
            RecoveryRepository(modelContext: context).fetchTodaySnapshot(athlete: athlete)
        )
        XCTAssertEqual(try XCTUnwrap(snapshot.hrvSDNN), 60, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(snapshot.restingHR), 50, accuracy: 0.001)
        XCTAssertEqual(snapshot.bodyTemp, 36.4)
        XCTAssertEqual(snapshot.vo2Max, 51.2)
        XCTAssertGreaterThan(health.fetchCount, 0)
    }

    /// A failing read is now something a test states rather than something it inherits from
    /// an empty simulator. The pipeline must still produce a result.
    func test_failingProvider_stillProducesAResult() async throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)
        let health = StubHealthDataProvider.reporting()
        health.fetchError = URLError(.notConnectedToInternet)

        let result = try await RecoveryPipeline.run(
            athlete: athlete, healthKitService: health, modelContext: context
        )

        XCTAssertGreaterThan(result.score, 0, "A failed HealthKit read must not sink the pipeline")
    }

    /// Fence: no pipeline test may reach for the real service again, or the whole class of
    /// scheduling-dependent failures comes back.
    func testNoTestConstructsTheConcreteHealthService() throws {
        let testsDirectory = URL(fileURLWithPath: "\(#filePath)").deletingLastPathComponent()
        let files = try FileManager.default.contentsOfDirectory(at: testsDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty)

        // Assembled at runtime so this fence does not trip on its own source.
        let banned = "HealthKitService" + "()"
        for file in files {
            guard let source = try? String(contentsOf: file, encoding: .utf8) else { continue }
            XCTAssertFalse(
                source.contains(banned),
                "\(file.lastPathComponent) constructs the real HealthKit service — use StubHealthDataProvider"
            )
        }
    }
}
