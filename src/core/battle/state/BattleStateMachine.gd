@tool
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const BattleCharacter = preload("res://src/core/battle/BattleCharacter.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")

signal state_changed(new_state: int)
signal phase_changed(new_phase: int)
signal round_started(round_number: int)
signal round_ended(round_number: int)
signal unit_action_changed(action: int)
signal unit_action_completed(unit: BattleCharacter, action: int)
signal battle_started
signal battle_ended(victory: bool)
signal attack_resolved(attacker: BattleCharacter, target: BattleCharacter, result: Dictionary)
signal reaction_opportunity(unit: BattleCharacter, reaction_type: String, source: BattleCharacter)
signal combat_effect_triggered(effect_name: String, source: BattleCharacter, target: BattleCharacter)

var game_state_manager: GameStateManager = null

var current_state: int = GameEnums.BattleState.SETUP
var current_phase: int = GameEnums.CombatPhase.NONE
var current_round: int = 1
var is_battle_active: bool = false
var active_combatants: Array[BattleCharacter] = []
var current_unit_action: int = GameEnums.UnitAction.NONE

# Track unit actions
var _completed_actions: Dictionary = {}
var _reaction_opportunities: Array[Dictionary] = []
var _current_unit: BattleCharacter = null

func _init(p_game_state_manager: GameStateManager = null) -> void:
	game_state_manager = p_game_state_manager
	if p_game_state_manager and not game_state_manager:
		push_warning("BattleStateMachine initialized without GameStateManager")

func add_character(character: BattleCharacter) -> void:
	if not character in active_combatants:
		active_combatants.append(character)
		# Only add to scene tree if not already there and not already has a parent
		if not character.is_inside_tree() and not character.get_parent():
			add_child(character)

func add_combatant(character: Node) -> void:
	if character is BattleCharacter and not character in active_combatants:
		add_character(character)

func get_active_combatants() -> Array[Node]:
	var result: Array[Node] = []
	for combatant in active_combatants:
		result.append(combatant)
	return result

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

func start_unit_action(unit: BattleCharacter, action: int) -> void:
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

func has_unit_completed_action(unit: BattleCharacter, action: int) -> bool:
	return _completed_actions.has(unit) and action in _completed_actions[unit]

func get_available_actions(unit: BattleCharacter) -> Array[int]:
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

func resolve_attack(attacker: BattleCharacter, target: BattleCharacter) -> void:
	# Implement attack resolution logic
	var result: Dictionary = {} # Add actual combat resolution logic
	attack_resolved.emit(attacker, target, result)

func trigger_reaction(unit: BattleCharacter, reaction_type: String, source: BattleCharacter) -> void:
	reaction_opportunity.emit(unit, reaction_type, source)

func apply_combat_effect(effect_name: String, source: BattleCharacter, target: BattleCharacter) -> void:
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
	transition_to_phase(GameEnums.CombatPhase.INITIATIVE)

func _handle_cleanup_state() -> void:
	current_phase = GameEnums.CombatPhase.NONE
	_completed_actions.clear()
	_reaction_opportunities.clear()

func _handle_initiative_phase() -> void:
	for character in active_combatants:
		character.initialize_for_battle()

func _handle_deployment_phase() -> void:
	# Position characters on battlefield
	pass

func _handle_action_phase() -> void:
	# Reset action points and available actions
	for character in active_combatants:
		if not _completed_actions.has(character):
			_completed_actions[character] = []

func _handle_reaction_phase() -> void:
	_reaction_opportunities.clear()

func _handle_end_phase() -> void:
	if is_battle_active:
		current_round += 1
		round_ended.emit(current_round - 1)

func start_round() -> void:
	current_round = max(1, current_round)
	transition_to(GameEnums.BattleState.ROUND)

func end_round() -> void:
	round_ended.emit(current_round)
	current_round += 1
	if is_battle_active:
		transition_to_phase(GameEnums.CombatPhase.END)

func trigger_combat_effect(effect_name: String, source: BattleCharacter, target: BattleCharacter) -> void:
	combat_effect_triggered.emit(effect_name, source, target)

func trigger_reaction_opportunity(unit: BattleCharacter, reaction_type: String, source: BattleCharacter) -> void:
	reaction_opportunity.emit(unit, reaction_type, source)
