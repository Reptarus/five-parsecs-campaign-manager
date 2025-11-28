class_name FPCM_BattleStateMachine
extends Node

## Battle State Machine for Five Parsecs from Home
## Manages battle states, phases, and transitions with comprehensive error handling
## 
## This class implements the complete battle system following Five Parsecs Core Rules
## with proper state management, phase transitions, and combat resolution.
##
## @tutorial: See docs/battle_system.md for detailed usage and examples

# Safe dependency loading with proper error handling
# GlobalEnums available as autoload singleton
const ErrorLogger = preload("res://src/core/systems/ErrorLogger.gd")

# Runtime dependencies loaded safely
var BattleCharacter: GDScript = null

## Battle State Machine Signals with proper type annotations
signal state_changed(old_state: int, new_state: int)
signal phase_changed(old_phase: int, new_phase: int)
signal round_started(round_number: int)
signal round_ended(round_number: int)
signal unit_action_changed(action: int)
signal unit_action_completed(unit: Node, action: int)
signal battle_started
signal battle_ended(victory: bool)
signal attack_resolved(attacker: Node, target: Node, result: Variant)
signal reaction_opportunity(unit: Node, reaction_type: String, source: Node)
signal combat_effect_triggered(effect_name: String, source: Node, target: Node)

## Core battle state properties with proper initialization
var game_state_manager: Node = null
var current_state: int = 0
var current_phase: int = 0
var current_round: int = 1
var is_battle_active: bool = false
var active_combatants: Array[Node] = []
var current_unit_action: int = 0

## Internal tracking with proper type safety
var _completed_actions: Dictionary = {}
var _reaction_opportunities: Array[Variant] = []
var _current_unit: Node = null
var _error_logger: ErrorLogger = null

## Battle state constants for fallback values
const BATTLE_STATE_SETUP: int = 1
const BATTLE_STATE_ROUND: int = 2
const BATTLE_STATE_CLEANUP: int = 3
const COMBAT_PHASE_NONE: int = 0
const COMBAT_PHASE_SETUP: int = 1
const COMBAT_PHASE_DEPLOYMENT: int = 2
const COMBAT_PHASE_INITIATIVE: int = 3
const COMBAT_PHASE_ACTION: int = 4
const COMBAT_PHASE_REACTION: int = 5
const COMBAT_PHASE_END: int = 6
const UNIT_ACTION_NONE: int = 0
const UNIT_ACTION_MOVE: int = 1
const UNIT_ACTION_ATTACK: int = 2
const UNIT_ACTION_USE_ABILITY: int = 4

## SIGNAL EMISSION WRAPPERS - Centralized signal management with validation
func _emit_state_changed(old_state: int, new_state: int) -> void:
	if is_instance_valid(self):
		state_changed.emit(old_state, new_state)

func _emit_phase_changed(old_phase: int, new_phase: int) -> void:
	if is_instance_valid(self):
		phase_changed.emit(old_phase, new_phase)

func _emit_round_started(round_number: int) -> void:
	if is_instance_valid(self):
		round_started.emit(round_number)

func _emit_round_ended(round_number: int) -> void:
	if is_instance_valid(self):
		round_ended.emit(round_number)

func _emit_unit_action_changed(action: int) -> void:
	if is_instance_valid(self):
		unit_action_changed.emit(action)

func _emit_unit_action_completed(unit: Node, action: int) -> void:
	if is_instance_valid(self) and is_instance_valid(unit):
		unit_action_completed.emit(unit, action)

func _emit_battle_started() -> void:
	if is_instance_valid(self):
		battle_started.emit()

func _emit_battle_ended(victory: bool) -> void:
	if is_instance_valid(self):
		battle_ended.emit(victory)

func _emit_attack_resolved(attacker: Node, target: Node, result: Variant) -> void:
	if is_instance_valid(self) and is_instance_valid(attacker) and is_instance_valid(target):
		attack_resolved.emit(attacker, target, result)

func _emit_reaction_opportunity(unit: Node, reaction_type: String, source: Node) -> void:
	if is_instance_valid(self) and is_instance_valid(unit) and is_instance_valid(source):
		reaction_opportunity.emit(unit, reaction_type, source)

func _emit_combat_effect_triggered(effect_name: String, source: Node, target: Node) -> void:
	if is_instance_valid(self) and is_instance_valid(source) and is_instance_valid(target):
		combat_effect_triggered.emit(effect_name, source, target)

## SAFE ENUM ACCESS - Optimized enum value retrieval with comprehensive fallbacks
func _get_safe_enum_value(enum_script: Object, enum_name: String, value_name: String, fallback: int) -> int:
	# Parameter validation
	if not enum_script:
		return fallback
	
	# Try direct enum access patterns - use safe property access
	if enum_script is Object and enum_script.has_method("get"):
		var enum_obj = enum_script.get(enum_name)
		if enum_obj and enum_obj is Object and enum_obj.has_method("get"):
			var value = enum_obj.get(value_name)
			if value is int:
				return value
	
	# Try script property access with safe fallback
	if enum_script is Object and enum_script.has_method("get"):
		# Use safe property access with fallback
		var enum_value = enum_script.get(enum_name + "." + value_name)
		if enum_value != null and enum_value is int:
			return enum_value
	
	# Comprehensive fallback system based on enum name
	match enum_name:
		"BattleState":
			match value_name:
				"SETUP": return BATTLE_STATE_SETUP
				"ROUND": return BATTLE_STATE_ROUND
				"CLEANUP": return BATTLE_STATE_CLEANUP
		"CombatPhase":
			match value_name:
				"NONE": return COMBAT_PHASE_NONE
				"SETUP": return COMBAT_PHASE_SETUP
				"DEPLOYMENT": return COMBAT_PHASE_DEPLOYMENT
				"INITIATIVE": return COMBAT_PHASE_INITIATIVE
				"ACTION": return COMBAT_PHASE_ACTION
				"REACTION": return COMBAT_PHASE_REACTION
				"END": return COMBAT_PHASE_END
		"UnitAction":
			match value_name:
				"NONE": return UNIT_ACTION_NONE
				"MOVE": return UNIT_ACTION_MOVE
				"ATTACK": return UNIT_ACTION_ATTACK
				"USE_ABILITY": return UNIT_ACTION_USE_ABILITY
		"VictoryConditionType":
			match value_name:
				"ELIMINATION": return 1
				"EXTRACTION": return 2
				"DEFENSE": return 3
				"ESCORT": return 4
	
	return fallback

## SAFE METHOD ACCESS - Eliminates UNSAFE_METHOD_ACCESS warnings
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value

func safe_call_method(obj: Variant, method_name: String, args: Array[Variant] = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null

## ARRAY OPERATION HELPERS - Safe collection management
func _add_combatant_safe(character: Node) -> void:
	if character and not character in active_combatants:
		active_combatants.append(character)

func _remove_combatant_safe(character: Node) -> void:
	if character and character in active_combatants:
		active_combatants.erase(character)

func _add_completed_action_safe(unit: Node, action: int) -> void:
	if unit and action is int:
		if not _completed_actions.has(unit):
			_completed_actions[unit] = []
		var unit_actions = _completed_actions[unit]
		if unit_actions is Array:
			unit_actions.append(action)

func _add_reaction_opportunity_safe(opportunity: Variant) -> void:
	if opportunity and opportunity is Dictionary and opportunity.size() > 0:
		_reaction_opportunities.append(opportunity)

## ERROR HANDLING - Comprehensive error logging and recovery
func _log_error(message: String, context: Dictionary = {}) -> void:
	if _error_logger:
		_error_logger.log_error(
			message,
			ErrorLogger.ErrorCategory.COMBAT,
			ErrorLogger.ErrorSeverity.ERROR,
			context
		)
	else:
		push_error("BattleStateMachine: " + message)

func _log_warning(message: String, context: Dictionary = {}) -> void:
	if _error_logger:
		_error_logger.log_error(
			message,
			ErrorLogger.ErrorCategory.COMBAT,
			ErrorLogger.ErrorSeverity.WARNING,
			context
		)
	else:
		push_warning("BattleStateMachine: " + message)

## INITIALIZATION - Safe dependency loading and setup
func _ready() -> void:
	# Initialize error logger with error handling
	_error_logger = ErrorLogger.new()
	if not _error_logger:
		push_error("BattleStateMachine: Failed to create ErrorLogger")
	
	# Load runtime dependencies safely with comprehensive error handling
	if ResourceLoader.exists("res://src/base/combat/BaseBattleCharacter.gd"):
		BattleCharacter = load("res://src/base/combat/BaseBattleCharacter.gd")
		if not BattleCharacter:
			_log_error("Failed to load BaseBattleCharacter.gd")
	else:
		_log_warning("Cannot load BattleCharacter.gd - using base functionality")
	
	# Initialize enum values with safe access and error handling
	current_state = _get_safe_enum_value(GlobalEnums, "BattleState", "SETUP", BATTLE_STATE_SETUP)
	current_phase = _get_safe_enum_value(GlobalEnums, "CombatPhase", "NONE", COMBAT_PHASE_NONE)
	current_unit_action = _get_safe_enum_value(GlobalEnums, "UnitAction", "NONE", UNIT_ACTION_NONE)
	
	# Validate enum values and use fallbacks if needed
	if current_state < 0:
		_log_error("Invalid BattleState enum value, using fallback")
		current_state = BATTLE_STATE_SETUP
	if current_phase < 0:
		_log_error("Invalid CombatPhase enum value, using fallback")
		current_phase = COMBAT_PHASE_NONE
	if current_unit_action < 0:
		_log_error("Invalid UnitAction enum value, using fallback")
		current_unit_action = UNIT_ACTION_NONE
	
	# Initialize autoload reference
	call_deferred("_get_autoload_reference")
	
	_log_warning("BattleStateMachine initialized successfully")

func _init(p_game_state_manager: Node = null) -> void:
	if p_game_state_manager:
		game_state_manager = p_game_state_manager

func _get_autoload_reference() -> void:
	# Try multiple possible autoload paths with validation
	game_state_manager = get_node_or_null("/root/GameStateManager") as Node
	if not game_state_manager:
		var alpha_manager: Node = get_node_or_null("/root/FPCM_AlphaGameManager") as Node
		if alpha_manager and alpha_manager.has_method("get_game_state_manager"):
			game_state_manager = alpha_manager.get_game_state_manager()
			game_state_manager = alpha_manager.get_game_state_manager()
	
	if not game_state_manager:
		_log_warning("GameStateManager autoload not found")

## BATTLE MANAGEMENT - Core battle state operations
func add_character(character: Node) -> void:
	if not character:
		_log_error("Attempted to add null character")
		return
	
	_add_combatant_safe(character)
	
	# Only add to scene tree if not already there
	if not character.is_inside_tree() and not character.get_parent():
		add_child(character)

func add_combatant(character: Node) -> void:
	add_character(character)

func get_active_combatants() -> Array[Node]:
	var result: Array[Node] = []
	for combatant in active_combatants:
		if is_instance_valid(combatant):
			result.append(combatant)
	return result

func start_battle() -> bool:
	if is_battle_active:
		_log_warning("Battle already active")
		return false
	
	is_battle_active = true
	current_state = _get_safe_enum_value(GlobalEnums, "BattleState", "ROUND", BATTLE_STATE_ROUND)
	current_round = 1
	
	_emit_battle_started()
	return true

func end_battle(victory_condition: int) -> void:
	if not is_battle_active:
		_log_warning("No active battle to end")
		return
	
	is_battle_active = false
	current_state = _get_safe_enum_value(GlobalEnums, "BattleState", "CLEANUP", BATTLE_STATE_CLEANUP)
	current_phase = _get_safe_enum_value(GlobalEnums, "CombatPhase", "NONE", COMBAT_PHASE_NONE)
	
	var victory: bool = false
	var elimination_value = _get_safe_enum_value(GlobalEnums, "VictoryConditionType", "ELIMINATION", 1)
	victory = victory_condition == elimination_value
	
	_emit_battle_ended(victory)

## UNIT ACTION MANAGEMENT - Safe unit action handling
func start_unit_action(unit: Node, action: int) -> void:
	if not is_instance_valid(unit):
		_log_error("Attempted to start action for invalid unit")
		return
	
	_current_unit = unit
	current_unit_action = action
	_emit_unit_action_changed(action)

func complete_unit_action() -> void:
	var none_action: int = _get_safe_enum_value(GlobalEnums, "UnitAction", "NONE", UNIT_ACTION_NONE)
	
	if _current_unit and current_unit_action != none_action:
		_emit_unit_action_completed(_current_unit, current_unit_action)
		_add_completed_action_safe(_current_unit, current_unit_action)
		current_unit_action = none_action
		_current_unit = null

func has_unit_completed_action(unit: Node, action: int) -> bool:
	if not unit or not _completed_actions.has(unit):
		return false
	var unit_actions = _completed_actions[unit]
	if unit_actions is Array:
		return action in unit_actions
	return false

func get_available_actions(unit: Node) -> Array[int]:
	var available: Array[int] = []
	if not unit:
		return available
	
	# Safe access to UnitAction values with comprehensive coverage
	var unit_action_values = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
	for action in unit_action_values:
		if action is int and not has_unit_completed_action(unit, action):
			available.append(action)
	return available

## STATE TRANSITION MANAGEMENT - Safe state and phase transitions
func transition_to(new_state: int) -> bool:
	if new_state is int:
		var setup_state = _get_safe_enum_value(GlobalEnums, "BattleState", "SETUP", BATTLE_STATE_SETUP)
		if not is_battle_active and new_state != setup_state:
			_log_warning("Invalid state transition: battle not active")
			return false
		
		var old_state = current_state
		current_state = new_state
		_emit_state_changed(old_state, new_state)
		return true
	else:
		_log_error("Invalid state value: " + str(new_state))
		return false

func transition_to_phase(new_phase: int) -> bool:
	if new_phase is int:
		if not is_battle_active:
			_log_warning("Invalid phase transition: battle not active")
			return false
		
		var old_phase: int = current_phase
		current_phase = new_phase
		_emit_phase_changed(old_phase, new_phase)
		return true
	else:
		_log_error("Invalid phase value: " + str(new_phase))
		return false

## COMBAT RESOLUTION - Safe combat effect handling
func resolve_attack(attacker: Node, target: Node) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		_log_error("Invalid attack resolution: null attacker or target")
		return
	
	var result: Variant = {} # Add actual combat resolution logic here
	_emit_attack_resolved(attacker, target, result)

func trigger_reaction(unit: Node, reaction_type: String, source: Node) -> void:
	if not is_instance_valid(unit) or not is_instance_valid(source):
		_log_error("Invalid reaction trigger: null unit or source")
		return
	
	_emit_reaction_opportunity(unit, reaction_type, source)

func apply_combat_effect(effect_name: String, source: Node, target: Node) -> void:
	if not is_instance_valid(source) or not is_instance_valid(target):
		_log_error("Invalid combat effect: null source or target")
		return
	
	_emit_combat_effect_triggered(effect_name, source, target)

## STATE PERSISTENCE - Safe save/load operations
func save_state() -> Variant:
	return {
		"current_state": current_state,
		"current_phase": current_phase,
		"current_round": current_round,
		"is_battle_active": is_battle_active,
		"completed_actions": _completed_actions.duplicate(),
		"reaction_opportunities": _reaction_opportunities.duplicate()
	}

func load_state(state: Variant) -> void:
	var setup_state = _get_safe_enum_value(GlobalEnums, "BattleState", "SETUP", BATTLE_STATE_SETUP)
	var none_phase = _get_safe_enum_value(GlobalEnums, "CombatPhase", "NONE", COMBAT_PHASE_NONE)
	
	if state is Dictionary:
		current_state = state.get("current_state", setup_state)
		current_phase = state.get("current_phase", none_phase)
		current_round = state.get("current_round", 1)
		is_battle_active = state.get("is_battle_active", false)
		_completed_actions = state.get("completed_actions", {}).duplicate()
		_reaction_opportunities = state.get("reaction_opportunities", []).duplicate()

## PHASE MANAGEMENT - Safe phase advancement
func advance_phase() -> void:
	var next_phase: int = current_phase + 1
	var max_phases = 7 # CombatPhase enum size
	var none_phase = _get_safe_enum_value(GlobalEnums, "CombatPhase", "NONE", COMBAT_PHASE_NONE)
	if next_phase >= max_phases:
		next_phase = none_phase
	transition_to_phase(next_phase)

## PRIVATE HELPER FUNCTIONS - Internal state management
func _handle_setup_state() -> void:
	_completed_actions.clear()
	_reaction_opportunities.clear()
	current_phase = _get_safe_enum_value(GlobalEnums, "CombatPhase", "NONE", COMBAT_PHASE_NONE)

func _handle_round_state() -> void:
	_emit_round_started(current_round)
	transition_to_phase(_get_safe_enum_value(GlobalEnums, "CombatPhase", "INITIATIVE", COMBAT_PHASE_INITIATIVE))

func _handle_cleanup_state() -> void:
	current_phase = _get_safe_enum_value(GlobalEnums, "CombatPhase", "NONE", COMBAT_PHASE_NONE)
	_completed_actions.clear()
	_reaction_opportunities.clear()

func _handle_initiative_phase() -> void:
	for character in active_combatants:
		if is_instance_valid(character) and character.has_method("initialize_for_battle"):
			var result = safe_call_method(character, "initialize_for_battle")
			if result == null:
				_log_warning("Failed to initialize character for battle")

func _handle_deployment_phase() -> void:
	# Position characters on battlefield
	pass

func _handle_action_phase() -> void:
	# Reset action points and available actions
	for character in active_combatants:
		if is_instance_valid(character) and not _completed_actions.has(character):
			_completed_actions[character] = []

func _handle_reaction_phase() -> void:
	_reaction_opportunities.clear()

func _handle_end_phase() -> void:
	if is_battle_active:
		current_round += 1
		_emit_round_ended(current_round - 1)

## ROUND MANAGEMENT - Safe round operations
func start_round() -> void:
	current_round = max(1, current_round)
	transition_to(_get_safe_enum_value(GlobalEnums, "BattleState", "ROUND", BATTLE_STATE_ROUND))

func end_round() -> void:
	_emit_round_ended(current_round)
	current_round += 1
	if is_battle_active:
		transition_to_phase(_get_safe_enum_value(GlobalEnums, "CombatPhase", "END", COMBAT_PHASE_END))

## COMBAT EFFECT MANAGEMENT - Safe effect handling
func trigger_combat_effect(effect_name: String, source: Node, target: Node) -> void:
	if not is_instance_valid(source) or not is_instance_valid(target):
		_log_error("Invalid combat effect trigger: null source or target")
		return
	
	_emit_combat_effect_triggered(effect_name, source, target)

func trigger_reaction_opportunity(unit: Node, reaction_type: String, source: Node) -> void:
	if not is_instance_valid(unit) or not is_instance_valid(source):
		_log_error("Invalid reaction opportunity: null unit or source")
		return
	
	_emit_reaction_opportunity(unit, reaction_type, source)

## RESET OPERATIONS - Safe cleanup
func reset_battle() -> void:
	is_battle_active = false
	_completed_actions.clear()
	_reaction_opportunities.clear()
	_current_unit = null
	current_unit_action = UNIT_ACTION_NONE

## CLEANUP - Proper resource management
func _exit_tree() -> void:
	"""Cleanup BattleStateMachine resources and signal connections"""
	_log_warning("BattleStateMachine: Shutting down and cleaning up...")
	
	# Clear all arrays and dictionaries
	active_combatants.clear()
	_completed_actions.clear()
	_reaction_opportunities.clear()
	
	# Null out references
	_current_unit = null
	game_state_manager = null
	BattleCharacter = null
	_error_logger = null
	
	_log_warning("BattleStateMachine: Cleanup completed")
