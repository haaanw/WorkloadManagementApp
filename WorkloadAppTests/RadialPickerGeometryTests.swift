import XCTest
import CoreGraphics
@testable import workload_management

/// Pure geometry + hit-testing tests for `RadialRingGeometry` (Phase 21, Plan 01).
/// No UI automation — validates angular layout (D-05) and dead-zone/cancel
/// classification (D-07) directly against the helper.
final class RadialPickerGeometryTests: XCTestCase {

    private let epsilon: CGFloat = 0.0001

    private func geometry(count: Int, diameter: CGFloat = 240, deadZone: CGFloat = 64) -> RadialRingGeometry {
        RadialRingGeometry(count: count, diameter: diameter, deadZoneRadius: deadZone)
    }

    // MARK: angle(forIndex:)

    func test_angle_index0_isTop() {
        // Index 0 sits at -90° (top) for any count.
        XCTAssertEqual(geometry(count: 5).angle(forIndex: 0), -.pi / 2, accuracy: epsilon)
        XCTAssertEqual(geometry(count: 7).angle(forIndex: 0), -.pi / 2, accuracy: epsilon)
    }

    func test_angle_evenSpacing_count5() {
        let g = geometry(count: 5)
        let step = (2 * CGFloat.pi) / 5
        for i in 0..<5 {
            XCTAssertEqual(g.angle(forIndex: i), -.pi / 2 + CGFloat(i) * step, accuracy: epsilon)
        }
    }

    func test_angle_evenSpacing_count7() {
        let g = geometry(count: 7)
        let step = (2 * CGFloat.pi) / 7
        for i in 0..<7 {
            XCTAssertEqual(g.angle(forIndex: i), -.pi / 2 + CGFloat(i) * step, accuracy: epsilon)
        }
    }

    // MARK: point(forIndex:radius:)

    func test_point_index0_landsAtTop() {
        // Top = (0, -radius) in SwiftUI coords (y grows downward).
        let g = geometry(count: 4)
        let p = g.point(forIndex: 0, radius: 100)
        XCTAssertEqual(p.width, 0, accuracy: epsilon)
        XCTAssertEqual(p.height, -100, accuracy: epsilon)
    }

    func test_point_quarterTurn_landsRight() {
        // For count 4, index 1 = +90° clockwise from top = right side (x=+radius).
        let g = geometry(count: 4)
        let p = g.point(forIndex: 1, radius: 100)
        XCTAssertEqual(p.width, 100, accuracy: epsilon)
        XCTAssertEqual(p.height, 0, accuracy: epsilon)
    }

    // MARK: highlightIndex(for:) — dead zone & cancel

    func test_highlight_centerIsDeadZone() {
        let g = geometry(count: 5)
        XCTAssertNil(g.highlightIndex(for: CGPoint(x: 0, y: 0)))
        // Just inside the dead-zone radius → nil.
        XCTAssertNil(g.highlightIndex(for: CGPoint(x: 0, y: -63)))
    }

    func test_highlight_beyondCancelRadius() {
        let g = geometry(count: 5)
        // cancelRadius = diameter * 0.75 = 180.
        XCTAssertNil(g.highlightIndex(for: CGPoint(x: 0, y: -181)))
        XCTAssertNil(g.highlightIndex(for: CGPoint(x: 200, y: 0)))
    }

    // MARK: highlightIndex(for:) — sector resolution

    func test_highlight_topSector_index0() {
        let g = geometry(count: 5)
        // A point straight up at a valid radius → index 0 (top).
        XCTAssertEqual(g.highlightIndex(for: CGPoint(x: 0, y: -120)), 0)
    }

    func test_highlight_sectors_count4_cardinals() {
        let g = geometry(count: 4)
        // index 0 top, 1 right, 2 bottom, 3 left.
        XCTAssertEqual(g.highlightIndex(for: CGPoint(x: 0, y: -120)), 0)
        XCTAssertEqual(g.highlightIndex(for: CGPoint(x: 120, y: 0)), 1)
        XCTAssertEqual(g.highlightIndex(for: CGPoint(x: 0, y: 120)), 2)
        XCTAssertEqual(g.highlightIndex(for: CGPoint(x: -120, y: 0)), 3)
    }

    func test_highlight_count7_allSectorsResolveInRange() {
        let g = geometry(count: 7)
        // Each option's own placement point must resolve back to its index.
        for i in 0..<7 {
            let offset = g.point(forIndex: i, radius: g.optionRadius)
            let index = g.highlightIndex(for: CGPoint(x: offset.width, y: offset.height))
            XCTAssertEqual(index, i, "Option \(i) placement should resolve to index \(i)")
        }
    }

    func test_highlight_count5_allSectorsResolveInRange() {
        let g = geometry(count: 5)
        for i in 0..<5 {
            let offset = g.point(forIndex: i, radius: g.optionRadius)
            let index = g.highlightIndex(for: CGPoint(x: offset.width, y: offset.height))
            XCTAssertEqual(index, i, "Option \(i) placement should resolve to index \(i)")
        }
    }
}
