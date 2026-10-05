import SwiftUI
import Charts
import Combine

@MainActor
final class StatsViewModel: ObservableObject {
    @Published var filter = StatsFilter()
    @Published var selectedPeriod: Period = .all
    @Published var summary = BankrollSummary(hands: 0, netProfit: 0, bigBlind: 1, hoursPlayed: 0, sessions: 0)
    @Published var profitPoints: [ProfitPoint] = []
    @Published var dayProfits: [DayProfit] = []
    @Published var positionStats: [PositionStat] = []
    @Published var hud = HUDStats(
        hands: 0, vpip: 0, pfr: 0, threeBet: 0, foldToThreeBet: 0,
        cbet: 0, aggressionFactor: 0, wsd: 0, wDollarSD: 0
    )
    @Published var rangeCells: [RangeCell] = []
    @Published var leaks: [LeakWarning] = []
    @Published var stakes: [Int] = []
    @Published var sessions: [StatsSession] = []

    enum Period: String, CaseIterable, Identifiable {
        case all, day, week, month
        var id: String { rawValue }

        @MainActor
        var title: String {
            switch self {
            case .all: return L10n.t("stats.period.all")
            case .day: return L10n.t("stats.period.day")
            case .week: return L10n.t("stats.period.week")
            case .month: return L10n.t("stats.period.month")
            }
        }
    }

    func reload() {
        switch selectedPeriod {
        case .all: filter.dateRange = .all
        case .day: filter.dateRange = .lastHours(24)
        case .week: filter.dateRange = .thisWeek()
        case .month: filter.dateRange = .thisMonth()
        }

        let store = StatsStore.shared
        summary = store.bankrollSummary(filter: filter)
        profitPoints = store.profitSeries(filter: filter)
        dayProfits = store.dayProfits(filter: filter)
        positionStats = store.positionStats(filter: filter)
        stakes = store.availableStakes()
        sessions = store.recentSessions()

        let hands = store.hands(filter: filter)
        let actions = store.actions(forHandIds: hands.map(\.id))
        hud = StatsAggregator.hud(hands: hands, actions: actions)
        rangeCells = StatsAggregator.rangeMatrix(hands: hands)
        leaks = LeakDetector.warnings(hud: hud, positions: positionStats)
    }
}
