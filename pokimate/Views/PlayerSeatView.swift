import SwiftUI

struct PlayerSeatView: View {
    let player: Player
    var isDealer: Bool
    var revealCards: Bool
    var showdownHand: String?
    var primaryHighlightedCardIDs: Set<UUID> = []
    var secondaryHighlightedCardIDs: Set<UUID> = []
    var isActiveTurn: Bool = false
    var compact: Bool = false
    /// Visual scale for crowded tables (banners stay outside, unscaled separately).
    var scale: CGFloat = 1
    /// Offset from the seat to where cards are dealt from (table center).
    var dealFrom: CGSize = .zero
    var dealDelay: (Int) -> Double = { _ in 0 }

    @EnvironmentObject private var l10n: LocalizationManager

    private var cardHeight: CGFloat { compact ? 44 : 60 }
    private var cardSpacing: CGFloat { compact ? 2 : 3 }

    var body: some View {
        VStack(spacing: compact ? 4 : 8) {
            HStack(spacing: 4) {
                if isDealer {
                    Text("D")
                        .font(.system(size: compact ? 8 : 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, compact ? 5 : 7)
                        .padding(.vertical, compact ? 2 : 3)
                        .background(Capsule().fill(PokerTheme.brandBlue))
                }

                Text(player.name)
                    .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                    .foregroundStyle(PokerTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Group {
                if player.isFolded {
                    Text(l10n.t("player.folded"))
                        .font(.system(size: compact ? 9 : 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(PokerTheme.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else if player.holeCards.count == 2 {
                    HStack(spacing: cardSpacing) {
                        ForEach(Array(player.holeCards.enumerated()), id: \.element.id) { index, card in
                            DealtCardView(
                                card: card,
                                faceDown: !revealCards && !player.isHuman,
                                compact: true,
                                highlight: revealCards
                                    ? .style(
                                        for: card.id,
                                        primary: primaryHighlightedCardIDs,
                                        secondary: secondaryHighlightedCardIDs
                                    )
                                    : .none,
                                dealFrom: dealFrom,
                                delay: dealDelay(index),
                                flipOnLand: false
                            )
                        }
                    }
                    .scaleEffect(compact ? 0.78 : 1)
                    .frame(height: cardHeight)
                } else {
                    HStack(spacing: cardSpacing) {
                        CardView(card: nil, faceDown: true, compact: true)
                            .opacity(0.25)
                        CardView(card: nil, faceDown: true, compact: true)
                            .opacity(0.25)
                    }
                    .scaleEffect(compact ? 0.78 : 1)
                    .frame(height: cardHeight)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: player.isFolded)

            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: compact ? 12 : 14))
                    .foregroundStyle(PokerTheme.brandBlue)
                Text("\(player.chips)")
                    .font(compact ? .caption.weight(.semibold) : .footnote.weight(.semibold))
                    .foregroundStyle(PokerTheme.turnGlow)
                    .contentTransition(.numericText(value: Double(player.chips)))
                    .animation(.snappy, value: player.chips)
            }

            if let showdownHand {
                Text(showdownHand)
                    .font(.system(size: compact ? 9 : 11, weight: .bold, design: .rounded))
                    .foregroundStyle(PokerTheme.raiseText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(PokerTheme.raiseFill))
                    .overlay(Capsule().strokeBorder(PokerTheme.raiseText.opacity(0.35), lineWidth: 1))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.35), value: showdownHand)
        .padding(compact ? 6 : 10)
        .background(
            RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous)
                .fill(PokerTheme.surface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous)
                .strokeBorder(
                    isActiveTurn ? PokerTheme.turnGlow.opacity(0.95) : PokerTheme.cardStroke,
                    lineWidth: isActiveTurn ? 2.5 : 1
                )
            if isActiveTurn {
                RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
                    .stroke(PokerTheme.turnGlow.opacity(0.35), lineWidth: 6)
            }
        }
        .overlay(alignment: .topTrailing) {
            if player.hasCheckedThisRound && !player.isFolded {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: compact ? 11 : 12, weight: .semibold))
                    .foregroundStyle(PokerTheme.callText)
                    .padding(5)
                    .background(Circle().fill(PokerTheme.foldFill))
                    .overlay(Circle().strokeBorder(PokerTheme.callText.opacity(0.35), lineWidth: 1))
                    .offset(x: 6, y: -6)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: player.hasCheckedThisRound)
        .animation(.easeInOut(duration: 0.2), value: isActiveTurn)
        .shadow(color: .black.opacity(0.5), radius: compact ? 4 : 6, y: 3)
        .scaleEffect(scale)
    }
}

/// Floating decision label rendered outside the seat card.
struct ActionBannerLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(PokerTheme.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.78)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
            .transition(.opacity.combined(with: .scale(scale: 0.92)))
    }
}
