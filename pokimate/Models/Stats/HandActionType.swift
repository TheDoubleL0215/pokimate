import Foundation

enum HandActionType: String, Codable, Hashable, Sendable {
    case fold
    case check
    case call
    case bet
    case raise
    case blind

    var isAggressive: Bool {
        self == .bet || self == .raise
    }

    var isVoluntary: Bool {
        self != .blind
    }
}

enum HandStreet: String, Codable, Hashable, Sendable {
    case preflop
    case flop
    case turn
    case river

    init(phase: GamePhase) {
        switch phase {
        case .preFlop: self = .preflop
        case .flop: self = .flop
        case .turn: self = .turn
        case .river: self = .river
        default: self = .preflop
        }
    }
}
