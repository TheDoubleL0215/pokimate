import SwiftUI

struct MainMenuView: View {
    var onNewGame: () -> Void
    var onStats: () -> Void
    var onSettings: () -> Void

    @EnvironmentObject private var l10n: LocalizationManager
    @State private var logoAppeared = false

    var body: some View {
        ZStack {
            MenuBackground()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    GlassIconButton(
                        systemImage: "gearshape.fill",
                        accessibilityLabel: l10n.t("a11y.settings"),
                        action: onSettings
                    )
                }
                .padding(.top, 12)
                .padding(.horizontal, 12)

                Spacer(minLength: 12)

                Image("pokimate_header_nobg")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 340)
                    .shadow(color: PokerTheme.brandBlue.opacity(0.35), radius: 24, y: 10)
                    .scaleEffect(logoAppeared ? 1 : 0.92)
                    .opacity(logoAppeared ? 1 : 0)

                Spacer(minLength: 40)

                VStack(spacing: 12) {
                    GameCapsuleButton(title: l10n.t("menu.new_game")) {
                        onNewGame()
                    }
                    GameCapsuleButton(
                        title: l10n.t("menu.stats"),
                        fill: PokerTheme.foldFill,
                        text: PokerTheme.textPrimary
                    ) {
                        onStats()
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                logoAppeared = true
            }
        }
    }
}

#Preview {
    MainMenuView(onNewGame: {}, onStats: {}, onSettings: {})
        .environmentObject(LocalizationManager.shared)
        .preferredColorScheme(.dark)
}
