import SwiftUI

enum SessionStartChoice: String, CaseIterable, Identifiable {
    case strength
    case basketball
    case aerobic
    case otherSport

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strength: String(localized: "sessionStart.strength", defaultValue: "Strength")
        case .basketball: String(localized: "sessionStart.basketball", defaultValue: "Basketball")
        case .aerobic: String(localized: "sessionStart.aerobic", defaultValue: "Aerobic / Class")
        case .otherSport: String(localized: "sessionStart.otherSport", defaultValue: "Other Sport")
        }
    }

    var systemImage: String {
        switch self {
        case .strength: "dumbbell.fill"
        case .basketball: "basketball.fill"
        case .aerobic: "figure.run"
        case .otherSport: "figure.mixed.cardio"
        }
    }
}

enum BasketballSessionChoice: String, CaseIterable, Identifiable {
    case practice
    case pickup
    case scrimmage
    case match

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .practice: String(localized: "sessionStart.basketball.practice", defaultValue: "Practice")
        case .pickup: String(localized: "sessionStart.basketball.pickup", defaultValue: "Pickup")
        case .scrimmage: String(localized: "sessionStart.basketball.scrimmage", defaultValue: "Scrimmage")
        case .match: String(localized: "sessionStart.basketball.match", defaultValue: "Match")
        }
    }
}

struct SessionStartConfiguration: Equatable {
    let sportType: SportType
    let sessionType: SessionType
    let matchTier: MatchTier?
}

/// Pure mapping between the four session-start choices and the existing persisted enums.
struct SessionStartMapper {
    static func configuration(
        for choice: SessionStartChoice,
        basketballChoice: BasketballSessionChoice = .practice,
        otherSport: SportType = .running,
        currentSessionType: SessionType = .strength
    ) -> SessionStartConfiguration {
        switch choice {
        case .strength:
            SessionStartConfiguration(sportType: .lifting, sessionType: .strength, matchTier: nil)
        case .basketball:
            basketballConfiguration(for: basketballChoice)
        case .aerobic:
            SessionStartConfiguration(sportType: .custom, sessionType: .cardio, matchTier: nil)
        case .otherSport:
            SessionStartConfiguration(
                sportType: otherSport,
                sessionType: defaultSessionType(
                    for: otherSport,
                    currentSessionType: currentSessionType
                ),
                matchTier: nil
            )
        }
    }

    static func basketballConfiguration(
        for choice: BasketballSessionChoice
    ) -> SessionStartConfiguration {
        switch choice {
        case .practice:
            SessionStartConfiguration(sportType: .teamSport, sessionType: .skill, matchTier: nil)
        case .pickup:
            SessionStartConfiguration(sportType: .teamSport, sessionType: .match, matchTier: .pickup)
        case .scrimmage:
            SessionStartConfiguration(sportType: .teamSport, sessionType: .match, matchTier: .scrimmage)
        case .match:
            SessionStartConfiguration(sportType: .teamSport, sessionType: .match, matchTier: .match)
        }
    }

    static func choice(
        sportType: SportType,
        sessionType: SessionType
    ) -> SessionStartChoice {
        if sportType == .lifting && sessionType == .strength { return .strength }
        if sportType == .teamSport { return .basketball }
        if sportType == .custom && sessionType == .cardio { return .aerobic }
        return .otherSport
    }

    static func basketballChoice(
        sessionType: SessionType,
        matchTier: MatchTier?
    ) -> BasketballSessionChoice {
        guard sessionType == .match else { return .practice }
        switch matchTier ?? .pickup {
        case .pickup: return .pickup
        case .scrimmage: return .scrimmage
        case .match: return .match
        }
    }

    static func defaultSessionType(
        for sport: SportType,
        currentSessionType: SessionType
    ) -> SessionType {
        switch sport {
        case .lifting, .crossfit: .strength
        case .running, .cycling, .swimming: .cardio
        case .teamSport: .skill
        case .custom: currentSessionType
        }
    }
}

struct SessionStartPicker: View {
    @Binding var choice: SessionStartChoice
    @Binding var sportType: SportType
    @Binding var sessionType: SessionType
    @Binding var matchTier: MatchTier?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var basketballChoice: BasketballSessionChoice
    @State private var otherSport: SportType
    @State private var isAdjustExpanded = false

    private let defaultSessionType: (SportType) -> SessionType
    private static let otherSports: [SportType] = [
        .running,
        .cycling,
        .swimming,
        .crossfit,
        .custom
    ]

    init(
        choice: Binding<SessionStartChoice>,
        sportType: Binding<SportType>,
        sessionType: Binding<SessionType>,
        matchTier: Binding<MatchTier?>,
        defaultSessionType: ((SportType) -> SessionType)? = nil
    ) {
        _choice = choice
        _sportType = sportType
        _sessionType = sessionType
        _matchTier = matchTier
        self.defaultSessionType = defaultSessionType ?? { sport in
            SessionStartMapper.defaultSessionType(
                for: sport,
                currentSessionType: sessionType.wrappedValue
            )
        }
        _basketballChoice = State(
            initialValue: SessionStartMapper.basketballChoice(
                sessionType: sessionType.wrappedValue,
                matchTier: matchTier.wrappedValue
            )
        )
        _otherSport = State(
            initialValue: Self.otherSports.contains(sportType.wrappedValue)
                ? sportType.wrappedValue
                : .running
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(String(localized: "sessionStart.title", defaultValue: "What are you training?"))
                .font(.Tokens.sectionHead)
                .foregroundStyle(ColorTokens.text1)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Spacing.xs),
                    GridItem(.flexible(), spacing: Spacing.xs)
                ],
                spacing: Spacing.xs
            ) {
                ForEach(SessionStartChoice.allCases) { option in
                    choiceButton(option)
                }
            }

            if choice == .basketball {
                basketballChoices.transition(.opacity)
            } else if choice == .otherSport {
                otherSportChoices.transition(.opacity)
            }

            Button {
                isAdjustExpanded.toggle()
                Haptics.tap()
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text(isAdjustExpanded
                         ? String(localized: "sessionStart.adjust.hide", defaultValue: "Hide adjustments")
                         : String(localized: "sessionStart.adjust.show", defaultValue: "Adjust"))
                        .font(.Tokens.label)
                    Spacer()
                    Image(systemName: isAdjustExpanded ? "chevron.up" : "chevron.down")
                        .font(.Tokens.label)
                }
                .foregroundStyle(ColorTokens.text2)
                .padding(.vertical, Spacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)

            if isAdjustExpanded {
                fullAdjustments.transition(.opacity)
            }
        }
        .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: choice)
        .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: isAdjustExpanded)
    }

    private func choiceButton(_ option: SessionStartChoice) -> some View {
        let isSelected = choice == option
        return Button {
            apply(option)
            Haptics.select()
        } label: {
            VStack(spacing: Spacing.xs) {
                Image(systemName: option.systemImage)
                    .font(.Tokens.sectionHead)
                Text(option.displayName)
                    .font(.Tokens.label)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(isSelected ? ColorTokens.accent : ColorTokens.text2)
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(Spacing.xs)
            .background(isSelected ? ColorTokens.accentSubtle : ColorTokens.surfaceEl)
            .overlay(
                Rectangle().stroke(
                    isSelected ? ColorTokens.accent : ColorTokens.divider,
                    lineWidth: 0.5
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var basketballChoices: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            microLabel("sessionStart.basketball.title", "Basketball session")
            HStack(spacing: Spacing.xs) {
                ForEach(BasketballSessionChoice.allCases) { option in
                    compactButton(label: option.displayName, isSelected: basketballChoice == option) {
                        basketballChoice = option
                        applyConfiguration(SessionStartMapper.basketballConfiguration(for: option))
                    }
                }
            }
        }
    }

    private var otherSportChoices: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                microLabel("sessionStart.otherSport.title", "Sport")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(Self.otherSports) { sport in
                            compactButton(label: sport.displayName, isSelected: otherSport == sport) {
                                otherSport = sport
                                applyOtherSport(sport)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                microLabel("sessionStart.otherSession.title", "Session type")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(SessionType.allCases) { type in
                            compactButton(label: type.displayName, isSelected: sessionType == type) {
                                sessionType = type
                                if type != .match { matchTier = nil }
                            }
                        }
                    }
                }
            }

            if sessionType == .match {
                MatchTierPicker(selection: $matchTier)
            }
        }
    }

    private var fullAdjustments: some View {
        VStack(spacing: Spacing.sm) {
            RadialPicker(selection: $sportType, title: "picker.sportType.title")
                .onChange(of: sportType) { _, newSport in
                    sessionType = defaultSessionType(newSport)
                    if newSport != .teamSport { matchTier = nil }
                    syncChoiceFromBindings()
                }

            RadialPicker(selection: $sessionType, title: "picker.sessionType.title")
                .onChange(of: sessionType) { _, newType in
                    if newType != .match { matchTier = nil }
                    syncChoiceFromBindings()
                }

            if sessionType == .match {
                MatchTierPicker(selection: $matchTier)
            }
        }
    }

    private func microLabel(
        _ key: StaticString,
        _ fallback: String.LocalizationValue
    ) -> some View {
        Text(String(localized: key, defaultValue: fallback))
            .font(.Tokens.micro)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(ColorTokens.text3)
    }

    private func compactButton(
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            Haptics.select()
        } label: {
            Text(label)
                .font(.Tokens.label)
                .foregroundStyle(isSelected ? ColorTokens.accent : ColorTokens.text2)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(isSelected ? ColorTokens.accentSubtle : ColorTokens.surfaceEl)
                .overlay(
                    Rectangle().stroke(
                        isSelected ? ColorTokens.accent : ColorTokens.divider,
                        lineWidth: 0.5
                    )
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func apply(_ newChoice: SessionStartChoice) {
        choice = newChoice
        switch newChoice {
        case .basketball:
            basketballChoice = sportType == .teamSport
                ? SessionStartMapper.basketballChoice(sessionType: sessionType, matchTier: matchTier)
                : .practice
            applyConfiguration(SessionStartMapper.basketballConfiguration(for: basketballChoice))
        case .otherSport:
            if Self.otherSports.contains(sportType) { otherSport = sportType }
            applyOtherSport(otherSport)
        default:
            applyConfiguration(SessionStartMapper.configuration(for: newChoice))
        }
    }

    private func applyOtherSport(_ sport: SportType) {
        applyConfiguration(
            SessionStartConfiguration(
                sportType: sport,
                sessionType: defaultSessionType(sport),
                matchTier: nil
            )
        )
    }

    private func applyConfiguration(_ configuration: SessionStartConfiguration) {
        sportType = configuration.sportType
        sessionType = configuration.sessionType
        matchTier = configuration.matchTier
    }

    private func syncChoiceFromBindings() {
        choice = SessionStartMapper.choice(sportType: sportType, sessionType: sessionType)
        if choice == .basketball {
            basketballChoice = SessionStartMapper.basketballChoice(
                sessionType: sessionType,
                matchTier: matchTier
            )
        } else if choice == .otherSport && Self.otherSports.contains(sportType) {
            otherSport = sportType
        }
    }
}

struct MatchTierPicker: View {
    @Binding var selection: MatchTier?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(String(localized: "matchTier.picker.title", defaultValue: "Match tier"))
                .font(.Tokens.micro)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(ColorTokens.text3)

            HStack(spacing: Spacing.xs) {
                ForEach(MatchTier.allCases) { tier in
                    tierButton(tier)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Motion.state, value: selection)
    }

    private func tierButton(_ tier: MatchTier) -> some View {
        let isSelected = (selection ?? .pickup) == tier
        return Button {
            selection = tier
            Haptics.select()
        } label: {
            Text(tier.displayName)
                .font(.Tokens.label)
                .foregroundStyle(isSelected ? ColorTokens.surface : ColorTokens.text2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xs)
                .background(Rectangle().fill(isSelected ? ColorTokens.text1 : Color.clear))
                .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(tier.displayName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
