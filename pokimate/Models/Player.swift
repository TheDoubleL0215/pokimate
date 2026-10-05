import Foundation

struct Player: Identifiable, Hashable {
    let id: UUID
    var name: String
    var chips: Int
    var currentBet: Int
    /// Chips this player has put in during the current hand (stays visible in front of them).
    var totalBetThisHand: Int
    var holeCards: [Card]
    var isHuman: Bool
    var isActive: Bool
    var isFolded: Bool
    var hasActedThisRound: Bool
    /// True after a check this street (cleared on call/raise/new street).
    var hasCheckedThisRound: Bool

    init(
        id: UUID = UUID(),
        name: String,
        chips: Int,
        currentBet: Int = 0,
        totalBetThisHand: Int = 0,
        holeCards: [Card] = [],
        isHuman: Bool = false,
        isActive: Bool = true,
        isFolded: Bool = false,
        hasActedThisRound: Bool = false,
        hasCheckedThisRound: Bool = false
    ) {
        self.id = id
        self.name = name
        self.chips = chips
        self.currentBet = currentBet
        self.totalBetThisHand = totalBetThisHand
        self.holeCards = holeCards
        self.isHuman = isHuman
        self.isActive = isActive
        self.isFolded = isFolded
        self.hasActedThisRound = hasActedThisRound
        self.hasCheckedThisRound = hasCheckedThisRound
    }

    var isInHand: Bool {
        isActive && !isFolded && chips >= 0
    }

    var canAct: Bool {
        isInHand && chips > 0
    }

    func canCheck(against highestBet: Int) -> Bool {
        currentBet >= highestBet
    }

    func callAmount(against highestBet: Int) -> Int {
        max(0, highestBet - currentBet)
    }

    mutating func resetForNewHand() {
        currentBet = 0
        totalBetThisHand = 0
        holeCards = []
        isFolded = false
        hasActedThisRound = false
        hasCheckedThisRound = false
        isActive = chips > 0
    }

    mutating func resetForNewStreet() {
        currentBet = 0
        hasActedThisRound = false
        hasCheckedThisRound = false
    }
}
