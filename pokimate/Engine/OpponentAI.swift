import Foundation

enum PlayerAction {
    case fold
    case checkOrCall
    case raise
}

enum OpponentAI {

    /// Threshold / random decisions for a minimal AI opponent.
    static func decide(
        player: Player,
        phase: GamePhase,
        highestBet: Int,
        pot: Int,
        requiresEntryBet: Bool = false
    ) -> PlayerAction {
        let callAmount = requiresEntryBet
            ? max(highestBet, 1)
            : player.callAmount(against: highestBet)
        let canCheck = !requiresEntryBet && player.canCheck(against: highestBet)
        let roll = Double.random(in: 0...1)

        // Blindless entry / facing a bet: weak hands often fold instead of buying in.
        if phase == .preFlop, player.holeCards.count == 2 {
            if isTerribleStartingHand(player.holeCards), roll < 0.65, !canCheck {
                return .fold
            }
        }

        // Facing a sizable bet relative to stack — sometimes fold.
        if callAmount > 0 || requiresEntryBet {
            let pressure = Double(max(callAmount, 1)) / Double(max(player.chips, 1))
            if pressure > 0.4, roll < 0.35 {
                return .fold
            }
            // Occasional raise when calling / entering is cheap.
            if pressure < 0.15, roll > 0.85, player.chips > callAmount {
                return .raise
            }
            return .checkOrCall
        }

        // Free check: sometimes raise as a bluff / value.
        if canCheck {
            if roll > 0.82, player.chips > 0 {
                return .raise
            }
            return .checkOrCall
        }

        return .checkOrCall
    }

    /// Unsuited low connectors / rag hands treated as "terrible".
    private static func isTerribleStartingHand(_ cards: [Card]) -> Bool {
        guard cards.count == 2 else { return false }
        let a = cards[0]
        let b = cards[1]
        let high = max(a.rank, b.rank)
        let low = min(a.rank, b.rank)
        let suited = a.suit == b.suit
        let paired = a.rank == b.rank

        if paired { return false }
        if high >= .jack { return false }
        if suited, high.rawValue - low.rawValue <= 2 { return false }
        return high < .ten && low < .eight
    }
}
