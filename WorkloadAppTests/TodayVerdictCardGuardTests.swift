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

    // Tuwa v3 (2026-07-14, Ink & Grain): `RoundedRectangle` and `.cornerRadius` removed from the
    // banned set — the 0pt corner law is retired. Corners are now legal on the card, but ONLY via
    // CornerTokens (card 12 / control 8 / pill); a hand-typed radius literal stays a fence failure.
    // The nocebo guard (no alarm colors on the verdict state) is unchanged.
    func test_card_designFence_noBannedTokens() throws {
        let source = try cardSource()
        let banned = [
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

    // Tuwa v3 Corner Law: any radius the card draws must come from CornerTokens.
    func test_card_cornerRadii_onlyViaCornerTokens() throws {
        let source = try cardSource()
        if source.contains("RoundedRectangle(cornerRadius:") || source.contains(".cornerRadius(") {
            XCTAssertTrue(
                source.contains("CornerTokens"),
                "TodayVerdictCard.swift uses a corner radius without CornerTokens — hand-typed radii are banned (DESIGN.md v3 Corner Law)"
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

final class UIKitDesignPrimitiveTests: XCTestCase {

    func test_microText_uppercasesLatinButPreservesChinese() {
        XCTAssertEqual(UIKitDesign.microText("Cross-signal read"), "CROSS-SIGNAL READ")
        XCTAssertEqual(UIKitDesign.microText("选择语言"), "选择语言")
        XCTAssertEqual(UIKitDesign.microText("恢复 HRV"), "恢复 HRV")
    }
}
