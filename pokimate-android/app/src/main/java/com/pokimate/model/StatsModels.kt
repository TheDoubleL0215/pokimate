package com.pokimate.model

import java.util.Calendar
import java.util.Date

data class StatsSession(
    var id: String,
    var startedAt: Date,
    var endedAt: Date? = null,
    var bigBlind: Int,
    var raiseAmount: Int,
    var startingChips: Int,
    var endingChips: Int? = null,
    var botCount: Int,
    var blindsEnabled: Boolean,
    var handsPlayed: Int = 0,
    var netProfit: Int = 0
)

data class StatsHand(
    var id: String,
    var sessionId: String,
    var handIndex: Int,
    var dealerSeat: Int,
    var humanSeat: Int,
    var humanPosition: String,
    var bigBlind: Int,
    var boardJSON: String,
    var humanHoleJSON: String,
    var netWon: Int,
    var allInEV: Double? = null,
    var wentToShowdown: Boolean,
    var wonAtShowdown: Boolean,
    var endedAt: Date
)

data class StatsAction(
    var id: Long? = null,
    var handId: String,
    var sequence: Int,
    var street: String,
    var seat: Int,
    var isHero: Boolean,
    var actionType: String,
    var amount: Int,
    var facingRaises: Int,
    var isVoluntary: Boolean
)

object CardCodec {
    fun encode(cards: List<Card>): String =
        cards.joinToString(",") { "${it.rank.rawValue}${suitLetter(it.suit)}" }

    fun decode(raw: String): List<Card> {
        if (raw.isEmpty()) return emptyList()
        return raw.split(",").mapNotNull { token ->
            val digits = token.takeWhile { it.isDigit() }
            val rankVal = digits.toIntOrNull() ?: return@mapNotNull null
            val rank = Rank.fromRaw(rankVal) ?: return@mapNotNull null
            val suitChar = token.drop(digits.length).firstOrNull() ?: return@mapNotNull null
            val suit = suitFrom(suitChar) ?: return@mapNotNull null
            Card(suit = suit, rank = rank)
        }
    }

    /** Canonical hand key for 13×13 matrix (e.g. "AKs", "AKo", "QQ"). */
    fun matrixKey(forCards: List<Card>): String? {
        if (forCards.size != 2) return null
        val a = forCards[0]
        val b = forCards[1]
        val high = maxOf(a.rank, b.rank, compareBy { it.rawValue })
        val low = minOf(a.rank, b.rank, compareBy { it.rawValue })
        if (high == low) {
            return "${matrixRank(high)}${matrixRank(low)}"
        }
        val suited = a.suit == b.suit
        return "${matrixRank(high)}${matrixRank(low)}${if (suited) "s" else "o"}"
    }

    val matrixRanks: List<Rank> = listOf(
        Rank.ACE, Rank.KING, Rank.QUEEN, Rank.JACK, Rank.TEN, Rank.NINE, Rank.EIGHT,
        Rank.SEVEN, Rank.SIX, Rank.FIVE, Rank.FOUR, Rank.THREE, Rank.TWO
    )

    fun matrixRank(rank: Rank): String = when (rank) {
        Rank.ACE -> "A"
        Rank.KING -> "K"
        Rank.QUEEN -> "Q"
        Rank.JACK -> "J"
        Rank.TEN -> "T"
        else -> rank.display
    }

    private fun suitLetter(suit: Suit): String = when (suit) {
        Suit.HEARTS -> "h"
        Suit.DIAMONDS -> "d"
        Suit.CLUBS -> "c"
        Suit.SPADES -> "s"
    }

    private fun suitFrom(letter: Char): Suit? = when (letter) {
        'h' -> Suit.HEARTS
        'd' -> Suit.DIAMONDS
        'c' -> Suit.CLUBS
        's' -> Suit.SPADES
        else -> null
    }
}

data class StatsDateRange(
    var start: Date? = null,
    var end: Date? = null
) {
    companion object {
        val all = StatsDateRange(start = null, end = null)

        fun lastHours(hours: Int): StatsDateRange =
            StatsDateRange(
                start = Date(System.currentTimeMillis() - hours * 3600_000L),
                end = null
            )

        fun thisWeek(): StatsDateRange {
            val cal = Calendar.getInstance()
            cal.firstDayOfWeek = Calendar.MONDAY
            cal.set(Calendar.DAY_OF_WEEK, cal.firstDayOfWeek)
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            return StatsDateRange(start = cal.time, end = null)
        }

        fun thisMonth(): StatsDateRange {
            val cal = Calendar.getInstance()
            cal.set(Calendar.DAY_OF_MONTH, 1)
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            return StatsDateRange(start = cal.time, end = null)
        }
    }
}

data class StatsFilter(
    var dateRange: StatsDateRange = StatsDateRange.all,
    var bigBlind: Int? = null
)

data class BankrollSummary(
    var hands: Int,
    var netProfit: Int,
    var bigBlind: Int,
    var hoursPlayed: Double,
    var sessions: Int
) {
    val bbPer100: Double
        get() {
            if (hands <= 0 || bigBlind <= 0) return 0.0
            return (netProfit.toDouble() / bigBlind.toDouble()) / (hands.toDouble() / 100.0)
        }

    val hourlyRate: Double
        get() {
            if (hoursPlayed <= 0) return 0.0
            return netProfit.toDouble() / hoursPlayed
        }
}

data class ProfitPoint(
    var handOrdinal: Int,
    var cumulativeProfit: Double,
    var cumulativeEV: Double
) {
    val id: Int get() = handOrdinal
}

data class DayProfit(
    var dayKey: String,
    var date: Date,
    var netProfit: Int,
    var hands: Int
) {
    val id: String get() = dayKey
}

data class PositionStat(
    var position: String,
    var hands: Int,
    var netWon: Int,
    var bigBlind: Int
) {
    val id: String get() = position

    val bbPer100: Double
        get() {
            if (hands <= 0 || bigBlind <= 0) return 0.0
            return (netWon.toDouble() / bigBlind.toDouble()) / (hands.toDouble() / 100.0)
        }
}

data class HUDStats(
    var hands: Int,
    var vpip: Double,
    var pfr: Double,
    var threeBet: Double,
    var foldToThreeBet: Double,
    var cbet: Double,
    var aggressionFactor: Double,
    var wsd: Double,
    var wDollarSD: Double
)

data class RangeCell(
    var key: String,
    var row: Int,
    var col: Int,
    var hands: Int,
    var netWon: Int
) {
    val id: String get() = key
}

data class LeakWarning(
    var title: String,
    var detail: String,
    var severity: Int
) {
    val id: String get() = title
}
