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
        case .lifting: "Lifting"
        case .running: "Running"
        case .cycling: "Cycling"
        case .teamSport: "Team Sport"
        case .crossfit: "CrossFit"
        case .swimming: "Swimming"
        case .custom: "Custom"
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
        case .kg: "kg"
        case .lbs: "lbs"
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
        case .ewma: "EWMA"
        case .rolling28day: "Rolling 28-Day"
        }
    }
}

enum LoadSource: String, Codable, CaseIterable {
    case srpe
    case trimp
    case combined

    var displayName: String {
        switch self {
        case .srpe: "sRPE"
        case .trimp: "TRIMP"
        case .combined: "Combined"
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
        case 0.8...1.3: return .optimal
        case 1.3...1.5: return .caution
        default: return .danger
        }
    }

    var displayName: String {
        switch self {
        case .undertrained: "Undertrained"
        case .optimal: "Optimal"
        case .caution: "Caution"
        case .danger: "Danger"
        case .noData: "No Data"
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
        case .compound: "Compound"
        case .isolation: "Isolation"
        case .cardio: "Cardio"
        case .bodyweight: "Bodyweight"
        case .plyometric: "Plyometric"
        case .drill: "Drill"
        case .interval: "Interval"
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
        case .chest: "Chest"
        case .back: "Back"
        case .legs: "Legs"
        case .shoulders: "Shoulders"
        case .arms: "Arms"
        case .core: "Core"
        case .fullBody: "Full Body"
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
        case .maxWeight: "Max Weight"
        case .maxReps: "Max Reps"
        case .maxVolume: "Max Volume"
        case .fastestPace: "Fastest Pace"
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
        case .red: "Rest / Light Only"
        case .yellow: "Cautious"
        case .green: "Go"
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
        case .assigned: "Assigned"
        case .completed: "Completed"
        case .skipped: "Skipped"
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
        case .strength: "Strength"
        case .skill:    "Skill"
        case .cardio:   "Cardio"
        case .match:    "Match"
        case .recovery: "Recovery"
        }
    }
}
