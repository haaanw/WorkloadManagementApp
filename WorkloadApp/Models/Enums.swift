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
        case .undertrained: String(localized: "zone.low", defaultValue: "Load Light")
        case .optimal: String(localized: "zone.optimal", defaultValue: "Load Steady")
        case .caution: String(localized: "zone.caution", defaultValue: "Load Building")
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

/// High-level region used to group `MuscleGroup` cases into a
/// region -> sub-group hierarchy in the muscle picker.
///
/// Named `MuscleRegion` (not `BodyRegion`) to avoid colliding with the
/// pre-existing injury-tracking `BodyRegion` enum (joints: shoulder, knee,
/// hip, ...). `fullBody` is retained as a region because cardio / running /
/// team-sport seed exercises depend on the coarse `MuscleGroup.fullBody`
/// value (see Phase 22 D-02).
enum MuscleRegion: String, Codable, CaseIterable, Identifiable {
    case legs
    case back
    case chest
    case shoulders
    case arms
    case core
    case fullBody

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .legs: String(localized: "muscleRegion.legs", defaultValue: "Legs")
        case .back: String(localized: "muscleRegion.back", defaultValue: "Back")
        case .chest: String(localized: "muscleRegion.chest", defaultValue: "Chest")
        case .shoulders: String(localized: "muscleRegion.shoulders", defaultValue: "Shoulders")
        case .arms: String(localized: "muscleRegion.arms", defaultValue: "Arms")
        case .core: String(localized: "muscleRegion.core", defaultValue: "Core")
        case .fullBody: String(localized: "muscleRegion.fullBody", defaultValue: "Full Body")
        }
    }

    var systemImage: String {
        switch self {
        case .legs: "figure.walk"
        case .back: "figure.stand"
        case .chest: "figure.arms.open"
        case .shoulders: "figure.strengthtraining.functional"
        case .arms: "dumbbell.fill"
        case .core: "figure.core.training"
        case .fullBody: "figure.strengthtraining.traditional"
        }
    }
}

/// Anatomically specific muscle taxonomy (Phase 22).
///
/// The original 7 coarse cases (`chest, back, legs, shoulders, arms, core,
/// fullBody`) are RETAINED with their exact original rawValues so every
/// existing SwiftData row and `groups_json` blob continues to decode
/// without migration (backward compat by retention — see D-03). The new
/// ~26 specific cases are purely additive lowerCamelCase rawValues, which
/// are permanent serialization contracts and must never be renamed.
enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    // MARK: Retained coarse cases (region-level aliases — D-03/D-04)
    case chest
    case back
    case legs
    case shoulders
    case arms
    case core
    case fullBody

    // MARK: Legs (specific)
    case quads
    case hamstrings
    case glutes
    case calves
    case hipFlexors
    case psoas
    case adductors
    case hipRotators
    case tibialisAnterior

    // MARK: Back (specific)
    case lats
    case trapsUpper
    case trapsMid
    case trapsLower
    case rhomboids
    case erectors

    // MARK: Chest (specific)
    case pecsUpper
    case pecsLower

    // MARK: Shoulders (specific)
    case anteriorDelts
    case lateralDelts
    case posteriorDelts

    // MARK: Arms (specific)
    case biceps
    case triceps
    case forearms

    // MARK: Core (specific)
    case rectusAbdominis
    case obliques
    case transverseAbdominis

    var id: String { rawValue }

    var displayName: String {
        switch self {
        // Retained coarse cases keep their region-name label (D-04)
        case .chest: String(localized: "muscleGroup.chest", defaultValue: "Chest")
        case .back: String(localized: "muscleGroup.back", defaultValue: "Back")
        case .legs: String(localized: "muscleGroup.legs", defaultValue: "Legs")
        case .shoulders: String(localized: "muscleGroup.shoulders", defaultValue: "Shoulders")
        case .arms: String(localized: "muscleGroup.arms", defaultValue: "Arms")
        case .core: String(localized: "muscleGroup.core", defaultValue: "Core")
        case .fullBody: String(localized: "muscleGroup.fullBody", defaultValue: "Full Body")
        // Legs
        case .quads: String(localized: "muscleGroup.quads", defaultValue: "Quads")
        case .hamstrings: String(localized: "muscleGroup.hamstrings", defaultValue: "Hamstrings")
        case .glutes: String(localized: "muscleGroup.glutes", defaultValue: "Glutes")
        case .calves: String(localized: "muscleGroup.calves", defaultValue: "Calves")
        case .hipFlexors: String(localized: "muscleGroup.hipFlexors", defaultValue: "Hip Flexors")
        case .psoas: String(localized: "muscleGroup.psoas", defaultValue: "Psoas")
        case .adductors: String(localized: "muscleGroup.adductors", defaultValue: "Adductors")
        case .hipRotators: String(localized: "muscleGroup.hipRotators", defaultValue: "Hip Rotators")
        case .tibialisAnterior: String(localized: "muscleGroup.tibialisAnterior", defaultValue: "Tibialis Anterior")
        // Back
        case .lats: String(localized: "muscleGroup.lats", defaultValue: "Lats")
        case .trapsUpper: String(localized: "muscleGroup.trapsUpper", defaultValue: "Upper Traps")
        case .trapsMid: String(localized: "muscleGroup.trapsMid", defaultValue: "Mid Traps")
        case .trapsLower: String(localized: "muscleGroup.trapsLower", defaultValue: "Lower Traps")
        case .rhomboids: String(localized: "muscleGroup.rhomboids", defaultValue: "Rhomboids")
        case .erectors: String(localized: "muscleGroup.erectors", defaultValue: "Erectors")
        // Chest
        case .pecsUpper: String(localized: "muscleGroup.pecsUpper", defaultValue: "Upper Chest")
        case .pecsLower: String(localized: "muscleGroup.pecsLower", defaultValue: "Lower Chest")
        // Shoulders
        case .anteriorDelts: String(localized: "muscleGroup.anteriorDelts", defaultValue: "Front Delts")
        case .lateralDelts: String(localized: "muscleGroup.lateralDelts", defaultValue: "Side Delts")
        case .posteriorDelts: String(localized: "muscleGroup.posteriorDelts", defaultValue: "Rear Delts")
        // Arms
        case .biceps: String(localized: "muscleGroup.biceps", defaultValue: "Biceps")
        case .triceps: String(localized: "muscleGroup.triceps", defaultValue: "Triceps")
        case .forearms: String(localized: "muscleGroup.forearms", defaultValue: "Forearms")
        // Core
        case .rectusAbdominis: String(localized: "muscleGroup.rectusAbdominis", defaultValue: "Rectus Abdominis")
        case .obliques: String(localized: "muscleGroup.obliques", defaultValue: "Obliques")
        case .transverseAbdominis: String(localized: "muscleGroup.transverseAbdominis", defaultValue: "Transverse Abdominis")
        }
    }

    /// The muscle region this muscle belongs to. Exhaustive over all cases
    /// (old + new) — single source of truth for grouping the picker.
    var region: MuscleRegion {
        switch self {
        // Retained coarse cases map to their own region
        case .chest: .chest
        case .back: .back
        case .legs: .legs
        case .shoulders: .shoulders
        case .arms: .arms
        case .core: .core
        case .fullBody: .fullBody
        // Legs
        case .quads, .hamstrings, .glutes, .calves, .hipFlexors, .psoas,
             .adductors, .hipRotators, .tibialisAnterior: .legs
        // Back
        case .lats, .trapsUpper, .trapsMid, .trapsLower, .rhomboids, .erectors: .back
        // Chest
        case .pecsUpper, .pecsLower: .chest
        // Shoulders
        case .anteriorDelts, .lateralDelts, .posteriorDelts: .shoulders
        // Arms
        case .biceps, .triceps, .forearms: .arms
        // Core
        case .rectusAbdominis, .obliques, .transverseAbdominis: .core
        }
    }

    var systemImage: String { region.systemImage }

    /// Default specific muscle for a coarse region value, used by the
    /// picker's "specify" UX (D-05). Returns the input unchanged for any
    /// value that is already specific (idempotent). Never rewrites stored
    /// data — only nudges the user when they actively re-specify.
    static func suggestedSpecific(for coarse: MuscleGroup) -> MuscleGroup {
        switch coarse {
        case .legs: .quads
        case .chest: .pecsLower
        case .back: .lats
        case .shoulders: .lateralDelts
        case .arms: .biceps
        case .core: .rectusAbdominis
        case .fullBody: .fullBody
        // Already-specific values are returned unchanged
        default: coarse
        }
    }
}

/// Localized self-reported niggle type for the on-device Soreness self-log (Phase 25, D-02).
///
/// The `rawValue`s ("soreness"/"pain"/"tweak") are a **permanent serialization contract** — they
/// are persisted into `SorenessLog.typeRaw` and must never be renamed. The enum being `Codable`
/// is fine; only the `SorenessLog` @Model must avoid `Codable` to stay local-only (D-01).
enum NiggleType: String, Codable, CaseIterable, Identifiable {
    case soreness
    case pain
    case tweak

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .soreness: String(localized: "niggleType.soreness", defaultValue: "Soreness")
        case .pain: String(localized: "niggleType.pain", defaultValue: "Pain")
        case .tweak: String(localized: "niggleType.tweak", defaultValue: "Tweak")
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

// MARK: - Strain-Risk Enum (Phase 27 — heuristic load-tolerance context, NOT injury prediction)

/// Categorical zone for the Phase-27 Strain-Risk channel.
///
/// Strain-Risk is an HONEST heuristic **load-tolerance / overreaching-caution** flag produced
/// by the glass-box `StrainRiskEngine`. It is display/shadow context only this phase and
/// deliberately NEVER frames itself as injury prediction — none of the copy below contains
/// "injury prediction", "injury risk", "predicts injury", or "will get injured" (D-27-01,
/// enforced by a string-audit test). It does NOT drive the live recommendation or recovery
/// score in Phase 27.
enum StrainRiskZone: String, Codable, CaseIterable, Identifiable {
    case low
    case moderate
    case elevated
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: String(localized: "strainRiskZone.low", defaultValue: "Low")
        case .moderate: String(localized: "strainRiskZone.moderate", defaultValue: "Moderate")
        case .elevated: String(localized: "strainRiskZone.elevated", defaultValue: "Elevated load-tolerance caution")
        case .high: String(localized: "strainRiskZone.high", defaultValue: "High overreaching caution")
        }
    }

    var systemImage: String {
        switch self {
        case .low: "checkmark.circle"
        case .moderate: "circle.lefthalf.filled"
        case .elevated: "exclamationmark.triangle"
        case .high: "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Readiness Enum (Phase 28 — PRS-v1 Personal Readiness, separate channel from Strain-Risk)

/// Categorical zone for the Phase-28 **Readiness** channel (PRS-v1).
///
/// Readiness is a SEPARATE scalar from Strain-Risk (GA-1): it answers "how recovered / ready to
/// train is this athlete today" via a FIXED sign-constrained glass-box logistic fusion of the
/// Phase-26 personal z-scores (`ReadinessFusionEngine`). It is NOT a load-tolerance flag (that is
/// `StrainRiskZone`) and it is NEVER framed as injury prediction — none of the copy below contains
/// "injury prediction", "injury risk", "predicts injury", or "will get injured" (GA-11, enforced by
/// the no-prediction-copy grep guard).
///
/// 3 levels (low / moderate / high — GA-3) mirroring `RecoveryZone` granularity so the new
/// (readiness × strain-risk) decision matrix has the same shape discipline as the legacy
/// (recovery × ACWR) matrix. Zone-cut thresholds are FIXED named constants defined on
/// `ReadinessFusionEngine` (not magic numbers here).
///
/// This is shadow/flagged context this phase: with `PRSActivation.isEnabled == false` it never
/// reaches the live recommendation.
enum ReadinessZone: String, Codable, CaseIterable, Identifiable {
    case low
    case moderate
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: String(localized: "readinessZone.low", defaultValue: "Low Readiness")
        case .moderate: String(localized: "readinessZone.moderate", defaultValue: "Moderate Readiness")
        case .high: String(localized: "readinessZone.high", defaultValue: "High Readiness")
        }
    }

    var systemImage: String {
        switch self {
        case .low: "battery.25"
        case .moderate: "battery.50"
        case .high: "battery.100"
        }
    }
}

// MARK: - Coach / Role Enums

enum RelationshipStatus: String, Codable {
    case pending
    case accepted
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

    var systemImage: String {
        switch self {
        case .strength: "dumbbell.fill"
        case .skill:    "figure.cooldown"
        case .cardio:   "heart.fill"
        case .match:    "flag.checkered"
        case .recovery: "bed.double.fill"
        }
    }
}

// MARK: - RadialSelectable conformances (Phase 21)

extension SportType: RadialSelectable {
    var radialIcon: String { systemImage }
}

extension SessionType: RadialSelectable {
    var radialIcon: String { systemImage }
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

    /// Readiness-first 2-bucket context-copy localization key (Phase 19 D-05).
    /// Follicular bucket (earlyFollicular/lateFollicular/ovulatory) -> follicular key,
    /// luteal bucket (earlyLuteal/lateLuteal) -> luteal key, .unknown -> nil.
    /// The copy explains the readiness score; it never prescribes training.
    /// Views localize the returned key at render time (LocalizedStringKey).
    var contextCopyKey: String? {
        switch self {
        case .earlyFollicular, .lateFollicular, .ovulatory:
            return "cyclePhase.context.follicular"
        case .earlyLuteal, .lateLuteal:
            return "cyclePhase.context.luteal"
        case .unknown:
            return nil
        }
    }
}
