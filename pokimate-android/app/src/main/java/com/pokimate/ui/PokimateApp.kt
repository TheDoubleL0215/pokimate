package com.pokimate.ui

import android.app.LocaleManager
import android.content.Context
import android.os.Build
import android.os.LocaleList
import androidx.appcompat.app.AppCompatDelegate
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.core.os.LocaleListCompat
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.pokimate.ui.screens.GameScreen
import com.pokimate.ui.screens.MainMenuScreen
import com.pokimate.ui.screens.SettingsScreen
import com.pokimate.ui.screens.SetupScreen
import com.pokimate.ui.screens.StatsScreen
import com.pokimate.ui.theme.PokimateTheme
import java.util.Locale

object Routes {
    const val Menu = "menu"
    const val Setup = "setup"
    const val Settings = "settings"
    const val Stats = "stats"
    const val Game = "game/{chips}/{baseBet}/{blinds}/{bots}"

    fun game(chips: Int, baseBet: Int, blinds: Boolean, bots: Int): String =
        "game/$chips/$baseBet/${if (blinds) 1 else 0}/$bots"
}

enum class AppLanguage(val tag: String) {
    System(""),
    English("en"),
    Hungarian("hu"),
}

fun currentAppLanguage(context: Context): AppLanguage {
    val tag = if (Build.VERSION.SDK_INT >= 33) {
        context.getSystemService(LocaleManager::class.java)
            ?.applicationLocales
            ?.toLanguageTags()
            ?.substringBefore(',')
            .orEmpty()
    } else {
        AppCompatDelegate.getApplicationLocales().toLanguageTags().substringBefore(',')
    }
    return when {
        tag.isBlank() -> AppLanguage.System
        tag.startsWith("hu") -> AppLanguage.Hungarian
        else -> AppLanguage.English
    }
}

fun applyAppLanguage(context: Context, language: AppLanguage) {
    if (Build.VERSION.SDK_INT >= 33) {
        val locales = if (language.tag.isEmpty()) {
            LocaleList.getEmptyLocaleList()
        } else {
            LocaleList.forLanguageTags(language.tag)
        }
        context.getSystemService(LocaleManager::class.java)?.applicationLocales = locales
    } else {
        val locales = if (language.tag.isEmpty()) {
            LocaleListCompat.getEmptyLocaleList()
        } else {
            LocaleListCompat.forLanguageTags(language.tag)
        }
        AppCompatDelegate.setApplicationLocales(locales)
    }
    if (language.tag.isNotEmpty()) {
        Locale.setDefault(Locale.forLanguageTag(language.tag))
    }
}

@Composable
fun PokimateApp() {
    PokimateTheme {
        val navController = rememberNavController()
        val context = LocalContext.current
        val youLabel = remember { context.getString(com.pokimate.R.string.player_you) }

        NavHost(navController = navController, startDestination = Routes.Menu) {
            composable(Routes.Menu) {
                MainMenuScreen(
                    onNewGame = { navController.navigate(Routes.Setup) },
                    onStats = { navController.navigate(Routes.Stats) },
                    onSettings = { navController.navigate(Routes.Settings) },
                )
            }
            composable(Routes.Setup) {
                SetupScreen(
                    onBack = { navController.popBackStack() },
                    onSitDown = { chips, baseBet, blinds, bots ->
                        navController.navigate(Routes.game(chips, baseBet, blinds, bots))
                    },
                )
            }
            composable(Routes.Settings) {
                SettingsScreen(onBack = { navController.popBackStack() })
            }
            composable(Routes.Stats) {
                StatsScreen(onBack = { navController.popBackStack() })
            }
            composable(
                route = Routes.Game,
                arguments = listOf(
                    navArgument("chips") { type = NavType.IntType },
                    navArgument("baseBet") { type = NavType.IntType },
                    navArgument("blinds") { type = NavType.IntType },
                    navArgument("bots") { type = NavType.IntType },
                ),
            ) { entry ->
                val chips = entry.arguments?.getInt("chips") ?: 500
                val baseBet = entry.arguments?.getInt("baseBet") ?: 20
                val blinds = (entry.arguments?.getInt("blinds") ?: 1) == 1
                val bots = entry.arguments?.getInt("bots") ?: 2
                GameScreen(
                    humanName = youLabel,
                    startingChips = chips,
                    baseBet = baseBet,
                    blindsEnabled = blinds,
                    botCount = bots,
                    onExitToMenu = {
                        navController.popBackStack(Routes.Menu, inclusive = false)
                    },
                )
            }
        }
    }
}
