package com.pokimate.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.pokimate.R
import com.pokimate.engine.EvaluatedHand
import com.pokimate.model.GamePhase
import com.pokimate.model.Player
import com.pokimate.ui.GameViewModel
import com.pokimate.ui.components.ActionBannerLabel
import com.pokimate.ui.components.ActionBar
import com.pokimate.ui.components.CardHighlightStyle
import com.pokimate.ui.components.CommunityCardSlot
import com.pokimate.ui.components.GlassIconButton
import com.pokimate.ui.components.PlayerSeat
import com.pokimate.ui.components.cardHighlightFor
import com.pokimate.ui.theme.PokerBackground
import com.pokimate.ui.theme.PokerTableFelt
import com.pokimate.ui.theme.PokerTableFeltLight
import com.pokimate.ui.theme.PokerTableRail
import com.pokimate.ui.theme.PokerTableRailHighlight
import com.pokimate.ui.theme.PokerTextPrimary
import com.pokimate.ui.theme.PokerWinningCardStroke
import com.pokimate.ui.theme.PokimateFontFamily
import java.util.UUID
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

@Composable
fun GameScreen(
    humanName: String,
    startingChips: Int,
    baseBet: Int,
    blindsEnabled: Boolean,
    botCount: Int,
    onExitToMenu: () -> Unit,
) {
    val vm: GameViewModel = viewModel(
        factory = GameViewModel.Factory(
            humanName = humanName,
            aiCount = botCount,
            startingChips = startingChips,
            baseBet = baseBet,
            blindsEnabled = blindsEnabled,
        ),
    )
    val snap by vm.snapshot.collectAsStateWithLifecycle()
    val state = snap.state

    LaunchedEffect(Unit) {
        if (state.phase == GamePhase.WAITING && !state.isHandInProgress) {
            vm.startHand()
        }
    }

    val human = state.players.firstOrNull { it.isHuman }
    val opponents = state.players.filter { !it.isHuman }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(PokerBackground)
            .statusBarsPadding()
            .navigationBarsPadding(),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            GlassIconButton(onClick = {
                vm.exit()
                onExitToMenu()
            }) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = stringResource(R.string.a11y_menu),
                    tint = PokerTextPrimary,
                )
            }
            Spacer(Modifier.weight(1f))
            Text(
                text = state.phase.displayName,
                color = PokerTextPrimary.copy(alpha = 0.7f),
                fontFamily = PokimateFontFamily,
                fontWeight = FontWeight.Bold,
                fontSize = 13.sp,
            )
            Spacer(Modifier.weight(1f))
            Box(Modifier.width(40.dp))
        }

        BoxWithConstraints(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 4.dp),
        ) {
            val w = maxWidth
            val h = maxHeight
            OvalFeltTable(modifier = Modifier.fillMaxSize())

            Column(
                modifier = Modifier.align(Alignment.Center),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text(
                    text = "${stringResource(R.string.table_pot)}  ${state.pot}",
                    color = PokerTextPrimary,
                    fontFamily = PokimateFontFamily,
                    fontWeight = FontWeight.ExtraBold,
                    fontSize = 14.sp,
                    modifier = Modifier
                        .clip(RoundedCornerShape(percent = 50))
                        .background(Color.Black.copy(alpha = 0.45f))
                        .padding(horizontal = 12.dp, vertical = 4.dp),
                )
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    repeat(5) { index ->
                        val card = state.communityCards.getOrNull(index)
                        CommunityCardSlot(
                            card = card,
                            highlight = card?.let {
                                cardHighlightFor(
                                    it.id,
                                    state.primaryHighlightedCardIDs,
                                    state.secondaryHighlightedCardIDs,
                                )
                            } ?: CardHighlightStyle.None,
                        )
                    }
                }
                if (state.hasWinningHighlights || state.isAwaitingContinue) {
                    Text(
                        text = state.message,
                        color = PokerWinningCardStroke,
                        fontFamily = PokimateFontFamily,
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp,
                        textAlign = TextAlign.Center,
                        maxLines = 2,
                        modifier = Modifier
                            .clip(RoundedCornerShape(percent = 50))
                            .background(Color.Black.copy(alpha = 0.55f))
                            .border(
                                1.dp,
                                PokerWinningCardStroke.copy(alpha = 0.35f),
                                RoundedCornerShape(percent = 50),
                            )
                            .padding(horizontal = 12.dp, vertical = 5.dp),
                    )
                } else if (state.message.isNotBlank()) {
                    Text(
                        text = state.message,
                        color = PokerTextPrimary.copy(alpha = 0.75f),
                        fontFamily = PokimateFontFamily,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 12.sp,
                        textAlign = TextAlign.Center,
                        maxLines = 2,
                    )
                }
            }

            OpponentSeats(
                opponents = opponents,
                allPlayers = state.players,
                dealerIndex = state.dealerIndex,
                activePlayerIndex = state.activePlayerIndex,
                revealedIds = state.revealedShowdownIDs,
                showdownResults = state.showdownResults,
                primary = state.primaryHighlightedCardIDs,
                secondary = state.secondaryHighlightedCardIDs,
                banners = state.actionBanners,
                tableWidth = w,
                tableHeight = h,
            )
        }

        ActionBar(
            holeCards = human?.holeCards.orEmpty(),
            balance = human?.chips ?: 0,
            isEnabled = snap.isHumanTurn,
            callLabel = snap.callLabel,
            toCallAmount = snap.toCallAmount,
            showContinue = state.isAwaitingContinue,
            onFold = vm::fold,
            onCheckOrCall = vm::checkOrCall,
            onRaise = vm::raise,
            onContinue = vm::continueToNextHand,
            primaryHighlighted = state.primaryHighlightedCardIDs,
            secondaryHighlighted = state.secondaryHighlightedCardIDs,
            winStreak = state.humanWinStreak,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 8.dp),
        )
    }
}

@Composable
private fun OvalFeltTable(modifier: Modifier = Modifier) {
    Box(modifier = modifier) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 10.dp, vertical = 18.dp)
                .clip(RoundedCornerShape(percent = 50))
                .background(PokerTableRail)
                .border(1.5.dp, PokerTableRailHighlight, RoundedCornerShape(percent = 50)),
        )
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 22.dp, vertical = 32.dp)
                .clip(RoundedCornerShape(percent = 50))
                .background(
                    Brush.radialGradient(
                        colors = listOf(
                            PokerTableFeltLight,
                            PokerTableFelt,
                            Color.Black.copy(alpha = 0.55f),
                        ),
                    ),
                )
                .border(1.dp, Color.White.copy(alpha = 0.06f), RoundedCornerShape(percent = 50)),
        )
    }
}

@Composable
private fun OpponentSeats(
    opponents: List<Player>,
    allPlayers: List<Player>,
    dealerIndex: Int,
    activePlayerIndex: Int,
    revealedIds: Set<UUID>,
    showdownResults: Map<UUID, EvaluatedHand>,
    primary: Set<UUID>,
    secondary: Set<UUID>,
    banners: Map<UUID, String>,
    tableWidth: Dp,
    tableHeight: Dp,
) {
    if (opponents.isEmpty()) return
    val density = LocalDensity.current
    val cx = with(density) { tableWidth.toPx() / 2f }
    val cy = with(density) { tableHeight.toPx() / 2f }
    val rx = with(density) { (tableWidth * 0.38f).toPx() }
    val ry = with(density) { (tableHeight * 0.34f).toPx() }

    opponents.forEachIndexed { index, player ->
        val t = if (opponents.size == 1) 0.5f else index / (opponents.size - 1).toFloat()
        val angle = PI + t * PI
        val xPx = cx + (rx * cos(angle)).toFloat()
        val yPx = cy + (ry * sin(angle)).toFloat()
        val xDp = with(density) { xPx.toDp() } - 56.dp
        val yDp = with(density) { yPx.toDp() } - 48.dp
        val globalIndex = allPlayers.indexOfFirst { it.id == player.id }

        Box(modifier = Modifier.offset(x = xDp, y = yDp)) {
            PlayerSeat(
                player = player,
                isDealer = globalIndex == dealerIndex,
                revealCards = revealedIds.contains(player.id),
                isActiveTurn = globalIndex == activePlayerIndex,
                showdownHand = showdownResults[player.id]?.category?.displayName,
                primaryHighlighted = primary,
                secondaryHighlighted = secondary,
                compact = opponents.size >= 4,
            )
            banners[player.id]?.let { banner ->
                ActionBannerLabel(
                    text = banner,
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .offset(y = (-18).dp),
                )
            }
        }
    }
}
