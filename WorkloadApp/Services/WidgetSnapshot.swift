import Foundation

/// The one record the home-screen widgets read — written by the app after each pipeline
/// run, stored as JSON in the App Group container, decoded by the widget extension.
///
/// **The composite-only law.** The on-device raw-data rule (raw HealthKit data never
/// leaves the device; only composite scores sync) extends to the App Group container:
/// this struct may carry SCORES, ZONES, a verdict sentence, and training-load values —
/// never an HRV, a resting heart rate, a sleep duration, a temperature, or any other
/// raw physiological signal. `WidgetSnapshotTests` fences the field names.
///
/// **Membership:** this file compiles in BOTH the app target and the widget extension
/// target (it is the shared contract). It therefore imports Foundation only.
///
/// **Localization note:** the zone labels and the verdict line are resolved to the
/// app's language at WRITE time (the widget extension has no access to the app's
/// in-app language override, so pre-resolved strings are the honest option). The
/// `*ZoneKey` fields carry the stable enum raw values so the widget can map color
/// without parsing display text.
struct WidgetSnapshot: Codable, Equatable {

    /// Bump when a field changes meaning. The reader rejects snapshots written by a
    /// NEWER schema (an old widget must not misrender fields it does not understand);
    /// older snapshots decode through the lenient `init(from:)` below.
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    /// When the app last wrote any part of this snapshot.
    var generatedAt: Date

    // MARK: Readiness (widget a)

    /// Today's recovery/readiness score, 0–100. Composite by construction.
    var readinessScore: Int?
    /// `RecoveryZone` raw value ("red" / "yellow" / "green") — color mapping only.
    var readinessZoneKey: String?
    /// The zone's display label, localized at write time.
    var readinessZoneLabel: String?
    /// The autoregulation headline — working voice, one sentence the app already says.
    var verdictLine: String?

    // MARK: Training load (widget b)

    /// Acute:chronic workload ratio. nil until the athlete has load history.
    var acwr: Double?
    /// `ACWRZone` raw value ("undertrained" / "optimal" / "caution" / "danger" / "noData").
    var acwrZoneKey: String?
    /// The zone's display label, localized at write time.
    var acwrZoneLabel: String?
    /// Seven day-total training loads (sRPE/TSS composites, rest days = 0),
    /// oldest → newest, ending today. Feeds the sparkline.
    var dailyLoads: [DailyLoad]

    struct DailyLoad: Codable, Equatable {
        var day: Date
        var load: Double

        init(day: Date, load: Double) {
            self.day = day
            self.load = load
        }
    }

    init(
        schemaVersion: Int = WidgetSnapshot.currentSchemaVersion,
        generatedAt: Date = .now,
        readinessScore: Int? = nil,
        readinessZoneKey: String? = nil,
        readinessZoneLabel: String? = nil,
        verdictLine: String? = nil,
        acwr: Double? = nil,
        acwrZoneKey: String? = nil,
        acwrZoneLabel: String? = nil,
        dailyLoads: [DailyLoad] = []
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.readinessScore = readinessScore
        self.readinessZoneKey = readinessZoneKey
        self.readinessZoneLabel = readinessZoneLabel
        self.verdictLine = verdictLine
        self.acwr = acwr
        self.acwrZoneKey = acwrZoneKey
        self.acwrZoneLabel = acwrZoneLabel
        self.dailyLoads = dailyLoads
    }

    /// Lenient on purpose: every field except the version decodes with `decodeIfPresent`,
    /// so a snapshot written by an OLDER app (fewer fields) still renders what it has
    /// instead of failing whole. Unknown fields from a newer writer are ignored by
    /// `Decodable` anyway; the version gate in `WidgetSnapshotStore.read` handles
    /// meaning changes.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt) ?? .distantPast
        readinessScore = try container.decodeIfPresent(Int.self, forKey: .readinessScore)
        readinessZoneKey = try container.decodeIfPresent(String.self, forKey: .readinessZoneKey)
        readinessZoneLabel = try container.decodeIfPresent(String.self, forKey: .readinessZoneLabel)
        verdictLine = try container.decodeIfPresent(String.self, forKey: .verdictLine)
        acwr = try container.decodeIfPresent(Double.self, forKey: .acwr)
        acwrZoneKey = try container.decodeIfPresent(String.self, forKey: .acwrZoneKey)
        acwrZoneLabel = try container.decodeIfPresent(String.self, forKey: .acwrZoneLabel)
        dailyLoads = try container.decodeIfPresent([DailyLoad].self, forKey: .dailyLoads) ?? []
    }

    // MARK: - Codec

    /// One encoder/decoder configuration for both sides of the App Group boundary.
    /// ISO-8601 dates (debuggable in a plist dump), sorted keys (byte-stable output).
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func encoded() throws -> Data {
        try WidgetSnapshot.makeEncoder().encode(self)
    }

    static func decoded(from data: Data) throws -> WidgetSnapshot {
        try makeDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
