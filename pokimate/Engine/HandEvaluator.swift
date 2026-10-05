import Foundation

// MARK: - Hand Category

enum HandCategory: Int, Comparable, CaseIterable {
    case highCard = 0
    case onePair = 1
    case twoPair = 2
    case threeOfAKind = 3
    case straight = 4
    case flush = 5
    case fullHouse = 6
    case fourOfAKind = 7
    case straightFlush = 8
    case royalFlush = 9

    static func < (lhs: HandCategory, rhs: HandCategory) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    @MainActor
    var displayName: String {
        switch self {
        case .highCard: return L10n.t("hand.high_card")
        case .onePair: return L10n.t("hand.one_pair")
        case .twoPair: return L10n.t("hand.two_pair")
        case .threeOfAKind: return L10n.t("hand.three_of_a_kind")
        case .straight: return L10n.t("hand.straight")
        case .flush: return L10n.t("hand.flush")
        case .fullHouse: return L10n.t("hand.full_house")
        case .fourOfAKind: return L10n.t("hand.four_of_a_kind")
        case .straightFlush: return L10n.t("hand.straight_flush")
        case .royalFlush: return L10n.t("hand.royal_flush")
        }
    }
}

// MARK: - Evaluated Hand

struct EvaluatedHand: Comparable {
    let category: HandCategory
    /// Kickers / tie-break ranks, highest first.
    let ranks: [Int]
    /// The five cards that form this hand (subset of hole + community).
    let cards: [Card]

    static func < (lhs: EvaluatedHand, rhs: EvaluatedHand) -> Bool {
        if lhs.category != rhs.category {
            return lhs.category < rhs.category
        }
        for (l, r) in zip(lhs.ranks, rhs.ranks) {
            if l != r { return l < r }
        }
        return false
    }

    static func == (lhs: EvaluatedHand, rhs: EvaluatedHand) -> Bool {
        lhs.category == rhs.category && lhs.ranks == rhs.ranks
    }

    /// Cards that define the hand category get a strong highlight; the rest of
    /// the made five (kickers / fillers) get a softer one — e.g. pair = 2 strong + 3 soft.
    func highlightGroups() -> (primary: Set<UUID>, secondary: Set<UUID>) {
        let handIDs = Set(cards.map(\.id))
        let primaryRanks: Set<Int>

        switch category {
        case .highCard:
            primaryRanks = Set(ranks.prefix(2))
        case .onePair:
            primaryRanks = Set(ranks.prefix(1))
        case .twoPair:
            primaryRanks = Set(ranks.prefix(2))
        case .threeOfAKind:
            primaryRanks = Set(ranks.prefix(1))
        case .straight, .flush, .straightFlush, .royalFlush:
            // Every card is part of the made hand.
            return (handIDs, [])
        case .fullHouse:
            primaryRanks = Set(ranks.prefix(2))
        case .fourOfAKind:
            primaryRanks = Set(ranks.prefix(1))
        }

        let primary = Set(cards.filter { primaryRanks.contains($0.rank.rawValue) }.map(\.id))
        return (primary, handIDs.subtracting(primary))
    }
}

// MARK: - Hand Evaluator

enum HandEvaluator {

    /// Best 5-card hand from 2 hole + up to 5 community cards.
    static func evaluateBestHand(hole: [Card], community: [Card]) -> EvaluatedHand {
        let all = hole + community
        guard all.count >= 5 else {
            // Incomplete board — pad only for early/debug evaluation paths.
            var padded = all
            while padded.count < 5 {
                padded.append(Card(suit: .clubs, rank: .two))
            }
            return evaluateFiveCards(Array(padded.prefix(5)))
        }

        var best: EvaluatedHand?
        for combo in combinations(all, choosing: 5) {
            let evaluated = evaluateFiveCards(combo)
            if best == nil || evaluated > best! {
                best = evaluated
            }
        }
        return best ?? EvaluatedHand(category: .highCard, ranks: [0], cards: [])
    }

    /// Modular 5-card evaluation — expand here for edge cases.
    static func evaluateFiveCards(_ cards: [Card]) -> EvaluatedHand {
        precondition(cards.count == 5, "Exactly 5 cards required")

        let sortedRanks = cards.map(\.rank.rawValue).sorted(by: >)
        let isFlush = Set(cards.map(\.suit)).count == 1
        let straightHigh = straightHighRank(sortedRanks)

        if isFlush, let high = straightHigh {
            if high == Rank.ace.rawValue {
                return EvaluatedHand(category: .royalFlush, ranks: [high], cards: cards)
            }
            return EvaluatedHand(category: .straightFlush, ranks: [high], cards: cards)
        }

        let rankCounts = countByRank(sortedRanks)
        let countsDescending = rankCounts.map(\.count).sorted(by: >)

        if countsDescending.first == 4 {
            let quad = rankCounts.first { $0.count == 4 }!.rank
            let kicker = rankCounts.first { $0.count == 1 }!.rank
            return EvaluatedHand(category: .fourOfAKind, ranks: [quad, kicker], cards: cards)
        }

        if countsDescending == [3, 2] {
            let trips = rankCounts.first { $0.count == 3 }!.rank
            let pair = rankCounts.first { $0.count == 2 }!.rank
            return EvaluatedHand(category: .fullHouse, ranks: [trips, pair], cards: cards)
        }

        if isFlush {
            return EvaluatedHand(category: .flush, ranks: sortedRanks, cards: cards)
        }

        if let high = straightHigh {
            return EvaluatedHand(category: .straight, ranks: [high], cards: cards)
        }

        if countsDescending.first == 3 {
            let trips = rankCounts.first { $0.count == 3 }!.rank
            let kickers = rankCounts.filter { $0.count == 1 }.map(\.rank).sorted(by: >)
            return EvaluatedHand(category: .threeOfAKind, ranks: [trips] + kickers, cards: cards)
        }

        let pairs = rankCounts.filter { $0.count == 2 }.map(\.rank).sorted(by: >)
        if pairs.count == 2 {
            let kicker = rankCounts.first { $0.count == 1 }!.rank
            return EvaluatedHand(category: .twoPair, ranks: pairs + [kicker], cards: cards)
        }

        if pairs.count == 1 {
            let kickers = rankCounts.filter { $0.count == 1 }.map(\.rank).sorted(by: >)
            return EvaluatedHand(category: .onePair, ranks: [pairs[0]] + kickers, cards: cards)
        }

        return EvaluatedHand(category: .highCard, ranks: sortedRanks, cards: cards)
    }

    // MARK: - Helpers

    private static func countByRank(_ ranks: [Int]) -> [(rank: Int, count: Int)] {
        var map: [Int: Int] = [:]
        for r in ranks { map[r, default: 0] += 1 }
        return map.map { (rank: $0.key, count: $0.value) }
    }

    /// Returns the high card of a straight, or nil. Handles wheel (A-2-3-4-5).
    private static func straightHighRank(_ sortedDescending: [Int]) -> Int? {
        let unique = Array(Set(sortedDescending)).sorted(by: >)
        guard unique.count == 5 else { return nil }
        return checkStraight(unique)
    }

    private static func checkStraight(_ uniqueDescending: [Int]) -> Int? {
        let ranks = uniqueDescending.sorted(by: >)
        // Normal straight
        var consecutive = true
        for i in 0..<(ranks.count - 1) {
            if ranks[i] - ranks[i + 1] != 1 {
                consecutive = false
                break
            }
        }
        if consecutive && ranks.count == 5 {
            return ranks[0]
        }

        // Wheel: A,5,4,3,2
        let wheel: Set<Int> = [14, 5, 4, 3, 2]
        if Set(ranks) == wheel {
            return 5
        }
        return nil
    }

    private static func combinations(_ array: [Card], choosing k: Int) -> [[Card]] {
        guard k > 0, array.count >= k else { return [] }
        if k == array.count { return [array] }
        if k == 1 { return array.map { [$0] } }

        var result: [[Card]] = []
        for i in 0...(array.count - k) {
            let head = array[i]
            let tailCombos = combinations(Array(array[(i + 1)...]), choosing: k - 1)
            for combo in tailCombos {
                result.append([head] + combo)
            }
        }
        return result
    }
}
