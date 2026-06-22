import XCTest
@testable import workload_management

/// Phase 44 Plan 02 (Task 3) — source-grep FENCE over `TodayVerdictCard.swift`.
///
/// The suggest-and-confirm surface is the autonomy/nocebo load-bearing UX. This fence proves, at
/// build time, that the card source never reintroduces the cracks the pressure-test flagged:
///  - DESIGN drift (rounded corners, shadows, the danger-zone token, raw red/green, `.system(`
///    fonts), and
///
/// NOTE (Tuwa v2, 2026-06-17): `ColorTokens.accent` is no longer banned here. v2 relaxed the
/// accent rule from "hero number only" to the "live / actionable" semantic, which DESIGN.md
/// explicitly sanctions on strike-zone / progress fills — and the card's `StrikeZoneBar` is
/// exactly that. The fence still forbids painting the verdict *state* with alarm colors
/// (`.zoneDanger`, raw red/green) — that nocebo guard is unchanged.
///  - nocebo / coercion copy ("don't train", "rest day" gate, "are you sure", guilt phrasing).
///
/// Mirrors `TodayVerdictServiceTests.test_service_neverSaysInjuryPrediction_sourceGrep`: resolve the
/// repo root from `#filePath` (WorkloadAppTests/ → repo root) and read the card source directly.
final class TodayVerdictCardGuardTests: XCTestCase {

    private func cardSource() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // WorkloadAppTests/
            .deletingLastPathComponent()   // repo root
        let url = root.appendingPathComponent("WorkloadApp/Views/WorkoutLog/TodayVerdictCard.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - DESIGN fence

    func test_card_designFence_noBannedTokens() throws {
        let source = try cardSource()
        let banned = [
            "RoundedRectangle",
            ".cornerRadius",
            ".shadow",
            ".system(",
            ".zoneDanger",
            "Color.red",
            "Color.green"
        ]
        for token in banned {
            XCTAssertFalse(
                source.contains(token),
                "TodayVerdictCard.swift must not contain DESIGN-banned token '\(token)'"
            )
        }
    }

    // MARK: - Nocebo-copy fence

    func test_card_noceboFence_noBannedCopy() throws {
        let source = try cardSource().lowercased()
        let banned = [
            "don't train",
            "do not train",
            "rest day",
            "are you sure",
            "this may hurt",
            "this will hurt",
            "hurt your progress",
            "stop training"
        ]
        for phrase in banned {
            XCTAssertFalse(
                source.contains(phrase),
                "TodayVerdictCard.swift must not contain nocebo/coercion phrase '\(phrase)'"
            )
        }
    }
}
