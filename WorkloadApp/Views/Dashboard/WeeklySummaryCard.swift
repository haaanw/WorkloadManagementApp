import SwiftUI

/// Collapsible weekly training summary card (D-03).
/// Shows sessions, volume, avg recovery, load trend, ACWR zone distribution with week-over-week deltas.
struct WeeklySummaryCard: View {
    let summary: AnalyticsEngine.WeeklySummary
    let streak: Int
    @AppStorage("weeklySummaryExpanded") private var storedExpanded: Bool = true
    @State private var isExpanded: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row (tappable to collapse)
            Button {
                Haptics.tap()
                withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                    isExpanded.toggle()
                    storedExpanded = isExpanded
                }
            } label: {
                HStack {
                    // A period stamp ("THIS WEEK") is marginalia, not a headline —
                    // annotation voice (DESIGN.md v6: timestamps and cycle position).
                    AnnotationLabel(key: "weekly.summary.header", size: .small)
                        .annotationReveal()
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.Tokens.micro)
                        .foregroundStyle(ColorTokens.text3)
                        .rotationEffect(.degrees(isExpanded ? 0 : -180))
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.pressable(scale: 1, opacity: 0.6))

            if isExpanded {
                VStack(spacing: Spacing.sm) {
                    // Streak row (STRK-01, STRK-02, D-01, D-02)
                    if streak > 0 {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "flame.fill")
                                .font(.Tokens.smallLabel)
                                .foregroundStyle(ColorTokens.text2)
                                .accessibilityHidden(true)
                            Text("\(streak)")
                                .font(.Tokens.smallLabelMedium)
                                .monospacedDigit()
                                .foregroundStyle(ColorTokens.text1)
                            Text("weekly.summary.streak.label")
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text2)
                        }
                        .padding(.horizontal, Spacing.sm)
                        .accessibilityLabel("\(streak) week training streak")
                    }

                    // Row 1: Sessions + Volume (2-column)
                    HStack(spacing: Spacing.sm) {
                        metricCell(index: 1, title: String(localized: "weekly.summary.metric.sessions", defaultValue: "SESSIONS"), value: "\(summary.sessionCount)", delta: summary.sessionCountDelta)
                        metricCell(index: 2, title: String(localized: "weekly.summary.metric.volume", defaultValue: "VOLUME"), value: String(format: "%.0f", summary.totalVolume), delta: summary.volumeDelta)
                    }
                    .padding(.horizontal, Spacing.sm)

                    // Row 2: Avg Recovery + Load Trend (2-column)
                    HStack(spacing: Spacing.sm) {
                        metricCell(index: 3, title: String(localized: "weekly.summary.metric.avgRecovery", defaultValue: "AVG RECOVERY"), value: String(format: "%.0f", summary.avgRecoveryScore), delta: summary.recoveryDelta)
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            AnnotationLabel(key: "weekly.summary.metric.loadTrend", size: .small)
                                .annotationReveal(index: 4)
                            Text(summary.loadTrendDirection.rawValue.capitalized)
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, Spacing.sm)

                    // Row 3: ACWR Zone Distribution
                    if !summary.acwrZoneDistribution.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            AnnotationLabel(key: "weekly.summary.metric.zoneDistribution", size: .small)
                                .annotationReveal(index: 5)
                            HStack(spacing: Spacing.xs) {
                                ForEach(sortedZones, id: \.self) { zone in
                                    WeeklyZoneBadge(zone: zone, count: summary.acwrZoneDistribution[zone, default: 0])
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.sm)
                    }
                }
                .padding(.bottom, Spacing.sm)
                .transition(.opacity)
            }
        }
        .cardStyle(horizontalPadding: 0, verticalPadding: 0)
        .onAppear { isExpanded = storedExpanded }
    }

    /// Ordered zones for display (excluding noData, only those with count > 0).
    private var sortedZones: [ACWRZone] {
        let order: [ACWRZone] = [.undertrained, .optimal, .caution, .danger]
        return order.filter { summary.acwrZoneDistribution[$0, default: 0] > 0 }
    }

    /// A weekly metric key + reading. The key is a machine label (annotation voice); the
    /// reading stays working-voice with tabular digits, and the delta comes from the shared
    /// `DeltaIndicator` (Session D owns its restyle — this lane consumes it).
    private func metricCell(index: Int, title: String, value: String, delta: Double) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            AnnotationLabel(title, size: .small)
                .annotationReveal(index: index)
            HStack(spacing: Spacing.xs) {
                Text(value)
                    .font(.Tokens.smallLabelMedium)
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.text1)
                DeltaIndicator(delta: delta)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Zone Distribution Badge

/// Inline zone badge for weekly distribution display.
private struct WeeklyZoneBadge: View {
    let zone: ACWRZone
    let count: Int

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(zone.displayName)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
            Text("\(count)")
                .font(.Tokens.label)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text1)
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xs)
        // v3 Corner Law: chips are pills.
        .background(ColorTokens.background, in: Capsule())
        .overlay(Capsule().stroke(ColorTokens.divider, lineWidth: 0.5))
    }
}
