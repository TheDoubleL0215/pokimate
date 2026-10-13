package com.pokimate.model

import java.util.UUID

enum class Suit(val symbol: String, val isRed: Boolean) {
    HEARTS("♥", true),
    DIAMONDS("♦", true),
    CLUBS("♣", false),
    SPADES("♠", false),
}

enum class Rank(val rawValue: Int) {
    TWO(2),
    THREE(3),
    FOUR(4),
    FIVE(5),
    SIX(6),
    SEVEN(7),
    EIGHT(8),
    NINE(9),
    TEN(10),
    JACK(11),
    QUEEN(12),
    KING(13),
    ACE(14);

    val display: String
        get() = when (this) {
            TWO -> "2"
            THREE -> "3"
            FOUR -> "4"
            FIVE -> "5"
            SIX -> "6"
            SEVEN -> "7"
            EIGHT -> "8"
            NINE -> "9"
            TEN -> "10"
            JACK -> "J"
            QUEEN -> "Q"
            KING -> "K"
            ACE -> "A"
        }

    companion object {
        fun fromRaw(value: Int): Rank? = entries.firstOrNull { it.rawValue == value }
    }
}

data class Card(
    val suit: Suit,
    val rank: Rank,
    val id: UUID = UUID.randomUUID(),
) {
    val displayText: String get() = "${rank.display}${suit.symbol}"
}

class Deck {
    private val _cards: MutableList<Card> =
        Suit.entries.flatMap { suit ->
            Rank.entries.map { rank -> Card(suit = suit, rank = rank) }
        }.toMutableList()

    val cards: List<Card> get() = _cards

    fun shuffle() {
        _cards.shuffle()
    }

    fun draw(): Card? {
        if (_cards.isEmpty()) return null
        return _cards.removeAt(0)
    }

    fun draw(count: Int): List<Card> {
        val drawn = mutableListOf<Card>()
        repeat(count) {
            draw()?.let { drawn += it }
        }
        return drawn
    }

    val remainingCount: Int get() = _cards.size
}
