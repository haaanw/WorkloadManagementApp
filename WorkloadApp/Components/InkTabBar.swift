import SwiftUI

/// The tab bar — **Console architecture, stone dress** (DESIGN.md v5 "Pavilion"; Console
/// grammar from v4.1 D12 retained).
///
/// Replaces the stock TabView chrome with the app's own bar:
/// - A flat OPAQUE `ColorTokens.tabBarSurface` plane (a hair darker than the stone base)
///   with a 0.5pt `dividerStrong` top hairline. NO material blur, NO floating pill, NO
///   shadow, NO corner radius — this is an edge-to-edge plane (the bottom edge of the
///   stone body), not a card.
/// - Text-only **Console** items: 11pt Medium `keyLabel`, TITLE-CASE (not caps), modest
///   ~0.13em tracking (Latin only; zh gets none) — the D12 readability raise, kept in v5.
///   Selected = the three-part presence grammar: `text1` ink + a faint sliding "well" behind
///   the item (`text1` @5%, `Motion.state`) + the 1.5pt ACCENT tick (travertine) ABOVE the
///   label riding the bar's top edge on the springy `Motion.tickSpring` throw — needle
///   grammar, a sanctioned live-state accent mark (Accent Rule). Unselected = `text3`.
/// - Per-item press-down: scale 0.94 (the D12 Console press), via `.pressable`.
/// - Full-height ≥44pt tap targets, `Haptics.select()` on switch (commit-only feedback).
///
/// **On the weight-shift (D12) and the One-Voice Type Law:** the demo shows selected labels
/// at font-weight 600, but the app ships only Regular/Medium and DESIGN.md forbids bold —
/// a same-size 500→600 shift would be fake-bolding. So selection is carried by the sanctioned
/// substitutes: the ink color step (`text3`→`text1`), the sliding well, and the springy tick.
/// Labels stay Medium at both states (matching the butted-key grammar).
///
/// The optional compact `glyph:` variant is retired in Console (text-only per D12); the field
/// is retained on `Item` for source compatibility but is not rendered.
///
/// Mount via `.safeAreaInset(edge: .bottom)` on the TabView, WITHOUT hiding the stock tab
/// bar. The TabView's tabs are UIKit-hosted, so a SwiftUI inset cannot reach their safe
/// areas; instead the (fully covered) stock bar keeps contributing its real UIKit bottom
/// inset to every tab root and every pushed detail screen — that is what clears scroll
/// content under this bar. The InkTabBar plane is opaque and its five full-width buttons
/// absorb every tap on the region, so the stock bar is never seen and never hit.
enum InkTabBarMetrics {
    /// Fixed content height of the bar above the bottom safe area (8pt grid), sized to
    /// cover the stock bar region it replaces visually.
    static let height: CGFloat = 48
}

struct InkTabBar<Tab: Hashable>: View {
    struct Item {
        let tab: Tab
        let title: LocalizedStringKey
        let accessibilityID: String
        /// Optional compact glyph above the label — fallback variant only; the primary
        /// direction is a pure-text bar.
        var glyph: String? = nil
    }

    let items: [Item]
    @Binding var selection: Tab

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @Namespace private var tickNamespace

    /// Case/tracking are Latin typography — Chinese labels get neither (same rule as
    /// ScreenHeader / ZoneBadge).
    private var isLatinLocale: Bool {
        locale.language.languageCode?.identifier != "zh"
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                tabButton(item)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: InkTabBarMetrics.height)
        .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: selection)
        // Opaque bar plane (a hair darker than the stone base), extended under the
        // home-indicator region so the bar reads as the bottom edge of the stone body
        // (never a floating pill), capped by the 0.5pt strong top hairline.
        .background(ColorTokens.tabBarSurface.ignoresSafeArea(edges: [.bottom, .horizontal]))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ColorTokens.dividerStrong)
                .frame(height: 0.5)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tabbar.ink")
    }

    private func tabButton(_ item: Item) -> some View {
        let isSelected = item.tab == selection
        return Button {
            guard selection != item.tab else { return }
            Haptics.select()
            selection = item.tab
        } label: {
            Text(item.title)
                // Console: 11pt Medium, title-case, modest tracking (D12).
                .font(.Tokens.keyLabel)
                .tracking(isLatinLocale ? 1.4 : 0)
                .lineLimit(1)
                .foregroundStyle(isSelected ? ColorTokens.text1 : ColorTokens.text3)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // The faint sliding "well" behind the active item — `text1` @5%, clipped to
                // a control-cornered plate, inset off the bar edges. Slides between tabs on
                // the container's `Motion.state` transaction (D12).
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: CornerTokens.control)
                            .fill(ColorTokens.text1.opacity(0.05))
                            .padding(.vertical, Spacing.xs)
                            .padding(.horizontal, Spacing.baselinePair)
                            .matchedGeometryEffect(id: "ink.tab.well", in: tickNamespace)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
                // The 1.5pt accent tick (travertine) ABOVE the label, riding the bar's top
                // edge — needle grammar (Accent Rule live-state mark): the needle points at
                // the active tab. It is the ONE element that gets the springy
                // `Motion.tickSpring` throw (its own transaction, overriding the container's
                // ease-out), so it settles onto the newly-selected tab with a hint of overshoot.
                .overlay(alignment: .top) {
                    if isSelected {
                        Rectangle()
                            .fill(ColorTokens.accent)
                            .frame(width: 38, height: 1.5)
                            .matchedGeometryEffect(id: "ink.tab.tick", in: tickNamespace)
                            .animation(Motion.resolved(Motion.tickSpring, reduceMotion: reduceMotion), value: selection)
                            .accessibilityHidden(true)
                    }
                }
        }
        // Per-item press-down 0.94 (D12 Console), no dim — the well + tick carry state.
        .buttonStyle(.pressable(scale: 0.94, opacity: 1))
        .accessibilityIdentifier(item.accessibilityID)
        .accessibilityLabel(Text(item.title))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
