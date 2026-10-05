import SwiftUI

// MARK: - Denominations

enum ChipDenomination: Int, CaseIterable, Identifiable {
    case twoHundred = 200
    case oneHundred = 100
    case fifty = 50
    case twenty = 20
    case ten = 10

    var id: Int { rawValue }

    /// Greedy breakdown order (largest first).
    static let breakdownOrder: [ChipDenomination] = [
        .twoHundred, .oneHundred, .fifty, .twenty, .ten
    ]

    var fill: Color {
        switch self {
        case .ten:
            return Color(red: 0.88, green: 0.88, blue: 0.9)
        case .twenty:
            return Color(red: 0, green: 0.44, blue: 0.33) // light blue
        case .fifty:
            return Color(red: 0.12, green: 0.28, blue: 0.65) // deep blue
        case .oneHundred:
            return Color(red: 0.75, green: 0.18, blue: 0.2)
        case .twoHundred:
            return Color(red: 0.12, green: 0.12, blue: 0.14)
        }
    }

    var labelColor: Color {
        switch self {
        case .ten:
            return Color.black.opacity(0.8)
        default:
            return Color.white.opacity(0.95)
        }
    }

    var edgeColor: Color {
        switch self {
        case .ten:
            return Color.black.opacity(0.2)
        case .twoHundred:
            return Color.white.opacity(0.35)
        default:
            return Color.white.opacity(0.45)
        }
    }
}

enum ChipMath {
    /// Break `amount` into chip counts using 200 / 100 / 50 / 20 / 10.
    /// Amounts should be multiples of 10; any leftover under 10 is dropped from the visual stacks.
    static func breakdown(amount: Int) -> [(ChipDenomination, Int)] {
        guard amount > 0 else { return [] }
        var left = amount
        var stacks: [(ChipDenomination, Int)] = []
        for denom in ChipDenomination.breakdownOrder {
            let count = left / denom.rawValue
            if count > 0 {
                stacks.append((denom, count))
                left -= count * denom.rawValue
            }
        }
        return stacks
    }
}

// MARK: - Single Chip

struct ChipView: View {
    let denomination: ChipDenomination
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            denomination.fill.opacity(1.15),
                            denomination.fill,
                            denomination.fill.opacity(0.85)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.55
                    )
                )

            // Edge dashes (poker chip rim)
            Circle()
                .strokeBorder(denomination.edgeColor, style: StrokeStyle(lineWidth: size * 0.08, dash: [size * 0.12, size * 0.1]))
                .padding(size * 0.06)

            Circle()
                .strokeBorder(denomination.edgeColor.opacity(0.5), lineWidth: 1)
                .padding(size * 0.22)

            Text("\(denomination.rawValue)")
                .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                .foregroundStyle(denomination.labelColor)
                .minimumScaleFactor(0.5)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
    }
}

// MARK: - Vertical stack of one denomination

struct ChipPileView: View {
    let denomination: ChipDenomination
    let count: Int
    var chipSize: CGFloat = 56

    /// How many physical chips to draw (cap for layout).
    private var visibleCount: Int {
        min(count, 5)
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                ForEach(0..<visibleCount, id: \.self) { i in
                    ChipView(denomination: denomination, size: chipSize)
                        .offset(y: -CGFloat(i) * (chipSize * 0.14))
                }
            }
            .frame(width: chipSize, height: chipSize + CGFloat(visibleCount - 1) * (chipSize * 0.14))

            if count > 1 {
                Text("×\(count)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(PokerTheme.textSecondary)
            }
        }
    }
}

// MARK: - Full amount as chip stacks

struct ChipStackView: View {
    let amount: Int
    var chipSize: CGFloat = 36
    var showTotal: Bool = true

    private var stacks: [(ChipDenomination, Int)] {
        ChipMath.breakdown(amount: amount)
    }

    var body: some View {
        if amount <= 0 {
            EmptyView()
        } else {
            VStack(spacing: 4) {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(stacks, id: \.0) { denom, count in
                        ChipPileView(denomination: denom, count: count, chipSize: chipSize)
                    }
                }

                if showTotal {
                    Text("$\(amount)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PokerTheme.textPrimary)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        ChipStackView(amount: 10)
        ChipStackView(amount: 70)
        ChipStackView(amount: 380)
        ChipStackView(amount: 20)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(PokerTheme.tableFelt)
}

// MARK: - Bet chips that fly from the player seat onto the felt

struct AnimatedPlayerBetChips: View {
    let amount: Int
    let seatPosition: CGPoint
    let betPosition: CGPoint
    var chipSize: CGFloat = 20

    /// 0 = at the player, 1 = landed at the bet spot.
    @State private var progress: CGFloat = 0
    @State private var lastAmount: Int = 0

    private var currentPosition: CGPoint {
        CGPoint(
            x: seatPosition.x + (betPosition.x - seatPosition.x) * progress,
            y: seatPosition.y + (betPosition.y - seatPosition.y) * progress
        )
    }

    var body: some View {
        Group {
            if amount > 0 {
                ChipStackView(amount: amount, chipSize: chipSize, showTotal: true)
                    .position(currentPosition)
                    .opacity(Double(0.35 + 0.65 * progress))
                    .scaleEffect(0.85 + 0.15 * progress)
            }
        }
        .onAppear {
            launchFromPlayer(newAmount: amount)
        }
        .onChange(of: amount) { _, newAmount in
            if newAmount > lastAmount {
                // Fresh chips push out from the player again.
                launchFromPlayer(newAmount: newAmount)
            } else if newAmount <= 0 {
                progress = 0
                lastAmount = 0
            } else {
                lastAmount = newAmount
                progress = 1
            }
        }
        .onChange(of: seatPosition.x) { _, _ in
            // Keep landed chips aligned if layout shifts.
            if lastAmount > 0 { progress = 1 }
        }
    }

    private func launchFromPlayer(newAmount: Int) {
        lastAmount = newAmount
        progress = 0
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            progress = 1
        }
    }
}

// MARK: - Pot chips that fly from the center to the winner

struct PotAwardChips: View {
    let amount: Int
    let from: CGPoint
    let to: CGPoint
    var chipSize: CGFloat = 22
    var delay: Double = 0.35

    @State private var progress: CGFloat = 0
    @State private var faded = false

    private var currentPosition: CGPoint {
        CGPoint(
            x: from.x + (to.x - from.x) * progress,
            y: from.y + (to.y - from.y) * progress
        )
    }

    var body: some View {
        ChipStackView(amount: amount, chipSize: chipSize, showTotal: true)
            .scaleEffect(1.15 - 0.35 * progress)
            .position(currentPosition)
            .opacity(faded ? 0 : 1)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.82).delay(delay)) {
                    progress = 1
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(delay + 0.9))
                withAnimation(.easeOut(duration: 0.35)) {
                    faded = true
                }
            }
    }
}
