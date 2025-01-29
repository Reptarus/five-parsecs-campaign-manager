@tool
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")

signal state_changed(new_state: int)
signal phase_changed(new_phase: int)
signal round_started(round_number: int)
signal round_ended(round_number: int)
signal unit_action_changed(action: int)
signal unit_action_completed(unit: Character, action: int)
signal battle_started
signal battle_ended(victory: bool)
signal attack_resolved(attacker: Character, target: Character, result: Dictionary)
signal reaction_opportunity(unit: Character, reaction_type: String, source: Character)
signal combat_effect_triggered(effect_name: String, source: Character, target: Character)

var game_state_manager: GameStateManager = null

var current_state: int = GameEnums.BattleState.SETUP
var current_phase: int = GameEnums.CombatPhase.NONE
var current_round: int = 1
var is_battle_active: bool = false
var active_combatants: Array[Character] = []
var current_unit_action: int = GameEnums.UnitAction.NONE

# Track unit actions
var _completed_actions: Dictionary = {}
var _reaction_opportunities: Array[Dictionary] = []
var _current_unit: Character = null

func _init(p_game_state_manager: GameStateManager = null) -> void:
	game_state_manager = p_game_state_manager
	if p_game_state_manager and not game_state_manager:
		push_warning("BattleStateMachine initialized without GameStateManager")

func start_battle() -> void:
	current_state = GameEnums.BattleState.SETUP
	current_round = 1
	is_battle_active = true
	_completed_actions.clear()
	battle_started.emit()
	transition_to(GameEnums.BattleState.ROUND)

func end_battle(victory_type: int) -> void:
	is_battle_active = false
	battle_ended.emit(victory_type == GameEnums.VictoryConditionType.ELIMINATION)

func start_unit_action(unit: Character, action: int) -> void:
	_current_unit = unit
	current_unit_action = action
	unit_action_changed.emit(action)

func complete_unit_action() -> void:
	if _current_unit and current_unit_action != GameEnums.UnitAction.NONE:
		unit_action_completed.emit(_current_unit, current_unit_action)
		if not _completed_actions.has(_current_unit):
			_completed_actions[_current_unit] = []
		_completed_actions[_current_unit].append(current_unit_action)
		current_unit_action = GameEnums.UnitAction.NONE
		_current_unit = null

func has_unit_completed_action(unit: Character, action: int) -> bool:
	return _completed_actions.has(unit) and action in _completed_actions[unit]

func get_available_actions(unit: Character) -> Array[int]:
	var available: Array[int] = []
	for action in GameEnums.UnitAction.values():
		if not has_unit_completed_action(unit, action):
			available.append(action)
	return available

func transition_to(new_state: int) -> void:
	if new_state == current_state:
		return
		
	match new_state:
		GameEnums.BattleState.SETUP:
			await _handle_setup_state()
		GameEnums.BattleState.ROUND:
			await _handle_round_state()
		GameEnums.BattleState.CLEANUP:
			await _handle_cleanup_state()
	
	current_state = new_state
	state_changed.emit(new_state)

func transition_to_phase(new_phase: int) -> void:
	if new_phase == current_phase:
		return
		
	match new_phase:
		GameEnums.CombatPhase.INITIATIVE:
			await _handle_initiative_phase()
		GameEnums.CombatPhase.DEPLOYMENT:
			await _handle_deployment_phase()
		GameEnums.CombatPhase.ACTION:
			await _handle_action_phase()
		GameEnums.CombatPhase.REACTION:
			await _handle_reaction_phase()
		GameEnums.CombatPhase.END:
			await _handle_end_phase()
	
	current_phase = new_phase
	phase_changed.emit(new_phase)

func add_combatant(character: Character) -> void:
	if not character in active_combatants:
		active_combatants.append(character)

func resolve_attack(attacker: Character, target: Character) -> void:
	# Implement attack resolution logic
	var result: Dictionary = {} # Add actual combat resolution logic
	attack_resolved.emit(attacker, target, result)

func trigger_reaction(unit: Character, reaction_type: String, source: Character) -> void:
	reaction_opportunity.emit(unit, reaction_type, source)

func apply_combat_effect(effect_name: String, source: Character, target: Character) -> void:
	combat_effect_triggered.emit(effect_name, source, target)

func save_state() -> Dictionary:
	return {
		"current_state": current_state,
		"current_phase": current_phase,
		"current_round": current_round,
		"is_battle_active": is_battle_active,
		"completed_actions": _completed_actions,
		"reaction_opportunities": _reaction_opportunities
	}

func load_state(state: Dictionary) -> void:
	current_state = state.get("current_state", GameEnums.BattleState.SETUP)
	current_phase = state.get("current_phase", GameEnums.CombatPhase.NONE)
	current_round = state.get("current_round", 1)
	is_battle_active = state.get("is_battle_active", false)
	_completed_actions = state.get("completed_actions", {})
	_reaction_opportunities = state.get("reaction_opportunities", [])

func advance_phase() -> void:
	var next_phase: int = current_phase + 1
	if next_phase >= GameEnums.CombatPhase.size():
		next_phase = GameEnums.CombatPhase.NONE
	transition_to_phase(next_phase)

# Private helper functions
func _handle_setup_state() -> void:
	_completed_actions.clear()
	_reaction_opportunities.clear()
	current_phase = GameEnums.CombatPhase.NONE

func _handle_round_state() -> void:
	round_started.emit(current_round)
	await transition_to_phase(GameEnums.CombatPhase.INITIATIVE)

func _handle_cleanup_state() -> void:
	if not is_battle_active:
		battle_ended.emit(true)

func _handle_initiative_phase() -> void:
	# Implement initiative phase logic
	pass

func _handle_deployment_phase() -> void:
	# Implement deployment phase logic
	pass

func _handle_action_phase() -> void:
	# Implement action phase logic
	pass

func _handle_reaction_phase() -> void:
	# Implement reaction phase logic
	pass

func _handle_end_phase() -> void:
	# Implement end phase logic
	pass

func start_round() -> void:
	current_round = max(1, current_round)
	round_started.emit(current_round)
	transition_to_phase(GameEnums.CombatPhase.INITIATIVE)

func end_round() -> void:
	round_ended.emit(current_round)
	current_round += 1
	if is_battle_active:
		transition_to_phase(GameEnums.CombatPhase.END)

func trigger_combat_effect(effect_name: String, source: Character, target: Character) -> void:
	combat_effect_triggered.emit(effect_name, source, target)

func trigger_reaction_opportunity(unit: Character, reaction_type: String, source: Character) -> void:
	reaction_opportunity.emit(unit, reaction_type, source)
