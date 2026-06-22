import SwiftUI

/// Segmented control for time range selection (D-01).
/// 0pt corner radius, hairline border, General Sans font.
struct TimeRangeSegmentedControl: View {
    @Binding var selected: TimeRange

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases) { range in
                Button(range.rawValue) {
                    guard selected != range else { return }
                    Haptics.select()
                    withAnimation(Motion.state) {
                        selected = range
                    }
                }
                .font(selected == range ? .Tokens.bodyMedium : .Tokens.body)
                .foregroundStyle(selected == range ? ColorTokens.accent : ColorTokens.text2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selected == range ? ColorTokens.accentSubtle : ColorTokens.surface)
                .buttonStyle(.pressable)
            }
        }
        .overlay(
            Rectangle()
                .stroke(ColorTokens.divider, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
    }
}
