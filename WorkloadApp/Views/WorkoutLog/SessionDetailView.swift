import SwiftUI

/// Read-only detail view for a completed workout session.
struct SessionDetailView: View {
    let session: WorkoutSession

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Session header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: session.sportType.systemImage)
                            .foregroundStyle(ColorTokens.text2)
                        Text(session.sportType.displayName)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                        Spacer()
                        Text(session.sessionDate.relativeString)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(ColorTokens.surface)

                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)

                // Metric row
                HStack(spacing: 0) {
                    MetricTile(
                        title: "Duration",
                        value: Date.durationString(seconds: session.durationSeconds)
                    )
                    if let rpe = session.sessionRPE {
                        Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                        MetricTile(
                            title: "RPE",
                            value: String(format: "%.0f", rpe),
                            color: rpe >= 8 ? ColorTokens.zoneDanger : rpe >= 6 ? ColorTokens.zoneCaution : ColorTokens.zoneOptimal
                        )
                    }
                    if session.totalVolume > 0 {
                        Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                        MetricTile(
                            title: "Volume",
                            value: String(format: "%.0f kg", session.totalVolume)
                        )
                    }
                }

                if session.trainingStress > 0 || session.acuteLoad > 0 {
                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    HStack(spacing: 0) {
                        if session.trainingStress > 0 {
                            MetricTile(
                                title: "TSS",
                                value: String(format: "%.1f", session.trainingStress)
                            )
                        }
                        if session.acuteLoad > 0 {
                            Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                            MetricTile(
                                title: "ATL",
                                value: String(format: "%.0f", session.acuteLoad),
                                color: ColorTokens.chartATL
                            )
                            Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                            MetricTile(
                                title: "CTL",
                                value: String(format: "%.0f", session.chronicLoad),
                                color: ColorTokens.chartCTL
                            )
                        }
                    }
                }

                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)

                // Exercises
                ForEach(session.sortedEntries, id: \.id) { entry in
                    ExerciseDetailCard(entry: entry)
                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)
                }
            }
        }
        .background(ColorTokens.background)
        .navigationTitle(session.sessionName ?? session.sportType.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Exercise Detail Card

struct ExerciseDetailCard: View {
    let entry: ExerciseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(entry.exerciseName)
                    .font(.Tokens.sectionHead)
                    .foregroundStyle(ColorTokens.text1)
                Spacer()
                if let muscle = entry.muscleGroup {
                    Text(muscle.displayName)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Rectangle()
                .fill(ColorTokens.divider)
                .frame(height: 0.5)

            // Column headers
            HStack {
                Text("SET")
                    .frame(width: 32, alignment: .leading)
                Text("WEIGHT")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("REPS")
                    .frame(width: 48, alignment: .leading)
                Text("RPE")
                    .frame(width: 40, alignment: .trailing)
                Text("VOL")
                    .frame(width: 56, alignment: .trailing)
            }
            .font(.Tokens.micro)
            .tracking(1.2)
            .foregroundStyle(ColorTokens.text3)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            ForEach(entry.sortedSets, id: \.id) { set in
                HStack {
                    Text("\(set.setIndex + 1)")
                        .frame(width: 32, alignment: .leading)
                        .foregroundStyle(set.isWarmup ? ColorTokens.zoneCaution : ColorTokens.text2)
                    Text(set.weightKg.map { String(format: "%.1f kg", $0) } ?? "—")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(ColorTokens.text1)
                    Text(set.reps.map { "\($0)" } ?? "—")
                        .frame(width: 48, alignment: .leading)
                        .foregroundStyle(ColorTokens.text1)
                    Text(set.rpe.map { String(format: "%.0f", $0) } ?? "—")
                        .frame(width: 40, alignment: .trailing)
                        .foregroundStyle(ColorTokens.text2)
                    Text(set.volume > 0 ? String(format: "%.0f", set.volume) : "—")
                        .frame(width: 56, alignment: .trailing)
                        .foregroundStyle(ColorTokens.text2)
                }
                .font(.Tokens.label)
                .monospacedDigit()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)
            }

            if entry.totalVolume > 0 {
                HStack {
                    Spacer()
                    Text("Total: \(String(format: "%.0f kg", entry.totalVolume))")
                        .font(.Tokens.label)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.text2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(ColorTokens.surface)
    }
}
