package com.pokimate.model

import com.pokimate.i18n.L10n

enum class GamePhase {
    WAITING,
    PRE_FLOP,
    FLOP,
    TURN,
    RIVER,
    SHOWDOWN;

    val displayName: String
        get() = when (this) {
            WAITING -> L10n.t("phase.waiting")
            PRE_FLOP -> L10n.t("game.preflop")
            FLOP -> L10n.t("game.flop")
            TURN -> L10n.t("game.turn")
            RIVER -> L10n.t("game.river")
            SHOWDOWN -> L10n.t("game.showdown")
        }
}
