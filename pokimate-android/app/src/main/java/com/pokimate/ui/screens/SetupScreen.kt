package com.pokimate.ui.screens

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pokimate.R
import com.pokimate.ui.components.GameCapsuleButton
import com.pokimate.ui.components.GameCapsuleChip
import com.pokimate.ui.components.GlassIconButton
import com.pokimate.ui.components.MenuPanel
import com.pokimate.ui.theme.PokerBackground
import com.pokimate.ui.theme.PokerBrandBlue
import com.pokimate.ui.theme.PokerCardStroke
import com.pokimate.ui.theme.PokerFoldFill
import com.pokimate.ui.theme.PokerFoldText
import com.pokimate.ui.theme.PokerTableFelt
import com.pokimate.ui.theme.PokerTextPrimary
import com.pokimate.ui.theme.PokerTextSecondary
import com.pokimate.ui.theme.PokimateFontFamily

@Composable
fun SetupScreen(
    onBack: () -> Unit,
    onSitDown: (startingChips: Int, baseBet: Int, useBlinds: Boolean, botCount: Int) -> Unit,
) {
    val betOptions = listOf(20, 40, 100, 200)
    val chipOptions = listOf(200, 500, 1_000, 2_000, 5_000)
    val botOptions = listOf(2, 3, 4, 5)

    var baseBet by remember { mutableIntStateOf(20) }
    var startingChips by remember { mutableIntStateOf(500) }
    var useBlinds by remember { mutableStateOf(true) }
    var botCount by remember { mutableIntStateOf(2) }
    var appeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { appeared = true }

    val alpha by animateFloatAsState(if (appeared) 1f else 0f, label = "setupAlpha")
    val scale by animateFloatAsState(
        if (appeared) 1f else 0.94f,
        animationSpec = spring(dampingRatio = 0.84f),
        label = "setupScale",
    )

    val canStart = startingChips >= baseBet * 4
    val smallBlind = baseBet / 2

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
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                GlassIconButton(onClick = onBack) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = stringResource(R.string.a11y_back),
                        tint = PokerTextPrimary,
                    )
                }
            }

            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp)
                    .alpha(alpha)
                    .scale(scale),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Image(
                    painter = painterResource(R.drawable.pokimate_header_nobg),
                    contentDescription = null,
                    contentScale = ContentScale.Fit,
                    modifier = Modifier
                        .fillMaxWidth(0.55f)
                        .padding(top = 8.dp, bottom = 16.dp),
                )

                MenuPanel {
                    Column(verticalArrangement = Arrangement.spacedBy(22.dp)) {
                        SettingSection(
                            title = stringResource(R.string.setup_base_bet),
                            subtitle = if (useBlinds) {
                                stringResource(R.string.setup_blinds_sb_bb, smallBlind, baseBet)
                            } else {
                                stringResource(R.string.setup_raise_unit, baseBet)
                            },
                        ) {
                            SteppedSelector(
                                value = baseBet,
                                options = betOptions,
                                onChange = { baseBet = it },
                            )
                        }
                        DividerLine()
                        SettingSection(
                            title = stringResource(R.string.setup_starting_chips),
                            subtitle = stringResource(R.string.setup_starting_chips_subtitle, startingChips),
                        ) {
                            SteppedSelector(
                                value = startingChips,
                                options = chipOptions,
                                onChange = { startingChips = it },
                            )
                        }
                        DividerLine()
                        SettingSection(
                            title = stringResource(R.string.setup_bots),
                            subtitle = stringResource(R.string.setup_bots_subtitle, botCount),
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                botOptions.forEach { value ->
                                    GameCapsuleChip(
                                        title = "$value",
                                        isSelected = botCount == value,
                                        onClick = { botCount = value },
                                        modifier = Modifier.weight(1f),
                                    )
                                }
                            }
                        }
                        DividerLine()
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(Modifier.weight(1f)) {
                                Text(
                                    text = stringResource(R.string.setup_blinds).uppercase(),
                                    color = PokerTextSecondary,
                                    fontFamily = PokimateFontFamily,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 12.sp,
                                    letterSpacing = 1.2.sp,
                                )
                                Spacer(Modifier.height(4.dp))
                                Text(
                                    text = stringResource(
                                        if (useBlinds) R.string.setup_blinds_on
                                        else R.string.setup_blinds_off,
                                    ),
                                    color = PokerTextSecondary,
                                    fontFamily = PokimateFontFamily,
                                    fontWeight = FontWeight.Medium,
                                    fontSize = 12.sp,
                                )
                            }
                            Switch(
                                checked = useBlinds,
                                onCheckedChange = { useBlinds = it },
                                colors = SwitchDefaults.colors(
                                    checkedThumbColor = PokerBrandBlue,
                                    checkedTrackColor = PokerBrandBlue.copy(alpha = 0.35f),
                                    uncheckedThumbColor = PokerTextSecondary,
                                    uncheckedTrackColor = PokerFoldFill,
                                ),
                            )
                        }
                        if (!canStart) {
                            Text(
                                text = stringResource(R.string.setup_chips_rule),
                                color = PokerFoldText,
                                fontFamily = PokimateFontFamily,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 12.sp,
                            )
                        }
                    }
                }

                Spacer(Modifier.height(20.dp))
                GameCapsuleButton(
                    title = stringResource(R.string.setup_sit_down),
                    onClick = { onSitDown(startingChips, baseBet, useBlinds, botCount) },
                    enabled = canStart,
                    modifier = Modifier.padding(horizontal = 8.dp),
                )
                Spacer(Modifier.height(36.dp))
            }
        }
    }
}

@Composable
private fun SettingSection(
    title: String,
    subtitle: String,
    content: @Composable () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            text = title.uppercase(),
            color = PokerTextSecondary,
            fontFamily = PokimateFontFamily,
            fontWeight = FontWeight.Bold,
            fontSize = 12.sp,
            letterSpacing = 1.2.sp,
        )
        content()
        Text(
            text = subtitle,
            color = PokerTextSecondary,
            fontFamily = PokimateFontFamily,
            fontWeight = FontWeight.Medium,
            fontSize = 12.sp,
        )
    }
}

@Composable
private fun SteppedSelector(
    value: Int,
    options: List<Int>,
    onChange: (Int) -> Unit,
) {
    val index = options.indexOf(value).coerceAtLeast(0)
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        CircleStepButton(enabled = index > 0, onClick = { onChange(options[index - 1]) }) {
            Icon(Icons.Filled.ChevronLeft, null, tint = PokerTextPrimary)
        }
        Text(
            text = "$value",
            color = PokerTextPrimary,
            fontFamily = PokimateFontFamily,
            fontWeight = FontWeight.ExtraBold,
            fontSize = 22.sp,
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(14.dp))
                .background(PokerFoldFill)
                .border(1.dp, PokerCardStroke, RoundedCornerShape(14.dp))
                .padding(vertical = 14.dp),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
        CircleStepButton(enabled = index < options.lastIndex, onClick = { onChange(options[index + 1]) }) {
            Icon(Icons.Filled.ChevronRight, null, tint = PokerTextPrimary)
        }
    }
}

@Composable
private fun CircleStepButton(
    enabled: Boolean,
    onClick: () -> Unit,
    content: @Composable () -> Unit,
) {
    Box(
        modifier = Modifier
            .size(44.dp)
            .clip(CircleShape)
            .background(PokerFoldFill)
            .border(1.dp, PokerCardStroke, CircleShape)
            .alpha(if (enabled) 1f else 0.4f)
            .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        content()
    }
}

@Composable
private fun DividerLine() {
    Box(
        Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(PokerCardStroke),
    )
}
