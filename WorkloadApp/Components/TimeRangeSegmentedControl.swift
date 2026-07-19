import SwiftUI

/// Segmented control for time range selection (D-01).
/// v4 Key Row Law: butted segments — flex cells separated by interior 0.5pt hairlines
/// inside one `dividerStrong`-bordered container (`CornerTokens.control` corners).
/// The selected segment is an INK-FILLED cell (`text1` fill, `panelInk` label) —
/// never a red wash (Index Rule).
struct TimeRangeSegmentedControl: View {
    @Binding var selected: TimeRange
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(TimeRange.allCases.enumerated()), id: \.element) { index, range in
                Button(range.rawValue) {
                    guard selected != range else { return }
                    Haptics.select()
                    withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                        selected = range
                    }
                }
                .font(selected == range ? .Tokens.smallLabelMedium : .Tokens.smallLabel)
                .foregroundStyle(selected == range ? ColorTokens.panelInk : ColorTokens.text2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selected == range ? ColorTokens.text1 : ColorTokens.surfaceEl)
                .buttonStyle(.pressable(scale: 1, opacity: 0.7))
                .accessibilityAddTraits(selected == range ? [.isButton, .isSelected] : .isButton)

                if index < TimeRange.allCases.count - 1 {
                    Rectangle()
                        .fill(ColorTokens.dividerStrong)
                        .frame(width: 0.5)
                        .accessibilityHidden(true)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerTokens.control))
        .overlay(
            RoundedRectangle(cornerRadius: CornerTokens.control)
                .stroke(ColorTokens.dividerStrong, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
    }
}
