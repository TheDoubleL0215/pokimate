import Foundation

/// Seat relative to the dealer button (clockwise).
enum TablePosition: String, CaseIterable, Codable, Hashable, Sendable {
    case btn
    case sb
    case bb
    case utg
    case mp
    case co

    var displayName: String {
        switch self {
        case .btn: return "BTN"
        case .sb: return "SB"
        case .bb: return "BB"
        case .utg: return "UTG"
        case .mp: return "MP"
        case .co: return "CO"
        }
    }

    /// Maps a seat index to a named position given the dealer and table size.
    static func resolve(seat: Int, dealerIndex: Int, playerCount: Int) -> TablePosition {
        guard playerCount > 0 else { return .btn }
        let offset = (seat - dealerIndex + playerCount) % playerCount

        if playerCount == 2 {
            return offset == 0 ? .btn : .bb
        }

        switch offset {
        case 0: return .btn
        case 1: return .sb
        case 2: return .bb
        default:
            break
        }

        let remaining = playerCount - 3
        let postBlindOffset = offset - 3
        if remaining == 1 {
            return .utg
        }
        if remaining == 2 {
            return postBlindOffset == 0 ? .utg : .co
        }
        if remaining == 3 {
            switch postBlindOffset {
            case 0: return .utg
            case 1: return .mp
            default: return .co
            }
        }
        // 6-max+: UTG, MP, …, CO
        if postBlindOffset == 0 { return .utg }
        if postBlindOffset == remaining - 1 { return .co }
        return .mp
    }
}
