import SwiftUI
import SwiftData

/// Cold-start questionnaire form presented as a sheet from Dashboard or ProfileView.
/// Contains 4 required questions (sessions/week, avg duration, typical effort, weeks at level)
/// and 4 optional questions (training age, schedule type, sports, injury history).
/// On save, calls ColdStartEngine.computeSeed() and persists TrainingProfile via repository.
///
/// This is the way a profile is CREATED. Once one exists, Profile edits every answer in
/// place (v1.7.3 · U10, `.planning/v173/PROFILE-IA.md`), so the sheet is no longer mounted
/// as an editor from there; `existingProfile` remains for any caller that still re-edits.
struct TrainingProfileSheet: View {

    // MARK: - Option lists (shared with the in-place Profile rows)

    static let sessionsPerWeekOptions = Array(1...14)
    static let durationOptions = [15, 30, 45, 60, 75, 90, 120, 150, 180]
    static let effortOptions = Array(1...10)
    static let weeksAtLevelOptions = [1, 2, 3, 4, 6, 8, 12, 16, 24, 52]
    static let trainingAgeOptions = Array(0...30)
    /// Stored raw values — synced as-is, so they stay English; `scheduleTypeLabel` localizes.
    static let scheduleTypeOptions = ["Steady", "Periodized"]

    static func scheduleTypeLabel(_ raw: String, locale: Locale) -> String {
        switch raw {
        case "Steady":
            return LocalePinnedStrings.localized("profile.trainingProfile.schedule.steady", defaultValue: "Steady", locale: locale)
        case "Periodized":
            return LocalePinnedStrings.localized("profile.trainingProfile.schedule.periodized", defaultValue: "Periodized", locale: locale)
        default:
            return raw
        }
    }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
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

    /// Track whether user has interacted with any field (not just pre-populated: a re-edit
    /// fills every row, and a first run pre-selects the athlete's sport).
    @State private var userHasEdited = false

    private var hasChanges: Bool { userHasEdited }

    // MARK: - sRPE Labels

    private static let srpeLabels: [Int: String] = [
        1: "1 — Rest",
        2: "2 — Very Light",
        3: "3 — Light",
        4: "4 — Moderate-",
        5: "5 — Moderate",
        6: "6 — Moderate+",
        7: "7 — Hard",
        8: "8 — Very Hard",
        9: "9 — Near Max",
        10: "10 — Maximal"
    ]

    private func srpeLabel(_ value: Int) -> String {
        Self.srpeLabels[value] ?? "\(value)"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // UAT round 1, U6: "Discard changes" / "Save profile" were long enough to
                // draw straight across the centred title. The slots now say what every
                // other sheet in the app says — the sheet's own title already names what
                // is being cancelled or saved.
                InstrumentSheetHeader(title: "profile.trainingProfile.navTitle") {
                    SheetHeaderButton(title: "action.cancel") { dismiss() }
                } trailing: {
                    SheetHeaderButton(title: "action.save", emphasis: true, isDisabled: !isFormValid) { save() }
                }
                ScrollView {
                    VStack(spacing: 0) {
                        // REQUIRED section
                    formSection(String(localized: "profile.trainingProfile.sectionRequired", defaultValue: "Required")) {

                    pickerRow(
                        String(localized: "profile.trainingProfile.sessionsPerWeek", defaultValue: "Sessions per week"),
                        selection: $sessionsPerWeek,
                        options: Self.sessionsPerWeekOptions,
                        placeholder: String(localized: "profile.trainingProfile.placeholder.select", defaultValue: "Select"),
                        displayName: { "\($0)" }
                    )
                    divider()

                    pickerRow(
                        String(localized: "profile.trainingProfile.avgDuration", defaultValue: "Average duration"),
                        selection: $avgDurationMinutes,
                        options: Self.durationOptions,
                        placeholder: String(localized: "profile.trainingProfile.placeholder.select", defaultValue: "Select"),
                        displayName: { "\($0) min" }
                    )
                    divider()

                    pickerRow(
                        String(localized: "profile.trainingProfile.typicalEffort", defaultValue: "Typical effort"),
                        selection: $typicalSRPE,
                        options: Self.effortOptions,
                        placeholder: String(localized: "profile.trainingProfile.placeholder.select", defaultValue: "Select"),
                        displayName: { srpeLabel($0) }
                    )
                    divider()

                    pickerRow(
                        String(localized: "profile.trainingProfile.weeksAtLevel", defaultValue: "Weeks at current level"),
                        selection: $weeksAtLevel,
                        options: Self.weeksAtLevelOptions,
                        placeholder: String(localized: "profile.trainingProfile.placeholder.select", defaultValue: "Select"),
                        displayName: { $0 == 1
                            ? String(localized: "profile.trainingProfile.weeks.one", defaultValue: "1 week")
                            : String(localized: "profile.trainingProfile.weeks.other", defaultValue: "\($0) weeks") }
                    )
                    }

                    // OPTIONAL section
                    formSection(String(localized: "profile.trainingProfile.sectionOptional", defaultValue: "Optional")) {

                    pickerRow(
                        String(localized: "profile.trainingProfile.trainingAge", defaultValue: "Training age"),
                        selection: $trainingAgeYears,
                        options: Self.trainingAgeOptions,
                        placeholder: String(localized: "profile.trainingProfile.placeholder.dash", defaultValue: "---"),
                        displayName: { $0 == 1
                            ? String(localized: "profile.trainingProfile.years.one", defaultValue: "1 year")
                            : String(localized: "profile.trainingProfile.years.other", defaultValue: "\($0) years") }
                    )
                    divider()

                    pickerRow(
                        String(localized: "profile.trainingProfile.scheduleType", defaultValue: "Schedule type"),
                        selection: $scheduleType,
                        options: Self.scheduleTypeOptions,
                        placeholder: String(localized: "profile.trainingProfile.placeholder.dash", defaultValue: "---"),
                        displayName: { Self.scheduleTypeLabel($0, locale: locale) }
                    )
                    divider()

                    movementTypesRow()
                    divider()

                    injuryHistoryRow()
                    }

                    // Error message if save fails
                    if let saveError {
                        Text(saveError)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.zoneDanger)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.top, Spacing.xs)
                    }
                }
                }
                .scrollDismissesKeyboard(.interactively)
                .dismissesKeyboardOnTap()
                .background(ColorTokens.background)
                .interactiveDismissDisabled(hasChanges)
                .onAppear {
                if let p = existingProfile {
                    sessionsPerWeek = p.sessionsPerWeek
                    avgDurationMinutes = p.avgDurationMinutes
                    typicalSRPE = Int(p.typicalSRPE)
                    weeksAtLevel = p.weeksAtLevel
                    trainingAgeYears = p.trainingAgeYears
                    scheduleType = p.periodizationPreference
                    if let athlete {
                        selectedMovementTypes = Set(SportSelection.sports(
                            movementTypes: p.movementTypes,
                            primary: athlete.sportType
                        ))
                    }
                    let injuries = TrainingProfile.decodeInjuryHistory(p.injuryHistory)
                    selectedBodyRegions = injuries.regions
                    injuryNotes = injuries.notes
                    if !selectedBodyRegions.isEmpty {
                        showInjuryDetail = true
                    }
                } else if let athlete {
                    // The sport chosen at sign-up is already one of the athlete's sports; the
                    // multi-select starts from it rather than asking the question twice.
                    selectedMovementTypes = [athlete.sportType]
                }
            }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Helper Views

    /// Wraps a form section: 32pt break + 17pt Medium sentence-case header, then the rows on a
    /// single raised plate (each section reads as a distinct surface).
    @ViewBuilder
    private func formSection<Content: View>(
        _ title: String,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: Spacing.lg)
            SectionHeader(title: LocalizedStringKey(title))
            Spacer().frame(height: Spacing.sm)
            VStack(spacing: 0) {
                content()
            }
            // v4.2 Relief Law: the section is a milled RAISED plate; rows sit transparent on it,
            // and any inline option channel recesses INTO it. Clip so expanding channels stay
            // inside the plate corners (CornerTokens.card).
            .clipShape(RoundedRectangle(cornerRadius: CornerTokens.card))
            .raised(cornerRadius: CornerTokens.card)
            .padding(.horizontal, Spacing.sm)
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        SectionHeader(title: LocalizedStringKey(title))
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.sm)
    }

    @ViewBuilder
    private func divider() -> some View {
        Rectangle()
            .fill(ColorTokens.divider)
            .frame(height: 0.5)
            .padding(.leading, Spacing.sm)
    }

    @ViewBuilder
    private func sectionDivider() -> some View {
        Rectangle()
            .fill(ColorTokens.divider)
            .frame(height: 0.5)
    }

    /// Machined select (v4.2): the stock `Menu` dies — an inline debossed channel of raised
    /// option cells with drilled selection dots. `label` arrives already-localized, so it is
    /// shown verbatim through a `LocalizedStringKey` interpolation.
    @ViewBuilder
    private func pickerRow<T: Hashable>(
        _ label: String,
        selection: Binding<T?>,
        options: [T],
        placeholder: String,
        displayName: @escaping (T) -> String
    ) -> some View {
        InlineOptionList(
            LocalizedStringKey("\(label)"),
            selection: selection,
            options: options,
            placeholder: placeholder,
            onSelect: { userHasEdited = true },
            displayName: displayName
        )
    }

    /// The sports multi-select (v1.7.3 · U6, HAN: GO). Same field, same label as the Profile
    /// row that edits it later; `save()` derives the primary from it (`SportSelection`).
    @ViewBuilder
    private func movementTypesRow() -> some View {
        InlineMultiOptionList(
            label: "profile.field.sports",
            selection: $selectedMovementTypes,
            options: SportType.allCases,
            displayName: { $0.displayName },
            summary: { count in
                String(localized: "profile.trainingProfile.movementTypes.selected", defaultValue: "\(count) selected")
            },
            placeholder: String(localized: "profile.trainingProfile.placeholder.dash", defaultValue: "---"),
            onToggle: { userHasEdited = true }
        )
    }

    @ViewBuilder
    private func injuryHistoryRow() -> some View {
        VStack(spacing: 0) {
            Button {
                Haptics.tap()
                withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                    showInjuryDetail.toggle()
                }
            } label: {
                HStack {
                    Text("profile.trainingProfile.injuryHistory")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text2)
                    Spacer()
                    HStack(spacing: Spacing.baselinePair) {
                        if selectedBodyRegions.isEmpty {
                            Text("profile.trainingProfile.placeholder.dash")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text3)
                        } else {
                            Text(selectedBodyRegions.count == 1
                                ? String(localized: "profile.trainingProfile.areas.one", defaultValue: "\(selectedBodyRegions.count) area")
                                : String(localized: "profile.trainingProfile.areas.other", defaultValue: "\(selectedBodyRegions.count) areas"))
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                        }
                        Image(systemName: showInjuryDetail ? "chevron.up" : "chevron.down")
                            .font(.Tokens.micro)
                            .foregroundStyle(ColorTokens.text3)
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.sm)
                .background(Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable(scale: 1, opacity: 0.6))

            if showInjuryDetail {
                InjuryHistoryFields(
                    regions: $selectedBodyRegions,
                    notes: $injuryNotes,
                    onEdit: { userHasEdited = true }
                )
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

        let injuryData = TrainingProfile.encodeInjuryHistory(regions: selectedBodyRegions, notes: injuryNotes)

        // Sports: the ordered list is the single source for BOTH fields (SportSelection).
        // The athlete's current sport stays primary while it is still selected; deselecting
        // it promotes the next. An empty selection leaves both fields as they were.
        let currentSports = SportSelection.sports(
            movementTypes: existingProfile?.movementTypes,
            primary: athlete.sportType
        )
        let sports: [SportType]? = selectedMovementTypes.isEmpty
            ? nil
            : SportSelection.ordered(current: currentSports, selected: selectedMovementTypes)
        let movementTypeStrings = sports?.map(\.rawValue)

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
                syncPrimarySport(sports, athlete: athlete)
                Haptics.success()
                dismiss()
            } catch {
                saveError = String(localized: "profile.trainingProfile.saveError", defaultValue: "Couldn't save your training profile. Please try again.")
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
                syncPrimarySport(sports, athlete: athlete)
                Haptics.success()
                dismiss()
            } catch {
                saveError = String(localized: "profile.trainingProfile.saveError", defaultValue: "Couldn't save your training profile. Please try again.")
            }
        }
    }

    /// Keep `athlete.sportType` equal to the first selected sport (the SportSelection
    /// invariant). A no-op when the primary did not move, so no athlete push is spent.
    private func syncPrimarySport(_ sports: [SportType]?, athlete: Athlete) {
        guard let primary = sports?.first, primary != athlete.sportType else { return }
        athlete.sportType = primary
        athlete.updatedAt = .now
        try? modelContext.save()
        Task { await container.syncService.pushAthlete(athlete) }
    }
}

// MARK: - Injury history fields (shared by the sheet and the Profile detail screen)

/// Body regions as flat outlined option cells (v1.7.1: debossed channel dropped, same grammar
/// as the inline selects) + a machined notes field. Owns no persistence: the sheet encodes on
/// Save, the Profile detail screen commits on change.
struct InjuryHistoryFields: View {
    @Binding var regions: Set<BodyRegion>
    @Binding var notes: String
    var onEdit: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.baselinePair) {
            ForEach(BodyRegion.allCases) { region in
                MachinedOptionCell(
                    label: region.displayName,
                    isSelected: regions.contains(region)
                ) {
                    if regions.contains(region) {
                        regions.remove(region)
                    } else {
                        regions.insert(region)
                    }
                    onEdit?()
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.xs)

        FormField(
            placeholder: "profile.trainingProfile.injuryNotes",
            text: $notes,
            axis: .vertical,
            alignment: .leading,
            lineLimit: 2...4,
            onEdit: onEdit
        )
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.sm)
    }
}
