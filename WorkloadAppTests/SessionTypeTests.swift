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

final class MatchTierTests: XCTestCase {

    func test_matchTier_rawValues_areSerializationContract() {
        XCTAssertEqual(MatchTier.pickup.rawValue,    "pickup")
        XCTAssertEqual(MatchTier.scrimmage.rawValue, "scrimmage")
        XCTAssertEqual(MatchTier.match.rawValue,     "match")
    }

    func test_matchTier_allCases_ladderOrder() {
        // The seriousness ladder: pickup → scrimmage → match (CONTEXT.md "Match tier").
        XCTAssertEqual(MatchTier.allCases, [.pickup, .scrimmage, .match])
    }

    func test_matchTier_displayNames() {
        XCTAssertEqual(MatchTier.pickup.displayName,    "Pickup")
        XCTAssertEqual(MatchTier.scrimmage.displayName, "Scrimmage")
        XCTAssertEqual(MatchTier.match.displayName,     "Match")
    }

    func test_matchTier_identifiable_idIsRawValue() {
        for tier in MatchTier.allCases {
            XCTAssertEqual(tier.id, tier.rawValue)
        }
    }

    func test_workoutSession_defaultMatchTier_isNil() {
        // Additive nullable field: every pre-v2.1 row and fresh session decodes to nil
        // (treated as pickup by the carry model) — no SwiftData migration.
        let session = WorkoutSession()
        XCTAssertNil(session.matchTierRaw)
        XCTAssertNil(session.matchTier)
    }

    func test_workoutSession_matchTier_roundtripsThroughRaw() {
        let session = WorkoutSession()
        session.matchTier = .scrimmage
        XCTAssertEqual(session.matchTierRaw, "scrimmage")
        XCTAssertEqual(session.matchTier, .scrimmage)
        session.matchTier = nil
        XCTAssertNil(session.matchTierRaw)
    }

    func test_workoutSession_unknownRawTier_decodesToNil() {
        // Forward-compat: an unrecognized stored raw value degrades to nil (pickup), never traps.
        let session = WorkoutSession()
        session.matchTierRaw = "playoff-final"
        XCTAssertNil(session.matchTier)
    }

    // MARK: - Save-time persistence rule (persist what the picker showed)

    func test_persistedTier_matchSession_untouchedPicker_defaultsToExplicitPickup() {
        // A saved match session with a nil picker state persists .pickup EXPLICITLY —
        // "true pickup" must never be conflated with "unknown/pre-v2.1" (nil).
        XCTAssertEqual(MatchTier.persistedTier(sessionType: .match, selected: nil), .pickup)
    }

    func test_persistedTier_matchSession_keepsExplicitSelection() {
        XCTAssertEqual(MatchTier.persistedTier(sessionType: .match, selected: .scrimmage), .scrimmage)
        XCTAssertEqual(MatchTier.persistedTier(sessionType: .match, selected: .match), .match)
        XCTAssertEqual(MatchTier.persistedTier(sessionType: .match, selected: .pickup), .pickup)
    }

    func test_persistedTier_nonMatchSessions_alwaysPersistNil() {
        for type in SessionType.allCases where type != .match {
            XCTAssertNil(
                MatchTier.persistedTier(sessionType: type, selected: .match),
                "\(type.rawValue) sessions carry no tier — even a stale picker selection persists nil"
            )
            XCTAssertNil(MatchTier.persistedTier(sessionType: type, selected: nil))
        }
    }

    func test_activeWorkoutSheet_usesPersistedTierRule_sourceGrep() throws {
        // Structural guard: the save path must route through MatchTier.persistedTier so the
        // explicit-.pickup default can't silently regress to persisting raw nil state.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // WorkloadAppTests/
            .deletingLastPathComponent()   // repo root
        let url = root.appendingPathComponent("WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(
            source.contains("MatchTier.persistedTier(sessionType:"),
            "ActiveWorkoutSheet must persist the tier via MatchTier.persistedTier (explicit .pickup on save)"
        )
    }

    func test_syncRow_neverCarriesMatchTier() throws {
        // Sync fence: matchTier is local-only by design (no Supabase schema change). The
        // explicit-field WorkoutSessionRow must not pick it up, even when set.
        let session = WorkoutSession()
        session.sessionType = .match
        session.matchTier = .match
        let row = WorkoutSessionRow(from: session, athleteId: UUID())
        let json = String(decoding: try JSONEncoder().encode(row), as: UTF8.self)
        XCTAssertFalse(json.contains("matchTier"))
    }
}

final class WorkoutSessionRowTests: XCTestCase {

    func test_row_mapsSessionType() {
        let session = WorkoutSession(sessionDate: .now, durationSeconds: 3600)
        session.sessionType = .skill
        let row = WorkoutSessionRow(from: session, athleteId: UUID())
        XCTAssertEqual(row.sessionType, "skill")
    }

    func test_row_mapsLoggedByCoachId_whenNil() {
        let session = WorkoutSession()
        let row = WorkoutSessionRow(from: session, athleteId: UUID())
        XCTAssertNil(row.loggedByCoachId)
    }

    func test_row_mapsLoggedByCoachId_whenSet() {
        let coachId = UUID()
        let session = WorkoutSession()
        session.loggedByCoachId = coachId
        let row = WorkoutSessionRow(from: session, athleteId: UUID())
        XCTAssertEqual(row.loggedByCoachId, coachId)
    }

    func test_row_mapsDurationSeconds_directly() {
        let session = WorkoutSession(durationSeconds: 5400)
        let row = WorkoutSessionRow(from: session, athleteId: UUID())
        XCTAssertEqual(row.durationSeconds, 5400)
    }

    func test_row_sessionType_roundtripsToEnum() {
        let session = WorkoutSession()
        session.sessionType = .cardio
        let row = WorkoutSessionRow(from: session, athleteId: UUID())
        let decoded = SessionType(rawValue: row.sessionType ?? "")
        XCTAssertEqual(decoded, SessionType.cardio)
    }

    func test_row_preservesAllAttributionFields() {
        let coachId = UUID()
        let session = WorkoutSession()
        session.sessionType = .match
        session.loggedByCoachId = coachId
        let row = WorkoutSessionRow(from: session, athleteId: UUID())
        // Simulate pull-direction decode
        XCTAssertEqual(SessionType(rawValue: row.sessionType ?? ""), SessionType.match)
        XCTAssertEqual(row.loggedByCoachId, coachId)
    }
}
