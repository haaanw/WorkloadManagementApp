import SwiftUI
import SwiftData

/// Cold-start questionnaire form presented as a sheet from Dashboard or ProfileView.
/// Contains 4 required questions (sessions/week, avg duration, typical effort, weeks at level)
/// and 4 optional questions (training age, schedule type, movement types, injury history).
/// On save, calls ColdStartEngine.computeSeed() and persists TrainingProfile via repository.
struct TrainingProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppContainer.self) private var container
    @Query private var athletes: [Athlete]

    /// Pass an existing profile for re-edit from ProfileView. Nil for first-time completion.
    var existingProfile: TrainingProfile?

    private var athlete: Athlete? { athletes.first }

    // MARK: - Required Fields (nil sentinel = not yet selected)

    @State private var sessionsPerWeek: Int? = nil
    @State private var avgDurationMinutes: Int? = nil
    @State private var typicalSRPE: Int? = nil
    @State private var weeksAtLevel: Int? = nil

    // MARK: - Optional Fields

    @State private var trainingAgeYears: Int? = nil
    @State private var scheduleType: String? = nil
    @State private var selectedMovementTypes: Set<SportType> = []
    @State private var selectedBodyRegions: Set<BodyRegion> = []
    @State private var injuryNotes: String = ""
    @State private var showInjuryDetail: Bool = false

    // MARK: - UI State

    @State private var saveError: String? = nil

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        sessionsPerWeek != nil && avgDurationMinutes != nil && typicalSRPE != nil && weeksAtLevel != nil
    }

    /// Track whether user has interacted with any field (not just pre-populated from re-edit)
    @State private var userHasEdited = false

    private var hasChanges: Bool {
        if existingProfile != nil {
            return userHasEdited
        }
        return sessionsPerWeek != nil || avgDurationMinutes != nil || typicalSRPE != nil || weeksAtLevel != nil ||
        trainingAgeYears != nil || scheduleType != nil || !selectedMovementTypes.isEmpty || !selectedBodyRegions.isEmpty ||
        !injuryNotes.isEmpty
    }

    // MARK: - sRPE Labels

    private static let srpeLabels: [Int: String] = [
        1: "1 -- Rest",
        2: "2 -- Very Light",
        3: "3 -- Light",
        4: "4 -- Moderate-",
        5: "5 -- Moderate",
        6: "6 -- Moderate+",
        7: "7 -- Hard",
        8: "8 -- Very Hard",
        9: "9 -- Near Max",
        10: "10 -- Maximal"
    ]

    private func srpeLabel(_ value: Int) -> String {
        Self.srpeLabels[value] ?? "\(value)"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // REQUIRED section
                    sectionHeader(String(localized: "profile.trainingProfile.sectionRequired", defaultValue: "REQUIRED"))

                    pickerRow(
                        String(localized: "profile.trainingProfile.sessionsPerWeek", defaultValue: "Sessions per week"),
                        selection: $sessionsPerWeek,
                        options: Array(1...14),
                        placeholder: "Select",
                        displayName: { "\($0)" }
                    )
                    divider()

                    pickerRow(
                        String(localized: "profile.trainingProfile.avgDuration", defaultValue: "Average duration"),
                        selection: $avgDurationMinutes,
                        options: [15, 30, 45, 60, 75, 90, 120, 150, 180],
                        placeholder: "Select",
                        displayName: { "\($0) min" }
                    )
                    divider()

                    pickerRow(
                        String(localized: "profile.trainingProfile.typicalEffort", defaultValue: "Typical effort"),
                        selection: $typicalSRPE,
                        options: Array(1...10),
                        placeholder: "Select",
                        displayName: { srpeLabel($0) }
                    )
                    divider()

                    pickerRow(
                        String(localized: "profile.trainingProfile.weeksAtLevel", defaultValue: "Weeks at current level"),
                        selection: $weeksAtLevel,
                        options: [1, 2, 3, 4, 6, 8, 12, 16, 24, 52],
                        placeholder: "Select",
                        displayName: { $0 == 1 ? "1 week" : "\($0) weeks" }
                    )
                    sectionDivider()

                    // OPTIONAL section
                    sectionHeader(String(localized: "profile.trainingProfile.sectionOptional", defaultValue: "OPTIONAL"))

                    pickerRow(
                        String(localized: "profile.trainingProfile.trainingAge", defaultValue: "Training age"),
                        selection: $trainingAgeYears,
                        options: Array(0...30),
                        placeholder: "---",
                        displayName: { $0 == 1 ? "1 year" : "\($0) years" }
                    )
                    divider()

                    pickerRow(
                        String(localized: "profile.trainingProfile.scheduleType", defaultValue: "Schedule type"),
                        selection: $scheduleType,
                        options: ["Steady", "Periodized"],
                        placeholder: "---",
                        displayName: { $0 }
                    )
                    divider()

                    movementTypesRow()
                    divider()

                    injuryHistoryRow()

                    // Error message if save fails
                    if let saveError {
                        Text(saveError)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.zoneDanger)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("profile.trainingProfile.navTitle")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(hasChanges)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.discardChanges") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.saveProfile") { save() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                        .disabled(!isFormValid)
                }
            }
            .onAppear {
                if let p = existingProfile {
                    sessionsPerWeek = p.sessionsPerWeek
                    avgDurationMinutes = p.avgDurationMinutes
                    typicalSRPE = Int(p.typicalSRPE)
                    weeksAtLevel = p.weeksAtLevel
                    trainingAgeYears = p.trainingAgeYears
                    scheduleType = p.periodizationPreference
                    if let types = p.movementTypes {
                        selectedMovementTypes = Set(types.compactMap { SportType(rawValue: $0) })
                    }
                    if let data = p.injuryHistory,
                       let injuries = try? JSONDecoder().decode([InjuryEntry].self, from: data) {
                        selectedBodyRegions = Set(injuries.map(\.bodyRegion))
                        injuryNotes = injuries.first?.notes ?? ""
                        if !selectedBodyRegions.isEmpty {
                            showInjuryDetail = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.Tokens.micro)
            .foregroundStyle(ColorTokens.text3)
            .tracking(1.2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }

    @ViewBuilder
    private func divider() -> some View {
        Rectangle()
            .fill(ColorTokens.divider)
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

    @ViewBuilder
    private func sectionDivider() -> some View {
        Rectangle()
            .fill(ColorTokens.divider)
            .frame(height: 0.5)
    }

    @ViewBuilder
    private func pickerRow<T: Hashable>(
        _ label: String,
        selection: Binding<T?>,
        options: [T],
        placeholder: String,
        displayName: @escaping (T) -> String
    ) -> some View {
        HStack {
            Text(label)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
            Spacer()
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(displayName(option)) {
                        selection.wrappedValue = option
                        userHasEdited = true
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    if let value = selection.wrappedValue {
                        Text(displayName(value))
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                    } else {
                        Text(placeholder)
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text3)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.text3)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private func movementTypesRow() -> some View {
        HStack {
            Text("profile.trainingProfile.movementTypes")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
            Spacer()
            Menu {
                ForEach(SportType.allCases) { sport in
                    Button {
                        if selectedMovementTypes.contains(sport) {
                            selectedMovementTypes.remove(sport)
                        } else {
                            selectedMovementTypes.insert(sport)
                        }
                        userHasEdited = true
                    } label: {
                        HStack {
                            Text(sport.displayName)
                            if selectedMovementTypes.contains(sport) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    if selectedMovementTypes.isEmpty {
                        Text("---")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text3)
                    } else {
                        Text("\(selectedMovementTypes.count) selected")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.text3)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private func injuryHistoryRow() -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    showInjuryDetail.toggle()
                }
            } label: {
                HStack {
                    Text("profile.trainingProfile.injuryHistory")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text2)
                    Spacer()
                    HStack(spacing: 4) {
                        if selectedBodyRegions.isEmpty {
                            Text("---")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text3)
                        } else {
                            Text("\(selectedBodyRegions.count) area\(selectedBodyRegions.count == 1 ? "" : "s")")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                        }
                        Image(systemName: showInjuryDetail ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.text3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }

            if showInjuryDetail {
                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)
                    .padding(.leading, 16)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(BodyRegion.allCases) { region in
                        Button {
                            if selectedBodyRegions.contains(region) {
                                selectedBodyRegions.remove(region)
                            } else {
                                selectedBodyRegions.insert(region)
                            }
                            userHasEdited = true
                        } label: {
                            HStack {
                                Text(region.displayName)
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                                Spacer()
                                if selectedBodyRegions.contains(region) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14))
                                        .foregroundStyle(ColorTokens.text1)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }

                        if region != BodyRegion.allCases.last {
                            Rectangle()
                                .fill(ColorTokens.divider)
                                .frame(height: 0.5)
                                .padding(.leading, 32)
                        }
                    }

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)
                        .padding(.leading, 16)

                    TextField("profile.trainingProfile.injuryNotes", text: $injuryNotes, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .onChange(of: injuryNotes) { userHasEdited = true }
                }
                .background(ColorTokens.surface)
            }
        }
    }

    // MARK: - Save Handler

    private func save() {
        guard let athlete,
              let sessions = sessionsPerWeek,
              let duration = avgDurationMinutes,
              let srpe = typicalSRPE,
              let weeks = weeksAtLevel else { return }

        let input = ColdStartEngine.SeedInput(
            sessionsPerWeek: sessions,
            avgDurationMinutes: duration,
            typicalSRPE: Double(srpe),
            weeksAtLevel: weeks
        )
        let result = ColdStartEngine.computeSeed(input: input)

        // Encode injury history if any regions selected
        let injuryData: Data? = {
            guard !selectedBodyRegions.isEmpty else { return nil }
            let entries = selectedBodyRegions.map { region in
                InjuryEntry(bodyRegion: region,
                            notes: injuryNotes.isEmpty ? nil : injuryNotes,
                            isActive: true)
            }
            return try? JSONEncoder().encode(entries)
        }()

        let movementTypeStrings: [String]? = selectedMovementTypes.isEmpty
            ? nil
            : selectedMovementTypes.map(\.rawValue)

        let repo = TrainingProfileRepository(modelContext: modelContext)

        if let existing = existingProfile {
            // Re-edit: update existing profile
            existing.sessionsPerWeek = sessions
            existing.avgDurationMinutes = duration
            existing.typicalSRPE = Double(srpe)
            existing.weeksAtLevel = weeks
            existing.trainingAgeYears = trainingAgeYears
            existing.periodizationPreference = scheduleType
            existing.movementTypes = movementTypeStrings
            existing.injuryHistory = injuryData
            existing.seededATL = result.seededATL
            existing.seededCTL = result.seededCTL
            do {
                try repo.updateProfile(existing)
                // WR-01: sync re-edited profile to Supabase
                Task { await container.syncService.pushTrainingProfile(context: modelContext, athleteId: athlete.id) }
                dismiss()
            } catch {
                saveError = "Couldn't save your training profile. Please try again."
            }
        } else {
            // New profile
            let profile = TrainingProfile(
                athleteId: athlete.id,
                sessionsPerWeek: sessions,
                avgDurationMinutes: duration,
                typicalSRPE: Double(srpe),
                weeksAtLevel: weeks,
                trainingAgeYears: trainingAgeYears,
                periodizationPreference: scheduleType,
                movementTypes: movementTypeStrings,
                injuryHistory: injuryData,
                seededATL: result.seededATL,
                seededCTL: result.seededCTL
            )
            do {
                try repo.saveProfile(profile)
                Task { await container.syncService.pushTrainingProfile(context: modelContext, athleteId: athlete.id) }
                dismiss()
            } catch {
                saveError = "Couldn't save your training profile. Please try again."
            }
        }
    }
}
