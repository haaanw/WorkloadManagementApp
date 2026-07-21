import SwiftUI
import UIKit
import CoreText

/// Type scale for the app — the DESIGN.md v5 "Pavilion" One-Voice Type Law:
///
/// - **One voice:** Instrument Sans (static Regular 400 + Medium 500 faces), with a
///   UIFontDescriptor cascade fallback to Noto Sans SC for CJK glyphs. All hierarchy is
///   achieved through size and the single weight step — no bold, no italic, no semantic
///   styles, no second face.
/// - **Numerals:** Instrument Sans carries the `tnum` feature; every data numeral applies
///   `.monospacedDigit()` at the call site (v1 law restored).
///
/// RETIRED voices (do not reintroduce; names are fence-banned app-wide):
/// - v3 serif display voice (Source Serif 4) — retired 2026-07-20.
/// - v4 mono dial voice (IBM Plex Mono) — retired 2026-07-21 with v5; data numerals use
///   the one-voice ramp + .monospacedDigit().
///
/// Usage: `.font(.Tokens.body)` or `.font(Font.Tokens.heroScore)`
///
/// Glyph routing (single point of change for the whole app per phase 23):
/// - Latin / digits / punctuation render via Instrument Sans.
/// - CJK glyphs (and any glyph the primary face lacks) cascade to Noto Sans SC
///   (PostScript: NotoSansSC-Regular / -Medium). Cascade built via
///   UIFontDescriptor.AttributeName.cascadeList with PostScript names (23-RESEARCH Pitfall 3).
///
/// Static faces on purpose: the GeneralSans variable font declared no instance PostScript
/// names, so per-weight lookups silently fell back to the system face (found 2026-07-17).
/// InstrumentSans-{Regular,Medium}.ttf are static faces whose PostScript names resolve
/// directly (verified via fontTools name-table dump 2026-07-21; re-verify on-sim via the
/// DEBUG family dump before declaring the pivot rendered).
///
/// Note: InstrumentSans-{Regular,Medium}.ttf and NotoSansSC-{Regular,Medium}.otf must be
/// in the Xcode project and registered in Info.plist under UIAppFonts.
extension Font {

    enum Tokens {
        /// The exact PostScript names this chokepoint resolves at runtime. The DEBUG launch
        /// assert in WorkloadApp.swift consumes this list — font literals live HERE only.
        static let requiredPostScriptNames = [
            "InstrumentSans-Regular",
            "InstrumentSans-Medium",
            "NotoSansSC-Regular",
            "NotoSansSC-Medium"
        ]

        /// 64pt — the hero readiness score: the ONE colored text element in the app
        /// (rendered in `ColorTokens.accent`). Apply .monospacedDigit() at the call site.
        static let heroScore   = cascaded(size: 64, weight: .regular)

        /// 64pt — large numeric instrument values. Apply .monospacedDigit() at the call site.
        static let displayMetric = heroScore

        /// 32pt — dominant action / verdict copy and standing display values.
        static let displayAction = cascaded(size: 32, weight: .regular)

        /// 28pt — page title (v1 editorial style restored: sentence case, Regular; the v4
        /// micro-caps titlebar is retired).
        static let pageTitle   = cascaded(size: 28, weight: .regular)

        /// 28pt — the v5 screen title (ScreenHeader). Sentence case — alias of `pageTitle`.
        static let screenTitle = pageTitle

        /// 10pt Medium — the screen header's trailing action slot.
        static let headerAction = cascaded(size: 10, weight: .medium)

        /// 11pt Medium — decision-key cell and CTA labels (sentence case in v5;
        /// the v4 micro-caps tracking is retired).
        static let keyLabel = cascaded(size: 11, weight: .medium)

        /// 11pt Medium — tab-bar item labels (title case, modest tracking at the render site).
        static let tabLabel = cascaded(size: 11, weight: .medium)

        /// 17pt Medium — section header (v1 scale restored; was 19pt in v3/v4).
        static let sectionHead = cascaded(size: 17, weight: .medium)

        /// 17pt Medium — section title
        static let sectionTitle = sectionHead

        /// 17pt — body copy, metric values
        static let body        = cascaded(size: 17, weight: .regular)

        /// 17pt Medium — active state labels (context switcher, selected states)
        static let bodyMedium  = cascaded(size: 17, weight: .medium)

        /// 15pt — secondary info, factor labels
        static let label       = cascaded(size: 15, weight: .regular)

        /// 15pt Medium — emphasized secondary info
        static let labelMedium = cascaded(size: 15, weight: .medium)

        /// 13pt — component labels, banner text
        static let smallLabel  = cascaded(size: 13, weight: .regular)

        /// 13pt — caption text
        static let caption     = smallLabel

        /// 13pt Medium — component emphasis
        static let smallLabelMedium = cascaded(size: 13, weight: .medium)

        /// 11pt — micro labels, all-caps (v1 scale restored). Apply .tracking(≈0.08em → 0.9)
        /// and .textCase(.uppercase) at the call site.
        static let micro       = cascaded(size: 11, weight: .regular)

    }

    /// Construct a Font whose primary glyph face is Instrument Sans and whose cascade
    /// fallback is Noto Sans SC for any glyph the primary lacks (CJK, fullwidth punctuation).
    ///
    /// The cascade is glyph-by-glyph: Latin chars stay on Instrument Sans even when
    /// interleaved with Chinese in the same string. This is the single point of change that
    /// gives every Font.Tokens.* call site mixed-script harmony without per-string font logic.
    ///
    /// PostScript names (static faces — resolve directly, no variation axis):
    /// - InstrumentSans-Regular / InstrumentSans-Medium
    /// - NotoSansSC-Regular / NotoSansSC-Medium
    private static func cascaded(size: CGFloat, weight: UIFont.Weight) -> Font {
        let primaryName = (weight == .medium) ? "InstrumentSans-Medium" : "InstrumentSans-Regular"
        let cjkName     = (weight == .medium) ? "NotoSansSC-Medium"     : "NotoSansSC-Regular"

        guard UIFont(name: primaryName, size: size) != nil else {
            // Font not registered (missing from bundle / Info.plist) — degrade honestly to
            // the system face rather than letting an unresolvable descriptor pick one silently.
            return Font(UIFont.systemFont(ofSize: size, weight: weight))
        }

        let descriptor = UIFontDescriptor(name: primaryName, size: size)
            .addingAttributes([
                UIFontDescriptor.AttributeName.cascadeList: [
                    UIFontDescriptor(fontAttributes: [.name: cjkName])
                ]
            ])
        return Font(UIFont(descriptor: descriptor, size: size))
    }
}
