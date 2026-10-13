package com.pokimate.ui.screens

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.pokimate.R
import com.pokimate.ui.components.GameCapsuleButton
import com.pokimate.ui.components.GlassIconButton
import com.pokimate.ui.theme.PokerBackground
import com.pokimate.ui.theme.PokerBrandBlue
import com.pokimate.ui.theme.PokerFoldFill
import com.pokimate.ui.theme.PokerTableFelt
import com.pokimate.ui.theme.PokerTextPrimary

@Composable
fun MainMenuScreen(
    onNewGame: () -> Unit,
    onStats: () -> Unit,
    onSettings: () -> Unit,
) {
    var appeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { appeared = true }
    val scale by animateFloatAsState(
        targetValue = if (appeared) 1f else 0.92f,
        animationSpec = spring(dampingRatio = 0.78f, stiffness = 180f),
        label = "logoScale",
    )
    val alpha by animateFloatAsState(
        targetValue = if (appeared) 1f else 0f,
        label = "logoAlpha",
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(PokerBackground, PokerTableFelt.copy(alpha = 0.35f), PokerBackground),
                ),
            )
            .statusBarsPadding(),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 12.dp, end = 12.dp),
            horizontalArrangement = Arrangement.End,
        ) {
            GlassIconButton(onClick = onSettings) {
                Icon(
                    imageVector = Icons.Filled.Settings,
                    contentDescription = stringResource(R.string.a11y_settings),
                    tint = PokerTextPrimary,
                )
            }
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 28.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.weight(1f))
            Image(
                painter = painterResource(R.drawable.pokimate_header_nobg),
                contentDescription = stringResource(R.string.app_name),
                contentScale = ContentScale.Fit,
                modifier = Modifier
                    .fillMaxWidth(0.85f)
                    .scale(scale)
                    .alpha(alpha),
            )
            Spacer(Modifier.weight(1f))
            GameCapsuleButton(
                title = stringResource(R.string.menu_new_game),
                onClick = onNewGame,
            )
            Spacer(Modifier.height(12.dp))
            GameCapsuleButton(
                title = stringResource(R.string.menu_stats),
                onClick = onStats,
                fill = PokerFoldFill,
                text = PokerTextPrimary,
            )
            Spacer(Modifier.height(44.dp))
        }
    }
}
