import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
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
    @State private var isDeletingAccount = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if let athlete {
                        // Athlete Info
                        profileSection("profile.section.athlete") {
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
                        }

                        // Training Profile (D-03)
                        profileSection("profile.section.trainingProfile") {
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(ColorTokens.surfaceEl)
                        }
                        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                        divider()
                        editablePicker("profile.row.weightUnit", selection: Binding(
                            get: { athlete.weightUnit },
                            set: { athlete.weightUnit = $0; saveAthlete(athlete) }
                        ), options: WeightUnit.allCases) { $0.displayName }
                        }

                        // NOTIFICATIONS section (NOTF-03)
                        profileSection("profile.section.notifications") {

                        // Toggle row
                        HStack {
                            Text("profile.row.weeklySummary")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { notificationsEnabled },
                                set: { newValue in
                                    Haptics.tap()
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
                        .padding(.vertical, 16)
                        .background(ColorTokens.surfaceEl)

                        // System denied warning
                        if notificationsDenied {
                            Text("profile.notif.deniedHint")
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                                .background(ColorTokens.surfaceEl)
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(ColorTokens.surfaceEl)
                        }
                        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                        divider()
                        Text("profile.healthkit.devicesHint")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(ColorTokens.surfaceEl)
                        }

                        // Data Sync
                        profileSection("profile.section.dataSync") {
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
                            .background(ColorTokens.surfaceEl)
                        }
                        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                        }

                        // Validation signals — quiet internal readout (METRIC-02). NOT a hero row:
                        // no accent, mirrors the Sync row treatment.
                        profileSection("profile.section.measurement") {
                        NavigationLink {
                            VerdictMeasurementView()
                        } label: {
                            HStack(spacing: 8) {
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(ColorTokens.surfaceEl)
                        }
                        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                        }

                        // Account — destructive actions, grouped + separated
                        profileSection("profile.section.account") {
                        Button {
                            Task {
                                try? await container.signOut(modelContext: modelContext)
                            }
                        } label: {
                            Text("profile.signOut")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .background(ColorTokens.surfaceEl)
                        }
                        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                        divider()
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Text(isDeletingAccount ? "profile.action.deleting" : "profile.action.deleteAccount")
                                .font(.Tokens.bodyMedium)
                                .foregroundStyle(ColorTokens.zoneDanger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .background(ColorTokens.surfaceEl)
                        }
                        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                        .disabled(isDeletingAccount)
                        }

                        Spacer().frame(height: Spacing.lg)
                    } else {
                        Text("profile.empty.noAthlete")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text3)
                            .padding(Spacing.lg)
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

    /// Wraps a top-level grouped section: 32pt break + 19pt header, then the rows on a single
    /// bordered card plane (Tuwa v2 separation — each section reads as a distinct surface).
    @ViewBuilder
    private func profileSection<Content: View>(
        _ header: LocalizedStringKey,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: Spacing.lg)
            SectionHeader(title: header)
            Spacer().frame(height: Spacing.sm)
            VStack(spacing: 0) {
                content()
            }
            .cardStyle(horizontalPadding: 0, verticalPadding: 0)
            .padding(.horizontal, Spacing.sm)
        }
    }

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
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(ColorTokens.surfaceEl)
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
                .background(ColorTokens.surfaceEl)
        }
        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
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
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(ColorTokens.surfaceEl)
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
                        Haptics.select()
                        selection.wrappedValue = option
                    }
                }
            } label: {
                HStack(spacing: Spacing.baselinePair) {
                    Text(displayName(selection.wrappedValue))
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
        SectionHeader(title: title)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.sm)
    }
}
