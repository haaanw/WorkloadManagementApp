import SwiftUI

/// Segmented control for time range selection (D-01).
/// 0pt corner radius, hairline border, DM Sans font.
struct TimeRangeSegmentedControl: View {
    @Binding var selected: TimeRange

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases) { range in
                Button(range.rawValue) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        selected = range
                    }
                }
                .font(selected == range ? .Tokens.bodyMedium : .Tokens.body)
                .foregroundStyle(selected == range ? ColorTokens.text1 : ColorTokens.text2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selected == range ? ColorTokens.surface : ColorTokens.background)
            }
        }
        .overlay(
            Rectangle()
                .stroke(ColorTokens.divider, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
    }
}
