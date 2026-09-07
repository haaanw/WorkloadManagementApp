import SwiftUI
import WidgetKit

/// Widget (b) — the training-load strip: ACWR in its metric hue (`metricLoad`), the
/// zone as text + hairline capsule (never a fill — nocebo guard), and a 7-day load
/// sparkline. Small + medium families.
struct TrainingLoadWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TuwaTrainingLoadWidget", provider: WidgetSnapshotProvider()) { entry in
            TrainingLoadWidgetView(entry: entry)
                .tuwaWidgetBackground(area: .load)
        }
        .configurationDisplayName(Text("widget.load.title", comment: "Training-load widget name"))
        .description(Text("widget.load.description", comment: "Training-load widget description"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TrainingLoadWidgetView: View {
    let entry: WidgetSnapshotProvider.Entry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot = entry.snapshot, let acwr = snapshot.acwr {
            switch family {
            case .systemMedium:
                mediumBody(snapshot: snapshot, acwr: acwr)
            default:
                smallBody(snapshot: snapshot, acwr: acwr)
            }
        } else {
            emptyBody
        }
    }

    // MARK: - Families

    private func smallBody(snapshot: WidgetSnapshot, acwr: Double) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetAnnotationLabel(key: "widget.anno.acwr", size: .small)
            Spacer(minLength: 8)
            acwrReading(acwr)
            if let zoneLabel = snapshot.acwrZoneLabel {
                zoneBadge(label: zoneLabel, key: snapshot.acwrZoneKey)
                    .padding(.top, 8)
            }
            Spacer(minLength: 8)
            LoadSparkline(loads: snapshot.dailyLoads)
                .frame(height: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func mediumBody(snapshot: WidgetSnapshot, acwr: Double) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                WidgetAnnotationLabel(key: "widget.anno.acwr", size: .small)
                Spacer(minLength: 8)
                acwrReading(acwr)
                if let zoneLabel = snapshot.acwrZoneLabel {
                    zoneBadge(label: zoneLabel, key: snapshot.acwrZoneKey)
                        .padding(.top, 8)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                WidgetAnnotationLabel(key: "widget.anno.sevenDay", size: .small)
                LoadSparkline(loads: snapshot.dailyLoads)
                    .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var emptyBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetAnnotationLabel(key: "widget.anno.load", size: .small)
            Spacer(minLength: 8)
            Text("widget.load.empty", comment: "Training-load widget empty state")
                .font(.Tokens.smallLabel)
                .foregroundStyle(ColorTokens.text2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Pieces

    /// The hero reading — the ACWR ratio in the load metric's hue, tabular digits.
    private func acwrReading(_ acwr: Double) -> some View {
        Text(acwr.formatted(.number.precision(.fractionLength(2))))
            .font(.Tokens.displayAction)
            .monospacedDigit()
            .foregroundStyle(ColorTokens.metricLoad)
    }

    /// Zone badge per the Zone Color Rule: the TEXT label carries the state; color is
    /// supplementary; the capsule is a 0.5pt hairline, never a fill.
    private func zoneBadge(label: String, key: String?) -> some View {
        let zoneColor = WidgetZonePalette.acwrZoneColor(forKey: key)
        return Text(verbatim: label)
            .font(.Tokens.keyLabel)
            .foregroundStyle(zoneColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .overlay(Capsule().strokeBorder(zoneColor, lineWidth: 0.5))
    }
}

/// The 7-day day-total sparkline: one 1.5pt line in the load hue with a hue dot
/// marking "now" (chart grammar — a metric-hue mark, not a needle; needles are
/// live-state accent and nothing here is live).
struct LoadSparkline: View {
    let loads: [WidgetSnapshot.DailyLoad]

    var body: some View {
        GeometryReader { proxy in
            let points = normalizedPoints(in: proxy.size)
            if let last = points.last {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    ColorTokens.metricLoad,
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
                Circle()
                    .fill(ColorTokens.metricLoad)
                    .frame(width: 4, height: 4)
                    .position(last)
            }
        }
    }

    /// Values scaled into the drawing rect, oldest → newest across the width. A 2pt
    /// vertical inset keeps the round caps and the now-dot inside the frame; an
    /// all-zero week draws an honest flat baseline.
    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard loads.count > 1, size.width > 0, size.height > 0 else { return [] }
        let maxLoad = loads.map(\.load).max() ?? 0
        let inset: CGFloat = 2
        let drawableHeight = max(size.height - inset * 2, 1)
        let stepX = size.width / CGFloat(loads.count - 1)
        return loads.enumerated().map { index, daily in
            let fraction = maxLoad > 0 ? daily.load / maxLoad : 0
            return CGPoint(
                x: CGFloat(index) * stepX,
                y: inset + drawableHeight * (1 - CGFloat(fraction))
            )
        }
    }
}
