class_name BattleStateMachineClass
extends Node

## Battle State Machine for Five Parsecs from Home
## Manages battle states, phases, and transitions

# Dependencies loaded at runtime to avoid circular dependencies
var GameEnums = null
var BattleCharacter = null
# Note: GameStateManager is an autoload - access via get_node() instead of preload()

signal state_changed(new_state: int)
signal phase_changed(new_phase: int)
signal round_started(round_number: int)
signal round_ended(round_number: int)
signal unit_action_changed(action: int)
signal unit_action_completed(unit: Node, action: int) # unit is BattleCharacter
signal battle_started
signal battle_ended(victory: bool)
signal attack_resolved(attacker: Node, target: Node, result: Dictionary) # attacker/target are BattleCharacter
signal reaction_opportunity(unit: Node, reaction_type: String, source: Node) # unit/source are BattleCharacter
signal combat_effect_triggered(effect_name: String, source: Node, target: Node) # source/target are BattleCharacter

var game_state_manager: Node = null # GameStateManager autoload

var current_state: int = 0 # Will be set to GameEnums.BattleState.SETUP in _ready()
var current_phase: int = 0 # Will be set to GameEnums.CombatPhase.NONE in _ready()
var current_round: int = 1
var is_battle_active: bool = false
var active_combatants: Array[Node] = [] # Will contain BattleCharacter nodes
var current_unit_action: int = 0 # Will be set to GameEnums.UnitAction.NONE in _ready()

# Track unit actions
var _completed_actions: Dictionary = {}
var _reaction_opportunities: Array[Dictionary] = []
var _current_unit: Node = null # Will contain BattleCharacter

func _ready() -> void:
	# Load dependencies at runtime to avoid circular dependencies
	GameEnums = load("res://src/core/systems/GlobalEnums.gd")
	BattleCharacter = load("res://src/game/combat/BattleCharacter.gd")
	
	# Initialize enum values
	if GameEnums:
		current_state = GameEnums.BattleState.SETUP
		current_phase = GameEnums.CombatPhase.NONE
		current_unit_action = GameEnums.UnitAction.NONE

func _init(p_game_state_manager: Node = null) -> void:
	if p_game_state_manager:
		game_state_manager = p_game_state_manager
	else:
		# Get GameStateManager autoload at runtime
		call_deferred("_get_autoload_reference")

func _get_autoload_reference() -> void:
	# Try multiple possible autoload paths
	game_state_manager = get_node_or_null("/root/GameStateManager")
	if not game_state_manager:
		game_state_manager = get_node_or_null("/root/GameStateManagerAutoload")
	if not game_state_manager:
		# Try to find it via AlphaGameManager
		var alpha_manager = get_node_or_null("/root/AlphaGameManager")
		if alpha_manager and alpha_manager.has_method("get_game_state_manager"):
			game_state_manager = alpha_manager.get_game_state_manager()
	
	if not game_state_manager:
		push_warning("BattleStateMachine: GameStateManager autoload not found")

func add_character(character: Node) -> void:
	if not character in active_combatants:
		active_combatants.append(character)

		# Only add to scene tree if not already there and not already has a parent
		if not character.is_inside_tree() and not character.get_parent():
			add_child(character)

func add_combatant(character: Node) -> void:
	if character and not character in active_combatants:
		add_character(character)

func get_active_combatants() -> Array[Node]:
	var result: Array[Node] = []
	for combatant in active_combatants:
		result.append(combatant) # warning: return value discarded (intentional)
	return result

func start_battle() -> bool:
	if is_battle_active:
		return false
	
	is_battle_active = true
	current_state = GameEnums.BattleState.ROUND
	current_round = 1
	
	battle_started.emit()
	return true

func end_battle(victory_condition: int) -> void:
	if not is_battle_active:
		return
	
	is_battle_active = false
	current_state = GameEnums.BattleState.CLEANUP
	current_phase = GameEnums.CombatPhase.NONE
	
	var victory = victory_condition == GameEnums.VictoryConditionType.ELIMINATION
	battle_ended.emit(victory)

func start_unit_action(unit: Node, action: int) -> void:
	_current_unit = unit
	current_unit_action = action
	unit_action_changed.emit(action)

func complete_unit_action() -> void:
	if _current_unit and current_unit_action != GameEnums.UnitAction.NONE:
		unit_action_completed.emit(_current_unit, current_unit_action) # warning: return value discarded (intentional)
		if not _completed_actions.has(_current_unit):
			_completed_actions[_current_unit] = []
		_completed_actions[_current_unit].append(current_unit_action)
		current_unit_action = GameEnums.UnitAction.NONE
		_current_unit = null

func has_unit_completed_action(unit: Node, action: int) -> bool:
	return _completed_actions.has(unit) and action in _completed_actions[unit]

func get_available_actions(unit: Node) -> Array[int]:
	var available: Array[int] = []
	if GameEnums:
		for action in GameEnums.UnitAction.values():
			if not has_unit_completed_action(unit, action):
				available.append(action)
	return available

func transition_to(new_state: int) -> bool:
	if not is_battle_active and new_state != GameEnums.BattleState.SETUP:
		return false
	
	var old_state = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)
	return true

func transition_to_phase(new_phase: int) -> bool:
	if not is_battle_active:
		return false
	
	var old_phase = current_phase
	current_phase = new_phase
	phase_changed.emit(old_phase, new_phase)
	return true

func resolve_attack(attacker: Node, target: Node) -> void:
	# Implement attack resolution logic
	var result: Dictionary = {} # Add actual combat resolution logic
	attack_resolved.emit(attacker, target, result)

func trigger_reaction(unit: Node, reaction_type: String, source: Node) -> void:
	reaction_opportunity.emit(unit, reaction_type, source)

func apply_combat_effect(effect_name: String, source: Node, target: Node) -> void:
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
	round_started.emit(current_round) # warning: return value discarded (intentional)
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
		round_ended.emit(current_round - 1) # warning: return value discarded (intentional)

func start_round() -> void:
	current_round = max(1, current_round)
	transition_to(GameEnums.BattleState.ROUND)

func end_round() -> void:
	round_ended.emit(current_round) # warning: return value discarded (intentional)
	current_round += 1
	if is_battle_active:
		transition_to_phase(GameEnums.CombatPhase.END)

func trigger_combat_effect(effect_name: String, source: Node, target: Node) -> void: # source/target are BattleCharacter
	combat_effect_triggered.emit(effect_name, source, target) # warning: return value discarded (intentional)

func trigger_reaction_opportunity(unit: Node, reaction_type: String, source: Node) -> void: # unit/source are BattleCharacter
	reaction_opportunity.emit(unit, reaction_type, source) # warning: return value discarded (intentional)

func reset_battle() -> void:
	is_battle_active = false