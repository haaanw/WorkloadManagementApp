import XCTest

/// App-wide design-fence — DESIGN.md v6 "Field Notes" (2026-07-30), an overlay on v5 "Pavilion".
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
/// The v6 laws added on top (fences 7–8):
/// 7. **Metric identities** — the five icon-derived hues exist, carry the exact
///    `design-system/tokens/colors.css` values, and are a CLOSED set; the retired v5 near-gray
///    zone values are gone.
/// 8. **Two-Voice Type Law** — Fragment Mono is sanctioned for ANNOTATION ONLY: the face name
///    lives only in `FontTokens.swift`, the ≤12pt cap is enforced by clamping rather than by
///    documentation, annotation choreography has exactly one implementation, and the Alpino
///    display face is banned in the app (marketing/slides only). `IBMPlexMono` and
///    `SourceSerif4` stay banned by fence 4 — a mono above 12pt is still the retired v4 mistake.
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

    // MARK: - 7. v6 "Field Notes": metric hues are the only new colors

    func test_metricHueTokens_existAndAreComplete() throws {
        // The five icon-derived metric identities (DESIGN.md v6). Each metric owns its hue, so a
        // legend is never needed — and the set is CLOSED: adding a sixth is a design decision,
        // not a token addition. Values must match `design-system/tokens/colors.css` exactly.
        // Full enumeration, then filter — `fencedSources` carries a >50-file sanity guard that a
        // single-subdirectory call would trip.
        let colorTokens = try fencedSources()
            .first { $0.name == "ColorTokens.swift" }
        let text = try XCTUnwrap(colorTokens?.text, "ColorTokens.swift not found in the fenced sources")

        let requiredHues = [
            ("metricReadiness", "0x2E7D4F"),
            ("metricRecovery",  "0x1D7189"),
            ("metricSleep",     "0x52589E"),
            ("metricStrain",    "0xA8442D"),
            ("metricLoad",      "0x8A6810")
        ]
        for (token, hex) in requiredHues {
            XCTAssertTrue(
                text.contains("static let \(token)"),
                "ColorTokens is missing the v6 metric hue `\(token)` (DESIGN.md v6 metric identities)"
            )
            XCTAssertTrue(
                text.contains(hex),
                "ColorTokens.\(token) must be \(hex) — the value in design-system/tokens/colors.css"
            )
        }

        // The set is closed: exactly five `metric*` tokens, no more.
        let metricDeclarations = try NSRegularExpression(pattern: #"static let (metric[A-Za-z]+)\s*="#)
        let range = NSRange(text.startIndex..., in: text)
        var found: Set<String> = []
        metricDeclarations.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match, let r = Range(match.range(at: 1), in: text) else { return }
            found.insert(String(text[r]))
        }
        // `metricHues` is the canonical array, not a sixth hue.
        found.remove("metricHues")
        XCTAssertEqual(
            found, Set(requiredHues.map(\.0)),
            "The v6 metric-hue set is closed at five. Unexpected/missing metric tokens: \(found.symmetricDifference(Set(requiredHues.map(\.0)))) — adding a hue is a design change (DESIGN.md v6)"
        )
    }

    func test_retunedZoneColors_matchV6() throws {
        // v6 re-tuned all four zone colors for gym-floor legibility. The v5 near-gray values are
        // retired and must not linger. The label-first Zone Color Rule is unchanged and is
        // enforced separately (TodayVerdictCardGuardTests) — this fence only pins the values.
        // Full enumeration, then filter — `fencedSources` carries a >50-file sanity guard that a
        // single-subdirectory call would trip.
        let colorTokens = try fencedSources()
            .first { $0.name == "ColorTokens.swift" }
        let text = try XCTUnwrap(colorTokens?.text, "ColorTokens.swift not found in the fenced sources")

        for hex in ["0x2E7D4F", "0x8A5C08", "0x9E3428", "0x52589E"] {
            XCTAssertTrue(text.contains(hex), "ColorTokens is missing the v6 zone value \(hex)")
        }
        for retired in ["0x3F5A46", "0x6E5624", "0x7E362E", "0x46525E"] {
            XCTAssertFalse(
                text.contains(retired),
                "ColorTokens still carries the retired v5 zone value \(retired) — v6 re-tuned the zone palette"
            )
        }
    }

    // MARK: - 8. v6: Fragment Mono is sanctioned for ANNOTATION ONLY

    func test_annotationFace_reachableOnlyViaFontTokens() throws {
        // Same law as the working voice: the face name is a FontTokens-only literal. Everywhere
        // else reaches Fragment Mono through `Font.Tokens.anno` / `.annoSmall` (or, preferably,
        // the `AnnotationLabel` primitive), never by name.
        for (name, text) in try fencedSources() {
            if name == "FontTokens.swift" { continue }
            XCTAssertFalse(
                text.contains("FragmentMono"),
                "\(name) names the annotation face directly — Fragment Mono is reachable only via Font.Tokens.anno / .annoSmall (DESIGN.md v6 Two-Voice Type Law)"
            )
        }
    }

    func test_annotationSizeCap_isEnforcedAndNotBypassed() throws {
        // The ≤12pt cap is the whole difference between v6's annotation layer and the RETIRED v4
        // mono dial voice (a mono at 30–64pt). It must be enforced by clamping inside the
        // chokepoint — not merely documented — so no future token can raise it.
        let fontTokens = try fencedSources()
            .first { $0.name == "FontTokens.swift" }
        let text = try XCTUnwrap(fontTokens?.text, "FontTokens.swift not found in the fenced sources")

        XCTAssertTrue(
            text.contains("annoSizeCap"),
            "FontTokens must declare `annoSizeCap` — the v6 annotation size ceiling"
        )
        XCTAssertTrue(
            text.contains("annoSizeCap: CGFloat = 12"),
            "The v6 annotation cap must be 12pt (DESIGN.md v6: Fragment Mono never renders above 12pt)"
        )
        XCTAssertTrue(
            text.contains("min(size, Tokens.annoSizeCap)"),
            "`annoCascaded` must CLAMP to annoSizeCap, not just document it — a larger request has to be unrepresentable, which is what keeps the retired v4 dial-voice mistake out (DESIGN.md v6)"
        )

        // Only the two sanctioned annotation tokens may exist, at exactly 12pt and 10pt.
        XCTAssertTrue(text.contains("static let anno = annoCascaded(size: 12)"),
                      "Font.Tokens.anno must be Fragment Mono at 12pt")
        XCTAssertTrue(text.contains("static let annoSmall = annoCascaded(size: 10)"),
                      "Font.Tokens.annoSmall must be Fragment Mono at 10pt")

        let annoCalls = try NSRegularExpression(pattern: #"annoCascaded\(size:\s*(\d+)\)"#)
        let range = NSRange(text.startIndex..., in: text)
        annoCalls.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match, let r = Range(match.range(at: 1), in: text),
                  let size = Int(text[r]) else { return }
            XCTAssertLessThanOrEqual(
                size, 12,
                "FontTokens builds an annotation font at \(size)pt — above the 12pt v6 cap (DESIGN.md v6)"
            )
        }
    }

    func test_annotationChoreography_hasOneImplementation() throws {
        // v6's staggered annotation reveal is a chokepoint primitive, like Motion itself. If a
        // screen hand-rolls a delayed opacity stagger, the 40ms grammar drifts per surface — the
        // exact failure the primitive exists to prevent.
        let cardStyle = try fencedSources()
            .first { $0.name == "CardStyle.swift" }
        let text = try XCTUnwrap(cardStyle?.text, "CardStyle.swift not found in the fenced sources")

        XCTAssertTrue(
            text.contains("func annotationReveal("),
            "CardStyle.swift must define the `.annotationReveal(index:)` primitive (DESIGN.md v6 annotation choreography)"
        )
        XCTAssertTrue(
            text.contains("static let anno = snap(0.18)"),
            "Motion must carry the v6 `anno` token (180ms, --dur-anno) so the annotation fade is not a call-site literal"
        )
        XCTAssertTrue(
            text.contains("Motion.annoSurfaceSettle"),
            "The annotation reveal must delay past `Motion.annoSurfaceSettle` — labels arrive AFTER the surface settles (DESIGN.md v6)"
        )

        // Nobody outside the chokepoint may define their own annotation stagger modifier.
        for (name, source) in try fencedSources() {
            if name == "CardStyle.swift" { continue }
            XCTAssertFalse(
                source.contains("AnnotationRevealModifier"),
                "\(name) defines or references the private annotation-reveal modifier — consume `.annotationReveal(index:)` instead (DESIGN.md v6)"
            )
        }
    }

    func test_alpinoDisplayFace_bannedInApp() throws {
        // Alpino is the v6 DISPLAY voice — marketing surfaces and slides only. It is not bundled
        // in the app target and must never be referenced from app code (readme.md: "never app UI").
        for (name, text) in try fencedSources() {
            XCTAssertFalse(
                text.contains("Alpino"),
                "\(name) references Alpino — the display face is marketing/slides only and is banned in the app (DESIGN.md v6)"
            )
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
