extends Node

signal phase_changed(new_phase: int) # BattlePhase
signal unit_action_changed(action: int) # UnitAction
signal round_started
signal round_ended
signal battle_ended
signal state_changed

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

enum BattleState {SETUP, ROUND, CLEANUP}

var current_state: BattleState = BattleState.SETUP
var current_phase: GameEnums.BattlePhase = GameEnums.BattlePhase.INITIATIVE
var current_unit_action: GameEnums.UnitAction = GameEnums.UnitAction.NONE

# ... rest of the file remains unchanged ... 