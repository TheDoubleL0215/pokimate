import Foundation

enum GamePhase: String, CaseIterable, Codable {
    case waiting
    case preFlop
    case flop
    case turn
    case river
    case showdown

    @MainActor
    var displayName: String {
        switch self {
        case .waiting: return L10n.t("phase.waiting")
        case .preFlop: return L10n.t("game.preflop")
        case .flop: return L10n.t("game.flop")
        case .turn: return L10n.t("game.turn")
        case .river: return L10n.t("game.river")
        case .showdown: return L10n.t("game.showdown")
        }
    }
}
