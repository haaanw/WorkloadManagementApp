import SwiftUI

// v4.1 sheet-chrome primitives (owned by workstream WS3 — see
// .planning/orchestration/2026-07-20-v41-handoff.md). Replaces stock `navigationTitle` +
// translucent glass toolbar buttons on sheets with an instrument titlebar: a centered
// UPPERCASE micro-caps title on a flat opaque aluminum plane, quiet caps action slots, and a
// 0.5pt bottom hairline. The modal analogue of `ScreenHeader` (CardStyle.swift). All values
// from ColorTokens / Font.Tokens / Spacing only; motion/press via the shared `.pressable`
// Key grammar.

// MARK: - Sheet header action slot

/// A quiet caps action slot for the instrument sheet header (Cancel / primary action).
/// 10pt Medium micro-caps in the UI voice (`headerAction`); `emphasis` renders the
/// primary/confirm action in ink (`text1`), the default dismissive slot in `text2` — a quiet
/// two-tier hierarchy, never a filled key and never the red index. Press feedback via the
/// shared `.pressable` Key grammar (scale 0.97, 120ms); the commit tap is the sanctioned
/// commit-only haptic. Locale-aware tracking (Latin only; caps + tracking are Latin
/// typography). Minimum 44pt hit target.
struct SheetHeaderButton: View {
    let title: LocalizedStringKey
    var emphasis: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    @Environment(\.locale) private var locale
    private var isLatinLocale: Bool { locale.language.languageCode?.identifier != "zh" }

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.Tokens.headerAction)
                .tracking(isLatinLocale ? 0.8 : 0)
                .textCase(.uppercase)
                .foregroundStyle(emphasis ? ColorTokens.text1 : ColorTokens.text2)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Instrument sheet header

/// The instrument sheet titlebar: a centered UPPERCASE micro-caps title (13pt Medium
/// `screenTitle`, wide locale-aware tracking) flanked by quiet caps action slots, closed by a
/// 0.5pt `divider` hairline on a flat opaque aluminum plane (`background`). Replaces stock
/// `navigationTitle` + `navigationBarTitleDisplayMode(.inline)` + translucent glass toolbar
/// buttons on sheets. The bar sits at the top of the sheet's content VStack (not overlaying
/// scroll content) so the plane stays flat and opaque — no material blur, no large-title
/// chrome. Pair with `.toolbar(.hidden, for: .navigationBar)` on the enclosing NavigationStack.
///
/// Tracking is a sheet-tuned 2.6 (≈0.2em) — wide but a hair tighter than `ScreenHeader`'s 3.6
/// so a centered title between two slots does not collide/truncate; `minimumScaleFactor`
/// guards long localized titles. Zh gets no tracking/case (Latin typography).
struct InstrumentSheetHeader<Leading: View, Trailing: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    @Environment(\.locale) private var locale
    private var isLatinLocale: Bool { locale.language.languageCode?.identifier != "zh" }

    init(
        title: LocalizedStringKey,
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            Text(title)
                .font(.Tokens.screenTitle)
                .tracking(isLatinLocale ? 2.6 : 0)
                .textCase(.uppercase)
                .foregroundStyle(ColorTokens.text1)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, Spacing.xl)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: Spacing.sm) {
                leading
                Spacer(minLength: 0)
                trailing
            }
        }
        .padding(.horizontal, Spacing.sm)
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background(ColorTokens.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ColorTokens.divider)
                .frame(height: 0.5)
        }
    }
}
