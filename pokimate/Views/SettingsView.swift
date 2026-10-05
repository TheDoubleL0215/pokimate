import SwiftUI

struct SettingsView: View {
    var onBack: () -> Void

    @EnvironmentObject private var l10n: LocalizationManager

    var body: some View {
        ZStack {
            MenuBackground()

            VStack(spacing: 0) {
                header
                    .padding(.top, 12)
                    .padding(.horizontal, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        MenuPanel {
                            VStack(alignment: .leading, spacing: 14) {
                                Text(l10n.t("settings.language").uppercased())
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .tracking(1.2)
                                    .foregroundStyle(PokerTheme.textSecondary)

                                Text(l10n.t("settings.language_subtitle"))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(PokerTheme.textSecondary)

                                VStack(spacing: 8) {
                                    ForEach(AppLanguage.allCases) { language in
                                        languageRow(language)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 36)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            GlassBackButton(
                accessibilityLabel: l10n.t("a11y.back"),
                action: onBack
            )

            Spacer()

            Text(l10n.t("settings.title"))
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(PokerTheme.textPrimary)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
    }

    private func languageRow(_ language: AppLanguage) -> some View {
        let selected = l10n.language == language
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                l10n.language = language
            }
        } label: {
            HStack(spacing: 12) {
                Text(language.displayName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(selected ? PokerTheme.brandBlue : PokerTheme.textPrimary)

                Spacer(minLength: 8)

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PokerTheme.brandBlue)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(PokerTheme.foldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        selected ? PokerTheme.brandBlue.opacity(0.45) : PokerTheme.cardStroke,
                        lineWidth: selected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView(onBack: {})
        .environmentObject(LocalizationManager.shared)
        .preferredColorScheme(.dark)
}
