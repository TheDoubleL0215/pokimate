import SwiftUI

/// New-game setup: base bet, starting chips, optional blinds.
struct SetupMenuView: View {
    var onBack: () -> Void
    var onStart: (_ startingChips: Int, _ baseBet: Int, _ useBlinds: Bool, _ botCount: Int) -> Void

    @EnvironmentObject private var l10n: LocalizationManager
    @State private var baseBet: Int = 20
    @State private var startingChips: Int = 500
    @State private var useBlinds: Bool = true
    @State private var botCount: Int = 2
    @State private var contentAppeared = false

    private let betOptions = [20, 40, 100, 200]
    private let chipOptions = [200, 500, 1_000, 2_000, 5_000]
    private let botOptions = [2, 3, 4, 5]

    private var smallBlind: Int { baseBet / 2 }

    private var canStart: Bool {
        startingChips >= baseBet * 4
    }

    var body: some View {
        ZStack {
            MenuBackground()

            VStack(spacing: 0) {
                header
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : -8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        Image("pokimate_header_nobg")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 220)
                            .shadow(color: PokerTheme.brandBlue.opacity(0.3), radius: 16, y: 6)
                            .padding(.top, 8)
                            .opacity(contentAppeared ? 1 : 0)
                            .scaleEffect(contentAppeared ? 1 : 0.94)

                        MenuPanel {
                            VStack(spacing: 22) {
                                settingSection(
                                    title: l10n.t("setup.base_bet"),
                                    subtitle: useBlinds
                                        ? l10n.format("setup.blinds_sb_bb", smallBlind, baseBet)
                                        : l10n.format("setup.raise_unit", baseBet)
                                ) {
                                    steppedValueSelector(selection: $baseBet, options: betOptions)
                                }

                                softDivider

                                settingSection(
                                    title: l10n.t("setup.starting_chips"),
                                    subtitle: l10n.format("setup.starting_chips_subtitle", startingChips)
                                ) {
                                    steppedValueSelector(selection: $startingChips, options: chipOptions)
                                }

                                softDivider

                                settingSection(
                                    title: l10n.t("setup.bots"),
                                    subtitle: l10n.format("setup.bots_subtitle", botCount)
                                ) {
                                    optionRow(options: botOptions, selection: $botCount)
                                }

                                softDivider

                                MenuToggleRow(
                                    title: l10n.t("setup.blinds"),
                                    subtitle: useBlinds
                                        ? l10n.t("setup.blinds_on")
                                        : l10n.t("setup.blinds_off"),
                                    isOn: $useBlinds
                                )

                                if !canStart {
                                    Text(l10n.t("setup.chips_rule"))
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(PokerTheme.foldText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 22)

                        GameCapsuleButton(title: l10n.t("setup.sit_down"), enabled: canStart) {
                            onStart(startingChips, baseBet, useBlinds, botCount)
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 36)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 28)
                    }
                }
            }
        }
        .onAppear {
            contentAppeared = false
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84).delay(0.05)) {
                contentAppeared = true
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
        }
    }

    private var softDivider: some View {
        Rectangle()
            .fill(PokerTheme.cardStroke)
            .frame(height: 1)
    }

    private func settingSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(PokerTheme.textSecondary)

            content()

            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(PokerTheme.textSecondary)
        }
    }

    private func steppedValueSelector(selection: Binding<Int>, options: [Int]) -> some View {
        let index = options.firstIndex(of: selection.wrappedValue) ?? 0
        let canGoPrev = index > 0
        let canGoNext = index < options.count - 1

        return HStack(spacing: 12) {
            stepArrowButton(systemName: "chevron.left", enabled: canGoPrev) {
                guard canGoPrev else { return }
                selection.wrappedValue = options[index - 1]
            }

            Text("\(selection.wrappedValue)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(PokerTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(PokerTheme.foldFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(PokerTheme.cardStroke, lineWidth: 1)
                        )
                )
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: selection.wrappedValue)

            stepArrowButton(systemName: "chevron.right", enabled: canGoNext) {
                guard canGoNext else { return }
                selection.wrappedValue = options[index + 1]
            }
        }
    }

    private func stepArrowButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(enabled ? PokerTheme.textPrimary : PokerTheme.textSecondary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(PokerTheme.foldFill)
                        .overlay(
                            Circle()
                                .strokeBorder(PokerTheme.cardStroke, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    private func optionRow(options: [Int], selection: Binding<Int>) -> some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { value in
                GameCapsuleChip(
                    title: "\(value)",
                    isSelected: selection.wrappedValue == value
                ) {
                    selection.wrappedValue = value
                }
            }
        }
    }
}

#Preview {
    SetupMenuView(onBack: {}, onStart: { _, _, _, _ in })
        .environmentObject(LocalizationManager.shared)
        .preferredColorScheme(.dark)
}
