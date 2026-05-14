import Foundation
import HealthKit
import SwiftData

/// Service that reads menstrual data from HealthKit and produces CycleContext
/// for downstream engines (RecoveryScoreEngine, AutoregulationEngine).
///
/// Responsibilities:
/// - Read menstrual flow history from HealthKit
/// - Detect cycle starts (metadata + gap-based fallback)
/// - Estimate cycle phase via 14-day fixed luteal model
/// - Score confidence from completed cycles, regularity, and optional wrist temp
/// - Upsert daily MenstrualCycleSnapshot
/// - Produce CycleContext for downstream consumption
///
/// Local-only service -- never syncs menstrual data to Supabase (D-12).
@MainActor
final class CycleTrackingService {
    private let store = HKHealthStore()

    // MARK: - Public API

    /// Run the full cycle tracking pipeline for the given athlete.
    /// Returns CycleContext for downstream engines (Phase 18).
    func run(athlete: Athlete, context: ModelContext) async -> CycleContext {
        // 1. Check exclusions first
        if athlete.isPregnant == true || athlete.isLactating == true {
            return CycleContext(
                phase: .unknown, confidence: 0, cycleDay: nil, cycleLength: nil,
                isOnHormonalContraceptive: athlete.isOnHormonalContraceptive ?? false,
                isPregnant: athlete.isPregnant ?? false,
                isLactating: athlete.isLactating ?? false
            )
        }

        // 2. Fetch menstrual flow history (last 365 days)
        let flowHistory: [(date: Date, flow: Int, isCycleStart: Bool)]
        do {
            flowHistory = try await fetchMenstrualFlowHistory(days: 365)
        } catch {
            print("Cycle data fetch error: \(error)")
            return .none
        }

        guard !flowHistory.isEmpty else { return .none }

        // 3. Detect cycle starts
        let cycleStarts = detectCycleStarts(from: flowHistory)
        guard cycleStarts.count >= 2 else { return .none }  // D-05: need 1 complete cycle

        // 4. Compute cycle lengths + stats
        let cycleLengths = computeCycleLengths(from: cycleStarts)
        let medianLength = median(cycleLengths)
        let cv = coefficientOfVariation(cycleLengths)

        // 5. Compute current cycle day
        let lastStart = cycleStarts.last!
        let cycleDay = Calendar.current.dateComponents([.day], from: lastStart, to: .now).day.map { $0 + 1 }

        // 6. Estimate phase
        let phase: CyclePhase
        if athlete.isOnHormonalContraceptive == true {
            phase = .unknown  // OC users skip phase estimation (D-04)
        } else if let day = cycleDay, let length = medianLength {
            phase = Self.estimatePhase(cycleDay: day, cycleLength: length)
        } else {
            phase = .unknown
        }

        // 7. Optional wrist temp confidence boost
        let hasWristTempConfirmation = await checkBiphasicShift()

        // 8. Compute confidence
        let completedCycles = cycleStarts.count - 1
        let confidence = Self.computeConfidence(
            completedCycles: completedCycles,
            cycleLengthCV: cv ?? 0,
            hasWristTempConfirmation: hasWristTempConfirmation
        )

        // 9. Upsert today's snapshot
        upsertSnapshot(
            athlete: athlete,
            context: context,
            cycleDay: cycleDay,
            phase: phase,
            confidence: confidence,
            cycleLength: medianLength,
            wristTempDeviation: nil,
            flowHistory: flowHistory
        )

        // 10. Build and return CycleContext
        return CycleContext(
            phase: phase,
            confidence: confidence,
            cycleDay: cycleDay,
            cycleLength: medianLength,
            isOnHormonalContraceptive: athlete.isOnHormonalContraceptive ?? false,
            isPregnant: athlete.isPregnant ?? false,
            isLactating: athlete.isLactating ?? false
        )
    }

    // MARK: - HealthKit Fetch

    /// Fetch menstrual flow samples from HealthKit.
    /// Returns array of (date, flow raw value, isCycleStart from metadata).
    private func fetchMenstrualFlowHistory(days: Int) async throws -> [(date: Date, flow: Int, isCycleStart: Bool)] {
        let type = HKCategoryType(.menstrualFlow)
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: .now, options: .strictStartDate)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )

        let samples = try await descriptor.result(for: store)
        return samples.map { sample in
            let isCycleStart = (sample.metadata?[HKMetadataKeyMenstrualCycleStart] as? Bool) ?? false
            return (date: sample.startDate, flow: sample.value, isCycleStart: isCycleStart)
        }
    }

    // MARK: - Cycle Start Detection

    /// Detect cycle start dates from flow history.
    /// Uses HKMetadataKeyMenstrualCycleStart when available,
    /// falls back to gap-based detection (14+ day gap between flow samples).
    private func detectCycleStarts(from flowHistory: [(date: Date, flow: Int, isCycleStart: Bool)]) -> [Date] {
        let calendar = Calendar.current

        // Try metadata-based detection first
        let metadataStarts = flowHistory
            .filter { $0.isCycleStart }
            .map { calendar.startOfDay(for: $0.date) }

        if metadataStarts.count >= 2 {
            // Remove duplicates (same day) and sort
            return Array(Set(metadataStarts)).sorted()
        }

        // Fallback: gap-based detection (Pitfall 2 -- third-party apps may not set metadata)
        var starts: [Date] = []
        var lastFlowDate: Date?

        for entry in flowHistory {
            let entryDay = calendar.startOfDay(for: entry.date)
            if let last = lastFlowDate {
                let daysBetween = calendar.dateComponents([.day], from: last, to: entryDay).day ?? 0
                if daysBetween >= 14 {
                    starts.append(entryDay)
                }
            } else {
                starts.append(entryDay)  // First flow entry = first cycle start
            }
            lastFlowDate = entryDay
        }

        return starts
    }

    // MARK: - Cycle Length Computation

    /// Compute cycle lengths from consecutive cycle start dates.
    private func computeCycleLengths(from starts: [Date]) -> [Int] {
        guard starts.count >= 2 else { return [] }
        let calendar = Calendar.current
        var lengths: [Int] = []
        for i in 1..<starts.count {
            if let days = calendar.dateComponents([.day], from: starts[i-1], to: starts[i]).day {
                lengths.append(days)
            }
        }
        return lengths
    }

    // MARK: - Phase Estimation (Pure)

    /// Estimate cycle phase from cycle day using 14-day fixed luteal model.
    /// Follicular length varies with individual cycle length; luteal is ~14 days.
    static func estimatePhase(cycleDay: Int, cycleLength: Int) -> CyclePhase {
        let follicularLength = max(cycleLength - 14, 10)  // minimum 10 day follicular
        let menstruationEnd = 5
        let ovulationDay = follicularLength
        let lutealStart = ovulationDay + 1

        switch cycleDay {
        case 1...menstruationEnd:
            return .earlyFollicular
        case (menstruationEnd + 1)..<ovulationDay:
            return .lateFollicular
        case ovulationDay...(ovulationDay + 1):
            return .ovulatory
        case lutealStart...(lutealStart + 6):
            return .earlyLuteal
        default:
            return .lateLuteal
        }
    }

    // MARK: - Confidence Scoring (Pure)

    /// Compute confidence score from cycle data quality.
    /// Returns 0.0-1.0 based on completed cycles, regularity, and wrist temp.
    static func computeConfidence(
        completedCycles: Int,
        cycleLengthCV: Double,
        hasWristTempConfirmation: Bool
    ) -> Double {
        guard completedCycles >= 1 else { return 0.0 }

        var confidence: Double
        switch completedCycles {
        case 1: confidence = 0.4
        case 2: confidence = 0.6
        default: confidence = 0.7
        }

        // Regularity: CV < 0.10 = regular, > 0.20 = irregular (D-06)
        if cycleLengthCV < 0.10 {
            confidence += 0.15
        } else if cycleLengthCV > 0.20 {
            confidence -= 0.20
        }

        // Wrist temp confirmation
        if hasWristTempConfirmation {
            confidence += 0.15
        }

        return max(0.0, min(1.0, confidence))
    }

    // MARK: - Wrist Temperature

    /// Check if biphasic temperature shift detected in recent wrist temp data.
    /// Returns true if post-ovulation rise of >= 0.2 degrees C found.
    private func checkBiphasicShift() async -> Bool {
        guard let wristTempType = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) else {
            return false
        }

        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: .now, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: wristTempType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )

        let samples: [HKQuantitySample]
        do {
            samples = try await descriptor.result(for: store)
        } catch {
            return false
        }

        guard samples.count >= 10 else { return false }

        let deviations = samples.map { $0.quantity.doubleValue(for: .degreeCelsius()) }

        // Sliding window: 5-day pre vs 5-day post, looking for >= 0.2 degree rise
        for i in 5..<(deviations.count - 4) {
            let preMean = deviations[(i-5)..<i].reduce(0, +) / 5.0
            let postMean = deviations[i..<(i+5)].reduce(0, +) / 5.0
            if postMean - preMean >= 0.2 {
                return true
            }
        }
        return false
    }

    // MARK: - Snapshot Persistence

    /// Upsert today's MenstrualCycleSnapshot.
    @discardableResult
    private func upsertSnapshot(
        athlete: Athlete,
        context: ModelContext,
        cycleDay: Int?,
        phase: CyclePhase,
        confidence: Double,
        cycleLength: Int?,
        wristTempDeviation: Double?,
        flowHistory: [(date: Date, flow: Int, isCycleStart: Bool)]
    ) -> MenstrualCycleSnapshot {
        let today = Calendar.current.startOfDay(for: .now)

        // Check for existing snapshot today
        let existingSnapshots = (try? context.fetch(FetchDescriptor<MenstrualCycleSnapshot>())) ?? []
        let todaySnapshot = existingSnapshots.first {
            Calendar.current.isDate($0.date, inSameDayAs: today) && $0.athlete?.id == athlete.id
        }

        // Today's flow info
        let todayFlow = flowHistory.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
        let isCycleStart = todayFlow?.isCycleStart ?? false

        if let existing = todaySnapshot {
            existing.cycleDay = cycleDay
            existing.estimatedPhase = phase
            existing.confidence = confidence
            existing.cycleLength = cycleLength
            existing.wristTempDeviation = wristTempDeviation
            existing.flowIntensity = todayFlow?.flow
            existing.isCycleStart = isCycleStart
            existing.isOnHormonalContraceptive = athlete.isOnHormonalContraceptive ?? false
            existing.isPregnant = athlete.isPregnant ?? false
            existing.isLactating = athlete.isLactating ?? false
            existing.updatedAt = .now
            try? context.save()
            return existing
        } else {
            let snapshot = MenstrualCycleSnapshot(
                date: today,
                cycleDay: cycleDay,
                estimatedPhase: phase,
                confidence: confidence,
                cycleLength: cycleLength,
                wristTempDeviation: wristTempDeviation,
                flowIntensity: todayFlow?.flow,
                isCycleStart: isCycleStart,
                isOnHormonalContraceptive: athlete.isOnHormonalContraceptive ?? false,
                isPregnant: athlete.isPregnant ?? false,
                isLactating: athlete.isLactating ?? false
            )
            snapshot.athlete = athlete
            context.insert(snapshot)
            try? context.save()
            return snapshot
        }
    }

    // MARK: - Helpers

    private func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[mid - 1] + sorted[mid]) / 2
            : sorted[mid]
    }

    private func coefficientOfVariation(_ values: [Int]) -> Double? {
        guard values.count >= 2 else { return nil }
        let doubles = values.map(Double.init)
        let mean = doubles.reduce(0, +) / Double(doubles.count)
        guard mean > 0 else { return nil }
        let variance = doubles.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(doubles.count)
        let stddev = variance.squareRoot()
        return stddev / mean
    }
}
