import Foundation
import Combine

/// Core Texas Hold'em loop: blinds → streets → betting → showdown → reset.
@MainActor
final class PokerGameEngine: ObservableObject {

    // MARK: - Published State

    @Published private(set) var players: [Player] = []
    @Published private(set) var communityCards: [Card] = []
    @Published private(set) var phase: GamePhase = .waiting
    @Published private(set) var pot: Int = 0
    @Published private(set) var currentHighestBet: Int = 0
    @Published private(set) var activePlayerIndex: Int = 0
    @Published private(set) var dealerIndex: Int = 0
    @Published private(set) var message: String = ""
    @Published private(set) var isHandInProgress: Bool = false
    @Published private(set) var showdownResults: [UUID: EvaluatedHand] = [:]
    @Published private(set) var revealedShowdownIDs: Set<UUID> = []
    @Published private(set) var revealingPlayerID: UUID?
    /// Cards that define the winning category (pair, trips, …) — strong yellow.
    @Published private(set) var primaryHighlightedCardIDs: Set<UUID> = []
    /// Remaining cards in the made five (kickers) — softer yellow.
    @Published private(set) var secondaryHighlightedCardIDs: Set<UUID> = []
    /// True after the hand result is shown; next hand waits for `continueToNextHand()`.
    @Published private(set) var isAwaitingContinue: Bool = false

    var hasWinningHighlights: Bool {
        !primaryHighlightedCardIDs.isEmpty || !secondaryHighlightedCardIDs.isEmpty
    }
    @Published private(set) var potAwards: [PotAward] = []
    @Published private(set) var actionBanners: [UUID: String] = [:]
    @Published private(set) var handNumber: Int = 0

    struct PotAward: Identifiable, Equatable {
        let id = UUID()
        let playerID: UUID
        let amount: Int
    }

    // MARK: - Config

    let smallBlind: Int
    let bigBlind: Int
    let raiseAmount: Int
    let blindsEnabled: Bool
    let startingChips: Int
    let botCount: Int

    @Published private(set) var humanWinStreak: Int = 0

    // MARK: - Private

    private var deck = Deck()
    private var aiTask: Task<Void, Never>?
    private var bannerTasks: [UUID: Task<Void, Never>] = [:]
    private var isActionOpen = false

    // Stats tracking
    private var sessionId: String?
    private var pendingActions: [StatsStore.PendingAction] = []
    private var handStartHumanChips: Int = 0
    private var streetRaiseCount: Int = 0
    private var recordedAllInEV: Double?
    private var humanHoleSnapshot: [Card] = []
    private var lastWentToShowdown = false
    private var lastWonAtShowdown = false
    /// Payouts held until the player taps Continue (chips fly only then).
    private var pendingPayouts: [(playerID: UUID, amount: Int)] = []

    // MARK: - Init

    init(
        humanName: String? = nil,
        aiCount: Int = 2,
        startingChips: Int = 500,
        baseBet: Int = 20,
        blindsEnabled: Bool = true
    ) {
        self.blindsEnabled = blindsEnabled
        self.startingChips = startingChips
        self.botCount = min(max(aiCount, 2), 5)
        if blindsEnabled {
            self.smallBlind = max(10, baseBet / 2)
            self.bigBlind = baseBet
            self.raiseAmount = baseBet
        } else {
            self.smallBlind = 0
            self.bigBlind = max(baseBet, 1)
            self.raiseAmount = baseBet
        }

        var seats: [Player] = [
            Player(name: humanName ?? L10n.t("player.you"), chips: startingChips, isHuman: true)
        ]
        let aiNames = ["Alex", "Blake", "Casey", "Drew", "Eden"]
        for i in 0..<self.botCount {
            seats.append(Player(name: aiNames[i], chips: startingChips, isHuman: false))
        }
        players = seats
        message = L10n.t("game.tap_to_start")

        sessionId = StatsStore.shared.startSession(
            bigBlind: self.bigBlind,
            raiseAmount: self.raiseAmount,
            startingChips: startingChips,
            botCount: self.botCount,
            blindsEnabled: blindsEnabled
        )
    }

    // MARK: - Computed Helpers

    var humanPlayer: Player? {
        players.first(where: \.isHuman)
    }

    var humanSeatIndex: Int? {
        players.firstIndex(where: \.isHuman)
    }

    var activePlayer: Player? {
        guard players.indices.contains(activePlayerIndex) else { return nil }
        return players[activePlayerIndex]
    }

    var isHumanTurn: Bool {
        guard isActionOpen, phase != .waiting, phase != .showdown, isHandInProgress else { return false }
        return activePlayer?.isHuman == true
    }

    /// Preflop without blinds: everyone must put in the base bet (or fold) to enter.
    var isBlindlessEntryRound: Bool {
        !blindsEnabled && phase == .preFlop && currentHighestBet == 0
    }

    var toCallAmount: Int {
        guard let player = humanPlayer else { return 0 }
        if isBlindlessEntryRound {
            return min(raiseAmount, player.chips)
        }
        return player.callAmount(against: currentHighestBet)
    }

    var callLabel: String {
        let amount = toCallAmount
        if amount <= 0 { return L10n.t("action.check") }
        if isBlindlessEntryRound { return L10n.format("action.enter", amount) }
        return L10n.format("action.call", amount)
    }

    var humanEquity: Int {
        guard let human = humanPlayer else { return startingChips }
        if human.isFolded {
            return human.chips
        }
        return human.chips + human.totalBetThisHand
    }

    var humanProfitPercent: Double {
        guard startingChips > 0 else { return 0 }
        return (Double(humanEquity - startingChips) / Double(startingChips)) * 100
    }

    var playersInHand: [Player] {
        players.filter(\.isInHand)
    }

    // MARK: - Public Actions

    func tearDown() {
        aiTask?.cancel()
        aiTask = nil
        for task in bannerTasks.values { task.cancel() }
        bannerTasks.removeAll()
        isHandInProgress = false
        phase = .waiting

        if let sessionId {
            StatsStore.shared.endSession(
                id: sessionId,
                endingChips: humanPlayer?.chips ?? startingChips
            )
            self.sessionId = nil
        }
    }

    func startHand() {
        aiTask?.cancel()
        guard players.filter({ $0.chips > 0 }).count >= 2 else {
            message = L10n.t("game.not_enough_players")
            phase = .waiting
            isHandInProgress = false
            return
        }

        handNumber += 1
        isHandInProgress = true
        isActionOpen = false
        showdownResults = [:]
        revealedShowdownIDs = []
        revealingPlayerID = nil
        primaryHighlightedCardIDs = []
        secondaryHighlightedCardIDs = []
        isAwaitingContinue = false
        potAwards = []
        actionBanners = [:]
        for task in bannerTasks.values { task.cancel() }
        bannerTasks.removeAll()
        communityCards = []
        pot = 0
        currentHighestBet = 0

        pendingActions = []
        handStartHumanChips = humanPlayer?.chips ?? startingChips
        streetRaiseCount = 0
        recordedAllInEV = nil
        humanHoleSnapshot = []
        lastWentToShowdown = false
        lastWonAtShowdown = false
        pendingPayouts = []

        for i in players.indices {
            players[i].resetForNewHand()
        }

        deck = Deck()
        deck.shuffle()

        phase = .preFlop
        message = L10n.t("game.blinds")
        scheduleBlindAndDeal()
    }

    func fold() {
        guard isHumanTurn else { return }
        applyFold(at: activePlayerIndex)
    }

    func checkOrCall() {
        guard isHumanTurn else { return }
        applyCheckOrCall(at: activePlayerIndex)
    }

    func raise() {
        guard isHumanTurn else { return }
        applyRaise(at: activePlayerIndex)
    }

    // MARK: - Blinds & Dealing

    private let actionGapNs: UInt64 = 800_000_000

    private func scheduleBlindAndDeal() {
        aiTask?.cancel()
        aiTask = Task { @MainActor [weak self] in
            guard let self else { return }

            try? await Task.sleep(nanoseconds: self.actionGapNs)
            guard !Task.isCancelled else { return }

            if self.blindsEnabled {
                guard let seats = self.blindSeatIndices() else { return }

                self.activePlayerIndex = seats.sb
                self.message = L10n.format(
                    "game.posts_sb",
                    self.players[seats.sb].name,
                    self.smallBlind
                )
                self.placeBet(at: seats.sb, amount: self.smallBlind)
                self.logAction(
                    seat: seats.sb,
                    type: .blind,
                    amount: self.smallBlind,
                    facingRaises: 0,
                    voluntary: false
                )

                try? await Task.sleep(nanoseconds: self.actionGapNs)
                guard !Task.isCancelled else { return }

                self.activePlayerIndex = seats.bb
                self.message = L10n.format(
                    "game.posts_bb",
                    self.players[seats.bb].name,
                    self.bigBlind
                )
                self.placeBet(at: seats.bb, amount: self.bigBlind)
                self.currentHighestBet = self.bigBlind
                self.logAction(
                    seat: seats.bb,
                    type: .blind,
                    amount: self.bigBlind,
                    facingRaises: 0,
                    voluntary: false
                )

                try? await Task.sleep(nanoseconds: self.actionGapNs)
                guard !Task.isCancelled else { return }
            } else {
                self.currentHighestBet = 0
                self.message = L10n.t("game.no_blinds")
                try? await Task.sleep(nanoseconds: self.actionGapNs)
                guard !Task.isCancelled else { return }
            }

            self.dealHoleCards()
            self.message = L10n.t("game.dealing")
            self.playDealHaptics()

            let dealWait = UInt64(max(Double(self.players.count) * 2 * 0.12 + 0.35, 0.8) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: dealWait)
            guard !Task.isCancelled else { return }

            self.message = self.blindsEnabled ? L10n.t("game.preflop") : L10n.t("game.enter_or_fold")
            self.beginBettingRound(isPreFlop: true)
        }
    }

    private func blindSeatIndices() -> (sb: Int, bb: Int)? {
        let withChips = players.indices.filter { players[$0].chips > 0 }
        guard withChips.count >= 2 else { return nil }

        let sbIndex: Int
        let bbIndex: Int
        if withChips.count == 2 {
            sbIndex = dealerIndex
            bbIndex = nextActiveIndex(after: dealerIndex)
        } else {
            sbIndex = nextActiveIndex(after: dealerIndex)
            bbIndex = nextActiveIndex(after: sbIndex)
        }
        return (sbIndex, bbIndex)
    }

    private func dealHoleCards() {
        for i in players.indices where players[i].isActive {
            players[i].holeCards = deck.draw(count: 2)
        }
        humanHoleSnapshot = humanPlayer?.holeCards ?? []
    }

    private func playDealHaptics() {
        let n = players.count
        guard n > 0 else { return }
        Task { @MainActor in
            for cardIndex in 0..<2 {
                for order in 0..<n {
                    Haptics.cardDealt()
                    let isLast = cardIndex == 1 && order == n - 1
                    if !isLast {
                        try? await Task.sleep(nanoseconds: 120_000_000)
                    }
                }
            }
        }
    }

    private func playBoardDealHaptics(count: Int) {
        Task { @MainActor in
            for i in 0..<count {
                Haptics.cardDealt()
                if i < count - 1 {
                    try? await Task.sleep(nanoseconds: 180_000_000)
                }
            }
        }
    }

    /// "You win …" / "Nyertél: …" vs third-person winner copy.
    private func winPhrase(for name: String, suffix: String) -> String {
        if players.first(where: { $0.name == name })?.isHuman == true
            || name == L10n.t("player.you") {
            return L10n.format("game.you_win", suffix)
        }
        return L10n.format("game.player_wins", name, suffix)
    }

    // MARK: - Betting Round

    private func beginBettingRound(isPreFlop: Bool) {
        for i in players.indices {
            players[i].hasActedThisRound = false
        }
        streetRaiseCount = 0

        if isPreFlop {
            if blindsEnabled {
                let activeIndices = players.indices.filter { players[$0].isInHand }
                if activeIndices.count == 2 {
                    activePlayerIndex = players[dealerIndex].canAct
                        ? dealerIndex
                        : nextCanActIndex(after: dealerIndex)
                } else {
                    let sb = nextActiveIndex(after: dealerIndex)
                    let bb = nextActiveIndex(after: sb)
                    activePlayerIndex = nextCanActIndex(after: bb)
                }
            } else {
                currentHighestBet = 0
                activePlayerIndex = nextCanActIndex(after: dealerIndex)
            }
        } else {
            currentHighestBet = 0
            activePlayerIndex = nextCanActIndex(after: dealerIndex)
        }

        if playersInHand.count <= 1 {
            scheduleEndHandEarly()
            return
        }

        maybeCaptureAllInEV()
        if shouldRunOutBoard() {
            advancePhase()
            return
        }

        if isBettingRoundComplete() {
            advancePhase()
            return
        }

        promptCurrentPlayer()
    }

    // MARK: - Timing

    private func promptCurrentPlayer() {
        guard let player = activePlayer, phase != .showdown else { return }

        if player.isHuman {
            isActionOpen = true
            message = L10n.t("game.your_turn")
            return
        }

        isActionOpen = false
        message = L10n.format("game.thinking", player.name)
        scheduleAIMove()
    }

    private func scheduleAIMove() {
        aiTask?.cancel()
        let index = activePlayerIndex
        aiTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: self?.actionGapNs ?? 800_000_000)
            guard !Task.isCancelled else { return }
            self?.performAIMove(at: index)
        }
    }

    private func performAIMove(at index: Int) {
        guard players.indices.contains(index),
              index == activePlayerIndex,
              !players[index].isHuman,
              phase != .showdown,
              isHandInProgress
        else { return }

        let action = OpponentAI.decide(
            player: players[index],
            phase: phase,
            highestBet: currentHighestBet,
            pot: pot,
            requiresEntryBet: isBlindlessEntryRound
        )

        switch action {
        case .fold:
            applyFold(at: index)
        case .checkOrCall:
            applyCheckOrCall(at: index)
        case .raise:
            applyRaise(at: index)
        }
    }

    // MARK: - Apply Actions

    private func applyFold(at index: Int) {
        guard players.indices.contains(index) else { return }
        logAction(
            seat: index,
            type: .fold,
            amount: 0,
            facingRaises: streetRaiseCount,
            voluntary: true
        )
        players[index].isFolded = true
        players[index].hasActedThisRound = true
        players[index].hasCheckedThisRound = false
        message = L10n.format("game.folds", players[index].name)
        showActionBanner(for: players[index].id, text: L10n.t("banner.fold"))
        Haptics.playerActed()

        if playersInHand.count <= 1 {
            scheduleEndHandEarly()
            return
        }

        continueAfterAction(from: index)
    }

    private func applyCheckOrCall(at index: Int) {
        guard players.indices.contains(index) else { return }
        // Blindless preflop: "call" means voluntarily entering with the base bet.
        if isBlindlessEntryRound {
            applyEntryBet(at: index)
            return
        }
        let toCall = players[index].callAmount(against: currentHighestBet)
        if toCall > 0 {
            applyCall(at: index, amount: toCall)
        } else {
            applyCheck(at: index)
        }
    }

    /// Puts in the base bet to join a blindless hand.
    private func applyEntryBet(at index: Int) {
        guard players.indices.contains(index) else { return }
        let amount = min(raiseAmount, players[index].chips)
        guard amount > 0 else {
            applyFold(at: index)
            return
        }

        logAction(
            seat: index,
            type: .bet,
            amount: amount,
            facingRaises: streetRaiseCount,
            voluntary: true
        )
        placeBet(at: index, amount: amount)
        currentHighestBet = max(currentHighestBet, players[index].currentBet)
        players[index].hasActedThisRound = true
        players[index].hasCheckedThisRound = false

        // Others still need to respond to the open bet.
        for i in players.indices where i != index && players[i].isInHand && players[i].chips > 0 {
            players[i].hasActedThisRound = false
        }

        message = L10n.format("game.enters", players[index].name, amount)
        showActionBanner(for: players[index].id, text: L10n.format("banner.enter", amount))
        Haptics.playerActed()
        maybeCaptureAllInEV()
        continueAfterAction(from: index)
    }

    private func applyCheck(at index: Int) {
        logAction(
            seat: index,
            type: .check,
            amount: 0,
            facingRaises: streetRaiseCount,
            voluntary: true
        )
        message = L10n.format("game.checks", players[index].name)
        showActionBanner(for: players[index].id, text: L10n.t("banner.check"))
        Haptics.playerActed()
        players[index].hasCheckedThisRound = true
        players[index].hasActedThisRound = true
        continueAfterAction(from: index)
    }

    private func applyCall(at index: Int, amount: Int) {
        logAction(
            seat: index,
            type: .call,
            amount: amount,
            facingRaises: streetRaiseCount,
            voluntary: true
        )
        placeBet(at: index, amount: amount)
        message = L10n.format("game.calls", players[index].name, amount)
        showActionBanner(for: players[index].id, text: L10n.format("banner.call", amount))
        Haptics.playerActed()
        players[index].hasCheckedThisRound = false
        players[index].hasActedThisRound = true
        maybeCaptureAllInEV()
        continueAfterAction(from: index)
    }

    private func applyRaise(at index: Int) {
        guard players.indices.contains(index) else { return }

        // Blindless open: Raise opens for 2× base bet so Enter stays the min buy-in.
        let toCall = players[index].callAmount(against: currentHighestBet)
        let totalNeeded = isBlindlessEntryRound
            ? min(raiseAmount * 2, players[index].chips)
            : toCall + raiseAmount

        guard players[index].chips > toCall || isBlindlessEntryRound else {
            applyCheckOrCall(at: index)
            return
        }

        guard totalNeeded > 0 else {
            applyCheckOrCall(at: index)
            return
        }

        let actionType: HandActionType = currentHighestBet == 0 ? .bet : .raise
        logAction(
            seat: index,
            type: actionType,
            amount: totalNeeded,
            facingRaises: streetRaiseCount,
            voluntary: true
        )
        streetRaiseCount += 1

        placeBet(at: index, amount: totalNeeded)
        currentHighestBet = players[index].currentBet
        players[index].hasActedThisRound = true
        players[index].hasCheckedThisRound = false

        for i in players.indices where i != index && players[i].isInHand && players[i].chips > 0 {
            players[i].hasActedThisRound = false
        }

        if actionType == .bet {
            message = L10n.format("game.bets", players[index].name, currentHighestBet)
            showActionBanner(for: players[index].id, text: L10n.format("banner.bet", currentHighestBet))
        } else {
            message = L10n.format("game.raises_to", players[index].name, currentHighestBet)
            showActionBanner(for: players[index].id, text: L10n.format("banner.raise", currentHighestBet))
        }
        Haptics.playerActed()
        maybeCaptureAllInEV()
        continueAfterAction(from: index)
    }

    private func logAction(
        seat: Int,
        type: HandActionType,
        amount: Int,
        facingRaises: Int,
        voluntary: Bool
    ) {
        guard players.indices.contains(seat) else { return }
        pendingActions.append(
            StatsStore.PendingAction(
                street: HandStreet(phase: phase),
                seat: seat,
                isHero: players[seat].isHuman,
                actionType: type,
                amount: amount,
                facingRaises: facingRaises,
                isVoluntary: voluntary
            )
        )
    }

    private func showActionBanner(for playerID: UUID, text: String) {
        var next = actionBanners
        next[playerID] = text
        actionBanners = next

        bannerTasks[playerID]?.cancel()
        bannerTasks[playerID] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard let self, !Task.isCancelled else { return }
            var cleared = self.actionBanners
            if cleared[playerID] == text {
                cleared.removeValue(forKey: playerID)
                self.actionBanners = cleared
            }
        }
    }

    private func continueAfterAction(from index: Int) {
        isActionOpen = false
        aiTask?.cancel()
        aiTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: self?.actionGapNs ?? 800_000_000)
            guard !Task.isCancelled else { return }
            self?.advanceTurnOrStreet()
        }
    }

    private func placeBet(at index: Int, amount: Int) {
        let actual = min(amount, players[index].chips)
        var next = players
        next[index].chips -= actual
        next[index].currentBet += actual
        next[index].totalBetThisHand += actual
        players = next
        pot += actual
    }

    // MARK: - All-in EV

    private func shouldRunOutBoard() -> Bool {
        let inHand = players.filter(\.isInHand)
        guard inHand.count >= 2 else { return false }
        let canAct = inHand.filter { $0.chips > 0 }
        return canAct.count <= 1
    }

    private func maybeCaptureAllInEV() {
        guard recordedAllInEV == nil else { return }
        let inHand = players.filter(\.isInHand)
        guard inHand.count >= 2 else { return }
        let canAct = inHand.filter { $0.chips > 0 }
        guard canAct.count <= 1 else { return }
        guard let human = humanPlayer, human.isInHand, human.holeCards.count == 2 else { return }

        let villainHoles = inHand
            .filter { !$0.isHuman && $0.holeCards.count == 2 }
            .map(\.holeCards)
        guard !villainHoles.isEmpty else { return }

        recordedAllInEV = EquityCalculator.allInEVDelta(
            heroHole: human.holeCards,
            villainHoles: villainHoles,
            board: communityCards,
            pot: pot,
            heroContribution: human.totalBetThisHand
        )
    }

    // MARK: - Turn / Street Progression

    private func advanceTurnOrStreet() {
        if playersInHand.count <= 1 {
            scheduleEndHandEarly()
            return
        }

        maybeCaptureAllInEV()
        if shouldRunOutBoard() {
            // Skip remaining betting; run streets out to showdown.
            advancePhase()
            return
        }

        if isBettingRoundComplete() {
            advancePhase()
            return
        }

        activePlayerIndex = nextCanActIndex(after: activePlayerIndex)
        promptCurrentPlayer()
    }

    private func isBettingRoundComplete() -> Bool {
        let contenders = players.filter { $0.isInHand }
        guard contenders.count > 1 else { return true }

        for player in contenders {
            if player.chips == 0 { continue }
            if !player.hasActedThisRound { return false }
            if player.currentBet < currentHighestBet { return false }
        }
        return true
    }

    private func advancePhase() {
        isActionOpen = false

        for i in players.indices {
            players[i].resetForNewStreet()
        }
        currentHighestBet = 0

        let previousPhase = phase
        let runOut = shouldRunOutBoard()

        aiTask?.cancel()
        aiTask = Task { @MainActor [weak self] in
            guard let self else { return }

            try? await Task.sleep(nanoseconds: self.actionGapNs)
            guard !Task.isCancelled else { return }

            switch previousPhase {
            case .preFlop:
                self.communityCards.append(contentsOf: self.deck.draw(count: 3))
                self.phase = .flop
                self.message = L10n.t("game.flop")
                self.playBoardDealHaptics(count: 3)
            case .flop:
                if let card = self.deck.draw() {
                    self.communityCards.append(card)
                }
                self.phase = .turn
                self.message = L10n.t("game.turn")
                self.playBoardDealHaptics(count: 1)
            case .turn:
                if let card = self.deck.draw() {
                    self.communityCards.append(card)
                }
                self.phase = .river
                self.message = L10n.t("game.river")
                self.playBoardDealHaptics(count: 1)
            case .river:
                self.runShowdown()
                return
            default:
                return
            }

            self.maybeCaptureAllInEV()

            try? await Task.sleep(nanoseconds: self.actionGapNs)
            guard !Task.isCancelled else { return }

            if runOut {
                self.advancePhase()
            } else {
                self.beginBettingRound(isPreFlop: false)
            }
        }
    }

    // MARK: - Showdown & Reset

    private func scheduleEndHandEarly() {
        isActionOpen = false
        aiTask?.cancel()
        aiTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: self?.actionGapNs ?? 800_000_000)
            guard !Task.isCancelled else { return }
            self?.endHandEarly()
        }
    }

    private func endHandEarly() {
        aiTask?.cancel()
        guard let winner = playersInHand.first else {
            message = L10n.t("game.hand_over")
            persistCurrentHand(wentToShowdown: false, wonAtShowdown: false)
            pendingPayouts = []
            awaitContinue()
            return
        }

        lastWentToShowdown = false
        lastWonAtShowdown = false
        pendingPayouts = [(winner.id, pot)]
        message = winPhrase(for: winner.name, suffix: "\(pot)")
        phase = .showdown
        isHandInProgress = false
        awaitContinue()
    }

    private func runShowdown() {
        aiTask?.cancel()
        phase = .showdown
        isHandInProgress = false
        isActionOpen = false
        revealedShowdownIDs = []
        revealingPlayerID = nil
        primaryHighlightedCardIDs = []
        secondaryHighlightedCardIDs = []
        isAwaitingContinue = false
        showdownResults = [:]
        potAwards = []
        lastWentToShowdown = true

        let contenders = players.filter(\.isInHand)
        var evaluations: [UUID: EvaluatedHand] = [:]
        for player in contenders {
            evaluations[player.id] = HandEvaluator.evaluateBestHand(
                hole: player.holeCards,
                community: communityCards
            )
        }

        let ordered = contenders.sorted { a, b in
            revealOrder(of: a) < revealOrder(of: b)
        }

        // Capture contributions before payout clears them.
        let contributions = players.map {
            (id: $0.id, amount: $0.totalBetThisHand, inHand: $0.isInHand)
        }
        let sidePots = SidePotCalculator.pots(contributions: contributions)
        let payouts = SidePotCalculator.awards(pots: sidePots, evaluations: evaluations)

        aiTask = Task { @MainActor [weak self] in
            guard let self else { return }

            self.message = L10n.t("game.showdown")
            try? await Task.sleep(nanoseconds: self.actionGapNs)
            guard !Task.isCancelled else { return }

            for player in ordered {
                guard !Task.isCancelled else { return }

                self.revealingPlayerID = player.id
                self.revealedShowdownIDs.insert(player.id)
                self.message = L10n.format("game.reveals", player.name)
                Haptics.cardRevealed()

                try? await Task.sleep(nanoseconds: self.actionGapNs)
                guard !Task.isCancelled else { return }

                if let hand = evaluations[player.id] {
                    self.showdownResults[player.id] = hand
                    self.message = L10n.format(
                        "game.player_hand",
                        player.name,
                        hand.category.displayName
                    )
                }

                try? await Task.sleep(nanoseconds: self.actionGapNs * 2)
            }

            guard !Task.isCancelled else { return }
            self.revealingPlayerID = nil

            if let humanID = self.humanPlayer?.id {
                self.lastWonAtShowdown = payouts.contains { $0.playerID == humanID && $0.amount > 0 }
            }

            // 1) Highlight winning cards first so the result is readable.
            // Strong = category-defining cards; soft = the other cards in the made five.
            var primaryIDs = Set<UUID>()
            var secondaryIDs = Set<UUID>()
            for payout in payouts where payout.amount > 0 {
                guard let hand = evaluations[payout.playerID] else { continue }
                let groups = hand.highlightGroups()
                primaryIDs.formUnion(groups.primary)
                secondaryIDs.formUnion(groups.secondary)
            }
            secondaryIDs.subtract(primaryIDs)
            self.primaryHighlightedCardIDs = primaryIDs
            self.secondaryHighlightedCardIDs = secondaryIDs

            if payouts.count == 1, let only = payouts.first,
               let winner = self.players.first(where: { $0.id == only.playerID }) {
                let handName = evaluations[winner.id]?.category.displayName ?? ""
                let suffix = handName.isEmpty
                    ? "\(only.amount)"
                    : L10n.format("game.with_hand", handName)
                self.message = self.winPhrase(for: winner.name, suffix: suffix)
            } else {
                let names = payouts
                    .compactMap { p in self.players.first(where: { $0.id == p.playerID })?.name }
                    .joined(separator: ", ")
                self.message = L10n.format("game.split_pot", names)
            }

            // Hold chips until Continue — then they fly to the winner(s).
            self.pendingPayouts = payouts
            self.awaitContinue()
        }
    }

    /// After the result is shown: pay out chips, then deal the next hand.
    func continueToNextHand() {
        guard isAwaitingContinue else { return }
        isAwaitingContinue = false
        aiTask?.cancel()

        let payouts = pendingPayouts
        pendingPayouts = []

        aiTask = Task { @MainActor [weak self] in
            guard let self else { return }

            if !payouts.isEmpty {
                self.award(payouts)
                self.pot = 0

                if payouts.count == 1, let only = payouts.first,
                   let winner = self.players.first(where: { $0.id == only.playerID }) {
                    let handName = self.showdownResults[winner.id]?.category.displayName ?? ""
                    if handName.isEmpty {
                        self.message = self.winPhrase(for: winner.name, suffix: "\(only.amount)")
                    } else {
                        let suffix = L10n.format("game.amount_with_hand", only.amount, handName)
                        self.message = self.winPhrase(for: winner.name, suffix: suffix)
                    }
                } else {
                    let names = payouts
                        .compactMap { p in self.players.first(where: { $0.id == p.playerID })?.name }
                        .joined(separator: ", ")
                    let total = payouts.reduce(0) { $0 + $1.amount }
                    self.message = L10n.format("game.split_side_pots", total, names)
                }

                // Let the pot chips finish flying before the next deal.
                try? await Task.sleep(nanoseconds: self.actionGapNs * 2)
                guard !Task.isCancelled else { return }
            }

            self.prepareNextHand()
        }
    }

    private func awaitContinue() {
        isAwaitingContinue = true
    }

    private func revealOrder(of player: Player) -> Int {
        let n = players.count
        guard n > 0, let idx = players.firstIndex(where: { $0.id == player.id }) else { return 0 }
        return (idx - dealerIndex - 1 + n) % n
    }

    private func award(_ payouts: [(playerID: UUID, amount: Int)]) {
        for payout in payouts {
            if let idx = players.firstIndex(where: { $0.id == payout.playerID }) {
                players[idx].chips += payout.amount
            }
        }
        for i in players.indices {
            players[i].totalBetThisHand = 0
        }
        potAwards = payouts
            .filter { $0.amount > 0 }
            .map { PotAward(playerID: $0.playerID, amount: $0.amount) }

        if let humanID = humanPlayer?.id {
            let humanWon = payouts.contains { $0.playerID == humanID && $0.amount > 0 }
            humanWinStreak = humanWon ? humanWinStreak + 1 : 0
        }

        persistCurrentHand(
            wentToShowdown: lastWentToShowdown,
            wonAtShowdown: lastWonAtShowdown
        )
    }

    private func persistCurrentHand(wentToShowdown: Bool, wonAtShowdown: Bool) {
        guard let sessionId, let humanSeat = humanSeatIndex else { return }
        let human = players[humanSeat]
        let netWon = human.chips - handStartHumanChips
        let position = TablePosition.resolve(
            seat: humanSeat,
            dealerIndex: dealerIndex,
            playerCount: players.count
        )
        let hole = humanHoleSnapshot.isEmpty ? human.holeCards : humanHoleSnapshot

        StatsStore.shared.saveHand(
            sessionId: sessionId,
            handIndex: handNumber,
            dealerSeat: dealerIndex,
            humanSeat: humanSeat,
            humanPosition: position,
            bigBlind: bigBlind,
            board: communityCards,
            humanHole: hole,
            netWon: netWon,
            allInEV: recordedAllInEV,
            wentToShowdown: wentToShowdown,
            wonAtShowdown: wonAtShowdown,
            actions: pendingActions
        )
        pendingActions = []
    }

    private func scheduleNextHand(afterNanoseconds delay: UInt64 = 2_500_000_000) {
        aiTask?.cancel()
        aiTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            self?.prepareNextHand()
        }
    }

    private func prepareNextHand() {
        dealerIndex = nextActiveIndex(after: dealerIndex)
        communityCards = []
        showdownResults = [:]
        revealedShowdownIDs = []
        revealingPlayerID = nil
        primaryHighlightedCardIDs = []
        secondaryHighlightedCardIDs = []
        isAwaitingContinue = false
        pendingPayouts = []
        potAwards = []
        currentHighestBet = 0
        startHand()
    }

    // MARK: - Index Helpers

    private func nextActiveIndex(after index: Int) -> Int {
        guard !players.isEmpty else { return 0 }
        var i = index
        for _ in 0..<players.count {
            i = (i + 1) % players.count
            if players[i].chips > 0 || players[i].isInHand {
                return i
            }
        }
        return (index + 1) % players.count
    }

    private func nextCanActIndex(after index: Int) -> Int {
        guard !players.isEmpty else { return 0 }
        var i = index
        for _ in 0..<players.count {
            i = (i + 1) % players.count
            if players[i].canAct {
                return i
            }
        }
        return index
    }
}
