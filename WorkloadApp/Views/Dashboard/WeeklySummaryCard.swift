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
                        metricCell(index: 1, title: "weekly.summary.metric.sessions", value: "\(summary.sessionCount)", delta: summary.sessionCountDelta)
                        metricCell(index: 2, title: "weekly.summary.metric.volume", value: String(format: "%.0f", summary.totalVolume), delta: summary.volumeDelta)
                    }
                    .padding(.horizontal, Spacing.sm)

                    // Row 2: Avg Recovery + Load Trend (2-column)
                    HStack(spacing: Spacing.sm) {
                        metricCell(index: 3, title: "weekly.summary.metric.avgRecovery", value: String(format: "%.0f", summary.avgRecoveryScore), delta: summary.recoveryDelta)
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
    ///
    /// `title` is a `LocalizedStringKey` on the `AnnotationLabel(key:)` path, not a call-site
    /// `String(localized:)`: the literal path reads the **process** locale and keeps the launch
    /// language until restart, so these three keys stayed English after an in-app switch while
    /// the two sibling keys in this same card (`key:`) switched immediately.
    private func metricCell(index: Int, title: LocalizedStringKey, value: String, delta: Double) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            AnnotationLabel(key: title, size: .small)
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

/// Inline zone badge for weekly distribution display — the same object `ZoneBadge` is, so it
/// wears the same engraving (Wave 3, REQ from the Wave 2 record).
///
/// Three things changed from the pre-v6 version, all of them law rather than taste:
///
/// 1. **Card-plane backing.** It filled itself with `background` (the BASE plane), where
///    `zone-optimal` measures 4.39:1 and `metric-load` 4.49:1 — under the 4.5:1 small-text floor
///    (DESIGN.md:201; those two are the only sub-floor pairs. `zone-caution` #8A5C08 on #F0EFEC
///    is ≈5.05:1 — an earlier revision of this comment mis-attributed the 4.49:1 figure to it).
///    `ZoneBadge` solves this by carrying its own `surfaceEl2` capsule instead
///    of trusting the plane beneath it (all nine v6 colors clear 4.5:1 there); this now does the
///    same, so the badge is legal wherever it is dropped rather than legal by luck.
/// 2. **The zone name takes its zone's color, and the hairline follows it** — the badge grammar
///    in DESIGN.md v6 is text + hairline capsule, never a fill. State is still carried by the
///    LABEL first (`Optimal` / `Caution`); the hue is supplementary, never the only channel
///    (rule 6). Previously the chip was uniform `text2`, so four adjacent zones read identically
///    and the distribution had no state channel at all.
/// 3. **Micro-caps at micro size**, Latin-only (`isLatin`) — 15pt `label` was a size step above
///    every other badge in the app. Tracking is **0.9**, the value DESIGN.md:66 and
///    `FontTokens.swift:139` both specify for `micro`; `ZoneBadge` (`MetricTile.swift:75`) still
///    carries a hand-typed 1.2, which is a pre-existing deviation in a file this lane does not
///    own. Copying it here to "match" would have propagated the deviation, so this badge follows
///    the token and `ZoneBadge` is left flagged rather than quietly diverged from.
///
/// The count stays a working-voice tabular numeral in ink: it is the chip's DATA, and annotation
/// is marginalia, not the reading it annotates.
private struct WeeklyZoneBadge: View {
    @Environment(\.locale) private var locale
    let zone: ACWRZone
    let count: Int

    private var isLatin: Bool { locale.language.languageCode?.identifier != "zh" }

    var body: some View {
        HStack(spacing: Spacing.baselinePair) {
            Text(zone.displayName)
                .font(.Tokens.micro)
                .tracking(isLatin ? 0.9 : 0)
                .textCase(isLatin ? .uppercase : nil)
                .foregroundStyle(ColorTokens.acwrZoneColor(zone))
            Text("\(count)")
                .font(.Tokens.micro)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text1)
        }
        .padding(.horizontal, isLatin ? Spacing.xs : Spacing.sm)
        .padding(.vertical, Spacing.baselinePair)
        // v3 Corner Law: chips are pills.
        .background(ColorTokens.surfaceEl2, in: Capsule())
        .overlay(Capsule().stroke(ColorTokens.acwrZoneColor(zone), lineWidth: 0.5))
    }
}
