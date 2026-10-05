import SwiftUI

@main
struct MyApp: App {
    private enum Screen {
        case mainMenu
        case setup
        case stats
        case settings
        case playing(PokerGameEngine)
    }

    /// Drives asymmetric transitions between menu / setup / table.
    private enum NavStyle {
        case push
        case pop
        case enterGame
        case leaveGame
    }

    @ObservedObject private var localization = LocalizationManager.shared
    @State private var screen: Screen = .mainMenu
    @State private var navStyle: NavStyle = .push

    var body: some Scene {
        WindowGroup {
            ZStack {
                switch screen {
                case .mainMenu:
                    MainMenuView(
                        onNewGame: { go(to: .setup, style: .push) },
                        onStats: { go(to: .stats, style: .push) },
                        onSettings: { go(to: .settings, style: .push) }
                    )
                    .transition(screenTransition)

                case .setup:
                    SetupMenuView(
                        onBack: { go(to: .mainMenu, style: .pop) },
                        onStart: { startingChips, baseBet, useBlinds, botCount in
                            let engine = PokerGameEngine(
                                humanName: localization.t("player.you"),
                                aiCount: botCount,
                                startingChips: startingChips,
                                baseBet: baseBet,
                                blindsEnabled: useBlinds
                            )
                            go(to: .playing(engine), style: .enterGame)
                        }
                    )
                    .transition(screenTransition)

                case .stats:
                    StatsRootView {
                        go(to: .mainMenu, style: .pop)
                    }
                    .transition(screenTransition)

                case .settings:
                    SettingsView {
                        go(to: .mainMenu, style: .pop)
                    }
                    .transition(screenTransition)

                case .playing(let engine):
                    ContentView(engine: engine) {
                        engine.tearDown()
                        go(to: .mainMenu, style: .leaveGame)
                    }
                    .transition(screenTransition)
                    .onAppear {
                        if engine.phase == .waiting {
                            engine.startHand()
                        }
                    }
                }
            }
            .environmentObject(localization)
            .environment(\.locale, localization.locale)
            .id(localization.language)
            .preferredColorScheme(.dark)
        }
    }

    private func go(to next: Screen, style: NavStyle) {
        navStyle = style
        withAnimation(animation(for: style)) {
            screen = next
        }
    }

    private func animation(for style: NavStyle) -> Animation {
        switch style {
        case .push, .pop:
            return .spring(response: 0.42, dampingFraction: 0.88)
        case .enterGame:
            return .spring(response: 0.52, dampingFraction: 0.86)
        case .leaveGame:
            return .easeInOut(duration: 0.32)
        }
    }

    private var screenTransition: AnyTransition {
        switch navStyle {
        case .push:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .offset(x: -36).combined(with: .opacity).combined(with: .scale(scale: 0.98))
            )
        case .pop:
            return .asymmetric(
                insertion: .offset(x: -36).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        case .enterGame:
            return .asymmetric(
                insertion: .opacity
                    .combined(with: .scale(scale: 1.04))
                    .combined(with: .offset(y: 28)),
                removal: .opacity.combined(with: .scale(scale: 0.94))
            )
        case .leaveGame:
            return .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                removal: .opacity.combined(with: .scale(scale: 1.03))
            )
        }
    }
}
