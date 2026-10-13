package com.pokimate.ui.theme

import android.app.Activity
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val PokimateDarkColors = darkColorScheme(
    primary = PokerBrandBlue,
    onPrimary = Color.White,
    secondary = PokerTurnGlow,
    onSecondary = Color.White,
    background = PokerBackground,
    onBackground = PokerTextPrimary,
    surface = PokerSurface,
    onSurface = PokerTextPrimary,
    surfaceVariant = PokerFoldFill,
    onSurfaceVariant = PokerTextSecondary,
    outline = PokerCardStroke,
    error = PokerFoldText,
)

@Composable
fun PokimateTheme(content: @Composable () -> Unit) {
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = PokerBackground.toArgb()
            window.navigationBarColor = PokerBackground.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = false
        }
    }

    MaterialTheme(
        colorScheme = PokimateDarkColors,
        typography = PokimateTypography,
        content = content,
    )
}
