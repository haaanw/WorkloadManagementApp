import XCTest
@testable import workload_management

/// The dedupe guard behind silent watch auto-import (v1.7.3, UAT round 1 · U4).
///
/// These are the tests that used to be a human looking at an "Add" row. HAN's ruling
/// removed that human, so every case they used to judge by eye has to be pinned here —
/// especially the two the retired point-match got wrong in opposite directions.
final class WatchWorkoutMatcherTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_757_000_000)  // fixed; never .now

    private func candidate(
        offsetMinutes: Double = 0,
        minutes: Double = 50,
        uuid: UUID = UUID()
    ) -> WatchWorkoutMatcher.Candidate {
        WatchWorkoutMatcher.Candidate(
            workoutUUID: uuid,
            start: base.addingTimeInterval(offsetMinutes * 60),
            durationSeconds: Int(minutes * 60)
        )
    }

    private func session(
        offsetMinutes: Double = 0,
        minutes: Double = 50,
        hkUUID: UUID? = nil
    ) -> WatchWorkoutMatcher.ExistingSession {
        WatchWorkoutMatcher.ExistingSession(
            healthKitWorkoutUUID: hkUUID,
            start: base.addingTimeInterval(offsetMinutes * 60),
            durationSeconds: Int(minutes * 60)
        )
    }

    // MARK: - The clean cases

    func test_noExistingSessions_logs() {
        XCTAssertEqual(WatchWorkoutMatcher.decide(candidate: candidate(), existing: []), .log)
    }

    func test_sameClockTime_isRefused() {
        let decision = WatchWorkoutMatcher.decide(
            candidate: candidate(),
            existing: [session()]
        )
        XCTAssertEqual(decision, .overlapsExistingSession)
    }

    func test_differentDay_logs() {
        let decision = WatchWorkoutMatcher.decide(
            candidate: candidate(),
            existing: [session(offsetMinutes: 24 * 60)]
        )
        XCTAssertEqual(decision, .log)
    }

    // MARK: - The two failures of the retired point match

    func test_watchStartedTenMinutesAfterTheAppSession_isStillRefused() {
        // The double-count case. The athlete opened the Tuwa sheet, warmed up, then
        // started the watch. The retired 5-minute start tolerance called these two
        // different sessions and logged the workout a second time — inflating ATL,
        // ACWR and the fatigue index for the next four weeks with no signal at all.
        let decision = WatchWorkoutMatcher.decide(
            candidate: candidate(offsetMinutes: 10, minutes: 40),
            existing: [session(minutes: 50)]
        )
        XCTAssertEqual(decision, .overlapsExistingSession)
    }

    func test_twoRealSessionsBeginningFourMinutesApart_bothSurvive() {
        // The silent-loss case, and the reason the guard cannot simply be a wider
        // tolerance. A four-minute sprint block starting four minutes after a lift
        // ENDS is a second session; the retired point match swallowed it.
        let lift = session(offsetMinutes: -50, minutes: 46)   // ends 4 min before base
        let decision = WatchWorkoutMatcher.decide(
            candidate: candidate(minutes: 6),
            existing: [lift]
        )
        XCTAssertEqual(decision, .log)
    }

    // MARK: - Idempotency

    func test_alreadyImportedUUID_isRefusedEvenAtADifferentTime() {
        let id = UUID()
        let decision = WatchWorkoutMatcher.decide(
            candidate: candidate(uuid: id),
            existing: [session(offsetMinutes: 24 * 60, hkUUID: id)]
        )
        XCTAssertEqual(decision, .alreadyImported)
    }

    func test_alreadyImportedWins_overTheDurationFloor() {
        // Order matters: an imported workout is settled regardless of length, and
        // reporting it as "too short" would misdescribe what happened.
        let id = UUID()
        let decision = WatchWorkoutMatcher.decide(
            candidate: candidate(minutes: 0.2, uuid: id),
            existing: [session(hkUUID: id)]
        )
        XCTAssertEqual(decision, .alreadyImported)
    }

    func test_aDifferentWatchWorkoutDoesNotSuppressThisOne() {
        // Two back-to-back watch workouts — a lift, then a court session — are two
        // sessions. Only the athlete's own hand-logged records suppress a candidate;
        // each imported one already owns its UUID key.
        let decision = WatchWorkoutMatcher.decide(
            candidate: candidate(offsetMinutes: 10, minutes: 40),
            existing: [session(minutes: 50, hkUUID: UUID())]
        )
        XCTAssertEqual(decision, .log)
    }

    // MARK: - Duration floor

    func test_underAMinute_isRefused() {
        let decision = WatchWorkoutMatcher.decide(
            candidate: candidate(minutes: 0.5),
            existing: []
        )
        XCTAssertEqual(decision, .belowDurationFloor)
    }

    func test_fourMinuteSession_isKept() {
        // The retired importer's floor was five minutes, which discarded real short
        // work. This is the case that regression would silently re-break.
        XCTAssertEqual(
            WatchWorkoutMatcher.decide(candidate: candidate(minutes: 4), existing: []),
            .log
        )
    }

    // MARK: - Overlap arithmetic

    func test_overlapIsMeasuredAgainstTheShorterInterval() {
        // A 20-minute watch workout recorded entirely inside a 60-minute logged
        // session is fully covered — and the athlete's longer record is the keeper.
        let fraction = WatchWorkoutMatcher.overlapFraction(
            candidate: candidate(offsetMinutes: 20, minutes: 20),
            session: session(minutes: 60)
        )
        XCTAssertEqual(fraction, 1.0, accuracy: 0.0001)
    }

    func test_touchingButNotOverlappingIntervals_scoreZero() {
        let fraction = WatchWorkoutMatcher.overlapFraction(
            candidate: candidate(offsetMinutes: 50, minutes: 30),
            session: session(minutes: 50)
        )
        XCTAssertEqual(fraction, 0)
    }

    func test_overlapJustUnderHalf_logs() {
        // 24 of 50 minutes shared = 0.48, under the floor.
        let decision = WatchWorkoutMatcher.decide(
            candidate: candidate(offsetMinutes: 26, minutes: 50),
            existing: [session(minutes: 50)]
        )
        XCTAssertEqual(decision, .log)
    }

    func test_overlapExactlyHalf_isRefused() {
        // 25 of 50 = the floor itself, which is inclusive.
        let decision = WatchWorkoutMatcher.decide(
            candidate: candidate(offsetMinutes: 25, minutes: 50),
            existing: [session(minutes: 50)]
        )
        XCTAssertEqual(decision, .overlapsExistingSession)
    }

    func test_zeroDurationSession_fallsBackToStartProximity() {
        // A hand-logged session that was never given a duration has no interval to
        // intersect, so start proximity is the only evidence available.
        XCTAssertEqual(
            WatchWorkoutMatcher.decide(
                candidate: candidate(offsetMinutes: 5),
                existing: [session(minutes: 0)]
            ),
            .overlapsExistingSession
        )
        XCTAssertEqual(
            WatchWorkoutMatcher.decide(
                candidate: candidate(offsetMinutes: 20),
                existing: [session(minutes: 0)]
            ),
            .log
        )
    }

    // MARK: - Effort → RPE

    func test_effortMapsOntoSessionRPEUnchanged() {
        // Both instruments are 1–10 category-ratio scales asking the same question
        // after the fact. Inventing a curve between them would bias the one
        // subjective input the whole load model rests on.
        for value in 1...10 {
            XCTAssertEqual(
                WatchWorkoutMatcher.sessionRPE(fromEffortScore: Double(value)),
                Double(value)
            )
        }
    }

    func test_effortRounds() {
        XCTAssertEqual(WatchWorkoutMatcher.sessionRPE(fromEffortScore: 7.4), 7)
        XCTAssertEqual(WatchWorkoutMatcher.sessionRPE(fromEffortScore: 7.6), 8)
    }

    func test_effortOutsideTheScaleIsClamped() {
        XCTAssertEqual(WatchWorkoutMatcher.sessionRPE(fromEffortScore: 0), 1)
        XCTAssertEqual(WatchWorkoutMatcher.sessionRPE(fromEffortScore: -4), 1)
        XCTAssertEqual(WatchWorkoutMatcher.sessionRPE(fromEffortScore: 14), 10)
    }
}

// MARK: - Source fences

/// The auto-import touches two laws at once — the HealthKit raw-data law and the
/// double-counting guard. Both are properties a green build cannot see, so they are
/// asserted against the source text.
final class WatchWorkoutImportFenceTests: XCTestCase {

    private func source(_ relativePath: String) throws -> String {
        // WorkloadAppTests/ sits beside WorkloadApp/ at the repo root.
        let here = URL(fileURLWithPath: #filePath)
        let repo = here.deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repo.appendingPathComponent(relativePath), encoding: .utf8)
    }

    func test_theRetiredBannerIsGone() throws {
        // The prompt-shaped surface is the thing HAN's ruling removed. If this file
        // comes back, someone has reintroduced the Add row.
        let here = URL(fileURLWithPath: #filePath)
        let repo = here.deletingLastPathComponent().deletingLastPathComponent()
        let banner = repo.appendingPathComponent("WorkloadApp/Views/WorkoutLog/WorkoutImportBanner.swift")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: banner.path),
            "WorkoutImportBanner.swift is retired — watch workouts log silently (U4)."
        )
    }

    func test_theImportedSessionKeyNeverSyncs() throws {
        // `healthKitWorkoutUUID` names a sample in the athlete's own Health store. It
        // has no meaning on the server and must never be pushed.
        let sync = try source("WorkloadApp/Services/SyncService.swift")
        XCTAssertFalse(
            sync.contains("healthKitWorkoutUUID"),
            "healthKitWorkoutUUID must stay device-local — it names a HealthKit sample."
        )
    }

    func test_theImporterRunsThroughTheMatcher() throws {
        // The guard is only a guard if the insert path cannot bypass it.
        let service = try source("WorkloadApp/Services/WatchWorkoutImportService.swift")
        XCTAssertTrue(
            service.contains("WatchWorkoutMatcher.decide"),
            "Every candidate must pass the dedupe guard before it is logged."
        )
        XCTAssertTrue(
            service.contains("SCREENSHOT_MODE"),
            "Seeded screenshot runs must never reach the real Health store."
        )
    }

    func test_theImporterGuardsAgainstReentrancy() throws {
        // Two triggers fire on the same event — AppRouter's foreground handler and the Log
        // tab's `.task`. Overlapping runs would each read their comparison set before the
        // other wrote, and the UUID key cannot catch that.
        let service = try source("WorkloadApp/Services/WatchWorkoutImportService.swift")
        XCTAssertTrue(service.contains("guard !isRunning else { return 0 }"))
        XCTAssertTrue(service.contains("defer { isRunning = false }"))
    }

    func test_effortIsReadNotAsked() throws {
        // The whole point of U4's third clause: an athlete who rated the session on
        // their watch is never asked for the same number again.
        let health = try source("WorkloadApp/Services/HealthKitService.swift")
        XCTAssertTrue(health.contains("workoutEffortScore"))
        XCTAssertTrue(health.contains("estimatedWorkoutEffortScore"))
    }
}
