@tool
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
# Avoid circular class references by using a weak type reference
var BattleCharacter = null
var GameStateManager = null

signal state_changed(new_state: int)
signal phase_changed(new_phase: int)
signal round_started(round_number: int)
signal round_ended(round_number: int)
signal unit_action_changed(action: int)
signal unit_action_completed(unit, action: int)
signal battle_started
signal battle_ended(victory: bool)
signal attack_resolved(attacker, target, result: Dictionary)
signal reaction_opportunity(unit, reaction_type: String, source)
signal combat_effect_triggered(effect_name: String, source, target)

var game_state_manager = null

var current_state: int = GameEnums.BattleState.SETUP
var current_phase: int = GameEnums.CombatPhase.NONE
var current_round: int = 1
var is_battle_active: bool = false
var active_combatants: Array = []
var current_unit_action: int = GameEnums.UnitAction.NONE

# Track unit actions
var _completed_actions: Dictionary = {}
var _reaction_opportunities: Array = []
var _current_unit = null

func _init() -> void:
	# Load classes to avoid circular references
	BattleCharacter = load("res://src/core/battle/CharacterUnit.gd")
	GameStateManager = load("res://src/core/managers/GameStateManager.gd")
	
	# Initialize properties to prevent null references
	current_state = GameEnums.BattleState.SETUP
	current_phase = GameEnums.CombatPhase.NONE
	current_round = 1
	is_battle_active = false
	active_combatants = []
	current_unit_action = GameEnums.UnitAction.NONE
	_completed_actions = {}
	_reaction_opportunities = []
	_current_unit = null

func _ready() -> void:
	# Ensure we have valid references
	if not BattleCharacter:
		BattleCharacter = load("res://src/core/battle/CharacterUnit.gd")
	
	if not GameStateManager:
		GameStateManager = load("res://src/core/managers/GameStateManager.gd")

func set_game_state_manager(p_game_state_manager) -> void:
	if is_instance_valid(p_game_state_manager):
		game_state_manager = p_game_state_manager

func add_character(character) -> void:
	if not is_instance_valid(character):
		return
		
	if not character in active_combatants:
		active_combatants.append(character)
		# Only add to scene tree if not already there and not already has a parent
		if not character.is_inside_tree() and not character.get_parent():
			add_child(character)

func add_combatant(character: Node) -> void:
	if is_instance_valid(character) and not character in active_combatants:
		add_character(character)

func get_active_combatants() -> Array:
	return active_combatants.duplicate()

func start_battle() -> void:
	current_state = GameEnums.BattleState.SETUP
	current_round = 1
	is_battle_active = true
	_completed_actions.clear()
	battle_started.emit()
	current_state = GameEnums.BattleState.ROUND
	state_changed.emit(current_state)
	_handle_round_state()

func end_battle(victory_type: int) -> void:
	is_battle_active = false
	transition_to(GameEnums.BattleState.CLEANUP)
	battle_ended.emit(victory_type == GameEnums.VictoryConditionType.ELIMINATION)

func start_unit_action(unit, action: int) -> void:
	if not is_instance_valid(unit):
		return
		
	_current_unit = unit
	current_unit_action = action
	unit_action_changed.emit(action)

func complete_unit_action() -> void:
	if not is_instance_valid(_current_unit) or current_unit_action == GameEnums.UnitAction.NONE:
		return
		
	unit_action_completed.emit(_current_unit, current_unit_action)
	if not _current_unit in _completed_actions:
		_completed_actions[_current_unit] = []
	_completed_actions[_current_unit].append(current_unit_action)
	current_unit_action = GameEnums.UnitAction.NONE
	_current_unit = null

func has_unit_completed_action(unit, action: int) -> bool:
	if not is_instance_valid(unit):
		return false
	return unit in _completed_actions and action in _completed_actions[unit]

func get_available_actions(unit) -> Array:
	if not is_instance_valid(unit):
		return []
		
	var available = []
	for action in GameEnums.UnitAction.values():
		if not has_unit_completed_action(unit, action):
			available.append(action)
	return available

func transition_to(new_state: int) -> void:
	if new_state == current_state:
		return
		
	match new_state:
		GameEnums.BattleState.SETUP:
			_handle_setup_state()
		GameEnums.BattleState.ROUND:
			_handle_round_state()
		GameEnums.BattleState.CLEANUP:
			_handle_cleanup_state()
	
	current_state = new_state
	state_changed.emit(new_state)

func transition_to_phase(new_phase: int) -> void:
	if new_phase == current_phase:
		return
		
	match new_phase:
		GameEnums.CombatPhase.INITIATIVE:
			_handle_initiative_phase()
		GameEnums.CombatPhase.DEPLOYMENT:
			_handle_deployment_phase()
		GameEnums.CombatPhase.ACTION:
			_handle_action_phase()
		GameEnums.CombatPhase.REACTION:
			_handle_reaction_phase()
		GameEnums.CombatPhase.END:
			_handle_end_phase()
	
	current_phase = new_phase
	phase_changed.emit(new_phase)

# These implementation methods would be provided in a derived class
func _handle_setup_state() -> void:
	pass

func _handle_round_state() -> void:
	round_started.emit(current_round)

func _handle_cleanup_state() -> void:
	pass

func _handle_initiative_phase() -> void:
	pass
	
func _handle_deployment_phase() -> void:
	pass
	
func _handle_action_phase() -> void:
	pass
	
func _handle_reaction_phase() -> void:
	pass
	
func _handle_end_phase() -> void:
	round_ended.emit(current_round)
	current_round += 1

func resolve_attack(attacker, target) -> void:
	# Implement attack resolution logic
	var result: Dictionary = {} # Add actual combat resolution logic
	attack_resolved.emit(attacker, target, result)

func trigger_reaction(unit, reaction_type: String, source) -> void:
	reaction_opportunity.emit(unit, reaction_type, source)

func apply_combat_effect(effect_name: String, source, target) -> void:
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
	if state == null:
		return
		
	current_state = state.get("current_state", GameEnums.BattleState.SETUP)
	current_phase = state.get("current_phase", GameEnums.CombatPhase.NONE)
	current_round = state.get("current_round", 1)
	is_battle_active = state.get("is_battle_active", false)
	
	# Safely load completed actions
	var completed = state.get("completed_actions", {})
	_completed_actions.clear()
	for unit in completed:
		_completed_actions[unit] = completed[unit].duplicate()
		
	# Safely load reaction opportunities
	var opportunities = state.get("reaction_opportunities", [])
	_reaction_opportunities = opportunities.duplicate()

func advance_phase() -> void:
	var next_phase: int = current_phase + 1
	if next_phase >= GameEnums.CombatPhase.size():
		next_phase = GameEnums.CombatPhase.NONE
	transition_to_phase(next_phase)

func start_round() -> void:
	current_round = max(1, current_round)
	transition_to(GameEnums.BattleState.ROUND)

func end_round() -> void:
	round_ended.emit(current_round)
	current_round += 1
	if is_battle_active:
		transition_to_phase(GameEnums.CombatPhase.END)

func trigger_combat_effect(effect_name: String, source, target) -> void:
	combat_effect_triggered.emit(effect_name, source, target)
