import XCTest
import SwiftUI
import CoreGraphics
@testable import workload_management

/// Behavior + genericity + source-compliance tests for `RadialPicker` (Phase 21, Plan 03).
///
/// Proves the commit/cancel selection contract (criteria 4, 5) and that the
/// component is generic over any `RadialSelectable` enum (criteria 1, 7) by
/// driving `RadialRingGeometry` for both `SportType` (7 cases) and
/// `SessionType` (5 cases) — no UI automation needed.
final class RadialPickerInteractionTests: XCTestCase {

    // MARK: Selection resolver mirroring RadialPicker.commit/updateHighlight

    /// Resolve a center-relative point to a committed option, or nil (cancel),
    /// for a given enum's case list. Mirrors `RadialPicker.commit(at:)`.
    private func resolve<Option: RadialSelectable>(
        _ type: Option.Type,
        point: CGPoint,
        diameter: CGFloat = 240
    ) -> Option? where Option.AllCases.Element == Option {
        let options = Array(Option.allCases)
        let geometry = RadialRingGeometry(count: options.count, diameter: diameter, deadZoneRadius: 64)
        guard let index = geometry.highlightIndex(for: point) else { return nil }
        return options[index]
    }

    // MARK: Commit (in-sector -> correct option)

    func test_commit_sportType_topSector_isFirstCase() {
        let options = Array(SportType.allCases)
        // Straight up at a mid radius -> index 0 -> first case.
        let result = resolve(SportType.self, point: CGPoint(x: 0, y: -120))
        XCTAssertEqual(result, options[0])
    }

    func test_commit_sessionType_topSector_isFirstCase() {
        let options = Array(SessionType.allCases)
        let result = resolve(SessionType.self, point: CGPoint(x: 0, y: -120))
        XCTAssertEqual(result, options[0])
    }

    func test_commit_eachPlacementResolvesToOwnCase_sportType() {
        let options = Array(SportType.allCases)
        let geometry = RadialRingGeometry(count: options.count, diameter: 240, deadZoneRadius: 64)
        for (i, option) in options.enumerated() {
            let o = geometry.point(forIndex: i, radius: geometry.optionRadius)
            let result = resolve(SportType.self, point: CGPoint(x: o.width, y: o.height))
            XCTAssertEqual(result, option, "SportType case \(i) should resolve to itself")
        }
    }

    func test_commit_eachPlacementResolvesToOwnCase_sessionType() {
        let options = Array(SessionType.allCases)
        let geometry = RadialRingGeometry(count: options.count, diameter: 240, deadZoneRadius: 64)
        for (i, option) in options.enumerated() {
            let o = geometry.point(forIndex: i, radius: geometry.optionRadius)
            let result = resolve(SessionType.self, point: CGPoint(x: o.width, y: o.height))
            XCTAssertEqual(result, option, "SessionType case \(i) should resolve to itself")
        }
    }

    // MARK: Cancel (dead zone / beyond cancel radius -> no commit)

    func test_cancel_deadZone_sportType() {
        XCTAssertNil(resolve(SportType.self, point: CGPoint(x: 0, y: 0)))
        XCTAssertNil(resolve(SportType.self, point: CGPoint(x: 0, y: -60)))
    }

    func test_cancel_deadZone_sessionType() {
        XCTAssertNil(resolve(SessionType.self, point: CGPoint(x: 0, y: 0)))
        XCTAssertNil(resolve(SessionType.self, point: CGPoint(x: 0, y: -60)))
    }

    func test_cancel_beyondCancelRadius_bothEnums() {
        // cancelRadius = 240 * 0.75 = 180.
        XCTAssertNil(resolve(SportType.self, point: CGPoint(x: 0, y: -181)))
        XCTAssertNil(resolve(SessionType.self, point: CGPoint(x: 200, y: 0)))
    }

    // MARK: Genericity witnesses (compile-time proof over both enums)

    func test_genericity_bothEnumsTypeCheck() {
        _ = RadialPicker(selection: .constant(SportType.lifting), title: "Sport")
        _ = RadialPicker(selection: .constant(SessionType.strength), title: "Type")
        // Conformance witnesses.
        XCTAssertEqual(SportType.lifting.radialIcon, SportType.lifting.systemImage)
        XCTAssertEqual(SessionType.strength.radialIcon, SessionType.strength.systemImage)
        XCTAssertEqual(SportType.allCases.count, 7)
        XCTAssertEqual(SessionType.allCases.count, 5)
    }

    // MARK: Source compliance (DESIGN.md criterion 8)

    func test_source_isDesignCompliant() throws {
        // Resolve RadialPicker.swift relative to this test file's path.
        let testDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repoRoot = testDir.deletingLastPathComponent()
        let source = repoRoot
            .appendingPathComponent("WorkloadApp/Components/RadialPicker.swift")
        let text = try String(contentsOf: source, encoding: .utf8)
        // Tuwa v2 (2026-06-17): ColorTokens.accent removed from the forbidden set — the accent rule
        // relaxed to the "live / active" semantic, and RadialPicker uses it for the active selection
        // (selected icon/label + highlighted ring chip), a sanctioned use per DESIGN.md.
        for forbidden in ["RoundedRectangle", ".shadow(", ".system("] {
            XCTAssertFalse(text.contains(forbidden), "RadialPicker.swift must not contain \(forbidden)")
        }
    }
}
