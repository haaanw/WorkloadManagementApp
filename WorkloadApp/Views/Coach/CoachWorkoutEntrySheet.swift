import SwiftUI
import SwiftData

struct CoachWorkoutEntrySheet: View {
    let athlete: Athlete
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var myAthletes: [Athlete]

    @State private var sessionDate = Date()
    @State private var durationMinutes: Double = 60
    @State private var srpe: Double = 6
    @State private var sessionType: SessionType = .strength
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var spikeAlert: WorkloadCalculator.SpikeAlert?
    @State private var showSpikeAlert = false

    // The coach's own Athlete record (for loggedByCoachId)
    private var coachAthlete: Athlete? { myAthletes.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // Date
                    HStack {
                        Text("coach.workout.fieldDate")
                            .font(.Tokens.micro)
                            .tracking(1.2)
                            .foregroundStyle(ColorTokens.text3)
                        Spacer()
                        DatePicker("", selection: $sessionDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(ColorTokens.surface)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // Session Type
                    VStack(alignment: .leading, spacing: 8) {
                        Text("coach.workout.fieldSessionType")
                            .font(.Tokens.micro)
                            .tracking(1.2)
                            .foregroundStyle(ColorTokens.text3)
                        Picker("Session Type", selection: $sessionType) {
                            ForEach(SessionType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(ColorTokens.surface)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // Duration
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("coach.workout.fieldDuration")
                                .font(.Tokens.micro)
                                .tracking(1.2)
                                .foregroundStyle(ColorTokens.text3)
                            Spacer()
                            Text("\(Int(durationMinutes)) min")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                        }
                        Slider(value: $durationMinutes, in: 15...180, step: 5)
                            .tint(ColorTokens.text2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(ColorTokens.surface)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // sRPE
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("coach.workout.fieldSRPE")
                                .font(.Tokens.micro)
                                .tracking(1.2)
                                .foregroundStyle(ColorTokens.text3)
                            Spacer()
                            Text(String(format: "%.1f / 10", srpe))
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                        }
                        Slider(value: $srpe, in: 1...10, step: 0.5)
                            .tint(ColorTokens.text2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(ColorTokens.surface)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    if let error = errorMessage {
                        Text(error)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.zoneDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    }

                    Button {
                        Task { await logWorkout() }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView()
                            } else {
                                Text(String(localized: "coach.workout.title", defaultValue: "Log Workout for \(athlete.displayName)"))
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ColorTokens.surface)
                    }
                    .disabled(isLoading)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("coach.nav.logWorkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
            .overlay(alignment: .bottom) {
                if showSpikeAlert, let spikeAlert {
                    SpikeAlertBanner(alert: spikeAlert) {
                        showSpikeAlert = false
                        dismiss()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 16)
                    .padding(.horizontal, 16)
                }
            }
            .animation(.easeOut(duration: 0.25), value: showSpikeAlert)
        }
    }

    private func logWorkout() async {
        isLoading = true
        errorMessage = nil
        do {
            let durationSecs = Int(durationMinutes * 60)

            // Create and save the WorkoutSession locally
            let session = WorkoutSession(
                sessionDate: sessionDate,
                durationSeconds: durationSecs,
                sessionRPE: srpe,
                sessionType: sessionType,
                loggedByCoachId: coachAthlete?.id
            )
            session.athlete = athlete
            modelContext.insert(session)
            try modelContext.save()

            // Process through pipeline (computes ACWR/ATL/CTL correctly)
            let result = try WorkoutPipeline.processSession(session, athlete: athlete, modelContext: modelContext)

            // Push session to Supabase
            do {
                await container.syncService.pushCoachWorkoutSession(session, for: athlete.id)
            }

            // Show spike alert if detected, otherwise dismiss
            if let spike = result.spikeAlert {
                spikeAlert = spike
                showSpikeAlert = true
            } else {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
