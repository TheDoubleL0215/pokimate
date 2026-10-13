package com.pokimate.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pokimate.R
import com.pokimate.model.Card
import com.pokimate.model.Player
import com.pokimate.ui.theme.PokerBrandBlue
import com.pokimate.ui.theme.PokerCallText
import com.pokimate.ui.theme.PokerCardStroke
import com.pokimate.ui.theme.PokerFoldFill
import com.pokimate.ui.theme.PokerRaiseFill
import com.pokimate.ui.theme.PokerRaiseText
import com.pokimate.ui.theme.PokerSurface
import com.pokimate.ui.theme.PokerTextPrimary
import com.pokimate.ui.theme.PokerTextSecondary
import com.pokimate.ui.theme.PokerTurnGlow
import com.pokimate.ui.theme.PokimateFontFamily
import java.util.UUID

@Composable
fun PlayerSeat(
    player: Player,
    isDealer: Boolean,
    revealCards: Boolean,
    isActiveTurn: Boolean,
    modifier: Modifier = Modifier,
    showdownHand: String? = null,
    primaryHighlighted: Set<UUID> = emptySet(),
    secondaryHighlighted: Set<UUID> = emptySet(),
    compact: Boolean = true,
) {
    val shape = RoundedCornerShape(if (compact) 10.dp else 12.dp)
    Box(modifier = modifier) {
        Column(
            modifier = Modifier
                .shadow(6.dp, shape)
                .clip(shape)
                .background(PokerSurface)
                .border(
                    width = if (isActiveTurn) 2.5.dp else 1.dp,
                    color = if (isActiveTurn) PokerTurnGlow.copy(alpha = 0.95f) else PokerCardStroke,
                    shape = shape,
                )
                .padding(if (compact) 6.dp else 10.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(if (compact) 4.dp else 6.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                if (isDealer) {
                    Text(
                        text = "D",
                        color = androidx.compose.ui.graphics.Color.White,
                        fontFamily = PokimateFontFamily,
                        fontWeight = FontWeight.ExtraBold,
                        fontSize = 9.sp,
                        modifier = Modifier
                            .clip(RoundedCornerShape(percent = 50))
                            .background(PokerBrandBlue)
                            .padding(horizontal = 6.dp, vertical = 2.dp),
                    )
                }
                Text(
                    text = player.name,
                    color = PokerTextPrimary,
                    fontFamily = PokimateFontFamily,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = if (compact) 11.sp else 12.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            when {
                player.isFolded -> {
                    Text(
                        text = stringResource(R.string.player_folded),
                        color = PokerTextSecondary,
                        fontFamily = PokimateFontFamily,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 10.sp,
                        modifier = Modifier
                            .clip(RoundedCornerShape(percent = 50))
                            .background(androidx.compose.ui.graphics.Color.White.copy(alpha = 0.06f))
                            .padding(horizontal = 7.dp, vertical = 3.dp),
                    )
                }
                player.holeCards.size == 2 -> {
                    Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                        player.holeCards.forEach { card ->
                            CardView(
                                card = card,
                                faceDown = !revealCards && !player.isHuman,
                                compact = true,
                                highlight = if (revealCards) {
                                    cardHighlightFor(card.id, primaryHighlighted, secondaryHighlighted)
                                } else {
                                    CardHighlightStyle.None
                                },
                            )
                        }
                    }
                }
                else -> {
                    Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                        CardView(card = null, faceDown = true, compact = true, modifier = Modifier)
                        CardView(card = null, faceDown = true, compact = true)
                    }
                }
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = "◉",
                    color = PokerBrandBlue,
                    fontSize = if (compact) 12.sp else 14.sp,
                )
                Text(
                    text = "${player.chips}",
                    color = PokerTurnGlow,
                    fontFamily = PokimateFontFamily,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = if (compact) 12.sp else 13.sp,
                )
            }

            if (showdownHand != null) {
                Text(
                    text = showdownHand,
                    color = PokerRaiseText,
                    fontFamily = PokimateFontFamily,
                    fontWeight = FontWeight.Bold,
                    fontSize = 10.sp,
                    maxLines = 1,
                    modifier = Modifier
                        .clip(RoundedCornerShape(percent = 50))
                        .background(PokerRaiseFill)
                        .border(1.dp, PokerRaiseText.copy(alpha = 0.35f), RoundedCornerShape(percent = 50))
                        .padding(horizontal = 6.dp, vertical = 2.dp),
                )
            }
        }

        if (player.hasCheckedThisRound && !player.isFolded) {
            Icon(
                imageVector = Icons.Filled.TouchApp,
                contentDescription = null,
                tint = PokerCallText,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .offset(x = 6.dp, y = (-6).dp)
                    .size(22.dp)
                    .clip(CircleShape)
                    .background(PokerFoldFill)
                    .border(1.dp, PokerCallText.copy(alpha = 0.35f), CircleShape)
                    .padding(4.dp),
            )
        }
    }
}

@Composable
fun ActionBannerLabel(
    text: String,
    modifier: Modifier = Modifier,
) {
    Text(
        text = text,
        color = PokerTextPrimary,
        fontFamily = PokimateFontFamily,
        fontWeight = FontWeight.ExtraBold,
        fontSize = 11.sp,
        modifier = modifier
            .clip(RoundedCornerShape(percent = 50))
            .background(androidx.compose.ui.graphics.Color.Black.copy(alpha = 0.78f))
            .border(1.dp, androidx.compose.ui.graphics.Color.White.copy(alpha = 0.18f), RoundedCornerShape(percent = 50))
            .padding(horizontal = 8.dp, vertical = 4.dp),
    )
}

@Composable
fun CommunityCardSlot(
    card: Card?,
    highlight: CardHighlightStyle = CardHighlightStyle.None,
    modifier: Modifier = Modifier,
) {
    if (card != null) {
        CardView(card = card, compact = true, highlight = highlight, modifier = modifier)
    } else {
        Box(
            modifier = modifier
                .size(40.dp, 56.dp)
                .border(
                    width = 1.dp,
                    color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.1f),
                    shape = RoundedCornerShape(6.dp),
                ),
        )
    }
}
