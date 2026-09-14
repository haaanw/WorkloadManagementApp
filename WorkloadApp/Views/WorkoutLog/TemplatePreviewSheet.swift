import SwiftUI
import SwiftData

// The program's day-level drill-down (v1.7.3 · UAT round 3 · U21 + U24).
//
// This file used to hold `TemplatePreviewSheet`, a sheet that nothing presented any more
// (U7/U8 retired its last entry point) and whose set summary read only the FIRST set and
// hard-coded kilograms. Its one good idea — group · exercise · set spec on one plate — is
// rebuilt here as the destination the program screen's day rows push to, with a set
// summary that folds like sets, prints a ramp, and spells weights in the athlete's unit.

// MARK: - Set summary

/// The folded set spec for one planned exercise — "5 × 5 @ 100 kg", "3 × 3 @ 80 / 85 / 90 kg",
/// "4 × 8 @ RPE 8", "3 × 10 @ BW".
///
/// Pure and static so the folding rules are testable without a view. Four decisions, in order:
///
/// 1. **Reps.** Uniform across the working sets → `n × r`. Varied → the list itself
///    (`5 / 5 / 3`), because the count is then already visible in the list.
/// 2. **Load.** Uniform → one numeral. Varied → the ramp, `80 / 85 / 90`, with ONE unit
///    symbol for the whole list. A bodyweight movement reads `BW`, or `BW + 10 kg` when the
///    plan adds load.
/// 3. **Effort.** An RPE or RIR target when the plan carries one. It takes the `@` slot when
///    there is no load to put there, so a plan written in RPE still reads as a spec.
/// 4. Warm-up sets never appear — a warm-up is not part of the prescription.
///
/// Every weight goes through `WeightFormatter`; nothing here types a unit.
enum TemplateSetSummary {

    static func line(for exercise: TemplateExercise, unit: WeightUnit) -> String {
        let working = exercise.sortedSets.filter { !$0.isWarmup }
        guard !working.isEmpty else { return setCount(exercise.sets.count) }

        let reps = repsPart(working)
        let load = loadPart(working, category: exercise.exerciseCategory, unit: unit)
        let effort = effortPart(working)

        let head = reps ?? setCount(working.count)
        switch (load, effort) {
        case (.some(let load), .some(let effort)):
            return "\(head) @ \(load) · \(effort)"
        case (.some(let load), .none):
            return "\(head) @ \(load)"
        case (.none, .some(let effort)):
            return "\(head) @ \(effort)"
        case (.none, .none):
            return head
        }
    }

    // MARK: Parts

    private static func setCount(_ count: Int) -> String {
        String(
            // A machine key rather than "%lld SETS" — the count can be 1, and the annotation
            // voice has no plural to agree with.
            format: String(localized: "program.day.setCount", defaultValue: "SETS: %lld"),
            count
        )
    }

    private static func repsPart(_ sets: [TemplateSet]) -> String? {
        let reps = sets.map(\.targetReps)
        guard reps.contains(where: { $0 != nil }) else { return nil }
        if let first = reps.first ?? nil, reps.allSatisfy({ $0 == first }) {
            return "\(sets.count) × \(first)"
        }
        return reps.map { $0.map(String.init) ?? "—" }.joined(separator: " / ")
    }

    private static func loadPart(
        _ sets: [TemplateSet],
        category: ExerciseCategory,
        unit: WeightUnit
    ) -> String? {
        let weights = sets.map(\.targetWeightKg)
        let added = weights.compactMap { $0 }.filter { $0 > 0 }
        let bw = String(localized: "setEntry.bw", defaultValue: "BW")

        guard category != .bodyweight else {
            guard !added.isEmpty else { return bw }
            return "\(bw) + \(numerals(weights, unit: unit))"
        }

        guard !added.isEmpty else { return nil }
        return numerals(weights, unit: unit)
    }

    /// One numeral when the plan holds the load flat, the ramp when it does not — with a
    /// single trailing unit symbol either way.
    private static func numerals(_ weights: [Double?], unit: WeightUnit) -> String {
        let symbol = unit.displayName
        if let first = weights.first ?? nil, weights.allSatisfy({ $0 == first }) {
            return "\(WeightFormatter.displayNumeral(first, unit: unit)) \(symbol)"
        }
        let list = weights
            .map { $0.map { WeightFormatter.displayNumeral($0, unit: unit) } ?? "—" }
            .joined(separator: " / ")
        return "\(list) \(symbol)"
    }

    private static func effortPart(_ sets: [TemplateSet]) -> String? {
        let rpes = sets.map(\.targetRPE)
        if rpes.contains(where: { $0 != nil }) {
            let values = rpes.map { $0.map(effortNumeral) ?? "—" }
            if let first = values.first, values.allSatisfy({ $0 == first }) {
                return "RPE \(first)"
            }
            return "RPE \(values.joined(separator: " / "))"
        }
        let rirs = sets.map(\.targetRIR)
        if rirs.contains(where: { $0 != nil }) {
            let values = rirs.map { $0.map(String.init) ?? "—" }
            if let first = values.first, values.allSatisfy({ $0 == first }) {
                return "\(first) RIR"
            }
            return "\(values.joined(separator: " / ")) RIR"
        }
        return nil
    }

    private static func effortNumeral(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

// MARK: - Program day detail

/// One day of the imported block, opened from the program screen's week rows (U21 + U24).
///
/// It READS the plan and shows nothing else: the day's own name, where it sits in the block,
/// what the log says about it, then group → exercise → set spec. There is no "Edit template"
/// slot — the day belongs to a program the athlete imported, and Tuwa never writes the
/// program. A day the file left empty says so in one quiet line rather than showing a blank
/// plate.
struct ProgramDayDetailView: View {
    let day: ProgramDay
    let template: WorkoutTemplate?
    /// The already-resolved status stamp ("TRAINED" / "TODAY" / "UPCOMING"), so this screen
    /// and the week row it came from can never disagree about the same day.
    let status: String
    let unit: WeightUnit

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                header
                if let template {
                    content(template)
                    if let notes = template.notes, !notes.isEmpty {
                        Text(verbatim: notes)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                            .padding(Spacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardStyle(horizontalPadding: 0, verticalPadding: 0)
                    }
                } else {
                    Text("program.day.noTemplate")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text2)
                        .padding(Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle(horizontalPadding: 0, verticalPadding: 0)
                }
            }
            .padding(Spacing.sm)
        }
        .background(ColorTokens.background)
        .navigationTitle(Text(verbatim: day.title))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            // The day's own name is content the athlete wrote or imported — working voice.
            Text(verbatim: day.title)
                .font(.Tokens.sectionHead)
                .foregroundStyle(ColorTokens.text1)
            // Position in the block + what the log says. Both marginalia.
            AnnotationLabel("W\(day.weekNumber) · D\(day.dayNumber) · \(status)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Content

    private func content(_ template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(template.sortedGroups, id: \.id) { group in
                AnnotationLabel(group.groupName)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.sm)
                    .padding(.bottom, Spacing.baselinePair)

                ForEach(group.sortedExercises, id: \.id) { exercise in
                    VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                        Text(verbatim: exercise.exerciseName)
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                        // The set spec is a unitized machine string — annotation (v6), on
                        // `text2` because it is the reading the athlete actually came for.
                        AnnotationLabel(
                            TemplateSetSummary.line(for: exercise, unit: unit),
                            color: ColorTokens.text2
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .overlay(alignment: .top) {
                        if exercise.orderIndex > 0 {
                            Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                        }
                    }
                }
            }
            .padding(.bottom, Spacing.xs)
        }
        .emphasisCardStyle(horizontalPadding: 0, verticalPadding: 0)
    }
}
