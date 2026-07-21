import XCTest

/// App-wide design-fence — DESIGN.md v5 "Pavilion" (Warm Stone, 2026-07-21).
///
/// Source-grep fences over the styled SwiftUI layer (`Views/`, `Components/`, `Utilities/`,
/// plus the live SwiftUI app files in `App/`). The retired UIKit shell was deleted in the
/// v1.6 launch cleanup (2026-07-21) — no exclusions remain.
///
/// The v5 laws these enforce:
/// 1. **Corner Law** — radii only via `CornerTokens` (card 12 / control 8 / pill).
///    Hand-typed radius literals are a fence failure.
/// 2. **No shadows** — elevation stays plane + hairline + relief, never blur.
/// 3. **No hardcoded colors in views** — everything routes through `ColorTokens`.
/// 4. **One-Voice Type Law** — the app's face name ("InstrumentSans") lives ONLY in
///    `FontTokens.swift`; no `.system(` fonts. The retired v3 serif ("SourceSerif4") and
///    v4 mono dial voice ("IBMPlexMono") are BANNED app-wide — they must not reappear,
///    and neither may the v4 black panel (`panelStyle(`) or the dial tokens.
/// 5. **Spacing grid** — structural `spacing:` / bare `.padding(` literals of 4pt and above
///    must be multiples of 4 (8pt grid + the sanctioned 4pt `baselinePair`).
/// 6. **Motion Law** — one motion language: every animation routes through the `Motion`
///    tokens in CardStyle.swift. Ad-hoc curve/duration literals and bare `withAnimation`
///    (SwiftUI's default spring) are fence failures.
///
/// Retired fences: halftone (deleted with v4); the v4 Panel Law one-panel-per-screen fence
/// inverted into the app-wide panelStyle ban (v5 Hero Law: hero = raised light card).
final class DesignSystemFenceTests: XCTestCase {

    // MARK: - Source enumeration

    private static let excludedFiles: Set<String> = []

    private func appRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // WorkloadAppTests/
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("WorkloadApp")
    }

    /// All fenced Swift sources: [(fileName, commentStrippedText)].
    private func fencedSources(subdirectories: [String] = ["Views", "Components", "Utilities", "App"]) throws -> [(name: String, text: String)] {
        var results: [(String, String)] = []
        let fm = FileManager.default
        for dir in subdirectories {
            let root = appRoot().appendingPathComponent(dir)
            guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                let name = url.lastPathComponent
                if Self.excludedFiles.contains(name) { continue }
                let raw = try String(contentsOf: url, encoding: .utf8)
                results.append((name, Self.strippingCommentLines(raw)))
            }
        }
        XCTAssertGreaterThan(results.count, 50, "Fence enumeration looks broken — expected the SwiftUI layer to contain many files")
        return results
    }

    /// Drop full-line comments so doc references to banned tokens don't trip the fences.
    private static func strippingCommentLines(_ source: String) -> String {
        source
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    // MARK: - 1. Corner Law: radii only via CornerTokens

    func test_cornerRadii_onlyViaCornerTokens() throws {
        for (name, text) in try fencedSources() {
            if name == "CornerTokens.swift" { continue }
            if text.contains("RoundedRectangle(cornerRadius:")
                || text.contains("UnevenRoundedRectangle(")
                || text.contains(".cornerRadius(") {
                XCTAssertTrue(
                    text.contains("CornerTokens"),
                    "\(name) uses a corner radius without CornerTokens — hand-typed radii are banned (DESIGN.md v5 Corner Law: card 12 / control 8 / pill)"
                )
            }
        }
    }

    // MARK: - 2. No shadows anywhere

    func test_noShadowModifiers() throws {
        for (name, text) in try fencedSources() {
            XCTAssertFalse(
                text.contains(".shadow("),
                "\(name) contains .shadow( — DESIGN.md v4 keeps the no-shadow law; elevation is plane + hairline only"
            )
        }
    }

    // MARK: - 3. No hardcoded colors in the view layer

    func test_noHardcodedColors_inViewsAndComponents() throws {
        for (name, text) in try fencedSources(subdirectories: ["Views", "Components"]) {
            for banned in ["Color(red:", "#colorLiteral", "UIColor(red:"] {
                XCTAssertFalse(
                    text.contains(banned),
                    "\(name) contains \(banned) — colors must come from ColorTokens (DESIGN.md v4)"
                )
            }
        }
    }

    // MARK: - 4. One-Voice Type Law: face name only in FontTokens; retired voices banned

    func test_faceName_onlyInFontTokens() throws {
        for (name, text) in try fencedSources() {
            if name == "FontTokens.swift" { continue }
            XCTAssertFalse(
                text.contains("InstrumentSans"),
                "\(name) names the app face directly — Instrument Sans is reachable only via Font.Tokens.* (DESIGN.md v5 One-Voice Type Law)"
            )
        }
    }

    func test_retiredVoicesAndPanel_bannedAppWide() throws {
        // Fence inversions: the v3 serif display voice (retired 2026-07-20), the v4 mono
        // dial voice, and the v4 black panel (retired 2026-07-21 by DESIGN.md v5) must not
        // reappear anywhere in the styled layer — including FontTokens/CardStyle.
        let banned = [
            ("SourceSerif4", "the serif display voice was retired by DESIGN.md v4 and stays banned in v5"),
            ("IBMPlexMono", "the mono dial voice was retired by DESIGN.md v5 \"Pavilion\" (2026-07-21)"),
            ("panelStyle(", "the black instrument panel was retired by the v5 Hero Law — heroes are raised light cards"),
            ("Tokens.dial", "the dial tokens were retired by the v5 One-Voice Type Law — use the one-voice ramp + .monospacedDigit()"),
            ("Tokens.Dial", "the v4 dial metrics enum is retired — the v5 ramp carries no custom tracking")
        ]
        for (name, text) in try fencedSources() {
            for (token, why) in banned {
                XCTAssertFalse(
                    text.contains(token),
                    "\(name) references \(token) — \(why)"
                )
            }
        }
    }

    func test_noSystemFonts_inViewsAndComponents() throws {
        for (name, text) in try fencedSources(subdirectories: ["Views", "Components"]) {
            XCTAssertFalse(
                text.contains(".system("),
                "\(name) contains .system( — all type goes through Font.Tokens.* (DESIGN.md v5)"
            )
        }
    }

    // MARK: - 5. Spacing grid: structural literals are multiples of 4

    func test_structuralSpacingLiterals_areOnTheGrid() throws {
        // `spacing: N` and bare `.padding(N)` literals: values >= 4 must be multiples of 4
        // (the 8pt grid plus the sanctioned 4pt baselinePair; sub-4 optical kerning gaps pass).
        let patterns = [
            try NSRegularExpression(pattern: #"spacing:\s*(\d+)"#),
            try NSRegularExpression(pattern: #"\.padding\((\d+)\)"#)
        ]
        for (name, text) in try fencedSources(subdirectories: ["Views", "Components"]) {
            let range = NSRange(text.startIndex..., in: text)
            for regex in patterns {
                regex.enumerateMatches(in: text, range: range) { match, _, _ in
                    guard let match, let valueRange = Range(match.range(at: 1), in: text),
                          let value = Int(text[valueRange]) else { return }
                    if value >= 4 {
                        XCTAssertEqual(
                            value % 4, 0,
                            "\(name) uses structural spacing literal \(value)pt — structural spacing must be a multiple of 4 (DESIGN.md v4 spacing grid)"
                        )
                    }
                }
            }
        }
    }

    // MARK: - 6. Motion Law: animation literals only in CardStyle.swift

    func test_animationCurveLiterals_onlyInCardStyle() throws {
        // Curve/spring constructors define motion personalities. The single motion language
        // lives in `Motion` (CardStyle.swift); everywhere else must reference tokens
        // (Motion.press / .state / .screen / .entrance / .exit / .tabSwitch / .scoreCountUp
        // or their aliases), ideally via `Motion.resolved(_:reduceMotion:)`. v4 Stage 3″
        // adds `.timingCurve(` — the strong ease-out cubic-bezier lives ONLY in the tokens.
        let bannedCurveLiterals = [
            ".easeIn(", ".easeOut(", ".easeInOut(", ".linear(", ".spring(", ".timingCurve(",
            ".interpolatingSpring", ".interactiveSpring", ".bouncy", ".snappy",
            "withAnimation(.", ".animation(."
        ]
        for (name, text) in try fencedSources() {
            if name == "CardStyle.swift" { continue }
            for banned in bannedCurveLiterals {
                XCTAssertFalse(
                    text.contains(banned),
                    "\(name) contains \(banned) — animation curves/durations are hand-typed only inside CardStyle.swift's Motion tokens; route this through Motion.* (DESIGN.md Motion Law)"
                )
            }
        }
    }

    func test_tickSpring_overshootReservedForTabTick() throws {
        // v4.1 Five-Primitive Interaction Law: `Motion.tickSpring` is the ONE sanctioned
        // overshoot curve in the whole app, reserved for the Console tab tick. It is DEFINED
        // in CardStyle.swift (the Motion chokepoint) and may be REFERENCED only by
        // InkTabBar.swift. Any other consumer would leak overshoot into the otherwise
        // overshoot-free mechanical grammar — a design-law failure.
        let allowed: Set<String> = ["CardStyle.swift", "InkTabBar.swift"]
        for (name, text) in try fencedSources() {
            if allowed.contains(name) { continue }
            XCTAssertFalse(
                text.contains("tickSpring"),
                "\(name) references Motion.tickSpring — the overshoot curve is reserved for the Console tab tick (InkTabBar.swift) only (DESIGN.md v4.1 Five-Primitive Interaction Law)"
            )
        }
    }

    func test_noBareWithAnimation() throws {
        // A bare `withAnimation { }` silently uses SwiftUI's default spring — a hidden,
        // untokenized personality. Every withAnimation call must name a Motion token
        // (and should pass through Motion.resolved for Reduce Motion).
        for (name, text) in try fencedSources() {
            for banned in ["withAnimation {", "withAnimation() {"] {
                XCTAssertFalse(
                    text.contains(banned),
                    "\(name) contains a bare `withAnimation` — pass a Motion token (Motion.resolved(Motion.state, reduceMotion:)) instead (DESIGN.md Motion Law)"
                )
            }
        }
    }

    func test_directionalPaddingLiterals_areOnTheGrid() throws {
        // Stage 1 extension: directional `.padding(.edge, ...)` forms. Every INTEGER literal in
        // the padding argument (including ternary branches like `? 16 : 10`) that is >= 4 must be
        // a multiple of 4. Decimal literals (0.5 hairline offsets) are excluded via the
        // dot-adjacency guards; token references (Spacing.*, CornerTokens.*) carry no digits.
        let argumentPattern = try NSRegularExpression(pattern: #"\.padding\(\.[a-zA-Z]+,([^)]*)\)"#)
        let integerLiteral = try NSRegularExpression(pattern: #"(?<![\d.])(\d+)(?![\d.])"#)
        for (name, text) in try fencedSources(subdirectories: ["Views", "Components"]) {
            let range = NSRange(text.startIndex..., in: text)
            argumentPattern.enumerateMatches(in: text, range: range) { match, _, _ in
                guard let match, let argRange = Range(match.range(at: 1), in: text) else { return }
                let argument = String(text[argRange])
                let argNSRange = NSRange(argument.startIndex..., in: argument)
                integerLiteral.enumerateMatches(in: argument, range: argNSRange) { literal, _, _ in
                    guard let literal, let valueRange = Range(literal.range(at: 1), in: argument),
                          let value = Int(argument[valueRange]) else { return }
                    if value >= 4 {
                        XCTAssertEqual(
                            value % 4, 0,
                            "\(name) uses directional padding literal \(value)pt in `.padding(.edge, ...)` — structural spacing must be a multiple of 4 (DESIGN.md v4 spacing grid)"
                        )
                    }
                }
            }
        }
    }
}
