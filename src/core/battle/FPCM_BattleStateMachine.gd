class_name FPCM_BattleStateMachine
extends Node

## FPCM_BattleStateMachine - Battle state machine for Five Parsecs
## Manages battle phases and state transitions

signal battle_started()
signal battle_ended(results: Dictionary)
signal state_changed(new_state: int)
signal phase_changed(new_phase: int)
signal round_started(round_number: int)

enum BattlePhase {
	SETUP,
	QUICK_ACTIONS,
	ENEMY_ACTIONS,
	SLOW_ACTIONS,
	END_PHASE
}

enum BattleState {
	IDLE,
	IN_PROGRESS,
	PAUSED,
	COMPLETED
}

var current_phase: int = BattlePhase.SETUP
var current_state: int = BattleState.IDLE
var current_round: int = 0

func start_battle(battle_data: Dictionary = {}) -> bool:
	current_state = BattleState.IN_PROGRESS
	current_phase = BattlePhase.SETUP
	current_round = 1
	state_changed.emit(current_state)
	battle_started.emit()
	round_started.emit(current_round)
	return true

func end_battle(results: Variant = {}) -> void:
	current_state = BattleState.COMPLETED
	state_changed.emit(current_state)
	var result_dict: Dictionary = results if results is Dictionary else {"outcome": results}
	battle_ended.emit(result_dict)

func advance_phase() -> void:
	match current_phase:
		BattlePhase.SETUP:
			current_phase = BattlePhase.QUICK_ACTIONS
		BattlePhase.QUICK_ACTIONS:
			current_phase = BattlePhase.ENEMY_ACTIONS
		BattlePhase.ENEMY_ACTIONS:
			current_phase = BattlePhase.SLOW_ACTIONS
		BattlePhase.SLOW_ACTIONS:
			current_phase = BattlePhase.END_PHASE
		BattlePhase.END_PHASE:
			current_round += 1
			current_phase = BattlePhase.QUICK_ACTIONS
			round_started.emit(current_round)
	phase_changed.emit(current_phase)
