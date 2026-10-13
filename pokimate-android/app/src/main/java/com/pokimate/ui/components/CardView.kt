package com.pokimate.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pokimate.model.Card
import com.pokimate.ui.theme.PokerCardBack
import com.pokimate.ui.theme.PokerCardFace
import com.pokimate.ui.theme.PokerCardStroke
import com.pokimate.ui.theme.PokerCardText
import com.pokimate.ui.theme.PokerCardTextRed
import com.pokimate.ui.theme.PokerWinningCardStroke
import com.pokimate.ui.theme.PokerWinningCardStrokeSoft
import com.pokimate.ui.theme.PokimateFontFamily

enum class CardHighlightStyle {
    None,
    Soft,
    Strong,
}

@Composable
fun CardView(
    card: Card?,
    modifier: Modifier = Modifier,
    faceDown: Boolean = false,
    compact: Boolean = false,
    highlight: CardHighlightStyle = CardHighlightStyle.None,
) {
    val width: Dp = if (compact) 42.dp else 58.dp
    val height: Dp = if (compact) 60.dp else 82.dp
    val isFaceDown = faceDown || card == null
    val shape = RoundedCornerShape(8.dp)

    val stroke = when (highlight) {
        CardHighlightStyle.None -> PokerCardStroke
        CardHighlightStyle.Soft -> PokerWinningCardStrokeSoft
        CardHighlightStyle.Strong -> PokerWinningCardStroke
    }
    val strokeWidth = when (highlight) {
        CardHighlightStyle.None -> 1.dp
        CardHighlightStyle.Soft -> 1.5.dp
        CardHighlightStyle.Strong -> 2.75.dp
    }
    val flip by animateFloatAsState(
        targetValue = if (isFaceDown) 180f else 0f,
        animationSpec = tween(450),
        label = "cardFlip",
    )

    Box(
        modifier = modifier
            .size(width, height)
            .shadow(3.dp, shape)
            .graphicsLayer {
                rotationY = flip
                cameraDistance = 12f * density
            }
            .clip(shape)
            .background(if (flip < 90f) PokerCardFace else PokerCardBack)
            .border(strokeWidth, stroke, shape),
    ) {
        if (flip < 90f && card != null) {
            val color = if (card.suit.isRed) PokerCardTextRed else PokerCardText
            Column(
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(4.dp),
            ) {
                Text(
                    text = card.rank.display,
                    color = color,
                    fontFamily = PokimateFontFamily,
                    fontWeight = FontWeight.Bold,
                    fontSize = if (compact) 16.sp else 20.sp,
                    lineHeight = if (compact) 16.sp else 20.sp,
                )
                Text(
                    text = card.suit.symbol,
                    color = color,
                    fontSize = if (compact) 14.sp else 17.sp,
                    lineHeight = if (compact) 14.sp else 17.sp,
                )
            }
            Text(
                text = card.suit.symbol,
                color = color.copy(alpha = 0.1f),
                fontSize = if (compact) 36.sp else 48.sp,
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .offset(x = 6.dp, y = 8.dp),
            )
        } else {
            Text(
                text = "♠",
                color = Color.White.copy(alpha = 0.2f),
                fontSize = if (compact) 12.sp else 16.sp,
                modifier = Modifier.align(Alignment.Center),
            )
        }
    }
}

fun cardHighlightFor(
    cardId: java.util.UUID,
    primary: Set<java.util.UUID>,
    secondary: Set<java.util.UUID>,
): CardHighlightStyle = when {
    primary.contains(cardId) -> CardHighlightStyle.Strong
    secondary.contains(cardId) -> CardHighlightStyle.Soft
    else -> CardHighlightStyle.None
}
