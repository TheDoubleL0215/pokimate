package com.pokimate.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pokimate.ui.theme.PokerBrandBlue
import com.pokimate.ui.theme.PokerCardStroke
import com.pokimate.ui.theme.PokerFoldFill
import com.pokimate.ui.theme.PokerSurface
import com.pokimate.ui.theme.PokerTextPrimary
import com.pokimate.ui.theme.PokerTextSecondary
import com.pokimate.ui.theme.PokimateFontFamily

@Composable
fun GameCapsuleButton(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    fill: Color = PokerFoldFill,
    text: Color = PokerBrandBlue,
    enabled: Boolean = true,
    compact: Boolean = false,
) {
    val shape = RoundedCornerShape(percent = 50)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(fill)
            .border(1.dp, (if (enabled) text else PokerTextSecondary).copy(alpha = 0.25f), shape)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(vertical = if (compact) 12.dp else 16.dp, horizontal = 6.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = title,
            color = if (enabled) text else PokerTextSecondary,
            fontFamily = PokimateFontFamily,
            fontWeight = FontWeight.ExtraBold,
            fontSize = if (compact) 14.sp else 16.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
fun GameCapsuleChip(
    title: String,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(percent = 50)
    Box(
        modifier = modifier
            .clip(shape)
            .background(PokerFoldFill)
            .border(
                width = if (isSelected) 1.5.dp else 1.dp,
                color = if (isSelected) PokerBrandBlue.copy(alpha = 0.45f) else PokerCardStroke,
                shape = shape,
            )
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp, horizontal = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = title,
            color = if (isSelected) PokerBrandBlue else PokerTextPrimary,
            fontFamily = PokimateFontFamily,
            fontWeight = FontWeight.ExtraBold,
            fontSize = 14.sp,
        )
    }
}

@Composable
fun MenuPanel(
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues = PaddingValues(20.dp),
    content: @Composable () -> Unit,
) {
    val shape = RoundedCornerShape(20.dp)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(PokerSurface)
            .border(1.dp, PokerCardStroke, shape)
            .padding(contentPadding),
    ) {
        content()
    }
}

@Composable
fun GlassIconButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    size: Dp = 40.dp,
    content: @Composable () -> Unit,
) {
    Box(
        modifier = modifier
            .clip(CircleShape)
            .background(PokerFoldFill)
            .border(1.dp, PokerCardStroke, CircleShape)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            )
            .padding(8.dp),
        contentAlignment = Alignment.Center,
    ) {
        content()
    }
}
