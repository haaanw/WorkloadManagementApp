import SwiftUI
import SwiftData

/// Case + diacritic folding matching `ExerciseCatalogStore`'s normalization, so
/// bank-side name matching agrees with the catalog index and the picker.
private func fold(_ string: String) -> String {
    string.folding(
        options: [.caseInsensitive, .diacriticInsensitive],
        locale: Locale(identifier: "en_US_POSIX")
    )
}

/// Management scopes for the bank list.
private enum BankScope: String, CaseIterable, Identifiable {
    case all
    case yours
    case hidden

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .all: "movementBank.scope.all"
        case .yours: "movementBank.scope.yours"
        case .hidden: "movementBank.scope.hidden"
        }
    }
}

/// One row of the bank list: the pre-override definition (catalog defaults for
/// the edit sheet) plus the display definition the picker would show.
private struct BankItem: Identifiable, Equatable {
    /// Definition BEFORE overrides — carries the catalog/legacy defaults.
    let base: ExerciseDefinition
    /// Definition with the athlete's overrides applied.
    let display: ExerciseDefinition
    /// A non-nil muscle/category override exists.
    let isEdited: Bool
    /// Hidden from the picker via an `ExerciseOverride`.
    let isHidden: Bool

    /// Exercise identity throughout the app IS the name string.
    var id: String { base.name }
}

/// Precomputed display state — built in ONE place (`recompute()`, debounced off
/// query + filters, same approach as the Stage C picker), never per-row.
private struct BankSections: Equatable {
    var items: [BankItem] = []
    /// Regions present in the scoped pool; empty when the facet should hide.
    var availableRegions: [MuscleRegion] = []
    /// Equipment facets; empty when the pool carries no equipment metadata.
    var availableEquipment: [String] = []
}

/// Movement Bank — the athlete curates the exercise library that feeds the
/// picker: hide catalog entries, remap muscle/category (ExerciseOverride),
/// and manage custom exercises. Local-only; never synced.
struct MovementBankView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var customExercises: [CustomExercise]
    @Query private var overrides: [ExerciseOverride]
    @Query private var athletes: [Athlete]

    @State private var searchText = ""
    @State private var scope: BankScope = .all
    @State private var selectedRegion: MuscleRegion?
    @State private var selectedEquipment: String?
    @State private var showAddCustom = false
    @State private var editingCustom: CustomExercise?
    @State private var editingCatalog: BankItem?
    @State private var pendingDelete: CustomExercise?
    @State private var sections = BankSections()
    @State private var appliedQuery = ""

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Everything the list computation depends on. Field EDITS (not just counts)
    /// must refresh rows, so the customs/overrides content is fingerprinted.
    private struct RecomputeKey: Hashable {
        let query: String
        let scope: BankScope
        let region: MuscleRegion?
        let equipment: String?
        let customsFingerprint: Int
        let overridesFingerprint: Int
    }

    private var recomputeKey: RecomputeKey {
        var customsHasher = Hasher()
        for exercise in customExercises {
            customsHasher.combine(exercise.name)
            customsHasher.combine(exercise.exerciseCategory)
            customsHasher.combine(exercise.muscleGroup)
        }
        var overridesHasher = Hasher()
        for override in overrides {
            overridesHasher.combine(override.exerciseName)
            overridesHasher.combine(override.muscleGroup)
            overridesHasher.combine(override.exerciseCategory)
            overridesHasher.combine(override.isHidden)
        }
        return RecomputeKey(
            query: trimmedSearchText,
            scope: scope,
            region: selectedRegion,
            equipment: selectedEquipment,
            customsFingerprint: customsHasher.finalize(),
            overridesFingerprint: overridesHasher.finalize()
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            BankScopeControl(selection: $scope)
                .padding(.horizontal, Spacing.sm)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.xs)

            if !sections.availableRegions.isEmpty || !sections.availableEquipment.isEmpty {
                filterBar
            }
            Rectangle()
                .fill(ColorTokens.divider)
                .frame(height: 0.5)

            bankList
        }
        .background(ColorTokens.background)
        .navigationTitle("movementBank.title")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "exercise.search.prompt")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddCustom = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(ColorTokens.text1)
                }
                .accessibilityLabel(Text("movementBank.action.new"))
            }
        }
        .sheet(isPresented: $showAddCustom) {
            // Row appears via @Query once saved; no selection follow-up here.
            AddCustomExerciseSheet(sportType: athletes.first?.sportType ?? .custom) { _, _, _ in }
        }
        .sheet(item: $editingCustom) { exercise in
            CustomExerciseEditSheet(exercise: exercise)
        }
        .sheet(item: $editingCatalog) { item in
            CatalogExerciseEditSheet(item: item)
        }
        .alert(
            "movementBank.delete.title",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { exercise in
            Button("action.cancel", role: .cancel) {}
            Button("action.delete", role: .destructive) {
                deleteCustom(exercise)
            }
        } message: { _ in
            Text("movementBank.delete.message")
        }
        .task(id: recomputeKey) { await recompute() }
    }

    // MARK: - Filter bar (region chips + equipment menu — mirrors the picker)

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

    /// Compact equipment facet — same `Menu` idiom as the Stage C picker
    /// (28 values; a second chip row would be noise). Active filter wears
    /// accent per the live/selected accent semantic.
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

    private var bankList: some View {
        List {
            if sections.items.isEmpty {
                Text(scope == .hidden ? "movementBank.empty.hidden" : "empty.noExercises")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text2)
            } else {
                ForEach(sections.items) { item in
                    bankRow(item)
                }
            }
        }
        .listStyle(.plain)
    }

    /// State badge as a TEXT label (design law: state never by color alone).
    private func badgeKey(for item: BankItem) -> LocalizedStringKey? {
        if scope == .hidden { return "movementBank.badge.hidden" }
        if item.base.isCustom { return "movementBank.badge.custom" }
        if item.isEdited { return "movementBank.badge.edited" }
        return nil
    }

    private func bankRow(_ item: BankItem) -> some View {
        Button {
            Haptics.select()
            if item.base.isCustom {
                editingCustom = customExercises.first { fold($0.name) == fold(item.base.name) }
            } else {
                editingCatalog = item
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                    Text(item.display.name)
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                    HStack(spacing: Spacing.xs) {
                        if let muscle = item.display.muscleGroup {
                            Text(muscle.displayName)
                                .foregroundStyle(ColorTokens.text2)
                        } else {
                            Text(item.display.category.displayName)
                                .foregroundStyle(ColorTokens.text2)
                        }
                        if let equipment = item.display.equipment {
                            Text("·")
                                .foregroundStyle(ColorTokens.text3)
                            Text(equipment.capitalized)
                                .foregroundStyle(ColorTokens.text3)
                        }
                    }
                    .font(.Tokens.label)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let badge = badgeKey(for: item) {
                    Text(badge)
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.text2)
                }
                Image(systemName: "chevron.right")
                    .font(.Tokens.micro)
                    .foregroundStyle(ColorTokens.text3)
            }
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .swipeActions(edge: .trailing) {
            if item.base.isCustom {
                // Non-destructive role: deletion waits for the confirmation
                // alert, so the row must not animate out on full swipe.
                Button {
                    pendingDelete = customExercises.first { fold($0.name) == fold(item.base.name) }
                } label: {
                    Label("action.delete", systemImage: "trash")
                }
                .tint(ColorTokens.zoneDanger)
            } else if item.isHidden {
                Button {
                    setHidden(false, for: item)
                } label: {
                    Label("movementBank.action.unhide", systemImage: "eye")
                }
            } else {
                Button {
                    setHidden(true, for: item)
                } label: {
                    Label("movementBank.action.hide", systemImage: "eye.slash")
                }
            }
        }
    }

    // MARK: - Section computation (debounced, one place — Stage C approach)

    /// Debounces typing (~250ms, cancelled by the next keystroke via `.task(id:)`)
    /// and rebuilds the item array. Scope/filter taps and model mutations
    /// recompute immediately (query unchanged).
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

    private func computeSections(query: String) -> BankSections {
        // 1. Pool: full merged library (legacy curated + 1,324-item catalog)
        //    plus ALL of the athlete's customs (management is sport-agnostic),
        //    deduped by folded name — first occurrence wins, same as the picker.
        var rawPool = ExerciseDatabase.all
        rawPool.append(contentsOf: customExercises.map {
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

        // 2. Apply overrides WITHOUT dropping hidden entries — the bank manages
        //    them (`ExerciseCatalogStore.applying` drops hidden for the picker).
        var overrideMap: [String: ExerciseOverride] = [:]
        for override in overrides {
            overrideMap[fold(override.exerciseName)] = override
        }
        var items: [BankItem] = []
        items.reserveCapacity(deduped.count)
        for def in deduped {
            let override = overrideMap[fold(def.name)]
            var display = def
            if let override {
                if let muscle = override.muscleGroup { display.muscleGroup = muscle }
                if let category = override.exerciseCategory { display.category = category }
            }
            items.append(BankItem(
                base: def,
                display: display,
                isEdited: override.map { $0.muscleGroup != nil || $0.exerciseCategory != nil } ?? false,
                isHidden: override?.isHidden ?? false
            ))
        }

        // 3. Scope, then facet availability over the scoped pool.
        let scoped = items.filter { item in
            switch scope {
            case .all: !item.isHidden
            case .yours: item.base.isCustom && !item.isHidden
            case .hidden: item.isHidden
            }
        }

        var out = BankSections()
        let regions = MuscleRegion.allCases.filter { region in
            scoped.contains { $0.display.muscleGroup?.region == region }
        }
        out.availableRegions = regions.count > 1 ? regions : []
        out.availableEquipment = scoped.contains { $0.display.equipment != nil }
            ? ExerciseCatalogStore.equipmentFacets
            : []

        // 4. Facet filters + ranked search (prefix matches first, stable within tiers).
        let equipmentKey = selectedEquipment.map(fold)
        let region = selectedRegion
        var filtered = scoped.filter { item in
            if let region, item.display.muscleGroup?.region != region { return false }
            if let equipmentKey {
                guard let equipment = item.display.equipment, fold(equipment) == equipmentKey else {
                    return false
                }
            }
            return true
        }

        if !query.isEmpty {
            let foldedQuery = fold(query)
            let tokens = foldedQuery
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
            var scored: [(prefixRank: Int, index: Int, item: BankItem)] = []
            for (index, item) in filtered.enumerated() {
                let foldedName = fold(item.display.name)
                let searchKey = item.display.equipment.map { "\(foldedName) \(fold($0))" } ?? foldedName
                guard tokens.allSatisfy({ searchKey.contains($0) }) else { continue }
                scored.append((foldedName.hasPrefix(foldedQuery) ? 0 : 1, index, item))
            }
            scored.sort { ($0.prefixRank, $0.index) < ($1.prefixRank, $1.index) }
            filtered = scored.map(\.item)
        }
        out.items = filtered
        return out
    }

    // MARK: - Mutations

    private func deleteCustom(_ exercise: CustomExercise) {
        Haptics.warning()
        modelContext.delete(exercise)
        do {
            try modelContext.save()
        } catch {
            print("Movement bank delete error: \(error)")
        }
    }

    /// Hide/unhide a catalog entry. Unhiding an override whose remap fields are
    /// all nil deletes the row so the table stays clean.
    private func setHidden(_ hidden: Bool, for item: BankItem) {
        Haptics.tap()
        let foldedName = fold(item.base.name)
        if let existing = overrides.first(where: { fold($0.exerciseName) == foldedName }) {
            existing.isHidden = hidden
            if !hidden, existing.muscleGroup == nil, existing.exerciseCategory == nil {
                modelContext.delete(existing)
            }
        } else if hidden {
            modelContext.insert(ExerciseOverride(exerciseName: item.base.name, isHidden: true))
        }
        do {
            try modelContext.save()
        } catch {
            print("Movement bank override save error: \(error)")
        }
    }
}

// MARK: - Scope control

/// Segmented-style scope control per the design system (`CornerTokens.control`
/// corners, hairline border, accent = selected per the live-state semantic —
/// same grammar as `TimeRangeSegmentedControl`).
private struct BankScopeControl: View {
    @Binding var selection: BankScope
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BankScope.allCases) { scope in
                Button {
                    guard selection != scope else { return }
                    Haptics.select()
                    withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                        selection = scope
                    }
                } label: {
                    Text(scope.titleKey)
                        .font(selection == scope ? .Tokens.labelMedium : .Tokens.label)
                        .foregroundStyle(selection == scope ? ColorTokens.accent : ColorTokens.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xs)
                        .background(selection == scope ? ColorTokens.accentSubtle : ColorTokens.surface)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerTokens.control))
        .overlay(
            RoundedRectangle(cornerRadius: CornerTokens.control)
                .stroke(ColorTokens.divider, lineWidth: 0.5)
        )
    }
}

// MARK: - Custom exercise edit sheet

/// Edit a CUSTOM exercise: muscle group + category. The NAME is fixed —
/// exercise identity is the name string; renaming would orphan logged history
/// and PRs. Deletion asks for confirmation.
private struct CustomExerciseEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let exercise: CustomExercise

    @State private var category: ExerciseCategory
    @State private var muscleGroup: MuscleGroup?
    @State private var showDeleteConfirmation = false

    init(exercise: CustomExercise) {
        self.exercise = exercise
        _category = State(initialValue: exercise.exerciseCategory)
        _muscleGroup = State(initialValue: exercise.muscleGroup)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                        Text(exercise.name)
                            .font(.Tokens.pageTitle)
                            .foregroundStyle(ColorTokens.text1)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("movementBank.hint.nameFixed")
                            .font(.Tokens.smallLabel)
                            .foregroundStyle(ColorTokens.text3)
                    }

                    VStack(spacing: 0) {
                        ExerciseCategoryRow(selection: $category)
                        rowDivider
                        MuscleGroupRow(selection: $muscleGroup)
                    }
                    .cardStyle(horizontalPadding: 0, verticalPadding: 0)

                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Text("action.delete")
                            .font(.Tokens.bodyMedium)
                            .foregroundStyle(ColorTokens.zoneDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.sm)
                            .background(ColorTokens.surfaceEl)
                    }
                    .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                    .cardStyle(horizontalPadding: 0, verticalPadding: 0)
                }
                .padding(Spacing.sm)
            }
            .background(ColorTokens.background)
            .navigationTitle("movementBank.nav.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                }
            }
            .onChange(of: category) { _, _ in save() }
            .onChange(of: muscleGroup) { _, _ in save() }
            .alert("movementBank.delete.title", isPresented: $showDeleteConfirmation) {
                Button("action.cancel", role: .cancel) {}
                Button("action.delete", role: .destructive) {
                    Haptics.warning()
                    modelContext.delete(exercise)
                    do {
                        try modelContext.save()
                    } catch {
                        print("Movement bank delete error: \(error)")
                    }
                    dismiss()
                }
            } message: {
                Text("movementBank.delete.message")
            }
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(ColorTokens.divider)
            .frame(height: 0.5)
            .padding(.leading, Spacing.sm)
    }

    private func save() {
        exercise.exerciseCategory = category
        exercise.muscleGroup = muscleGroup
        do {
            try modelContext.save()
        } catch {
            print("Movement bank save error: \(error)")
        }
    }
}

// MARK: - Catalog exercise edit sheet

/// Edit a CATALOG (or legacy curated) entry: shows the catalog defaults +
/// instructions, and persists deviations as an `ExerciseOverride` — created on
/// first edit, field nulled when set back to the catalog value, and the whole
/// row deleted when all fields are nil and it is not hidden.
private struct CatalogExerciseEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Pre-override definition — the catalog defaults.
    private let base: ExerciseDefinition
    @State private var category: ExerciseCategory
    @State private var muscleGroup: MuscleGroup?
    @State private var isHidden: Bool

    init(item: BankItem) {
        base = item.base
        _category = State(initialValue: item.display.category)
        _muscleGroup = State(initialValue: item.display.muscleGroup)
        _isHidden = State(initialValue: item.isHidden)
    }

    /// Catalog record for instructions/secondary muscles (nil for legacy names).
    private var catalogEntry: CatalogExercise? {
        ExerciseCatalogStore.entry(named: base.name)
    }

    private var deviatesFromDefaults: Bool {
        muscleGroup != base.muscleGroup || category != base.category || isHidden
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text(base.name)
                        .font(.Tokens.pageTitle)
                        .foregroundStyle(ColorTokens.text1)
                        .fixedSize(horizontal: false, vertical: true)

                    defaultsPlate

                    VStack(spacing: 0) {
                        ExerciseCategoryRow(selection: $category)
                        rowDivider
                        MuscleGroupRow(selection: $muscleGroup)
                        rowDivider
                        hideToggleRow
                        if deviatesFromDefaults {
                            rowDivider
                            resetRow
                        }
                    }
                    .cardStyle(horizontalPadding: 0, verticalPadding: 0)

                    if let steps = catalogEntry?.localizedSteps(), !steps.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("exercise.detail.instructions")
                                .font(.Tokens.sectionHead)
                                .foregroundStyle(ColorTokens.text1)
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                stepRow(number: index + 1, text: step)
                            }
                        }
                    }
                }
                .padding(Spacing.sm)
            }
            .background(ColorTokens.background)
            .navigationTitle("movementBank.nav.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                }
            }
            .onChange(of: category) { _, _ in persist() }
            .onChange(of: muscleGroup) { _, _ in persist() }
            .onChange(of: isHidden) { _, _ in persist() }
        }
    }

    // MARK: Rows

    /// Catalog defaults as micro-caps caption/value pairs (Stage C metadata
    /// plate grammar) so the athlete sees what "Reset to Default" restores.
    private var defaultsPlate: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("movementBank.section.defaults")
                .font(.Tokens.micro)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(ColorTokens.text3)
            if let muscle = base.muscleGroup {
                metadataRow("exercise.detail.target", muscle.displayName)
            }
            metadataRow("exercise.detail.category", base.category.displayName)
            if let equipment = base.equipment ?? catalogEntry?.equipment {
                metadataRow("exercise.detail.equipment", equipment.capitalized)
            }
        }
        .dataPlate()
    }

    private func metadataRow(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            Text(label)
                .font(.Tokens.micro)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(ColorTokens.text3)
            Text(value)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var hideToggleRow: some View {
        HStack {
            Text("movementBank.toggle.hideFromPicker")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
            Spacer()
            Toggle("", isOn: Binding(
                get: { isHidden },
                set: { newValue in
                    Haptics.tap()
                    isHidden = newValue
                }
            ))
            .labelsHidden()
            .toggleStyle(.design)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(ColorTokens.surfaceEl)
    }

    private var resetRow: some View {
        Button {
            Haptics.tap()
            muscleGroup = base.muscleGroup
            category = base.category
            isHidden = false
        } label: {
            Text("movementBank.action.resetDefault")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.sm)
                .background(ColorTokens.surfaceEl)
        }
        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(ColorTokens.divider)
            .frame(height: 0.5)
            .padding(.leading, Spacing.sm)
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Text("\(number)")
                .font(.Tokens.labelMedium)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text3)
                .frame(width: Spacing.md, alignment: .trailing)
            Text(text)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Persistence

    /// Upserts/deletes the override for the current state: fields equal to the
    /// catalog default are stored as nil; an all-nil non-hidden override is
    /// deleted so the table stays clean.
    private func persist() {
        let name = base.name
        let descriptor = FetchDescriptor<ExerciseOverride>(
            predicate: #Predicate { $0.exerciseName == name }
        )
        let existing = (try? modelContext.fetch(descriptor))?.first
        let newMuscle: MuscleGroup? = muscleGroup == base.muscleGroup ? nil : muscleGroup
        let newCategory: ExerciseCategory? = category == base.category ? nil : category

        if newMuscle == nil, newCategory == nil, !isHidden {
            guard let existing else { return }
            modelContext.delete(existing)
        } else if let existing {
            existing.muscleGroup = newMuscle
            existing.exerciseCategory = newCategory
            existing.isHidden = isHidden
        } else {
            modelContext.insert(ExerciseOverride(
                exerciseName: name,
                muscleGroup: newMuscle,
                exerciseCategory: newCategory,
                isHidden: isHidden
            ))
        }
        do {
            try modelContext.save()
        } catch {
            print("Movement bank override save error: \(error)")
        }
    }
}

// MARK: - Shared edit rows

/// Category row — the same `Menu` picker idiom as ProfileView's editablePicker.
private struct ExerciseCategoryRow: View {
    @Binding var selection: ExerciseCategory

    var body: some View {
        HStack {
            Text("exercise.field.category")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
            Spacer()
            Menu {
                ForEach(ExerciseCategory.allCases) { option in
                    Button(option.displayName) {
                        Haptics.select()
                        selection = option
                    }
                }
            } label: {
                HStack(spacing: Spacing.baselinePair) {
                    Text(selection.displayName)
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                    MenuChevron()
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(ColorTokens.surfaceEl)
    }
}

/// Muscle-group row — pushes the shared `MuscleGroupSelector` (Stage C).
private struct MuscleGroupRow: View {
    @Binding var selection: MuscleGroup?

    var body: some View {
        NavigationLink {
            MuscleGroupSelector(selection: $selection)
        } label: {
            HStack(spacing: Spacing.xs) {
                Text("exercise.field.muscleGroup.required")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text2)
                Spacer()
                Text(
                    selection?.displayName
                        ?? String(localized: "muscleGroup.required", defaultValue: "Required")
                )
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                Image(systemName: "chevron.right")
                    .font(.Tokens.micro)
                    .foregroundStyle(ColorTokens.text3)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            .background(ColorTokens.surfaceEl)
        }
        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
    }
}
