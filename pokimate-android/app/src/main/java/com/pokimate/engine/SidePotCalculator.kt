package com.pokimate.engine

import java.util.UUID

data class SidePot(
    var amount: Int,
    /** Player IDs eligible to win this pot (still in hand when pot formed). */
    var eligible: Set<UUID>
)

data class Contribution(
    val id: UUID,
    val amount: Int,
    val inHand: Boolean
)

data class PotAwardResult(
    val playerID: UUID,
    val amount: Int
)

object SidePotCalculator {

    /** Builds main + side pots from each player's total contribution this hand. */
    fun pots(contributions: List<Contribution>): List<SidePot> {
        val positive = contributions.filter { it.amount > 0 }
        if (positive.isEmpty()) return emptyList()

        val levels = positive.map { it.amount }.toSet().sorted()
        val pots = mutableListOf<SidePot>()
        var previous = 0

        for (level in levels) {
            val layer = level - previous
            if (layer <= 0) continue
            val contributors = positive.filter { it.amount >= level }
            val amount = layer * contributors.size
            val eligible = contributors
                .filter { it.inHand }
                .map { it.id }
                .toSet()
            // Folded players' chips stay in pot; only in-hand players can win.
            if (amount > 0 && eligible.isNotEmpty()) {
                pots.add(SidePot(amount = amount, eligible = eligible))
            } else if (amount > 0) {
                // All contributors folded at deeper level — award to remaining in-hand overall.
                val anyInHand = contributions.filter { it.inHand }.map { it.id }.toSet()
                if (anyInHand.isNotEmpty()) {
                    pots.add(SidePot(amount = amount, eligible = anyInHand))
                }
            }
            previous = level
        }

        return pots
    }

    /** Resolve each pot among eligible players using provided hand strengths. */
    fun awards(
        pots: List<SidePot>,
        evaluations: Map<UUID, EvaluatedHand>
    ): List<PotAwardResult> {
        val totals = mutableMapOf<UUID, Int>()

        for (pot in pots) {
            val contenders = pot.eligible.mapNotNull { id ->
                val hand = evaluations[id] ?: return@mapNotNull null
                id to hand
            }
            if (contenders.isEmpty()) continue

            var best: EvaluatedHand? = null
            val winners = mutableListOf<UUID>()
            for ((id, hand) in contenders) {
                when {
                    best == null || hand > best -> {
                        best = hand
                        winners.clear()
                        winners.add(id)
                    }
                    hand == best -> winners.add(id)
                }
            }

            val share = pot.amount / winners.size
            val remainder = pot.amount % winners.size
            winners.forEachIndexed { i, id ->
                totals[id] = (totals[id] ?: 0) + share + if (i == 0) remainder else 0
            }
        }

        return totals.map { PotAwardResult(playerID = it.key, amount = it.value) }
    }
}
