import SwiftUI
import Charts

// Shared trend/history sections, moved here verbatim from the retired tab files with the
// Trends merge (v1.7.3 reorientation slice 3): `LoadTrendChartView` + `PRHistorySection`
// from `WorkloadView.swift`, `WellnessHistorySection` from `RecoveryView.swift`.
//
// The three sections at the top of this file are new with the v1.7.3 re-scope (UAT round 1 ·
// U9): the fatigue hero, the load read, and the activity read. Everything below them is
// carried over unchanged.

// MARK: - Range rail

/// The page's spine: 1 week / 2 weeks / 1 month.
///
/// Shaped as a RAIL rather than a segmented control, matching the Log tab's
/// `SessionTypeFilterBar` — it sits in the same place on the screen and does the same job, and
/// two filter rails one tab apart that look different is the kind of drift this release is
/// closing. The active item takes an INK underline: v5 gives chrome selection to ink and keeps
/// travertine for live-state marks.
///
/// (`Components/TimeRangeSegmentedControl.swift` was this control's previous form and now has
/// no caller. Left in place rather than deleted — removing a file is a `.pbxproj` edit, which
/// is serialized across lanes.)
struct TrendsRangeRail: View {
    @Binding var selected: TimeRange
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases) { range in
                Button {
                    guard selected != range else { return }
                    Haptics.select()
                    withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                        selected = range
                    }
                } label: {
                    Text(range.label)
                        .font(selected == range ? .Tokens.smallLabelMedium : .Tokens.smallLabel)
                        .foregroundStyle(selected == range ? ColorTokens.text1 : ColorTokens.text2)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .overlay(alignment: .bottom) {
                            if selected == range {
                                Rectangle()
                                    .fill(ColorTokens.text1)
                                    .frame(height: 1.5)
                                    .padding(.horizontal, Spacing.sm)
                            }
                        }
                }
                .buttonStyle(.pressable)
                .accessibilityAddTraits(selected == range ? [.isButton, .isSelected] : .isButton)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.sm)
        .frame(height: 40)
        .background(ColorTokens.background)
        .accessibilityIdentifier("trends.rangeRail")
    }
}

// MARK: - Door caret

/// The `text3` caret that marks a card as a DOOR (UAT round 3 · U20).
///
/// The same mark `MetricCell.indicatesNavigation` puts on Today's three body-signal plates, and
/// for the same reason: a surface that navigates with no mark reads as a readout. It sits in the
/// hero row beside the zone capsule rather than in the plate's corner, because the capsule is
/// already there and two marks in one corner read as a collision.
private struct CardDoorCaret: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.Tokens.smallLabel)
            .foregroundStyle(ColorTokens.text3)
            .accessibilityHidden(true)
    }
}

// MARK: - Fatigue (the page's hero)

/// Accumulated fatigue across the window: the index as a hero reading in the load hue, its zone
/// as a hairline capsule, the accumulation chart, one trajectory sentence in the working voice,
/// and the engine's own component decomposition as an annotation reason tree.
///
/// ## Claim rails (U9, HAN)
///
/// Everything this section says is a DESCRIPTION of values the app already holds: where the
/// index started and where it is now, how many recent days it has not come down, and what the
/// six component scores were. It never names an injury risk, never forecasts, and never
/// prescribes — Trends describes, and the day's proposal on Today decides. Under
/// `FatigueHistoryEngine.minimumHistoryDays` it draws no chart and says how much history it has
/// instead of guessing.
struct TrendsFatigueSection: View {
    let points: [FatigueHistoryEngine.Point]
    let trajectory: FatigueHistoryEngine.Trajectory?
    let daysWithoutRelief: Int
    let observedHistoryDays: Int
    let hasEnoughHistory: Bool
    let rangeDays: Int
    /// Where the card leads. The whole card is a DOOR (UAT round 3 · U20): the explanations
    /// used to sit under it as eleven collapsed rows, which cost the page more height than the
    /// hero itself. They moved to `FatigueDetailScreen`, and this is the way in.
    let destination: TrendDestination

    @Environment(\.locale) private var locale

    private var latest: FatigueHistoryEngine.Point? { points.last }

    var body: some View {
        // Primitive 2 (Row): a well on press, no scale — a surface that navigates, not a key
        // that commits. The same treatment Today's metric cells carry, so the two tabs press
        // alike. Nothing inside this card takes a gesture of its own, so the whole plate can be
        // the tap target (the load card below cannot say the same — its plot scrubs).
        NavigationLink(value: destination) {
            card
        }
        .buttonStyle(.rowWell(cornerRadius: CornerTokens.card))
        .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasEnoughHistory, let latest {
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        // The hero reading, in the LOAD hue. `displayAction` is 32pt — the
                        // floor at which DESIGN.md allows a hue-coloured reading on any plane
                        // — and it sits on the hero card anyway (Reading Color Rule v6).
                        Text("\(Int(latest.index.rounded()))")
                            .font(.Tokens.displayAction)
                            .monospacedDigit()
                            .foregroundStyle(ColorTokens.metricLoad)
                        AnnotationLabel(key: "trends.fatigue.unit", size: .small)
                            .annotationReveal()
                    }
                    Spacer()
                    // Text label first, colour supplementary — the Zone Color Rule. A hairline
                    // capsule, never a fill.
                    ZoneBadge(
                        label: Self.zoneLabel(latest.zone, locale: locale),
                        color: ColorTokens.fatigueZoneColor(latest.zone)
                    )
                    CardDoorCaret()
                }

                // (U16) The plain-language reading, directly under the hero: number, then what
                // the number means, then the plot. Working voice — a sentence is never
                // annotation. It composes zone + trajectory, both DESCRIPTIONS of stored
                // values, and for anything above Low it points at the one surface that
                // actually decides.
                Text(Self.fatigueReading(
                    zone: latest.zone,
                    trajectory: Self.readingTrajectory(points: points, trajectory: trajectory),
                    locale: locale
                ))
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.sm)

                FatigueAccumulationChart(points: points)

                Text(trajectorySentence)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.sm)

                VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                    ForEach(Array(componentRows.enumerated()), id: \.offset) { index, row in
                        AnnotationLabel(row, size: .small)
                            .annotationReveal(index: index)
                    }
                }
                .padding(.top, Spacing.sm)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(
                        format: LocalePinnedStrings.localized("trends.fatigue.empty", locale: locale),
                        observedHistoryDays,
                        FatigueHistoryEngine.minimumHistoryDays
                    ))
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
                    // The door stands even with no series: what the index IS is exactly what an
                    // athlete who cannot see one yet wants to read.
                    CardDoorCaret()
                }
            }
        }
        // The one card on this page that takes the area's 4% wash.
        .cardStyle(isHero: true)
        .accessibilityIdentifier("trends.fatigue")
    }

    /// The window's story in one or two sentences, both readings of stored values.
    private var trajectorySentence: String {
        Self.trajectorySentence(
            points: points,
            trajectory: trajectory,
            daysWithoutRelief: daysWithoutRelief,
            rangeDays: rangeDays,
            locale: locale
        )
    }

    /// The same two sentences, for any surface that draws the same series — the card and the
    /// detail screen both say where the window started and where it ended.
    static func trajectorySentence(
        points: [FatigueHistoryEngine.Point],
        trajectory: FatigueHistoryEngine.Trajectory?,
        daysWithoutRelief: Int,
        rangeDays: Int,
        locale: Locale
    ) -> String {
        guard let first = points.first, let latest = points.last else { return "" }
        let from = Int(first.index.rounded())
        let to = Int(latest.index.rounded())

        // A steady window gets its own sentence rather than "moved from 48 to 49" — the number
        // did not move, and saying it did would be a claim the series does not support.
        var sentence: String
        if trajectory == .steady {
            sentence = String(
                format: LocalePinnedStrings.localized("trends.fatigue.sentence.held", locale: locale),
                to, rangeDays
            )
        } else {
            sentence = String(
                format: LocalePinnedStrings.localized("trends.fatigue.sentence.moved", locale: locale),
                from, to, rangeDays
            )
        }

        if daysWithoutRelief > 0 {
            sentence += " " + String(
                format: LocalePinnedStrings.localized("trends.fatigue.sentence.noRelief", locale: locale),
                daysWithoutRelief
            )
        }
        return sentence
    }

    /// The engine's own six components, complete. All six rather than the movers only: a
    /// partial decomposition would misreport what built the number.
    ///
    /// The names are resolved from LITERAL keys, not from a `[String]` of key names — a runtime
    /// string cannot be a `String.LocalizationValue`, and the paired arrays keep the six names
    /// and the six scores in one visible order.
    private var componentRows: [String] {
        guard let components = latest?.components else { return [] }
        return Self.componentRows(components: components, names: Self.componentNames(locale: locale))
    }

    /// The six component names the CARD prints — short, because the card has one line per
    /// component and no room to say more.
    static func componentNames(locale: Locale) -> [String] {
        [
            LocalePinnedStrings.localized("trends.fatigue.component.loadElevation", locale: locale),
            LocalePinnedStrings.localized("trends.fatigue.component.sessionDensity", locale: locale),
            LocalePinnedStrings.localized("trends.fatigue.component.restDebt", locale: locale),
            LocalePinnedStrings.localized("trends.fatigue.component.recoveryTrend", locale: locale),
            LocalePinnedStrings.localized("trends.fatigue.component.wellnessTrend", locale: locale),
            LocalePinnedStrings.localized("trends.fatigue.component.softTissue", locale: locale)
        ]
    }

    /// The same six names as the DETAIL screen prints them, each carrying the engine's own
    /// weight. Resolved from the About titles, so the weights are authored in exactly one place
    /// and the tree can never disagree with the explanation beside it.
    static func componentWeightedNames(locale: Locale) -> [String] {
        [
            LocalePinnedStrings.localized("trends.meaning.about.fatigue.component.loadElevation.title", locale: locale),
            LocalePinnedStrings.localized("trends.meaning.about.fatigue.component.sessionDensity.title", locale: locale),
            LocalePinnedStrings.localized("trends.meaning.about.fatigue.component.restDebt.title", locale: locale),
            LocalePinnedStrings.localized("trends.meaning.about.fatigue.component.recoveryTrend.title", locale: locale),
            LocalePinnedStrings.localized("trends.meaning.about.fatigue.component.wellnessTrend.title", locale: locale),
            LocalePinnedStrings.localized("trends.meaning.about.fatigue.component.softTissue.title", locale: locale)
        ]
    }

    /// The stemmed annotation rows for a set of component scores, in the engine's order.
    ///
    /// Static and name-parameterised because two surfaces print the same six rows with two name
    /// forms: the card's short names, and the detail screen's weighted ones. The arithmetic and
    /// the stem live here once.
    static func componentRows(
        components: FatigueIndexEngine.FatigueResult,
        names: [String]
    ) -> [String] {
        let scores = [
            components.loadElevation,
            components.sessionDensity,
            components.restDebt,
            components.recoveryTrend,
            components.wellnessTrend,
            components.softTissueRisk
        ]
        return zip(names, scores).enumerated().map { index, row in
            let branch = index == names.count - 1 ? "\u{2514}\u{2500}" : "\u{251C}\u{2500}"
            return "\(branch) \(row.0) \(componentGlyph(row.1)) \(Int((row.1 * 100).rounded()))"
        }
    }

    /// `▲` above the neutral 0.5, `▼` below it, `●` at it — DESIGN.md's glyph set. Ink, never a
    /// zone colour: a component above neutral is a reading, not a diagnosis.
    private static func componentGlyph(_ score: Double) -> String {
        if score > 0.55 { return "\u{25B2}" }
        if score < 0.45 { return "\u{25BC}" }
        return "\u{25CF}"
    }

    // MARK: - Meaning layer (UAT round 2 · U16)

    /// Index points of first-to-last movement below which a window reads as level rather than
    /// as climbing or coming down. Two points is inside the day-to-day jitter of the component
    /// scores, so calling that a direction would be reporting noise as a trend.
    static let readingDeadBand: Double = 2

    /// The window's direction, for the reading only.
    ///
    /// The engine's own slope classification is preferred when it has one — it fits every point
    /// rather than two. Below the two points a slope needs, first-versus-last with the dead band
    /// above stands in, so the reading is never silently missing its second clause.
    static func readingTrajectory(
        points: [FatigueHistoryEngine.Point],
        trajectory: FatigueHistoryEngine.Trajectory?
    ) -> FatigueHistoryEngine.Trajectory {
        if let trajectory { return trajectory }
        guard let first = points.first, let last = points.last else { return .steady }
        let delta = last.index - first.index
        if delta > readingDeadBand { return .rising }
        if delta < -readingDeadBand { return .falling }
        return .steady
    }

    /// One plain-language reading of the hero: what the zone means, which way the window went,
    /// and — above Low only — where the decision actually gets made.
    ///
    /// ## Claim rails (U16, HAN)
    ///
    /// Every clause describes values the app already holds. None of them names an injury, none
    /// of them says what happens next, none of them prescribes, and none of them calls any part
    /// of the scale a safe range. Trends describes; Today decides.
    static func fatigueReading(
        zone: FatigueIndexEngine.FatigueZone,
        trajectory: FatigueHistoryEngine.Trajectory,
        locale: Locale
    ) -> String {
        var reading = zoneReading(zone, locale: locale)
        reading += " " + trajectoryClause(trajectory, locale: locale)
        if zone != .low {
            reading += " " + LocalePinnedStrings.localized("trends.meaning.fatigue.pointer", locale: locale)
        }
        return reading
    }

    /// What the zone means, in words an athlete who has never met the index can act on.
    static func zoneReading(_ zone: FatigueIndexEngine.FatigueZone, locale: Locale) -> String {
        switch zone {
        case .low:        LocalePinnedStrings.localized("trends.meaning.fatigue.zone.low", locale: locale)
        case .elevated:   LocalePinnedStrings.localized("trends.meaning.fatigue.zone.elevated", locale: locale)
        case .high:       LocalePinnedStrings.localized("trends.meaning.fatigue.zone.high", locale: locale)
        case .saturation: LocalePinnedStrings.localized("trends.meaning.fatigue.zone.veryHigh", locale: locale)
        }
    }

    /// Which way the window went, as the reading's second clause.
    static func trajectoryClause(_ trajectory: FatigueHistoryEngine.Trajectory, locale: Locale) -> String {
        switch trajectory {
        case .rising:  LocalePinnedStrings.localized("trends.meaning.fatigue.trajectory.rising", locale: locale)
        case .steady:  LocalePinnedStrings.localized("trends.meaning.fatigue.trajectory.steady", locale: locale)
        case .falling: LocalePinnedStrings.localized("trends.meaning.fatigue.trajectory.falling", locale: locale)
        }
    }

    /// The collapsed explanation set: what the index is, how its bands are cut, what kind of
    /// scale it is, what moves it, and how to read the tree's glyphs.
    ///
    /// It lives on `FatigueDetailScreen` now, not on the card (UAT round 3 · U20). The six
    /// per-component explanations left this list at the same time — see `componentAboutItems`.
    static let aboutItems: [DetailDisclosureItem] = [
        DetailDisclosureItem(
            titleKey: "trends.meaning.about.fatigue.what.title",
            bodyKey: "trends.meaning.about.fatigue.what.body"
        ),
        DetailDisclosureItem(
            titleKey: "trends.meaning.about.fatigue.cutpoints.title",
            bodyKey: "trends.meaning.about.fatigue.cutpoints.body"
        ),
        DetailDisclosureItem(
            titleKey: "trends.meaning.about.fatigue.absolute.title",
            bodyKey: "trends.meaning.about.fatigue.absolute.body"
        ),
        DetailDisclosureItem(
            titleKey: "trends.meaning.about.fatigue.moves.title",
            bodyKey: "trends.meaning.about.fatigue.moves.body"
        ),
        DetailDisclosureItem(
            titleKey: "trends.meaning.about.fatigue.glyphs.title",
            bodyKey: "trends.meaning.about.fatigue.glyphs.body"
        )
    ]

    /// One explanation per component, in the order the tree prints them, each carrying the
    /// engine's own weight in its title.
    ///
    /// Held apart from `aboutItems` because the detail screen does not COLLAPSE these: it
    /// prints each one under the component row it explains, which is what "expand the tree"
    /// means. Two copies of the same six sentences on one page would be worse than none.
    static let componentAboutItems: [DetailDisclosureItem] = [
        DetailDisclosureItem(
            titleKey: "trends.meaning.about.fatigue.component.loadElevation.title",
            bodyKey: "trends.meaning.about.fatigue.component.loadElevation.body"
        ),
        DetailDisclosureItem(
            titleKey: "trends.meaning.about.fatigue.component.sessionDensity.title",
            bodyKey: "trends.meaning.about.fatigue.component.sessionDensity.body"
        ),
        DetailDisclosureItem(
            titleKey: "trends.meaning.about.fatigue.component.restDebt.title",
            bodyKey: "trends.meaning.about.fatigue.component.restDebt.body"
        ),
        DetailDisclosureItem(
            titleKey: "trends.meaning.about.fatigue.component.recoveryTrend.title",
            bodyKey: "trends.meaning.about.fatigue.component.recoveryTrend.body"
        ),
        DetailDisclosureItem(
            titleKey: "trends.meaning.about.fatigue.component.wellnessTrend.title",
            bodyKey: "trends.meaning.about.fatigue.component.wellnessTrend.body"
        ),
        DetailDisclosureItem(
            titleKey: "trends.meaning.about.fatigue.component.softTissue.title",
            bodyKey: "trends.meaning.about.fatigue.component.softTissue.body"
        )
    ]

    /// The zone in words. `FatigueZone.displayName` is an untranslated English literal used for
    /// diagnostics; a badge an athlete reads takes a localized key.
    static func zoneLabel(_ zone: FatigueIndexEngine.FatigueZone, locale: Locale) -> String {
        switch zone {
        case .low:        LocalePinnedStrings.localized("trends.fatigue.zone.low", locale: locale)
        case .elevated:   LocalePinnedStrings.localized("trends.fatigue.zone.elevated", locale: locale)
        case .high:       LocalePinnedStrings.localized("trends.fatigue.zone.high", locale: locale)
        case .saturation: LocalePinnedStrings.localized("trends.fatigue.zone.veryHigh", locale: locale)
        }
    }
}

/// The accumulation plot: one line, in the load hue, over the window.
///
/// **No area fill under the line**, and that is deliberate rather than an omission. The gated
/// demo draws one; DESIGN.md forbids a metric hue as a plane fill outright, and this app already
/// held that line once — `HRVDetailChart` documents refusing a hue-filled ±1SD band for the same
/// reason, and `LoadTrendChartView`'s TSB wash uses the identity-less `chartTSB` ink to stay
/// inside the rule. A line carries the accumulation on its own.
struct FatigueAccumulationChart: View {
    @Environment(\.locale) private var locale
    let points: [FatigueHistoryEngine.Point]

    /// Days the series spans — the axis stride has to be computed, because the rail changes it.
    private var spanDays: Int {
        guard let first = points.first?.day, let last = points.last?.day else { return 1 }
        return max(1, Calendar.current.dateComponents([.day], from: first, to: last).day ?? 1)
    }

    var body: some View {
        Chart {
            ForEach(points, id: \.day) { point in
                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Fatigue", point.index)
                )
                .foregroundStyle(ColorTokens.metricLoad)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
        }
        .frame(height: 120)
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: ChartAxisTicks.dayStride(spanningDays: spanDays))) { value in
                AxisGridLine().foregroundStyle(ColorTokens.chartGrid)
                AxisTick().foregroundStyle(ColorTokens.chartGrid)
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        AnnotationLabel(
                            date.formatted(.dateTime.month(.abbreviated).day().locale(locale)),
                            size: .small
                        )
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: ChartAxisTicks.yAxisStops)) { value in
                AxisGridLine().foregroundStyle(ColorTokens.chartGrid)
                AxisValueLabel {
                    if let index = value.as(Double.self) {
                        AnnotationLabel(String(format: "%.0f", index), size: .small)
                    }
                }
            }
        }
        .id(locale)
        .padding(.top, Spacing.sm)
        .entranceReveal()
    }
}

// MARK: - Load

/// Acute ÷ chronic over the window, with the range the athlete has actually held stated in
/// words. The held range is a SENTENCE rather than the demo's shaded band: a zone-hued band
/// behind a plot is a hue dressing a surface, and a range is unambiguous stated.
struct TrendsLoadSection: View {
    let snapshot: WorkloadSnapshot?
    let acwrRange: (low: Double, high: Double)?
    let trendSnapshots: [WorkloadSnapshot]
    @Binding var selectedTrendDate: Date?
    /// Where the hero leads (UAT round 3 · U20).
    let destination: TrendDestination

    @Environment(\.locale) private var locale

    var body: some View {
        card
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            if snapshot != nil {
                // The DOOR is the hero block, not the whole plate: the plot below it scrubs, and
                // a card-wide button would eat the scrub's taps. So the reading navigates and the
                // chart keeps its gesture.
                NavigationLink(value: destination) {
                    hero
                }
                .buttonStyle(.rowWell(cornerRadius: CornerTokens.control))
                .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
            }

            if trendSnapshots.count > 1 {
                LoadTrendChartView(snapshots: trendSnapshots, selectedDate: $selectedTrendDate)
                    .padding(.top, Spacing.sm)
            } else {
                // Say WHY there is no chart (v1.7.2 / audit M10) — a young history, not a
                // rendering failure.
                Text("workload.chart.insufficientData")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(.top, Spacing.sm)
            }

            if let sentence = loadSentence {
                Text(sentence)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.sm)
            }
        }
        .cardStyle()
        .accessibilityIdentifier("trends.loadTrend")
    }

    /// The ratio, its zone and what the ratio means — the block that navigates.
    @ViewBuilder
    private var hero: some View {
        if let snapshot {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text(String(format: "%.2f", snapshot.acwr))
                            .font(.Tokens.displayAction)
                            .monospacedDigit()
                            .foregroundStyle(ColorTokens.text1)
                        AnnotationLabel(key: "trends.load.unit", size: .small)
                            .annotationReveal()
                    }
                    Spacer()
                    ZoneBadge(
                        label: snapshot.zone.displayName,
                        color: ColorTokens.acwrZoneColor(snapshot.zone)
                    )
                    CardDoorCaret()
                }

                // (U16) What the ratio means, under the ratio. `LOAD STEADY` is a label; this
                // says what the label is a label FOR.
                Text(Self.loadReading(snapshot.zone, locale: locale))
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.sm)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Meaning layer (UAT round 2 · U16)

    /// What the acute-to-chronic ratio means in words. Each sentence compares the last week with
    /// the month behind it and stops there: no injury claim, no forecast, no prescription, and
    /// no band called safe — 0.8–1.3 is described as a CONTINUATION of work already done, which
    /// is what the arithmetic actually supports.
    static func loadReading(_ zone: ACWRZone, locale: Locale) -> String {
        switch zone {
        case .undertrained: LocalePinnedStrings.localized("trends.meaning.load.light", locale: locale)
        case .optimal:      LocalePinnedStrings.localized("trends.meaning.load.steady", locale: locale)
        case .caution:      LocalePinnedStrings.localized("trends.meaning.load.building", locale: locale)
        case .danger:       LocalePinnedStrings.localized("trends.meaning.load.high", locale: locale)
        case .noData:       LocalePinnedStrings.localized("trends.meaning.load.noData", locale: locale)
        }
    }

    /// The collapsed explanation set: the ratio the two loads form, and where it is cut.
    ///
    /// It lives on `LoadDetailScreen` now (UAT round 3 · U20). The three per-load explanations
    /// left this list at the same time — see `componentAboutItems`.
    static let aboutItems: [DetailDisclosureItem] = [
        DetailDisclosureItem(
            titleKey: "trends.meaning.about.load.ratio.title",
            bodyKey: "trends.meaning.about.load.ratio.body"
        ),
        DetailDisclosureItem(
            titleKey: "trends.meaning.about.load.cutpoints.title",
            bodyKey: "trends.meaning.about.load.cutpoints.body"
        )
    ]

    /// One explanation per load, in the order the detail screen's tree prints them: acute,
    /// chronic, and the balance between them. Printed UNDER their rows rather than collapsed, so
    /// the number and the sentence that defines it stand together.
    static let componentAboutItems: [DetailDisclosureItem] = [
        DetailDisclosureItem(
            titleKey: "trends.meaning.about.load.acute.title",
            bodyKey: "trends.meaning.about.load.acute.body"
        ),
        DetailDisclosureItem(
            titleKey: "trends.meaning.about.load.chronic.title",
            bodyKey: "trends.meaning.about.load.chronic.body"
        ),
        DetailDisclosureItem(
            titleKey: "trends.detail.load.tsb.title",
            bodyKey: "trends.meaning.about.load.terms.body"
        )
    ]

    /// The three stemmed annotation rows the detail screen's tree prints: each load's own name,
    /// the machine abbreviation the plot keys it by, and its stored value.
    ///
    /// ATL / CTL / TSB are untranslated scientific abbreviations — the same ones the series key
    /// under the plot already prints — so they are literals here, exactly as they are there.
    static func loadRows(acute: Double, chronic: Double, tsb: Double, locale: Locale) -> [String] {
        let names = [
            LocalePinnedStrings.localized("trends.meaning.about.load.acute.title", locale: locale),
            LocalePinnedStrings.localized("trends.meaning.about.load.chronic.title", locale: locale),
            LocalePinnedStrings.localized("trends.detail.load.tsb.title", locale: locale)
        ]
        let keys = ["ATL", "CTL", "TSB"]
        let values = [acute, chronic, tsb]

        return zip(zip(names, keys), values).enumerated().map { index, row in
            let branch = index == names.count - 1 ? "\u{2514}\u{2500}" : "\u{251C}\u{2500}"
            return "\(branch) \(row.0.0) · \(row.0.1) \(String(format: "%.0f", row.1))"
        }
    }

    /// A ratio and its own history — both readings of stored values.
    private var loadSentence: String? {
        guard let snapshot else { return nil }
        var sentence = String(
            format: LocalePinnedStrings.localized("trends.load.sentence", locale: locale),
            String(format: "%.2f", snapshot.acwr)
        )
        if let acwrRange, acwrRange.high > acwrRange.low {
            sentence += " " + String(
                format: LocalePinnedStrings.localized("trends.load.sentence.heldRange", locale: locale),
                String(format: "%.2f", acwrRange.low),
                String(format: "%.2f", acwrRange.high)
            )
        }
        return sentence
    }
}

// MARK: - What you did

/// Sessions across the window against the athlete's OWN average, one bar per day. Counts and
/// stored training-stress values only — no comparison to anybody else, and no judgement.
struct TrendsWhatYouDidSection: View {
    let sessionCount: Int
    let baselineSessions: Double?
    let bars: [(date: Date, load: Double)]
    let typeCounts: [(type: SessionType, count: Int)]
    let rangeDays: Int

    @Environment(\.locale) private var locale

    var body: some View {
        card
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text("\(sessionCount)")
                    .font(.Tokens.displayAction)
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.text1)
                AnnotationLabel(
                    String(
                        format: LocalePinnedStrings.localized("trends.activity.unit", locale: locale),
                        rangeDays
                    ),
                    size: .small
                )
                .annotationReveal()
            }

            if sessionCount > 0 {
                // (U16) The count is the only number on this card that a non-expert cannot place.
                // One line ties it to the number the page opened with.
                Text(Self.activityReading(locale: locale))
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.sm)

                DailyLoadBars(bars: bars)

                if let sentence = baselineSentence {
                    Text(sentence)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Spacing.sm)
                }

                if !typeCounts.isEmpty {
                    AnnotationLabel(breakdown, size: .small)
                        .annotationReveal(index: 1)
                        .padding(.top, Spacing.baselinePair)
                }
            } else {
                Text("trends.activity.empty")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(.top, Spacing.sm)
            }
        }
        .cardStyle()
        .accessibilityIdentifier("trends.activity")
    }

    // MARK: - Meaning layer (UAT round 2 · U16)

    /// The one line that ties the session count to the fatigue hero above it. A statement of
    /// where the number upstream came from — not a judgement of the count.
    static func activityReading(locale: Locale) -> String {
        LocalePinnedStrings.localized("trends.meaning.activity", locale: locale)
    }

    /// The collapsed explanation set: what a bar is, and whose average the comparison uses.
    ///
    /// This card carries no list of its own any more (UAT round 3 · U20). The two items ride the
    /// LOAD detail screen under a "what you did" head — the bars ARE the load the ratio is built
    /// from, so that is where a reader who wants them is already standing.
    static let aboutItems: [DetailDisclosureItem] = [
        DetailDisclosureItem(
            titleKey: "trends.meaning.about.activity.bars.title",
            bodyKey: "trends.meaning.about.activity.bars.body"
        ),
        DetailDisclosureItem(
            titleKey: "trends.meaning.about.activity.average.title",
            bodyKey: "trends.meaning.about.activity.average.body"
        )
    ]

    private var baselineSentence: String? {
        guard let baselineSessions else { return nil }
        return String(
            format: LocalePinnedStrings.localized("trends.activity.sentence.baseline", locale: locale),
            rangeDays,
            String(format: "%.0f", baselineSessions.rounded())
        )
    }

    /// `STRENGTH 5 · SKILL 3 · CONDITIONING 1` — counts, in the annotation voice. The type
    /// names come from the enum's own display names, so the key set never drifts from it.
    private var breakdown: String {
        typeCounts
            .map { "\($0.type.displayName) \($0.count)" }
            .joined(separator: " \u{00B7} ")
    }
}

/// One bar per day of the window: that day's summed training stress. Rest days are drawn as
/// present-and-zero, so the rhythm of a week reads off the plot rather than being inferred from
/// gaps. `BarMark` in a metric hue is the shipped idiom (`SleepTrendChart`) — a bar is a datum,
/// not a plane.
struct DailyLoadBars: View {
    let bars: [(date: Date, load: Double)]

    var body: some View {
        Chart {
            ForEach(bars, id: \.date) { bar in
                BarMark(
                    x: .value("Day", bar.date, unit: .day),
                    y: .value("Load", bar.load)
                )
                .foregroundStyle(ColorTokens.metricLoad)
                .opacity(0.5)
            }
        }
        .frame(height: 56)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .padding(.top, Spacing.sm)
        .entranceReveal()
    }
}

// MARK: - Load Trend Chart

/// DESIGN.md v6 "Field Notes" — the load trend chart carries two series with a METRIC IDENTITY,
/// so each takes its hue: **ATL (acute load) → `metricStrain`** (rust) and
/// **CTL (chronic load) → `metricLoad`** (ochre). TSB is a derived balance with no metric identity
/// of its own, so its area keeps the identity-less warm-ink `chartTSB` token — which also keeps v6's
/// hard prohibition intact: a metric hue is never an area fill.
///
/// Grid hairlines are `chartGrid`; axis value labels render in the annotation voice (10pt Fragment
/// Mono via `AnnotationLabel`). The mono series key under the plot is the design system's own chart
/// grammar (`design-system/guidelines/charts.card.html` labels its series in mono): the DOT carries
/// the hue (a state dot — a sanctioned mark) while the key text stays `text3`.
struct LoadTrendChartView: View {
    @Environment(\.locale) private var locale
    let snapshots: [WorkloadSnapshot]
    @Binding var selectedDate: Date?

    /// Days the plotted snapshots actually span — the range control lets the athlete change it,
    /// so the axis stride has to be computed rather than assumed (v1.7.2 / audit L1).
    private var spanDays: Int {
        guard let first = snapshots.map(\.snapshotDate).min(),
              let last = snapshots.map(\.snapshotDate).max() else { return 1 }
        let calendar = Calendar.current
        return max(1, calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: first),
            to: calendar.startOfDay(for: last)
        ).day ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Chart {
                ForEach(snapshots, id: \.id) { snapshot in
                    // `series:` is load-bearing, not decoration. Swift Charts groups marks into
                    // series, and two `LineMark`s sharing the same x-values with NO series
                    // discriminator collapse into ONE series — so Charts connected ATL→CTL→ATL→CTL
                    // and drew a single zigzag in whichever style won, with the CTL line rendering
                    // nowhere. That predates v6 (it shipped with the warm-ink `chartATL`/`chartCTL`
                    // pair, where two near-identical inks made the artifact easy to miss); v6's
                    // distinct rust/ochre hues plus the series key below made it visible. Naming
                    // the series is what makes the two-hue mapping actually true on screen.
                    LineMark(
                        x: .value("Date", snapshot.snapshotDate),
                        y: .value("ATL", snapshot.acuteLoad),
                        series: .value("Series", "ATL")
                    )
                    .foregroundStyle(ColorTokens.metricStrain)

                    LineMark(
                        x: .value("Date", snapshot.snapshotDate),
                        y: .value("CTL", snapshot.chronicLoad),
                        series: .value("Series", "CTL")
                    )
                    .foregroundStyle(ColorTokens.metricLoad)

                    AreaMark(
                        x: .value("Date", snapshot.snapshotDate),
                        y: .value("TSB", snapshot.tsb)
                    )
                    .foregroundStyle(ColorTokens.chartTSB.opacity(0.2))
                }
            }
            .frame(height: 160)
            // No `.chartLegend` here (v1.7.2 / audit L10): it was a no-op. A legend needs a
            // `foregroundStyle(by:)` mapping to describe, and these series are styled directly;
            // the series key under the plot is hand-built in the annotation voice.
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: ChartAxisTicks.dayStride(spanningDays: spanDays))) { value in
                    AxisGridLine().foregroundStyle(ColorTokens.chartGrid)
                    AxisTick().foregroundStyle(ColorTokens.chartGrid)
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            AnnotationLabel(
                                date.formatted(.dateTime.month(.abbreviated).day().locale(locale)),
                                size: .small
                            )
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: ChartAxisTicks.yAxisStops)) { value in
                    AxisGridLine().foregroundStyle(ColorTokens.chartGrid)
                    AxisValueLabel {
                        if let load = value.as(Double.self) {
                            AnnotationLabel(String(format: "%.0f", load), size: .small)
                        }
                    }
                }
            }
            .id(locale)
            .entranceReveal()
            .chartOverlay { proxy in
                ChartTooltipGesture(
                    proxy: proxy,
                    data: snapshots.map { (date: $0.snapshotDate, value: $0.acuteLoad) },
                    selectedDate: $selectedDate
                )
            }
            .overlay(alignment: .top) {
                if let selectedDate,
                   let snapshot = snapshots.first(where: { Calendar.current.isDate($0.snapshotDate, inSameDayAs: selectedDate) }) {
                    TooltipBubble(
                        value: "ATL: \(String(format: "%.0f", snapshot.acuteLoad)) | CTL: \(String(format: "%.0f", snapshot.chronicLoad))",
                        dateLabel: snapshot.snapshotDate.formatted(.dateTime.month(.abbreviated).day().locale(locale))
                    )
                }
            }

            // Mono series key. ATL/CTL/TSB are the same untranslated scientific abbreviations the
            // metric grid above already prints verbatim, so this adds no new localizable copy.
            HStack(spacing: Spacing.sm) {
                seriesKey(glyph: "\u{25CF}", color: ColorTokens.metricStrain, label: "ATL", index: 0)
                seriesKey(glyph: "\u{25CF}", color: ColorTokens.metricLoad, label: "CTL", index: 1)
                seriesKey(glyph: "\u{2592}", color: ColorTokens.chartTSB, label: "TSB", index: 2)
                Spacer(minLength: 0)
            }
        }
    }

    /// One series-key cell: a hue-bearing state dot (`●`) or fill glyph (`▒`) plus its `text3`
    /// abbreviation, both in the annotation voice, revealed on the v6 choreography.
    private func seriesKey(glyph: String, color: Color, label: String, index: Int) -> some View {
        HStack(spacing: Spacing.baselinePair) {
            AnnotationLabel(glyph, size: .small, color: color)
                .accessibilityHidden(true)
            AnnotationLabel(label, size: .small)
        }
        .annotationReveal(index: index)
    }
}

// MARK: - PR History

struct PRHistorySection: View {
    let records: [PersonalRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(records.enumerated()), id: \.element.id) { index, pr in
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                        Text(pr.exerciseName)
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                        Text(pr.recordType.displayName)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: Spacing.baselinePair) {
                        Text(String(format: "%.1f", pr.value))
                            .font(.Tokens.body)
                            .monospacedDigit()
                            .foregroundStyle(ColorTokens.text1)
                        if let improvement = pr.improvement {
                            // v6: a signed delta is marginalia — the annotation voice. It keeps
                            // its zone color and sits on a CARD plane, which is where rule 7
                            // requires sub-24pt zone-colored text to live.
                            AnnotationLabel(
                                String(format: "+%.1f", improvement),
                                color: ColorTokens.zoneOptimal
                            )
                        }
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.sm)

                if index < records.count - 1 {
                    RowSeparator()
                }
            }
        }
        .cardStyle(horizontalPadding: 0, verticalPadding: 0)
    }
}

// MARK: - Wellness History

struct WellnessHistorySection: View {
    let checkIns: [WellnessCheckIn]
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(checkIns.enumerated()), id: \.element.id) { index, checkIn in
                HStack {
                    Text(checkIn.date.relativeString(locale: locale))
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                    Spacer()
                    Text("\(Int(checkIn.wellnessScore))/100")
                        .font(.Tokens.smallLabelMedium)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.text1)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.sm)

                if index < checkIns.count - 1 {
                    RowSeparator()
                }
            }
        }
        .cardStyle(horizontalPadding: 0, verticalPadding: 0)
    }
}
