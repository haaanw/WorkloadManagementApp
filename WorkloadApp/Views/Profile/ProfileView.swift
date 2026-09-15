import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var athletes: [Athlete]
    @Query private var trainingProfiles: [TrainingProfile]

    private var athlete: Athlete? { athletes.first }

    // Notification settings
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = false
    @AppStorage("notificationDay") private var notificationDay: Int = 1  // 1 = Sunday
    @AppStorage("notificationTime") private var notificationTime: String = "19:00"
    @State private var notificationsDenied: Bool = false

    @State private var errorMessage: String?
    @State private var showTrainingProfileSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showSignOutRiskConfirm = false
    @State private var isDeletingAccount = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Editorial screen header (Stage 4a) — in-content title, not stock nav chrome.
                    ScreenHeader(title: "profile.nav.title")

                    if let athlete {
                        // Coach-mode entry REMOVED (codex P1, 2026-07-18): the rehosted SwiftUI
                        // app intentionally carries no coach surfaces (decision D3), so the old
                        // "Open coach mode" action was a dead button — setMode(.coach) is never
                        // observed by AppRouter.

                        // Athlete Info
                        profileSection("profile.section.athlete") {
                        editableTextField("profile.field.name", value: Binding(
                            get: { athlete.displayName },
                            set: { athlete.displayName = $0; saveAthlete(athlete) }
                        ))
                        divider()
                        sportsRow(athlete: athlete)
                        divider()
                        editablePicker("profile.field.trainingFrequency", selection: Binding(
                            get: { athlete.trainingFrequency ?? .threeToFour },
                            set: { athlete.trainingFrequency = $0; saveAthlete(athlete) }
                        ), options: TrainingFrequency.allCases) { $0.displayName }
                        divider()
                        editablePicker("profile.field.experienceLevel", selection: Binding(
                            get: { athlete.experienceLevel ?? .intermediate },
                            set: { athlete.experienceLevel = $0; saveAthlete(athlete) }
                        ), options: ExperienceLevel.allCases) { $0.displayName }
                        }

                        // Training Profile (D-03) — edited IN PLACE (v1.7.3 · U10,
                        // `.planning/v173/PROFILE-IA.md` §4). The cold-start questionnaire is
                        // how a profile is CREATED; once one exists every answer is a row here,
                        // committing on change exactly like the athlete rows above. No Save, no
                        // Discard, no dirty state — that grammar belongs to the wizard. All nine
                        // answers are reachable: six rows below, sports in the athlete section,
                        // and injury history behind its own screen (a region grid and free text
                        // do not belong in a settings list).
                        profileSection("profile.section.trainingProfile") {
                        if let profile = trainingProfiles.first {
                            editablePicker("profile.field.sessionsPerWeek", selection: Binding(
                                get: { profile.sessionsPerWeek },
                                set: { profile.sessionsPerWeek = $0; saveProfile(profile, athlete: athlete) }
                            ), options: TrainingProfileSheet.sessionsPerWeekOptions) { "\($0)" }
                            divider()
                            editablePicker("profile.field.avgDuration", selection: Binding(
                                get: { profile.avgDurationMinutes },
                                set: { profile.avgDurationMinutes = $0; saveProfile(profile, athlete: athlete) }
                            ), options: TrainingProfileSheet.durationOptions, unit: "min") { "\($0)" }
                            divider()
                            editablePicker("profile.field.typicalEffort", selection: Binding(
                                get: { Int(profile.typicalSRPE.rounded()) },
                                set: { profile.typicalSRPE = Double($0); saveProfile(profile, athlete: athlete) }
                            ), options: TrainingProfileSheet.effortOptions) { effortLabel($0) }
                            divider()
                            editablePicker("profile.field.weeksAtLevel", selection: Binding(
                                get: { profile.weeksAtLevel },
                                set: { profile.weeksAtLevel = $0; saveProfile(profile, athlete: athlete) }
                            ), options: TrainingProfileSheet.weeksAtLevelOptions) { weeksLabel($0) }
                            divider()
                            InlineOptionList(
                                "profile.trainingProfile.trainingAge",
                                selection: Binding<Int?>(
                                    get: { profile.trainingAgeYears },
                                    set: { profile.trainingAgeYears = $0; saveProfile(profile, athlete: athlete) }
                                ),
                                options: TrainingProfileSheet.trainingAgeOptions,
                                placeholder: dashPlaceholder,
                                displayName: { yearsLabel($0) }
                            )
                            divider()
                            InlineOptionList(
                                "profile.trainingProfile.scheduleType",
                                selection: Binding<String?>(
                                    get: { profile.periodizationPreference },
                                    set: { profile.periodizationPreference = $0; saveProfile(profile, athlete: athlete) }
                                ),
                                options: TrainingProfileSheet.scheduleTypeOptions,
                                placeholder: dashPlaceholder,
                                displayName: { TrainingProfileSheet.scheduleTypeLabel($0, locale: locale) }
                            )
                            divider()
                            injuryHistoryRow(profile: profile, athlete: athlete)
                        } else {
                            // No profile: nothing to edit in place. The questionnaire is a real
                            // sequence with a seeding step at its end, so it stays a sheet.
                            actionButton("profile.action.setupTrainingProfile") {
                                showTrainingProfileSheet = true
                            }
                        }
                        }

                        // Movement Bank — curate the exercise library that feeds the picker (Stage D)
                        profileSection("profile.section.exerciseLibrary") {
                        NavigationLink {
                            MovementBankView()
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "dumbbell")
                                    .font(.Tokens.label)
                                    .foregroundStyle(ColorTokens.text2)
                                    .frame(width: 24)
                                Text("movementBank.title")
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.Tokens.micro)
                                    .foregroundStyle(ColorTokens.text3)
                            }
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.sm)
                            .background(Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                        .accessibilityIdentifier("profile.movementBank")
                        }

                        // Preferences
                        profileSection("profile.section.preferences") {
                        NavigationLink {
                            LanguagePickerView()
                        } label: {
                            HStack {
                                Text("profile.language.label")
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                                Spacer()
                                Text(container.localeManager.activeLocale.language.languageCode?.identifier == "zh" ? "中文" : "English")
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text2)
                                Image(systemName: "chevron.right")
                                    .font(.Tokens.smallLabel)
                                    .foregroundStyle(ColorTokens.text3)
                            }
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.sm)
                            .background(Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                        divider()
                        editablePicker("profile.row.weightUnit", selection: Binding(
                            get: { athlete.weightUnit },
                            set: { athlete.weightUnit = $0; saveAthlete(athlete) }
                        ), options: WeightUnit.allCases) { $0.displayName }
                        }

                        // ALGORITHM VALIDATION.
                        //
                        // The opt-in morning probe that this section used to offer was REMOVED
                        // from the product (HAN ruling 2026-09-15): asking a 1–10 question in
                        // front of the score every morning is a cost the athlete pays daily for
                        // evidence only the developer reads. The `MorningReadinessProbe` model
                        // and the `RecoveryShadowDay` outcome columns are deliberately KEPT —
                        // unmount, not a schema change, so no migration and no lost rows. What
                        // remains here is the verdict-measurement readout, under the heading it
                        // already had.
                        profileSection("profile.validation.title") {
                            // Validation signals — quiet internal readout (METRIC-02). Lived in
                            // its own "Validation" section five sections below this one; two
                            // sections for one idea (U10 section review). NOT a hero row: no
                            // accent, mirrors the Sync row treatment.
                            NavigationLink {
                                VerdictMeasurementView()
                            } label: {
                                HStack(spacing: Spacing.xs) {
                                    Image(systemName: "chart.bar")
                                        .font(.Tokens.label)
                                        .foregroundStyle(ColorTokens.text2)
                                        .frame(width: 24)
                                    Text("profile.measurement.row")
                                        .font(.Tokens.body)
                                        .foregroundStyle(ColorTokens.text1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.Tokens.micro)
                                        .foregroundStyle(ColorTokens.text3)
                                }
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.sm)
                                .background(Color.clear)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                        }

                        // NOTIFICATIONS section (NOTF-03)
                        profileSection("profile.section.notifications") {

                        // Toggle row — machined round knob in a debossed channel (v4.2).
                        InstrumentFormRow(label: "profile.row.weeklySummary") {
                            Toggle("", isOn: Binding(
                                get: { notificationsEnabled },
                                set: { newValue in
                                    if newValue {
                                        Task {
                                            let status = await container.notificationService.authorizationStatus()
                                            if status == .denied {
                                                notificationsDenied = true
                                                notificationsEnabled = false
                                                return
                                            }
                                            if status == .notDetermined {
                                                let granted = await container.notificationService.requestAuthorization()
                                                if !granted {
                                                    notificationsEnabled = false
                                                    return
                                                }
                                            }
                                            notificationsEnabled = true
                                            scheduleNotification()
                                        }
                                    } else {
                                        notificationsEnabled = false
                                        container.notificationService.cancelWeeklySummary()
                                    }
                                }
                            ))
                            .labelsHidden()
                            .toggleStyle(.machined)
                        }

                        // System denied warning
                        if notificationsDenied {
                            Text("profile.notif.deniedHint")
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.bottom, Spacing.xs)
                                .transition(.opacity)
                        }

                        divider()

                        // Day picker row
                        editablePicker(
                            "profile.field.day",
                            selection: Binding(
                                get: { notificationDay },
                                set: { newValue in
                                    notificationDay = newValue
                                    if notificationsEnabled { scheduleNotification() }
                                }
                            ),
                            options: Array(1...7),
                            displayName: { weekday in
                                var cal = Calendar.current
                                cal.locale = locale
                                return cal.weekdaySymbols[weekday - 1]
                            }
                        )
                        .disabled(!notificationsEnabled)
                        .foregroundStyle(notificationsEnabled ? ColorTokens.text1 : ColorTokens.text3)

                        divider()

                        // Time picker row
                        editablePicker(
                            "profile.field.time",
                            selection: Binding(
                                get: { notificationTime },
                                set: { newValue in
                                    notificationTime = newValue
                                    if notificationsEnabled { scheduleNotification() }
                                }
                            ),
                            options: stride(from: 6, through: 22, by: 1).map { hour in
                                String(format: "%02d:00", hour)
                            },
                            displayName: { timeStr in
                                let parts = timeStr.split(separator: ":").compactMap { Int($0) }
                                let hour = parts.first ?? 19
                                let minute = parts.count > 1 ? parts[1] : 0
                                var comps = DateComponents()
                                comps.hour = hour
                                comps.minute = minute
                                var cal = Calendar.current
                                cal.locale = locale
                                let date = cal.date(from: comps) ?? .now
                                return date.formatted(.dateTime.hour().minute().locale(locale))
                            }
                        )
                        .disabled(!notificationsEnabled)
                        .foregroundStyle(notificationsEnabled ? ColorTokens.text1 : ColorTokens.text3)
                        }

                        // HealthKit
                        profileSection("profile.section.connectedDevices") {
                        NavigationLink {
                            HealthKitPermissionsView()
                        } label: {
                            HStack {
                                Text("profile.healthkit.permissions")
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.Tokens.micro)
                                    .foregroundStyle(ColorTokens.text3)
                            }
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.sm)
                            .background(Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                        divider()
                        Text("profile.healthkit.devicesHint")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.sm)
                            .background(Color.clear)
                            .contentShape(Rectangle())
                        }

                        // Data Sync
                        profileSection("profile.section.dataSync") {
                        NavigationLink {
                            SyncStatusView()
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.Tokens.label)
                                    .foregroundStyle(ColorTokens.text2)
                                    .frame(width: 24)
                                Text("profile.sync.status")
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                                Spacer()
                                // v6: a sync state is a machine status stamp → annotation voice.
                                // The row label stays working voice. `zoneCaution` clears 4.5:1
                                // on every stone plane, and this section is a raised card plane
                                // anyway (DESIGN.md rule 7).
                                if SyncTimestampStore.shared.hasAnyFailure {
                                    AnnotationLabel(
                                        LocalePinnedStrings.localized("profile.sync.issues", locale: locale),
                                        color: ColorTokens.zoneCaution
                                    )
                                    .annotationReveal()
                                } else {
                                    AnnotationLabel(
                                        LocalePinnedStrings.localized("profile.sync.allSynced", locale: locale),
                                        color: ColorTokens.text2
                                    )
                                    .annotationReveal()
                                }
                                Image(systemName: "chevron.right")
                                    .font(.Tokens.micro)
                                    .foregroundStyle(ColorTokens.text3)
                            }
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.sm)
                            .background(Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                        }

                        // Account — destructive actions, grouped + separated
                        profileSection("profile.section.account") {
                        InstrumentFormRow(label: "profile.signOut", action: {
                            // v1.7.1: sign-out cascade-deletes the local store. When a push
                            // has failed (or sync is refused on identity), local data may
                            // exist nowhere else — confirm before destroying the only copy.
                            if SyncTimestampStore.shared.hasPushRisk {
                                showSignOutRiskConfirm = true
                            } else {
                                Task {
                                    try? await container.signOut(modelContext: modelContext)
                                }
                            }
                        }) {
                            EmptyView()
                        }
                        divider()
                        // Quiet destructive row (v4.2): zone-danger label, no alarm fill.
                        DestructiveFormRow(
                            label: isDeletingAccount ? "profile.action.deleting" : "profile.action.deleteAccount",
                            isBusy: isDeletingAccount
                        ) {
                            showDeleteConfirmation = true
                        }
                        }

                        Spacer().frame(height: Spacing.lg)
                    } else {
                        // v3 empty state: one quiet line on the plate plane.
                        Text("profile.empty.noAthlete")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text2)
                            .dataPlate()
                            .padding(.horizontal, Spacing.sm)
                            .padding(.top, Spacing.md)
                            .transition(.opacity)
                    }
                }
                .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: athlete?.id)
                .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: trainingProfiles.first?.id)
                .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: notificationsDenied)
            }
            // Match the other roots' editorial top rhythm now the nav bar is hidden.
            .contentMargins(.top, Spacing.md, for: .scrollContent)
            // UAT round 1, U6: the name field is a plain text field in a long scroller —
            // give the keyboard the two escapes the platform expects (a downward drag and
            // a tap on the page). The field's own toolbar Done is the third.
            .scrollDismissesKeyboard(.interactively)
            .dismissesKeyboardOnTap()
            .background(ColorTokens.background)
            .task {
                let status = await container.notificationService.authorizationStatus()
                notificationsDenied = (status == .denied)
                if status == .denied && notificationsEnabled {
                    notificationsEnabled = false
                    container.notificationService.cancelWeeklySummary()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            // Reached only while no profile exists (U10): the sheet creates, the page edits.
            .sheet(isPresented: $showTrainingProfileSheet) {
                TrainingProfileSheet()
                    .environment(container)
            }
            // Sign-out with unsynced local data (v1.7.1)
            .alert("profile.signOut.riskTitle", isPresented: $showSignOutRiskConfirm) {
                Button("action.cancel", role: .cancel) { }
                Button("profile.signOut.riskConfirm", role: .destructive) {
                    Task {
                        try? await container.signOut(modelContext: modelContext)
                    }
                }
            } message: {
                Text("profile.signOut.riskMessage")
            }
            // Delete account confirmation
            .alert("profile.action.deleteAccount", isPresented: $showDeleteConfirmation) {
                Button("action.cancel", role: .cancel) { }
                Button("action.delete", role: .destructive) {
                    isDeletingAccount = true
                    Task {
                        do {
                            try await container.deleteAccount(modelContext: modelContext)
                        } catch {
                            errorMessage = String(format: String(localized: "profile.deleteAccount.error", defaultValue: "Failed to delete account: %@"), error.localizedDescription)
                            isDeletingAccount = false
                        }
                    }
                }
            } message: {
                Text("profile.delete.confirmBody")
            }
            // Error
            .alert("common.error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("action.ok") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Helpers

    /// Wraps a top-level grouped section: 32pt break + ruled micro-caps header, then the rows on
    /// a single raised plate (each section reads as a distinct surface).
    @ViewBuilder
    private func profileSection<Content: View>(
        _ header: LocalizedStringKey,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: Spacing.lg)
            // Ruled micro-caps header (demo §3): structures each section with a trailing
            // hairline instead of a floating 19pt title. Inset to align flush with the card.
            RuledSectionHeader(title: header)
                .padding(.horizontal, Spacing.sm)
            Spacer().frame(height: Spacing.sm)
            VStack(spacing: 0) {
                content()
            }
            // v4.2 Relief Law: each section is a milled RAISED plate; rows sit transparent on it.
            .raised(cornerRadius: CornerTokens.card)
            .padding(.horizontal, Spacing.sm)
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        RuledSectionHeader(title: title)
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.sm)
    }

    @ViewBuilder
    private func actionButton(_ label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        InstrumentFormRow(label: label, showsChevron: false, action: action) {
            EmptyView()
        }
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

    @ViewBuilder
    private func editableTextField(_ label: LocalizedStringKey, value: Binding<String>) -> some View {
        // Machined field: quiet at rest, grows a debossed focus well + ink border while editing.
        InstrumentFormRow(label: label) {
            FormField(placeholder: label, text: value)
                .frame(maxWidth: 200)
        }
    }

    /// Machined select (v4.2): every stock `Menu` dies — the row opens an inline debossed channel
    /// of raised option cells with drilled selection dots.
    @ViewBuilder
    private func editablePicker<T: Hashable>(
        _ label: LocalizedStringKey,
        selection: Binding<T>,
        options: [T],
        unit: String? = nil,
        displayName: @escaping (T) -> String
    ) -> some View {
        InlineOptionList(
            label,
            selection: selection,
            options: options,
            unit: unit,
            displayName: displayName
        )
    }

    /// U12: the weekly trigger REPEATS, so the numbers handed over here are the ones the
    /// notification states every week until something reschedules it. This surface passed
    /// four zeros, which froze a body reading "0 sessions logged — 0 week streak" into every
    /// future delivery. It now reads the athlete's real week from the store.
    private func scheduleNotification() {
        let timeParts = notificationTime.split(separator: ":").compactMap { Int($0) }
        let hour = timeParts.first ?? 19
        let minute = timeParts.count > 1 ? timeParts[1] : 0
        let numbers = WeeklyNotificationNumbers.compute(
            modelContext: modelContext,
            athleteId: athlete?.id
        )
        container.notificationService.scheduleWeeklySummary(
            weekday: notificationDay,
            hour: hour,
            minute: minute,
            sessionCount: numbers.sessionCount,
            streak: numbers.streak,
            prCount: numbers.prCount,
            volumeDelta: numbers.volumeDelta
        )
    }

    private func saveAthlete(_ athlete: Athlete) {
        athlete.updatedAt = .now
        try? modelContext.save()
        Task { await container.syncService.pushAthlete(athlete) }
    }

    // MARK: - Training profile, in place (U10)

    /// Commit one in-place edit of a questionnaire ANSWER.
    ///
    /// Writes the answer fields only. `seededATL` / `seededCTL` / `seededAt` are the cold-start
    /// estimate `ColdStartEngine` made from the ORIGINAL answers, and Home reads them only
    /// while no workload snapshot exists yet (`DashboardViewModel`'s cold-start fallback).
    /// Re-seeding from an edited answer would move a number that real sessions have already
    /// superseded — so an edit does not, and must not, re-run the seed. Seeding happens once,
    /// in `TrainingProfileSheet.save()`.
    private func saveProfile(_ profile: TrainingProfile, athlete: Athlete) {
        profile.updatedAt = .now
        try? modelContext.save()
        Task { await container.syncService.pushTrainingProfile(context: modelContext, athleteId: athlete.id) }
    }

    private var dashPlaceholder: String {
        LocalePinnedStrings.localized("profile.trainingProfile.placeholder.dash", defaultValue: "---", locale: locale)
    }

    /// "8 · Very hard" — the numeral keeps its resolution, the word is Foster's anchor at or
    /// below it (`SessionRPEScale`), read exactly as the Finish sheet reads session RPE.
    private func effortLabel(_ rpe: Int) -> String {
        let anchor = SessionRPEScale.anchor(for: rpe)
        let word = LocalePinnedStrings.localized(String.LocalizationValue(anchor.keyName), locale: locale)
        return "\(rpe) · \(word)"
    }

    private func weeksLabel(_ weeks: Int) -> String {
        weeks == 1
            ? LocalePinnedStrings.localized("profile.trainingProfile.weeks.one", defaultValue: "1 week", locale: locale)
            : LocalePinnedStrings.localized("profile.trainingProfile.weeks.other", defaultValue: "\(weeks) weeks", locale: locale)
    }

    private func yearsLabel(_ years: Int) -> String {
        years == 1
            ? LocalePinnedStrings.localized("profile.trainingProfile.years.one", defaultValue: "1 year", locale: locale)
            : LocalePinnedStrings.localized("profile.trainingProfile.years.other", defaultValue: "\(years) years", locale: locale)
    }

    /// Injury history is a navigation row, not inlined: a body-region grid and a free-text
    /// field do not belong in a settings list (PROFILE-IA §4, row 8).
    @ViewBuilder
    private func injuryHistoryRow(profile: TrainingProfile, athlete: Athlete) -> some View {
        let regionCount = TrainingProfile.decodeInjuryHistory(profile.injuryHistory).regions.count
        NavigationLink {
            InjuryHistoryDetailView(profile: profile, athleteId: athlete.id)
        } label: {
            HStack {
                Text("profile.trainingProfile.injuryHistory")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                Spacer()
                Text(injuryAreasLabel(regionCount))
                    .font(.Tokens.body)
                    .foregroundStyle(regionCount == 0 ? ColorTokens.text3 : ColorTokens.text2)
                Image(systemName: "chevron.right")
                    .font(.Tokens.smallLabel)
                    .foregroundStyle(ColorTokens.text3)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
        .accessibilityIdentifier("profile.injuryHistory")
    }

    private func injuryAreasLabel(_ count: Int) -> String {
        switch count {
        case 0: return dashPlaceholder
        case 1: return LocalePinnedStrings.localized("profile.trainingProfile.areas.one", defaultValue: "\(count) area", locale: locale)
        default: return LocalePinnedStrings.localized("profile.trainingProfile.areas.other", defaultValue: "\(count) areas", locale: locale)
        }
    }

    // MARK: - Sports (U6, HAN: GO — multi-select on TrainingProfile.movementTypes)

    /// The athlete's sports. Multi-select on the synced `TrainingProfile.movementTypes`
    /// field; the FIRST selection is the primary and is mirrored to `athlete.sportType`
    /// (`SportSelection`), so the two single-sport readers — the Movement Bank's new-exercise
    /// default and the PDF report title — and every legacy client keep reading one sport. No
    /// engine reads either field; the load math reads the SESSION's sport.
    ///
    /// The field lives on the profile, so until one exists there is nowhere to hold a second
    /// sport: the row is the single primary picker, and the section below offers the setup.
    @ViewBuilder
    private func sportsRow(athlete: Athlete) -> some View {
        if let profile = trainingProfiles.first {
            InlineMultiOptionList(
                label: "profile.field.sports",
                selection: Binding(
                    get: { Set(SportSelection.sports(movementTypes: profile.movementTypes, primary: athlete.sportType)) },
                    set: { newSelection in
                        let current = SportSelection.sports(movementTypes: profile.movementTypes, primary: athlete.sportType)
                        let next = SportSelection.ordered(current: current, selected: newSelection)
                        // `ordered` refuses an empty set by returning `current`: the last sport
                        // stays selected and nothing is written.
                        guard next != current, let primary = next.first else { return }
                        profile.movementTypes = next.map(\.rawValue)
                        saveProfile(profile, athlete: athlete)
                        if athlete.sportType != primary {
                            athlete.sportType = primary
                            saveAthlete(athlete)
                        }
                    }
                ),
                options: SportType.allCases,
                displayName: { $0.displayName },
                summary: { count in
                    let primary = athlete.sportType.displayName
                    return count > 1 ? "\(primary) +\(count - 1)" : primary
                },
                subtitleFor: { sport in
                    sport == athlete.sportType
                        ? LocalePinnedStrings.localized("profile.sports.primary", defaultValue: "Primary", locale: locale)
                        : nil
                }
            )
        } else {
            editablePicker("profile.field.sport", selection: Binding(
                get: { athlete.sportType },
                set: { athlete.sportType = $0; saveAthlete(athlete) }
            ), options: SportType.allCases) { $0.displayName }
        }
    }
}

// MARK: - Injury history (pushed from the Profile page, U10 row 8)

/// The training profile's injury answer on its own screen: the region grid and the notes
/// field the cold-start sheet shows inline, committing in place. Regions commit on each tap;
/// the notes commit when the field is left or the screen is popped, so a keystroke never
/// costs a save and a sync push.
struct InjuryHistoryDetailView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext

    let profile: TrainingProfile
    let athleteId: UUID

    @State private var regions: Set<BodyRegion> = []
    @State private var notes: String = ""
    @State private var isLoaded = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    Spacer().frame(height: Spacing.sm)
                    InjuryHistoryFields(regions: $regions, notes: $notes)
                }
                .raised(cornerRadius: CornerTokens.card)
                .padding(.horizontal, Spacing.sm)
                .padding(.top, Spacing.md)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissesKeyboardOnTap()
        .background(ColorTokens.background)
        .navigationTitle("profile.trainingProfile.injuryHistory")
        .onAppear {
            guard !isLoaded else { return }
            let stored = TrainingProfile.decodeInjuryHistory(profile.injuryHistory)
            regions = stored.regions
            notes = stored.notes
            isLoaded = true
        }
        .onChange(of: regions) { _, _ in commit() }
        .onDisappear { commit() }
    }

    /// Write only when the encoded answer actually changed — `onDisappear` fires on every
    /// pop, and an unchanged pop must not spend a save or a push.
    private func commit() {
        guard isLoaded else { return }
        let encoded = TrainingProfile.encodeInjuryHistory(regions: regions, notes: notes)
        guard encoded != profile.injuryHistory else { return }
        profile.injuryHistory = encoded
        profile.updatedAt = .now
        try? modelContext.save()
        Task { await container.syncService.pushTrainingProfile(context: modelContext, athleteId: athleteId) }
    }
}

// MARK: - HealthKit Permissions

struct HealthKitPermissionsView: View {
    @Environment(AppContainer.self) private var container
    @State private var isAuthorizing = false
    @State private var authError: String?

    private let dataTypes = [
        ("Heart Rate Variability (HRV)", "heart.text.square"),
        ("Resting Heart Rate", "heart.fill"),
        ("Sleep Analysis", "bed.double.fill"),
        ("Workout Heart Rate", "waveform.path.ecg"),
        ("Active Energy", "flame.fill"),
        ("Body Temperature", "thermometer.medium"),
        ("VO2 Max", "lungs.fill"),
        ("Workouts", "figure.run"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("profile.healthkit.disclaimer")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.sm)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                sectionHeader("profile.healthkit.dataWeRead")

                ForEach(dataTypes, id: \.0) { item in
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: item.1)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                            .frame(width: 24)
                        Text(item.0)
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5).padding(.leading, Spacing.xl)
                }

                Spacer().frame(height: Spacing.md)
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // State-driven status / action. The persisted state distinguishes:
                //  - .notRequested → "Connect" action (triggers the system permission sheet)
                //  - .requestedNoData → connected, but no recent samples (benign, NOT an error)
                //  - .connected → authorized + data flowing
                let hkState = container.healthKitService.connectionState

                Button {
                    Task {
                        isAuthorizing = true
                        do {
                            try await container.healthKitService.requestAuthorization()
                            // Probe immediately so the row reflects connected/no-data right away.
                            await container.healthKitService.runMigrationProbe()
                        } catch {
                            authError = error.localizedDescription
                        }
                        isAuthorizing = false
                    }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        if isAuthorizing {
                            ProgressView()
                        } else {
                            switch hkState {
                            case .connected:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(ColorTokens.zoneOptimal)
                                Text("profile.healthkit.authorized")
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.zoneOptimal)
                            case .requestedNoData:
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(ColorTokens.text2)
                                Text("profile.healthkit.connectedNoData")
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text2)
                            case .notRequested:
                                Text("profile.healthkit.authorize")
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.sm)
                }
                .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                .disabled(isAuthorizing || hkState != .notRequested)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // "Manage in Health" affordance — the right home for fixing/reviewing permissions
                // once access has been requested (a persisted flag stays true after revocation).
                if hkState != .notRequested {
                    Button {
                        // Apple Health app opens its own permissions surface; fall back to Settings.
                        if let url = URL(string: "x-apple-health://"),
                           UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        } else if let settings = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settings)
                        }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Text("profile.healthkit.manageInHealth")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.Tokens.smallLabel)
                                .foregroundStyle(ColorTokens.text2)
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.sm)
                    }
                    .buttonStyle(.pressable(scale: 1, opacity: 0.6))

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                }

                if let error = authError {
                    Text(error)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.zoneDanger)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                }
            }
        }
        .background(ColorTokens.background)
        .navigationTitle("profile.healthkit.navTitle")
    }

    @ViewBuilder
    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        RuledSectionHeader(title: title)
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.sm)
    }
}
