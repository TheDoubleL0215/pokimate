import Foundation
import GRDB

// MARK: - Session

struct StatsSession: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "sessions"

    var id: String
    var startedAt: Date
    var endedAt: Date?
    var bigBlind: Int
    var raiseAmount: Int
    var startingChips: Int
    var endingChips: Int?
    var botCount: Int
    var blindsEnabled: Bool
    var handsPlayed: Int
    var netProfit: Int

    enum Columns: String, ColumnExpression {
        case id, startedAt, endedAt, bigBlind, raiseAmount, startingChips
        case endingChips, botCount, blindsEnabled, handsPlayed, netProfit
    }
}

// MARK: - Hand

struct StatsHand: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "hands"

    var id: String
    var sessionId: String
    var handIndex: Int
    var dealerSeat: Int
    var humanSeat: Int
    var humanPosition: String
    var bigBlind: Int
    var boardJSON: String
    var humanHoleJSON: String
    var netWon: Int
    var allInEV: Double?
    var wentToShowdown: Bool
    var wonAtShowdown: Bool
    var endedAt: Date

    enum Columns: String, ColumnExpression {
        case id, sessionId, handIndex, dealerSeat, humanSeat, humanPosition
        case bigBlind, boardJSON, humanHoleJSON, netWon, allInEV
        case wentToShowdown, wonAtShowdown, endedAt
    }
}

// MARK: - Action

struct StatsAction: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "actions"

    var id: Int64?
    var handId: String
    var sequence: Int
    var street: String
    var seat: Int
    var isHero: Bool
    var actionType: String
    var amount: Int
    var facingRaises: Int
    var isVoluntary: Bool

    enum Columns: String, ColumnExpression {
        case id, handId, sequence, street, seat, isHero
        case actionType, amount, facingRaises, isVoluntary
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Card encoding helpers

enum CardCodec {
    static func encode(_ cards: [Card]) -> String {
        cards.map { "\($0.rank.rawValue)\(suitLetter($0.suit))" }
            .joined(separator: ",")
    }

    static func decode(_ raw: String) -> [Card] {
        guard !raw.isEmpty else { return [] }
        return raw.split(separator: ",").compactMap { token in
            let s = String(token)
            let digits = s.prefix(while: \.isNumber)
            guard let rankVal = Int(digits),
                  let rank = Rank(rawValue: rankVal),
                  let suitLetter = s.dropFirst(digits.count).first,
                  let suit = suit(from: suitLetter)
            else { return nil }
            return Card(suit: suit, rank: rank)
        }
    }

    /// Canonical hand key for 13×13 matrix (e.g. "AKs", "AKo", "QQ").
    static func matrixKey(for cards: [Card]) -> String? {
        guard cards.count == 2 else { return nil }
        let a = cards[0]
        let b = cards[1]
        let high = max(a.rank, b.rank)
        let low = min(a.rank, b.rank)
        if high == low {
            return "\(matrixRank(high))\(matrixRank(low))"
        }
        let suited = a.suit == b.suit
        return "\(matrixRank(high))\(matrixRank(low))\(suited ? "s" : "o")"
    }

    static let matrixRanks: [Rank] = [
        .ace, .king, .queen, .jack, .ten, .nine, .eight,
        .seven, .six, .five, .four, .three, .two
    ]

    static func matrixRank(_ rank: Rank) -> String {
        switch rank {
        case .ace: return "A"
        case .king: return "K"
        case .queen: return "Q"
        case .jack: return "J"
        case .ten: return "T"
        default: return rank.display
        }
    }

    private static func suitLetter(_ suit: Suit) -> String {
        switch suit {
        case .hearts: return "h"
        case .diamonds: return "d"
        case .clubs: return "c"
        case .spades: return "s"
        }
    }

    private static func suit(from letter: Character) -> Suit? {
        switch letter {
        case "h": return .hearts
        case "d": return .diamonds
        case "c": return .clubs
        case "s": return .spades
        default: return nil
        }
    }
}

// MARK: - Filter / summary DTOs

struct StatsDateRange: Hashable {
    var start: Date?
    var end: Date?

    static let all = StatsDateRange(start: nil, end: nil)

    static func lastHours(_ hours: Int) -> StatsDateRange {
        StatsDateRange(start: Date().addingTimeInterval(-Double(hours) * 3600), end: nil)
    }

    static func thisWeek() -> StatsDateRange {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))
        return StatsDateRange(start: start, end: nil)
    }

    static func thisMonth() -> StatsDateRange {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: Date()))
        return StatsDateRange(start: start, end: nil)
    }
}

struct StatsFilter: Hashable {
    var dateRange: StatsDateRange = .all
    var bigBlind: Int? = nil
}

struct BankrollSummary: Hashable {
    var hands: Int
    var netProfit: Int
    var bigBlind: Int
    var hoursPlayed: Double
    var sessions: Int

    var bbPer100: Double {
        guard hands > 0, bigBlind > 0 else { return 0 }
        return (Double(netProfit) / Double(bigBlind)) / (Double(hands) / 100.0)
    }

    var hourlyRate: Double {
        guard hoursPlayed > 0 else { return 0 }
        return Double(netProfit) / hoursPlayed
    }
}

struct ProfitPoint: Identifiable, Hashable {
    var id: Int { handOrdinal }
    var handOrdinal: Int
    var cumulativeProfit: Double
    var cumulativeEV: Double
}

struct DayProfit: Identifiable, Hashable {
    var id: String { dayKey }
    var dayKey: String
    var date: Date
    var netProfit: Int
    var hands: Int
}

struct PositionStat: Identifiable, Hashable {
    var id: String { position }
    var position: String
    var hands: Int
    var netWon: Int
    var bigBlind: Int

    var bbPer100: Double {
        guard hands > 0, bigBlind > 0 else { return 0 }
        return (Double(netWon) / Double(bigBlind)) / (Double(hands) / 100.0)
    }
}

struct HUDStats: Hashable {
    var hands: Int
    var vpip: Double
    var pfr: Double
    var threeBet: Double
    var foldToThreeBet: Double
    var cbet: Double
    var aggressionFactor: Double
    var wsd: Double
    var wDollarSD: Double
}

struct RangeCell: Identifiable, Hashable {
    var id: String { key }
    var key: String
    var row: Int
    var col: Int
    var hands: Int
    var netWon: Int
}

struct LeakWarning: Identifiable, Hashable {
    var id: String { title }
    var title: String
    var detail: String
    var severity: Int
}
