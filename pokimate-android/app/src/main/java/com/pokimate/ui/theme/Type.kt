package com.pokimate.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/** Distinct geometric sans (not Inter-like) via spacing + weight hierarchy. */
val PokimateFontFamily: FontFamily = FontFamily.SansSerif

val BrandLetterSpacing = 1.1.sp

val PokimateTypography = Typography(
    displayLarge = TextStyle(
        fontFamily = PokimateFontFamily,
        fontWeight = FontWeight.Black,
        fontSize = 40.sp,
        letterSpacing = BrandLetterSpacing,
        color = PokerTextPrimary,
    ),
    headlineLarge = TextStyle(
        fontFamily = PokimateFontFamily,
        fontWeight = FontWeight.ExtraBold,
        fontSize = 28.sp,
        letterSpacing = 0.6.sp,
        color = PokerTextPrimary,
    ),
    headlineMedium = TextStyle(
        fontFamily = PokimateFontFamily,
        fontWeight = FontWeight.Bold,
        fontSize = 22.sp,
        letterSpacing = 0.3.sp,
        color = PokerTextPrimary,
    ),
    titleLarge = TextStyle(
        fontFamily = PokimateFontFamily,
        fontWeight = FontWeight.Bold,
        fontSize = 20.sp,
        letterSpacing = 0.4.sp,
        color = PokerTextPrimary,
    ),
    titleMedium = TextStyle(
        fontFamily = PokimateFontFamily,
        fontWeight = FontWeight.SemiBold,
        fontSize = 16.sp,
        color = PokerTextPrimary,
    ),
    bodyLarge = TextStyle(
        fontFamily = PokimateFontFamily,
        fontWeight = FontWeight.Medium,
        fontSize = 16.sp,
        color = PokerTextPrimary,
    ),
    bodyMedium = TextStyle(
        fontFamily = PokimateFontFamily,
        fontWeight = FontWeight.Medium,
        fontSize = 14.sp,
        color = PokerTextPrimary,
    ),
    labelLarge = TextStyle(
        fontFamily = PokimateFontFamily,
        fontWeight = FontWeight.ExtraBold,
        fontSize = 14.sp,
        letterSpacing = 0.8.sp,
        color = PokerTextPrimary,
    ),
    labelMedium = TextStyle(
        fontFamily = PokimateFontFamily,
        fontWeight = FontWeight.Bold,
        fontSize = 12.sp,
        letterSpacing = 1.4.sp,
        color = PokerTextSecondary,
    ),
    labelSmall = TextStyle(
        fontFamily = PokimateFontFamily,
        fontWeight = FontWeight.SemiBold,
        fontSize = 11.sp,
        letterSpacing = 0.4.sp,
        color = PokerTextSecondary,
    ),
)
