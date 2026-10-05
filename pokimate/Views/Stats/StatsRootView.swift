import SwiftUI
import Charts

struct StatsRootView: View {
    var onBack: () -> Void

    @EnvironmentObject private var l10n: LocalizationManager
    @StateObject private var model = StatsViewModel()
    @State private var tab: Tab = .bankroll

    private enum Tab: String, CaseIterable, Identifiable {
        case bankroll, hud, leaks
        var id: String { rawValue }

        @MainActor
        var title: String {
            switch self {
            case .bankroll: return L10n.t("stats.tab.bankroll")
            case .hud: return L10n.t("stats.tab.hud")
            case .leaks: return L10n.t("stats.tab.leaks")
            }
        }
    }

    var body: some View {
        ZStack {
            MenuBackground()

            VStack(spacing: 0) {
                header

                filterBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Picker("Tab", selection: $tab) {
                    ForEach(Tab.allCases) { t in
                        Text(t.title).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                ScrollView {
                    Group {
                        switch tab {
                        case .bankroll:
                            BankrollStatsView(model: model)
                        case .hud:
                            HUDStatsView(model: model)
                        case .leaks:
                            LeakStatsView(model: model)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .onAppear { model.reload() }
        .onChange(of: model.selectedPeriod) { _, _ in model.reload() }
        .onChange(of: model.filter.bigBlind) { _, _ in model.reload() }
    }

    private var header: some View {
        HStack {
            GlassBackButton(action: onBack)

            Spacer()

            Text(l10n.t("stats.title"))
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(PokerTheme.textPrimary)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var filterBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(StatsViewModel.Period.allCases) { period in
                    GameCapsuleChip(
                        title: period.title,
                        isSelected: model.selectedPeriod == period
                    ) {
                        model.selectedPeriod = period
                    }
                }
            }

            if !model.stakes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        GameCapsuleChip(
                            title: l10n.t("stats.all_stakes"),
                            isSelected: model.filter.bigBlind == nil
                        ) {
                            model.filter.bigBlind = nil
                        }
                        ForEach(model.stakes, id: \.self) { bb in
                            GameCapsuleChip(
                                title: "BB \(bb)",
                                isSelected: model.filter.bigBlind == bb
                            ) {
                                model.filter.bigBlind = bb
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Bankroll

struct BankrollStatsView: View {
    @ObservedObject var model: StatsViewModel
    @EnvironmentObject private var l10n: LocalizationManager

    var body: some View {
        VStack(spacing: 16) {
            summaryCards

            MenuPanel {
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle(l10n.t("stats.cumulative"))
                    if model.profitPoints.isEmpty {
                        emptyState(l10n.t("stats.empty_hands"))
                    } else {
                        Chart {
                            ForEach(model.profitPoints) { point in
                                LineMark(
                                    x: .value("Hands", point.handOrdinal),
                                    y: .value("Profit", point.cumulativeProfit)
                                )
                                .foregroundStyle(Color.green.opacity(0.9))
                                .lineStyle(StrokeStyle(lineWidth: 2.2))

                                LineMark(
                                    x: .value("Hands", point.handOrdinal),
                                    y: .value("EV", point.cumulativeEV)
                                )
                                .foregroundStyle(Color.orange.opacity(0.85))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                            }
                        }
                        .frame(height: 200)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4))
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }

                        HStack(spacing: 16) {
                            legendDot(color: .green, title: l10n.t("stats.legend.actual"))
                            legendDot(color: .orange, title: l10n.t("stats.legend.ev"))
                        }
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                }
            }

            MenuPanel {
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle(l10n.t("stats.daily"))
                    if model.dayProfits.isEmpty {
                        emptyState(l10n.t("stats.empty_calendar"))
                    } else {
                        CalendarHeatmapView(days: model.dayProfits)
                    }
                }
            }

            if !model.sessions.isEmpty {
                MenuPanel {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle(l10n.t("stats.recent_sessions"))
                        ForEach(model.sessions.prefix(8)) { session in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(PokerTheme.textPrimary)
                                    Text(l10n.format("stats.session_meta", session.handsPlayed, session.bigBlind))
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(PokerTheme.textSecondary)
                                }
                                Spacer()
                                Text(signed(session.netProfit))
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundStyle(session.netProfit >= 0 ? Color.green : Color.red.opacity(0.85))
                            }
                            if session.id != model.sessions.prefix(8).last?.id {
                                Divider().background(PokerTheme.cardStroke)
                            }
                        }
                    }
                }
            }
        }
    }

    private var summaryCards: some View {
        let s = model.summary
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricCard(title: l10n.t("stats.net_pl"), value: signed(s.netProfit))
            metricCard(title: l10n.t("stats.hands"), value: "\(s.hands)")
            metricCard(title: "bb/100", value: String(format: "%.1f", s.bbPer100))
            metricCard(title: l10n.t("stats.hourly"), value: String(format: "%.0f", s.hourlyRate))
        }
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(PokerTheme.textSecondary)
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(PokerTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PokerTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(PokerTheme.cardStroke, lineWidth: 1)
                )
        )
    }
}

// MARK: - HUD

struct HUDStatsView: View {
    @ObservedObject var model: StatsViewModel
    @EnvironmentObject private var l10n: LocalizationManager

    var body: some View {
        VStack(spacing: 16) {
            MenuPanel {
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle(l10n.t("stats.hero_style"))
                    if model.hud.hands == 0 {
                        emptyState(l10n.t("stats.empty_hud"))
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            hudCell("VPIP", String(format: "%.0f%%", model.hud.vpip))
                            hudCell("PFR", String(format: "%.0f%%", model.hud.pfr))
                            hudCell("3-Bet", String(format: "%.0f%%", model.hud.threeBet))
                            hudCell("Fold 3B", String(format: "%.0f%%", model.hud.foldToThreeBet))
                            hudCell("C-Bet", String(format: "%.0f%%", model.hud.cbet))
                            hudCell("AF", String(format: "%.1f", model.hud.aggressionFactor))
                            hudCell("WSD", String(format: "%.0f%%", model.hud.wsd))
                            hudCell("W$SD", String(format: "%.0f%%", model.hud.wDollarSD))
                            hudCell(l10n.t("stats.hands"), "\(model.hud.hands)")
                        }
                    }
                }
            }

            MenuPanel {
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle(l10n.t("stats.bb_by_position"))
                    if model.positionStats.isEmpty {
                        emptyState(l10n.t("stats.empty_position"))
                    } else {
                        Chart(model.positionStats) { stat in
                            BarMark(
                                x: .value("Pos", stat.position),
                                y: .value("bb/100", stat.bbPer100)
                            )
                            .foregroundStyle(stat.bbPer100 >= 0 ? Color.green.opacity(0.85) : Color.red.opacity(0.75))
                        }
                        .frame(height: 180)
                    }
                }
            }

            MenuPanel {
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle(l10n.t("stats.range_heatmap"))
                    RangeHeatmapView(cells: model.rangeCells)
                }
            }
        }
    }

    private func hudCell(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(PokerTheme.textSecondary)
            Text(value)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(PokerTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PokerTheme.foldFill)
        )
    }
}

// MARK: - Leaks

struct LeakStatsView: View {
    @ObservedObject var model: StatsViewModel
    @EnvironmentObject private var l10n: LocalizationManager

    var body: some View {
        VStack(spacing: 16) {
            MenuPanel {
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle(l10n.t("stats.warnings"))
                    if model.leaks.isEmpty {
                        emptyState(model.hud.hands < 30
                                   ? l10n.t("stats.leaks_need_hands")
                                   : l10n.t("stats.leaks_none"))
                    } else {
                        ForEach(model.leaks) { leak in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Circle()
                                        .fill(severityColor(leak.severity))
                                        .frame(width: 8, height: 8)
                                    Text(leak.title)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(PokerTheme.textPrimary)
                                }
                                Text(leak.detail)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(PokerTheme.textSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }

    private func severityColor(_ s: Int) -> Color {
        switch s {
        case 3: return .red
        case 2: return .orange
        default: return .yellow
        }
    }
}

// MARK: - Shared bits

private func sectionTitle(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 15, weight: .bold, design: .rounded))
        .foregroundStyle(PokerTheme.textPrimary)
}

private func emptyState(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .foregroundStyle(PokerTheme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
}

private func legendDot(color: Color, title: String) -> some View {
    HStack(spacing: 6) {
        Circle().fill(color).frame(width: 8, height: 8)
        Text(title).foregroundStyle(PokerTheme.textSecondary)
    }
}

private func signed(_ value: Int) -> String {
    value >= 0 ? "+\(value)" : "\(value)"
}

struct CalendarHeatmapView: View {
    let days: [DayProfit]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let recent = Array(days.suffix(56))
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(recent) { day in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color(for: day.netProfit))
                    .frame(height: 18)
                    .overlay(
                        Text(day.hands > 0 ? "\(min(day.hands, 99))" : "")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.75))
                    )
                    .accessibilityLabel("\(day.dayKey): \(day.netProfit)")
            }
        }
    }

    private func color(for net: Int) -> Color {
        if net > 0 { return Color.green.opacity(min(0.35 + Double(net) / 2000.0, 0.95)) }
        if net < 0 { return Color.red.opacity(min(0.35 + Double(-net) / 2000.0, 0.95)) }
        return PokerTheme.foldFill
    }
}

struct RangeHeatmapView: View {
    let cells: [RangeCell]

    private let ranks = CardCodec.matrixRanks
    private let spacing: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = max(8.0, (side - spacing * 12) / 13)
            let grid = cell * 13 + spacing * 12

            VStack(spacing: spacing) {
                ForEach(0..<13, id: \.self) { r in
                    HStack(spacing: spacing) {
                        ForEach(0..<13, id: \.self) { c in
                            let item = cells.first { $0.row == r && $0.col == c }
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(fill(for: item))
                                .frame(width: cell, height: cell)
                                .overlay(
                                    Text(shortLabel(r: r, c: c))
                                        .font(.system(size: max(5, cell * 0.3), weight: .bold, design: .rounded))
                                        .minimumScaleFactor(0.5)
                                        .lineLimit(1)
                                        .foregroundStyle(Color.white.opacity((item?.hands ?? 0) > 0 ? 0.9 : 0.25))
                                )
                        }
                    }
                }
            }
            .frame(width: grid, height: grid)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func shortLabel(r: Int, c: Int) -> String {
        let a = CardCodec.matrixRank(ranks[r])
        let b = CardCodec.matrixRank(ranks[c])
        if r == c { return "\(a)\(b)" }
        if c > r { return "\(a)\(b)s" }
        return "\(b)\(a)o"
    }

    private func fill(for cell: RangeCell?) -> Color {
        guard let cell, cell.hands > 0 else {
            return PokerTheme.foldFill.opacity(0.6)
        }
        if cell.netWon > 0 {
            return Color.green.opacity(min(0.35 + Double(cell.netWon) / 800.0, 0.95))
        }
        if cell.netWon < 0 {
            return Color.red.opacity(min(0.35 + Double(-cell.netWon) / 800.0, 0.95))
        }
        return PokerTheme.brandBlue.opacity(0.35)
    }
}
