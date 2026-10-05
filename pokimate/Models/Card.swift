import Foundation

// MARK: - Suit

enum Suit: String, CaseIterable, Codable, Hashable {
    case hearts
    case diamonds
    case clubs
    case spades

    var symbol: String {
        switch self {
        case .hearts: return "♥"
        case .diamonds: return "♦"
        case .clubs: return "♣"
        case .spades: return "♠"
        }
    }

    var isRed: Bool {
        self == .hearts || self == .diamonds
    }
}

// MARK: - Rank

enum Rank: Int, CaseIterable, Codable, Comparable, Hashable {
    case two = 2
    case three = 3
    case four = 4
    case five = 5
    case six = 6
    case seven = 7
    case eight = 8
    case nine = 9
    case ten = 10
    case jack = 11
    case queen = 12
    case king = 13
    case ace = 14

    var display: String {
        switch self {
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .ten: return "10"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        }
    }

    static func < (lhs: Rank, rhs: Rank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Card

struct Card: Identifiable, Hashable, Codable {
    let id: UUID
    let suit: Suit
    let rank: Rank

    init(suit: Suit, rank: Rank, id: UUID = UUID()) {
        self.id = id
        self.suit = suit
        self.rank = rank
    }

    var displayText: String {
        "\(rank.display)\(suit.symbol)"
    }
}

// MARK: - Deck

struct Deck {
    private(set) var cards: [Card]

    init() {
        cards = Suit.allCases.flatMap { suit in
            Rank.allCases.map { rank in
                Card(suit: suit, rank: rank)
            }
        }
    }

    mutating func shuffle() {
        cards.shuffle()
    }

    mutating func draw() -> Card? {
        guard !cards.isEmpty else { return nil }
        return cards.removeFirst()
    }

    mutating func draw(count: Int) -> [Card] {
        var drawn: [Card] = []
        drawn.reserveCapacity(count)
        for _ in 0..<count {
            guard let card = draw() else { break }
            drawn.append(card)
        }
        return drawn
    }

    var remainingCount: Int { cards.count }
}
