import SwiftUI

/// Read-only detail view for a completed workout session.
struct SessionDetailView: View {
    let session: WorkoutSession
    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                // Session summary card (metadata + metrics) — one bordered plane so it reads as a
                // distinct surface lifted off the page (Tuwa v2 separation).
                VStack(spacing: 0) {
                // Session header
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Image(systemName: session.sportType.systemImage)
                            .foregroundStyle(ColorTokens.text2)
                        Text(session.sportType.displayName)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                        Spacer()
                        // A timestamp — annotation's canonical content (v6).
                        AnnotationLabel(
                            session.sessionDate.relativeString(locale: locale),
                            color: ColorTokens.text2
                        )
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.sm)

                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)

                // Metric row
                HStack(spacing: 0) {
                    MetricTile(
                        title: String(localized: "metric.duration", defaultValue: "Duration"),
                        value: Date.durationString(seconds: session.durationSeconds, locale: locale)
                    )
                    if let rpe = session.sessionRPE {
                        Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                        MetricTile(
                            title: String(localized: "metric.rpe", defaultValue: "RPE"),
                            value: String(format: "%.0f", rpe),
                            color: rpe >= 8 ? ColorTokens.zoneDanger : rpe >= 6 ? ColorTokens.zoneCaution : ColorTokens.zoneOptimal
                        )
                    }
                    if session.totalVolume > 0 {
                        Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                        MetricTile(
                            title: String(localized: "metric.volume", defaultValue: "Volume"),
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
                                title: String(localized: "metric.tss", defaultValue: "TSS"),
                                value: String(format: "%.1f", session.trainingStress)
                            )
                        }
                        if session.acuteLoad > 0 {
                            Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                            MetricTile(
                                title: String(localized: "metric.atl", defaultValue: "ATL"),
                                value: String(format: "%.0f", session.acuteLoad),
                                color: ColorTokens.chartATL
                            )
                            Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                            MetricTile(
                                title: String(localized: "metric.ctl", defaultValue: "CTL"),
                                value: String(format: "%.0f", session.chronicLoad),
                                color: ColorTokens.chartCTL
                            )
                        }
                    }
                }
                }
                // v3 Corner Law: card plane on `CornerTokens.card`; internal hairlines are
                // sanctioned separators, clipped by the rounded shape.
                .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.card))
                .clipShape(RoundedRectangle(cornerRadius: CornerTokens.card))
                .overlay(RoundedRectangle(cornerRadius: CornerTokens.card).stroke(ColorTokens.divider, lineWidth: 0.5))

                // Exercises — each a distinct bordered card (Tuwa v2 separation).
                ForEach(session.sortedEntries, id: \.id) { entry in
                    ExerciseDetailCard(entry: entry)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
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
                    // A taxonomy tag beside the movement name — marginalia (v6).
                    AnnotationLabel(muscle.displayName, color: ColorTokens.text2)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)

            Rectangle()
                .fill(ColorTokens.divider)
                .frame(height: 0.5)

            // Column headers — axis labels for a table of readings, so the ANNOTATION voice at
            // the axis size (v6). Case, tracking and the CJK guard belong to `AnnotationLabel`.
            HStack {
                AnnotationLabel(key: "table.header.set", size: .small)
                    .frame(width: 32, alignment: .leading)
                AnnotationLabel(key: "table.header.weight", size: .small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                AnnotationLabel(key: "table.header.reps", size: .small)
                    .frame(width: 48, alignment: .leading)
                AnnotationLabel(key: "table.header.rpe", size: .small)
                    .frame(width: 40, alignment: .trailing)
                AnnotationLabel(key: "table.header.volume", size: .small)
                    .frame(width: 56, alignment: .trailing)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)

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
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)

                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)
            }

            if entry.totalVolume > 0 {
                HStack {
                    Spacer()
                    Text(String(format: String(localized: "exercise.totalVolume", defaultValue: "Total: %.0f kg"), entry.totalVolume))
                        .font(.Tokens.labelMedium)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.text1)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
            }
        }
        .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.card))
        .clipShape(RoundedRectangle(cornerRadius: CornerTokens.card))
        .overlay(RoundedRectangle(cornerRadius: CornerTokens.card).stroke(ColorTokens.divider, lineWidth: 0.5))
    }
}
