import XCTest
@testable import workload_management

/// Guards the UIKit shell ports for the v2.1 verdict surfaces. The SwiftUI twins are no longer
/// the running app, so these tests pin the live shell seams directly.
final class AppShellVerdictSurfaceGuardTests: XCTestCase {

    private func appShellSource() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent("WorkloadApp/App/AppShell.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    func test_activeWorkoutUIKitShellPersistsMatchTierThroughCanonicalRule() throws {
        let source = try appShellSource()

        XCTAssertTrue(source.contains("private var matchTier: MatchTier?"))
        XCTAssertTrue(source.contains("session.matchTier = MatchTier.persistedTier(sessionType: sessionType, selected: matchTier)"))
        XCTAssertTrue(source.contains("self.matchTier = type == .match ? tier : nil"))
        XCTAssertTrue(source.contains("activeWorkout.settings.matchTier.\\(tier.rawValue)"))
    }

    func test_measurementUIKitShellRendersDogfoodSummaryRows() throws {
        let source = try appShellSource()

        XCTAssertTrue(source.contains("FeltRightPromptEngine.summary(events: events, asOf: .now, calendar: .current)"))
        XCTAssertTrue(source.contains("measurement.dogfood.differingDays"))
        XCTAssertTrue(source.contains("measurement.dogfood.followed.label"))
        XCTAssertTrue(source.contains("measurement.dogfood.feltRight.context"))
        XCTAssertTrue(source.contains("measurement.dogfood.proximity.label"))
    }

    func test_verdictUIKitShellDoesNotUseAccentForVerdictSurface() throws {
        let source = try appShellSource()

        XCTAssertFalse(source.contains("UIKitDesign.accent.cgColor"))
    }
}
