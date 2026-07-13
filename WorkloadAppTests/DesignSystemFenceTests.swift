import XCTest

/// App-wide design-fence — DESIGN.md v3 "Ink & Grain" (2026-07-14).
///
/// Source-grep fences over the styled SwiftUI layer (`Views/`, `Components/`, `Utilities/`,
/// plus the live SwiftUI app files in `App/`). The retired UIKit shell
/// (`AppShell.swift` / `AppShellUIKitPrimitives.swift`) is excluded — it is scheduled for
/// deletion after v1.6 validates and must merely keep compiling.
///
/// The v3 laws these enforce:
/// 1. **Corner Law** — radii are legal (0pt rule retired) but only via `CornerTokens`
///    (card 12 / control 8 / pill). Hand-typed radius literals are a fence failure.
/// 2. **No shadows** — elevation stays plane + hairline, never blur.
/// 3. **No hardcoded colors in views** — everything routes through `ColorTokens`.
/// 4. **Two-Voice Type Law** — the serif's PostScript name lives ONLY in `FontTokens.swift`
///    (`serifDisplay(size:)` is the single chokepoint); no `.system(` fonts.
/// 5. **Halftone Law** — the dot signature exists only as the `HalftoneField` component,
///    hero plane only: at most one instantiation per screen file.
/// 6. **Spacing grid** — structural `spacing:` / bare `.padding(` literals of 4pt and above
///    must be multiples of 4 (8pt grid + the sanctioned 4pt `baselinePair`).
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
                    "\(name) uses a corner radius without CornerTokens — hand-typed radii are banned (DESIGN.md v3 Corner Law: card 12 / control 8 / pill)"
                )
            }
        }
    }

    // MARK: - 2. No shadows anywhere

    func test_noShadowModifiers() throws {
        for (name, text) in try fencedSources() {
            XCTAssertFalse(
                text.contains(".shadow("),
                "\(name) contains .shadow( — DESIGN.md v3 keeps the no-shadow law; elevation is plane + hairline only"
            )
        }
    }

    // MARK: - 3. No hardcoded colors in the view layer

    func test_noHardcodedColors_inViewsAndComponents() throws {
        for (name, text) in try fencedSources(subdirectories: ["Views", "Components"]) {
            for banned in ["Color(red:", "#colorLiteral", "UIColor(red:"] {
                XCTAssertFalse(
                    text.contains(banned),
                    "\(name) contains \(banned) — colors must come from ColorTokens (DESIGN.md v3)"
                )
            }
        }
    }

    // MARK: - 4. Two-Voice Type Law: serif name only in FontTokens; no .system( fonts

    func test_serifFontName_onlyInFontTokens() throws {
        for (name, text) in try fencedSources() {
            if name == "FontTokens.swift" { continue }
            XCTAssertFalse(
                text.contains("SourceSerif4"),
                "\(name) names the serif directly — Source Serif 4 is reachable only via Font.Tokens.displayScore / .displayVerdict (DESIGN.md v3 Two-Voice Type Law)"
            )
        }
    }

    func test_noSystemFonts_inViewsAndComponents() throws {
        for (name, text) in try fencedSources(subdirectories: ["Views", "Components"]) {
            XCTAssertFalse(
                text.contains(".system("),
                "\(name) contains .system( — all type goes through Font.Tokens.* (DESIGN.md v3)"
            )
        }
    }

    // MARK: - 5. Halftone Law: component-only, at most one per screen file

    func test_halftone_atMostOnePerScreenFile() throws {
        for (name, text) in try fencedSources() {
            if name == "HalftoneField.swift" { continue }
            let count = text.components(separatedBy: "HalftoneField(").count - 1
            XCTAssertLessThanOrEqual(
                count, 1,
                "\(name) instantiates HalftoneField \(count) times — the halftone signature is hero-plane-only, at most ONE per screen (DESIGN.md v3 Halftone Law)"
            )
        }
    }

    // MARK: - 6. Spacing grid: structural literals are multiples of 4

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
                            "\(name) uses structural spacing literal \(value)pt — structural spacing must be a multiple of 4 (DESIGN.md v3 spacing grid)"
                        )
                    }
                }
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
                            "\(name) uses directional padding literal \(value)pt in `.padding(.edge, ...)` — structural spacing must be a multiple of 4 (DESIGN.md v3 spacing grid)"
                        )
                    }
                }
            }
        }
    }
}
