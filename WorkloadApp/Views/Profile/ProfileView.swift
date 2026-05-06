import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]
    @Query private var relationships: [CoachAthleteRelationship]
    @Query private var trainingProfiles: [TrainingProfile]

    private var athlete: Athlete? { athletes.first }

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
                        sectionHeader("ATHLETE")
                        editableTextField("Name", value: Binding(
                            get: { athlete.displayName },
                            set: { athlete.displayName = $0; saveAthlete(athlete) }
                        ))
                        divider()
                        editablePicker("Sport", selection: Binding(
                            get: { athlete.sportType },
                            set: { athlete.sportType = $0; saveAthlete(athlete) }
                        ), options: SportType.allCases) { $0.displayName }
                        divider()
                        editablePicker("Training Frequency", selection: Binding(
                            get: { athlete.trainingFrequency ?? .threeToFour },
                            set: { athlete.trainingFrequency = $0; saveAthlete(athlete) }
                        ), options: TrainingFrequency.allCases) { $0.displayName }
                        divider()
                        editablePicker("Experience Level", selection: Binding(
                            get: { athlete.experienceLevel ?? .intermediate },
                            set: { athlete.experienceLevel = $0; saveAthlete(athlete) }
                        ), options: ExperienceLevel.allCases) { $0.displayName }
                        sectionDivider()

                        // Training Profile (D-03)
                        sectionHeader("TRAINING PROFILE")
                        if let profile = trainingProfiles.first {
                            // Profile exists: show summary rows
                            profileRow("Sessions / week", value: "\(profile.sessionsPerWeek)")
                            divider()
                            profileRow("Avg duration", value: "\(profile.avgDurationMinutes) min")
                            divider()
                            profileRow("Typical effort", value: "\(Int(profile.typicalSRPE))/10")
                            divider()
                            profileRow("Weeks at level", value: "\(profile.weeksAtLevel)")
                            divider()
                            actionButton("Edit Profile") {
                                showTrainingProfileSheet = true
                            }
                        } else {
                            // No profile: show setup prompt
                            actionButton("Set up training profile") {
                                showTrainingProfileSheet = true
                            }
                        }
                        sectionDivider()

                        // Preferences
                        sectionHeader("PREFERENCES")
                        editablePicker("Weight Unit", selection: Binding(
                            get: { athlete.weightUnit },
                            set: { athlete.weightUnit = $0; saveAthlete(athlete) }
                        ), options: WeightUnit.allCases) { $0.displayName }
                        divider()
                        editablePicker("ACWR Method", selection: Binding(
                            get: { athlete.acwrMethod },
                            set: { athlete.acwrMethod = $0; saveAthlete(athlete) }
                        ), options: ACWRMethod.allCases) { $0.displayName }
                        divider()
                        editablePicker("Load Metric", selection: Binding(
                            get: { athlete.loadMetricPreference },
                            set: { athlete.loadMetricPreference = $0; saveAthlete(athlete) }
                        ), options: LoadSource.allCases) { $0.displayName }
                        sectionDivider()

                        // NOTIFICATIONS section (NOTF-03)
                        sectionHeader("NOTIFICATIONS")

                        // Toggle row
                        HStack {
                            Text("Weekly Summary")
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
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        // System denied warning
                        if notificationsDenied {
                            Text("Notifications are disabled in Settings. Go to Settings > Tonus to enable them.")
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text3)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                        }

                        divider()

                        // Day picker row
                        editablePicker(
                            "Day",
                            selection: Binding(
                                get: { notificationDay },
                                set: { newValue in
                                    notificationDay = newValue
                                    if notificationsEnabled { scheduleNotification() }
                                }
                            ),
                            options: Array(1...7),
                            displayName: { weekday in
                                Calendar.current.weekdaySymbols[weekday - 1]
                            }
                        )
                        .disabled(!notificationsEnabled)
                        .foregroundStyle(notificationsEnabled ? ColorTokens.text1 : ColorTokens.text3)

                        divider()

                        // Time picker row
                        editablePicker(
                            "Time",
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
                                let ampm = hour >= 12 ? "PM" : "AM"
                                let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
                                return "\(displayHour):00 \(ampm)"
                            }
                        )
                        .disabled(!notificationsEnabled)
                        .foregroundStyle(notificationsEnabled ? ColorTokens.text1 : ColorTokens.text3)

                        sectionDivider()

                        // HealthKit
                        sectionHeader("CONNECTED DEVICES")
                        NavigationLink {
                            HealthKitPermissionsView()
                        } label: {
                            HStack {
                                Text("HealthKit Permissions")
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(ColorTokens.text3)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        }
                        divider()
                        Text("Data from Apple Watch, Whoop, Oura, and Garmin flows through HealthKit automatically.")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text3)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        sectionDivider()

                        // Coach
                        sectionHeader("COACH")
                        if !athlete.isCoach {
                            HStack {
                                Text("Enable Coach Mode")
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
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            divider()
                        }

                        if athlete.isCoach {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Coach Only")
                                        .font(.Tokens.body)
                                        .foregroundStyle(ColorTokens.text1)
                                    Text("Hide athlete tabs, always show coach view")
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
                                        .font(.system(size: 12))
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

                        actionButton(isGeneratingCode ? "Generating..." : "Invite My Coach") {
                            Task { await generateCode(for: athlete) }
                        }
                        .disabled(isGeneratingCode)

                        if athlete.isCoach {
                            divider()
                            actionButton("Invite an Athlete (Email)") {
                                showEmailInviteSheet = true
                            }
                            divider()
                            actionButton("Enter Athlete Code") {
                                showEnterCodeSheet = true
                            }
                        }


                        // Linked Coaches
                        let myCoachRels = relationships.filter {
                            $0.athleteId == athlete.id && $0.status == .accepted
                        }
                        if !myCoachRels.isEmpty {
                            sectionDivider()
                            sectionHeader("MY COACHES")
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
                                sectionHeader("MY ATHLETES")
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

                        // Sign Out
                        sectionDivider()
                        Button {
                            Task {
                                try? await container.signOut(modelContext: modelContext)
                            }
                        } label: {
                            Text("Sign Out")
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
                            Text(isDeletingAccount ? "Deleting..." : "Delete Account")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.zoneDanger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                        }
                        .disabled(isDeletingAccount)
                        divider()
                    } else {
                        Text("No athlete profile found.")
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
            .navigationTitle("Profile")
            .toolbarBackground(ColorTokens.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .withContextSwitcher()
            // Generated code display
            .alert("Your Invite Code", isPresented: $showInviteCodeSheet, presenting: generatedCode) { code in
                Button("Done") { generatedCode = nil }
                Button("Copy") { UIPasteboard.general.string = code }
            } message: { code in
                Text("Share this code with your coach:\n\n\(code)\n\nExpires in 48 hours.")
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
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
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
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
            }
            // Error
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.Tokens.micro)
            .foregroundStyle(ColorTokens.text3)
            .tracking(0.88)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }

    @ViewBuilder
    private func profileRow(_ label: String, value: String) -> some View {
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
    private func actionButton(_ label: String, action: @escaping () -> Void) -> some View {
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
    private func editableTextField(_ label: String, value: Binding<String>) -> some View {
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
        _ label: String,
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
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.text3)
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
        let body = NotificationService.buildNotificationBody(
            sessionCount: 0, streak: 0, prCount: 0, volumeDelta: 0
        )
        container.notificationService.scheduleWeeklySummary(
            weekday: notificationDay, hour: hour, minute: minute, body: body
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
            Text("Unknown")
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
                    Text("INVITE CODE")
                        .font(.Tokens.micro)
                        .tracking(0.88)
                        .foregroundStyle(ColorTokens.text3)
                        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)
                    TextField("Enter 6-character code", text: $code)
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
                    Text("Look Up Code")
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
                    Text("ATHLETE EMAIL")
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
                    Text("Invite sent! They'll receive a link by email.")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                        .padding(16)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    Button("Done") { dismiss() }
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
                                Text("Send Invite")
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
                Text("Tonus reads data from HealthKit to calculate your recovery score and TRIMP. We never write data to HealthKit.")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                sectionHeader("DATA WE READ")

                ForEach(dataTypes, id: \.0) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.1)
                            .font(.system(size: 14))
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

                Button {
                    Task {
                        isAuthorizing = true
                        do {
                            try await container.healthKitService.requestAuthorization()
                        } catch {
                            authError = error.localizedDescription
                        }
                        isAuthorizing = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isAuthorizing {
                            ProgressView()
                        } else if container.healthKitService.isAuthorized {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(ColorTokens.zoneOptimal)
                            Text("Authorized")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.zoneOptimal)
                        } else {
                            Text("Authorize HealthKit Access")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .disabled(isAuthorizing || container.healthKitService.isAuthorized)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

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
        .navigationTitle("HealthKit")
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.Tokens.micro)
            .foregroundStyle(ColorTokens.text3)
            .tracking(0.88)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }
}
