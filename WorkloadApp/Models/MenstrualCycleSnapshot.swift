import Foundation
import SwiftData

/// Daily snapshot of menstrual cycle state, computed from HealthKit data.
/// Local-only model -- never synced to Supabase (D-12 privacy constraint).
@Model
final class MenstrualCycleSnapshot {
    @Attribute(.unique) var id: UUID
    var date: Date
    var cycleDay: Int?
    var estimatedPhase: CyclePhase?
    var confidence: Double
    var cycleLength: Int?
    var wristTempDeviation: Double?
    var flowIntensity: Int?
    var isCycleStart: Bool
    var isOnHormonalContraceptive: Bool
    var isPregnant: Bool
    var isLactating: Bool
    var updatedAt: Date

    var athlete: Athlete?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        cycleDay: Int? = nil,
        estimatedPhase: CyclePhase? = nil,
        confidence: Double = 0.0,
        cycleLength: Int? = nil,
        wristTempDeviation: Double? = nil,
        flowIntensity: Int? = nil,
        isCycleStart: Bool = false,
        isOnHormonalContraceptive: Bool = false,
        isPregnant: Bool = false,
        isLactating: Bool = false
    ) {
        self.id = id
        self.date = date
        self.cycleDay = cycleDay
        self.estimatedPhase = estimatedPhase
        self.confidence = confidence
        self.cycleLength = cycleLength
        self.wristTempDeviation = wristTempDeviation
        self.flowIntensity = flowIntensity
        self.isCycleStart = isCycleStart
        self.isOnHormonalContraceptive = isOnHormonalContraceptive
        self.isPregnant = isPregnant
        self.isLactating = isLactating
        self.updatedAt = .now
    }
}

// MARK: - CycleContext

/// Lightweight value type summarizing current cycle state for engine consumption.
/// Used by RecoveryScoreEngine and AutoregulationEngine to apply phase-aware adjustments.
struct CycleContext {
    let phase: CyclePhase
    let confidence: Double
    let cycleDay: Int?
    let cycleLength: Int?
    let isOnHormonalContraceptive: Bool
    let isPregnant: Bool
    let isLactating: Bool

    var hasExclusion: Bool {
        isOnHormonalContraceptive || isPregnant || isLactating
    }

    static let none = CycleContext(
        phase: .unknown, confidence: 0, cycleDay: nil, cycleLength: nil,
        isOnHormonalContraceptive: false, isPregnant: false, isLactating: false
    )
}
