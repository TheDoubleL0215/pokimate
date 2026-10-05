import SwiftUI

/// Bottom panel matching the mockup: hole cards + balance on the left,
/// vertical capsule actions (Fold / Raise / Call) on the right.
struct ActionBarView: View {
    let holeCards: [Card]
    let balance: Int
    let isEnabled: Bool
    let callLabel: String
    var toCallAmount: Int = 0
    var profitPercent: Double = 0
    var winStreak: Int = 0
    var hasChecked: Bool = false
    var primaryHighlightedCardIDs: Set<UUID> = []
    var secondaryHighlightedCardIDs: Set<UUID> = []
    var showContinue: Bool = false
    var continueTitle: String = ""
    let onFold: () -> Void
    let onCheckOrCall: () -> Void
    let onRaise: () -> Void
    var onContinue: (() -> Void)? = nil
    var dealDelay: (Int) -> Double = { _ in 0 }

    @EnvironmentObject private var l10n: LocalizationManager

    private let holdDuration: Double = 0.8

    @State private var callArmed = false

    private var resolvedContinueTitle: String {
        continueTitle.isEmpty ? l10n.t("action.continue") : continueTitle
    }

    private var isCheckAction: Bool {
        toCallAmount <= 0
    }

    private var profitColor: Color {
        profitPercent >= 0 ? Color(hex: 0x3DBE6E) : PokerTheme.foldText
    }

    private var profitIcon: String {
        profitPercent >= 0
            ? "chart.line.uptrend.xyaxis"
            : "chart.line.downtrend.xyaxis"
    }

    private var profitLabel: String {
        let absValue = abs(profitPercent)
        let formatted = absValue >= 10
            ? String(format: "%.0f", absValue)
            : String(format: "%.1f", absValue)
        let sign = profitPercent >= 0 ? "+" : "−"
        return "\(sign)\(formatted)%"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            playerInfo
                .frame(maxWidth: .infinity)

            Group {
                if showContinue {
                    continueColumn
                } else {
                    actionColumn
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 200)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(PokerTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(PokerTheme.cardStroke, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: showContinue)
        .onAppear {
            Haptics.prepare()
        }
        .onChange(of: isEnabled) { _, enabled in
            if enabled {
                Haptics.yourTurn()
            } else {
                callArmed = false
            }
        }
        .onChange(of: callLabel) { _, _ in
            callArmed = false
        }
    }

    private var continueColumn: some View {
        VStack {
            Spacer(minLength: 0)
            GameCapsuleButton(title: resolvedContinueTitle, text: PokerTheme.winningCardStroke) {
                onContinue?()
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Left: cards + balance

    private var playerInfo: some View {
        VStack(spacing: 6) {
            if winStreak > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xF0953A))
                    
                    Text("\(winStreak)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: 0xF0953A))
                        .contentTransition(.numericText(value: Double(winStreak)))
                }
                .transition(.scale.combined(with: .opacity)) // Opcionális: szép ki/be lebegő animáció
                .animation(.snappy, value: winStreak)
            }
            
            fannedHoleCards

            VStack(spacing: 3) {
                
                
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(PokerTheme.brandBlue)
                    Text("\(balance)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(PokerTheme.textPrimary)
                        .contentTransition(.numericText(value: Double(balance)))
                        .animation(.snappy, value: balance)
                }

                VStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: profitIcon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(profitLabel)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .contentTransition(.numericText(value: profitPercent))
                    }
                    .foregroundStyle(profitColor)
                    .animation(.snappy, value: profitPercent)

                    
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if hasChecked {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PokerTheme.callText)
                    .padding(6)
                    .background(Circle().fill(PokerTheme.foldFill))
                    .overlay(Circle().strokeBorder(PokerTheme.callText.opacity(0.35), lineWidth: 1))
                    .offset(x: 4, y: -4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: hasChecked)
    }

    private var fannedHoleCards: some View {
        let scale: CGFloat = 1.25

        return ZStack {
            cardAt(index: 0)
                .offset(x: -16, y: 0)
            cardAt(index: 1)
                .offset(x: 16, y: 0)
        }
        .scaleEffect(scale)
        .frame(width: 120 * scale, height: 92 * scale)
    }

    @ViewBuilder
    private func cardAt(index: Int) -> some View {
        if holeCards.indices.contains(index) {
            DealtCardView(
                card: holeCards[index],
                highlight: .style(
                    for: holeCards[index].id,
                    primary: primaryHighlightedCardIDs,
                    secondary: secondaryHighlightedCardIDs
                ),
                dealFrom: CGSize(width: 0, height: -260),
                delay: dealDelay(index)
            )
            .id(holeCards[index].id)
        } else {
            CardView(card: nil, faceDown: true)
                .opacity(0.25)
        }
    }

    // MARK: - Right: capsule buttons

    private var actionColumn: some View {
        VStack(spacing: 8) {
            HoldToConfirmButton(
                title: l10n.t("action.fold"),
                systemImage: "xmark",
                fill: PokerTheme.foldFill,
                progressFill: PokerTheme.foldText.opacity(0.35),
                text: PokerTheme.foldText,
                holdDuration: holdDuration,
                hapticKind: .fold,
                onHoldStart: { callArmed = false },
                action: onFold
            )
            HoldToConfirmButton(
                title: l10n.t("action.raise"),
                systemImage: "chevron.up.2",
                fill: PokerTheme.raiseFill,
                progressFill: PokerTheme.raiseText.opacity(0.35),
                text: PokerTheme.raiseText,
                holdDuration: holdDuration,
                hapticKind: .raise,
                onHoldStart: { callArmed = false },
                action: onRaise
            )
            DoubleTapConfirmButton(
                title: callLabel.uppercased(),
                confirmTitle: l10n.format("action.confirm_fmt", callLabel.uppercased()),
                confirmWord: l10n.t("action.confirm"),
                callWord: l10n.t("action.call_short"),
                showsCheckIcon: isCheckAction,
                callAmount: isCheckAction ? nil : toCallAmount,
                fill: PokerTheme.callFill,
                armedFill: PokerTheme.callText.opacity(0.28),
                text: PokerTheme.callText,
                isArmed: $callArmed,
                action: onCheckOrCall
            )
            .id(callLabel)
        }
        .opacity(isEnabled ? 1 : 0.4)
        .frame(maxHeight: .infinity)
        .disabled(!isEnabled)
        .animation(.easeInOut(duration: 0.2), value: callLabel)
        .animation(.easeInOut(duration: 0.2), value: callArmed)
    }
}

// MARK: - Hold to confirm (Fold / Raise)

private struct HoldToConfirmButton: View {
    let title: String
    var systemImage: String? = nil
    let fill: Color
    let progressFill: Color
    let text: Color
    let holdDuration: Double
    var hapticKind: HoldHapticPlayer.Kind = .fold
    var onHoldStart: () -> Void = {}
    let action: () -> Void

    @State private var progress: CGFloat = 0
    @State private var didFire = false
    @State private var hapticPlayer = HoldHapticPlayer()

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .heavy))
                }
                Text(title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Capsule()
                    .fill(fill)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(progressFill)
                            .frame(width: max(0, geo.size.width * progress))
                    }
                    .clipShape(Capsule())
            }
            .overlay(Capsule().strokeBorder(text.opacity(0.25), lineWidth: 1))
            .contentShape(Capsule())
            .onLongPressGesture(
                minimumDuration: holdDuration,
                maximumDistance: 64,
                pressing: { pressing in
                    if pressing {
                        beginHold()
                    } else {
                        cancelHold()
                    }
                },
                perform: {
                    completeHold()
                }
            )
        }
    }

    private func beginHold() {
        guard !didFire else { return }
        onHoldStart()
        didFire = false
        progress = 0
        hapticPlayer.start(kind: hapticKind, duration: holdDuration)
        withAnimation(.linear(duration: holdDuration)) {
            progress = 1
        }
    }

    private func completeHold() {
        guard !didFire else { return }
        didFire = true
        hapticPlayer.stop()
        Haptics.holdComplete()
        progress = 0
        action()
        // Allow another hold after the finger lifts (`cancelHold` resets `didFire`).
    }

    private func cancelHold() {
        hapticPlayer.stop()
        if !didFire {
            withAnimation(.easeOut(duration: 0.15)) {
                progress = 0
            }
        }
        didFire = false
    }
}

// MARK: - Double tap confirm (Check / Call)

private struct DoubleTapConfirmButton: View {
    let title: String
    let confirmTitle: String
    var confirmWord: String = "CONFIRM"
    var callWord: String = "CALL"
    var showsCheckIcon: Bool = false
    var callAmount: Int? = nil
    let fill: Color
    let armedFill: Color
    let text: Color
    @Binding var isArmed: Bool
    let action: () -> Void

    var body: some View {
        Button {
            if isArmed {
                Haptics.checkConfirm()
                isArmed = false
                action()
            } else {
                Haptics.checkArm()
                isArmed = true
            }
        } label: {
            HStack(spacing: 5) {
                if showsCheckIcon {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 13, weight: .semibold))
                }

                if let callAmount {
                    if isArmed {
                        Text(confirmWord)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                    }
                    Text("$")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(PokerTheme.callText)
                    Text("\(callAmount)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText(value: Double(callAmount)))
                    Text(callWord)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                } else {
                    Text(isArmed ? confirmTitle : title)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                }
            }
            .foregroundStyle(text)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 6)
            .background {
                Capsule()
                    .fill(fill)
                    .overlay {
                        if isArmed {
                            Capsule().fill(armedFill)
                        }
                    }
            }
            .overlay(
                Capsule()
                    .strokeBorder(text.opacity(isArmed ? 0.55 : 0.25), lineWidth: isArmed ? 1.5 : 1)
            )
            .contentTransition(.opacity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        Spacer()
        ActionBarView(
            holeCards: [
                Card(suit: .spades, rank: .ace),
                Card(suit: .hearts, rank: .ten)
            ],
            balance: 300,
            isEnabled: true,
            callLabel: "Call 10",
            toCallAmount: 10,
            onFold: {},
            onCheckOrCall: {},
            onRaise: {}
        )
        .padding(.horizontal)
        .environmentObject(LocalizationManager.shared)
    }
    .background(PokerTheme.background)
}
