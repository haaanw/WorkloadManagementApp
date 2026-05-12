import SwiftUI

/// Type scale for the app, using General Sans Variable (Regular + Medium weights).
/// All hierarchy is achieved through size — no bold, italic, or semantic styles.
///
/// Usage: `.font(.Tokens.body)` or `.font(Font.Tokens.label)`
///
/// Note: GeneralSans-Variable.ttf must be added to the Xcode project and
/// registered in Info.plist under UIAppFonts. The variable font's weight axis
/// is used to select Regular (400) and Medium (500).
extension Font {
    /// The registered font family name for General Sans Variable.
    /// If this doesn't match at runtime, check the font's actual PostScript
    /// or family name via `UIFont.familyNames` logging.
    private static let gsFamilyName = "General Sans"

    enum Tokens {
        /// 64pt — Readiness score. Accent color only. Apply .monospacedDigit() at the call site.
        static let heroScore   = Font.custom(Font.gsFamilyName, size: 64).weight(.regular)

        /// 32pt — Page title
        static let pageTitle   = Font.custom(Font.gsFamilyName, size: 32).weight(.regular)

        /// 19pt Medium — Section header
        static let sectionHead = Font.custom(Font.gsFamilyName, size: 19).weight(.medium)

        /// 17pt — Body copy, metric values
        static let body        = Font.custom(Font.gsFamilyName, size: 17).weight(.regular)

        /// 17pt Medium — active state labels (context switcher, selected states)
        static let bodyMedium  = Font.custom(Font.gsFamilyName, size: 17).weight(.medium)

        /// 15pt — Secondary info, factor labels
        static let label       = Font.custom(Font.gsFamilyName, size: 15).weight(.regular)

        /// 15pt Medium — emphasized secondary info
        static let labelMedium = Font.custom(Font.gsFamilyName, size: 15).weight(.medium)

        /// 13pt — Component labels, banner text
        static let smallLabel  = Font.custom(Font.gsFamilyName, size: 13).weight(.regular)

        /// 13pt Medium — Component emphasis
        static let smallLabelMedium = Font.custom(Font.gsFamilyName, size: 13).weight(.medium)

        /// 12pt — Micro labels, all-caps. Apply .tracking(1.2) and .textCase(.uppercase) at call site.
        static let micro       = Font.custom(Font.gsFamilyName, size: 12).weight(.regular)
    }
}
