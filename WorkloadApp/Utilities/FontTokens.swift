import SwiftUI
import UIKit

/// Type scale for the app, using General Sans Variable (Regular + Medium weights)
/// with a UIFontDescriptor cascade fallback to Noto Sans SC for CJK glyphs.
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
