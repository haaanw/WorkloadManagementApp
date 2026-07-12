import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppContainer.self) private var container
    @Query private var customExercises: [CustomExercise]
    @Query private var athletes: [Athlete]
    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var showAddCustom = false
    @State private var showUpgrade = false

    // TODO: revisit cap for commercial tiers.

    let sportType: SportType
    let onSelect: (String, ExerciseCategory, MuscleGroup?) -> Void

    private var allExercises: [ExerciseDefinition] {
        var results = ExerciseDatabase.exercises(for: sportType)
        results.append(contentsOf: customExercises
            .filter { $0.sportType == nil || $0.sportType == sportType }
            .map {
                ExerciseDefinition(
                    name: $0.name,
                    category: $0.exerciseCategory,
                    muscleGroup: $0.muscleGroup,
                    isCustom: true
                )
            })
        return results
    }

    private var filteredExercises: [ExerciseDefinition] {
        var results = allExercises
        if let selectedCategory {
            results = results.filter { $0.category == selectedCategory }
        }
        if !searchText.isEmpty {
            results = results.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return results
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shouldOfferInstantAdd: Bool {
        guard !trimmedSearchText.isEmpty else { return false }
        return !allExercises.contains {
            $0.name.compare(
                trimmedSearchText,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame
        }
    }

    private var relevantCategories: [ExerciseCategory] {
        let categories = Set(allExercises.map(\.category))
        return ExerciseCategory.allCases.filter { categories.contains($0) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        FilterChip(
                            label: String(localized: "filter.all", defaultValue: "All"),
                            isSelected: selectedCategory == nil
                        ) {
                            selectedCategory = nil
                        }
                        ForEach(relevantCategories) { category in
                            FilterChip(
                                label: category.displayName,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                }

                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)

                List {
                    if shouldOfferInstantAdd {
                        Button {
                            instantlyAddSearchText()
                        } label: {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "plus")
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                                Text(
                                    String(
                                        format: String(
                                            localized: "exercise.action.addQuery",
                                            defaultValue: "Add “%@”"
                                        ),
                                        trimmedSearchText
                                    )
                                )
                                .font(.Tokens.bodyMedium)
                                .foregroundStyle(ColorTokens.text1)
                                Spacer()
                            }
                            .padding(.vertical, Spacing.xs)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressable)
                        .listRowBackground(ColorTokens.surfaceEl2)
                    }

                    ForEach(filteredExercises, id: \.name) { exercise in
                        Button {
                            Haptics.select()
                            onSelect(exercise.name, exercise.category, exercise.muscleGroup)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                                    Text(exercise.name)
                                        .font(.Tokens.body)
                                        .foregroundStyle(ColorTokens.text1)
                                    HStack {
                                        Text(exercise.category.displayName)
                                        if let muscle = exercise.muscleGroup {
                                            Text("·")
                                            Text(muscle.displayName)
                                        }
                                        if exercise.isCustom {
                                            Text("·")
                                            Text("sport.custom")
                                        }
                                    }
                                    .font(.Tokens.label)
                                    .foregroundStyle(ColorTokens.text2)
                                }
                                Spacer()
                            }
                        }
                        .foregroundStyle(ColorTokens.text1)
                        .swipeActions(edge: .trailing) {
                            if exercise.isCustom {
                                Button(role: .destructive) {
                                    deleteCustomExercise(named: exercise.name)
                                } label: {
                                    Label("action.delete", systemImage: "trash")
                                }
                            }
                        }
                    }

                    if filteredExercises.isEmpty && !shouldOfferInstantAdd {
                        Text("empty.noExercises")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text2)
                    }
                }
                .listStyle(.plain)
            }
            .background(ColorTokens.background)
            .navigationTitle("exercise.nav.select")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "exercise.search.prompt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        tryAddCustom()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(ColorTokens.text1)
                    }
                }
            }
            .sheet(isPresented: $showAddCustom) {
                AddCustomExerciseSheet(initialName: searchText, sportType: sportType) {
                    name, category, muscle in
                    onSelect(name, category, muscle)
                }
            }
            .sheet(isPresented: $showUpgrade) {
                UpgradeSheet(trigger: .athletePro)
                    .environment(container)
            }
        }
    }

    private func instantlyAddSearchText() {
        let name = trimmedSearchText
        guard !name.isEmpty else { return }
        let classification = ExerciseClassifier.classify(name)
        let shouldPersist = container.subscriptionService.isPro
        let client = container.supabase
        let athlete = athletes.first
        let context = modelContext

        Haptics.select()
        onSelect(name, classification.category, classification.muscleGroup)
        dismiss()

        Task { @MainActor in
            var savedExercise: CustomExercise?
            if shouldPersist {
                let exercise = CustomExercise(
                    name: name,
                    exerciseCategory: classification.category,
                    muscleGroup: classification.muscleGroup ?? .fullBody,
                    sportType: sportType
                )
                exercise.muscleGroup = classification.muscleGroup
                exercise.athlete = athlete
                context.insert(exercise)
                if (try? context.save()) != nil {
                    savedExercise = exercise
                } else {
                    context.delete(exercise)
                }
            }

            guard let response = try? await WorkoutLLMImportService.parseWorkoutText(
                "\(name) 3x8",
                client: client
            ), let parsed = response.groups.first?.exercises.first else {
                return
            }

            let refinedCategory = WorkoutLLMImportService.mapExerciseCategory(
                parsed.exercise_category
            )
            let refinedMuscle = WorkoutLLMImportService.mapMuscleGroup(parsed.muscle_group)
            guard refinedCategory != classification.category
                    || refinedMuscle != classification.muscleGroup,
                  let savedExercise else {
                return
            }
            savedExercise.exerciseCategory = refinedCategory
            savedExercise.muscleGroup = refinedMuscle
            try? context.save()
        }
    }

    private func tryAddCustom() {
        showAddCustom = true
    }

    private func deleteCustomExercise(named name: String) {
        if let exercise = customExercises.first(where: { $0.name == name }) {
            modelContext.delete(exercise)
            try? modelContext.save()
        }
    }
}

struct AddCustomExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]
    @State private var name: String
    @State private var category: ExerciseCategory = .drill
    @State private var muscleGroup: MuscleGroup? = .fullBody

    let sportType: SportType
    let onAdd: (String, ExerciseCategory, MuscleGroup?) -> Void

    init(
        initialName: String = "",
        sportType: SportType,
        onAdd: @escaping (String, ExerciseCategory, MuscleGroup?) -> Void
    ) {
        _name = State(initialValue: initialName)
        self.sportType = sportType
        self.onAdd = onAdd
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.sm) {
                TextField(
                    String(localized: "exercise.field.name.placeholder", defaultValue: "Exercise name"),
                    text: $name
                )
                .textFieldStyle(SharpTextFieldStyle())

                Picker("exercise.field.category", selection: $category) {
                    ForEach(ExerciseCategory.allCases) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .pickerStyle(.menu)

                NavigationLink {
                    MuscleGroupSelector(selection: $muscleGroup)
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Text("exercise.field.muscleGroup.required")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                        Spacer()
                        Text(
                            muscleGroup?.displayName
                                ?? String(localized: "muscleGroup.required", defaultValue: "Required")
                        )
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                        Image(systemName: "chevron.right")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text3)
                    }
                    .padding(.vertical, Spacing.xs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)

                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)

                Spacer()
            }
            .padding(Spacing.sm)
            .background(ColorTokens.background)
            .navigationTitle("action.addExercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.add") {
                        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
                              let muscleGroup else { return }
                        let exercise = CustomExercise(
                            name: name.trimmingCharacters(in: .whitespaces),
                            exerciseCategory: category,
                            muscleGroup: muscleGroup,
                            sportType: sportType
                        )
                        exercise.athlete = athletes.first
                        modelContext.insert(exercise)
                        try? modelContext.save()
                        onAdd(exercise.name, exercise.exerciseCategory, exercise.muscleGroup)
                        dismiss()
                    }
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || muscleGroup == nil)
                }
            }
        }
    }
}

struct MuscleGroupSelector: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: MuscleGroup?

    private var suggestion: MuscleGroup? {
        guard let selection else { return nil }
        let suggested = MuscleGroup.suggestedSpecific(for: selection)
        return suggested == selection ? nil : suggested
    }

    private func muscles(in region: MuscleRegion) -> [MuscleGroup] {
        MuscleGroup.allCases.filter { $0.region == region }
    }

    var body: some View {
        List {
            ForEach(MuscleRegion.allCases) { region in
                Section {
                    ForEach(muscles(in: region)) { muscle in
                        row(
                            title: muscle.displayName,
                            isSelected: selection == muscle,
                            isSuggested: suggestion == muscle
                        ) {
                            selection = muscle
                            dismiss()
                        }
                    }
                } header: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: region.systemImage)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                        Text(region.displayName)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(ColorTokens.background)
        .navigationTitle("exercise.nav.muscleGroup")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(
        title: String,
        isSelected: Bool,
        isSuggested: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.select()
            action()
        } label: {
            HStack(spacing: Spacing.xs) {
                VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                    Text(title)
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                    if isSuggested {
                        Text(String(localized: "muscleGroup.suggested", defaultValue: "Suggested"))
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.accent)
                }
            }
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            Text(label)
                .font(.Tokens.label)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .foregroundStyle(isSelected ? ColorTokens.accent : ColorTokens.text2)
                .background(isSelected ? ColorTokens.accentSubtle : ColorTokens.background)
                .overlay(
                    Rectangle().stroke(
                        isSelected ? ColorTokens.accent : ColorTokens.divider,
                        lineWidth: 0.5
                    )
                )
        }
        .buttonStyle(.pressable)
    }
}

struct ExerciseDefinition {
    let name: String
    let category: ExerciseCategory
    let muscleGroup: MuscleGroup?
    var isCustom: Bool = false
}

enum ExerciseDatabase {
    static func exercises(for sportType: SportType) -> [ExerciseDefinition] {
        switch sportType {
        case .lifting, .crossfit: strength + bodyweight + plyometric
        case .running: running
        case .cycling: cycling
        case .swimming: swimming
        case .teamSport: teamSport + bodyweight + plyometric
        case .custom: all
        }
    }

    static let all = strength + bodyweight + plyometric + running + cycling + swimming + teamSport

    static let strength: [ExerciseDefinition] = [
        ExerciseDefinition(name: "Barbell Bench Press", category: .compound, muscleGroup: .chest),
        ExerciseDefinition(name: "Incline Barbell Press", category: .compound, muscleGroup: .chest),
        ExerciseDefinition(name: "Dumbbell Bench Press", category: .compound, muscleGroup: .chest),
        ExerciseDefinition(name: "Incline Dumbbell Press", category: .compound, muscleGroup: .chest),
        ExerciseDefinition(name: "Barbell Row", category: .compound, muscleGroup: .back),
        ExerciseDefinition(name: "Deadlift", category: .compound, muscleGroup: .back),
        ExerciseDefinition(name: "Pull Up", category: .compound, muscleGroup: .back),
        ExerciseDefinition(name: "Lat Pulldown", category: .compound, muscleGroup: .lats),
        ExerciseDefinition(name: "Seated Cable Row", category: .compound, muscleGroup: .back),
        ExerciseDefinition(name: "Barbell Back Squat", category: .compound, muscleGroup: .quads),
        ExerciseDefinition(name: "Front Squat", category: .compound, muscleGroup: .quads),
        ExerciseDefinition(name: "Romanian Deadlift", category: .compound, muscleGroup: .hamstrings),
        ExerciseDefinition(name: "Leg Press", category: .compound, muscleGroup: .quads),
        ExerciseDefinition(name: "Bulgarian Split Squat", category: .compound, muscleGroup: .legs),
        ExerciseDefinition(name: "Hip Thrust", category: .compound, muscleGroup: .glutes),
        ExerciseDefinition(name: "Hex Bar Deadlift", category: .compound, muscleGroup: .legs),
        ExerciseDefinition(name: "Overhead Press", category: .compound, muscleGroup: .shoulders),
        ExerciseDefinition(name: "Dumbbell Shoulder Press", category: .compound, muscleGroup: .shoulders),
        ExerciseDefinition(name: "Bicep Curl", category: .isolation, muscleGroup: .biceps),
        ExerciseDefinition(name: "Tricep Pushdown", category: .isolation, muscleGroup: .triceps),
        ExerciseDefinition(name: "Lateral Raise", category: .isolation, muscleGroup: .lateralDelts),
        ExerciseDefinition(name: "Face Pull", category: .isolation, muscleGroup: .posteriorDelts),
        ExerciseDefinition(name: "Leg Curl", category: .isolation, muscleGroup: .hamstrings),
        ExerciseDefinition(name: "Leg Extension", category: .isolation, muscleGroup: .quads),
        ExerciseDefinition(name: "Cable Fly", category: .isolation, muscleGroup: .chest),
        ExerciseDefinition(name: "Calf Raise", category: .isolation, muscleGroup: .calves),
        ExerciseDefinition(name: "Treadmill Run", category: .cardio, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Rowing Machine", category: .cardio, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Jump Rope", category: .cardio, muscleGroup: .fullBody)
    ]

    static let bodyweight: [ExerciseDefinition] = [
        ExerciseDefinition(name: "Push Up", category: .bodyweight, muscleGroup: .chest),
        ExerciseDefinition(name: "Chin Up", category: .bodyweight, muscleGroup: .back),
        ExerciseDefinition(name: "Dip", category: .bodyweight, muscleGroup: .chest),
        ExerciseDefinition(name: "Plank", category: .bodyweight, muscleGroup: .rectusAbdominis),
        ExerciseDefinition(name: "Hanging Leg Raise", category: .bodyweight, muscleGroup: .rectusAbdominis)
    ]

    static let plyometric: [ExerciseDefinition] = [
        ExerciseDefinition(name: "Box Jump", category: .plyometric, muscleGroup: .legs),
        ExerciseDefinition(name: "Depth Jump", category: .plyometric, muscleGroup: .legs),
        ExerciseDefinition(name: "Hex Bar Jump", category: .plyometric, muscleGroup: .legs),
        ExerciseDefinition(name: "Broad Jump", category: .plyometric, muscleGroup: .legs)
    ]

    static let running: [ExerciseDefinition] = [
        ExerciseDefinition(name: "Easy Run", category: .cardio, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Tempo Run", category: .interval, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Long Run", category: .cardio, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Interval Sprints", category: .interval, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Hill Repeats", category: .interval, muscleGroup: .legs),
        ExerciseDefinition(name: "Recovery Jog", category: .cardio, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Fartlek", category: .interval, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Track Workout", category: .interval, muscleGroup: .fullBody)
    ]

    static let cycling: [ExerciseDefinition] = [
        ExerciseDefinition(name: "Easy Ride", category: .cardio, muscleGroup: .legs),
        ExerciseDefinition(name: "Tempo Ride", category: .interval, muscleGroup: .legs),
        ExerciseDefinition(name: "Long Ride", category: .cardio, muscleGroup: .legs),
        ExerciseDefinition(name: "Hill Climb", category: .interval, muscleGroup: .legs),
        ExerciseDefinition(name: "Sprint Intervals", category: .interval, muscleGroup: .legs),
        ExerciseDefinition(name: "Recovery Spin", category: .cardio, muscleGroup: .legs)
    ]

    static let swimming: [ExerciseDefinition] = [
        ExerciseDefinition(name: "Freestyle", category: .cardio, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Backstroke", category: .cardio, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Breaststroke", category: .cardio, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Butterfly", category: .cardio, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Kick Drills", category: .drill, muscleGroup: .legs),
        ExerciseDefinition(name: "Pull Drills", category: .drill, muscleGroup: .back),
        ExerciseDefinition(name: "IM Set", category: .interval, muscleGroup: .fullBody)
    ]

    static let teamSport: [ExerciseDefinition] = [
        ExerciseDefinition(name: "Shooting Drills", category: .drill, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Ball Handling", category: .drill, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Defensive Slides", category: .drill, muscleGroup: .legs),
        ExerciseDefinition(name: "Scrimmage", category: .drill, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Fast Break Drills", category: .drill, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Passing Drills", category: .drill, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Dribbling Drills", category: .drill, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Small-Sided Game", category: .drill, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Crossing & Finishing", category: .drill, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Set Piece Practice", category: .drill, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Agility Ladder", category: .drill, muscleGroup: .legs),
        ExerciseDefinition(name: "Cone Drills", category: .drill, muscleGroup: .legs),
        ExerciseDefinition(name: "Sprint Drills", category: .interval, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Practice Match", category: .drill, muscleGroup: .fullBody),
        ExerciseDefinition(name: "Conditioning", category: .interval, muscleGroup: .fullBody)
    ]
}
