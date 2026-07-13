import SwiftUI
import UIKit
import CoreText

/// Type scale for the app — the DESIGN.md v3 "Ink & Grain" two-voice system:
///
/// - **Instrument voice** (everything): General Sans Variable (Regular + Medium weights)
///   with a UIFontDescriptor cascade fallback to Noto Sans SC for CJK glyphs.
/// - **Display voice** (exactly two roles): Source Serif 4 Variable, weight 400, used ONLY
///   for the hero readiness score (`displayScore`) and the verdict headline (`displayVerdict`).
///   App-authored strings only — NEVER user content (session names, exercise names, notes).
///   zh display strings cascade to Noto Sans SC (no serif CJK font is bundled — intentional).
///
/// All hierarchy is achieved through size — no bold, italic, or semantic styles.
///
/// Usage: `.font(.Tokens.body)` or `.font(Font.Tokens.label)`
///
/// Glyph routing (single point of change for the whole app per phase 23):
/// - Latin / digits / punctuation render via General Sans (PostScript: GeneralSans-Regular / -Medium).
/// - CJK glyphs (and any glyph General Sans does not cover) cascade to Noto Sans SC
///   (PostScript: NotoSansSC-Regular / -Medium).
///
/// The cascade is built via UIFontDescriptor.AttributeName.cascadeList; PostScript names
/// (not family names) are used per 23-RESEARCH Pitfall 3.
///
/// Note: GeneralSans-Variable.ttf and NotoSansSC-{Regular,Medium}.otf must be added to the
/// Xcode project and registered in Info.plist under UIAppFonts.
extension Font {

    enum Tokens {
        /// 64pt — Readiness score. Accent color only. Apply .monospacedDigit() at the call site.
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

        // MARK: Display voice — Source Serif 4 (DESIGN.md v3 "Ink & Grain", 2026-07-14)

        /// Metrics for the two serif display roles. Sizes are Stage-1-tunable constants;
        /// tracking/line-height are applied at the call site (SwiftUI `.tracking()` takes points —
        /// use `Display.tracking(for:em:)`).
        enum Display {
            /// Hero readiness score point size (locked spec target ≈ 76–88pt; Stage 1 tunes on device).
            static let scoreSize: CGFloat = 84
            /// Verdict headline point size (locked spec target ≈ 24–26pt).
            static let verdictSize: CGFloat = 25
            /// Hero score letter-spacing, in em (spec ≈ -0.03em).
            static let scoreTrackingEm: CGFloat = -0.03
            /// Verdict headline letter-spacing, in em (spec ≈ -0.01em).
            static let verdictTrackingEm: CGFloat = -0.01
            /// Hero score line-height multiple (spec ≈ 0.95).
            static let scoreLineHeight: CGFloat = 0.95
            /// Verdict headline line-height multiple (spec ≈ 1.1).
            static let verdictLineHeight: CGFloat = 1.1
            /// Convert an em-tracking spec into the point value SwiftUI's `.tracking()` expects.
            static func tracking(for size: CGFloat, em: CGFloat) -> CGFloat { size * em }
        }

        /// Source Serif 4 Regular, `Display.scoreSize` — the hero readiness score ONLY.
        /// Accent color only. Apply `.monospacedDigit()` and score tracking at the call site.
        static let displayScore   = serifDisplay(size: Display.scoreSize)

        /// Source Serif 4 Regular, `Display.verdictSize` — the verdict headline ONLY (`--text-1`).
        static let displayVerdict = serifDisplay(size: Display.verdictSize)
    }

    /// Construct a display-voice Font: Source Serif 4 (variable, wght 400, opsz pinned to the
    /// display end of the axis) cascading to Noto Sans SC for CJK glyphs.
    ///
    /// Sanctioned roles per DESIGN.md v3: hero readiness score + verdict headline. Nothing else.
    /// App-authored strings only — never user content.
    ///
    /// PostScript name (Google Fonts variable build, default named instance, verified via
    /// fontTools fvar dump): `SourceSerif4Roman-Regular`.
    ///
    /// Graceful fallback: if the serif face is not registered (font file missing from the
    /// bundle / Info.plist), this degrades to the General Sans instrument voice at the same
    /// size instead of crashing or snapping to San Francisco.
    static func serifDisplay(size: CGFloat) -> Font {
        let serifName = "SourceSerif4Roman-Regular"
        guard UIFont(name: serifName, size: size) != nil else {
            // SourceSerif4-Variable.ttf not registered — degrade to the instrument voice.
            return cascaded(size: size, weight: .regular)
        }

        let cjkDescriptor = UIFontDescriptor(fontAttributes: [.name: "NotoSansSC-Regular"])
        // Pin the optical-size axis ('opsz', max 60 = display cut) so large sizes render the
        // display drawing rather than the 20pt text default. 'wght' stays at the 400 default.
        let variation: [Int: Double] = [0x6F70737A: 60.0] // 'opsz'
        let descriptor = UIFontDescriptor(name: serifName, size: size)
            .addingAttributes([
                UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variation,
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
    /// PostScript names (verified via UIFont.fontNames(forFamilyName:) at runtime):
    /// - GeneralSans-Regular / GeneralSans-Medium
    /// - NotoSansSC-Regular / NotoSansSC-Medium
    private static func cascaded(size: CGFloat, weight: UIFont.Weight) -> Font {
        let cjkDescriptor: UIFontDescriptor = (weight == .medium)
            ? UIFontDescriptor(fontAttributes: [.name: "NotoSansSC-Medium"])
            : UIFontDescriptor(fontAttributes: [.name: "NotoSansSC-Regular"])

        let primaryName = (weight == .medium) ? "GeneralSans-Medium" : "GeneralSans-Regular"
        let primaryDescriptor = UIFontDescriptor(name: primaryName, size: size)
            .addingAttributes([
                UIFontDescriptor.AttributeName.cascadeList: [cjkDescriptor]
            ])

        return Font(UIFont(descriptor: primaryDescriptor, size: size))
    }
}
