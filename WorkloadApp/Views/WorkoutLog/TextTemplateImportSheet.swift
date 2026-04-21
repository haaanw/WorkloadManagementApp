import SwiftUI
import SwiftData

/// Parses a plain-text workout program and creates WorkoutTemplates.
///
/// Supported formats:
/// ```
/// Day 1: Upper Body
/// Bench Press 4x8 @RPE 7
/// Barbell Row 4x8
/// Overhead Press 3x10
///
/// Day 2: Lower Body
/// Squat 5x5 @80kg
/// Romanian Deadlift 3x10
/// Leg Press 3x12
/// ```
struct TextTemplateImportSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var athletes: [Athlete]

    @State private var inputText = ""
    @State private var parsedTemplates: [ParsedTemplate] = []
    @State private var parseError: String?
    @State private var isSaving = false

    private var athlete: Athlete? { athletes.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Input area
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paste your workout program below. Each day/session should start with a header line.")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)

                    TextEditor(text: $inputText)
                        .font(.custom("DMSans-Regular", size: 14))
                        .frame(minHeight: 200)
                        .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))

                    Button {
                        parseInput()
                    } label: {
                        Text("Parse")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(16)

                if let error = parseError {
                    Text(error)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.zoneDanger)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // Preview parsed templates
                if !parsedTemplates.isEmpty {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(parsedTemplates.enumerated()), id: \.offset) { _, template in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name)
                                        .font(.Tokens.sectionHead)
                                        .foregroundStyle(ColorTokens.text1)
                                    ForEach(template.exercises, id: \.name) { exercise in
                                        HStack {
                                            Text(exercise.name)
                                                .font(.Tokens.body)
                                                .foregroundStyle(ColorTokens.text2)
                                            Spacer()
                                            Text(exercise.summary)
                                                .font(.Tokens.label)
                                                .monospacedDigit()
                                                .foregroundStyle(ColorTokens.text3)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                            }
                        }
                    }
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("Import Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save All") { saveTemplates() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                        .disabled(parsedTemplates.isEmpty || isSaving)
                }
            }
        }
    }

    // MARK: - Parser

    private func parseInput() {
        parseError = nil
        let lines = inputText.components(separatedBy: .newlines)
        var templates: [ParsedTemplate] = []
        var currentTemplate: ParsedTemplate?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Detect day/session header
            if isHeaderLine(trimmed) {
                if let current = currentTemplate, !current.exercises.isEmpty {
                    templates.append(current)
                }
                currentTemplate = ParsedTemplate(name: cleanHeaderName(trimmed))
            } else if var current = currentTemplate {
                // Parse exercise line
                if let exercise = parseExerciseLine(trimmed) {
                    current.exercises.append(exercise)
                    currentTemplate = current
                }
            } else {
                // No header yet — create default
                currentTemplate = ParsedTemplate(name: "Workout")
                if let exercise = parseExerciseLine(trimmed) {
                    currentTemplate?.exercises.append(exercise)
                }
            }
        }

        // Capture last template
        if let current = currentTemplate, !current.exercises.isEmpty {
            templates.append(current)
        }

        if templates.isEmpty {
            parseError = "Could not parse any exercises. Try format: \"Bench Press 4x8 @RPE 7\""
        }

        parsedTemplates = templates
    }

    private func isHeaderLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.hasPrefix("day ") ||
               lower.hasPrefix("session ") ||
               lower.hasPrefix("workout ") ||
               lower.contains(":") && !lower.contains("x") // "Upper Body:" but not "4x8"
    }

    private func cleanHeaderName(_ line: String) -> String {
        var name = line
        // Remove "Day 1:", "Session A:", etc.
        if let colonIdx = name.firstIndex(of: ":") {
            name = String(name[name.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
            if name.isEmpty { name = line }
        }
        // Remove leading "Day 1 - " style
        let patterns = ["day \\d+\\s*[-–]\\s*", "session \\d+\\s*[-–]\\s*", "workout \\d+\\s*[-–]\\s*"]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(name.startIndex..., in: name)
                name = regex.stringByReplacingMatches(in: name, range: range, withTemplate: "")
            }
        }
        return name.trimmingCharacters(in: .whitespaces).isEmpty ? line : name.trimmingCharacters(in: .whitespaces)
    }

    /// Parse "Bench Press 4x8 @RPE 7" or "Squat 5x5 @80kg"
    private func parseExerciseLine(_ line: String) -> ParsedExercise? {
        // Match pattern: <name> <sets>x<reps> [optional: @weight or @RPE N]
        let setsRepsPattern = #"(.+?)\s+(\d+)\s*[xX×]\s*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: setsRepsPattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            // Try name-only (no sets/reps specified)
            let cleaned = line.trimmingCharacters(in: .whitespaces)
            guard !cleaned.isEmpty, cleaned.count > 2 else { return nil }
            return ParsedExercise(name: cleaned, sets: 3, reps: 10, weight: nil, rpe: nil)
        }

        let nameRange = Range(match.range(at: 1), in: line)!
        let setsRange = Range(match.range(at: 2), in: line)!
        let repsRange = Range(match.range(at: 3), in: line)!

        let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
        let sets = Int(line[setsRange]) ?? 3
        let reps = Int(line[repsRange]) ?? 10

        // Parse optional weight or RPE
        var weight: Double?
        var rpe: Double?
        let remainder = String(line[repsRange.upperBound...]).lowercased()

        if let rpeMatch = remainder.range(of: #"@?\s*rpe\s*(\d+\.?\d*)"#, options: .regularExpression) {
            let rpeStr = remainder[rpeMatch].components(separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ".")).inverted).joined()
            rpe = Double(rpeStr)
        }

        if let weightMatch = remainder.range(of: #"@?\s*(\d+\.?\d*)\s*kg"#, options: .regularExpression) {
            let weightStr = remainder[weightMatch].components(separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ".")).inverted).joined()
            weight = Double(weightStr)
        }

        return ParsedExercise(name: name, sets: sets, reps: reps, weight: weight, rpe: rpe)
    }

    // MARK: - Save

    private func saveTemplates() {
        guard let ownerId = athlete?.id else { return }
        isSaving = true

        for parsed in parsedTemplates {
            let template = WorkoutTemplate(
                coachId: ownerId,
                templateName: parsed.name,
                sportType: .lifting,
                sessionType: .strength
            )

            let group = ExerciseGroup(groupName: "Main", orderIndex: 0)

            for (idx, exercise) in parsed.exercises.enumerated() {
                let category = matchCategory(exercise.name)
                let templateExercise = TemplateExercise(
                    exerciseName: exercise.name,
                    exerciseCategory: category,
                    orderIndex: idx
                )

                for setIdx in 0..<exercise.sets {
                    let templateSet = TemplateSet(
                        setIndex: setIdx,
                        targetReps: exercise.reps,
                        targetWeightKg: exercise.weight,
                        targetRPE: exercise.rpe
                    )
                    templateExercise.sets.append(templateSet)
                }

                group.exercises.append(templateExercise)
            }

            template.groups.append(group)
            modelContext.insert(template)
        }

        try? modelContext.save()
        isSaving = false
        dismiss()
    }

    /// Try to match exercise name to a known category
    private func matchCategory(_ name: String) -> ExerciseCategory {
        let lower = name.lowercased()
        // Check if it exists in the built-in database
        if let def = ExerciseDatabase.all.first(where: { $0.name.lowercased() == lower }) {
            return def.category
        }
        // Heuristic
        if lower.contains("run") || lower.contains("jog") || lower.contains("sprint") { return .cardio }
        if lower.contains("drill") || lower.contains("practice") { return .drill }
        if lower.contains("plank") || lower.contains("push up") || lower.contains("pull up") { return .bodyweight }
        return .compound // default assumption for strength exercises
    }
}

// MARK: - Parsed Types

private struct ParsedTemplate {
    var name: String
    var exercises: [ParsedExercise] = []
}

private struct ParsedExercise {
    let name: String
    let sets: Int
    let reps: Int
    let weight: Double?
    let rpe: Double?

    var summary: String {
        var s = "\(sets)×\(reps)"
        if let w = weight { s += " @\(String(format: "%.0f", w))kg" }
        if let r = rpe { s += " RPE \(String(format: "%.0f", r))" }
        return s
    }
}
