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
