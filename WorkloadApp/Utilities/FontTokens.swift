import SwiftUI

/// Type scale for the app, using DM Sans Regular (400) and Medium (500) only.
/// All hierarchy is achieved through size — no bold, italic, or semantic styles.
///
/// Usage: `.font(.Tokens.body)` or `.font(Font.Tokens.label)`
///
/// Note: DMSans-Regular.otf and DMSans-Medium.otf must be added to the Xcode
/// project and registered in Info.plist under UIAppFonts.
extension Font {
    enum Tokens {
        /// 56pt — Readiness score. Accent color only. Apply .monospacedDigit() at the call site.
        static let heroScore   = Font.custom("DMSans-Regular", size: 56)

        /// 28pt — Page title
        static let pageTitle   = Font.custom("DMSans-Regular", size: 28)

        /// 17pt Medium — Section header
        static let sectionHead = Font.custom("DMSans-Medium",  size: 17)

        /// 15pt — Body copy, metric values
        static let body        = Font.custom("DMSans-Regular", size: 15)

        /// 15pt Medium — active state labels (context switcher, selected states)
        static let bodyMedium  = Font.custom("DMSans-Medium",  size: 15)

        /// 13pt — Secondary info, factor labels
        static let label       = Font.custom("DMSans-Regular", size: 13)

        /// 11pt — Micro labels, all-caps. Apply .tracking(1.2) and .textCase(.uppercase) at call site.
        static let micro       = Font.custom("DMSans-Regular", size: 11)
    }
}
