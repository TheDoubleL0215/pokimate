package com.pokimate.model

enum class HandActionType(val rawValue: String) {
    FOLD("fold"),
    CHECK("check"),
    CALL("call"),
    BET("bet"),
    RAISE("raise"),
    BLIND("blind");

    val isAggressive: Boolean
        get() = this == BET || this == RAISE

    val isVoluntary: Boolean
        get() = this != BLIND
}

enum class HandStreet(val rawValue: String) {
    PREFLOP("preflop"),
    FLOP("flop"),
    TURN("turn"),
    RIVER("river");

    companion object {
        fun fromPhase(phase: GamePhase): HandStreet = when (phase) {
            GamePhase.PRE_FLOP -> PREFLOP
            GamePhase.FLOP -> FLOP
            GamePhase.TURN -> TURN
            GamePhase.RIVER -> RIVER
            else -> PREFLOP
        }
    }
}
