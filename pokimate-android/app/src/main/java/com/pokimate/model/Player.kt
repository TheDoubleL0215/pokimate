package com.pokimate.model

import java.util.UUID

data class Player(
    val id: UUID = UUID.randomUUID(),
    var name: String,
    var chips: Int,
    var currentBet: Int = 0,
    /** Chips this player has put in during the current hand. */
    var totalBetThisHand: Int = 0,
    var holeCards: List<Card> = emptyList(),
    var isHuman: Boolean = false,
    var isActive: Boolean = true,
    var isFolded: Boolean = false,
    var hasActedThisRound: Boolean = false,
    /** True after a check this street (cleared on call/raise/new street). */
    var hasCheckedThisRound: Boolean = false,
) {
    val isInHand: Boolean
        get() = isActive && !isFolded && chips >= 0

    val canAct: Boolean
        get() = isInHand && chips > 0

    fun canCheck(against: Int): Boolean = currentBet >= against

    fun callAmount(against: Int): Int = maxOf(0, against - currentBet)

    fun resetForNewHand() {
        currentBet = 0
        totalBetThisHand = 0
        holeCards = emptyList()
        isFolded = false
        hasActedThisRound = false
        hasCheckedThisRound = false
        isActive = chips > 0
    }

    fun resetForNewStreet() {
        currentBet = 0
        hasActedThisRound = false
        hasCheckedThisRound = false
    }
}
