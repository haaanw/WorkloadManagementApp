import SwiftUI
import UIKit

// MARK: - RadialSelectable

/// Drives a `RadialPicker` ring. Any `CaseIterable` enum that supplies a display
/// label and an SF Symbol can be presented as a radial gesture menu.
///
/// `SportType` and `SessionType` conform in `Models/Enums.swift` (Phase 21).
protocol RadialSelectable: CaseIterable, Hashable, Identifiable {
    /// Localized label shown beneath the option's icon.
    var displayName: String { get }
    /// SF Symbol name rendered for the option (must be valid on iOS 17).
    var radialIcon: String { get }
}

// MARK: - Ring geometry (pure, unit-testable)

/// Pure geometry + hit-testing for the radial ring. SwiftUI-free so it can be
/// driven directly from unit tests (`RadialPickerGeometryTests`,
/// `RadialPickerInteractionTests`).
///
/// Layout (D-05): option `i` sits at `angle(i) = -90° + i * (360° / count)`,
/// i.e. index 0 at top, proceeding clockwise.
///
/// Hit-testing (D-07): a center-relative point is classified to an option index
/// only when its magnitude is within `[deadZoneRadius, cancelRadius]`. Inside the
/// dead zone or beyond the cancel radius the result is `nil` (a "cancel").
struct RadialRingGeometry {
    let count: Int
    let diameter: CGFloat
    let deadZoneRadius: CGFloat

    /// Radius at which option chips are placed (center of the ring band).
    var optionRadius: CGFloat { diameter / 2 }

    /// Outer radius beyond which a release is treated as cancel (D-07).
    var cancelRadius: CGFloat { diameter * 0.75 }

    /// Angle (radians) for the option at `index`. Index 0 = top (-90°), clockwise.
    func angle(forIndex index: Int) -> CGFloat {
        let step = (2 * CGFloat.pi) / CGFloat(max(count, 1))
        return -CGFloat.pi / 2 + CGFloat(index) * step
    }

    /// Offset (from ring center) for the option at `index` on `radius`.
    /// y grows downward to match SwiftUI's coordinate space.
    func point(forIndex index: Int, radius: CGFloat) -> CGSize {
        let a = angle(forIndex: index)
        return CGSize(width: radius * cos(a), height: radius * sin(a))
    }

    /// Classify a center-relative point into a highlighted option index, or `nil`
    /// (dead zone / beyond cancel radius). `point` uses SwiftUI coordinates
    /// (y downward), origin at ring center.
    func highlightIndex(for point: CGPoint) -> Int? {
        guard count > 0 else { return nil }
        let magnitude = (point.x * point.x + point.y * point.y).squareRoot()
        if magnitude < deadZoneRadius || magnitude > cancelRadius {
            return nil
        }
        // Angle of the finger, normalized to the same -90°-at-top, clockwise scheme.
        var theta = atan2(point.y, point.x) + CGFloat.pi / 2
        let twoPi = 2 * CGFloat.pi
        theta = theta.truncatingRemainder(dividingBy: twoPi)
        if theta < 0 { theta += twoPi }
        let step = twoPi / CGFloat(count)
        // Round to nearest sector center.
        let index = Int((theta / step).rounded()) % count
        return index
    }
}

// MARK: - RadialPicker

/// iPod-wheel-inspired radial gesture picker (Phase 21).
///
/// Collapsed: a 0pt-corner tile showing the selected option (icon + label),
/// matching the segmented-control visual weight it replaces. A long press
/// (>= 0.3s) opens a circular overlay with every case laid out around a ring;
/// the user drags to highlight the option under their finger (haptic on each
/// highlight change) and releases to commit. Releasing in the center dead zone
/// or outside the ring cancels with no change.
///
/// Accessibility (D-14): under VoiceOver or Reduce Motion the gesture overlay is
/// bypassed for an accessible `Menu`; Reduce Motion also zeroes the animation.
///
/// Design (D-10/D-11/D-12): every rectangular sub-element uses `Rectangle()` with
/// a hairline border — only the functional ring is circular. Selected / highlighted
/// state = INK (surfaceEl2 fill + ink label + ink hairline — v4 Index Rule), the
/// live-state semantic; unselected = `text2` + `divider` hairline.
struct RadialPicker<Option: RadialSelectable>: View where Option.AllCases.Element == Option {
    @Binding var selection: Option
    let title: LocalizedStringKey
    var diameter: CGFloat = 240

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    @State private var isOpen = false
    @State private var highlighted: Option?

    // Haptics — created once, prepared on open (D-06). First haptics in the app.
    private let openImpact = UIImpactFeedbackGenerator(style: .medium)
    private let commitImpact = UIImpactFeedbackGenerator(style: .medium)
    private let selectionFeedback = UISelectionFeedbackGenerator()

    // 8pt grid (D-12)
    private let deadZoneRadius: CGFloat = 64
    private let chipIconSize: CGFloat = 24
    private let chipPadding: CGFloat = 16

    private var options: [Option] { Array(Option.allCases) }

    private var geometry: RadialRingGeometry {
        RadialRingGeometry(count: options.count, diameter: diameter, deadZoneRadius: deadZoneRadius)
    }

    private var usesAccessibleFallback: Bool {
        voiceOverEnabled || reduceMotion
    }

    /// Micro-caps case + tracking are LATIN typography, not English typography. The old
    /// `== "en"` test wrongly stripped both from French, which wants them exactly as much as
    /// English does; only CJK must be excluded. This is the same `isLatin` idiom used by
    /// `AnnotationLabel`, `ZoneBadge`, `MetricCell`, and `RuledSectionHeader` — Wave 2 (Session D)
    /// converted the others and left this one behind.
    private var isLatin: Bool {
        locale.language.languageCode?.identifier != "zh"
    }

    var body: some View {
        Group {
            if usesAccessibleFallback {
                accessibleTile
            } else {
                gestureTile
            }
        }
        .overlay(alignment: .center) {
            if isOpen {
                ringOverlay
            }
        }
    }

    // MARK: Collapsed tile

    private func collapsedTileContent() -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.Tokens.micro)
                .tracking(isLatin ? 1.2 : 0)
                .textCase(isLatin ? .uppercase : nil)
                .foregroundStyle(ColorTokens.text3)
            Spacer(minLength: 8)
            Image(systemName: selection.radialIcon)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
            Text(selection.displayName)
                .font(.Tokens.bodyMedium)
                .foregroundStyle(ColorTokens.text1)
        }
        .padding(.horizontal, chipPadding)
        .padding(.vertical, chipPadding)
        .frame(maxWidth: .infinity)
        .background(ColorTokens.surface)
        .overlay(
            Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
    }

    /// Gesture-driven tile (default path).
    private var gestureTile: some View {
        collapsedTileContent()
            .gesture(openAndTrackGesture)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue(selection.displayName)
            .accessibilityHint(Text(verbatim: String(localized: "radialPicker.hint", defaultValue: "Long press to choose")))
    }

    /// Accessible fallback: a standard `Menu` of all options (D-14).
    private var accessibleTile: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    setSelection(option, animated: false)
                } label: {
                    Label(option.displayName, systemImage: option.radialIcon)
                }
            }
        } label: {
            collapsedTileContent()
        }
        .accessibilityLabel(title)
        .accessibilityValue(selection.displayName)
    }

    // MARK: Ring overlay

    private var ringOverlay: some View {
        ZStack {
            Rectangle()
                .fill(ColorTokens.background.opacity(0.6))
                .ignoresSafeArea()
                .contentShape(Rectangle())

            ZStack {
                Circle()
                    .stroke(ColorTokens.divider, lineWidth: 0.5)
                    .frame(width: diameter, height: diameter)

                ForEach(Array(options.enumerated()), id: \.element) { index, option in
                    optionChip(option, isHighlighted: highlighted == option)
                        .offset(geometry.point(forIndex: index, radius: geometry.optionRadius))
                }
            }
            .frame(width: geometry.cancelRadius * 2, height: geometry.cancelRadius * 2)
            .contentShape(Rectangle())
            .gesture(trackGesture)
        }
        .transition(.opacity)
    }

    private func optionChip(_ option: Option, isHighlighted: Bool) -> some View {
        VStack(spacing: Spacing.baselinePair) {
            Image(systemName: option.radialIcon)
                .font(.Tokens.sectionHead)
                .frame(width: chipIconSize, height: chipIconSize)
            Text(option.displayName)
                .font(isHighlighted ? .Tokens.smallLabelMedium : .Tokens.smallLabel)
                .lineLimit(1)
        }
        .foregroundStyle(isHighlighted ? ColorTokens.text1 : ColorTokens.text2)
        .padding(.horizontal, chipPadding)
        .padding(.vertical, 8)
        .background(isHighlighted ? ColorTokens.surfaceEl2 : ColorTokens.surface)
        .overlay(
            Rectangle().stroke(
                isHighlighted ? ColorTokens.text1 : ColorTokens.divider,
                lineWidth: 0.5
            )
        )
        .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: isHighlighted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.displayName)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Gestures

    /// Long-press to open, sequenced with a drag for finger tracking (D-06).
    private var openAndTrackGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .onEnded { _ in open() }
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                if case .second(true, let drag?) = value {
                    updateHighlight(for: drag.location)
                }
            }
            .onEnded { value in
                if case .second(true, let drag?) = value {
                    commit(at: drag.location)
                } else {
                    close()
                }
            }
    }

    /// Drag tracking once the ring is already open (over the overlay itself).
    private var trackGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in updateHighlight(for: value.location) }
            .onEnded { value in commit(at: value.location) }
    }

    // MARK: State transitions

    private func open() {
        openImpact.prepare()
        selectionFeedback.prepare()
        commitImpact.prepare()
        withAnimation(Motion.resolved(Motion.screen, reduceMotion: reduceMotion)) {
            isOpen = true
        }
        openImpact.impactOccurred()
    }

    private func close() {
        withAnimation(Motion.resolved(Motion.exit, reduceMotion: reduceMotion)) {
            isOpen = false
        }
        highlighted = nil
    }

    /// The overlay's local frame is `cancelRadius * 2` square; convert a touch
    /// location in that frame to a center-relative point for the geometry helper.
    private func centerRelative(_ location: CGPoint) -> CGPoint {
        CGPoint(x: location.x - geometry.cancelRadius, y: location.y - geometry.cancelRadius)
    }

    private func updateHighlight(for location: CGPoint) {
        guard isOpen else { return }
        let point = centerRelative(location)
        let newOption = geometry.highlightIndex(for: point).map { options[$0] }
        if newOption != highlighted {
            highlighted = newOption
            if newOption != nil {
                selectionFeedback.selectionChanged()
            }
        }
    }

    private func commit(at location: CGPoint) {
        guard isOpen else { return }
        let point = centerRelative(location)
        if let index = geometry.highlightIndex(for: point) {
            let option = options[index]
            commitImpact.impactOccurred()
            setSelection(option, animated: true)
        } else {
            close()
        }
    }

    private func setSelection(_ option: Option, animated: Bool) {
        selection = option
        if animated {
            close()
        } else {
            highlighted = nil
        }
    }
}
