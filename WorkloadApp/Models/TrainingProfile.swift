import Foundation
import SwiftData

/// Persists cold-start questionnaire answers, seeded ATL/CTL estimates,
/// and perceptual bias measurements for a single athlete.
///
/// Linked to Athlete via `athleteId` (plain UUID foreign key, NOT a
/// SwiftData @Relationship) to keep the Athlete model clean and
/// preserve raw answers for bias analysis.
@Model
final class TrainingProfile {
    @Attribute(.unique) var id: UUID

    // MARK: - Athlete Link (D-07)

    var athleteId: UUID

    // MARK: - Questionnaire (Required, D-08)

    var sessionsPerWeek: Int
    var avgDurationMinutes: Int
    var typicalSRPE: Double
    var weeksAtLevel: Int

    // MARK: - Questionnaire (Optional, D-09)

    var trainingAgeYears: Int?
    var periodizationPreference: String?
    var movementTypes: [String]?
    var injuryHistory: Data?

    // MARK: - Seeded Values (D-11)

    var seededATL: Double
    var seededCTL: Double
    var seededAt: Date

    // MARK: - Bias Fields (D-12)

    var biasEstimatedATL: Double?
    var biasEstimatedCTL: Double?
    var biasActualATL: Double?
    var biasActualCTL: Double?
    var biasCapturedAt: Date?

    // MARK: - Cold-Start Window (D-13)

    var coldStartCompletedAt: Date?

    // MARK: - Timestamps

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        athleteId: UUID,
        sessionsPerWeek: Int,
        avgDurationMinutes: Int,
        typicalSRPE: Double,
        weeksAtLevel: Int,
        trainingAgeYears: Int? = nil,
        periodizationPreference: String? = nil,
        movementTypes: [String]? = nil,
        injuryHistory: Data? = nil,
        seededATL: Double,
        seededCTL: Double,
        seededAt: Date = .now,
        biasEstimatedATL: Double? = nil,
        biasEstimatedCTL: Double? = nil,
        biasActualATL: Double? = nil,
        biasActualCTL: Double? = nil,
        biasCapturedAt: Date? = nil,
        coldStartCompletedAt: Date? = nil
    ) {
        self.id = id
        self.athleteId = athleteId
        self.sessionsPerWeek = sessionsPerWeek
        self.avgDurationMinutes = avgDurationMinutes
        self.typicalSRPE = typicalSRPE
        self.weeksAtLevel = weeksAtLevel
        self.trainingAgeYears = trainingAgeYears
        self.periodizationPreference = periodizationPreference
        self.movementTypes = movementTypes
        self.injuryHistory = injuryHistory
        self.seededATL = seededATL
        self.seededCTL = seededCTL
        self.seededAt = seededAt
        self.biasEstimatedATL = biasEstimatedATL
        self.biasEstimatedCTL = biasEstimatedCTL
        self.biasActualATL = biasActualATL
        self.biasActualCTL = biasActualCTL
        self.biasCapturedAt = biasCapturedAt
        self.coldStartCompletedAt = coldStartCompletedAt
        self.createdAt = .now
        self.updatedAt = .now
    }
}

// MARK: - Sports (v1.7.3 · U6 + U10, HAN: GO)

/// The multi-sport field and the one rule that keeps it honest
/// (`.planning/v173/SPORT-MULTISELECT-IMPACT.md`, option B).
///
/// `TrainingProfile.movementTypes` is the synced multi-sport answer. `Athlete.sportType` is the
/// PRIMARY sport — "the one you would name first" — and the only value the two single-sport
/// readers (the Movement Bank's new-exercise default, the PDF report title) and every legacy
/// client see. No engine reads either field: load, fatigue and the verdict all read the
/// SESSION's sport. The invariant is `athlete.sportType == ordered.first`, and every writer
/// derives both values from one ordered list built here, so the two fields cannot drift.
enum SportSelection {

    /// The athlete's sports in priority order: the primary first, then the profile's other
    /// sports in their stored order. Unknown raw values (a newer client's sport) are dropped.
    /// A legacy row whose array omits the primary converges on the next write.
    static func sports(movementTypes: [String]?, primary: SportType) -> [SportType] {
        let stored = (movementTypes ?? []).compactMap(SportType.init(rawValue:))
        var ordered = [primary]
        for sport in stored where !ordered.contains(sport) {
            ordered.append(sport)
        }
        return ordered
    }

    /// Apply a toggled set to the current ordered list. Survivors keep their order; additions
    /// append in `SportType.allCases` order, so the primary changes only when the athlete
    /// deselects it. An empty set is refused and returns `current` unchanged: an athlete
    /// always has a sport, so the last one cannot be deselected.
    static func ordered(current: [SportType], selected: Set<SportType>) -> [SportType] {
        guard !selected.isEmpty else { return current }
        var next = current.filter { selected.contains($0) }
        for sport in SportType.allCases where selected.contains(sport) && !next.contains(sport) {
            next.append(sport)
        }
        return next
    }
}

// MARK: - Injury history codec

extension TrainingProfile {
    /// Encode the injury answer the way the cold-start sheet always has: one `InjuryEntry` per
    /// region, the shared notes on each, `nil` when no region is selected. Regions are written in
    /// `BodyRegion.allCases` order so the same answer always produces the same bytes (the field
    /// syncs, and a `Set` iterates in no fixed order).
    static func encodeInjuryHistory(regions: Set<BodyRegion>, notes: String) -> Data? {
        guard !regions.isEmpty else { return nil }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let entries = BodyRegion.allCases
            .filter { regions.contains($0) }
            .map { InjuryEntry(bodyRegion: $0, notes: trimmed.isEmpty ? nil : trimmed, isActive: true) }
        // Sorted keys as well as sorted regions: `JSONEncoder` orders an object's keys
        // arbitrarily per run, so without this the same answer encodes to different bytes
        // (the test that pins byte-stability caught exactly that).
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(entries)
    }

    /// The stored injury answer, decoded; empty when nothing was recorded or the data is unreadable.
    static func decodeInjuryHistory(_ data: Data?) -> (regions: Set<BodyRegion>, notes: String) {
        guard let data,
              let entries = try? JSONDecoder().decode([InjuryEntry].self, from: data) else {
            return ([], "")
        }
        return (Set(entries.map(\.bodyRegion)), entries.first?.notes ?? "")
    }
}
