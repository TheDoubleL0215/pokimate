import SwiftUI

enum CardHighlightStyle: Equatable {
    case none
    /// Kickers / fillers in the made five.
    case soft
    /// Cards that define the winning category (pair, trips, …).
    case strong

    static func style(
        for cardID: UUID,
        primary: Set<UUID>,
        secondary: Set<UUID>
    ) -> CardHighlightStyle {
        if primary.contains(cardID) { return .strong }
        if secondary.contains(cardID) { return .soft }
        return .none
    }
}

struct CardView: View {
    let card: Card?
    var faceDown: Bool = false
    var compact: Bool = false
    var highlight: CardHighlightStyle = .none

    private var width: CGFloat { compact ? 42 : 58 }
    private var height: CGFloat { compact ? 60 : 82 }

    private var isFaceDown: Bool { faceDown || card == nil }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }

    var body: some View {
        FlipContainer(angle: isFaceDown ? 180 : 0, front: side(showFace: true), back: side(showFace: false))
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
            .shadow(
                color: highlightGlow,
                radius: highlight == .strong ? 7 : (highlight == .soft ? 3 : 0)
            )
            .animation(.easeInOut(duration: 0.55), value: isFaceDown)
            .animation(.easeOut(duration: 0.35), value: highlight)
    }

    private var highlightGlow: Color {
        switch highlight {
        case .none: return .clear
        case .soft: return PokerTheme.winningCardStroke.opacity(0.22)
        case .strong: return PokerTheme.winningCardStroke.opacity(0.65)
        }
    }

    private func side(showFace: Bool) -> some View {
        cardShape
            .fill(showFace ? PokerTheme.cardFace : PokerTheme.cardBack)
            .overlay {
                if showFace {
                    faceContent
                } else {
                    backContent
                }
            }
            .clipShape(cardShape) // crops the overflowing watermark
            .overlay(
                cardShape.strokeBorder(highlightStroke, lineWidth: highlightLineWidth)
            )
    }

    private var highlightStroke: Color {
        switch highlight {
        case .none: return PokerTheme.cardStroke
        case .soft: return PokerTheme.winningCardStrokeSoft
        case .strong: return PokerTheme.winningCardStroke
        }
    }

    private var highlightLineWidth: CGFloat {
        switch highlight {
        case .none: return 1
        case .soft: return 1.5
        case .strong: return 2.75
        }
    }

    @ViewBuilder
    private var faceContent: some View {
        let plusOffset: CGFloat = 15
        if let card {
            Color.clear
                // Bottom-right: big faint suit symbol, bleeding off the corner
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: card.suit.outlineSymbolName)
                        .font(.system(size: compact ? 44 : 60))
                        .opacity(0.1)
                        .offset(x: compact ? plusOffset : plusOffset + 4,
                                y: compact ? plusOffset : plusOffset + 4)
                }
                // Top-left corner: symbol + number
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(card.rank.display)
                            .font(.system(size: compact ? 13+5 : 17+5, weight: .bold, design: .rounded))
                        Text(card.suit.symbol)
                            .font(.system(size: compact ? 11+5 : 14+5))
                    }
                    .padding(4)
                }
                .foregroundStyle(suitColor(for: card))
        }
    }

    private var backContent: some View {
        Image(systemName: "suit.spade.fill")
            .font(.system(size: compact ? 12 : 16))
            .foregroundStyle(Color.white.opacity(0.2))
    }

    private func suitColor(for card: Card) -> Color {
        switch card.suit {
        case .hearts, .diamonds: return PokerTheme.cardTextRed
        case .spades, .clubs:    return PokerTheme.cardText
        }
    }
}

/// Y-axis 3D flip; swaps to the back side once the card passes edge-on.
private struct FlipContainer<Front: View, Back: View>: View, Animatable {
    var angle: Double
    let front: Front
    let back: Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            if angle < 90 {
                front
            } else {
                back.scaleEffect(x: -1, y: 1)
            }
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
    }
}

// MARK: - Dealt card

/// A card that slides in from `dealFrom` (offset relative to its final spot) when it appears,
/// optionally flipping face-up after it lands.
struct DealtCardView: View {
    let card: Card
    var faceDown: Bool = false
    var compact: Bool = false
    var highlight: CardHighlightStyle = .none
    var dealFrom: CGSize = .zero
    var delay: Double = 0
    var flipOnLand: Bool = true

    @State private var arrived = false
    @State private var revealed = false

    var body: some View {
        CardView(
            card: card,
            faceDown: faceDown || (flipOnLand && !revealed),
            compact: compact,
            highlight: highlight
        )
        .rotationEffect(.degrees(arrived ? 0 : -30))
        .scaleEffect(arrived ? 1 : 0.6)
        .offset(arrived ? .zero : dealFrom)
        .opacity(arrived ? 1 : 0)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(delay)) {
                arrived = true
            }
        }
        .task {
            guard flipOnLand else { return }
            // Set after a sleep (not via withAnimation delay) so CardView's own flip animation runs on time.
            try? await Task.sleep(for: .seconds(delay + 0.4))
            revealed = true
        }
    }
}

extension Suit {
    var outlineSymbolName: String {
        switch self {
        case .spades:   return "suit.spade"
        case .hearts:   return "suit.heart"
        case .diamonds: return "suit.diamond"
        case .clubs:    return "suit.club"
        }
    }
}

#Preview {
    HStack {
        CardView(card: Card(suit: .spades, rank: .ace))
        CardView(card: Card(suit: .hearts, rank: .ten))
        CardView(card: nil, faceDown: true)
        DealtCardView(card: Card(suit: .clubs, rank: .king), dealFrom: CGSize(width: 0, height: -200))
    }
    .padding()
    .background(PokerTheme.background)
}
