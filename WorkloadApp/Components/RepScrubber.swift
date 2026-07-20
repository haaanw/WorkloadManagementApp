import SwiftUI
import UIKit

/// Horizontal detent scrubber for reps entry (proposal §4) — replaces the reps keyboard
/// pop in the `.weightReps` set row with a bounded 1–30 drag.
///
/// LOCKED DECISIONS / DESIGN.md compliance (Tuwa v2 — accent now marks live / active state):
/// - A single 0.5pt hairline `divider` baseline with detent tick marks (0.5pt `Rectangle`s)
///   at constant pitch. NOT a filled rail. The position indicator is a 0pt-corner `Rectangle`
///   (no rounded thumb, no shadow); it carries the `accent` once a value is committed/being
///   dragged (the live selection), and falls back to `text3` while only a ghost suggestion shows.
/// - Live value rendered ABOVE the track, Font.Tokens Medium / `text1` / `.monospacedDigit()`
///   in a fixed-width box so 1↔8 width swaps never jitter the layout.
/// - Ghost baseline (suggested reps) renders in `text3` until the user commits.
///
/// Commit model (matches `WeightBlockPicker.onCommit`):
/// - The bound `reps` is written ONLY on a crossed-detent / drag release (not every pixel),
///   to avoid SwiftData `@Binding` re-render churn during the drag.
/// - Committing a reps value (drag or keypad) calls `onCommit`, which marks the set's
///   `isDone = true` (a real user commit), consistent with the weight picker.
///
/// Tap the number (or anywhere on the track) → `.numberPad` keypad fallback for the fast
/// known-value path; clamp 1–30 on dismiss.
///
/// Haptics (v4.1 D13(a)): per-detent scrub ticks are SILENT — the motion carries the
/// feedback. The ONLY haptic is `Haptics.limit()` when the drag reaches the 1 or 30 bound
/// (a rejected/at-limit press), fired once on the crossing into that bound.
struct RepScrubber: View {
    /// Bound stored reps (nil = unset / first-ever).
    @Binding var reps: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Suggested reps to render as a ghost baseline when `reps` is nil (from `SetSuggestion`).
    var suggestedReps: Int? = nil
    /// Called when the user commits a reps value (drag or keypad) — marks the set done.
    var onCommit: () -> Void = {}

    // MARK: In-flow keypad focus chain (proposal §5.5)
    /// Shared focus across the row's weight + reps inline keypads, so weight → reps
    /// advances without dismissing the keyboard.
    var focus: FocusState<SetFocusField?>.Binding? = nil
    /// Stable id of the owning set row (disambiguates focus across rows).
    var rowId: UUID = UUID()

    // MARK: Bounds / geometry

    private let minReps = 1
    private let maxReps = 30

    /// Live drag value (integer) while a drag is in progress; nil when not dragging.
    /// Isolated in local @State so per-pixel motion never writes the @Binding.
    @State private var dragValue: Int? = nil
    @State private var isDragging = false

    @State private var showKeypad = false
    @State private var keypadText = ""

    // v4.1 D13(a): the ONLY per-adjustment haptic is the min/max limit bump (a firm medium
    // impact, matching `Haptics.limit()`). Kept as a local generator so it can be `prepare()`d
    // on touch-down for tight drag latency; no per-detent selection buzz during the scrub.
    private let limitHaptic = UIImpactFeedbackGenerator(style: .medium)

    /// The value the indicator should sit on: the live drag value, else the committed reps,
    /// else the suggested ghost baseline, else the floor.
    private var indicatorValue: Int {
        dragValue ?? reps ?? suggestedReps ?? minReps
    }

    /// True when there is no committed reps and we are showing the suggested ghost.
    private var isGhost: Bool { dragValue == nil && reps == nil && suggestedReps != nil }

    /// The number to display above the track.
    private var displayValue: Int? {
        dragValue ?? reps ?? suggestedReps
    }

    private func clamp(_ v: Int) -> Int { min(maxReps, max(minReps, v)) }

    // MARK: Commit

    private func commit(_ v: Int) {
        reps = clamp(v)
        onCommit()
    }

    /// VoiceOver value: full words, e.g. "five reps".
    private func accessibilityValueString() -> String {
        guard let v = displayValue else {
            return String(localized: "repScrubber.unset.accessibility", defaultValue: "No reps set")
        }
        return String(format: String(localized: "repScrubber.value.accessibility", defaultValue: "%d reps"), v)
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Live readout above the track (display-over-control). When a focus chain is
            // wired, the value doubles as the inline keypad field so weight → reps advances
            // without dismissing the keyboard (§5.5); otherwise it falls back to an alert.
            HStack(spacing: Spacing.baselinePair) {
                readout
                Text("table.header.reps")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }

            track
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "repScrubber.accessibility", defaultValue: "Reps"))
        .accessibilityValue(accessibilityValueString())
        .accessibilityAdjustableAction { direction in
            let base = displayValue ?? minReps
            switch direction {
            case .increment: commit(base + 1)
            case .decrement: commit(base - 1)
            @unknown default: break
            }
        }
        .alert(String(localized: "repScrubber.type.title", defaultValue: "Enter reps"), isPresented: $showKeypad) {
            TextField(String(localized: "table.header.reps", defaultValue: "Reps"), text: $keypadText)
                .keyboardType(.numberPad)
            Button(String(localized: "action.cancel", defaultValue: "Cancel"), role: .cancel) {}
            Button(String(localized: "action.done", defaultValue: "Done")) {
                if let typed = Int(keypadText) {
                    commit(typed)
                }
            }
        }
    }

    /// The live value above the track. With a focus chain it is an inline keypad field
    /// (weight → reps advance); without one it is a plain Text (alert fallback via tap).
    @ViewBuilder private var readout: some View {
        if let focus {
            TextField("—", text: $keypadText)
                .keyboardType(.numberPad)
                .focused(focus, equals: .reps(rowId))
                .multilineTextAlignment(.leading)
                .font(.Tokens.bodyMedium)
                .monospacedDigit()
                .foregroundStyle(isGhost ? ColorTokens.text3 : (displayValue == nil ? ColorTokens.text2 : ColorTokens.text1))
                .frame(minWidth: 28, alignment: .leading)
                .fixedSize()
                .submitLabel(.done)
                .onChange(of: focus.wrappedValue) { _, newValue in
                    if newValue == .reps(rowId) {
                        keypadText = displayValue.map { "\($0)" } ?? ""
                    }
                }
                .onSubmit { commitKeypad() }
        } else {
            Text(displayValue.map { "\($0)" } ?? "—")
                .font(.Tokens.bodyMedium)
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(isGhost ? ColorTokens.text3 : (displayValue == nil ? ColorTokens.text2 : ColorTokens.text1))
                // Fixed-width value cell (D13(c)) — reserved for two digits ("30"); the swap
                // rolls subtly via digitRoll (D13(b)) so 1↔30 never jitters the row.
                .frame(minWidth: 28, alignment: .leading)
                .animation(Motion.resolved(Motion.digitRoll, reduceMotion: reduceMotion), value: displayValue)
        }
    }

    /// Commit the typed reps and release focus (end of the weight → reps chain).
    private func commitKeypad() {
        if let typed = Int(keypadText) {
            commit(typed)
        }
        focus?.wrappedValue = nil
    }

    // MARK: Track

    private var track: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let span = CGFloat(maxReps - minReps)
            // Indicator x for a given reps value, centered within the track width.
            let frac = CGFloat(indicatorValue - minReps) / max(1, span)
            let indicatorX = frac * width

            ZStack(alignment: .leading) {
                // Baseline hairline.
                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)
                    .frame(maxHeight: .infinity, alignment: .center)

                // Detent ticks at constant pitch (every 5 reps for legibility; 1–30 → ticks).
                ForEach(tickValues, id: \.self) { tickVal in
                    let tFrac = CGFloat(tickVal - minReps) / max(1, span)
                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(width: 0.5, height: 8)
                        .frame(maxHeight: .infinity, alignment: .center)
                        .offset(x: tFrac * width)
                }

                // Position indicator — a plain Rectangle (no thumb, no shadow). v4: the
                // committed/active selection is INK; a ghost suggestion stays text3
                // (Index Rule: the red needle lives on TickScale only).
                Rectangle()
                    .fill(isGhost ? ColorTokens.text3 : ColorTokens.text1)
                    .frame(width: 2, height: 24)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .offset(x: indicatorX - 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            // Horizontal drag with a minimumDistance so the sheet's vertical ScrollView still
            // scrolls; arbitration via .gesture (SwiftUI prefers the axis-matching gesture).
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { g in
                        if !isDragging {
                            isDragging = true
                            limitHaptic.prepare()
                        }
                        let f = max(0, min(1, g.location.x / max(1, width)))
                        let v = clamp(minReps + Int((f * span).rounded()))
                        if v != dragValue {
                            let previous = dragValue
                            dragValue = v
                            // Per-detent ticks are SILENT (D13(a)); fire the limit bump only
                            // when the scrub newly lands on the 1 or 30 bound.
                            if (v == minReps || v == maxReps) && v != previous {
                                limitHaptic.impactOccurred()
                                limitHaptic.prepare()
                            }
                        }
                    }
                    .onEnded { _ in
                        if let v = dragValue {
                            commit(v)
                        }
                        dragValue = nil
                        isDragging = false
                    }
            )
            // Tap → keypad fallback (fast known-value path). With a focus chain, focus the
            // inline field (no alert); otherwise present the alert.
            .onTapGesture {
                keypadText = displayValue.map { "\($0)" } ?? ""
                if let focus {
                    focus.wrappedValue = .reps(rowId)
                } else {
                    showKeypad = true
                }
            }
        }
        .frame(height: 32)
        .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: reps)
    }

    /// Detent values to draw ticks at: 1, 5, 10, … 30 (constant 5-rep pitch + the floor).
    private var tickValues: [Int] {
        var vals = [minReps]
        var v = 5
        while v <= maxReps {
            vals.append(v)
            v += 5
        }
        return vals
    }
}
