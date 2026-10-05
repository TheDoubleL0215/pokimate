import SwiftUI

struct ContentView: View {
    @ObservedObject var engine: PokerGameEngine
    var onExitToMenu: (() -> Void)? = nil

    @EnvironmentObject private var l10n: LocalizationManager
    @State private var tableAppeared = false
    @State private var showCheatsheet = false

    var body: some View {
        ZStack {
            PokerTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                    .opacity(tableAppeared ? 1 : 0)

                GeometryReader { geo in
                    ovalTable(in: geo.size)
                }
                .opacity(tableAppeared ? 1 : 0)
                .scaleEffect(tableAppeared ? 1 : 0.96)
                .offset(y: tableAppeared ? 0 : 18)

                ActionBarView(
                    holeCards: engine.humanPlayer?.holeCards ?? [],
                    balance: engine.humanPlayer?.chips ?? 0,
                    isEnabled: engine.isHumanTurn,
                    callLabel: engine.callLabel,
                    toCallAmount: engine.toCallAmount,
                    profitPercent: engine.humanProfitPercent,
                    winStreak: engine.humanWinStreak,
                    hasChecked: engine.humanPlayer?.hasCheckedThisRound == true,
                    primaryHighlightedCardIDs: engine.primaryHighlightedCardIDs,
                    secondaryHighlightedCardIDs: engine.secondaryHighlightedCardIDs,
                    showContinue: engine.isAwaitingContinue,
                    continueTitle: l10n.t("action.continue"),
                    onFold: { engine.fold() },
                    onCheckOrCall: { engine.checkOrCall() },
                    onRaise: { engine.raise() },
                    onContinue: { engine.continueToNextHand() },
                    dealDelay: { cardIndex in
                        engine.humanPlayer.map { dealDelay(cardIndex: cardIndex, player: $0) } ?? 0
                    }
                )
                .padding(.horizontal, 8)
                .opacity(tableAppeared ? 1 : 0)
                .offset(y: tableAppeared ? 0 : 24)
                .animation(.easeInOut(duration: 0.2), value: engine.callLabel)
                .animation(.easeInOut(duration: 0.2), value: engine.currentHighestBet)
            }
        }
        .onAppear {
            tableAppeared = false
            withAnimation(.spring(response: 0.55, dampingFraction: 0.86).delay(0.04)) {
                tableAppeared = true
            }
        }
        .sheet(isPresented: $showCheatsheet) {
            HandCheatsheetView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(PokerTheme.background)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            GlassBackButton(accessibilityLabel: l10n.t("a11y.menu")) {
                engine.tearDown()
                onExitToMenu?()
            }

            Spacer()

            GlassIconButton(
                systemImage: "list.bullet.rectangle",
                accessibilityLabel: l10n.t("a11y.hand_rankings")
            ) {
                showCheatsheet = true
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Oval Table

    private func ovalTable(in size: CGSize) -> some View {
        let opponents = engine.players.filter { !$0.isHuman }
        let human = engine.humanPlayer
        let seats = seatLayout(opponents: opponents, human: human, size: size)

        return ZStack {
            Capsule()
                .fill(PokerTheme.tableRail)
                .overlay(
                    Capsule()
                        .strokeBorder(PokerTheme.tableRailHighlight, lineWidth: 1.5)
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 18)

            Capsule()
                .fill(
                    RadialGradient(
                        colors: [
                            PokerTheme.tableFeltLight,
                            PokerTheme.tableFelt,
                            Color.black.opacity(0.55)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: max(size.width, size.height) * 0.45
                    )
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
                .padding(.horizontal, 22)
                .padding(.vertical, 32)

            // Center: community cards + pot total (number only — no chip stacks)
            VStack(spacing: 10) {
                potLabel

                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { index in
                        if index < engine.communityCards.count {
                            DealtCardView(
                                card: engine.communityCards[index],
                                compact: true,
                                highlight: .style(
                                    for: engine.communityCards[index].id,
                                    primary: engine.primaryHighlightedCardIDs,
                                    secondary: engine.secondaryHighlightedCardIDs
                                ),
                                dealFrom: CGSize(width: 0, height: -50),
                                delay: index < 3 ? Double(index) * 0.18 : 0
                            )
                            .id(engine.communityCards[index].id)
                        } else {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(
                                    Color.white.opacity(0.1),
                                    style: StrokeStyle(lineWidth: 1, dash: [3])
                                )
                                .frame(width: 40, height: 56)
                        }
                    }
                }

                if engine.hasWinningHighlights || engine.isAwaitingContinue {
                    Text(engine.message)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(PokerTheme.winningCardStroke)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.black.opacity(0.55)))
                        .overlay(
                            Capsule().strokeBorder(PokerTheme.winningCardStroke.opacity(0.35), lineWidth: 1)
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                }
            }
            .animation(.easeOut(duration: 0.3), value: engine.hasWinningHighlights)
            .animation(.easeOut(duration: 0.3), value: engine.isAwaitingContinue)

            // Seats (fixed size — banners are layered separately so seats don't resize)
            ForEach(seats) { seat in
                self.seat(
                    for: seat.player,
                    compact: seat.compact,
                    scale: seat.scale,
                    dealFrom: CGSize(
                        width: size.width * 0.5 - seat.position.x,
                        height: size.height * 0.48 - seat.position.y
                    )
                )
                .position(seat.position)
            }

            // Decision bubbles float above seats without changing seat height
            ForEach(seats) { seat in
                if let banner = engine.actionBanners[seat.player.id] {
                    ActionBannerLabel(text: banner)
                        .position(
                            x: seat.position.x,
                            y: seat.position.y - bannerOffset(for: seat)
                        )
                        .zIndex(20)
                }
            }

            // Chips stay in front of each player for the whole hand
            ForEach(seats) { seat in
                AnimatedPlayerBetChips(
                    amount: seat.player.totalBetThisHand,
                    seatPosition: seat.position,
                    betPosition: betPosition(for: seat.position, in: size),
                    chipSize: seat.compact ? 16 : 20
                )
            }

            ForEach(engine.potAwards) { award in
                if let winnerSeat = seats.first(where: { $0.player.id == award.playerID }) {
                    PotAwardChips(
                        amount: award.amount,
                        from: CGPoint(x: size.width * 0.5, y: size.height * 0.48),
                        to: winnerSeat.position
                    )
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var potLabel: some View {
        HStack(spacing: 6) {
            Text(l10n.t("table.pot"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(PokerTheme.textSecondary)
            Text("$\(engine.pot)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PokerTheme.textPrimary)
                .contentTransition(.numericText(value: Double(engine.pot)))
                .animation(.snappy, value: engine.pot)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.black.opacity(0.45)))
    }

    // MARK: - Seat / bet layout

    private struct SeatPlacement: Identifiable {
        var id: UUID { player.id }
        let player: Player
        let position: CGPoint
        let compact: Bool
        let scale: CGFloat
    }

    private func seatLayout(opponents: [Player], human: Player?, size: CGSize) -> [SeatPlacement] {
        let w = size.width
        let h = size.height
        var seats: [SeatPlacement] = []
        let crowdScale: CGFloat = {
            switch opponents.count {
            case 0...2: return 1.0
            case 3: return 0.92
            case 4: return 0.8
            default: return 0.7
            }
        }()

        switch opponents.count {
        case 1:
            seats.append(SeatPlacement(player: opponents[0], position: CGPoint(x: w * 0.5, y: h * 0.12), compact: true, scale: crowdScale))
        case 2:
            seats.append(SeatPlacement(player: opponents[0], position: CGPoint(x: w * 0.14, y: h * 0.26), compact: true, scale: crowdScale))
            seats.append(SeatPlacement(player: opponents[1], position: CGPoint(x: w * 0.86, y: h * 0.26), compact: true, scale: crowdScale))
        case 3:
            seats.append(SeatPlacement(player: opponents[0], position: CGPoint(x: w * 0.5, y: h * 0.09), compact: true, scale: crowdScale))
            seats.append(SeatPlacement(player: opponents[1], position: CGPoint(x: w * 0.14, y: h * 0.36), compact: true, scale: crowdScale))
            seats.append(SeatPlacement(player: opponents[2], position: CGPoint(x: w * 0.86, y: h * 0.36), compact: true, scale: crowdScale))
        case 4:
            seats.append(SeatPlacement(player: opponents[0], position: CGPoint(x: w * 0.26, y: h * 0.09), compact: true, scale: crowdScale))
            seats.append(SeatPlacement(player: opponents[1], position: CGPoint(x: w * 0.74, y: h * 0.09), compact: true, scale: crowdScale))
            seats.append(SeatPlacement(player: opponents[2], position: CGPoint(x: w * 0.14, y: h * 0.38), compact: true, scale: crowdScale))
            seats.append(SeatPlacement(player: opponents[3], position: CGPoint(x: w * 0.86, y: h * 0.38), compact: true, scale: crowdScale))
        default: // 5+
            let shown = Array(opponents.prefix(5))
            seats.append(SeatPlacement(player: shown[0], position: CGPoint(x: w * 0.5, y: h * 0.07), compact: true, scale: crowdScale))
            seats.append(SeatPlacement(player: shown[1], position: CGPoint(x: w * 0.16, y: h * 0.18), compact: true, scale: crowdScale))
            seats.append(SeatPlacement(player: shown[2], position: CGPoint(x: w * 0.84, y: h * 0.18), compact: true, scale: crowdScale))
            seats.append(SeatPlacement(player: shown[3], position: CGPoint(x: w * 0.14, y: h * 0.4), compact: true, scale: crowdScale))
            seats.append(SeatPlacement(player: shown[4], position: CGPoint(x: w * 0.86, y: h * 0.4), compact: true, scale: crowdScale))
        }

        if let human {
            seats.append(SeatPlacement(player: human, position: CGPoint(x: w * 0.5, y: h * 0.9), compact: false, scale: 1))
        }

        return seats
    }

    private func bannerOffset(for seat: SeatPlacement) -> CGFloat {
        // Keep the bubble just above the seat card, independent of seat layout scale.
        let base: CGFloat = seat.player.isHuman ? 28 : (seat.compact ? 58 : 72)
        return base * seat.scale + 18
    }

    /// Place chips just in front of the player (closer to seat than to center).
    private func betPosition(for seat: CGPoint, in size: CGSize) -> CGPoint {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.48)
        let t: CGFloat = 0.5 // 0 = at seat, 1 = at center
        return CGPoint(
            x: seat.x + (center.x - seat.x) * t,
            y: seat.y + (center.y - seat.y) * t
        )
    }

    /// Clockwise from the seat left of the dealer, one card per player per pass.
    private func dealDelay(cardIndex: Int, player: Player) -> Double {
        let n = engine.players.count
        guard n > 0, let idx = engine.players.firstIndex(where: { $0.id == player.id }) else { return 0 }
        let order = (idx - engine.dealerIndex - 1 + n) % n
        return Double(cardIndex * n + order) * 0.12
    }

    @ViewBuilder
    private func seat(for player: Player, compact: Bool, scale: CGFloat, dealFrom: CGSize) -> some View {
        let isDealer = engine.players.firstIndex(where: { $0.id == player.id }) == engine.dealerIndex
        let isRevealed = engine.revealedShowdownIDs.contains(player.id)
        let handName = engine.showdownResults[player.id]?.category.displayName

        if player.isHuman {
            humanTableMarker(
                isDealer: isDealer,
                showdownHand: handName
            )
        } else {
            let isActiveTurn =
                engine.isHandInProgress
                && engine.phase != .waiting
                && engine.phase != .showdown
                && engine.activePlayer?.id == player.id

            PlayerSeatView(
                player: player,
                isDealer: isDealer,
                revealCards: isRevealed,
                showdownHand: handName,
                primaryHighlightedCardIDs: engine.primaryHighlightedCardIDs,
                secondaryHighlightedCardIDs: engine.secondaryHighlightedCardIDs,
                isActiveTurn: isActiveTurn,
                compact: compact,
                scale: scale,
                dealFrom: dealFrom,
                dealDelay: { dealDelay(cardIndex: $0, player: player) }
            )
        }
    }

    /// Compact marker at the bottom of the oval for the human (cards are in ActionBar).
    @ViewBuilder
    private func humanTableMarker(
        isDealer: Bool,
        showdownHand: String?
    ) -> some View {
        VStack(spacing: 6) {
            if isDealer {
                Text("D")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(PokerTheme.brandBlue))
            }

            if let showdownHand {
                Text(showdownHand)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(PokerTheme.raiseText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(PokerTheme.raiseFill))
                    .overlay(Capsule().strokeBorder(PokerTheme.raiseText.opacity(0.35), lineWidth: 1))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.35), value: showdownHand)
    }


}

#Preview {
    ContentView(engine: PokerGameEngine())
        .environmentObject(LocalizationManager.shared)
}
