package com.pokimate.engine

import com.pokimate.i18n.L10n
import com.pokimate.model.Card
import com.pokimate.model.Rank
import com.pokimate.model.Suit
import java.util.UUID

enum class HandCategory(val rawValue: Int) {
    HIGH_CARD(0),
    ONE_PAIR(1),
    TWO_PAIR(2),
    THREE_OF_A_KIND(3),
    STRAIGHT(4),
    FLUSH(5),
    FULL_HOUSE(6),
    FOUR_OF_A_KIND(7),
    STRAIGHT_FLUSH(8),
    ROYAL_FLUSH(9);

    val displayName: String
        get() = when (this) {
            HIGH_CARD -> L10n.t("hand.high_card")
            ONE_PAIR -> L10n.t("hand.one_pair")
            TWO_PAIR -> L10n.t("hand.two_pair")
            THREE_OF_A_KIND -> L10n.t("hand.three_of_a_kind")
            STRAIGHT -> L10n.t("hand.straight")
            FLUSH -> L10n.t("hand.flush")
            FULL_HOUSE -> L10n.t("hand.full_house")
            FOUR_OF_A_KIND -> L10n.t("hand.four_of_a_kind")
            STRAIGHT_FLUSH -> L10n.t("hand.straight_flush")
            ROYAL_FLUSH -> L10n.t("hand.royal_flush")
        }
}

data class EvaluatedHand(
    val category: HandCategory,
    /** Kickers / tie-break ranks, highest first. */
    val ranks: List<Int>,
    /** The five cards that form this hand (subset of hole + community). */
    val cards: List<Card>
) : Comparable<EvaluatedHand> {

    override fun compareTo(other: EvaluatedHand): Int {
        if (category != other.category) {
            return category.rawValue.compareTo(other.category.rawValue)
        }
        for ((l, r) in ranks.zip(other.ranks)) {
            if (l != r) return l.compareTo(r)
        }
        return 0
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is EvaluatedHand) return false
        return category == other.category && ranks == other.ranks
    }

    override fun hashCode(): Int {
        var result = category.hashCode()
        result = 31 * result + ranks.hashCode()
        return result
    }

    /**
     * Cards that define the hand category get a strong highlight; the rest of
     * the made five (kickers / fillers) get a softer one — e.g. pair = 2 strong + 3 soft.
     */
    fun highlightGroups(): Pair<Set<UUID>, Set<UUID>> {
        val handIDs = cards.map { it.id }.toSet()
        val primaryRanks: Set<Int> = when (category) {
            HandCategory.HIGH_CARD -> ranks.take(2).toSet()
            HandCategory.ONE_PAIR -> ranks.take(1).toSet()
            HandCategory.TWO_PAIR -> ranks.take(2).toSet()
            HandCategory.THREE_OF_A_KIND -> ranks.take(1).toSet()
            HandCategory.STRAIGHT,
            HandCategory.FLUSH,
            HandCategory.STRAIGHT_FLUSH,
            HandCategory.ROYAL_FLUSH -> return handIDs to emptySet()
            HandCategory.FULL_HOUSE -> ranks.take(2).toSet()
            HandCategory.FOUR_OF_A_KIND -> ranks.take(1).toSet()
        }

        val primary = cards.filter { primaryRanks.contains(it.rank.rawValue) }.map { it.id }.toSet()
        return primary to (handIDs - primary)
    }
}

object HandEvaluator {

    /** Best 5-card hand from 2 hole + up to 5 community cards. */
    fun evaluateBestHand(hole: List<Card>, community: List<Card>): EvaluatedHand {
        val all = hole + community
        if (all.size < 5) {
            val padded = all.toMutableList()
            while (padded.size < 5) {
                padded.add(Card(suit = Suit.CLUBS, rank = Rank.TWO))
            }
            return evaluateFiveCards(padded.take(5))
        }

        var best: EvaluatedHand? = null
        for (combo in combinations(all, 5)) {
            val evaluated = evaluateFiveCards(combo)
            if (best == null || evaluated > best) {
                best = evaluated
            }
        }
        return best ?: EvaluatedHand(HandCategory.HIGH_CARD, listOf(0), emptyList())
    }

    /** Modular 5-card evaluation — expand here for edge cases. */
    fun evaluateFiveCards(cards: List<Card>): EvaluatedHand {
        require(cards.size == 5) { "Exactly 5 cards required" }

        val sortedRanks = cards.map { it.rank.rawValue }.sortedDescending()
        val isFlush = cards.map { it.suit }.toSet().size == 1
        val straightHigh = straightHighRank(sortedRanks)

        if (isFlush && straightHigh != null) {
            if (straightHigh == Rank.ACE.rawValue) {
                return EvaluatedHand(HandCategory.ROYAL_FLUSH, listOf(straightHigh), cards)
            }
            return EvaluatedHand(HandCategory.STRAIGHT_FLUSH, listOf(straightHigh), cards)
        }

        val rankCounts = countByRank(sortedRanks)
        val countsDescending = rankCounts.map { it.second }.sortedDescending()

        if (countsDescending.firstOrNull() == 4) {
            val quad = rankCounts.first { it.second == 4 }.first
            val kicker = rankCounts.first { it.second == 1 }.first
            return EvaluatedHand(HandCategory.FOUR_OF_A_KIND, listOf(quad, kicker), cards)
        }

        if (countsDescending == listOf(3, 2)) {
            val trips = rankCounts.first { it.second == 3 }.first
            val pair = rankCounts.first { it.second == 2 }.first
            return EvaluatedHand(HandCategory.FULL_HOUSE, listOf(trips, pair), cards)
        }

        if (isFlush) {
            return EvaluatedHand(HandCategory.FLUSH, sortedRanks, cards)
        }

        if (straightHigh != null) {
            return EvaluatedHand(HandCategory.STRAIGHT, listOf(straightHigh), cards)
        }

        if (countsDescending.firstOrNull() == 3) {
            val trips = rankCounts.first { it.second == 3 }.first
            val kickers = rankCounts.filter { it.second == 1 }.map { it.first }.sortedDescending()
            return EvaluatedHand(HandCategory.THREE_OF_A_KIND, listOf(trips) + kickers, cards)
        }

        val pairs = rankCounts.filter { it.second == 2 }.map { it.first }.sortedDescending()
        if (pairs.size == 2) {
            val kicker = rankCounts.first { it.second == 1 }.first
            return EvaluatedHand(HandCategory.TWO_PAIR, pairs + kicker, cards)
        }

        if (pairs.size == 1) {
            val kickers = rankCounts.filter { it.second == 1 }.map { it.first }.sortedDescending()
            return EvaluatedHand(HandCategory.ONE_PAIR, listOf(pairs[0]) + kickers, cards)
        }

        return EvaluatedHand(HandCategory.HIGH_CARD, sortedRanks, cards)
    }

    private fun countByRank(ranks: List<Int>): List<Pair<Int, Int>> {
        val map = mutableMapOf<Int, Int>()
        for (r in ranks) {
            map[r] = (map[r] ?: 0) + 1
        }
        return map.map { it.key to it.value }
    }

    /** Returns the high card of a straight, or null. Handles wheel (A-2-3-4-5). */
    private fun straightHighRank(sortedDescending: List<Int>): Int? {
        val unique = sortedDescending.toSet().toList().sortedDescending()
        if (unique.size != 5) return null
        return checkStraight(unique)
    }

    private fun checkStraight(uniqueDescending: List<Int>): Int? {
        val ranks = uniqueDescending.sortedDescending()
        var consecutive = true
        for (i in 0 until ranks.size - 1) {
            if (ranks[i] - ranks[i + 1] != 1) {
                consecutive = false
                break
            }
        }
        if (consecutive && ranks.size == 5) {
            return ranks[0]
        }

        val wheel = setOf(14, 5, 4, 3, 2)
        if (ranks.toSet() == wheel) {
            return 5
        }
        return null
    }

    private fun combinations(array: List<Card>, k: Int): List<List<Card>> {
        if (k <= 0 || array.size < k) return emptyList()
        if (k == array.size) return listOf(array)
        if (k == 1) return array.map { listOf(it) }

        val result = mutableListOf<List<Card>>()
        for (i in 0..(array.size - k)) {
            val head = array[i]
            val tailCombos = combinations(array.subList(i + 1, array.size), k - 1)
            for (combo in tailCombos) {
                result.add(listOf(head) + combo)
            }
        }
        return result
    }
}
