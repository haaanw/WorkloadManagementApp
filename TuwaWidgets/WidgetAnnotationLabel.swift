import SwiftUI

/// The widget-local annotation chokepoint — the extension's mirror of the app's
/// `AnnotationLabel` (`CardStyle.swift`), re-stated here because `CardStyle.swift`
/// carries app-only dependencies and does not join the extension target.
///
/// The law it enforces is identical (DESIGN.md v6 Two-Voice Type Law): Fragment Mono
/// via `Font.Tokens.anno`/`.annoSmall` ONLY (≤12pt, capped at the token), uppercase +
/// +0.05em tracking applied HERE and never at a call site, tabular digits, `text3`
/// default ink, and the zh-Hans guard (no case transform, no added tracking — CJK
/// takes neither).
///
/// Annotation is marginalia: keys (`READINESS`, `ACWR`), timestamps, axis labels.
/// Never a sentence — the verdict line renders in the working voice.
struct WidgetAnnotationLabel: View {

    enum Size {
        /// 12pt — the standard marginalia size.
        case standard
        /// 11pt — timestamps and axis labels.
        case small

        var font: Font {
            switch self {
            case .standard: Font.Tokens.anno
            case .small:    Font.Tokens.annoSmall
            }
        }

        /// +0.05em resolved in points at the token's size (0.6pt @ 12pt, 0.55pt @ 11pt).
        var tracking: CGFloat {
            switch self {
            case .standard: 0.6
            case .small:    0.55
            }
        }
    }

    private enum Content {
        case key(LocalizedStringKey)
        case literal(String)
    }

    private let content: Content
    private let size: Size
    private let color: Color

    @Environment(\.locale) private var locale
    private var isLatin: Bool { locale.language.languageCode?.identifier != "zh" }

    /// Localized keys resolve against the EXTENSION bundle's own strings table —
    /// the app's `Localizable.xcstrings` is not shipped in this target.
    init(key: LocalizedStringKey, size: Size = .standard, color: Color = ColorTokens.text3) {
        self.content = .key(key)
        self.size = size
        self.color = color
    }

    /// For content already interpolated from data (a timestamp, a zone label carried
    /// pre-localized in the snapshot).
    init(verbatim: String, size: Size = .standard, color: Color = ColorTokens.text3) {
        self.content = .literal(verbatim)
        self.size = size
        self.color = color
    }

    private var label: Text {
        switch content {
        case .key(let key):        Text(key)
        case .literal(let string): Text(verbatim: string)
        }
    }

    var body: some View {
        label
            .font(size.font)
            .monospacedDigit()
            .tracking(isLatin ? size.tracking : 0)
            .textCase(isLatin ? .uppercase : nil)
            .foregroundStyle(color)
    }
}
