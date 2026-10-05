import SwiftUI

/// In-game reference: the ten poker hands, strongest first, each with a sample.
struct HandCheatsheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager

    private let hands: [HandCategory] = HandCategory.allCases.reversed()

    var body: some View {
        ZStack {
            PokerTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        Text(l10n.t("cheatsheet.order"))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .tracking(1.1)
                            .foregroundStyle(PokerTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 4)

                        ForEach(Array(hands.enumerated()), id: \.element) { index, category in
                            handRow(rank: index + 1, category: category)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            GlassBackButton(accessibilityLabel: l10n.t("a11y.close"), action: { dismiss() })

            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.t("cheatsheet.title"))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(PokerTheme.textPrimary)
                Text(l10n.t("cheatsheet.subtitle"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(PokerTheme.textSecondary)
            }

            Spacer()
        }
    }

    private func handRow(rank: Int, category: HandCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("\(rank)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(PokerTheme.winningCardStroke)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(PokerTheme.winningCardStroke.opacity(0.14)))

                Text(category.displayName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(PokerTheme.textPrimary)

                Spacer(minLength: 0)
            }

            HStack(spacing: 4) {
                ForEach(category.cheatsheetExample) { card in
                    CardView(card: card, compact: true)
                        .scaleEffect(0.86)
                        .frame(width: 36, height: 52)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PokerTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(PokerTheme.cardStroke, lineWidth: 1)
        )
    }
}

extension HandCategory {
    /// Fixed sample five for the cheatsheet (strongest → weakest list order is separate).
    var cheatsheetExample: [Card] {
        switch self {
        case .royalFlush:
            return [
                Card(suit: .spades, rank: .ace),
                Card(suit: .spades, rank: .king),
                Card(suit: .spades, rank: .queen),
                Card(suit: .spades, rank: .jack),
                Card(suit: .spades, rank: .ten)
            ]
        case .straightFlush:
            return [
                Card(suit: .hearts, rank: .nine),
                Card(suit: .hearts, rank: .eight),
                Card(suit: .hearts, rank: .seven),
                Card(suit: .hearts, rank: .six),
                Card(suit: .hearts, rank: .five)
            ]
        case .fourOfAKind:
            return [
                Card(suit: .clubs, rank: .ace),
                Card(suit: .diamonds, rank: .ace),
                Card(suit: .hearts, rank: .ace),
                Card(suit: .spades, rank: .ace),
                Card(suit: .clubs, rank: .king)
            ]
        case .fullHouse:
            return [
                Card(suit: .spades, rank: .king),
                Card(suit: .hearts, rank: .king),
                Card(suit: .diamonds, rank: .king),
                Card(suit: .clubs, rank: .nine),
                Card(suit: .spades, rank: .nine)
            ]
        case .flush:
            return [
                Card(suit: .diamonds, rank: .ace),
                Card(suit: .diamonds, rank: .jack),
                Card(suit: .diamonds, rank: .eight),
                Card(suit: .diamonds, rank: .six),
                Card(suit: .diamonds, rank: .three)
            ]
        case .straight:
            return [
                Card(suit: .clubs, rank: .ten),
                Card(suit: .diamonds, rank: .nine),
                Card(suit: .spades, rank: .eight),
                Card(suit: .hearts, rank: .seven),
                Card(suit: .clubs, rank: .six)
            ]
        case .threeOfAKind:
            return [
                Card(suit: .spades, rank: .queen),
                Card(suit: .hearts, rank: .queen),
                Card(suit: .diamonds, rank: .queen),
                Card(suit: .clubs, rank: .eight),
                Card(suit: .spades, rank: .three)
            ]
        case .twoPair:
            return [
                Card(suit: .spades, rank: .jack),
                Card(suit: .hearts, rank: .jack),
                Card(suit: .diamonds, rank: .five),
                Card(suit: .clubs, rank: .five),
                Card(suit: .spades, rank: .nine)
            ]
        case .onePair:
            return [
                Card(suit: .spades, rank: .ten),
                Card(suit: .hearts, rank: .ten),
                Card(suit: .diamonds, rank: .ace),
                Card(suit: .clubs, rank: .seven),
                Card(suit: .spades, rank: .two)
            ]
        case .highCard:
            return [
                Card(suit: .spades, rank: .ace),
                Card(suit: .diamonds, rank: .king),
                Card(suit: .clubs, rank: .nine),
                Card(suit: .hearts, rank: .six),
                Card(suit: .spades, rank: .three)
            ]
        }
    }
}

#Preview {
    HandCheatsheetView()
}
