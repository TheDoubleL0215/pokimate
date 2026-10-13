package com.pokimate.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pokimate.R
import com.pokimate.model.Card
import com.pokimate.ui.theme.PokerBrandBlue
import com.pokimate.ui.theme.PokerCallFill
import com.pokimate.ui.theme.PokerCallText
import com.pokimate.ui.theme.PokerCardStroke
import com.pokimate.ui.theme.PokerFoldFill
import com.pokimate.ui.theme.PokerFoldText
import com.pokimate.ui.theme.PokerRaiseFill
import com.pokimate.ui.theme.PokerRaiseText
import com.pokimate.ui.theme.PokerSurface
import com.pokimate.ui.theme.PokerTextPrimary
import com.pokimate.ui.theme.PokerWinningCardStroke
import com.pokimate.ui.theme.PokimateFontFamily
import java.util.UUID
import kotlinx.coroutines.delay

@Composable
fun ActionBar(
    holeCards: List<Card>,
    balance: Int,
    isEnabled: Boolean,
    callLabel: String,
    toCallAmount: Int,
    showContinue: Boolean,
    onFold: () -> Unit,
    onCheckOrCall: () -> Unit,
    onRaise: () -> Unit,
    onContinue: () -> Unit,
    modifier: Modifier = Modifier,
    primaryHighlighted: Set<UUID> = emptySet(),
    secondaryHighlighted: Set<UUID> = emptySet(),
    winStreak: Int = 0,
) {
    val shape = RoundedCornerShape(20.dp)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(200.dp)
            .clip(shape)
            .background(PokerSurface)
            .border(1.dp, PokerCardStroke, shape)
            .padding(horizontal = 16.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(
            modifier = Modifier.weight(1f),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            if (winStreak > 0) {
                Text(
                    text = "🔥 $winStreak",
                    color = Color(0xFFF0953A),
                    fontFamily = PokimateFontFamily,
                    fontWeight = FontWeight.Bold,
                    fontSize = 12.sp,
                )
            }
            Box(contentAlignment = Alignment.Center) {
                if (holeCards.isNotEmpty()) {
                    CardView(
                        card = holeCards.getOrNull(0),
                        highlight = holeCards.getOrNull(0)?.let {
                            cardHighlightFor(it.id, primaryHighlighted, secondaryHighlighted)
                        } ?: CardHighlightStyle.None,
                        modifier = Modifier.padding(end = 28.dp),
                    )
                } else {
                    CardView(card = null, faceDown = true, modifier = Modifier.padding(end = 28.dp))
                }
                if (holeCards.size > 1) {
                    CardView(
                        card = holeCards[1],
                        highlight = cardHighlightFor(
                            holeCards[1].id,
                            primaryHighlighted,
                            secondaryHighlighted,
                        ),
                        modifier = Modifier.padding(start = 28.dp),
                    )
                } else {
                    CardView(card = null, faceDown = true, modifier = Modifier.padding(start = 28.dp))
                }
            }
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text("◉", color = PokerBrandBlue, fontSize = 16.sp)
                Text(
                    text = "$balance",
                    color = PokerTextPrimary,
                    fontFamily = PokimateFontFamily,
                    fontWeight = FontWeight.Bold,
                    fontSize = 17.sp,
                )
            }
        }

        if (showContinue) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight(),
                contentAlignment = Alignment.Center,
            ) {
                GameCapsuleButton(
                    title = stringResource(R.string.action_continue),
                    onClick = onContinue,
                    text = PokerWinningCardStroke,
                )
            }
        } else {
            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight(),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                HoldConfirmButton(
                    title = stringResource(R.string.action_fold),
                    fill = PokerFoldFill,
                    text = PokerFoldText,
                    progressFill = PokerFoldText.copy(alpha = 0.35f),
                    enabled = isEnabled,
                    onConfirm = onFold,
                    modifier = Modifier.weight(1f),
                )
                HoldConfirmButton(
                    title = stringResource(R.string.action_raise),
                    fill = PokerRaiseFill,
                    text = PokerRaiseText,
                    progressFill = PokerRaiseText.copy(alpha = 0.35f),
                    enabled = isEnabled,
                    onConfirm = onRaise,
                    modifier = Modifier.weight(1f),
                    leading = {
                        Icon(
                            imageVector = Icons.Filled.KeyboardArrowUp,
                            contentDescription = null,
                            tint = PokerRaiseText,
                        )
                    },
                )
                DoubleTapConfirmButton(
                    callLabel = callLabel,
                    toCallAmount = toCallAmount,
                    enabled = isEnabled,
                    onConfirm = onCheckOrCall,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

@Composable
private fun HoldConfirmButton(
    title: String,
    fill: Color,
    text: Color,
    progressFill: Color,
    enabled: Boolean,
    onConfirm: () -> Unit,
    modifier: Modifier = Modifier,
    leading: (@Composable () -> Unit)? = null,
) {
    var progress by remember { mutableFloatStateOf(0f) }
    var holding by remember { mutableStateOf(false) }
    var widthPx by remember { mutableFloatStateOf(0f) }
    val density = LocalDensity.current

    LaunchedEffect(holding) {
        if (holding && enabled) {
            progress = 0f
            val steps = 16
            repeat(steps) {
                delay(50)
                progress = (it + 1) / steps.toFloat()
            }
            progress = 0f
            holding = false
            onConfirm()
        } else {
            progress = 0f
        }
    }

    val shape = RoundedCornerShape(percent = 50)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .onSizeChanged { widthPx = it.width.toFloat() }
            .clip(shape)
            .background(fill)
            .then(
                if (progress > 0f) {
                    Modifier.border(0.dp, Color.Transparent, shape)
                } else {
                    Modifier
                },
            )
            .pointerInput(enabled) {
                detectTapGestures(
                    onPress = {
                        if (!enabled) return@detectTapGestures
                        holding = true
                        tryAwaitRelease()
                        holding = false
                        progress = 0f
                    },
                )
            }
            .border(1.dp, text.copy(alpha = 0.25f), shape),
        contentAlignment = Alignment.CenterStart,
    ) {
        if (progress > 0f && widthPx > 0f) {
            Box(
                modifier = Modifier
                    .fillMaxHeight()
                    .width(with(density) { (widthPx * progress).toDp() })
                    .background(progressFill),
            )
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 6.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            leading?.invoke()
            if (leading != null) Spacer(Modifier.width(4.dp))
            Text(
                text = title,
                color = text,
                fontFamily = PokimateFontFamily,
                fontWeight = FontWeight.ExtraBold,
                fontSize = 14.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun DoubleTapConfirmButton(
    callLabel: String,
    toCallAmount: Int,
    enabled: Boolean,
    onConfirm: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var armed by remember(callLabel) { mutableStateOf(false) }
    val isCheck = toCallAmount <= 0
    val shape = RoundedCornerShape(percent = 50)
    val confirmWord = stringResource(R.string.action_confirm)
    val callWord = stringResource(R.string.action_call_short)

    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(PokerCallFill)
            .border(
                width = if (armed) 1.5.dp else 1.dp,
                color = PokerCallText.copy(alpha = if (armed) 0.55f else 0.25f),
                shape = shape,
            )
            .clickable(enabled = enabled) {
                if (armed) {
                    armed = false
                    onConfirm()
                } else {
                    armed = true
                }
            }
            .padding(horizontal = 6.dp),
        contentAlignment = Alignment.Center,
    ) {
        if (armed) {
            Box(
                Modifier
                    .matchParentSize()
                    .background(PokerCallText.copy(alpha = 0.28f)),
            )
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            if (isCheck) {
                Icon(
                    imageVector = Icons.Filled.TouchApp,
                    contentDescription = null,
                    tint = PokerCallText,
                    modifier = Modifier.padding(end = 4.dp),
                )
                Text(
                    text = if (armed) {
                        stringResource(R.string.action_confirm_fmt, callLabel.uppercase())
                    } else {
                        callLabel.uppercase()
                    },
                    color = PokerCallText,
                    fontFamily = PokimateFontFamily,
                    fontWeight = FontWeight.ExtraBold,
                    fontSize = 14.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            } else {
                if (armed) {
                    Text(
                        text = confirmWord,
                        color = PokerCallText,
                        fontFamily = PokimateFontFamily,
                        fontWeight = FontWeight.ExtraBold,
                        fontSize = 13.sp,
                        modifier = Modifier.padding(end = 4.dp),
                    )
                }
                Text(
                    text = "$ $toCallAmount $callWord",
                    color = PokerCallText,
                    fontFamily = PokimateFontFamily,
                    fontWeight = FontWeight.ExtraBold,
                    fontSize = 14.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}
