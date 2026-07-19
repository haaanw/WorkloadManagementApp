import SwiftUI

/// The v4 "Instrument" tab bar (Stage 4a architecture, Stage 1″ restyle — mockup column D).
///
/// Replaces the stock TabView chrome with the app's own instrument bar:
/// - A flat OPAQUE `ColorTokens.tabBarSurface` plane (a hair darker than the aluminum base)
///   with a 0.5pt `dividerStrong` top hairline. NO material blur, NO floating pill, NO
///   shadow, NO corner radius — this is an edge-to-edge plane (the machined bottom edge of
///   the instrument), not a card.
/// - Text-only micro-caps items: 9pt Medium `tabLabel`, ~0.2em tracking. Selected = `text1`
///   + the 1.5pt red index tick ABOVE the label at the bar's top edge — needle grammar, one
///   of the sanctioned index-mark locations (Index Rule). Unselected = `disabled`. An
///   optional compact glyph variant exists (`glyph:`) as the fallback direction; the
///   primary direction is text-only.
/// - Full-height ≥44pt tap targets, `Haptics.select()` on switch (commit-only feedback),
///   tick movement via `Motion.state` (reduceMotion-aware).
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
    @Namespace private var tickNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                tabButton(item)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: InkTabBarMetrics.height)
        .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: selection)
        // Opaque bar plane (a hair darker than the aluminum base), extended under the
        // home-indicator region so the bar reads as the machined bottom edge of the
        // instrument (never a floating pill), capped by the 0.5pt strong top hairline.
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
            VStack(spacing: Spacing.xs) {
                if let glyph = item.glyph {
                    Image(systemName: glyph)
                        .font(.Tokens.label)
                        .foregroundStyle(isSelected ? ColorTokens.text1 : ColorTokens.disabled)
                        .accessibilityHidden(true)
                }

                Text(item.title)
                    .font(.Tokens.tabLabel)
                    .tracking(1.8)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? ColorTokens.text1 : ColorTokens.disabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            // The 1.5pt red index tick ABOVE the label, riding the bar's top edge —
            // needle grammar (Index Rule): the needle points at the active tab.
            .overlay(alignment: .top) {
                if isSelected {
                    Rectangle()
                        .fill(ColorTokens.index)
                        .frame(width: 36, height: 1.5)
                        .matchedGeometryEffect(id: "ink.tab.tick", in: tickNamespace)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
        .accessibilityIdentifier(item.accessibilityID)
        .accessibilityLabel(Text(item.title))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
