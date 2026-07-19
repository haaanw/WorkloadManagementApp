import SwiftUI

/// Push-navigation language picker. Renders an autonym row per supported locale,
/// with a checkmark on the active row. Tapping a row commits via LocaleManager.setLocale.
/// Live-renders immediately (no auto-pop) per UI-SPEC line 173.
/// Conforms to DESIGN.md: corners via `CornerTokens` (v3 Corner Law — the row group rides `cardStyle`),
/// no shadows; the active row carries the accent (Tuwa v2 live-state).
struct LanguagePickerView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(Array(container.localeManager.supportedLocales.enumerated()), id: \.element.identifier) { index, locale in
                    row(for: locale)
                    if index < container.localeManager.supportedLocales.count - 1 {
                        RowSeparator()
                    }
                }
            }
            // Row fills (active surfaceEl2) are clipped by the card shape so they never
            // poke past the rounded corners.
            .clipShape(RoundedRectangle(cornerRadius: CornerTokens.card))
            .cardStyle(horizontalPadding: 0, verticalPadding: 0)
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.lg)

            Spacer().frame(height: Spacing.lg)
            Text("language.picker.footer")
                .font(.Tokens.smallLabel)
                .foregroundStyle(ColorTokens.text2)
                .padding(.horizontal, 16)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.background)
        .navigationTitle("language.picker.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func row(for locale: Locale) -> some View {
        let isActive = container.localeManager.activeLocale.identifier == locale.identifier
        Button {
            guard !isActive else { return }
            Haptics.select()
            container.localeManager.setLocale(locale)
        } label: {
            HStack {
                if isActive {
                    Image(systemName: "checkmark")
                        .frame(width: 24)
                        .foregroundStyle(ColorTokens.text1)
                } else {
                    Color.clear.frame(width: 24, height: 1)
                }
                Text(autonym(for: locale))
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(isActive ? ColorTokens.surfaceEl2 : ColorTokens.surfaceEl)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
    }

    private func autonym(for locale: Locale) -> String {
        switch locale.identifier {
        case "zh-Hans": return "中文(简体)"
        default:        return "English"
        }
    }
}
