import XCTest
@testable import workload_management

final class SessionTypeTests: XCTestCase {

    func test_sessionType_rawValues() {
        XCTAssertEqual(SessionType.strength.rawValue, "strength")
        XCTAssertEqual(SessionType.skill.rawValue,    "skill")
        XCTAssertEqual(SessionType.cardio.rawValue,   "cardio")
        XCTAssertEqual(SessionType.match.rawValue,    "match")
        XCTAssertEqual(SessionType.recovery.rawValue, "recovery")
    }

    func test_sessionType_displayNames() {
        XCTAssertEqual(SessionType.strength.displayName, "Strength")
        XCTAssertEqual(SessionType.skill.displayName,    "Skill")
        XCTAssertEqual(SessionType.cardio.displayName,   "Cardio")
        XCTAssertEqual(SessionType.match.displayName,    "Match")
        XCTAssertEqual(SessionType.recovery.displayName, "Recovery")
    }

    func test_sessionType_allCases_containsAllExpectedRawValues() {
        let rawValues = SessionType.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues), Set(["strength", "skill", "cardio", "match", "recovery"]))
    }

    func test_workoutSession_defaultSessionType_isStrength() {
        let session = WorkoutSession()
        XCTAssertEqual(session.sessionType, .strength)
    }

    func test_workoutSession_defaultLoggedByCoachId_isNil() {
        let session = WorkoutSession()
        XCTAssertNil(session.loggedByCoachId)
    }
}

final class WorkoutSessionRowTests: XCTestCase {

    func test_row_mapsSessionType() {
        let session = WorkoutSession(sessionDate: .now, durationSeconds: 3600)
        session.sessionType = .skill
        let row = SyncService.WorkoutSessionRow(from: session, athleteId: UUID())
        XCTAssertEqual(row.sessionType, "skill")
    }

    func test_row_mapsLoggedByCoachId_whenNil() {
        let session = WorkoutSession()
        let row = SyncService.WorkoutSessionRow(from: session, athleteId: UUID())
        XCTAssertNil(row.loggedByCoachId)
    }

    func test_row_mapsLoggedByCoachId_whenSet() {
        let coachId = UUID()
        let session = WorkoutSession()
        session.loggedByCoachId = coachId
        let row = SyncService.WorkoutSessionRow(from: session, athleteId: UUID())
        XCTAssertEqual(row.loggedByCoachId, coachId)
    }

    func test_row_mapsDurationSeconds_directly() {
        let session = WorkoutSession(durationSeconds: 5400)
        let row = SyncService.WorkoutSessionRow(from: session, athleteId: UUID())
        XCTAssertEqual(row.durationSeconds, 5400)
    }

    func test_row_sessionType_roundtripsToEnum() {
        let session = WorkoutSession()
        session.sessionType = .cardio
        let row = SyncService.WorkoutSessionRow(from: session, athleteId: UUID())
        let decoded = SessionType(rawValue: row.sessionType)
        XCTAssertEqual(decoded, .cardio)
    }

    func test_row_preservesAllAttributionFields() {
        let coachId = UUID()
        let session = WorkoutSession()
        session.sessionType = .match
        session.loggedByCoachId = coachId
        let row = SyncService.WorkoutSessionRow(from: session, athleteId: UUID())
        // Simulate pull-direction decode
        XCTAssertEqual(SessionType(rawValue: row.sessionType), .match)
        XCTAssertEqual(row.loggedByCoachId, coachId)
    }
}
