import SwiftUI
import UIKit
import CoreText

/// Type scale for the app — the DESIGN.md v4 "Instrument" two-voice system:
///
/// - **UI voice** (everything textual): General Sans Variable (Regular + Medium weights)
///   with a UIFontDescriptor cascade fallback to Noto Sans SC for CJK glyphs.
/// - **Dial voice** (data numerals): IBM Plex Mono (static Regular/Medium/SemiBold), used
///   ONLY via the `dial*` tokens for instrument readings — scores, weights, metric values,
///   tick numerals, units. App-authored numerals/units only — never body copy, never user
///   content. Being a monospace face, all digits are tabular by construction (the
///   `.monospacedDigit()` call-site convention is satisfied inherently).
///
/// The v3 serif display voice (Source Serif 4, `displayScore`/`displayVerdict`) is RETIRED
/// as of v4 (2026-07-20) — the font file, tokens, and chokepoint are deleted.
///
/// All hierarchy is achieved through size — no bold, no italic, no semantic styles.
///
/// Usage: `.font(.Tokens.body)` or `.font(Font.Tokens.dialHero)`
///
/// Glyph routing (single point of change for the whole app per phase 23):
/// - Latin / digits / punctuation render via the primary face.
/// - CJK glyphs (and any glyph the primary face does not cover) cascade to Noto Sans SC
///   (PostScript: NotoSansSC-Regular / -Medium). Dial tokens carry the same defensive
///   cascade even though their content is app-authored numerals/units.
///
/// The cascade is built via UIFontDescriptor.AttributeName.cascadeList; PostScript names
/// (not family names) are used per 23-RESEARCH Pitfall 3.
///
/// Note: GeneralSans-Variable.ttf, IBMPlexMono-{Regular,Medium,SemiBold}.ttf and
/// NotoSansSC-{Regular,Medium}.otf must be added to the Xcode project and registered in
/// Info.plist under UIAppFonts.
extension Font {

    enum Tokens {
        /// The exact PostScript names this chokepoint resolves at runtime. The DEBUG launch
        /// assert in WorkloadApp.swift consumes this list — the names live HERE so the
        /// mono-name fence (Two-Voice Type Law) keeps every font literal in this one file.
        /// Plex Mono PS names verified at runtime via the DEBUG family dump 2026-07-20.
        static let requiredPostScriptNames = [
            "GeneralSansVariable-Bold",
            "IBMPlexMono-Regular",
            "IBMPlexMono-Medium",
            "IBMPlexMono-SemiBold",
            "NotoSansSC-Regular",
            "NotoSansSC-Medium"
        ]

        /// 64pt — Large numeric instrument values in the UI voice (legacy role; new hero
        /// readings use `dialHero`). Apply .monospacedDigit() at the call site.
        static let heroScore   = cascaded(size: 64, weight: .regular)

        /// 64pt — Large numeric instrument values. Apply .monospacedDigit() at the call site.
        static let displayMetric = heroScore

        /// 32pt — Dominant action or verdict copy.
        static let displayAction = cascaded(size: 32, weight: .regular)

        /// 32pt — Page title
        static let pageTitle   = cascaded(size: 32, weight: .regular)

        /// 32pt — Screen title
        static let screenTitle = pageTitle

        /// 19pt Medium — Section header
        static let sectionHead = cascaded(size: 19, weight: .medium)

        /// 19pt Medium — Section title
        static let sectionTitle = sectionHead

        /// 17pt — Body copy, metric values
        static let body        = cascaded(size: 17, weight: .regular)

        /// 17pt Medium — active state labels (context switcher, selected states)
        static let bodyMedium  = cascaded(size: 17, weight: .medium)

        /// 15pt — Secondary info, factor labels
        static let label       = cascaded(size: 15, weight: .regular)

        /// 15pt Medium — emphasized secondary info
        static let labelMedium = cascaded(size: 15, weight: .medium)

        /// 13pt — Component labels, banner text
        static let smallLabel  = cascaded(size: 13, weight: .regular)

        /// 13pt — Caption text
        static let caption     = smallLabel

        /// 13pt Medium — Component emphasis
        static let smallLabelMedium = cascaded(size: 13, weight: .medium)

        /// 12pt — Micro labels, all-caps. Apply .tracking(1.2) and .textCase(.uppercase) at call site.
        static let micro       = cascaded(size: 12, weight: .regular)

        // MARK: Dial voice — IBM Plex Mono (DESIGN.md v4 "Instrument", 2026-07-20)

        /// Metrics for the dial roles. Sizes are Stage-1″/2″-tunable constants; tracking is
        /// applied at the call site in points (`Dial.tracking(for:em:)` converts an em spec).
        enum Dial {
            /// Hero instrument reading point size (mockup D: 60px, −0.03em, line-height 0.95).
            static let heroSize: CGFloat = 60
            /// Standing dial value point size (mockup D `vnum`: 30px, −0.02em).
            static let valueSize: CGFloat = 30
            /// Inline dial value point size (mockup D `mrow b`: 13px).
            static let smallSize: CGFloat = 13
            /// Tick-numeral point size (mockup D scale nums: 8.5–10px band; token: 9).
            static let tickSize: CGFloat = 9
            /// Hero reading letter-spacing, in em (spec ≈ -0.03em).
            static let heroTrackingEm: CGFloat = -0.03
            /// Standing value letter-spacing, in em (spec ≈ -0.02em).
            static let valueTrackingEm: CGFloat = -0.02
            /// Convert an em-tracking spec into the point value SwiftUI's `.tracking()` expects.
            static func tracking(for size: CGFloat, em: CGFloat) -> CGFloat { size * em }
        }

        /// IBM Plex Mono Medium, `Dial.heroSize` (60pt) — the ONE hero instrument reading
        /// per screen (readiness score on the panel, ACWR hero). Tabular by construction.
        static let dialHero  = mono(size: Dial.heroSize, weight: .medium)

        /// IBM Plex Mono Medium, `Dial.valueSize` (30pt) — standing dial values
        /// (verdict weight, metric detail readings).
        static let dialValue = mono(size: Dial.valueSize, weight: .medium)

        /// IBM Plex Mono Medium, `Dial.smallSize` (13pt) — inline data readings
        /// (metric rows, table numerals, deltas).
        static let dialSmall = mono(size: Dial.smallSize, weight: .medium)

        /// IBM Plex Mono Regular, `Dial.tickSize` (9pt) — tick-scale numerals ONLY.
        static let dialTick  = mono(size: Dial.tickSize, weight: .regular)
    }

    /// Construct a dial-voice Font: IBM Plex Mono (static faces) cascading to Noto Sans SC
    /// for any non-covered glyph (defensive — dial content is app-authored numerals/units).
    ///
    /// Sanctioned roles per DESIGN.md v4: data numerals, units, and tick labels via the
    /// `dial*` tokens. Never body copy, never user content.
    ///
    /// PostScript names (static faces, verified at runtime via the DEBUG family dump):
    /// `IBMPlexMono-Regular`, `IBMPlexMono-Medium` (SemiBold bundled for Stage-2″ use).
    ///
    /// Graceful fallback: if the mono face is not registered (font file missing from the
    /// bundle / Info.plist), this degrades to the General Sans UI voice at the same size
    /// instead of crashing or snapping to San Francisco.
    private static func mono(size: CGFloat, weight: UIFont.Weight) -> Font {
        let monoName: String = switch weight {
        case .semibold: "IBMPlexMono-SemiBold"
        case .medium:   "IBMPlexMono-Medium"
        default:        "IBMPlexMono-Regular"
        }
        guard UIFont(name: monoName, size: size) != nil else {
            // IBM Plex Mono not registered — degrade to the UI voice.
            return cascaded(size: size, weight: weight == .regular ? .regular : .medium)
        }

        let cjkDescriptor: UIFontDescriptor = (weight == .regular)
            ? UIFontDescriptor(fontAttributes: [.name: "NotoSansSC-Regular"])
            : UIFontDescriptor(fontAttributes: [.name: "NotoSansSC-Medium"])
        let descriptor = UIFontDescriptor(name: monoName, size: size)
            .addingAttributes([
                UIFontDescriptor.AttributeName.cascadeList: [cjkDescriptor]
            ])
        return Font(UIFont(descriptor: descriptor, size: size))
    }

    /// Construct a Font whose primary glyph face is General Sans and whose cascade fallback
    /// is Noto Sans SC for any glyph the primary lacks (CJK, fullwidth punctuation, etc).
    ///
    /// The cascade is glyph-by-glyph: Latin chars stay on General Sans even when interleaved
    /// with Chinese in the same string. This is the single point of change that gives every
    /// Font.Tokens.* call site mixed-script harmony without per-string font logic.
    ///
    /// PostScript resolution (verified 2026-07-17 via fontTools fvar dump + on-sim launch):
    /// GeneralSans-Variable.ttf declares NO instance postscriptNameIDs, so per-weight names
    /// ("GeneralSans-Regular"/"GeneralSans-Medium") never register — requesting them made
    /// the descriptor fall back to the system face silently. The one registered face is the
    /// font's own PS name `GeneralSansVariable-Bold` (default instance, wght 700, axis
    /// 200–700); the UI weights are reached by pinning the 'wght' variation axis.
    /// - NotoSansSC-Regular / NotoSansSC-Medium (static faces, names resolve directly)
    private static func cascaded(size: CGFloat, weight: UIFont.Weight) -> Font {
        let cjkDescriptor: UIFontDescriptor = (weight == .medium)
            ? UIFontDescriptor(fontAttributes: [.name: "NotoSansSC-Medium"])
            : UIFontDescriptor(fontAttributes: [.name: "NotoSansSC-Regular"])

        let variableName = "GeneralSansVariable-Bold"
        guard UIFont(name: variableName, size: size) != nil else {
            // Font not registered (missing from bundle / Info.plist) — degrade honestly to
            // the system face rather than letting an unresolvable descriptor pick one silently.
            return Font(UIFont.systemFont(ofSize: size, weight: weight))
        }

        let wght: Double = (weight == .medium) ? 500.0 : 400.0
        let variation: [Int: Double] = [0x77676874: wght] // 'wght'
        let primaryDescriptor = UIFontDescriptor(name: variableName, size: size)
            .addingAttributes([
                UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variation,
                UIFontDescriptor.AttributeName.cascadeList: [cjkDescriptor]
            ])

        return Font(UIFont(descriptor: primaryDescriptor, size: size))
    }
}
