import XCTest
@testable import workload_management

final class SessionStartMapperTests: XCTestCase {
    func testFourPrimaryChoicesMapToPersistedEnums() {
        XCTAssertEqual(
            SessionStartMapper.configuration(for: .strength),
            SessionStartConfiguration(
                sportType: .lifting,
                sessionType: .strength,
                matchTier: nil
            )
        )
        XCTAssertEqual(
            SessionStartMapper.configuration(for: .basketball),
            SessionStartConfiguration(
                sportType: .teamSport,
                sessionType: .skill,
                matchTier: nil
            )
        )
        XCTAssertEqual(
            SessionStartMapper.configuration(for: .aerobic),
            SessionStartConfiguration(
                sportType: .custom,
                sessionType: .cardio,
                matchTier: nil
            )
        )
        XCTAssertEqual(
            SessionStartMapper.configuration(for: .otherSport, otherSport: .running),
            SessionStartConfiguration(
                sportType: .running,
                sessionType: .cardio,
                matchTier: nil
            )
        )
    }

    func testBasketballFollowUpsMapToExactSessionAndTier() {
        let cases: [(BasketballSessionChoice, SessionType, MatchTier?)] = [
            (.practice, .skill, nil),
            (.pickup, .match, .pickup),
            (.scrimmage, .match, .scrimmage),
            (.match, .match, .match)
        ]

        for (choice, expectedSession, expectedTier) in cases {
            let result = SessionStartMapper.basketballConfiguration(for: choice)
            XCTAssertEqual(result.sportType, .teamSport, "Unexpected sport for \(choice)")
            XCTAssertEqual(result.sessionType, expectedSession, "Unexpected session for \(choice)")
            XCTAssertEqual(result.matchTier, expectedTier, "Unexpected tier for \(choice)")
        }
    }

    func testSelectionInferenceSupportsTemplateAndResolvedPlanPrefill() {
        XCTAssertEqual(
            SessionStartMapper.choice(sportType: .lifting, sessionType: .strength),
            .strength
        )
        XCTAssertEqual(
            SessionStartMapper.choice(sportType: .teamSport, sessionType: .match),
            .basketball
        )
        XCTAssertEqual(
            SessionStartMapper.choice(sportType: .custom, sessionType: .cardio),
            .aerobic
        )
        XCTAssertEqual(
            SessionStartMapper.choice(sportType: .swimming, sessionType: .cardio),
            .otherSport
        )
    }

    func testSelectionRederivationAfterTemplateHydration() {
        XCTAssertEqual(
            SessionStartMapper.choice(sportType: .cycling, sessionType: .cardio),
            .otherSport
        )
        XCTAssertEqual(
            SessionStartMapper.choice(sportType: .custom, sessionType: .cardio),
            .aerobic
        )

        let matchCases: [(MatchTier, BasketballSessionChoice)] = [
            (.pickup, .pickup),
            (.scrimmage, .scrimmage),
            (.match, .match)
        ]

        for (tier, expectedChoice) in matchCases {
            XCTAssertEqual(
                SessionStartMapper.choice(sportType: .teamSport, sessionType: .match),
                .basketball
            )
            XCTAssertEqual(
                SessionStartMapper.basketballChoice(sessionType: .match, matchTier: tier),
                expectedChoice
            )
        }
    }
}
