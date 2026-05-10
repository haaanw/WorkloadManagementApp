import SwiftUI

/// Type scale for the app, using Alpino Regular and Medium only.
/// All hierarchy is achieved through size — no bold, italic, or semantic styles.
///
/// Usage: `.font(.Tokens.body)` or `.font(Font.Tokens.label)`
///
/// Note: Alpino-Regular.otf and Alpino-Medium.otf must be added to the Xcode
/// project and registered in Info.plist under UIAppFonts.
extension Font {
    enum Tokens {
        /// 64pt — Readiness score. Accent color only. Apply .monospacedDigit() at the call site.
        static let heroScore   = Font.custom("Alpino-Regular", size: 64)

        /// 32pt — Page title
        static let pageTitle   = Font.custom("Alpino-Regular", size: 32)

        /// 19pt Medium — Section header
        static let sectionHead = Font.custom("Alpino-Medium",  size: 19)

        /// 17pt — Body copy, metric values
        static let body        = Font.custom("Alpino-Regular", size: 17)

        /// 17pt Medium — active state labels (context switcher, selected states)
        static let bodyMedium  = Font.custom("Alpino-Medium",  size: 17)

        /// 15pt — Secondary info, factor labels
        static let label       = Font.custom("Alpino-Regular", size: 15)

        /// 15pt Medium — emphasized secondary info
        static let labelMedium = Font.custom("Alpino-Medium",  size: 15)

        /// 13pt — Component labels, banner text
        static let smallLabel  = Font.custom("Alpino-Regular", size: 13)

        /// 13pt Medium — Component emphasis
        static let smallLabelMedium = Font.custom("Alpino-Medium", size: 13)

        /// 12pt — Micro labels, all-caps. Apply .tracking(1.2) and .textCase(.uppercase) at call site.
        static let micro       = Font.custom("Alpino-Regular", size: 12)
    }
}
