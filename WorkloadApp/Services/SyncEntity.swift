import Foundation

/// Identifies each entity type that participates in bidirectional sync.
/// Used for per-entity timestamp tracking and error reporting.
enum SyncEntity: String, CaseIterable, Identifiable {
    case workouts
    case templates
    case personalRecords
    case recoverySnapshots
    case wellnessCheckIns
    case workloadSnapshots
    case behaviorTags
    case trainingProfiles

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .workouts: "Workouts"
        case .templates: "Templates"
        case .personalRecords: "Personal Records"
        case .recoverySnapshots: "Recovery"
        case .wellnessCheckIns: "Wellness"
        case .workloadSnapshots: "Training Load"
        case .behaviorTags: "Behavior Tags"
        case .trainingProfiles: "Training Profile"
        }
    }
}

/// Direction of a sync operation, used in structured error logging.
enum SyncDirection: String {
    case pull, push
}
