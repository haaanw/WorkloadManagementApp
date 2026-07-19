import XCTest

/// App-wide design-fence — DESIGN.md v4 "Instrument" (Aluminum Panel, 2026-07-20).
///
/// Source-grep fences over the styled SwiftUI layer (`Views/`, `Components/`, `Utilities/`,
/// plus the live SwiftUI app files in `App/`). The retired UIKit shell
/// (`AppShell.swift` / `AppShellUIKitPrimitives.swift`) is excluded — it is scheduled for
/// deletion after the pivot validates and must merely keep compiling.
///
/// The v4 laws these enforce:
/// 1. **Corner Law** — radii only via `CornerTokens` (card 5 / panel 5 / control 4;
///    pill demoted to chips). Hand-typed radius literals are a fence failure.
/// 2. **No shadows** — elevation stays plane + hairline, never blur.
/// 3. **No hardcoded colors in views** — everything routes through `ColorTokens`.
/// 4. **Two-Voice Type Law** — the dial voice's font name ("IBMPlexMono") lives ONLY in
///    `FontTokens.swift` (the `dial*` tokens are the single chokepoint); no `.system(` fonts.
///    The retired serif ("SourceSerif4") is BANNED app-wide — it must not reappear.
/// 5. **Spacing grid** — structural `spacing:` / bare `.padding(` literals of 4pt and above
///    must be multiples of 4 (8pt grid + the sanctioned 4pt `baselinePair`).
/// 6. **Motion Law** — one motion language: every animation routes through the `Motion`
///    tokens in CardStyle.swift. Ad-hoc curve/duration literals and bare `withAnimation`
///    (SwiftUI's default spring) are fence failures.
///
/// Retired v3 fences: the halftone fence was deleted with `HalftoneField` (v4 retires the
/// texture); the serif-chokepoint fence inverted into the app-wide SourceSerif4 ban.
final class DesignSystemFenceTests: XCTestCase {

    // MARK: - Source enumeration

    private static let excludedFiles: Set<String> = [
        "AppShell.swift",               // retired UIKit shell — do not touch, deleted post-v1.6
        "AppShellUIKitPrimitives.swift" // retired UIKit shell — do not touch, deleted post-v1.6
    ]

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
                    "\(name) uses a corner radius without CornerTokens — hand-typed radii are banned (DESIGN.md v4 Corner Law: card 5 / panel 5 / control 4)"
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

    // MARK: - 4. Two-Voice Type Law: mono name only in FontTokens; serif banned; no .system( fonts

    func test_monoFontName_onlyInFontTokens() throws {
        for (name, text) in try fencedSources() {
            if name == "FontTokens.swift" { continue }
            XCTAssertFalse(
                text.contains("IBMPlexMono"),
                "\(name) names the dial font directly — IBM Plex Mono is reachable only via Font.Tokens.dial* (DESIGN.md v4 Two-Voice Type Law)"
            )
        }
    }

    func test_sourceSerif_bannedAppWide() throws {
        // Fence inversion (v4): the v3 serif display voice is RETIRED. The name must not
        // reappear anywhere in the styled layer — including FontTokens.swift.
        for (name, text) in try fencedSources() {
            XCTAssertFalse(
                text.contains("SourceSerif4"),
                "\(name) references SourceSerif4 — the serif display voice was retired by DESIGN.md v4 \"Instrument\" (2026-07-20) and must not reappear"
            )
        }
    }

    func test_noSystemFonts_inViewsAndComponents() throws {
        for (name, text) in try fencedSources(subdirectories: ["Views", "Components"]) {
            XCTAssertFalse(
                text.contains(".system("),
                "\(name) contains .system( — all type goes through Font.Tokens.* (DESIGN.md v4)"
            )
        }
    }

    // MARK: - 4b. Panel Law: at most ONE black instrument panel per screen file

    func test_panelLaw_atMostOnePanelStylePerViewFile() throws {
        // DESIGN.md v4 Panel Law: the near-black panel carries the ONE hero instrument
        // reading per screen — a second dark surface on the same screen is a design error.
        // Enforced per screen file (mirrors the retired one-halftone-per-screen fence).
        for (name, text) in try fencedSources(subdirectories: ["Views"]) {
            let count = text.components(separatedBy: "panelStyle(").count - 1
            XCTAssertLessThanOrEqual(
                count, 1,
                "\(name) applies panelStyle( \(count) times — at most ONE black instrument panel per screen (DESIGN.md v4 Panel Law)"
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
