import Foundation
import GRDB

@MainActor
final class StatsStore {
    static let shared = StatsStore()

    private let dbQueue: DatabaseQueue

    private init() {
        let queue: DatabaseQueue
        do {
            let folder = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("pokimate", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let dbURL = folder.appendingPathComponent("stats.sqlite")
            queue = try DatabaseQueue(path: dbURL.path)
        } catch {
            assertionFailure("StatsStore failed to open on disk: \(error)")
            queue = try! DatabaseQueue()
        }
        dbQueue = queue
        try? Self.makeMigrator().migrate(dbQueue)
    }

    private static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_stats") { db in
            try db.create(table: "sessions") { t in
                t.column("id", .text).primaryKey()
                t.column("startedAt", .datetime).notNull()
                t.column("endedAt", .datetime)
                t.column("bigBlind", .integer).notNull()
                t.column("raiseAmount", .integer).notNull()
                t.column("startingChips", .integer).notNull()
                t.column("endingChips", .integer)
                t.column("botCount", .integer).notNull()
                t.column("blindsEnabled", .boolean).notNull()
                t.column("handsPlayed", .integer).notNull().defaults(to: 0)
                t.column("netProfit", .integer).notNull().defaults(to: 0)
            }

            try db.create(table: "hands") { t in
                t.column("id", .text).primaryKey()
                t.column("sessionId", .text).notNull()
                    .references("sessions", onDelete: .cascade)
                t.column("handIndex", .integer).notNull()
                t.column("dealerSeat", .integer).notNull()
                t.column("humanSeat", .integer).notNull()
                t.column("humanPosition", .text).notNull()
                t.column("bigBlind", .integer).notNull()
                t.column("boardJSON", .text).notNull()
                t.column("humanHoleJSON", .text).notNull()
                t.column("netWon", .integer).notNull()
                t.column("allInEV", .double)
                t.column("wentToShowdown", .boolean).notNull()
                t.column("wonAtShowdown", .boolean).notNull()
                t.column("endedAt", .datetime).notNull()
                t.uniqueKey(["sessionId", "handIndex"])
            }

            try db.create(table: "actions") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("handId", .text).notNull()
                    .references("hands", onDelete: .cascade)
                t.column("sequence", .integer).notNull()
                t.column("street", .text).notNull()
                t.column("seat", .integer).notNull()
                t.column("isHero", .boolean).notNull()
                t.column("actionType", .text).notNull()
                t.column("amount", .integer).notNull()
                t.column("facingRaises", .integer).notNull()
                t.column("isVoluntary", .boolean).notNull()
            }

            try db.create(index: "hands_session_ended", on: "hands", columns: ["sessionId", "endedAt"])
            try db.create(index: "hands_ended", on: "hands", columns: ["endedAt"])
            try db.create(index: "actions_hand", on: "actions", columns: ["handId", "sequence"])
        }
        return migrator
    }

    // MARK: - Write

    func startSession(
        bigBlind: Int,
        raiseAmount: Int,
        startingChips: Int,
        botCount: Int,
        blindsEnabled: Bool
    ) -> String {
        let id = UUID().uuidString
        let session = StatsSession(
            id: id,
            startedAt: Date(),
            endedAt: nil,
            bigBlind: bigBlind,
            raiseAmount: raiseAmount,
            startingChips: startingChips,
            endingChips: nil,
            botCount: botCount,
            blindsEnabled: blindsEnabled,
            handsPlayed: 0,
            netProfit: 0
        )
        try? dbQueue.write { db in
            try session.insert(db)
        }
        return id
    }

    func endSession(id: String, endingChips: Int) {
        try? dbQueue.write { db in
            guard var session = try StatsSession.fetchOne(db, key: id) else { return }
            session.endedAt = Date()
            session.endingChips = endingChips
            session.netProfit = endingChips - session.startingChips
            let handCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM hands WHERE sessionId = ?",
                arguments: [id]
            ) ?? 0
            session.handsPlayed = handCount
            try session.update(db)
        }
    }

    func saveHand(
        sessionId: String,
        handIndex: Int,
        dealerSeat: Int,
        humanSeat: Int,
        humanPosition: TablePosition,
        bigBlind: Int,
        board: [Card],
        humanHole: [Card],
        netWon: Int,
        allInEV: Double?,
        wentToShowdown: Bool,
        wonAtShowdown: Bool,
        actions: [PendingAction]
    ) {
        let handId = UUID().uuidString
        let hand = StatsHand(
            id: handId,
            sessionId: sessionId,
            handIndex: handIndex,
            dealerSeat: dealerSeat,
            humanSeat: humanSeat,
            humanPosition: humanPosition.rawValue,
            bigBlind: bigBlind,
            boardJSON: CardCodec.encode(board),
            humanHoleJSON: CardCodec.encode(humanHole),
            netWon: netWon,
            allInEV: allInEV,
            wentToShowdown: wentToShowdown,
            wonAtShowdown: wonAtShowdown,
            endedAt: Date()
        )

        try? dbQueue.write { db in
            try hand.insert(db)
            for (i, action) in actions.enumerated() {
                var row = StatsAction(
                    id: nil,
                    handId: handId,
                    sequence: i,
                    street: action.street.rawValue,
                    seat: action.seat,
                    isHero: action.isHero,
                    actionType: action.actionType.rawValue,
                    amount: action.amount,
                    facingRaises: action.facingRaises,
                    isVoluntary: action.isVoluntary
                )
                try row.insert(db)
            }
        }
    }

    struct PendingAction {
        var street: HandStreet
        var seat: Int
        var isHero: Bool
        var actionType: HandActionType
        var amount: Int
        var facingRaises: Int
        var isVoluntary: Bool
    }

    // MARK: - Read

    func bankrollSummary(filter: StatsFilter) -> BankrollSummary {
        (try? dbQueue.read { db in
            let hands = try filteredHands(db, filter: filter)
            let net = hands.reduce(0) { $0 + $1.netWon }
            let avgBB = averageBigBlind(of: hands)
            let sessions = try filteredSessions(db, filter: filter)
            let hours = sessions.reduce(0.0) { partial, session in
                let end = session.endedAt ?? Date()
                return partial + max(0, end.timeIntervalSince(session.startedAt)) / 3600.0
            }
            return BankrollSummary(
                hands: hands.count,
                netProfit: net,
                bigBlind: avgBB,
                hoursPlayed: hours,
                sessions: sessions.count
            )
        }) ?? BankrollSummary(hands: 0, netProfit: 0, bigBlind: 1, hoursPlayed: 0, sessions: 0)
    }

    func profitSeries(filter: StatsFilter) -> [ProfitPoint] {
        (try? dbQueue.read { db in
            let hands = try filteredHands(db, filter: filter)
                .sorted { $0.endedAt < $1.endedAt }
            var cum = 0.0
            var cumEV = 0.0
            return hands.enumerated().map { index, hand in
                cum += Double(hand.netWon)
                let evDelta = hand.allInEV ?? Double(hand.netWon)
                cumEV += evDelta
                return ProfitPoint(
                    handOrdinal: index + 1,
                    cumulativeProfit: cum,
                    cumulativeEV: cumEV
                )
            }
        }) ?? []
    }

    func dayProfits(filter: StatsFilter) -> [DayProfit] {
        (try? dbQueue.read { db in
            let hands = try filteredHands(db, filter: filter)
            let cal = Calendar.current
            var buckets: [String: (date: Date, net: Int, hands: Int)] = [:]
            for hand in hands {
                let day = cal.startOfDay(for: hand.endedAt)
                let key = ISO8601DateFormatter().string(from: day)
                var bucket = buckets[key] ?? (day, 0, 0)
                bucket.net += hand.netWon
                bucket.hands += 1
                buckets[key] = bucket
            }
            return buckets.map { key, value in
                DayProfit(dayKey: key, date: value.date, netProfit: value.net, hands: value.hands)
            }
            .sorted { $0.date < $1.date }
        }) ?? []
    }

    func positionStats(filter: StatsFilter) -> [PositionStat] {
        (try? dbQueue.read { db in
            let hands = try filteredHands(db, filter: filter)
            let avgBB = averageBigBlind(of: hands)
            var map: [String: (hands: Int, net: Int)] = [:]
            for hand in hands {
                var entry = map[hand.humanPosition] ?? (0, 0)
                entry.hands += 1
                entry.net += hand.netWon
                map[hand.humanPosition] = entry
            }
            let order = TablePosition.allCases.map(\.rawValue)
            return order.compactMap { key in
                guard let entry = map[key] else { return nil }
                return PositionStat(
                    position: TablePosition(rawValue: key)?.displayName ?? key.uppercased(),
                    hands: entry.hands,
                    netWon: entry.net,
                    bigBlind: avgBB
                )
            }
        }) ?? []
    }

    func availableStakes() -> [Int] {
        (try? dbQueue.read { db in
            try Int.fetchAll(db, sql: "SELECT DISTINCT bigBlind FROM sessions WHERE bigBlind > 0 ORDER BY bigBlind")
        }) ?? []
    }

    func recentSessions(limit: Int = 20) -> [StatsSession] {
        (try? dbQueue.read { db in
            try StatsSession
                .order(StatsSession.Columns.startedAt.desc)
                .limit(limit)
                .fetchAll(db)
        }) ?? []
    }

    func heroActions(filter: StatsFilter) -> [StatsAction] {
        (try? dbQueue.read { db in
            let hands = try filteredHands(db, filter: filter)
            let ids = hands.map(\.id)
            guard !ids.isEmpty else { return [] }
            let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
            return try StatsAction.fetchAll(
                db,
                sql: """
                SELECT * FROM actions
                WHERE isHero = 1 AND handId IN (\(placeholders))
                ORDER BY handId, sequence
                """,
                arguments: StatementArguments(ids)
            )
        }) ?? []
    }

    func hands(filter: StatsFilter) -> [StatsHand] {
        (try? dbQueue.read { db in
            try filteredHands(db, filter: filter)
        }) ?? []
    }

    func actions(forHandIds ids: [String]) -> [StatsAction] {
        guard !ids.isEmpty else { return [] }
        return (try? dbQueue.read { db in
            let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
            return try StatsAction.fetchAll(
                db,
                sql: """
                SELECT * FROM actions
                WHERE handId IN (\(placeholders))
                ORDER BY handId, sequence
                """,
                arguments: StatementArguments(ids)
            )
        }) ?? []
    }

    // MARK: - Private helpers

    private func filteredHands(_ db: Database, filter: StatsFilter) throws -> [StatsHand] {
        var sql = "SELECT * FROM hands WHERE 1=1"
        var args: [any DatabaseValueConvertible] = []

        if let start = filter.dateRange.start {
            sql += " AND endedAt >= ?"
            args.append(start)
        }
        if let end = filter.dateRange.end {
            sql += " AND endedAt <= ?"
            args.append(end)
        }
        if let bb = filter.bigBlind {
            sql += " AND bigBlind = ?"
            args.append(bb)
        }
        sql += " ORDER BY endedAt ASC"
        return try StatsHand.fetchAll(db, sql: sql, arguments: StatementArguments(args))
    }

    private func filteredSessions(_ db: Database, filter: StatsFilter) throws -> [StatsSession] {
        var sql = "SELECT * FROM sessions WHERE 1=1"
        var args: [any DatabaseValueConvertible] = []
        if let start = filter.dateRange.start {
            sql += " AND startedAt >= ?"
            args.append(start)
        }
        if let end = filter.dateRange.end {
            sql += " AND startedAt <= ?"
            args.append(end)
        }
        if let bb = filter.bigBlind {
            sql += " AND bigBlind = ?"
            args.append(bb)
        }
        return try StatsSession.fetchAll(db, sql: sql, arguments: StatementArguments(args))
    }

    private func averageBigBlind(of hands: [StatsHand]) -> Int {
        guard !hands.isEmpty else { return 1 }
        let sum = hands.reduce(0) { $0 + max($1.bigBlind, 1) }
        return max(1, sum / hands.count)
    }
}
