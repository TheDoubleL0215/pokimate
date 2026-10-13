package com.pokimate.engine.stats

import com.pokimate.model.Card
import com.pokimate.model.CardCodec
import com.pokimate.model.HandActionType
import com.pokimate.model.HandStreet
import com.pokimate.model.StatsAction
import com.pokimate.model.StatsFilter
import com.pokimate.model.StatsHand
import com.pokimate.model.StatsSession
import com.pokimate.model.TablePosition
import com.pokimate.model.BankrollSummary
import com.pokimate.model.DayProfit
import com.pokimate.model.PositionStat
import com.pokimate.model.ProfitPoint
import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

/**
 * In-memory + SharedPreferences JSON persistence for sessions / hands / actions.
 * Same public API as the Swift StatsStore (minus GRDB).
 */
class StatsStore private constructor(private val prefs: SharedPreferences?) {

    private val sessions = mutableListOf<StatsSession>()
    private val hands = mutableListOf<StatsHand>()
    private val actions = mutableListOf<StatsAction>()
    private var nextActionId = 1L

    init {
        load()
    }

    // MARK: - Write

    fun startSession(
        bigBlind: Int,
        raiseAmount: Int,
        startingChips: Int,
        botCount: Int,
        blindsEnabled: Boolean
    ): String {
        val id = UUID.randomUUID().toString()
        val session = StatsSession(
            id = id,
            startedAt = Date(),
            endedAt = null,
            bigBlind = bigBlind,
            raiseAmount = raiseAmount,
            startingChips = startingChips,
            endingChips = null,
            botCount = botCount,
            blindsEnabled = blindsEnabled,
            handsPlayed = 0,
            netProfit = 0
        )
        sessions.add(session)
        persist()
        return id
    }

    fun endSession(id: String, endingChips: Int) {
        val session = sessions.find { it.id == id } ?: return
        session.endedAt = Date()
        session.endingChips = endingChips
        session.netProfit = endingChips - session.startingChips
        session.handsPlayed = hands.count { it.sessionId == id }
        persist()
    }

    fun saveHand(
        sessionId: String,
        handIndex: Int,
        dealerSeat: Int,
        humanSeat: Int,
        humanPosition: TablePosition,
        bigBlind: Int,
        board: List<Card>,
        humanHole: List<Card>,
        netWon: Int,
        allInEV: Double?,
        wentToShowdown: Boolean,
        wonAtShowdown: Boolean,
        actions: List<PendingAction>
    ) {
        val handId = UUID.randomUUID().toString()
        val hand = StatsHand(
            id = handId,
            sessionId = sessionId,
            handIndex = handIndex,
            dealerSeat = dealerSeat,
            humanSeat = humanSeat,
            humanPosition = humanPosition.rawValue,
            bigBlind = bigBlind,
            boardJSON = CardCodec.encode(board),
            humanHoleJSON = CardCodec.encode(humanHole),
            netWon = netWon,
            allInEV = allInEV,
            wentToShowdown = wentToShowdown,
            wonAtShowdown = wonAtShowdown,
            endedAt = Date()
        )
        hands.add(hand)
        actions.forEachIndexed { i, action ->
            this.actions.add(
                StatsAction(
                    id = nextActionId++,
                    handId = handId,
                    sequence = i,
                    street = action.street.rawValue,
                    seat = action.seat,
                    isHero = action.isHero,
                    actionType = action.actionType.rawValue,
                    amount = action.amount,
                    facingRaises = action.facingRaises,
                    isVoluntary = action.isVoluntary
                )
            )
        }
        persist()
    }

    data class PendingAction(
        var street: HandStreet,
        var seat: Int,
        var isHero: Boolean,
        var actionType: HandActionType,
        var amount: Int,
        var facingRaises: Int,
        var isVoluntary: Boolean
    )

    // MARK: - Read

    fun bankrollSummary(filter: StatsFilter): BankrollSummary {
        val filteredHands = filteredHands(filter)
        val net = filteredHands.sumOf { it.netWon }
        val avgBB = averageBigBlind(filteredHands)
        val filteredSessions = filteredSessions(filter)
        val hours = filteredSessions.sumOf { session ->
            val end = session.endedAt ?: Date()
            maxOf(0.0, (end.time - session.startedAt.time) / 3600_000.0)
        }
        return BankrollSummary(
            hands = filteredHands.size,
            netProfit = net,
            bigBlind = avgBB,
            hoursPlayed = hours,
            sessions = filteredSessions.size
        )
    }

    fun profitSeries(filter: StatsFilter): List<ProfitPoint> {
        val sorted = filteredHands(filter).sortedBy { it.endedAt.time }
        var cum = 0.0
        var cumEV = 0.0
        return sorted.mapIndexed { index, hand ->
            cum += hand.netWon.toDouble()
            val evDelta = hand.allInEV ?: hand.netWon.toDouble()
            cumEV += evDelta
            ProfitPoint(
                handOrdinal = index + 1,
                cumulativeProfit = cum,
                cumulativeEV = cumEV
            )
        }
    }

    fun dayProfits(filter: StatsFilter): List<DayProfit> {
        val filtered = filteredHands(filter)
        val cal = java.util.Calendar.getInstance()
        val buckets = mutableMapOf<String, Triple<Date, Int, Int>>()
        val iso = isoFormatter()
        for (hand in filtered) {
            cal.time = hand.endedAt
            cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
            cal.set(java.util.Calendar.MINUTE, 0)
            cal.set(java.util.Calendar.SECOND, 0)
            cal.set(java.util.Calendar.MILLISECOND, 0)
            val day = cal.time
            val key = iso.format(day)
            val existing = buckets[key] ?: Triple(day, 0, 0)
            buckets[key] = Triple(existing.first, existing.second + hand.netWon, existing.third + 1)
        }
        return buckets.map { (key, value) ->
            DayProfit(dayKey = key, date = value.first, netProfit = value.second, hands = value.third)
        }.sortedBy { it.date.time }
    }

    fun positionStats(filter: StatsFilter): List<PositionStat> {
        val filtered = filteredHands(filter)
        val avgBB = averageBigBlind(filtered)
        val map = mutableMapOf<String, Pair<Int, Int>>()
        for (hand in filtered) {
            val entry = map[hand.humanPosition] ?: (0 to 0)
            map[hand.humanPosition] = (entry.first + 1) to (entry.second + hand.netWon)
        }
        return TablePosition.entries.mapNotNull { pos ->
            val entry = map[pos.rawValue] ?: return@mapNotNull null
            PositionStat(
                position = pos.displayName,
                hands = entry.first,
                netWon = entry.second,
                bigBlind = avgBB
            )
        }
    }

    fun availableStakes(): List<Int> =
        sessions.map { it.bigBlind }.filter { it > 0 }.distinct().sorted()

    fun recentSessions(limit: Int = 20): List<StatsSession> =
        sessions.sortedByDescending { it.startedAt.time }.take(limit)

    fun heroActions(filter: StatsFilter): List<StatsAction> {
        val ids = filteredHands(filter).map { it.id }.toSet()
        if (ids.isEmpty()) return emptyList()
        return actions
            .filter { it.isHero && it.handId in ids }
            .sortedWith(compareBy({ it.handId }, { it.sequence }))
    }

    fun hands(filter: StatsFilter): List<StatsHand> = filteredHands(filter)

    fun actions(forHandIds: List<String>): List<StatsAction> {
        if (forHandIds.isEmpty()) return emptyList()
        val set = forHandIds.toSet()
        return actions
            .filter { it.handId in set }
            .sortedWith(compareBy({ it.handId }, { it.sequence }))
    }

    // MARK: - Private helpers

    private fun filteredHands(filter: StatsFilter): List<StatsHand> {
        return hands.filter { hand ->
            val start = filter.dateRange.start
            val end = filter.dateRange.end
            val bb = filter.bigBlind
            if (start != null && hand.endedAt.before(start)) return@filter false
            if (end != null && hand.endedAt.after(end)) return@filter false
            if (bb != null && hand.bigBlind != bb) return@filter false
            true
        }.sortedBy { it.endedAt.time }
    }

    private fun filteredSessions(filter: StatsFilter): List<StatsSession> {
        return sessions.filter { session ->
            val start = filter.dateRange.start
            val end = filter.dateRange.end
            val bb = filter.bigBlind
            if (start != null && session.startedAt.before(start)) return@filter false
            if (end != null && session.startedAt.after(end)) return@filter false
            if (bb != null && session.bigBlind != bb) return@filter false
            true
        }
    }

    private fun averageBigBlind(ofHands: List<StatsHand>): Int {
        if (ofHands.isEmpty()) return 1
        val sum = ofHands.sumOf { maxOf(it.bigBlind, 1) }
        return maxOf(1, sum / ofHands.size)
    }

    // MARK: - Persistence

    private fun persist() {
        val p = prefs ?: return
        p.edit()
            .putString(KEY_SESSIONS, encodeSessions())
            .putString(KEY_HANDS, encodeHands())
            .putString(KEY_ACTIONS, encodeActions())
            .putLong(KEY_NEXT_ACTION_ID, nextActionId)
            .apply()
    }

    private fun load() {
        val p = prefs ?: return
        nextActionId = p.getLong(KEY_NEXT_ACTION_ID, 1L)
        decodeSessions(p.getString(KEY_SESSIONS, null))
        decodeHands(p.getString(KEY_HANDS, null))
        decodeActions(p.getString(KEY_ACTIONS, null))
    }

    private fun encodeSessions(): String {
        val arr = JSONArray()
        for (s in sessions) {
            arr.put(JSONObject().apply {
                put("id", s.id)
                put("startedAt", s.startedAt.time)
                put("endedAt", s.endedAt?.time ?: JSONObject.NULL)
                put("bigBlind", s.bigBlind)
                put("raiseAmount", s.raiseAmount)
                put("startingChips", s.startingChips)
                put("endingChips", s.endingChips ?: JSONObject.NULL)
                put("botCount", s.botCount)
                put("blindsEnabled", s.blindsEnabled)
                put("handsPlayed", s.handsPlayed)
                put("netProfit", s.netProfit)
            })
        }
        return arr.toString()
    }

    private fun decodeSessions(raw: String?) {
        sessions.clear()
        if (raw.isNullOrBlank()) return
        val arr = JSONArray(raw)
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            sessions.add(
                StatsSession(
                    id = o.getString("id"),
                    startedAt = Date(o.getLong("startedAt")),
                    endedAt = if (o.isNull("endedAt")) null else Date(o.getLong("endedAt")),
                    bigBlind = o.getInt("bigBlind"),
                    raiseAmount = o.getInt("raiseAmount"),
                    startingChips = o.getInt("startingChips"),
                    endingChips = if (o.isNull("endingChips")) null else o.getInt("endingChips"),
                    botCount = o.getInt("botCount"),
                    blindsEnabled = o.getBoolean("blindsEnabled"),
                    handsPlayed = o.getInt("handsPlayed"),
                    netProfit = o.getInt("netProfit")
                )
            )
        }
    }

    private fun encodeHands(): String {
        val arr = JSONArray()
        for (h in hands) {
            arr.put(JSONObject().apply {
                put("id", h.id)
                put("sessionId", h.sessionId)
                put("handIndex", h.handIndex)
                put("dealerSeat", h.dealerSeat)
                put("humanSeat", h.humanSeat)
                put("humanPosition", h.humanPosition)
                put("bigBlind", h.bigBlind)
                put("boardJSON", h.boardJSON)
                put("humanHoleJSON", h.humanHoleJSON)
                put("netWon", h.netWon)
                put("allInEV", h.allInEV ?: JSONObject.NULL)
                put("wentToShowdown", h.wentToShowdown)
                put("wonAtShowdown", h.wonAtShowdown)
                put("endedAt", h.endedAt.time)
            })
        }
        return arr.toString()
    }

    private fun decodeHands(raw: String?) {
        hands.clear()
        if (raw.isNullOrBlank()) return
        val arr = JSONArray(raw)
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            hands.add(
                StatsHand(
                    id = o.getString("id"),
                    sessionId = o.getString("sessionId"),
                    handIndex = o.getInt("handIndex"),
                    dealerSeat = o.getInt("dealerSeat"),
                    humanSeat = o.getInt("humanSeat"),
                    humanPosition = o.getString("humanPosition"),
                    bigBlind = o.getInt("bigBlind"),
                    boardJSON = o.getString("boardJSON"),
                    humanHoleJSON = o.getString("humanHoleJSON"),
                    netWon = o.getInt("netWon"),
                    allInEV = if (o.isNull("allInEV")) null else o.getDouble("allInEV"),
                    wentToShowdown = o.getBoolean("wentToShowdown"),
                    wonAtShowdown = o.getBoolean("wonAtShowdown"),
                    endedAt = Date(o.getLong("endedAt"))
                )
            )
        }
    }

    private fun encodeActions(): String {
        val arr = JSONArray()
        for (a in actions) {
            arr.put(JSONObject().apply {
                put("id", a.id ?: JSONObject.NULL)
                put("handId", a.handId)
                put("sequence", a.sequence)
                put("street", a.street)
                put("seat", a.seat)
                put("isHero", a.isHero)
                put("actionType", a.actionType)
                put("amount", a.amount)
                put("facingRaises", a.facingRaises)
                put("isVoluntary", a.isVoluntary)
            })
        }
        return arr.toString()
    }

    private fun decodeActions(raw: String?) {
        actions.clear()
        if (raw.isNullOrBlank()) return
        val arr = JSONArray(raw)
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val id = if (o.isNull("id")) null else o.getLong("id")
            actions.add(
                StatsAction(
                    id = id,
                    handId = o.getString("handId"),
                    sequence = o.getInt("sequence"),
                    street = o.getString("street"),
                    seat = o.getInt("seat"),
                    isHero = o.getBoolean("isHero"),
                    actionType = o.getString("actionType"),
                    amount = o.getInt("amount"),
                    facingRaises = o.getInt("facingRaises"),
                    isVoluntary = o.getBoolean("isVoluntary")
                )
            )
            if (id != null && id >= nextActionId) nextActionId = id + 1
        }
    }

    private fun isoFormatter(): SimpleDateFormat =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }

    companion object {
        private const val PREFS_NAME = "pokimate_stats"
        private const val KEY_SESSIONS = "sessions"
        private const val KEY_HANDS = "hands"
        private const val KEY_ACTIONS = "actions"
        private const val KEY_NEXT_ACTION_ID = "nextActionId"

        @Volatile
        private var instance: StatsStore? = null

        val shared: StatsStore
            get() = instance ?: StatsStore(null).also { instance = it }

        fun init(context: Context) {
            val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            instance = StatsStore(prefs)
        }
    }
}
