package com.pokimate.engine

import com.pokimate.model.Card
import com.pokimate.model.Rank
import com.pokimate.model.Suit

/** Monte Carlo equity for all-in situations (hero vs villains). */
object EquityCalculator {

    /** Returns hero equity in [0, 1] given known hole cards and optional board. */
    fun heroEquity(
        heroHole: List<Card>,
        villainHoles: List<List<Card>>,
        board: List<Card>,
        iterations: Int = 400
    ): Double {
        if (heroHole.size != 2 || villainHoles.isEmpty()) return 0.5
        val knownKeys = (heroHole + board + villainHoles.flatten())
            .map { "${it.rank.rawValue}-${it.suit.name}" }
            .toSet()
        var deck = Suit.entries.flatMap { suit ->
            Rank.entries.mapNotNull { rank ->
                val key = "${rank.rawValue}-${suit.name}"
                if (knownKeys.contains(key)) null else Card(suit = suit, rank = rank)
            }
        }.toMutableList()

        val boardNeeded = maxOf(0, 5 - board.size)
        var wins = 0.0
        val n = maxOf(iterations, 1)

        repeat(n) {
            deck = deck.shuffled().toMutableList()
            var idx = 0
            val runBoard = board.toMutableList()
            repeat(boardNeeded) {
                if (idx >= deck.size) return@repeat
                runBoard.add(deck[idx])
                idx += 1
            }

            val heroValue = HandEvaluator.evaluateBestHand(hole = heroHole, community = runBoard)
            var bestVillain: EvaluatedHand? = null
            var villainTies = 0
            for (hole in villainHoles) {
                val value = HandEvaluator.evaluateBestHand(hole = hole, community = runBoard)
                when {
                    bestVillain == null || value > bestVillain -> {
                        bestVillain = value
                        villainTies = 1
                    }
                    value == bestVillain -> villainTies += 1
                }
            }

            val best = bestVillain
            if (best == null) {
                wins += 1
            } else when {
                heroValue > best -> wins += 1
                heroValue == best -> wins += 1.0 / (villainTies + 1).toDouble()
            }
        }

        return wins / n.toDouble()
    }

    /**
     * Expected chip EV for hero if pot is contested all-in.
     * Simplification: hero EV delta ≈ equity * totalPot - heroContribution
     */
    fun allInEVDelta(
        heroHole: List<Card>,
        villainHoles: List<List<Card>>,
        board: List<Card>,
        pot: Int,
        heroContribution: Int
    ): Double {
        val equity = heroEquity(
            heroHole = heroHole,
            villainHoles = villainHoles,
            board = board
        )
        return equity * pot.toDouble() - heroContribution.toDouble()
    }
}
