import SwiftUI
import WidgetKit

/// Widget (a) — today's readiness: the recovery score in its metric hue
/// (`metricReadiness`, the Reading Color Rule) with the verdict line beneath in the
/// working voice. Small + medium families.
struct ReadinessWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TuwaReadinessWidget", provider: WidgetSnapshotProvider()) { entry in
            ReadinessWidgetView(entry: entry)
                .tuwaWidgetBackground(area: .readiness)
        }
        .configurationDisplayName(Text("widget.readiness.title", comment: "Readiness widget name"))
        .description(Text("widget.readiness.description", comment: "Readiness widget description"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ReadinessWidgetView: View {
    let entry: WidgetSnapshotProvider.Entry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot = entry.snapshot, let score = snapshot.readinessScore {
            switch family {
            case .systemMedium:
                mediumBody(snapshot: snapshot, score: score)
            default:
                smallBody(snapshot: snapshot, score: score)
            }
        } else {
            emptyBody
        }
    }

    // MARK: - Families

    private func smallBody(snapshot: WidgetSnapshot, score: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            annotationKey(snapshot: snapshot)
            Spacer(minLength: 8)
            scoreReading(score)
            if let verdict = snapshot.verdictLine {
                Text(verdict)
                    .font(.Tokens.smallLabel)
                    .foregroundStyle(ColorTokens.text2)
                    .lineLimit(3)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func mediumBody(snapshot: WidgetSnapshot, score: Int) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                annotationKey(snapshot: snapshot)
                Spacer(minLength: 8)
                scoreReading(score)
            }
            VStack(alignment: .leading, spacing: 0) {
                if let verdict = snapshot.verdictLine {
                    Text(verdict)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                        .lineLimit(4)
                }
                Spacer(minLength: 8)
                WidgetAnnotationLabel(
                    verbatim: widgetTimestamp(snapshot.generatedAt),
                    size: .small
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var emptyBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetAnnotationLabel(key: "widget.anno.readiness", size: .small)
            Spacer(minLength: 8)
            Text("widget.readiness.empty", comment: "Readiness widget empty state")
                .font(.Tokens.smallLabel)
                .foregroundStyle(ColorTokens.text2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Pieces

    /// `READINESS ● GO` — the metric key plus the zone as a keyed state dot + label.
    /// Zone color is supplementary (the label is the carrier), and the colored text
    /// names the zone whose hue it wears — sanctioned by the Reading Color Rule, on a
    /// card plane where all zone colors clear 4.5:1.
    private func annotationKey(snapshot: WidgetSnapshot) -> some View {
        HStack(spacing: 8) {
            WidgetAnnotationLabel(key: "widget.anno.readiness", size: .small)
            if let zoneLabel = snapshot.readinessZoneLabel {
                WidgetAnnotationLabel(
                    verbatim: "● \(zoneLabel)",
                    size: .small,
                    color: WidgetZonePalette.recoveryZoneColor(forKey: snapshot.readinessZoneKey)
                )
            }
        }
    }

    /// The hero reading — 32pt, `metricReadiness` (the readiness metric owns its hue),
    /// tabular digits.
    private func scoreReading(_ score: Int) -> some View {
        Text("\(score)")
            .font(.Tokens.displayAction)
            .monospacedDigit()
            .foregroundStyle(ColorTokens.metricReadiness)
    }
}
