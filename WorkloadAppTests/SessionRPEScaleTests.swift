import XCTest
@testable import workload_management

/// The session-RPE verbal anchors (v1.7.2).
///
/// These pin the *rule*, not the copy: a reading shows the highest published anchor at or below
/// it. Foster's session-RPE table leaves 6, 8 and 9 blank, and the app fills them by reading
/// down to the nearest anchor rather than by inventing words — so two adjacent values sharing a
/// word is the instrument working, and a test has to say so or someone will "fix" it later.
final class SessionRPEScaleTests: XCTestCase {

    func test_publishedAnchors_mapToThemselves() {
        XCTAssertEqual(SessionRPEScale.anchor(for: 1), .veryEasy)
        XCTAssertEqual(SessionRPEScale.anchor(for: 2), .easy)
        XCTAssertEqual(SessionRPEScale.anchor(for: 3), .moderate)
        XCTAssertEqual(SessionRPEScale.anchor(for: 4), .somewhatHard)
        XCTAssertEqual(SessionRPEScale.anchor(for: 5), .hard)
        XCTAssertEqual(SessionRPEScale.anchor(for: 7), .veryHard)
        XCTAssertEqual(SessionRPEScale.anchor(for: 10), .maximal)
    }

    func test_gapsReadDownToTheNearestAnchor() {
        // 6, 8 and 9 are blank on the instrument.
        XCTAssertEqual(SessionRPEScale.anchor(for: 6), .hard)
        XCTAssertEqual(SessionRPEScale.anchor(for: 8), .veryHard)
        XCTAssertEqual(SessionRPEScale.anchor(for: 9), .veryHard)
    }

    func test_neverReadsUp() {
        // A 9 must never be labelled "maximal" — that would overstate the session on the one
        // subjective input the load model has.
        XCTAssertNotEqual(SessionRPEScale.anchor(for: 9), .maximal)
        XCTAssertNotEqual(SessionRPEScale.anchor(for: 6), .veryHard)
    }

    func test_belowScale_clampsToLowestAnchor() {
        // The slider floors at 1, but the function must not trap on a stale or decoded 0.
        XCTAssertEqual(SessionRPEScale.anchor(for: 0), .veryEasy)
        XCTAssertEqual(SessionRPEScale.anchor(for: -3), .veryEasy)
    }

    func test_aboveScale_staysMaximal() {
        XCTAssertEqual(SessionRPEScale.anchor(for: 11), .maximal)
    }

    func test_doubleOverload_rounds() {
        XCTAssertEqual(SessionRPEScale.anchor(for: 6.6), .veryHard)
        XCTAssertEqual(SessionRPEScale.anchor(for: 6.4), .hard)
    }

    func test_everyValueOnTheSliderHasAnAnchor() {
        // The reading is never blank between 1 and 10 — the gap-filling rule covers the range.
        for rpe in 1...10 {
            XCTAssertNotNil(SessionRPEScale.anchor(for: rpe))
        }
    }
}
