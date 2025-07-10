class_name BattleStateMachineClass
extends Node

## Battle State Machine for Five Parsecs from Home
## Manages battle states, phases, and transitions

# Dependencies loaded at runtime to avoid circular dependencies
var GlobalEnums: Variant = null
var BattleCharacter: Variant = null
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

var current_state: int = 0 # Will be set to GlobalEnums.BattleState.SETUP in _ready()
var current_phase: int = 0 # Will be set to GlobalEnums.CombatPhase.NONE in _ready()
var current_round: int = 1
var is_battle_active: bool = false
var active_combatants: Array[Node] = [] # Will contain BattleCharacter nodes
var current_unit_action: int = 0 # Will be set to GlobalEnums.UnitAction.NONE in _ready()

# Track unit actions
var _completed_actions: Dictionary = {}
var _reaction_opportunities: Array[Dictionary] = []
var _current_unit: Node = null # Will contain BattleCharacter

func _ready() -> void:
	# Load dependencies at runtime to avoid circular dependencies
	if ResourceLoader.exists("res://src/core/systems/GlobalEnums.gd"):
		GlobalEnums = load("res://src/core/systems/GlobalEnums.gd")
	else:
		push_error("BattleStateMachine: Cannot load GlobalEnums.gd")

	if ResourceLoader.exists("res://src/game/combat/BattleCharacter.gd"):
		BattleCharacter = load("res://src/game/combat/BattleCharacter.gd")
	else:
		push_warning("BattleStateMachine: Cannot load BattleCharacter.gd - using base functionality")

	# Initialize enum values
	if GlobalEnums:
		# GlobalEnums is a script with const enums, access them directly
		current_state = GlobalEnums.BattleState.SETUP
		current_phase = GlobalEnums.CombatPhase.NONE
		current_unit_action = GlobalEnums.UnitAction.NONE
	else:
		# Fallback values if GlobalEnums not loaded
		current_state = 0
		current_phase = 0
		current_unit_action = 0
		push_error("BattleStateMachine: GlobalEnums not loaded, using fallback values")

func _init(p_game_state_manager: Node = null) -> void:
	if p_game_state_manager:
		game_state_manager = p_game_state_manager
	else:
		# Get GameStateManager autoload at runtime
		call_deferred("_get_autoload_reference")

func _get_autoload_reference() -> void:
	# Try multiple possible autoload paths
	game_state_manager = get_node_or_null("/root/GameStateManager") as Node
	if not game_state_manager:
		game_state_manager = get_node_or_null("/root/GameStateManagerAutoload") as Node
	if not game_state_manager:
		# Try to find it via AlphaGameManager
		var alpha_manager: Node = get_node_or_null("/root/FPCM_AlphaGameManager") as Node
		if alpha_manager and alpha_manager.has_method("get_game_state_manager"):
			game_state_manager = alpha_manager.get_game_state_manager()

	if not game_state_manager:
		push_warning("BattleStateMachine: GameStateManager autoload not found")

func add_character(character: Node) -> void:
	if not character in active_combatants:
		safe_call_method(active_combatants, "append", [character])

		# Only add to scene tree if not already there and not already has a parent
		if not character.is_inside_tree() and not character.get_parent():
			add_child(character)

func add_combatant(character: Node) -> void:
	if character and not character in active_combatants:
		add_character(character)

func get_active_combatants() -> Array[Node]:
	var result: Array[Node] = []
	for combatant in active_combatants:
		result.append(combatant)
	return result

func start_battle() -> bool:
	if is_battle_active:
		return false

	is_battle_active = true
	if GlobalEnums and GlobalEnums.has("BattleState"):
		current_state = GlobalEnums.BattleState.ROUND
	else:
		current_state = 1 # Fallback value
	current_round = 1

	battle_started.emit()
	return true

func end_battle(victory_condition: int) -> void:
	if not is_battle_active:
		return

	is_battle_active = false
	if GlobalEnums and GlobalEnums.has("BattleState"):
		current_state = GlobalEnums.BattleState.CLEANUP
	else:
		current_state = 99 # Fallback cleanup value

	if GlobalEnums and GlobalEnums.has("CombatPhase"):
		current_phase = GlobalEnums.CombatPhase.NONE
	else:
		current_phase = 0 # Fallback none value

	var victory: bool = false
	if GlobalEnums and GlobalEnums.has("VictoryConditionType"):
		victory = victory_condition == GlobalEnums.VictoryConditionType.ELIMINATION
	else:
		victory = victory_condition == 1 # Fallback elimination value

	battle_ended.emit(victory)

func start_unit_action(unit: Node, action: int) -> void:
	_current_unit = unit
	current_unit_action = action
	unit_action_changed.emit(action)

func complete_unit_action() -> void:
	var none_action: int = 0
	if GlobalEnums and GlobalEnums.has("UnitAction"):
		none_action = GlobalEnums.UnitAction.NONE

	if _current_unit and current_unit_action != none_action:
		unit_action_completed.emit(_current_unit, current_unit_action)
		if not _completed_actions.has(_current_unit):
			_completed_actions[_current_unit] = []
		_completed_actions[_current_unit].append(current_unit_action)
		current_unit_action = none_action
		_current_unit = null

func has_unit_completed_action(unit: Node, action: int) -> bool:
	return _completed_actions.has(unit) and action in _completed_actions[unit]

func get_available_actions(unit: Node) -> Array[int]:
	var available: Array[int] = []
	if GlobalEnums:
		for action in GlobalEnums.UnitAction.values():
			if not has_unit_completed_action(unit, action):
				available.append(action)
	return available

func transition_to(new_state: int) -> bool:
	if not is_battle_active and new_state != GlobalEnums.BattleState.SETUP:
		return false

	var old_state = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)
	return true

func transition_to_phase(new_phase: int) -> bool:
	if not is_battle_active:
		return false

	var old_phase: int = current_phase
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
	current_state = state.get("current_state", GlobalEnums.BattleState.SETUP)
	current_phase = state.get("current_phase", GlobalEnums.CombatPhase.NONE)
	current_round = state.get("current_round", 1)
	is_battle_active = state.get("is_battle_active", false)
	_completed_actions = state.get("completed_actions", {})
	_reaction_opportunities = state.get("reaction_opportunities", [])

func advance_phase() -> void:
	var next_phase: int = current_phase + 1
	if next_phase >= GlobalEnums.CombatPhase.size():
		next_phase = GlobalEnums.CombatPhase.NONE
	transition_to_phase(next_phase)

# Private helper functions
func _handle_setup_state() -> void:
	_completed_actions.clear()
	_reaction_opportunities.clear()
	current_phase = GlobalEnums.CombatPhase.NONE

func _handle_round_state() -> void:
	round_started.emit(current_round)
	transition_to_phase(GlobalEnums.CombatPhase.INITIATIVE)

func _handle_cleanup_state() -> void:
	current_phase = GlobalEnums.CombatPhase.NONE
	_completed_actions.clear()
	_reaction_opportunities.clear()

func _handle_initiative_phase() -> void:
	for character in active_combatants:
		if character and character.has_method("initialize_for_battle"): character.initialize_for_battle()

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
	transition_to(GlobalEnums.BattleState.ROUND)

func end_round() -> void:
	round_ended.emit(current_round)
	current_round += 1
	if is_battle_active:
		transition_to_phase(GlobalEnums.CombatPhase.END)

func trigger_combat_effect(effect_name: String, source: Node, target: Node) -> void: # source/target are BattleCharacter
	combat_effect_triggered.emit(effect_name, source, target)

func trigger_reaction_opportunity(unit: Node, reaction_type: String, source: Node) -> void: # unit/source are BattleCharacter
	reaction_opportunity.emit(unit, reaction_type, source)

func reset_battle() -> void:
	is_battle_active = false

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
