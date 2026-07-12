import Foundation

/// Fast, deterministic classification for free-text movements entered during a workout.
struct ExerciseClassifier {
    struct Classification: Equatable {
        let category: ExerciseCategory
        let muscleGroup: MuscleGroup?
    }

    static func classify(_ name: String) -> Classification {
        let movement = NormalizedMovement(name)

        if movement.containsAny([
            "shooting", "shooting drill", "shot practice", "free throw", "layup",
            "dribbling", "dribble", "ball handling", "handles", "finishing drill",
            "defensive slide", "closeout", "agility", "agility ladder", "cone drill",
            "footwork", "skill drill", "basketball drill", "practice drill"
        ]) {
            let muscle: MuscleGroup = movement.containsAny([
                "agility", "ladder", "defensive slide", "footwork", "closeout", "cone"
            ]) ? .legs : .fullBody
            return Classification(category: .drill, muscleGroup: muscle)
        }

        if movement.containsAny([
            "box jump", "depth jump", "broad jump", "vertical jump", "countermovement jump",
            "drop jump", "tuck jump", "pogo", "hop", "bounds", "bounding", "plyometric"
        ]) {
            let muscle: MuscleGroup = movement.containsAny(["pogo", "ankle hop"])
                ? .calves
                : .legs
            return Classification(category: .plyometric, muscleGroup: muscle)
        }

        if movement.containsAny([
            "plank", "push up", "pushup", "pull up", "pullup", "chin up", "chinup",
            "dip", "bodyweight squat", "air squat", "sit up", "situp", "crunch",
            "burpee", "mountain climber", "hollow hold", "wall sit"
        ]) {
            return Classification(
                category: .bodyweight,
                muscleGroup: bodyweightMuscle(for: movement)
            )
        }

        if movement.containsAny([
            "run", "running", "jog", "jogging", "bike", "biking", "bicycle", "cycling",
            "row erg", "rowing erg", "ergometer", "erg", "rowing machine", "swim", "swimming",
            "ski erg", "elliptical", "stair climber", "treadmill", "assault bike",
            "air bike", "spin bike"
        ]) {
            let muscle: MuscleGroup = movement.containsAny([
                "bike", "biking", "bicycle", "cycling", "stair climber", "spin bike"
            ]) ? .legs : .fullBody
            return Classification(category: .cardio, muscleGroup: muscle)
        }

        if movement.containsAny([
            "sprint", "suicide", "shuttle", "interval", "tempo", "fartlek", "hill repeat"
        ]) {
            return Classification(category: .interval, muscleGroup: .legs)
        }

        if movement.containsAny([
            "curl", "raise", "extension", "fly", "flye", "pulldown", "pushdown",
            "pec deck", "kickback", "adduction", "abduction", "calf press"
        ]) {
            return Classification(
                category: .isolation,
                muscleGroup: isolationMuscle(for: movement)
            )
        }

        if movement.containsAny([
            "squat", "deadlift", "press", "row", "clean", "snatch", "lunge",
            "split squat", "hip thrust", "good morning", "bench", "thruster",
            "jerk", "step up", "stepup"
        ]) {
            return Classification(
                category: .compound,
                muscleGroup: compoundMuscle(for: movement)
            )
        }

        return Classification(category: .isolation, muscleGroup: nil)
    }

    private static func bodyweightMuscle(for movement: NormalizedMovement) -> MuscleGroup {
        if movement.containsAny(["plank", "hollow hold", "sit up", "situp", "crunch"]) {
            return .rectusAbdominis
        }
        if movement.containsAny(["pull up", "pullup", "chin up", "chinup"]) {
            return .lats
        }
        if movement.containsAny(["push up", "pushup", "dip"]) {
            return .chest
        }
        if movement.containsAny(["squat", "wall sit"]) {
            return .quads
        }
        return .fullBody
    }

    private static func isolationMuscle(for movement: NormalizedMovement) -> MuscleGroup? {
        if movement.containsAny(["hamstring curl", "leg curl", "nordic curl"]) { return .hamstrings }
        if movement.containsAny(["bicep", "biceps", "preacher", "hammer curl", "curl"]) { return .biceps }
        if movement.containsAny(["tricep", "triceps", "pushdown", "skull crusher", "kickback"]) { return .triceps }
        if movement.containsAny(["leg extension", "knee extension"]) { return .quads }
        if movement.containsAny(["calf", "heel raise"]) { return .calves }
        if movement.containsAny(["lateral raise", "side raise"]) { return .lateralDelts }
        if movement.containsAny(["rear delt", "reverse fly", "face pull"]) { return .posteriorDelts }
        if movement.containsAny(["front raise"]) { return .anteriorDelts }
        if movement.containsAny(["pulldown", "straight arm pull"]) { return .lats }
        if movement.containsAny(["fly", "flye", "pec deck"]) { return .chest }
        if movement.containsAny(["hip abduction"]) { return .glutes }
        if movement.containsAny(["hip adduction"]) { return .adductors }
        return nil
    }

    private static func compoundMuscle(for movement: NormalizedMovement) -> MuscleGroup {
        if movement.containsAny(["clean", "snatch", "thruster", "jerk"]) { return .fullBody }
        if movement.containsAny(["deadlift", "good morning"]) { return .hamstrings }
        if movement.containsAny(["squat", "lunge", "split squat", "leg press", "step up", "stepup"]) {
            return .quads
        }
        if movement.containsAny(["hip thrust", "glute bridge"]) { return .glutes }
        if movement.containsAny(["row"]) { return .back }
        if movement.containsAny(["bench", "chest press"]) { return .chest }
        if movement.containsAny(["overhead press", "shoulder press", "military press", "push press"]) {
            return .shoulders
        }
        return .fullBody
    }
}

private struct NormalizedMovement {
    private let padded: String

    init(_ value: String) {
        let normalized = value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .joined(separator: " ")
        padded = " \(normalized) "
    }

    func containsAny(_ aliases: [String]) -> Bool {
        aliases.contains {
            padded.contains(" \($0) ") || padded.contains(" \($0)s ")
        }
    }
}
