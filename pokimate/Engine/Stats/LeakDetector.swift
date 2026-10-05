import Foundation

enum LeakDetector {

    @MainActor
    static func warnings(hud: HUDStats, positions: [PositionStat]) -> [LeakWarning] {
        var leaks: [LeakWarning] = []

        if hud.hands >= 30 {
            if hud.vpip > 40 {
                leaks.append(LeakWarning(
                    title: L10n.t("leak.loose_vpip.title"),
                    detail: L10n.format("leak.loose_vpip.detail", hud.vpip),
                    severity: 2
                ))
            }
            if hud.vpip < 12 {
                leaks.append(LeakWarning(
                    title: L10n.t("leak.tight_vpip.title"),
                    detail: L10n.format("leak.tight_vpip.detail", hud.vpip),
                    severity: 1
                ))
            }
            if hud.pfr > 0, hud.vpip - hud.pfr > 15 {
                leaks.append(LeakWarning(
                    title: L10n.t("leak.limp.title"),
                    detail: L10n.format("leak.limp.detail", hud.vpip - hud.pfr),
                    severity: 2
                ))
            }
            if hud.foldToThreeBet > 70 {
                leaks.append(LeakWarning(
                    title: L10n.t("leak.fold_3bet.title"),
                    detail: L10n.format("leak.fold_3bet.detail", hud.foldToThreeBet),
                    severity: 2
                ))
            }
            if hud.aggressionFactor > 0, hud.aggressionFactor < 1.2 {
                leaks.append(LeakWarning(
                    title: L10n.t("leak.passive.title"),
                    detail: L10n.format("leak.passive.detail", hud.aggressionFactor),
                    severity: 1
                ))
            }
            if hud.wsd > 40 {
                leaks.append(LeakWarning(
                    title: L10n.t("leak.wsd.title"),
                    detail: L10n.format("leak.wsd.detail", hud.wsd),
                    severity: 1
                ))
            }
            if hud.wDollarSD < 45, hud.hands >= 40 {
                leaks.append(LeakWarning(
                    title: L10n.t("leak.wsd_win.title"),
                    detail: L10n.format("leak.wsd_win.detail", hud.wDollarSD),
                    severity: 2
                ))
            }
        }

        if let sb = positions.first(where: { $0.position == "SB" }), sb.hands >= 15, sb.bbPer100 < -40 {
            leaks.append(LeakWarning(
                title: L10n.t("leak.sb_loss.title"),
                detail: L10n.format("leak.sb_loss.detail", sb.bbPer100),
                severity: 3
            ))
        }

        if let bb = positions.first(where: { $0.position == "BB" }), bb.hands >= 15, bb.bbPer100 < -50 {
            leaks.append(LeakWarning(
                title: L10n.t("leak.bb_loss.title"),
                detail: L10n.format("leak.bb_loss.detail", bb.bbPer100),
                severity: 2
            ))
        }

        return leaks.sorted { $0.severity > $1.severity }
    }
}
