import SwiftUI
import SwiftData

/// Case + diacritic folding matching `ExerciseCatalogStore`'s normalization, so
/// picker-side name matching agrees with the catalog index.
private func fold(_ string: String) -> String {
    string.folding(
        options: [.caseInsensitive, .diacriticInsensitive],
        locale: Locale(identifier: "en_US_POSIX")
    )
}

/// Precomputed display state for the picker list — built in ONE place
/// (`recompute()`, debounced off query + filters), never per-row.
private struct PickerSections: Equatable {
    /// Distinct recent exercise names resolved to definitions (browse mode).
    var recent: [ExerciseDefinition] = []
    /// The athlete's custom exercises (browse mode).
    var custom: [ExerciseDefinition] = []
    /// The full (facet-filtered) pool minus customs (browse mode).
    var catalog: [ExerciseDefinition] = []
    /// Ranked search results (search mode).
    var results: [ExerciseDefinition] = []
    var isSearching = false
    /// An exercise with exactly the queried name already exists (suppresses instant-add).
    var hasExactNameMatch = false
    /// Regions present in the pool; empty when the facet should hide (≤1 region).
    var availableRegions: [MuscleRegion] = []
    /// Equipment facets; empty when the pool carries no equipment metadata.
    var availableEquipment: [String] = []
}

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container
    @Query private var customExercises: [CustomExercise]
    @Query private var athletes: [Athlete]
    @Query private var overrides: [ExerciseOverride]
    @State private var searchText = ""
    @State private var selectedRegion: MuscleRegion?
    @State private var selectedEquipment: String?
    @State private var showAddCustom = false
    @State private var showUpgrade = false
    @State private var detailExercise: ExerciseDefinition?
    @State private var recentNames: [String] = []
    @State private var sections = PickerSections()
    @State private var appliedQuery = ""

    // TODO: revisit cap for commercial tiers.

    let sportType: SportType
    let onSelect: (String, ExerciseCategory, MuscleGroup?) -> Void

    /// Public API frozen: all call sites use exactly this shape.
    init(
        sportType: SportType,
        onSelect: @escaping (String, ExerciseCategory, MuscleGroup?) -> Void
    ) {
        self.sportType = sportType
        self.onSelect = onSelect
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Everything the section computation depends on. Driving `.task(id:)` off
    /// this value gives debounce-with-cancellation on typing and instant
    /// recomputes on filter taps / custom-exercise or override changes.
    private struct RecomputeKey: Hashable {
        let query: String
        let region: MuscleRegion?
        let equipment: String?
        let customCount: Int
        let overrideCount: Int
        let recentCount: Int
    }

    private var recomputeKey: RecomputeKey {
        RecomputeKey(
            query: trimmedSearchText,
            region: selectedRegion,
            equipment: selectedEquipment,
            customCount: customExercises.count,
            overrideCount: overrides.count,
            recentCount: recentNames.count
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !sections.availableRegions.isEmpty || !sections.availableEquipment.isEmpty {
                    filterBar
                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)
                }

                exerciseList
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
            .sheet(item: $detailExercise) { exercise in
                ExerciseDetailSheet(exercise: exercise) {
                    Haptics.select()
                    onSelect(exercise.name, exercise.category, exercise.muscleGroup)
                    detailExercise = nil
                    dismiss()
                }
            }
            .task { loadRecentNames() }
            .task(id: recomputeKey) { await recompute() }
        }
    }

    // MARK: - Filter bar (region chips + equipment menu)

    private var filterBar: some View {
        HStack(spacing: Spacing.xs) {
            if !sections.availableRegions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        FilterChip(
                            label: String(localized: "filter.all", defaultValue: "All"),
                            isSelected: selectedRegion == nil
                        ) {
                            selectedRegion = nil
                        }
                        ForEach(sections.availableRegions) { region in
                            FilterChip(
                                label: region.displayName,
                                isSelected: selectedRegion == region
                            ) {
                                selectedRegion = region
                            }
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                    .animation(
                        Motion.resolved(Motion.state, reduceMotion: reduceMotion),
                        value: selectedRegion
                    )
                }
            } else {
                Spacer(minLength: 0)
            }
            if !sections.availableEquipment.isEmpty {
                equipmentMenu
            }
        }
        .padding(.horizontal, Spacing.sm)
    }

    /// Compact equipment facet: a `Menu` over the store's frequency-ordered
    /// facets with a checkmark on the active pick — deliberately not a second
    /// chip row (28 values). Active filter wears accent per the live/selected
    /// accent semantic.
    private var equipmentMenu: some View {
        Menu {
            Button {
                Haptics.select()
                selectedEquipment = nil
            } label: {
                if selectedEquipment == nil {
                    Label(
                        String(localized: "exercise.filter.anyEquipment", defaultValue: "Any Equipment"),
                        systemImage: "checkmark"
                    )
                } else {
                    Text(String(localized: "exercise.filter.anyEquipment", defaultValue: "Any Equipment"))
                }
            }
            Divider()
            ForEach(sections.availableEquipment, id: \.self) { equipment in
                Button {
                    Haptics.select()
                    selectedEquipment = equipment
                } label: {
                    if selectedEquipment == equipment {
                        Label(equipment.capitalized, systemImage: "checkmark")
                    } else {
                        Text(equipment.capitalized)
                    }
                }
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(
                    selectedEquipment?.capitalized
                        ?? String(localized: "exercise.filter.equipment", defaultValue: "Equipment")
                )
                .font(.Tokens.label)
                .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.Tokens.micro)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .foregroundStyle(selectedEquipment != nil ? ColorTokens.accent : ColorTokens.text2)
            .background(
                selectedEquipment != nil ? ColorTokens.accentSubtle : ColorTokens.background,
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(
                    selectedEquipment != nil ? ColorTokens.accent : ColorTokens.divider,
                    lineWidth: 0.5
                )
            )
        }
    }

    // MARK: - List

    private var exerciseList: some View {
        List {
            if sections.isSearching {
                if !sections.hasExactNameMatch && !trimmedSearchText.isEmpty {
                    instantAddRow
                }
                ForEach(sections.results) { exercise in
                    exerciseRow(exercise)
                }
                if sections.results.isEmpty && sections.hasExactNameMatch {
                    emptyRow
                }
            } else {
                if !sections.recent.isEmpty {
                    headerRow("exercise.section.recent")
                    ForEach(sections.recent) { exercise in
                        exerciseRow(exercise)
                    }
                }
                if !sections.custom.isEmpty {
                    headerRow("exercise.section.yours")
                    ForEach(sections.custom) { exercise in
                        exerciseRow(exercise)
                    }
                }
                if !sections.catalog.isEmpty {
                    if !sections.recent.isEmpty || !sections.custom.isEmpty {
                        headerRow("exercise.section.all")
                    }
                    ForEach(sections.catalog) { exercise in
                        exerciseRow(exercise)
                    }
                } else if sections.custom.isEmpty && sections.recent.isEmpty {
                    emptyRow
                }
            }
        }
        .listStyle(.plain)
    }

    /// Non-sticky in-list section header (19pt Medium per the separator grammar).
    private func headerRow(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.Tokens.sectionHead)
            .foregroundStyle(ColorTokens.text1)
            .padding(.top, Spacing.sm)
            .listRowSeparator(.hidden)
    }

    private var instantAddRow: some View {
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

    private var emptyRow: some View {
        Text("empty.noExercises")
            .font(.Tokens.body)
            .foregroundStyle(ColorTokens.text2)
    }

    /// One exercise row: tapping the row selects (as before); the trailing info
    /// affordance opens the detail sheet WITHOUT selecting.
    private func exerciseRow(_ exercise: ExerciseDefinition) -> some View {
        HStack(spacing: Spacing.xs) {
            Button {
                Haptics.select()
                onSelect(exercise.name, exercise.category, exercise.muscleGroup)
                dismiss()
            } label: {
                VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                    Text(exercise.name)
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                    HStack(spacing: Spacing.xs) {
                        if let muscle = exercise.muscleGroup {
                            Text(muscle.displayName)
                                .foregroundStyle(ColorTokens.text2)
                        } else {
                            Text(exercise.category.displayName)
                                .foregroundStyle(ColorTokens.text2)
                        }
                        if let equipment = exercise.equipment {
                            Text("·")
                                .foregroundStyle(ColorTokens.text3)
                            Text(equipment.capitalized)
                                .foregroundStyle(ColorTokens.text3)
                        }
                        if exercise.isCustom {
                            Text("·")
                                .foregroundStyle(ColorTokens.text3)
                            Text("sport.custom")
                                .foregroundStyle(ColorTokens.text3)
                        }
                    }
                    .font(.Tokens.label)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)

            Button {
                detailExercise = exercise
            } label: {
                Image(systemName: "info.circle")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text("exercise.action.details"))
        }
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

    // MARK: - Section computation (debounced, one place)

    /// Debounces typing (~250ms, cancelled by the next keystroke via `.task(id:)`)
    /// and rebuilds all section arrays. Filter taps and list mutations recompute
    /// immediately (query unchanged). Never runs per keystroke on the render path.
    @MainActor
    private func recompute() async {
        let query = trimmedSearchText
        if !query.isEmpty, fold(query) != fold(appliedQuery) {
            try? await Task.sleep(for: .milliseconds(250))
            if Task.isCancelled { return }
        }
        appliedQuery = query
        sections = computeSections(query: query)
    }

    private func computeSections(query: String) -> PickerSections {
        // 1. Pool: curated + catalog for this sport, plus the athlete's customs,
        //    deduped by folded name (first occurrence wins — legacy names keep
        //    their history-stable identity), then user overrides applied
        //    (hidden entries drop; remapped muscle/category swap in).
        var rawPool = ExerciseDatabase.exercises(for: sportType)
        rawPool.append(contentsOf: customExercises
            .filter { $0.sportType == nil || $0.sportType == sportType }
            .map {
                ExerciseDefinition(
                    name: $0.name,
                    category: $0.exerciseCategory,
                    muscleGroup: $0.muscleGroup,
                    isCustom: true
                )
            })

        var seen = Set<String>()
        var deduped: [ExerciseDefinition] = []
        deduped.reserveCapacity(rawPool.count)
        for def in rawPool where seen.insert(fold(def.name)).inserted {
            deduped.append(def)
        }

        var out = PickerSections()
        out.isSearching = !query.isEmpty
        // Exact-match check runs pre-override so a hidden name never invites a duplicate.
        if !query.isEmpty {
            let foldedQuery = fold(query)
            out.hasExactNameMatch = deduped.contains { fold($0.name) == foldedQuery }
        }

        let pool = ExerciseCatalogStore.applying(overrides: overrides, to: deduped)

        // 2. Facet availability — hide gracefully when the pool has no such metadata.
        let regions = MuscleRegion.allCases.filter { region in
            pool.contains { $0.muscleGroup?.region == region }
        }
        out.availableRegions = regions.count > 1 ? regions : []
        out.availableEquipment = pool.contains { $0.equipment != nil }
            ? ExerciseCatalogStore.equipmentFacets
            : []

        let equipmentKey = selectedEquipment.map(fold)
        let region = selectedRegion
        func passesFilters(_ def: ExerciseDefinition) -> Bool {
            if let region, def.muscleGroup?.region != region { return false }
            if let equipmentKey {
                guard let defEquipment = def.equipment, fold(defEquipment) == equipmentKey else {
                    return false
                }
            }
            return true
        }

        if out.isSearching {
            // 3a. Ranked search: token AND-match over name + equipment;
            //     name-prefix matches first, then contains; recent/custom/legacy
            //     names above catalog-only names; stable order within tiers.
            let foldedQuery = fold(query)
            let tokens = foldedQuery
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
            let recentSet = Set(recentNames.map(fold))
            var scored: [(prefixRank: Int, sourceRank: Int, index: Int, def: ExerciseDefinition)] = []
            for (index, def) in pool.enumerated() where passesFilters(def) {
                let foldedName = fold(def.name)
                let searchKey = def.equipment.map { "\(foldedName) \(fold($0))" } ?? foldedName
                guard tokens.allSatisfy({ searchKey.contains($0) }) else { continue }
                let prefixRank = foldedName.hasPrefix(foldedQuery) ? 0 : 1
                let isFamiliar = def.isCustom || def.catalogID == nil || recentSet.contains(foldedName)
                scored.append((prefixRank, isFamiliar ? 0 : 1, index, def))
            }
            scored.sort {
                ($0.prefixRank, $0.sourceRank, $0.index) < ($1.prefixRank, $1.sourceRank, $1.index)
            }
            out.results = scored.map(\.def)
        } else {
            // 3b. Browse: Recent (≤8, resolving names only) / Your Exercises / full pool.
            let filtered = pool.filter(passesFilters)
            var byFoldedName: [String: ExerciseDefinition] = [:]
            byFoldedName.reserveCapacity(filtered.count)
            for def in filtered where byFoldedName[fold(def.name)] == nil {
                byFoldedName[fold(def.name)] = def
            }
            out.recent = Array(recentNames.compactMap { byFoldedName[fold($0)] }.prefix(8))
            out.custom = filtered.filter(\.isCustom)
            out.catalog = filtered.filter { !$0.isCustom }
        }
        return out
    }

    /// Distinct exercise names from the athlete's most recent sessions
    /// (most recent first), fetched once per presentation.
    private func loadRecentNames() {
        guard recentNames.isEmpty else { return }
        guard let athleteID = athletes.first?.id else { return }
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.athlete?.id == athleteID },
            sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]
        )
        descriptor.fetchLimit = 30
        guard let sessions = try? modelContext.fetch(descriptor) else { return }
        var seen = Set<String>()
        var names: [String] = []
        for session in sessions {
            for entry in session.sortedEntries where seen.insert(fold(entry.exerciseName)).inserted {
                names.append(entry.exerciseName)
            }
            if names.count >= 24 { break }
        }
        recentNames = names
    }

    private func instantlyAddSearchText() {
        let name = trimmedSearchText
        guard !name.isEmpty else { return }
        let classification = ExerciseClassifier.classify(name)
        // Custom-exercise persistence is free for all tiers (product decision 2026-07-13).
        let shouldPersist = true
        let client = container.supabase
        let athlete = athletes.first
        let context = modelContext

        var savedExerciseID: UUID?
        var athleteID: UUID?
        if shouldPersist, let athlete {
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
                savedExerciseID = exercise.id
                athleteID = athlete.id
            } else {
                context.delete(exercise)
            }
        }

        Haptics.success()
        onSelect(name, classification.category, classification.muscleGroup)
        dismiss()

        guard let savedExerciseID, let athleteID else { return }

        Task { @MainActor in
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
            let descriptor = FetchDescriptor<CustomExercise>(
                predicate: #Predicate { $0.id == savedExerciseID }
            )
            guard let savedExercise = try? context.fetch(descriptor).first,
                  savedExercise.athlete?.id == athleteID else {
                return
            }

            var didRefine = false
            if let refinedCategory, refinedCategory != savedExercise.exerciseCategory {
                savedExercise.exerciseCategory = refinedCategory
                didRefine = true
            }
            if let refinedMuscle, refinedMuscle != savedExercise.muscleGroup {
                savedExercise.muscleGroup = refinedMuscle
                didRefine = true
            }
            if didRefine {
                try? context.save()
            }
        }
    }

    private func tryAddCustom() {
        showAddCustom = true
    }

    private func deleteCustomExercise(named name: String) {
        if let exercise = customExercises.first(where: { $0.name == name }) {
            Haptics.warning()
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
                        Haptics.success()
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
                .background(isSelected ? ColorTokens.accentSubtle : ColorTokens.background, in: Capsule())
                .overlay(
                    Capsule().stroke(
                        isSelected ? ColorTokens.accent : ColorTokens.divider,
                        lineWidth: 0.5
                    )
                )
        }
        .buttonStyle(.pressable)
    }
}

struct ExerciseDefinition: Equatable {
    let name: String
    var category: ExerciseCategory
    var muscleGroup: MuscleGroup?
    var isCustom: Bool = false
    var equipment: String? = nil
    var catalogID: String? = nil
}

extension ExerciseDefinition: Identifiable {
    /// Exercise identity throughout the app IS the name string
    /// (history, PRs, templates all key on it).
    var id: String { name }
}

enum ExerciseDatabase {
    static func exercises(for sportType: SportType) -> [ExerciseDefinition] {
        switch sportType {
        case .lifting, .crossfit: gym
        case .running: running
        case .cycling: cycling
        case .swimming: swimming
        case .teamSport: teamSport + bodyweight + plyometric
        case .custom: all
        }
    }

    /// Legacy curated lists across all sports. Users' history, PRs, and
    /// templates reference these exact names — they must stay selectable.
    static let legacyAll = strength + bodyweight + plyometric + running + cycling + swimming + teamSport

    /// Curated gym entries merged with the full bundled catalog.
    /// Legacy names win the dedupe and stay listed first.
    static let gym: [ExerciseDefinition] = merged(
        legacy: strength + bodyweight + plyometric,
        catalog: ExerciseCatalogStore.catalogDefinitions
    )

    /// Everything: legacy curated (all sports) + full catalog, deduped, legacy first.
    static let all: [ExerciseDefinition] = merged(
        legacy: legacyAll,
        catalog: ExerciseCatalogStore.catalogDefinitions
    )

    /// Case-insensitive name dedupe. `legacy` entries win and keep their order;
    /// catalog entries append after in catalog order.
    private static func merged(
        legacy: [ExerciseDefinition],
        catalog: [ExerciseDefinition]
    ) -> [ExerciseDefinition] {
        var seen = Set<String>()
        var results: [ExerciseDefinition] = []
        results.reserveCapacity(legacy.count + catalog.count)
        for def in legacy where seen.insert(def.name.lowercased()).inserted {
            results.append(def)
        }
        for def in catalog where seen.insert(def.name.lowercased()).inserted {
            results.append(def)
        }
        return results
    }

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
