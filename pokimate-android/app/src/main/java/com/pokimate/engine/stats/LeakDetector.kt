package com.pokimate.engine.stats

import com.pokimate.i18n.L10n
import com.pokimate.model.HUDStats
import com.pokimate.model.LeakWarning
import com.pokimate.model.PositionStat

object LeakDetector {

    fun warnings(hud: HUDStats, positions: List<PositionStat>): List<LeakWarning> {
        val leaks = mutableListOf<LeakWarning>()

        if (hud.hands >= 30) {
            if (hud.vpip > 40) {
                leaks.add(
                    LeakWarning(
                        title = L10n.t("leak.loose_vpip.title"),
                        detail = L10n.format("leak.loose_vpip.detail", hud.vpip),
                        severity = 2
                    )
                )
            }
            if (hud.vpip < 12) {
                leaks.add(
                    LeakWarning(
                        title = L10n.t("leak.tight_vpip.title"),
                        detail = L10n.format("leak.tight_vpip.detail", hud.vpip),
                        severity = 1
                    )
                )
            }
            if (hud.pfr > 0 && hud.vpip - hud.pfr > 15) {
                leaks.add(
                    LeakWarning(
                        title = L10n.t("leak.limp.title"),
                        detail = L10n.format("leak.limp.detail", hud.vpip - hud.pfr),
                        severity = 2
                    )
                )
            }
            if (hud.foldToThreeBet > 70) {
                leaks.add(
                    LeakWarning(
                        title = L10n.t("leak.fold_3bet.title"),
                        detail = L10n.format("leak.fold_3bet.detail", hud.foldToThreeBet),
                        severity = 2
                    )
                )
            }
            if (hud.aggressionFactor > 0 && hud.aggressionFactor < 1.2) {
                leaks.add(
                    LeakWarning(
                        title = L10n.t("leak.passive.title"),
                        detail = L10n.format("leak.passive.detail", hud.aggressionFactor),
                        severity = 1
                    )
                )
            }
            if (hud.wsd > 40) {
                leaks.add(
                    LeakWarning(
                        title = L10n.t("leak.wsd.title"),
                        detail = L10n.format("leak.wsd.detail", hud.wsd),
                        severity = 1
                    )
                )
            }
            if (hud.wDollarSD < 45 && hud.hands >= 40) {
                leaks.add(
                    LeakWarning(
                        title = L10n.t("leak.wsd_win.title"),
                        detail = L10n.format("leak.wsd_win.detail", hud.wDollarSD),
                        severity = 2
                    )
                )
            }
        }

        val sb = positions.firstOrNull { it.position == "SB" }
        if (sb != null && sb.hands >= 15 && sb.bbPer100 < -40) {
            leaks.add(
                LeakWarning(
                    title = L10n.t("leak.sb_loss.title"),
                    detail = L10n.format("leak.sb_loss.detail", sb.bbPer100),
                    severity = 3
                )
            )
        }

        val bb = positions.firstOrNull { it.position == "BB" }
        if (bb != null && bb.hands >= 15 && bb.bbPer100 < -50) {
            leaks.add(
                LeakWarning(
                    title = L10n.t("leak.bb_loss.title"),
                    detail = L10n.format("leak.bb_loss.detail", bb.bbPer100),
                    severity = 2
                )
            )
        }

        return leaks.sortedByDescending { it.severity }
    }
}
