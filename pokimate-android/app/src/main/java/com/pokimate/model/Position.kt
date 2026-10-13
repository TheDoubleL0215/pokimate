package com.pokimate.model

/** Seat relative to the dealer button (clockwise). */
enum class TablePosition(val rawValue: String) {
    BTN("btn"),
    SB("sb"),
    BB("bb"),
    UTG("utg"),
    MP("mp"),
    CO("co");

    val displayName: String
        get() = when (this) {
            BTN -> "BTN"
            SB -> "SB"
            BB -> "BB"
            UTG -> "UTG"
            MP -> "MP"
            CO -> "CO"
        }

    companion object {
        /** Maps a seat index to a named position given the dealer and table size. */
        fun resolve(seat: Int, dealerIndex: Int, playerCount: Int): TablePosition {
            if (playerCount <= 0) return BTN
            val offset = (seat - dealerIndex + playerCount) % playerCount

            if (playerCount == 2) {
                return if (offset == 0) BTN else BB
            }

            when (offset) {
                0 -> return BTN
                1 -> return SB
                2 -> return BB
            }

            val remaining = playerCount - 3
            val postBlindOffset = offset - 3
            if (remaining == 1) return UTG
            if (remaining == 2) {
                return if (postBlindOffset == 0) UTG else CO
            }
            if (remaining == 3) {
                return when (postBlindOffset) {
                    0 -> UTG
                    1 -> MP
                    else -> CO
                }
            }
            // 6-max+: UTG, MP, …, CO
            if (postBlindOffset == 0) return UTG
            if (postBlindOffset == remaining - 1) return CO
            return MP
        }

        fun fromRaw(raw: String): TablePosition? =
            entries.find { it.rawValue == raw }
    }
}
