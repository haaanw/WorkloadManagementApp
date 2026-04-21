import SwiftUI
import Charts

/// Helper view for gesture handling inside `.chartOverlay` (D-02).
/// Provides tap-scrub interaction to select the nearest data point by date.
struct ChartTooltipGesture: View {
    let proxy: ChartProxy
    let data: [(date: Date, value: Double)]
    @Binding var selectedDate: Date?

    var body: some View {
        GeometryReader { geometry in
            Rectangle().fill(.clear).contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard let plotFrame = proxy.plotFrame else { return }
                            let origin = geometry[plotFrame].origin
                            let xPosition = value.location.x - origin.x
                            guard let date: Date = proxy.value(atX: xPosition) else { return }
                            selectedDate = closestDate(to: date)
                        }
                        .onEnded { _ in selectedDate = nil }
                )
        }
    }

    private func closestDate(to target: Date) -> Date? {
        data.min(by: {
            abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target))
        })?.date
    }
}

/// Tooltip popup view (surfaceEl background, 0pt corners, value + date).
struct TooltipBubble: View {
    let value: String
    let dateLabel: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
            Text(dateLabel)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(ColorTokens.surfaceEl)
        .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
    }
}
