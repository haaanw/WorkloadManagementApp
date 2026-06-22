import XCTest
import SwiftData
@testable import workload_management

final class CoachRelationshipModelTests: XCTestCase {

    func test_relationship_defaultStatus_isPending() {
        let rel = CoachAthleteRelationship(coachId: UUID(), athleteId: UUID())
        XCTAssertEqual(rel.status, .pending)
    }

    func test_relationship_accept_changesStatus() {
        let rel = CoachAthleteRelationship(coachId: UUID(), athleteId: UUID())
        rel.status = .accepted
        XCTAssertEqual(rel.status, .accepted)
    }

    func test_relationshipStatus_rawValues() {
        XCTAssertEqual(RelationshipStatus.pending.rawValue, "pending")
        XCTAssertEqual(RelationshipStatus.accepted.rawValue, "accepted")
    }

    func test_appMode_rawValues() {
        XCTAssertEqual(AppMode.athlete.rawValue, "athlete")
        XCTAssertEqual(AppMode.coach.rawValue, "coach")
    }
}
