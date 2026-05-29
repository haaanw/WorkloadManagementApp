import SwiftUI

/// Design-system primitives — the single reusable set of card / section / control
/// building blocks. See DESIGN.md "Elevation Ladder", "Separator Grammar", and
/// "Card Pattern". Every grouped surface on Dashboard and Profile is built from these
/// instead of hand-rolling background + overlay per screen.
///
/// Hard constraints (enforced here so call sites can't drift):
/// - 0pt corners — Rectangle only, never RoundedRectangle.
/// - No shadows — elevation is plane (surfaceEl) + 0.5pt divider border only.
/// - Spacing on the 8pt grid.

// MARK: - Spacing scale (DESIGN.md Spacing table)

enum Spacing {
    /// 8pt — icon-label gaps, tight inline spacing
    static let xs: CGFloat = 8
    /// 16pt — card horizontal padding, small gaps
    static let sm: CGFloat = 16
    /// 24pt — card vertical padding, standard gaps
    static let md: CGFloat = 24
    /// 32pt — section gaps (the section-break step)
    static let lg: CGFloat = 32
    /// 48pt — major section breaks
    static let xl: CGFloat = 48
}

// MARK: - Card

/// The one reusable card container: `surfaceEl` fill + 0.5pt `divider` hairline border,
/// 16pt horizontal / 24pt vertical padding, 0pt corners. Use for any grouped, elevated,
/// or tappable container so it reads as a distinct plane lifted off the page.
struct CardStyle: ViewModifier {
    var horizontalPadding: CGFloat = Spacing.sm
    var verticalPadding: CGFloat = Spacing.md

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(ColorTokens.surfaceEl)
            .overlay(
                Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
            )
    }
}

extension View {
    /// Apply the standard card plane (`surfaceEl` + 0.5pt divider border, square corners).
    func cardStyle(
        horizontalPadding: CGFloat = Spacing.sm,
        verticalPadding: CGFloat = Spacing.md
    ) -> some View {
        modifier(CardStyle(horizontalPadding: horizontalPadding, verticalPadding: verticalPadding))
    }
}

// MARK: - Section header

/// 19pt Medium `sectionHead` header in `--text-1`. This is the real section header per
/// DESIGN.md:27 — NOT 12pt micro-caps `--text-3` (that drift is what flattened hierarchy).
struct SectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.Tokens.sectionHead)
            .foregroundStyle(ColorTokens.text1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.sm)
    }
}

// MARK: - Section container

/// Wraps a top-level section: applies the 32pt section-break gap above the content and
/// (optionally) a 19pt Medium header. The break is the heavy tier of the separator
/// grammar — never a bare 8pt spacer.
struct SectionContainer<Content: View>: View {
    var header: LocalizedStringKey?
    var topGap: CGFloat = Spacing.lg
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: topGap)
            if let header {
                SectionHeader(title: header)
                Spacer().frame(height: Spacing.sm)
            }
            content
        }
    }
}

// MARK: - Row separator

/// The light tier of the separator grammar: a 0.5pt `divider` hairline inset 16pt from the
/// leading edge, used between sibling rows inside one section.
struct RowSeparator: View {
    var inset: CGFloat = Spacing.sm

    var body: some View {
        Rectangle()
            .fill(ColorTokens.divider)
            .frame(height: 0.5)
            .padding(.leading, inset)
    }
}

// MARK: - Toggle style (neutral — no Apple green)

/// A deliberately neutral toggle. The default system `Toggle` paints its "on" track Apple
/// green, which violates the accent-only rule (accent lives only on the hero score). This
/// style uses `--text-1` for the on-track and `--surface` for off, with a square 0pt knob —
/// consistent with the instrument aesthetic.
struct DesignToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Rectangle()
                    .fill(configuration.isOn ? ColorTokens.text1 : ColorTokens.surface)
                    .frame(width: 48, height: 28)
                    .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
                Rectangle()
                    .fill(configuration.isOn ? ColorTokens.background : ColorTokens.text2)
                    .frame(width: 20, height: 20)
                    .padding(4)
            }
        }
        .buttonStyle(.plain)
        .animation(.linear(duration: 0.15), value: configuration.isOn)
        .accessibilityAddTraits(configuration.isOn ? [.isButton, .isSelected] : .isButton)
    }
}

extension ToggleStyle where Self == DesignToggleStyle {
    /// Neutral design-system toggle (no Apple green). Use everywhere instead of the default.
    static var design: DesignToggleStyle { DesignToggleStyle() }
}

// MARK: - Menu picker chevron

/// The trailing chevron for a `Menu`-backed picker, styled to the system: a small caret in
/// `--text-3`, drawn with SF Symbols sizing that matches the type scale (no `.system()` font).
struct MenuChevron: View {
    var body: some View {
        Image(systemName: "chevron.up.chevron.down")
            .font(.Tokens.micro)
            .foregroundStyle(ColorTokens.text3)
    }
}
