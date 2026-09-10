import SwiftUI

// Sheet-chrome primitives (v4.1 architecture, restyled by DESIGN.md v5 "Pavilion").
// Replaces stock `navigationTitle` + translucent glass toolbar buttons on sheets with the
// app's own titlebar: a centered sentence-case title on a flat opaque stone plane, quiet
// micro-caps action slots, and a 0.5pt bottom hairline. The modal analogue of `ScreenHeader`
// (CardStyle.swift). All values from ColorTokens / Font.Tokens / Spacing only; motion/press
// via the shared `.pressable` Key grammar.

// MARK: - Sheet header action slot

/// A quiet micro-caps action slot for the sheet header (Cancel / primary action).
/// 10pt Medium micro-caps (`headerAction`); `emphasis` renders the primary/confirm action
/// in ink (`text1`), the default dismissive slot in `text2` — a quiet two-tier hierarchy,
/// never a filled key and never accent. Press feedback via the
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
                // v6/zh guard: CJK has no case, so the transform is Latin-only — the same
                // condition that already gated tracking (this was previously unconditional).
                .textCase(isLatinLocale ? .uppercase : nil)
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

/// The sheet titlebar (DESIGN.md v5): a centered sentence-case title (28pt Regular
/// `screenTitle` — the v4 micro-caps/wide-tracking treatment is retired) flanked by quiet
/// micro-caps action slots, closed by a 0.5pt `divider` hairline on a flat opaque stone
/// plane (`background`). Replaces stock `navigationTitle` +
/// `navigationBarTitleDisplayMode(.inline)` + translucent glass toolbar buttons on sheets.
/// The bar sits at the top of the sheet's content VStack (not overlaying scroll content) so
/// the plane stays flat and opaque — no material blur, no large-title chrome. Pair with
/// `.toolbar(.hidden, for: .navigationBar)` on the enclosing NavigationStack.
/// `minimumScaleFactor` guards long localized titles between the two slots.
///
/// **Always LABEL the slot** — `InstrumentSheetHeader(title:, leading: { … })`, never a bare
/// unlabeled trailing closure. Swift's deprecated backward matching sends an unlabeled
/// trailing closure to `trailing`, so seven sheets silently grew a right-hand Cancel while
/// `TrainingProfileSheet`, which labels its slots, kept the left-hand one (UAT round 1). The
/// label pins the slot, clears the compiler's deprecation warning, and stops a future Swift
/// from moving every Cancel button on its own.
struct InstrumentSheetHeader<Leading: View, Trailing: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

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
        SheetHeaderLayout(spacing: Spacing.sm) {
            // Each slot is wrapped so it contributes EXACTLY one subview to the layout: an
            // unwrapped `EmptyView` slot contributes none, and the three-slot placement
            // would then address the wrong views.
            HStack(spacing: 0) { leading }
            Text(title)
                .font(.Tokens.screenTitle)
                .foregroundStyle(ColorTokens.text1)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 0) { trailing }
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

// MARK: - Header slot layout

/// Three-slot titlebar layout: `leading`, `title`, `trailing`.
///
/// The two action slots are given the SAME width — the wider of the two — so the title
/// stays optically centred in the whole bar while being physically unable to run under an
/// action label. The earlier ZStack centred the title over a fixed 48pt inset and let long
/// actions ("Discard changes" / "Save profile") draw straight through it (UAT round 1, U6).
///
/// The title takes whatever width remains; its own `minimumScaleFactor` handles the squeeze.
/// Actions are never truncated — an action the athlete cannot read is worse than a title
/// rendered a point smaller.
struct SheetHeaderLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideals = subviews.map { $0.sizeThatFits(.unspecified) }
        let tallest = ideals.map(\.height).max() ?? 0
        // A bar always wants the width it is offered. `replacingUnspecifiedDimensions` only
        // fills in a nil, so an infinite proposal is clamped separately — a header must
        // never report an infinite width to its container.
        let natural = ideals.map(\.width).reduce(0, +) + spacing * 2
        let resolved = proposal.replacingUnspecifiedDimensions(
            by: CGSize(width: natural, height: tallest)
        )
        let width = resolved.width.isFinite ? resolved.width : natural
        return CGSize(width: width, height: max(resolved.height, tallest))
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 3 else { return }
        let leading = subviews[0]
        let title = subviews[1]
        let trailing = subviews[2]

        let slotWidth = max(
            leading.sizeThatFits(.unspecified).width,
            trailing.sizeThatFits(.unspecified).width
        )
        let titleWidth = max(0, bounds.width - 2 * slotWidth - 2 * spacing)
        let slotProposal = ProposedViewSize(width: slotWidth, height: bounds.height)

        leading.place(
            at: CGPoint(x: bounds.minX, y: bounds.midY),
            anchor: .leading,
            proposal: slotProposal
        )
        title.place(
            at: CGPoint(x: bounds.midX, y: bounds.midY),
            anchor: .center,
            proposal: ProposedViewSize(width: titleWidth, height: bounds.height)
        )
        trailing.place(
            at: CGPoint(x: bounds.maxX, y: bounds.midY),
            anchor: .trailing,
            proposal: slotProposal
        )
    }
}
