package com.pokimate.engine

import com.pokimate.engine.stats.StatsStore
import com.pokimate.i18n.L10n
import com.pokimate.model.Card
import com.pokimate.model.Deck
import com.pokimate.model.GamePhase
import com.pokimate.model.HandActionType
import com.pokimate.model.HandStreet
import com.pokimate.model.Player
import com.pokimate.model.TablePosition
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Core Texas Hold'em loop: blinds → streets → betting → showdown → reset. */
class PokerGameEngine(
    humanName: String? = null,
    aiCount: Int = 2,
    startingChips: Int = 500,
    baseBet: Int = 20,
    blindsEnabled: Boolean = true,
    parentScope: CoroutineScope? = null,
    scope: CoroutineScope? = parentScope,
) {

    data class PotAward(
        val id: UUID = UUID.randomUUID(),
        val playerID: UUID,
        val amount: Int,
    )

    data class UiState(
        val players: List<Player> = emptyList(),
        val communityCards: List<Card> = emptyList(),
        val phase: GamePhase = GamePhase.WAITING,
        val pot: Int = 0,
        val currentHighestBet: Int = 0,
        val activePlayerIndex: Int = 0,
        val dealerIndex: Int = 0,
        val message: String = "",
        val isHandInProgress: Boolean = false,
        val showdownResults: Map<UUID, EvaluatedHand> = emptyMap(),
        val revealedShowdownIDs: Set<UUID> = emptySet(),
        val revealingPlayerID: UUID? = null,
        val primaryHighlightedCardIDs: Set<UUID> = emptySet(),
        val secondaryHighlightedCardIDs: Set<UUID> = emptySet(),
        val isAwaitingContinue: Boolean = false,
        val potAwards: List<PotAward> = emptyList(),
        val actionBanners: Map<UUID, String> = emptyMap(),
        val handNumber: Int = 0,
        val humanWinStreak: Int = 0,
    ) {
        val hasWinningHighlights: Boolean
            get() = primaryHighlightedCardIDs.isNotEmpty() || secondaryHighlightedCardIDs.isNotEmpty()
    }

    val smallBlind: Int
    val bigBlind: Int
    val raiseAmount: Int
    val blindsEnabled: Boolean = blindsEnabled
    val startingChips: Int = startingChips
    val botCount: Int

    private val ownsScope = scope == null
    private val scopeJob = SupervisorJob()
    private val engineScope: CoroutineScope =
        scope ?: CoroutineScope(scopeJob + Dispatchers.Main.immediate)

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    private var deck = Deck()
    private var aiJob: Job? = null
    private val bannerJobs: MutableMap<UUID, Job> = mutableMapOf()
    private var isActionOpen = false

    private var sessionId: String? = null
    private var pendingActions: MutableList<StatsStore.PendingAction> = mutableListOf()
    private var handStartHumanChips: Int = 0
    private var streetRaiseCount: Int = 0
    private var recordedAllInEV: Double? = null
    private var humanHoleSnapshot: List<Card> = emptyList()
    private var lastWentToShowdown = false
    private var lastWonAtShowdown = false
    private var pendingPayouts: List<Pair<UUID, Int>> = emptyList()

    private val actionGapMs: Long = 800L

    init {
        this.botCount = minOf(maxOf(aiCount, 2), 5)
        if (blindsEnabled) {
            this.smallBlind = maxOf(10, baseBet / 2)
            this.bigBlind = baseBet
            this.raiseAmount = baseBet
        } else {
            this.smallBlind = 0
            this.bigBlind = maxOf(baseBet, 1)
            this.raiseAmount = baseBet
        }

        val seats = mutableListOf(
            Player(name = humanName ?: L10n.t("player.you"), chips = startingChips, isHuman = true),
        )
        val aiNames = listOf("Alex", "Blake", "Casey", "Drew", "Eden")
        for (i in 0 until this.botCount) {
            seats.add(Player(name = aiNames[i], chips = startingChips, isHuman = false))
        }
        _uiState.value = UiState(
            players = seats,
            message = L10n.t("game.tap_to_start"),
        )

        sessionId = StatsStore.shared.startSession(
            bigBlind = this.bigBlind,
            raiseAmount = this.raiseAmount,
            startingChips = startingChips,
            botCount = this.botCount,
            blindsEnabled = blindsEnabled,
        )
    }

    private val s: UiState get() = _uiState.value

    val humanPlayer: Player? get() = s.players.firstOrNull { it.isHuman }
    val humanSeatIndex: Int? get() = s.players.indexOfFirst { it.isHuman }.takeIf { it >= 0 }
    val activePlayer: Player? get() = s.players.getOrNull(s.activePlayerIndex)

    val isBlindlessEntryRound: Boolean
        get() = !blindsEnabled && s.phase == GamePhase.PRE_FLOP && s.currentHighestBet == 0

    val isHumanTurn: Boolean
        get() {
            if (!isActionOpen || s.phase == GamePhase.WAITING || s.phase == GamePhase.SHOWDOWN || !s.isHandInProgress) {
                return false
            }
            return activePlayer?.isHuman == true
        }

    val toCallAmount: Int
        get() {
            val player = humanPlayer ?: return 0
            if (isBlindlessEntryRound) return minOf(raiseAmount, player.chips)
            return player.callAmount(against = s.currentHighestBet)
        }

    val callLabel: String
        get() {
            val amount = toCallAmount
            if (amount <= 0) return L10n.t("action.check")
            if (isBlindlessEntryRound) return L10n.format("action.enter", amount)
            return L10n.format("action.call", amount)
        }

    val humanEquity: Int
        get() {
            val human = humanPlayer ?: return startingChips
            if (human.isFolded) return human.chips
            return human.chips + human.totalBetThisHand
        }

    val humanProfitPercent: Double
        get() {
            if (startingChips <= 0) return 0.0
            return ((humanEquity - startingChips).toDouble() / startingChips.toDouble()) * 100.0
        }

    val playersInHand: List<Player> get() = s.players.filter { it.isInHand }

    private fun update(block: (UiState) -> UiState) {
        _uiState.update(block)
    }

    fun tearDown() {
        aiJob?.cancel()
        aiJob = null
        bannerJobs.values.forEach { it.cancel() }
        bannerJobs.clear()
        isActionOpen = false
        update { it.copy(isHandInProgress = false, phase = GamePhase.WAITING) }

        sessionId?.let { id ->
            StatsStore.shared.endSession(id = id, endingChips = humanPlayer?.chips ?: startingChips)
            sessionId = null
        }
        if (ownsScope) engineScope.cancel()
    }

    fun startHand() {
        aiJob?.cancel()
        if (s.players.count { it.chips > 0 } < 2) {
            update {
                it.copy(
                    message = L10n.t("game.not_enough_players"),
                    phase = GamePhase.WAITING,
                    isHandInProgress = false,
                )
            }
            return
        }

        pendingActions = mutableListOf()
        handStartHumanChips = humanPlayer?.chips ?: startingChips
        streetRaiseCount = 0
        recordedAllInEV = null
        humanHoleSnapshot = emptyList()
        lastWentToShowdown = false
        lastWonAtShowdown = false
        pendingPayouts = emptyList()
        isActionOpen = false
        bannerJobs.values.forEach { it.cancel() }
        bannerJobs.clear()

        deck = Deck()
        deck.shuffle()

        update {
            it.copy(
                handNumber = it.handNumber + 1,
                isHandInProgress = true,
                showdownResults = emptyMap(),
                revealedShowdownIDs = emptySet(),
                revealingPlayerID = null,
                primaryHighlightedCardIDs = emptySet(),
                secondaryHighlightedCardIDs = emptySet(),
                isAwaitingContinue = false,
                potAwards = emptyList(),
                actionBanners = emptyMap(),
                communityCards = emptyList(),
                pot = 0,
                currentHighestBet = 0,
                players = it.players.map { p -> p.copy().also { c -> c.resetForNewHand() } },
                phase = GamePhase.PRE_FLOP,
                message = L10n.t("game.blinds"),
            )
        }
        scheduleBlindAndDeal()
    }

    fun fold() {
        if (!isHumanTurn) return
        applyFold(index = s.activePlayerIndex)
    }

    fun checkOrCall() {
        if (!isHumanTurn) return
        applyCheckOrCall(index = s.activePlayerIndex)
    }

    fun raise() {
        if (!isHumanTurn) return
        applyRaise(index = s.activePlayerIndex)
    }

    private fun scheduleBlindAndDeal() {
        aiJob?.cancel()
        aiJob = engineScope.launch {
            delay(actionGapMs)
            if (blindsEnabled) {
                val seats = blindSeatIndices() ?: return@launch
                update { it.copy(activePlayerIndex = seats.first) }
                update {
                    it.copy(
                        message = L10n.format("game.posts_sb", it.players[seats.first].name, smallBlind),
                    )
                }
                placeBet(index = seats.first, amount = smallBlind)
                logAction(seats.first, HandActionType.BLIND, smallBlind, 0, false)
                delay(actionGapMs)
                update { it.copy(activePlayerIndex = seats.second) }
                update {
                    it.copy(
                        message = L10n.format("game.posts_bb", it.players[seats.second].name, bigBlind),
                    )
                }
                placeBet(index = seats.second, amount = bigBlind)
                update { it.copy(currentHighestBet = bigBlind) }
                logAction(seats.second, HandActionType.BLIND, bigBlind, 0, false)
                delay(actionGapMs)
            } else {
                update { it.copy(currentHighestBet = 0, message = L10n.t("game.no_blinds")) }
                delay(actionGapMs)
            }
            dealHoleCards()
            update { it.copy(message = L10n.t("game.dealing")) }
            val dealWait = maxOf((s.players.size * 2 * 0.12 + 0.35) * 1000.0, 800.0).toLong()
            delay(dealWait)
            update {
                it.copy(
                    message = if (blindsEnabled) L10n.t("game.preflop") else L10n.t("game.enter_or_fold"),
                )
            }
            beginBettingRound(isPreFlop = true)
        }
    }

    private fun blindSeatIndices(): Pair<Int, Int>? {
        val withChips = s.players.indices.filter { s.players[it].chips > 0 }
        if (withChips.size < 2) return null
        val sb: Int
        val bb: Int
        if (withChips.size == 2) {
            sb = s.dealerIndex
            bb = nextActiveIndex(after = s.dealerIndex)
        } else {
            sb = nextActiveIndex(after = s.dealerIndex)
            bb = nextActiveIndex(after = sb)
        }
        return sb to bb
    }

    private fun dealHoleCards() {
        update {
            it.copy(
                players = it.players.map { p ->
                    if (p.isActive) p.copy(holeCards = deck.draw(count = 2)) else p
                },
            )
        }
        humanHoleSnapshot = humanPlayer?.holeCards ?: emptyList()
    }

    private fun winPhrase(forName: String, suffix: String): String {
        if (s.players.firstOrNull { it.name == forName }?.isHuman == true || forName == L10n.t("player.you")) {
            return L10n.format("game.you_win", suffix)
        }
        return L10n.format("game.player_wins", forName, suffix)
    }

    private fun beginBettingRound(isPreFlop: Boolean) {
        update {
            it.copy(players = it.players.map { p -> p.copy().also { c -> c.hasActedThisRound = false } })
        }
        streetRaiseCount = 0
        if (isPreFlop) {
            if (blindsEnabled) {
                val activeIndices = s.players.indices.filter { s.players[it].isInHand }
                if (activeIndices.size == 2) {
                    val idx = if (s.players[s.dealerIndex].canAct) s.dealerIndex else nextCanActIndex(after = s.dealerIndex)
                    update { it.copy(activePlayerIndex = idx) }
                } else {
                    val sb = nextActiveIndex(after = s.dealerIndex)
                    val bb = nextActiveIndex(after = sb)
                    update { it.copy(activePlayerIndex = nextCanActIndex(after = bb)) }
                }
            } else {
                update { it.copy(currentHighestBet = 0, activePlayerIndex = nextCanActIndex(after = s.dealerIndex)) }
            }
        } else {
            update { it.copy(currentHighestBet = 0, activePlayerIndex = nextCanActIndex(after = s.dealerIndex)) }
        }
        if (playersInHand.size <= 1) {
            scheduleEndHandEarly(); return
        }
        maybeCaptureAllInEV()
        if (shouldRunOutBoard()) { advancePhase(); return }
        if (isBettingRoundComplete()) { advancePhase(); return }
        promptCurrentPlayer()
    }

    private fun promptCurrentPlayer() {
        val player = activePlayer ?: return
        if (s.phase == GamePhase.SHOWDOWN) return
        if (player.isHuman) {
            isActionOpen = true
            update { it.copy(message = L10n.t("game.your_turn")) }
            return
        }
        isActionOpen = false
        update { it.copy(message = L10n.format("game.thinking", player.name)) }
        scheduleAIMove()
    }

    private fun scheduleAIMove() {
        aiJob?.cancel()
        val index = s.activePlayerIndex
        aiJob = engineScope.launch {
            delay(actionGapMs)
            performAIMove(index = index)
        }
    }

    private fun performAIMove(index: Int) {
        if (index !in s.players.indices) return
        if (index != s.activePlayerIndex) return
        if (s.players[index].isHuman) return
        if (s.phase == GamePhase.SHOWDOWN) return
        if (!s.isHandInProgress) return
        when (
            OpponentAI.decide(
                player = s.players[index],
                phase = s.phase,
                highestBet = s.currentHighestBet,
                pot = s.pot,
                requiresEntryBet = isBlindlessEntryRound,
            )
        ) {
            PlayerAction.FOLD -> applyFold(index = index)
            PlayerAction.CHECK_OR_CALL -> applyCheckOrCall(index = index)
            PlayerAction.RAISE -> applyRaise(index = index)
        }
    }

    private fun applyFold(index: Int) {
        if (index !in s.players.indices) return
        logAction(index, HandActionType.FOLD, 0, streetRaiseCount, true)
        mutatePlayer(index) {
            isFolded = true
            hasActedThisRound = true
            hasCheckedThisRound = false
        }
        update { it.copy(message = L10n.format("game.folds", it.players[index].name)) }
        showActionBanner(s.players[index].id, L10n.t("banner.fold"))
        if (playersInHand.size <= 1) { scheduleEndHandEarly(); return }
        continueAfterAction()
    }

    private fun applyCheckOrCall(index: Int) {
        if (index !in s.players.indices) return
        if (isBlindlessEntryRound) { applyEntryBet(index = index); return }
        val toCall = s.players[index].callAmount(against = s.currentHighestBet)
        if (toCall > 0) applyCall(index = index, amount = toCall) else applyCheck(index = index)
    }

    private fun applyEntryBet(index: Int) {
        if (index !in s.players.indices) return
        val amount = minOf(raiseAmount, s.players[index].chips)
        if (amount <= 0) { applyFold(index = index); return }
        logAction(index, HandActionType.BET, amount, streetRaiseCount, true)
        placeBet(index = index, amount = amount)
        update { it.copy(currentHighestBet = maxOf(it.currentHighestBet, it.players[index].currentBet)) }
        mutatePlayer(index) {
            hasActedThisRound = true
            hasCheckedThisRound = false
        }
        update {
            it.copy(
                players = it.players.mapIndexed { i, p ->
                    if (i != index && p.isInHand && p.chips > 0) p.copy().also { c -> c.hasActedThisRound = false } else p
                },
                message = L10n.format("game.enters", it.players[index].name, amount),
            )
        }
        showActionBanner(s.players[index].id, L10n.format("banner.enter", amount))
        maybeCaptureAllInEV()
        continueAfterAction()
    }

    private fun applyCheck(index: Int) {
        logAction(index, HandActionType.CHECK, 0, streetRaiseCount, true)
        update { it.copy(message = L10n.format("game.checks", it.players[index].name)) }
        showActionBanner(s.players[index].id, L10n.t("banner.check"))
        mutatePlayer(index) {
            hasCheckedThisRound = true
            hasActedThisRound = true
        }
        continueAfterAction()
    }

    private fun applyCall(index: Int, amount: Int) {
        logAction(index, HandActionType.CALL, amount, streetRaiseCount, true)
        placeBet(index = index, amount = amount)
        update { it.copy(message = L10n.format("game.calls", it.players[index].name, amount)) }
        showActionBanner(s.players[index].id, L10n.format("banner.call", amount))
        mutatePlayer(index) {
            hasCheckedThisRound = false
            hasActedThisRound = true
        }
        maybeCaptureAllInEV()
        continueAfterAction()
    }

    private fun applyRaise(index: Int) {
        if (index !in s.players.indices) return
        val toCall = s.players[index].callAmount(against = s.currentHighestBet)
        val totalNeeded = if (isBlindlessEntryRound) {
            minOf(raiseAmount * 2, s.players[index].chips)
        } else {
            toCall + raiseAmount
        }
        if (s.players[index].chips <= toCall && !isBlindlessEntryRound) {
            applyCheckOrCall(index = index); return
        }
        if (totalNeeded <= 0) { applyCheckOrCall(index = index); return }
        val actionType = if (s.currentHighestBet == 0) HandActionType.BET else HandActionType.RAISE
        logAction(index, actionType, totalNeeded, streetRaiseCount, true)
        streetRaiseCount += 1
        placeBet(index = index, amount = totalNeeded)
        update { it.copy(currentHighestBet = it.players[index].currentBet) }
        mutatePlayer(index) {
            hasActedThisRound = true
            hasCheckedThisRound = false
        }
        update {
            it.copy(
                players = it.players.mapIndexed { i, p ->
                    if (i != index && p.isInHand && p.chips > 0) p.copy().also { c -> c.hasActedThisRound = false } else p
                },
            )
        }
        val high = s.currentHighestBet
        if (actionType == HandActionType.BET) {
            update { it.copy(message = L10n.format("game.bets", it.players[index].name, high)) }
            showActionBanner(s.players[index].id, L10n.format("banner.bet", high))
        } else {
            update { it.copy(message = L10n.format("game.raises_to", it.players[index].name, high)) }
            showActionBanner(s.players[index].id, L10n.format("banner.raise", high))
        }
        maybeCaptureAllInEV()
        continueAfterAction()
    }

    private fun logAction(seat: Int, type: HandActionType, amount: Int, facingRaises: Int, voluntary: Boolean) {
        if (seat !in s.players.indices) return
        pendingActions.add(
            StatsStore.PendingAction(
                street = HandStreet.fromPhase(s.phase),
                seat = seat,
                isHero = s.players[seat].isHuman,
                actionType = type,
                amount = amount,
                facingRaises = facingRaises,
                isVoluntary = voluntary,
            ),
        )
    }

    private fun showActionBanner(playerID: UUID, text: String) {
        update { it.copy(actionBanners = it.actionBanners + (playerID to text)) }
        bannerJobs[playerID]?.cancel()
        bannerJobs[playerID] = engineScope.launch {
            delay(1600L)
            update { state ->
                val cleared = state.actionBanners.toMutableMap()
                if (cleared[playerID] == text) cleared.remove(playerID)
                state.copy(actionBanners = cleared)
            }
        }
    }

    private fun continueAfterAction() {
        isActionOpen = false
        aiJob?.cancel()
        aiJob = engineScope.launch {
            delay(actionGapMs)
            advanceTurnOrStreet()
        }
    }

    private fun placeBet(index: Int, amount: Int) {
        update { state ->
            val next = state.players.toMutableList()
            val actual = minOf(amount, next[index].chips)
            val p = next[index].copy()
            p.chips -= actual
            p.currentBet += actual
            p.totalBetThisHand += actual
            next[index] = p
            state.copy(players = next, pot = state.pot + actual)
        }
    }

    private fun shouldRunOutBoard(): Boolean {
        val inHand = s.players.filter { it.isInHand }
        if (inHand.size < 2) return false
        return inHand.count { it.chips > 0 } <= 1
    }

    private fun maybeCaptureAllInEV() {
        if (recordedAllInEV != null) return
        val inHand = s.players.filter { it.isInHand }
        if (inHand.size < 2) return
        if (inHand.count { it.chips > 0 } > 1) return
        val human = humanPlayer ?: return
        if (!human.isInHand || human.holeCards.size != 2) return
        val villainHoles = inHand.filter { !it.isHuman && it.holeCards.size == 2 }.map { it.holeCards }
        if (villainHoles.isEmpty()) return
        recordedAllInEV = EquityCalculator.allInEVDelta(
            heroHole = human.holeCards,
            villainHoles = villainHoles,
            board = s.communityCards,
            pot = s.pot,
            heroContribution = human.totalBetThisHand,
        )
    }

    private fun advanceTurnOrStreet() {
        if (playersInHand.size <= 1) { scheduleEndHandEarly(); return }
        maybeCaptureAllInEV()
        if (shouldRunOutBoard()) { advancePhase(); return }
        if (isBettingRoundComplete()) { advancePhase(); return }
        update { it.copy(activePlayerIndex = nextCanActIndex(after = it.activePlayerIndex)) }
        promptCurrentPlayer()
    }

    private fun isBettingRoundComplete(): Boolean {
        val contenders = s.players.filter { it.isInHand }
        if (contenders.size <= 1) return true
        for (player in contenders) {
            if (player.chips == 0) continue
            if (!player.hasActedThisRound) return false
            if (player.currentBet < s.currentHighestBet) return false
        }
        return true
    }

    private fun advancePhase() {
        isActionOpen = false
        update {
            it.copy(
                players = it.players.map { p -> p.copy().also { c -> c.resetForNewStreet() } },
                currentHighestBet = 0,
            )
        }
        val previousPhase = s.phase
        val runOut = shouldRunOutBoard()
        aiJob?.cancel()
        aiJob = engineScope.launch {
            delay(actionGapMs)
            when (previousPhase) {
                GamePhase.PRE_FLOP -> {
                    update {
                        it.copy(
                            communityCards = it.communityCards + deck.draw(count = 3),
                            phase = GamePhase.FLOP,
                            message = L10n.t("game.flop"),
                        )
                    }
                }
                GamePhase.FLOP -> {
                    val card = deck.draw()
                    update {
                        it.copy(
                            communityCards = if (card != null) it.communityCards + card else it.communityCards,
                            phase = GamePhase.TURN,
                            message = L10n.t("game.turn"),
                        )
                    }
                }
                GamePhase.TURN -> {
                    val card = deck.draw()
                    update {
                        it.copy(
                            communityCards = if (card != null) it.communityCards + card else it.communityCards,
                            phase = GamePhase.RIVER,
                            message = L10n.t("game.river"),
                        )
                    }
                }
                GamePhase.RIVER -> { runShowdown(); return@launch }
                else -> return@launch
            }
            maybeCaptureAllInEV()
            delay(actionGapMs)
            if (runOut) advancePhase() else beginBettingRound(isPreFlop = false)
        }
    }

    private fun scheduleEndHandEarly() {
        isActionOpen = false
        aiJob?.cancel()
        aiJob = engineScope.launch {
            delay(actionGapMs)
            endHandEarly()
        }
    }

    private fun endHandEarly() {
        aiJob?.cancel()
        val winner = playersInHand.firstOrNull()
        if (winner == null) {
            update { it.copy(message = L10n.t("game.hand_over")) }
            persistCurrentHand(false, false)
            pendingPayouts = emptyList()
            awaitContinue()
            return
        }
        lastWentToShowdown = false
        lastWonAtShowdown = false
        pendingPayouts = listOf(winner.id to s.pot)
        update {
            it.copy(
                message = winPhrase(winner.name, "${it.pot}"),
                phase = GamePhase.SHOWDOWN,
                isHandInProgress = false,
            )
        }
        awaitContinue()
    }

    private fun runShowdown() {
        aiJob?.cancel()
        isActionOpen = false
        lastWentToShowdown = true
        update {
            it.copy(
                phase = GamePhase.SHOWDOWN,
                isHandInProgress = false,
                revealedShowdownIDs = emptySet(),
                revealingPlayerID = null,
                primaryHighlightedCardIDs = emptySet(),
                secondaryHighlightedCardIDs = emptySet(),
                isAwaitingContinue = false,
                showdownResults = emptyMap(),
                potAwards = emptyList(),
            )
        }
        val contenders = s.players.filter { it.isInHand }
        val evaluations = mutableMapOf<UUID, EvaluatedHand>()
        for (player in contenders) {
            evaluations[player.id] = HandEvaluator.evaluateBestHand(player.holeCards, s.communityCards)
        }
        val ordered = contenders.sortedBy { revealOrder(it) }
        val contributions = s.players.map { Contribution(it.id, it.totalBetThisHand, it.isInHand) }
        val sidePots = SidePotCalculator.pots(contributions)
        val payouts = SidePotCalculator.awards(sidePots, evaluations)

        aiJob = engineScope.launch {
            update { it.copy(message = L10n.t("game.showdown")) }
            delay(actionGapMs)
            val revealed = mutableSetOf<UUID>()
            val results = mutableMapOf<UUID, EvaluatedHand>()
            for (player in ordered) {
                revealed.add(player.id)
                update {
                    it.copy(
                        revealingPlayerID = player.id,
                        revealedShowdownIDs = revealed.toSet(),
                        message = L10n.format("game.reveals", player.name),
                    )
                }
                delay(actionGapMs)
                evaluations[player.id]?.let { hand ->
                    results[player.id] = hand
                    update {
                        it.copy(
                            showdownResults = results.toMap(),
                            message = L10n.format("game.player_hand", player.name, hand.category.displayName),
                        )
                    }
                }
                delay(actionGapMs * 2)
            }
            update { it.copy(revealingPlayerID = null) }
            humanPlayer?.id?.let { hid ->
                lastWonAtShowdown = payouts.any { it.playerID == hid && it.amount > 0 }
            }
            val primaryIDs = mutableSetOf<UUID>()
            val secondaryIDs = mutableSetOf<UUID>()
            for (payout in payouts.filter { it.amount > 0 }) {
                val hand = evaluations[payout.playerID] ?: continue
                val (primary, secondary) = hand.highlightGroups()
                primaryIDs.addAll(primary)
                secondaryIDs.addAll(secondary)
            }
            secondaryIDs.removeAll(primaryIDs)
            update {
                it.copy(
                    primaryHighlightedCardIDs = primaryIDs,
                    secondaryHighlightedCardIDs = secondaryIDs,
                )
            }
            if (payouts.size == 1) {
                val only = payouts.first()
                val winner = s.players.firstOrNull { it.id == only.playerID }
                if (winner != null) {
                    val handName = evaluations[winner.id]?.category?.displayName ?: ""
                    val suffix = if (handName.isEmpty()) "${only.amount}" else L10n.format("game.with_hand", handName)
                    update { it.copy(message = winPhrase(winner.name, suffix)) }
                }
            } else {
                val names = payouts.mapNotNull { p -> s.players.firstOrNull { it.id == p.playerID }?.name }.joinToString(", ")
                update { it.copy(message = L10n.format("game.split_pot", names)) }
            }
            pendingPayouts = payouts.map { it.playerID to it.amount }
            awaitContinue()
        }
    }

    fun continueToNextHand() {
        if (!s.isAwaitingContinue) return
        update { it.copy(isAwaitingContinue = false) }
        aiJob?.cancel()
        val payouts = pendingPayouts
        pendingPayouts = emptyList()
        aiJob = engineScope.launch {
            if (payouts.isNotEmpty()) {
                award(payouts)
                update { it.copy(pot = 0) }
                if (payouts.size == 1) {
                    val only = payouts.first()
                    val winner = s.players.firstOrNull { it.id == only.first }
                    if (winner != null) {
                        val handName = s.showdownResults[winner.id]?.category?.displayName ?: ""
                        if (handName.isEmpty()) {
                            update { it.copy(message = winPhrase(winner.name, "${only.second}")) }
                        } else {
                            update {
                                it.copy(
                                    message = winPhrase(
                                        winner.name,
                                        L10n.format("game.amount_with_hand", only.second, handName),
                                    ),
                                )
                            }
                        }
                    }
                } else {
                    val names = payouts.mapNotNull { p -> s.players.firstOrNull { it.id == p.first }?.name }.joinToString(", ")
                    val total = payouts.sumOf { it.second }
                    update { it.copy(message = L10n.format("game.split_side_pots", total, names)) }
                }
                delay(actionGapMs * 2)
            }
            prepareNextHand()
        }
    }

    private fun awaitContinue() {
        update { it.copy(isAwaitingContinue = true) }
    }

    private fun revealOrder(of: Player): Int {
        val n = s.players.size
        if (n <= 0) return 0
        val idx = s.players.indexOfFirst { it.id == of.id }
        if (idx < 0) return 0
        return (idx - s.dealerIndex - 1 + n) % n
    }

    private fun award(payouts: List<Pair<UUID, Int>>) {
        update { state ->
            val next = state.players.map { it.copy() }.toMutableList()
            for ((playerID, amount) in payouts) {
                val idx = next.indexOfFirst { it.id == playerID }
                if (idx >= 0) next[idx].chips += amount
            }
            for (i in next.indices) next[i].totalBetThisHand = 0
            val awards = payouts.filter { it.second > 0 }.map { PotAward(playerID = it.first, amount = it.second) }
            var streak = state.humanWinStreak
            val humanID = next.firstOrNull { it.isHuman }?.id
            if (humanID != null) {
                streak = if (payouts.any { it.first == humanID && it.second > 0 }) streak + 1 else 0
            }
            state.copy(players = next, potAwards = awards, humanWinStreak = streak)
        }
        persistCurrentHand(lastWentToShowdown, lastWonAtShowdown)
    }

    private fun persistCurrentHand(wentToShowdown: Boolean, wonAtShowdown: Boolean) {
        val sid = sessionId ?: return
        val humanSeat = humanSeatIndex ?: return
        val human = s.players[humanSeat]
        val netWon = human.chips - handStartHumanChips
        val position = TablePosition.resolve(humanSeat, s.dealerIndex, s.players.size)
        val hole = if (humanHoleSnapshot.isEmpty()) human.holeCards else humanHoleSnapshot
        StatsStore.shared.saveHand(
            sessionId = sid,
            handIndex = s.handNumber,
            dealerSeat = s.dealerIndex,
            humanSeat = humanSeat,
            humanPosition = position,
            bigBlind = bigBlind,
            board = s.communityCards,
            humanHole = hole,
            netWon = netWon,
            allInEV = recordedAllInEV,
            wentToShowdown = wentToShowdown,
            wonAtShowdown = wonAtShowdown,
            actions = pendingActions.toList(),
        )
        pendingActions = mutableListOf()
    }

    private fun prepareNextHand() {
        update {
            it.copy(
                dealerIndex = nextActiveIndex(after = it.dealerIndex),
                communityCards = emptyList(),
                showdownResults = emptyMap(),
                revealedShowdownIDs = emptySet(),
                revealingPlayerID = null,
                primaryHighlightedCardIDs = emptySet(),
                secondaryHighlightedCardIDs = emptySet(),
                isAwaitingContinue = false,
                potAwards = emptyList(),
                currentHighestBet = 0,
            )
        }
        pendingPayouts = emptyList()
        startHand()
    }

    private fun nextActiveIndex(after: Int): Int {
        val list = s.players
        if (list.isEmpty()) return 0
        var i = after
        repeat(list.size) {
            i = (i + 1) % list.size
            if (list[i].chips > 0 || list[i].isInHand) return i
        }
        return (after + 1) % list.size
    }

    private fun nextCanActIndex(after: Int): Int {
        val list = s.players
        if (list.isEmpty()) return 0
        var i = after
        repeat(list.size) {
            i = (i + 1) % list.size
            if (list[i].canAct) return i
        }
        return after
    }

    private fun mutatePlayer(index: Int, block: Player.() -> Unit) {
        update { state ->
            val next = state.players.toMutableList()
            val p = next[index].copy()
            p.block()
            next[index] = p
            state.copy(players = next)
        }
    }
}
