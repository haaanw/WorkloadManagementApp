import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Query private var athletes: [Athlete]
    @Query private var relationships: [CoachAthleteRelationship]
    @Query private var trainingProfiles: [TrainingProfile]
    @Query private var cycleSnapshots: [MenstrualCycleSnapshot]

    private var athlete: Athlete? { athletes.first }

    private var showCycleSection: Bool {
        !cycleSnapshots.isEmpty ||
        athlete?.isOnHormonalContraceptive != nil ||
        athlete?.isPregnant != nil ||
        athlete?.isLactating != nil ||
        athlete?.hasPCOS != nil ||
        athlete?.isPerimenopausal != nil
    }

    // Notification settings
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = false
    @AppStorage("notificationDay") private var notificationDay: Int = 1  // 1 = Sunday
    @AppStorage("notificationTime") private var notificationTime: String = "19:00"
    @State private var notificationsDenied: Bool = false

    // Invite flow state
    @State private var showInviteCodeSheet = false
    @State private var showEnterCodeSheet = false
    @State private var showEmailInviteSheet = false
    @State private var generatedCode: String?
    @State private var isGeneratingCode = false
    @State private var pendingInviteFromProfile: PendingInvite?

    @State private var errorMessage: String?
    @State private var showUpgrade = false
    @State private var showTrainingProfileSheet = false
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if let athlete {
                        // Athlete Info
                        sectionHeader("profile.section.athlete")
                        editableTextField("profile.field.name", value: Binding(
                            get: { athlete.displayName },
                            set: { athlete.displayName = $0; saveAthlete(athlete) }
                        ))
                        divider()
                        editablePicker("profile.field.sport", selection: Binding(
                            get: { athlete.sportType },
                            set: { athlete.sportType = $0; saveAthlete(athlete) }
                        ), options: SportType.allCases) { $0.displayName }
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
                        sectionDivider()

                        // Training Profile (D-03)
                        sectionHeader("profile.section.trainingProfile")
                        if let profile = trainingProfiles.first {
                            // Profile exists: show summary rows
                            profileRow("profile.field.sessionsPerWeek", value: "\(profile.sessionsPerWeek)")
                            divider()
                            profileRow("profile.field.avgDuration", value: "\(profile.avgDurationMinutes) min")
                            divider()
                            profileRow("profile.field.typicalEffort", value: "\(Int(profile.typicalSRPE))/10")
                            divider()
                            profileRow("profile.field.weeksAtLevel", value: "\(profile.weeksAtLevel)")
                            divider()
                            actionButton("profile.action.editProfile") {
                                showTrainingProfileSheet = true
                            }
                        } else {
                            // No profile: show setup prompt
                            actionButton("profile.action.setupTrainingProfile") {
                                showTrainingProfileSheet = true
                            }
                        }
                        sectionDivider()

                        // Cycle & Hormones (D-03)
                        if showCycleSection {
                            sectionHeader("profile.section.cycleHormones")

                            HStack {
                                Text("profile.row.hormonalContraceptive")
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { athlete.isOnHormonalContraceptive ?? false },
                                    set: { newValue in
                                        athlete.isOnHormonalContraceptive = newValue
                                        saveAthlete(athlete)
                                    }
                                ))
                                .labelsHidden()
                                .toggleStyle(.design)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)

                            divider()

                            HStack {
                                Text("profile.row.pregnant")
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { athlete.isPregnant ?? false },
                                    set: { newValue in
                                        athlete.isPregnant = newValue
                                        saveAthlete(athlete)
                                    }
                                ))
                                .labelsHidden()
                                .toggleStyle(.design)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)

                            divider()

                            HStack {
                                Text("profile.row.lactating")
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { athlete.isLactating ?? false },
                                    set: { newValue in
                                        athlete.isLactating = newValue
                                        saveAthlete(athlete)
                                    }
                                ))
                                .labelsHidden()
                                .toggleStyle(.design)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)

                            divider()

                            // PCOS / Perimenopause (D-11a) — local-only RED-S exclusion flags.
                            HStack {
                                Text("profile.row.pcos")
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { athlete.hasPCOS ?? false },
                                    set: { newValue in
                                        athlete.hasPCOS = newValue
                                        saveAthlete(athlete)
                                    }
                                ))
                                .labelsHidden()
                                .toggleStyle(.design)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)

                            divider()

                            HStack {
                                Text("profile.row.perimenopausal")
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { athlete.isPerimenopausal ?? false },
                                    set: { newValue in
                                        athlete.isPerimenopausal = newValue
                                        saveAthlete(athlete)
                                    }
                                ))
                                .labelsHidden()
                                .toggleStyle(.design)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)

                            sectionDivider()
                        }

                        // Preferences
                        sectionHeader("profile.section.preferences")
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        }
                        divider()
                        editablePicker("profile.row.weightUnit", selection: Binding(
                            get: { athlete.weightUnit },
                            set: { athlete.weightUnit = $0; saveAthlete(athlete) }
                        ), options: WeightUnit.allCases) { $0.displayName }
                        divider()
                        editablePicker("profile.row.acwrMethod", selection: Binding(
                            get: { athlete.acwrMethod },
                            set: { athlete.acwrMethod = $0; saveAthlete(athlete) }
                        ), options: ACWRMethod.allCases) { $0.displayName }
                        divider()
                        editablePicker("profile.row.loadMetric", selection: Binding(
                            get: { athlete.loadMetricPreference },
                            set: { athlete.loadMetricPreference = $0; saveAthlete(athlete) }
                        ), options: LoadSource.allCases) { $0.displayName }
                        sectionDivider()

                        // NOTIFICATIONS section (NOTF-03)
                        sectionHeader("profile.section.notifications")

                        // Toggle row
                        HStack {
                            Text("profile.row.weeklySummary")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                            Spacer()
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
                            .toggleStyle(.design)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        // System denied warning
                        if notificationsDenied {
                            Text("profile.notif.deniedHint")
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text3)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
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

                        sectionDivider()

                        // HealthKit
                        sectionHeader("profile.section.connectedDevices")
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        }
                        divider()
                        Text("profile.healthkit.devicesHint")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text3)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        sectionDivider()

                        // Data Sync
                        sectionHeader("profile.section.dataSync")
                        NavigationLink {
                            SyncStatusView()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.Tokens.label)
                                    .foregroundStyle(ColorTokens.text2)
                                    .frame(width: 24)
                                Text("profile.sync.status")
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                                Spacer()
                                if SyncTimestampStore.shared.hasAnyFailure {
                                    Text("profile.sync.issues")
                                        .font(.Tokens.label)
                                        .foregroundStyle(ColorTokens.zoneCaution)
                                } else {
                                    Text("profile.sync.allSynced")
                                        .font(.Tokens.label)
                                        .foregroundStyle(ColorTokens.text2)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.Tokens.micro)
                                    .foregroundStyle(ColorTokens.text3)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        }
                        sectionDivider()

                        // Coach
                        sectionHeader("profile.section.coach")
                        if !athlete.isCoach {
                            HStack {
                                Text("profile.row.coachMode")
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { athlete.isCoach },
                                    set: { newValue in
                                        athlete.isCoach = newValue
                                        athlete.updatedAt = .now
                                        try? modelContext.save()
                                        Task { await container.syncService.pushAthlete(athlete) }
                                    }
                                ))
                                .labelsHidden()
                                .toggleStyle(.design)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            divider()
                        }

                        if athlete.isCoach {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("profile.row.coachOnly")
                                        .font(.Tokens.body)
                                        .foregroundStyle(ColorTokens.text1)
                                    Text("profile.row.coachOnlyHint")
                                        .font(.Tokens.label)
                                        .foregroundStyle(ColorTokens.text2)
                                }
                                Spacer()
                                if container.subscriptionService.isCoach {
                                    Toggle("", isOn: Binding(
                                        get: { athlete.isCoachOnly },
                                        set: { newValue in
                                            athlete.isCoachOnly = newValue
                                            athlete.updatedAt = .now
                                            try? modelContext.save()
                                            if newValue {
                                                container.setMode(.coach)
                                            }
                                            Task { await container.syncService.pushAthlete(athlete) }
                                        }
                                    ))
                                    .labelsHidden()
                                } else {
                                    Image(systemName: "lock.fill")
                                        .font(.Tokens.micro)
                                        .foregroundStyle(ColorTokens.text3)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !container.subscriptionService.isCoach {
                                    showUpgrade = true
                                }
                            }
                            divider()
                        }

                        InviteCoachCard(isGenerating: isGeneratingCode) {
                            Task { await generateCode(for: athlete) }
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.top, Spacing.sm)

                        if athlete.isCoach {
                            Spacer().frame(height: Spacing.sm)
                            actionButton("profile.action.inviteAthleteEmail") {
                                showEmailInviteSheet = true
                            }
                            divider()
                            actionButton("profile.action.enterAthleteCode") {
                                showEnterCodeSheet = true
                            }
                        }


                        // Linked Coaches
                        let myCoachRels = relationships.filter {
                            $0.athleteId == athlete.id && $0.status == .accepted
                        }
                        if !myCoachRels.isEmpty {
                            sectionDivider()
                            sectionHeader("profile.section.myCoaches")
                            ForEach(myCoachRels) { rel in
                                LinkedPartyRow(athleteId: rel.coachId)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                if rel.id != myCoachRels.last?.id {
                                    divider()
                                }
                            }
                        }

                        // My Athletes (coach mode)
                        if athlete.isCoach {
                            let myAthleteRels = relationships.filter {
                                $0.coachId == athlete.id && $0.status == .accepted
                            }
                            if !myAthleteRels.isEmpty {
                                sectionDivider()
                                sectionHeader("profile.section.myAthletes")
                                ForEach(myAthleteRels) { rel in
                                    LinkedPartyRow(athleteId: rel.athleteId)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    if rel.id != myAthleteRels.last?.id {
                                        divider()
                                    }
                                }
                            }
                        }

                        // Account — destructive actions, grouped + separated
                        sectionDivider()
                        sectionHeader("profile.section.account")
                        Button {
                            Task {
                                try? await container.signOut(modelContext: modelContext)
                            }
                        } label: {
                            Text("profile.signOut")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.zoneDanger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                        }
                        divider()
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Text(isDeletingAccount ? "profile.action.deleting" : "profile.action.deleteAccount")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.zoneDanger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                        }
                        .disabled(isDeletingAccount)
                        divider()
                    } else {
                        Text("profile.empty.noAthlete")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text3)
                            .padding(32)
                    }
                }
            }
            .background(ColorTokens.background)
            .task {
                let status = await container.notificationService.authorizationStatus()
                notificationsDenied = (status == .denied)
                if status == .denied && notificationsEnabled {
                    notificationsEnabled = false
                    container.notificationService.cancelWeeklySummary()
                }
            }
            .navigationTitle("profile.nav.title")
            .toolbarBackground(ColorTokens.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .withContextSwitcher()
            // Generated code display — designed sheet (not the system alert)
            .sheet(isPresented: $showInviteCodeSheet, onDismiss: { generatedCode = nil }) {
                if let code = generatedCode {
                    InviteCodeSheet(code: code)
                }
            }
            // Enter code sheet
            .sheet(isPresented: $showEnterCodeSheet) {
                EnterInviteCodeSheet()
                    .environment(container)
            }
            // Email invite sheet
            .sheet(isPresented: $showEmailInviteSheet) {
                EmailInviteSheet()
                    .environment(container)
            }
            // Confirmation sheet
            .sheet(item: $pendingInviteFromProfile) { pending in
                InviteConfirmationSheet(code: pending.code, mode: .coachConfirming)
                    .environment(container)
            }
            .sheet(isPresented: $showUpgrade) {
                UpgradeSheet(trigger: .coach)
                    .environment(container)
            }
            .sheet(isPresented: $showTrainingProfileSheet) {
                TrainingProfileSheet(existingProfile: trainingProfiles.first)
                    .environment(container)
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
                            errorMessage = "Failed to delete account: \(error.localizedDescription)"
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

    @ViewBuilder
    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        SectionHeader(title: title)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.sm)
    }

    @ViewBuilder
    private func profileRow(_ label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(label)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
            Spacer()
            Text(value)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func actionButton(_ label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
        }
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
    private func editableTextField(_ label: LocalizedStringKey, value: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
            Spacer()
            TextField(label, text: value)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func editablePicker<T: Hashable>(
        _ label: LocalizedStringKey,
        selection: Binding<T>,
        options: [T],
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
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(displayName(selection.wrappedValue))
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                    MenuChevron()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func scheduleNotification() {
        let timeParts = notificationTime.split(separator: ":").compactMap { Int($0) }
        let hour = timeParts.first ?? 19
        let minute = timeParts.count > 1 ? timeParts[1] : 0
        container.notificationService.scheduleWeeklySummary(
            weekday: notificationDay,
            hour: hour,
            minute: minute,
            sessionCount: 0,
            streak: 0,
            prCount: 0,
            volumeDelta: 0
        )
    }

    private func saveAthlete(_ athlete: Athlete) {
        athlete.updatedAt = .now
        try? modelContext.save()
        Task { await container.syncService.pushAthlete(athlete) }
    }

    // MARK: - Actions

    private func generateCode(for athlete: Athlete) async {
        isGeneratingCode = true
        do {
            generatedCode = try await InviteService.generateInviteCode(for: athlete.id, client: container.supabase)
            showInviteCodeSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isGeneratingCode = false
    }

    private func removeRelationship(_ rel: CoachAthleteRelationship) async {
        do {
            try await container.syncService.removeRelationship(id: rel.id, context: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Supporting views

/// Designed invite affordance — the primary coach-linking action, distinguished from the
/// flat preference rows by a card plane (`cardStyle`), a leading icon, a title + subtitle,
/// and a bordered action. Replaces the bare flat row that read as just another setting.
struct InviteCoachCard: View {
    let isGenerating: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "person.badge.plus")
                    .font(.Tokens.sectionHead)
                    .foregroundStyle(ColorTokens.text1)
                Text("profile.invite.cardTitle")
                    .font(.Tokens.sectionHead)
                    .foregroundStyle(ColorTokens.text1)
            }
            Text("profile.invite.cardSubtitle")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
            Button(action: action) {
                HStack(spacing: Spacing.xs) {
                    if isGenerating {
                        ProgressView()
                        Text("profile.action.generating")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text2)
                    } else {
                        Text("profile.action.inviteMyCoach")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                // Heavier 1pt border marks this as the primary action vs the 0.5pt row hairlines.
                .overlay(Rectangle().stroke(ColorTokens.text2, lineWidth: 1))
            }
            .disabled(isGenerating)
        }
        .cardStyle()
    }
}

/// Designed sheet that displays a generated invite code, replacing the default system alert.
/// Big tabular code on the card plane, copy + done actions in the separator grammar.
struct InviteCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let code: String
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("profile.invite.codeSheetTitle")
                        .font(.Tokens.micro)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(ColorTokens.text3)
                    Text(code)
                        .font(.Tokens.pageTitle)
                        .monospacedDigit()
                        .tracking(4)
                        .foregroundStyle(ColorTokens.text1)
                    Text("profile.invite.shareCodeHint")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                    Text("profile.invite.codeExpiry")
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.text3)
                }
                .cardStyle()
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                Button {
                    UIPasteboard.general.string = code
                    copied = true
                } label: {
                    Text(copied ? "action.copied" : "action.copy")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                }
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                Button { dismiss() } label: {
                    Text("action.done")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                }
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                Spacer()
            }
            .background(ColorTokens.background)
            .navigationBarHidden(true)
        }
    }
}

struct LinkedPartyRow: View {
    @Query private var athletes: [Athlete]
    let athleteId: UUID

    private var linkedAthlete: Athlete? {
        athletes.first(where: { $0.id == athleteId })
    }

    var body: some View {
        if let a = linkedAthlete {
            VStack(alignment: .leading, spacing: 2) {
                Text(a.displayName)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                Text(a.sportType.displayName)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text3)
            }
        } else {
            Text("common.unknown")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text3)
        }
    }
}

struct EnterInviteCodeSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var pending: PendingInvite?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                VStack(alignment: .leading, spacing: 0) {
                    Text("profile.invite.code")
                        .font(.Tokens.micro)
                        .tracking(0.88)
                        .foregroundStyle(ColorTokens.text3)
                        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)
                    TextField("profile.invite.codePlaceholder", text: $code)
                        .font(.Tokens.body)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16).padding(.bottom, 16)
                }
                .background(ColorTokens.surface)
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                Button {
                    pending = PendingInvite(code: code.uppercased())
                } label: {
                    Text("profile.invite.lookUp")
                        .font(.Tokens.body)
                        .foregroundStyle(code.count == 6 ? ColorTokens.text1 : ColorTokens.text3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .disabled(code.count != 6)
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                Spacer()
            }
            .background(ColorTokens.background)
            .navigationBarHidden(true)
            .sheet(item: $pending) { p in
                InviteConfirmationSheet(code: p.code, mode: .coachConfirming)
                    .environment(container)
                    .onDisappear { dismiss() }
            }
        }
    }
}

struct EmailInviteSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Query private var athletes: [Athlete]
    @State private var email = ""
    @State private var isSending = false
    @State private var sent = false
    @State private var error: String?

    private var athlete: Athlete? { athletes.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                VStack(alignment: .leading, spacing: 0) {
                    Text("profile.invite.athleteEmail")
                        .font(.Tokens.micro)
                        .tracking(0.88)
                        .foregroundStyle(ColorTokens.text3)
                        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)
                    TextField("athlete@example.com", text: $email)
                        .font(.Tokens.body)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16).padding(.bottom, 16)
                }
                .background(ColorTokens.surface)
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                if let error {
                    Text(error)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.zoneDanger)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                }
                if sent {
                    Text("profile.invite.sentConfirmation")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                        .padding(16)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    Button("action.done") { dismiss() }
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                } else {
                    Button {
                        Task { await sendInvite() }
                    } label: {
                        Group {
                            if isSending { ProgressView() }
                            else {
                                Text("profile.invite.send")
                                    .font(.Tokens.body)
                                    .foregroundStyle(email.contains("@") ? ColorTokens.text1 : ColorTokens.text3)
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                    }
                    .disabled(!email.contains("@") || isSending)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                }
                Spacer()
            }
            .background(ColorTokens.background)
            .navigationBarHidden(true)
        }
    }

    private func sendInvite() async {
        guard let athlete else { return }
        isSending = true
        do {
            try await InviteService.sendEmailInvite(to: email, from: athlete.id, client: container.supabase)
            sent = true
        } catch {
            self.error = error.localizedDescription
        }
        isSending = false
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                sectionHeader("profile.healthkit.dataWeRead")

                ForEach(dataTypes, id: \.0) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.1)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                            .frame(width: 24)
                        Text(item.0)
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5).padding(.leading, 52)
                }

                Spacer().frame(height: 24)
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
                    HStack(spacing: 8) {
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
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
                        HStack(spacing: 8) {
                            Text("profile.healthkit.manageInHealth")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.Tokens.smallLabel)
                                .foregroundStyle(ColorTokens.text2)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                }

                if let error = authError {
                    Text(error)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.zoneDanger)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
        }
        .background(ColorTokens.background)
        .navigationTitle("profile.healthkit.navTitle")
    }

    @ViewBuilder
    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        SectionHeader(title: title)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.sm)
    }
}
