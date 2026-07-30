import SwiftUI
import UIKit
import CoreText

/// Type scale for the app — the DESIGN.md v6 "Field Notes" **Two-Voice Type Law**:
///
/// Two faces, strictly disjoint jobs. The split is by *function*, not by taste:
///
/// - **Working voice — Instrument Sans** (static Regular 400 + Medium 500): everything the app
///   *says*. Titles, body, labels, values, CTAs, tab labels. All hierarchy through size and the
///   single weight step — no bold, no italic, no semantic styles.
/// - **Annotation voice — Fragment Mono** (Regular only), via `anno` (12pt) / `annoSmall` (10pt)
///   and the `.annotation()` modifier: everything the app *annotates*. Units, deltas,
///   timestamps, axis labels, reason trees, machine keys. **≤12pt hard cap** (see
///   `annoSizeCap`). It annotates; it never speaks a sentence, a headline, or a CTA label.
///
/// Both faces carry a UIFontDescriptor cascade fallback to Noto Sans SC for CJK glyphs —
/// Noto is a fallback, not a third voice.
///
/// - **Numerals:** both faces carry tabular figures; every data numeral applies
///   `.monospacedDigit()` at the call site.
///
/// RETIRED voices (do not reintroduce; names are fence-banned app-wide):
/// - v3 serif display voice (Source Serif 4) — retired 2026-07-20.
/// - v4 mono **dial** voice (IBM Plex Mono) — retired 2026-07-21. Note the distinction from
///   v6's annotation layer: the dial voice was a mono at 30–64pt DISPLAY size. A mono above
///   12pt is still a violation; `annoCascaded` clamps to make it unrepresentable.
/// - **Alpino** (the display face in `design-system/fonts/`) is marketing/slides ONLY and is
///   fence-banned in the app.
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
            "FragmentMono-Regular",
            "NotoSansSC-Regular",
            "NotoSansSC-Medium"
        ]

        // MARK: - Annotation voice (DESIGN.md v6 "Field Notes")

        /// The HARD size cap on the annotation voice: Fragment Mono may never render above
        /// 12pt. Enforced in `annoCascaded` by clamping, so no call site — and no future token
        /// — can raise it. v4's mistake was a mono at DISPLAY size (the retired IBM Plex Mono
        /// dial voice, 30–64pt); v6's mono is marginalia and nothing else.
        static let annoSizeCap: CGFloat = 12

        /// 12pt Fragment Mono — the standard annotation size. Units, deltas, timestamps,
        /// machine keys, reason trees.
        ///
        /// Prefer the `.annotation()` view modifier over setting this font directly: the
        /// modifier also applies the uppercase transform, the +0.05em tracking, and the
        /// locale guard (zh-Hans takes neither), which are part of the annotation law rather
        /// than a call-site choice.
        static let anno = annoCascaded(size: 12)

        /// 11pt Fragment Mono — chart axis labels and timestamps, the small annotation size.
        ///
        /// Raised from 10pt to 11pt (v6.1, HAN 2026-07-30): Fragment Mono uppercase with +0.05em
        /// tracking is the densest text the app renders, and at 10pt it read as too small on
        /// device. 11pt is the same size as `micro`, remains a step below `anno` (12pt) so the two
        /// annotation sizes stay distinguishable, and is still under `annoSizeCap`.
        static let annoSmall = annoCascaded(size: 11)

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

        /// 12pt — micro labels, all-caps. Apply .tracking(≈0.9) and .textCase(.uppercase)
        /// at the call site (0.9 ≈ 0.075em at 12pt — the law says ≈, call sites stay).
        /// Raised 11→12pt (v6.2, HAN 2026-07-30): tracked caps at 11pt were the smallest
        /// working-voice text on screen and read as too small on device — this token draws
        /// the HRV TREND / LOAD TREND section heads. 12pt keeps it below smallLabel (13pt),
        /// so the ramp's steps survive.
        static let micro       = cascaded(size: 12, weight: .regular)

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

    /// Construct an ANNOTATION font: Fragment Mono primary, Noto Sans SC cascade fallback.
    ///
    /// The DESIGN.md v6 ≤12pt cap is enforced HERE by clamping, not documented at call sites —
    /// `Font.Tokens.annoSizeCap` is the ceiling and a larger request is silently reduced to it
    /// rather than honored. That makes "a mono at display size" unrepresentable in the type
    /// system's only route to the face, which is the point: the retired v4 dial voice was
    /// exactly that mistake.
    ///
    /// Fragment Mono ships a single Regular face (no Medium) — correct for annotation, which
    /// carries no weight hierarchy. PostScript name `FragmentMono-Regular`, a static face
    /// (verified via name-table dump 2026-07-30: no `fvar`, so no variable-font PS-name trap).
    private static func annoCascaded(size: CGFloat) -> Font {
        let cappedSize = min(size, Tokens.annoSizeCap)
        let primaryName = "FragmentMono-Regular"
        let cjkName     = "NotoSansSC-Regular"

        guard UIFont(name: primaryName, size: cappedSize) != nil else {
            // Not registered (missing from bundle / Info.plist) — degrade honestly to the
            // system monospaced face rather than letting a bad descriptor pick one silently.
            return Font(UIFont.monospacedSystemFont(ofSize: cappedSize, weight: .regular))
        }

        let descriptor = UIFontDescriptor(name: primaryName, size: cappedSize)
            .addingAttributes([
                UIFontDescriptor.AttributeName.cascadeList: [
                    UIFontDescriptor(fontAttributes: [.name: cjkName])
                ]
            ])
        return Font(UIFont(descriptor: descriptor, size: cappedSize))
    }
}
