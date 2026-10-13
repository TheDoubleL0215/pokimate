package com.pokimate.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pokimate.R
import com.pokimate.ui.AppLanguage
import com.pokimate.ui.applyAppLanguage
import com.pokimate.ui.components.GlassIconButton
import com.pokimate.ui.components.MenuPanel
import com.pokimate.ui.currentAppLanguage
import com.pokimate.ui.theme.PokerBackground
import com.pokimate.ui.theme.PokerBrandBlue
import com.pokimate.ui.theme.PokerCardStroke
import com.pokimate.ui.theme.PokerFoldFill
import com.pokimate.ui.theme.PokerTableFelt
import com.pokimate.ui.theme.PokerTextPrimary
import com.pokimate.ui.theme.PokerTextSecondary
import com.pokimate.ui.theme.PokimateFontFamily

@Composable
fun SettingsScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    var selected by remember { mutableStateOf(currentAppLanguage(context)) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(PokerBackground, PokerTableFelt.copy(alpha = 0.28f), PokerBackground),
                ),
            )
            .statusBarsPadding(),
    ) {
        Column(Modifier.fillMaxSize()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                GlassIconButton(onClick = onBack) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = stringResource(R.string.a11y_back),
                        tint = PokerTextPrimary,
                    )
                }
                Spacer(Modifier.weight(1f))
                Text(
                    text = stringResource(R.string.settings_title),
                    color = PokerTextPrimary,
                    fontFamily = PokimateFontFamily,
                    fontWeight = FontWeight.ExtraBold,
                    fontSize = 20.sp,
                )
                Spacer(Modifier.weight(1f))
                Box(Modifier.padding(8.dp))
            }

            MenuPanel(modifier = Modifier.padding(horizontal = 20.dp, vertical = 20.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    Text(
                        text = stringResource(R.string.settings_language).uppercase(),
                        color = PokerTextSecondary,
                        fontFamily = PokimateFontFamily,
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp,
                        letterSpacing = 1.2.sp,
                    )
                    Text(
                        text = stringResource(R.string.settings_language_subtitle),
                        color = PokerTextSecondary,
                        fontFamily = PokimateFontFamily,
                        fontWeight = FontWeight.Medium,
                        fontSize = 12.sp,
                    )
                    Spacer(Modifier.height(4.dp))
                    LanguageRow(
                        label = stringResource(R.string.settings_lang_system),
                        selected = selected == AppLanguage.System,
                        onClick = {
                            selected = AppLanguage.System
                            applyAppLanguage(context, AppLanguage.System)
                        },
                    )
                    LanguageRow(
                        label = stringResource(R.string.settings_lang_hu),
                        selected = selected == AppLanguage.Hungarian,
                        onClick = {
                            selected = AppLanguage.Hungarian
                            applyAppLanguage(context, AppLanguage.Hungarian)
                        },
                    )
                    LanguageRow(
                        label = stringResource(R.string.settings_lang_en),
                        selected = selected == AppLanguage.English,
                        onClick = {
                            selected = AppLanguage.English
                            applyAppLanguage(context, AppLanguage.English)
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun LanguageRow(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(14.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(PokerFoldFill)
            .border(
                width = if (selected) 1.5.dp else 1.dp,
                color = if (selected) PokerBrandBlue.copy(alpha = 0.45f) else PokerCardStroke,
                shape = shape,
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            color = if (selected) PokerBrandBlue else PokerTextPrimary,
            fontFamily = PokimateFontFamily,
            fontWeight = FontWeight.Bold,
            fontSize = 16.sp,
            modifier = Modifier.weight(1f),
        )
        if (selected) {
            Icon(
                imageVector = Icons.Filled.CheckCircle,
                contentDescription = null,
                tint = PokerBrandBlue,
            )
        }
    }
}
