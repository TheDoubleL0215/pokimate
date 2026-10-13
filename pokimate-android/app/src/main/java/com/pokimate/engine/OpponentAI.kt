package com.pokimate.engine

import com.pokimate.model.Card
import com.pokimate.model.GamePhase
import com.pokimate.model.Player
import com.pokimate.model.Rank
import kotlin.random.Random

enum class PlayerAction {
    FOLD,
    CHECK_OR_CALL,
    RAISE
}

object OpponentAI {

    /** Threshold / random decisions for a minimal AI opponent. */
    fun decide(
        player: Player,
        phase: GamePhase,
        highestBet: Int,
        pot: Int,
        requiresEntryBet: Boolean = false
    ): PlayerAction {
        val callAmount = if (requiresEntryBet) {
            maxOf(highestBet, 1)
        } else {
            player.callAmount(against = highestBet)
        }
        val canCheck = !requiresEntryBet && player.canCheck(against = highestBet)
        val roll = Random.nextDouble(0.0, 1.0)

        // Blindless entry / facing a bet: weak hands often fold instead of buying in.
        if (phase == GamePhase.PRE_FLOP && player.holeCards.size == 2) {
            if (isTerribleStartingHand(player.holeCards) && roll < 0.65 && !canCheck) {
                return PlayerAction.FOLD
            }
        }

        // Facing a sizable bet relative to stack — sometimes fold.
        if (callAmount > 0 || requiresEntryBet) {
            val pressure = maxOf(callAmount, 1).toDouble() / maxOf(player.chips, 1).toDouble()
            if (pressure > 0.4 && roll < 0.35) {
                return PlayerAction.FOLD
            }
            // Occasional raise when calling / entering is cheap.
            if (pressure < 0.15 && roll > 0.85 && player.chips > callAmount) {
                return PlayerAction.RAISE
            }
            return PlayerAction.CHECK_OR_CALL
        }

        // Free check: sometimes raise as a bluff / value.
        if (canCheck) {
            if (roll > 0.82 && player.chips > 0) {
                return PlayerAction.RAISE
            }
            return PlayerAction.CHECK_OR_CALL
        }

        return PlayerAction.CHECK_OR_CALL
    }

    /** Unsuited low connectors / rag hands treated as "terrible". */
    private fun isTerribleStartingHand(cards: List<Card>): Boolean {
        if (cards.size != 2) return false
        val a = cards[0]
        val b = cards[1]
        val high = maxOf(a.rank, b.rank, compareBy { it.rawValue })
        val low = minOf(a.rank, b.rank, compareBy { it.rawValue })
        val suited = a.suit == b.suit
        val paired = a.rank == b.rank

        if (paired) return false
        if (high.rawValue >= Rank.JACK.rawValue) return false
        if (suited && high.rawValue - low.rawValue <= 2) return false
        return high.rawValue < Rank.TEN.rawValue && low.rawValue < Rank.EIGHT.rawValue
    }
}
