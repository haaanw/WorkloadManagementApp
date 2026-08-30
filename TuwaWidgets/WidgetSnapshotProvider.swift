import SwiftUI
import WidgetKit

/// The one timeline provider both widgets share: read the App Group snapshot, emit a
/// single entry, ask again in an hour. The real refresh signal is the app — every
/// `WidgetSnapshotWriter` publish calls `reloadAllTimelines()` — so the hourly policy
/// only keeps the relative staleness stamp honest overnight.
struct WidgetSnapshotProvider: TimelineProvider {

    struct Entry: TimelineEntry {
        let date: Date
        let snapshot: WidgetSnapshot?
    }

    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        // The widget gallery preview shows representative data, never the athlete's.
        let snapshot = context.isPreview ? WidgetSnapshot.sample : WidgetSnapshotStore.read()
        completion(Entry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = Entry(date: .now, snapshot: WidgetSnapshotStore.read())
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Shared rendering vocabulary

extension WidgetSnapshot {
    /// Gallery-preview data only (`context.isPreview` / `placeholder`). Never rendered
    /// for a real timeline entry.
    static let sample = WidgetSnapshot(
        readinessScore: 82,
        readinessZoneKey: "green",
        readinessZoneLabel: String(localized: "widget.sample.zone", defaultValue: "Go"),
        verdictLine: String(
            localized: "widget.sample.verdict",
            defaultValue: "Recovered and ready. Execute today's plan as written."
        ),
        acwr: 1.08,
        acwrZoneKey: "optimal",
        acwrZoneLabel: String(localized: "widget.sample.loadZone", defaultValue: "Load Steady"),
        dailyLoads: WidgetSnapshot.sampleLoads
    )

    private static var sampleLoads: [DailyLoad] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let values: [Double] = [180, 0, 320, 260, 0, 410, 300]
        return values.enumerated().compactMap { index, value in
            guard let day = calendar.date(byAdding: .day, value: index - 6, to: today) else { return nil }
            return DailyLoad(day: day, load: value)
        }
    }
}

/// Zone raw-value → token color, the widget-local half of the write-side contract
/// (`WidgetSnapshotTests.test_zoneKeys_matchEnumRawValues` pins the keys). Zone COLOR
/// is always supplementary here — every zone also renders its text label.
enum WidgetZonePalette {

    static func recoveryZoneColor(forKey key: String?) -> Color {
        switch key {
        case "green":  ColorTokens.zoneOptimal
        case "yellow": ColorTokens.zoneCaution
        case "red":    ColorTokens.zoneDanger
        default:       ColorTokens.text3
        }
    }

    static func acwrZoneColor(forKey key: String?) -> Color {
        switch key {
        case "undertrained": ColorTokens.zoneLow
        case "optimal":      ColorTokens.zoneOptimal
        case "caution":      ColorTokens.zoneCaution
        case "danger":       ColorTokens.zoneDanger
        default:             ColorTokens.text3
        }
    }
}

extension View {
    /// Every Tuwa widget sits on the card plane (`surfaceEl`) — widgets ARE raised
    /// light cards, and the card plane is where metric-hue/zone text below 24pt
    /// clears its 4.5:1 floor. Light-only by value: the tokens are absolute light
    /// hexes, so the stone does not invert in system dark mode.
    func tuwaWidgetBackground() -> some View {
        containerBackground(for: .widget) { ColorTokens.surfaceEl }
    }
}

/// The annotation stamp for "when was this written": `AUG 30 · 07:12` (the uppercase
/// transform is the annotation law's, applied by `WidgetAnnotationLabel`).
func widgetTimestamp(_ date: Date) -> String {
    let day = date.formatted(.dateTime.month(.abbreviated).day())
    let time = date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    return "\(day) · \(time)"
}
