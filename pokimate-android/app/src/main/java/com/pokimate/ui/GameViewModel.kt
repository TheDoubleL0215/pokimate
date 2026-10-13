package com.pokimate.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.pokimate.engine.PokerGameEngine
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn

data class GameUiSnapshot(
    val state: PokerGameEngine.UiState = PokerGameEngine.UiState(),
    val isHumanTurn: Boolean = false,
    val callLabel: String = "Check",
    val toCallAmount: Int = 0,
)

/**
 * Collects [PokerGameEngine.uiState] and derived turn/call labels for Compose.
 */
class GameViewModel(
    humanName: String,
    aiCount: Int,
    startingChips: Int,
    baseBet: Int,
    blindsEnabled: Boolean,
) : ViewModel() {

    private val engine = PokerGameEngine(
        humanName = humanName,
        aiCount = aiCount,
        startingChips = startingChips,
        baseBet = baseBet,
        blindsEnabled = blindsEnabled,
        scope = viewModelScope,
    )

    val snapshot: StateFlow<GameUiSnapshot> = engine.uiState
        .map { state ->
            GameUiSnapshot(
                state = state,
                isHumanTurn = engine.isHumanTurn,
                callLabel = engine.callLabel,
                toCallAmount = engine.toCallAmount,
            )
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), GameUiSnapshot())

    fun startHand() = engine.startHand()
    fun fold() = engine.fold()
    fun checkOrCall() = engine.checkOrCall()
    fun raise() = engine.raise()
    fun continueToNextHand() = engine.continueToNextHand()
    fun exit() = engine.tearDown()

    override fun onCleared() {
        engine.tearDown()
        super.onCleared()
    }

    class Factory(
        private val humanName: String,
        private val aiCount: Int,
        private val startingChips: Int,
        private val baseBet: Int,
        private val blindsEnabled: Boolean,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            return GameViewModel(
                humanName = humanName,
                aiCount = aiCount,
                startingChips = startingChips,
                baseBet = baseBet,
                blindsEnabled = blindsEnabled,
            ) as T
        }
    }
}
