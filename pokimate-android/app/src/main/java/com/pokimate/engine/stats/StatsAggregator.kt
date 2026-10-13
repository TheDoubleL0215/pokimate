package com.pokimate.engine.stats

import com.pokimate.model.CardCodec
import com.pokimate.model.HUDStats
import com.pokimate.model.HandActionType
import com.pokimate.model.HandStreet
import com.pokimate.model.RangeCell
import com.pokimate.model.StatsAction
import com.pokimate.model.StatsHand

object StatsAggregator {

    fun hud(hands: List<StatsHand>, actions: List<StatsAction>): HUDStats {
        if (hands.isEmpty()) {
            return HUDStats(
                hands = 0, vpip = 0.0, pfr = 0.0, threeBet = 0.0, foldToThreeBet = 0.0,
                cbet = 0.0, aggressionFactor = 0.0, wsd = 0.0, wDollarSD = 0.0
            )
        }

        val byHand = actions.filter { it.isHero }.groupBy { it.handId }
        val allByHand = actions.groupBy { it.handId }

        var vpipCount = 0
        var pfrCount = 0
        var threeBetOpps = 0
        var threeBets = 0
        var foldTo3BetOpps = 0
        var foldTo3Bets = 0
        var cbetOpps = 0
        var cbets = 0
        var postflopBetsRaises = 0
        var postflopCalls = 0
        var wsdCount = 0
        var wDollarSDCount = 0

        val preflopAggressorSeat = mutableMapOf<String, Int>()
        for ((handId, handActions) in allByHand) {
            val pre = handActions
                .filter { it.street == HandStreet.PREFLOP.rawValue }
                .sortedBy { it.sequence }
            val lastRaise = pre.lastOrNull {
                it.actionType == HandActionType.RAISE.rawValue ||
                    it.actionType == HandActionType.BET.rawValue
            }
            if (lastRaise != null) {
                preflopAggressorSeat[handId] = lastRaise.seat
            }
        }

        for (hand in hands) {
            val heroActs = (byHand[hand.id] ?: emptyList()).sortedBy { it.sequence }
            val preflop = heroActs.filter { it.street == HandStreet.PREFLOP.rawValue }

            val voluntary = preflop.filter {
                it.isVoluntary &&
                    (it.actionType == HandActionType.CALL.rawValue ||
                        it.actionType == HandActionType.BET.rawValue ||
                        it.actionType == HandActionType.RAISE.rawValue)
            }
            if (voluntary.isNotEmpty()) vpipCount += 1

            if (preflop.any {
                    it.actionType == HandActionType.RAISE.rawValue ||
                        it.actionType == HandActionType.BET.rawValue
                }
            ) {
                pfrCount += 1
            }

            val raiseFacing = preflop.firstOrNull {
                it.facingRaises >= 1 && it.actionType != HandActionType.BLIND.rawValue
            }
            if (raiseFacing != null) {
                threeBetOpps += 1
                if (raiseFacing.actionType == HandActionType.RAISE.rawValue) {
                    threeBets += 1
                }
            }

            val foldVs3 = preflop.firstOrNull { it.facingRaises >= 2 }
            if (foldVs3 != null) {
                foldTo3BetOpps += 1
                if (foldVs3.actionType == HandActionType.FOLD.rawValue) {
                    foldTo3Bets += 1
                }
            }

            if (preflopAggressorSeat[hand.id] == hand.humanSeat) {
                val flopActs = heroActs.filter { it.street == HandStreet.FLOP.rawValue }
                if (flopActs.isNotEmpty()) {
                    cbetOpps += 1
                    if (flopActs.any {
                            it.actionType == HandActionType.BET.rawValue ||
                                it.actionType == HandActionType.RAISE.rawValue
                        }
                    ) {
                        cbets += 1
                    }
                }
            }

            for (act in heroActs.filter { it.street != HandStreet.PREFLOP.rawValue }) {
                when (act.actionType) {
                    HandActionType.BET.rawValue, HandActionType.RAISE.rawValue ->
                        postflopBetsRaises += 1
                    HandActionType.CALL.rawValue ->
                        postflopCalls += 1
                }
            }

            if (hand.wentToShowdown) {
                wsdCount += 1
                if (hand.wonAtShowdown) wDollarSDCount += 1
            }
        }

        val n = hands.size.toDouble()
        val afDenom = maxOf(postflopCalls, 1).toDouble()
        val sawFlopOrLater = maxOf(
            hands.count { hand ->
                val heroActs = byHand[hand.id] ?: emptyList()
                heroActs.any { it.street != HandStreet.PREFLOP.rawValue } || hand.wentToShowdown
            },
            1
        )

        return HUDStats(
            hands = hands.size,
            vpip = 100.0 * vpipCount.toDouble() / n,
            pfr = 100.0 * pfrCount.toDouble() / n,
            threeBet = if (threeBetOpps > 0) 100.0 * threeBets.toDouble() / threeBetOpps.toDouble() else 0.0,
            foldToThreeBet = if (foldTo3BetOpps > 0) 100.0 * foldTo3Bets.toDouble() / foldTo3BetOpps.toDouble() else 0.0,
            cbet = if (cbetOpps > 0) 100.0 * cbets.toDouble() / cbetOpps.toDouble() else 0.0,
            aggressionFactor = postflopBetsRaises.toDouble() / afDenom,
            wsd = 100.0 * wsdCount.toDouble() / sawFlopOrLater.toDouble(),
            wDollarSD = if (wsdCount > 0) 100.0 * wDollarSDCount.toDouble() / wsdCount.toDouble() else 0.0
        )
    }

    fun rangeMatrix(hands: List<StatsHand>): List<RangeCell> {
        val ranks = CardCodec.matrixRanks
        val totals = mutableMapOf<String, Pair<Int, Int>>()

        for (hand in hands) {
            val hole = CardCodec.decode(hand.humanHoleJSON)
            val key = CardCodec.matrixKey(hole) ?: continue
            val entry = totals[key] ?: (0 to 0)
            totals[key] = (entry.first + 1) to (entry.second + hand.netWon)
        }

        val cells = mutableListOf<RangeCell>()
        for ((r, rowRank) in ranks.withIndex()) {
            for ((c, colRank) in ranks.withIndex()) {
                val rowLabel = CardCodec.matrixRank(rowRank)
                val colLabel = CardCodec.matrixRank(colRank)
                val key = when {
                    r == c -> "$rowLabel$colLabel"
                    c > r -> "${rowLabel}${colLabel}s"
                    else -> "${colLabel}${rowLabel}o"
                }
                val entry = totals[key] ?: (0 to 0)
                cells.add(RangeCell(key = key, row = r, col = c, hands = entry.first, netWon = entry.second))
            }
        }
        return cells
    }
}
