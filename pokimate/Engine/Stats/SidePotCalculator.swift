import Foundation

struct SidePot: Equatable {
    var amount: Int
    /// Player IDs eligible to win this pot (still in hand when pot formed).
    var eligible: Set<UUID>
}

enum SidePotCalculator {

    /// Builds main + side pots from each player's total contribution this hand.
    static func pots(
        contributions: [(id: UUID, amount: Int, inHand: Bool)]
    ) -> [SidePot] {
        let positive = contributions.filter { $0.amount > 0 }
        guard !positive.isEmpty else { return [] }

        let levels = Array(Set(positive.map(\.amount))).sorted()
        var pots: [SidePot] = []
        var previous = 0

        for level in levels {
            let layer = level - previous
            guard layer > 0 else { continue }
            let contributors = positive.filter { $0.amount >= level }
            let amount = layer * contributors.count
            let eligible = Set(
                contributors
                    .filter(\.inHand)
                    .map(\.id)
            )
            // Folded players' chips stay in pot; only in-hand players can win.
            // Also include players who folded but contributed? No — only inHand.
            // If nobody in hand at this level (shouldn't happen), skip.
            if amount > 0, !eligible.isEmpty {
                pots.append(SidePot(amount: amount, eligible: eligible))
            } else if amount > 0 {
                // All contributors folded at deeper level — award to remaining in-hand overall.
                let anyInHand = Set(contributions.filter(\.inHand).map(\.id))
                if !anyInHand.isEmpty {
                    pots.append(SidePot(amount: amount, eligible: anyInHand))
                }
            }
            previous = level
        }

        return pots
    }

    /// Resolve each pot among eligible players using provided hand strengths.
    static func awards(
        pots: [SidePot],
        evaluations: [UUID: EvaluatedHand]
    ) -> [(playerID: UUID, amount: Int)] {
        var totals: [UUID: Int] = [:]

        for pot in pots {
            let contenders = pot.eligible.compactMap { id -> (UUID, EvaluatedHand)? in
                guard let hand = evaluations[id] else { return nil }
                return (id, hand)
            }
            guard !contenders.isEmpty else { continue }

            var best: EvaluatedHand?
            var winners: [UUID] = []
            for (id, hand) in contenders {
                if best == nil || hand > best! {
                    best = hand
                    winners = [id]
                } else if let b = best, hand == b {
                    winners.append(id)
                }
            }

            let share = pot.amount / winners.count
            let remainder = pot.amount % winners.count
            for (i, id) in winners.enumerated() {
                totals[id, default: 0] += share + (i == 0 ? remainder : 0)
            }
        }

        return totals.map { (playerID: $0.key, amount: $0.value) }
    }
}
