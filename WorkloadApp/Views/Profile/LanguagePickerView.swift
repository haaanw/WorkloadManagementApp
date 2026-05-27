import SwiftUI

/// Push-navigation language picker. Renders an autonym row per supported locale,
/// with a checkmark on the active row. Tapping a row commits via LocaleManager.setLocale.
/// Live-renders immediately (no auto-pop) per UI-SPEC line 173.
/// Conforms to DESIGN.md: 0pt corners, no shadows, checkmark in text1 (never accent).
struct LanguagePickerView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
            ForEach(container.localeManager.supportedLocales, id: \.identifier) { locale in
                row(for: locale)
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
            }
            Spacer().frame(height: 64)
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
        Button {
            container.localeManager.setLocale(locale)
        } label: {
            HStack {
                if container.localeManager.activeLocale.identifier == locale.identifier {
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func autonym(for locale: Locale) -> String {
        switch locale.identifier {
        case "zh-Hans": return "中文(简体)"
        default:        return "English"
        }
    }
}
