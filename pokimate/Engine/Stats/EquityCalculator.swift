import Foundation

/// Monte Carlo equity for all-in situations (hero vs villains).
enum EquityCalculator {

    /// Returns hero equity in [0, 1] given known hole cards and optional board.
    static func heroEquity(
        heroHole: [Card],
        villainHoles: [[Card]],
        board: [Card],
        iterations: Int = 400
    ) -> Double {
        guard heroHole.count == 2, !villainHoles.isEmpty else { return 0.5 }
        let knownKeys = Set(
            (heroHole + board + villainHoles.flatMap { $0 }).map { "\($0.rank.rawValue)-\($0.suit.rawValue)" }
        )
        var deck = Suit.allCases.flatMap { suit in
            Rank.allCases.compactMap { rank -> Card? in
                let key = "\(rank.rawValue)-\(suit.rawValue)"
                return knownKeys.contains(key) ? nil : Card(suit: suit, rank: rank)
            }
        }

        let boardNeeded = max(0, 5 - board.count)
        var wins = 0.0
        let n = max(iterations, 1)

        for _ in 0..<n {
            deck.shuffle()
            var idx = 0
            var runBoard = board
            for _ in 0..<boardNeeded {
                guard idx < deck.count else { break }
                runBoard.append(deck[idx])
                idx += 1
            }

            let heroValue = HandEvaluator.evaluateBestHand(hole: heroHole, community: runBoard)
            var bestVillain: EvaluatedHand?
            var villainTies = 0
            for hole in villainHoles {
                let value = HandEvaluator.evaluateBestHand(hole: hole, community: runBoard)
                if bestVillain == nil || value > bestVillain! {
                    bestVillain = value
                    villainTies = 1
                } else if let best = bestVillain, value == best {
                    villainTies += 1
                }
            }

            guard let bestVillain else {
                wins += 1
                continue
            }

            if heroValue > bestVillain {
                wins += 1
            } else if heroValue == bestVillain {
                wins += 1.0 / Double(villainTies + 1)
            }
        }

        return wins / Double(n)
    }

    /// Expected chip EV for hero if pot is contested all-in: equity * potShare estimation.
    /// Simplification: hero EV delta ≈ equity * totalPot - heroContribution
    static func allInEVDelta(
        heroHole: [Card],
        villainHoles: [[Card]],
        board: [Card],
        pot: Int,
        heroContribution: Int
    ) -> Double {
        let equity = heroEquity(
            heroHole: heroHole,
            villainHoles: villainHoles,
            board: board
        )
        return equity * Double(pot) - Double(heroContribution)
    }
}
