import UIKit

/// Lightweight haptic helpers for table actions.
@MainActor
enum Haptics {
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)

    static func prepare() {
        soft.prepare()
        light.prepare()
        medium.prepare()
        heavy.prepare()
        rigid.prepare()
    }

    /// First tap on Check / Call — soft cue.
    static func checkArm() {
        soft.impactOccurred(intensity: 0.4)
        soft.prepare()
    }

    /// Second tap on Check / Call — firm confirm.
    static func checkConfirm() {
        rigid.impactOccurred(intensity: 1.0)
        rigid.prepare()
    }

    /// Human's turn just became active.
    static func yourTurn() {
        heavy.impactOccurred(intensity: 1.0)
        heavy.prepare()
    }

    /// Soft tick when a hole / board card is dealt.
    static func cardDealt() {
        soft.impactOccurred(intensity: 0.55)
        soft.prepare()
    }

    /// Firmer cue when a hole card is revealed at showdown.
    static func cardRevealed() {
        medium.impactOccurred(intensity: 0.75)
        medium.prepare()
    }

    /// Light feedback after any seat commits an action.
    static func playerActed() {
        light.impactOccurred(intensity: 0.55)
        light.prepare()
    }

    /// Final commit when a hold gesture completes.
    static func holdComplete() {
        rigid.impactOccurred(intensity: 1.0)
        rigid.prepare()
    }

    fileprivate static func holdTick(intensity: CGFloat) {
        let clamped = min(max(intensity, 0.15), 1)
        if clamped < 0.4 {
            soft.impactOccurred(intensity: clamped)
            soft.prepare()
        } else if clamped < 0.7 {
            light.impactOccurred(intensity: clamped)
            light.prepare()
        } else if clamped < 0.9 {
            medium.impactOccurred(intensity: clamped)
            medium.prepare()
        } else {
            heavy.impactOccurred(intensity: clamped)
            heavy.prepare()
        }
    }
}

/// Rising haptic pulses while Fold / Raise is held.
@MainActor
final class HoldHapticPlayer {
    enum Kind {
        /// Denser ticks while holding Fold.
        case fold
        /// Sparser ticks while holding Raise.
        case raise

        var intervalNanoseconds: UInt64 {
            switch self {
            case .fold: return 70_000_000
            case .raise: return 140_000_000
            }
        }
    }

    private var task: Task<Void, Never>?

    func start(kind: Kind, duration: Double) {
        stop()
        let intervalNs = kind.intervalNanoseconds
        let ticks = max(Int((duration * 1_000_000_000) / Double(intervalNs)), 1)
        task = Task { @MainActor in
            for i in 0..<ticks {
                guard !Task.isCancelled else { return }
                let progress = Double(i) / Double(max(ticks - 1, 1))
                // Ease-in so the last moments feel strongest.
                let intensity = 0.2 + pow(progress, 1.35) * 0.8
                Haptics.holdTick(intensity: intensity)
                try? await Task.sleep(nanoseconds: intervalNs)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
