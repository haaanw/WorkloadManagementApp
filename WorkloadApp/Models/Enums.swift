import Foundation

// MARK: - Sport & Unit Enums

enum SportType: String, Codable, CaseIterable, Identifiable {
    case lifting
    case running
    case cycling
    case teamSport
    case crossfit
    case swimming
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lifting: String(localized: "sport.lifting", defaultValue: "Lifting")
        case .running: String(localized: "sport.running", defaultValue: "Running")
        case .cycling: String(localized: "sport.cycling", defaultValue: "Cycling")
        case .teamSport: String(localized: "sport.teamSport", defaultValue: "Team Sport")
        case .crossfit: String(localized: "sport.crossfit", defaultValue: "CrossFit")
        case .swimming: String(localized: "sport.swimming", defaultValue: "Swimming")
        case .custom: String(localized: "sport.custom", defaultValue: "Custom")
        }
    }

    var systemImage: String {
        switch self {
        case .lifting: "dumbbell.fill"
        case .running: "figure.run"
        case .cycling: "bicycle"
        case .teamSport: "sportscourt.fill"
        case .crossfit: "flame.fill"
        case .swimming: "figure.pool.swim"
        case .custom: "star.fill"
        }
    }
}

enum WeightUnit: String, Codable, CaseIterable {
    case kg
    case lbs

    var displayName: String {
        switch self {
        case .kg: String(localized: "weightUnit.kg", defaultValue: "kg")
        case .lbs: String(localized: "weightUnit.lbs", defaultValue: "lbs")
        }
    }

    var conversionToKg: Double {
        switch self {
        case .kg: 1.0
        case .lbs: 0.453592
        }
    }
}

// MARK: - Workload Enums

enum ACWRMethod: String, Codable, CaseIterable {
    case ewma
    case rolling28day

    var displayName: String {
        switch self {
        case .ewma: String(localized: "acwrMethod.ewma", defaultValue: "EWMA")
        case .rolling28day: String(localized: "acwrMethod.rolling28day", defaultValue: "Rolling 28-Day")
        }
    }
}

enum LoadSource: String, Codable, CaseIterable {
    case srpe
    case trimp
    case combined

    var displayName: String {
        switch self {
        case .srpe: String(localized: "loadSource.srpe", defaultValue: "sRPE")
        case .trimp: String(localized: "loadSource.trimp", defaultValue: "TRIMP")
        case .combined: String(localized: "loadSource.combined", defaultValue: "Combined")
        }
    }
}

enum ACWRZone: String, Codable {
    case undertrained
    case optimal
    case caution
    case danger
    case noData

    static func classify(acwr: Double, ctl: Double) -> ACWRZone {
        guard ctl > 0 else { return .noData }
        switch acwr {
        case ..<0.8: return .undertrained
        case 0.8..<1.3: return .optimal
        case 1.3..<1.5: return .caution
        default: return .danger
        }
    }

    var displayName: String {
        switch self {
        case .undertrained: String(localized: "zone.low", defaultValue: "Undertrained")
        case .optimal: String(localized: "zone.optimal", defaultValue: "Optimal")
        case .caution: String(localized: "zone.caution", defaultValue: "Caution")
        case .danger: String(localized: "zone.danger", defaultValue: "High Load")
        case .noData: String(localized: "zone.noData", defaultValue: "No Data")
        }
    }

    var colorName: String {
        switch self {
        case .undertrained: "zoneUndertrained"
        case .optimal: "zoneOptimal"
        case .caution: "zoneCaution"
        case .danger: "zoneDanger"
        case .noData: "zoneNoData"
        }
    }
}

// MARK: - Exercise Enums

enum ExerciseCategory: String, Codable, CaseIterable, Identifiable {
    case compound
    case isolation
    case cardio
    case bodyweight
    case plyometric
    case drill
    case interval

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compound: String(localized: "exerciseCategory.compound", defaultValue: "Compound")
        case .isolation: String(localized: "exerciseCategory.isolation", defaultValue: "Isolation")
        case .cardio: String(localized: "exerciseCategory.cardio", defaultValue: "Cardio")
        case .bodyweight: String(localized: "exerciseCategory.bodyweight", defaultValue: "Bodyweight")
        case .plyometric: String(localized: "exerciseCategory.plyometric", defaultValue: "Plyometric")
        case .drill: String(localized: "exerciseCategory.drill", defaultValue: "Drill")
        case .interval: String(localized: "exerciseCategory.interval", defaultValue: "Interval")
        }
    }

    /// Which input fields this category uses
    var inputMode: ExerciseInputMode {
        switch self {
        case .compound, .isolation, .plyometric: .weightReps
        case .bodyweight: .repsOnly
        case .cardio, .interval: .distanceDuration
        case .drill: .durationOnly
        }
    }
}

enum ExerciseInputMode {
    case weightReps       // weight, reps, RPE, RIR
    case repsOnly         // reps, RPE (bodyweight)
    case distanceDuration // distance, duration, pace (running, cycling, swimming)
    case durationOnly     // duration, RPE (drills, skills, team sport activities)
}

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest
    case back
    case legs
    case shoulders
    case arms
    case core
    case fullBody

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: String(localized: "muscleGroup.chest", defaultValue: "Chest")
        case .back: String(localized: "muscleGroup.back", defaultValue: "Back")
        case .legs: String(localized: "muscleGroup.legs", defaultValue: "Legs")
        case .shoulders: String(localized: "muscleGroup.shoulders", defaultValue: "Shoulders")
        case .arms: String(localized: "muscleGroup.arms", defaultValue: "Arms")
        case .core: String(localized: "muscleGroup.core", defaultValue: "Core")
        case .fullBody: String(localized: "muscleGroup.fullBody", defaultValue: "Full Body")
        }
    }
}

enum PRType: String, Codable, CaseIterable {
    case maxWeight
    case maxReps
    case maxVolume
    case fastestPace

    var displayName: String {
        switch self {
        case .maxWeight: String(localized: "prType.maxWeight", defaultValue: "Max Weight")
        case .maxReps: String(localized: "prType.maxReps", defaultValue: "Max Reps")
        case .maxVolume: String(localized: "prType.maxVolume", defaultValue: "Max Volume")
        case .fastestPace: String(localized: "prType.fastestPace", defaultValue: "Fastest Pace")
        }
    }
}

// MARK: - Recovery Enums

enum RecoveryZone: String, Codable {
    case red
    case yellow
    case green

    static func classify(score: Double) -> RecoveryZone {
        switch score {
        case ..<34: return .red
        case 34...66: return .yellow
        default: return .green
        }
    }

    var displayName: String {
        switch self {
        case .red: String(localized: "recoveryZone.red", defaultValue: "Rest / Light Only")
        case .yellow: String(localized: "recoveryZone.yellow", defaultValue: "Cautious")
        case .green: String(localized: "recoveryZone.green", defaultValue: "Go")
        }
    }

    var volumeModifier: Double {
        switch self {
        case .red: 0.5
        case .yellow: 0.75
        case .green: 1.0
        }
    }

    var rpeCap: Double {
        switch self {
        case .red: 5.0
        case .yellow: 8.0
        case .green: 10.0
        }
    }
}

enum RecoveryDataSource: String, Codable {
    case healthKit
    case manual
}

// MARK: - Coach / Role Enums

enum RelationshipStatus: String, Codable {
    case pending
    case accepted
}

enum AppMode: String {
    case athlete
    case coach
}

enum PrescriptionStatus: String, Codable {
    case assigned
    case completed
    case skipped

    var displayName: String {
        switch self {
        case .assigned: String(localized: "prescriptionStatus.assigned", defaultValue: "Assigned")
        case .completed: String(localized: "prescriptionStatus.completed", defaultValue: "Completed")
        case .skipped: String(localized: "prescriptionStatus.skipped", defaultValue: "Skipped")
        }
    }
}

enum SessionType: String, Codable, CaseIterable, Identifiable {
    case strength
    case skill
    case cardio
    case match
    case recovery

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strength: String(localized: "sessionType.strength", defaultValue: "Strength")
        case .skill:    String(localized: "sessionType.skill", defaultValue: "Skill")
        case .cardio:   String(localized: "sessionType.cardio", defaultValue: "Cardio")
        case .match:    String(localized: "sessionType.match", defaultValue: "Match")
        case .recovery: String(localized: "sessionType.recovery", defaultValue: "Recovery")
        }
    }
}

// MARK: - Onboarding Enums

enum TrainingFrequency: String, Codable, CaseIterable, Identifiable {
    case oneToTwo
    case threeToFour
    case fiveToSix
    case sevenPlus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneToTwo: String(localized: "frequency.oneToTwo", defaultValue: "1-2 days/week")
        case .threeToFour: String(localized: "frequency.threeToFour", defaultValue: "3-4 days/week")
        case .fiveToSix: String(localized: "frequency.fiveToSix", defaultValue: "5-6 days/week")
        case .sevenPlus: String(localized: "frequency.sevenPlus", defaultValue: "7+ days/week")
        }
    }
}

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner: String(localized: "experience.beginner", defaultValue: "Beginner")
        case .intermediate: String(localized: "experience.intermediate", defaultValue: "Intermediate")
        case .advanced: String(localized: "experience.advanced", defaultValue: "Advanced")
        }
    }

    var subtitle: String {
        switch self {
        case .beginner: String(localized: "experience.beginner.subtitle", defaultValue: "New to structured training")
        case .intermediate: String(localized: "experience.intermediate.subtitle", defaultValue: "1-3 years consistent training")
        case .advanced: String(localized: "experience.advanced.subtitle", defaultValue: "3+ years, understands periodization")
        }
    }
}

// MARK: - Injury Enums

enum BodyRegion: String, Codable, CaseIterable, Identifiable {
    case shoulder
    case knee
    case back
    case hip
    case ankle
    case wrist
    case elbow
    case neck

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shoulder: String(localized: "bodyRegion.shoulder", defaultValue: "Shoulder")
        case .knee: String(localized: "bodyRegion.knee", defaultValue: "Knee")
        case .back: String(localized: "bodyRegion.back", defaultValue: "Back")
        case .hip: String(localized: "bodyRegion.hip", defaultValue: "Hip")
        case .ankle: String(localized: "bodyRegion.ankle", defaultValue: "Ankle")
        case .wrist: String(localized: "bodyRegion.wrist", defaultValue: "Wrist")
        case .elbow: String(localized: "bodyRegion.elbow", defaultValue: "Elbow")
        case .neck: String(localized: "bodyRegion.neck", defaultValue: "Neck")
        }
    }
}

struct InjuryEntry: Codable {
    let bodyRegion: BodyRegion
    let notes: String?
    let isActive: Bool
}

// MARK: - Cycle Enums

enum CyclePhase: String, Codable, CaseIterable, Identifiable {
    case earlyFollicular
    case lateFollicular
    case ovulatory
    case earlyLuteal
    case lateLuteal
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .earlyFollicular: String(localized: "cyclePhase.earlyFollicular", defaultValue: "Early Follicular")
        case .lateFollicular: String(localized: "cyclePhase.lateFollicular", defaultValue: "Late Follicular")
        case .ovulatory: String(localized: "cyclePhase.ovulatory", defaultValue: "Ovulatory")
        case .earlyLuteal: String(localized: "cyclePhase.earlyLuteal", defaultValue: "Early Luteal")
        case .lateLuteal: String(localized: "cyclePhase.lateLuteal", defaultValue: "Late Luteal")
        case .unknown: String(localized: "cyclePhase.unknown", defaultValue: "Unknown")
        }
    }
}
