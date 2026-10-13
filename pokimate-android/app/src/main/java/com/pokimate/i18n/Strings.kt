package com.pokimate.i18n

/**
 * Lightweight localization for the engine layer.
 * Holds an in-memory key→string map (English defaults).
 * Keys use dotted form in code (`game.your_turn`); Android resource names
 * would use underscores (`game_your_turn`) when loaded later via Context.
 */
object L10n {
    private val strings: MutableMap<String, String> = mutableMapOf()

    init {
        loadEnglishDefaults()
    }

    fun t(key: String): String = strings[key] ?: key

    fun format(key: String, vararg args: Any?): String {
        val template = t(key)
        return try {
            String.format(java.util.Locale.US, template, *args)
        } catch (_: Exception) {
            template
        }
    }

    fun put(key: String, value: String) {
        strings[key] = value
    }

    fun putAll(map: Map<String, String>) {
        strings.putAll(map)
    }

    /** Dotted key → Android resource-style name. */
    fun resourceName(key: String): String = key.replace('.', '_')

    private fun loadEnglishDefaults() {
        putAll(
            mapOf(
                // phase
                "phase.waiting" to "Waiting",

                // player
                "player.you" to "You",
                "player.folded" to "Folded",

                // action
                "action.call" to "Call %d",
                "action.call_short" to "CALL",
                "action.check" to "Check",
                "action.confirm" to "CONFIRM",
                "action.confirm_fmt" to "CONFIRM %s",
                "action.continue" to "CONTINUE",
                "action.enter" to "Enter %d",
                "action.fold" to "FOLD",
                "action.raise" to "RAISE",

                // banner
                "banner.bet" to "BET $%d",
                "banner.call" to "CALL $%d",
                "banner.check" to "CHECK",
                "banner.enter" to "ENTER $%d",
                "banner.fold" to "FOLD",
                "banner.raise" to "RAISE $%d",

                // game
                "game.amount_with_hand" to "%d with %s",
                "game.bets" to "%s bets %d",
                "game.blinds" to "Blinds…",
                "game.calls" to "%s calls %d",
                "game.checks" to "%s checks",
                "game.dealing" to "Dealing…",
                "game.enter_or_fold" to "Enter or fold",
                "game.enters" to "%s enters for %d",
                "game.flop" to "Flop",
                "game.folds" to "%s folds",
                "game.hand_over" to "Hand over",
                "game.no_blinds" to "No blinds — decide after the deal",
                "game.not_enough_players" to "Not enough players with chips",
                "game.player_hand" to "%s: %s",
                "game.player_wins" to "%s wins %s",
                "game.posts_bb" to "%s posts BB %d",
                "game.posts_sb" to "%s posts SB %d",
                "game.preflop" to "Pre-Flop",
                "game.raises_to" to "%s raises to %d",
                "game.reveals" to "%s reveals…",
                "game.river" to "River",
                "game.showdown" to "Showdown",
                "game.split_pot" to "Split pot: %s",
                "game.split_side_pots" to "Split / side pots %d: %s",
                "game.tap_to_start" to "Tap to start",
                "game.thinking" to "%s is thinking…",
                "game.turn" to "Turn",
                "game.with_hand" to "with %s",
                "game.you_win" to "You win %s",
                "game.your_turn" to "Your turn",

                // hand
                "hand.flush" to "Flush",
                "hand.four_of_a_kind" to "Four of a Kind",
                "hand.full_house" to "Full House",
                "hand.high_card" to "High Card",
                "hand.one_pair" to "One Pair",
                "hand.royal_flush" to "Royal Flush",
                "hand.straight" to "Straight",
                "hand.straight_flush" to "Straight Flush",
                "hand.three_of_a_kind" to "Three of a Kind",
                "hand.two_pair" to "Two Pair",

                // menu
                "menu.new_game" to "NEW GAME",
                "menu.settings" to "SETTINGS",
                "menu.stats" to "STATISTICS",

                // setup
                "setup.base_bet" to "Base bet",
                "setup.blinds" to "Blinds",
                "setup.blinds_off" to "No blinds: enter or fold after the deal",
                "setup.blinds_on" to "Classic Hold’em: SB / BB every hand",
                "setup.blinds_sb_bb" to "Small %d / Big %d",
                "setup.bots" to "Bots",
                "setup.bots_subtitle" to "%d opponents at the table",
                "setup.chips_rule" to "Starting chips must be at least four times the base bet.",
                "setup.raise_unit" to "Raise unit: %d",
                "setup.sit_down" to "SIT DOWN",
                "setup.starting_chips" to "Starting chips",
                "setup.starting_chips_subtitle" to "Every player starts with %d chips",

                // leak (used by LeakDetector)
                "leak.loose_vpip.title" to "Too loose preflop (VPIP)",
                "leak.loose_vpip.detail" to "VPIP %.0f%% — target around 20–28%% in 6-max.",
                "leak.tight_vpip.title" to "Too tight preflop (VPIP)",
                "leak.tight_vpip.detail" to "VPIP %.0f%% — you enter too few pots.",
                "leak.limp.title" to "Too much limping / passive preflop",
                "leak.limp.detail" to "VPIP–PFR gap %.0f%% — you raise too rarely when entering.",
                "leak.fold_3bet.title" to "Folding too often to 3-bets",
                "leak.fold_3bet.detail" to "Fold to 3-bet %.0f%% — you may be exploitable.",
                "leak.passive.title" to "Passive postflop",
                "leak.passive.detail" to "AF %.1f — bet/raise more instead of calling.",
                "leak.wsd.title" to "Going to showdown too often",
                "leak.wsd.detail" to "WSD %.0f%% — fold weak hands more often.",
                "leak.wsd_win.title" to "Weak showdown win rate",
                "leak.wsd_win.detail" to "W\$SD %.0f%% — you reach showdown with worse hands.",
                "leak.sb_loss.title" to "Big losses from the SB",
                "leak.sb_loss.detail" to "SB bb/100: %.1f — tighten your SB range.",
                "leak.bb_loss.title" to "Big losses from the BB",
                "leak.bb_loss.detail" to "BB bb/100: %.1f — defend better against steals."
            )
        )
    }
}
