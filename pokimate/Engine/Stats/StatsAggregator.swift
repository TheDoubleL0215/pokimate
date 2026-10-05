import Foundation

enum StatsAggregator {

    static func hud(hands: [StatsHand], actions: [StatsAction]) -> HUDStats {
        guard !hands.isEmpty else {
            return HUDStats(
                hands: 0, vpip: 0, pfr: 0, threeBet: 0, foldToThreeBet: 0,
                cbet: 0, aggressionFactor: 0, wsd: 0, wDollarSD: 0
            )
        }

        let byHand = Dictionary(grouping: actions.filter(\.isHero), by: \.handId)
        let allByHand = Dictionary(grouping: actions, by: \.handId)

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

        var preflopAggressorSeat: [String: Int] = [:]
        for (handId, handActions) in allByHand {
            let pre = handActions
                .filter { $0.street == HandStreet.preflop.rawValue }
                .sorted { $0.sequence < $1.sequence }
            if let lastRaise = pre.last(where: {
                $0.actionType == HandActionType.raise.rawValue || $0.actionType == HandActionType.bet.rawValue
            }) {
                preflopAggressorSeat[handId] = lastRaise.seat
            }
        }

        for hand in hands {
            let heroActs = (byHand[hand.id] ?? []).sorted { $0.sequence < $1.sequence }
            let preflop = heroActs.filter { $0.street == HandStreet.preflop.rawValue }

            let voluntary = preflop.filter {
                $0.isVoluntary &&
                ($0.actionType == HandActionType.call.rawValue
                 || $0.actionType == HandActionType.bet.rawValue
                 || $0.actionType == HandActionType.raise.rawValue)
            }
            if !voluntary.isEmpty { vpipCount += 1 }

            if preflop.contains(where: {
                $0.actionType == HandActionType.raise.rawValue || $0.actionType == HandActionType.bet.rawValue
            }) {
                pfrCount += 1
            }

            if let raiseFacing = preflop.first(where: {
                $0.facingRaises >= 1 && $0.actionType != HandActionType.blind.rawValue
            }) {
                threeBetOpps += 1
                if raiseFacing.actionType == HandActionType.raise.rawValue {
                    threeBets += 1
                }
            }

            if let foldVs3 = preflop.first(where: { $0.facingRaises >= 2 }) {
                foldTo3BetOpps += 1
                if foldVs3.actionType == HandActionType.fold.rawValue {
                    foldTo3Bets += 1
                }
            }

            if preflopAggressorSeat[hand.id] == hand.humanSeat {
                let flopActs = heroActs.filter { $0.street == HandStreet.flop.rawValue }
                if !flopActs.isEmpty {
                    cbetOpps += 1
                    if flopActs.contains(where: {
                        $0.actionType == HandActionType.bet.rawValue
                            || $0.actionType == HandActionType.raise.rawValue
                    }) {
                        cbets += 1
                    }
                }
            }

            for act in heroActs where act.street != HandStreet.preflop.rawValue {
                switch act.actionType {
                case HandActionType.bet.rawValue, HandActionType.raise.rawValue:
                    postflopBetsRaises += 1
                case HandActionType.call.rawValue:
                    postflopCalls += 1
                default:
                    break
                }
            }

            if hand.wentToShowdown {
                wsdCount += 1
                if hand.wonAtShowdown { wDollarSDCount += 1 }
            }
        }

        let n = Double(hands.count)
        let afDenom = Double(max(postflopCalls, 1))
        let sawFlopOrLater = max(hands.filter { hand in
            let heroActs = byHand[hand.id] ?? []
            return heroActs.contains { $0.street != HandStreet.preflop.rawValue } || hand.wentToShowdown
        }.count, 1)

        return HUDStats(
            hands: hands.count,
            vpip: 100.0 * Double(vpipCount) / n,
            pfr: 100.0 * Double(pfrCount) / n,
            threeBet: threeBetOpps > 0 ? 100.0 * Double(threeBets) / Double(threeBetOpps) : 0,
            foldToThreeBet: foldTo3BetOpps > 0 ? 100.0 * Double(foldTo3Bets) / Double(foldTo3BetOpps) : 0,
            cbet: cbetOpps > 0 ? 100.0 * Double(cbets) / Double(cbetOpps) : 0,
            aggressionFactor: Double(postflopBetsRaises) / afDenom,
            wsd: 100.0 * Double(wsdCount) / Double(sawFlopOrLater),
            wDollarSD: wsdCount > 0 ? 100.0 * Double(wDollarSDCount) / Double(wsdCount) : 0
        )
    }

    static func rangeMatrix(hands: [StatsHand]) -> [RangeCell] {
        let ranks = CardCodec.matrixRanks
        var totals: [String: (hands: Int, net: Int)] = [:]

        for hand in hands {
            let hole = CardCodec.decode(hand.humanHoleJSON)
            guard let key = CardCodec.matrixKey(for: hole) else { continue }
            var entry = totals[key] ?? (0, 0)
            entry.hands += 1
            entry.net += hand.netWon
            totals[key] = entry
        }

        var cells: [RangeCell] = []
        for (r, rowRank) in ranks.enumerated() {
            for (c, colRank) in ranks.enumerated() {
                let rowLabel = CardCodec.matrixRank(rowRank)
                let colLabel = CardCodec.matrixRank(colRank)
                let key: String
                if r == c {
                    key = "\(rowLabel)\(colLabel)"
                } else if c > r {
                    key = "\(rowLabel)\(colLabel)s"
                } else {
                    key = "\(colLabel)\(rowLabel)o"
                }
                let entry = totals[key] ?? (0, 0)
                cells.append(RangeCell(key: key, row: r, col: c, hands: entry.hands, netWon: entry.net))
            }
        }
        return cells
    }
}
