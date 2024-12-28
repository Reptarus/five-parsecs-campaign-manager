extends Node

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")

signal state_changed(new_state: int)  # BattleState
signal phase_changed(new_phase: int)  # BattlePhase
signal round_started(round_number: int)
signal round_ended(round_number: int)
signal unit_action_completed(unit: Character, action: int)
signal battle_ended(victory: bool)
signal unit_activated(unit: Character)
signal unit_deactivated(unit: Character)
signal action_points_changed(unit: Character, points: int)
signal combat_effect_triggered(effect_name: String, source: Character, target: Character)
signal reaction_opportunity(unit: Character, reaction_type: String, source: Character)

@export var game_state_manager: GameStateManager
@export var battlefield_manager: Node
@export var combat_resolver: Node

enum BattleState {SETUP, ROUND, CLEANUP}
enum BattlePhase {INITIATIVE, MOVEMENT, ACTION, REACTION, END}
enum UnitAction {MOVE, ATTACK, DASH, ITEMS, SNAP_FIRE, FREE_ACTION, STUNNED, BRAWL, OTHER}

var current_state: BattleState = BattleState.SETUP
var current_phase: BattlePhase = BattlePhase.INITIATIVE
var current_round: int = 1
var is_battle_complete: bool = false
var active_units: Array[Character] = []
var current_unit: Character = null
var last_battle_results: Dictionary = {}

# Track unit actions
var _completed_actions: Dictionary = {}
var _reaction_opportunities: Array[Dictionary] = []
var action_points: Dictionary = {}

func _ready() -> void:
	if not game_state_manager:
		push_error("BattleStateMachine: GameStateManager not set")
		return
	
	_connect_signals()

func _connect_signals() -> void:
	if battlefield_manager:
		battlefield_manager.unit_moved.connect(_on_unit_moved)
		battlefield_manager.unit_added.connect(_on_unit_added)
		battlefield_manager.unit_removed.connect(_on_unit_removed)
	
	if combat_resolver:
		combat_resolver.combat_resolved.connect(_on_combat_resolved)

func initialize_battle() -> void:
	current_state = BattleState.SETUP
	current_phase = BattlePhase.INITIATIVE
	current_round = 1
	is_battle_complete = false
	_completed_actions.clear()
	_reaction_opportunities.clear()
	action_points.clear()
	active_units.clear()
	current_unit = null
	last_battle_results.clear()
	
	_initialize_units()
	state_changed.emit(current_state)
	phase_changed.emit(current_phase)

func _initialize_units() -> void:
	if not battlefield_manager:
		return
	
	var units = battlefield_manager.get_all_units()
	for unit in units:
		active_units.append(unit)
		action_points[unit] = unit.get_max_action_points()

func change_phase(new_phase: BattlePhase) -> void:
	if new_phase == current_phase:
		return
	
	var old_phase = current_phase
	current_phase = new_phase
	
	match new_phase:
		BattlePhase.INITIATIVE:
			_handle_initiative_phase()
		BattlePhase.MOVEMENT:
			_handle_movement_phase()
		BattlePhase.ACTION:
			_handle_action_phase()
		BattlePhase.REACTION:
			_handle_reaction_phase()
		BattlePhase.END:
			_handle_end_phase()
	
	phase_changed.emit(new_phase)

func change_state(new_state: BattleState) -> void:
	if new_state == current_state:
		return
	
	var old_state = current_state
	current_state = new_state
	
	match new_state:
		BattleState.SETUP:
			_handle_setup_state()
		BattleState.ROUND:
			_handle_round_state()
		BattleState.CLEANUP:
			_handle_cleanup_state()
	
	state_changed.emit(new_state)

func activate_unit(unit: Character) -> void:
	if not unit in active_units:
		return
	
	current_unit = unit
	unit_activated.emit(unit)

func deactivate_unit(unit: Character) -> void:
	if unit != current_unit:
		return
	
	current_unit = null
	unit_deactivated.emit(unit)

func perform_action(unit: Character, action: UnitAction) -> void:
	if not _can_perform_action(unit, action):
		return
	
	var action_cost = _get_action_cost(action)
	action_points[unit] = action_points[unit] - action_cost
	
	_completed_actions[unit] = _completed_actions.get(unit, [])
	_completed_actions[unit].append(action)
	
	action_points_changed.emit(unit, action_points[unit])
	unit_action_completed.emit(unit, action)

func end_battle(victory: bool) -> void:
	is_battle_complete = true
	last_battle_results = {
		"victory": victory,
		"rounds": current_round,
		"units_remaining": active_units.size()
	}
	battle_ended.emit(victory)
	change_state(BattleState.CLEANUP)

func serialize() -> Dictionary:
	return {
		"current_state": current_state,
		"current_phase": current_phase,
		"current_round": current_round,
		"is_battle_complete": is_battle_complete,
		"last_battle_results": last_battle_results,
		"action_points": action_points,
		"completed_actions": _completed_actions
	}

func deserialize(data: Dictionary) -> void:
	current_state = data.get("current_state", BattleState.SETUP)
	current_phase = data.get("current_phase", BattlePhase.INITIATIVE)
	current_round = data.get("current_round", 1)
	is_battle_complete = data.get("is_battle_complete", false)
	last_battle_results = data.get("last_battle_results", {})
	action_points = data.get("action_points", {})
	_completed_actions = data.get("completed_actions", {})

# Phase handlers
func _handle_initiative_phase() -> void:
	_roll_initiative()
	_sort_units_by_initiative()
	if not active_units.is_empty():
		activate_unit(active_units[0])

func _handle_movement_phase() -> void:
	if current_unit:
		_process_unit_movement(current_unit)

func _handle_action_phase() -> void:
	if current_unit:
		_process_unit_actions(current_unit)

func _handle_reaction_phase() -> void:
	_process_reactions()

func _handle_end_phase() -> void:
	_cleanup_phase()
	if not is_battle_complete:
		current_round += 1
		round_ended.emit(current_round - 1)
		change_phase(BattlePhase.INITIATIVE)
		round_started.emit(current_round)

# State handlers
func _handle_setup_state() -> void:
	_initialize_units()
	change_phase(BattlePhase.INITIATIVE)

func _handle_round_state() -> void:
	if current_phase == BattlePhase.END:
		change_phase(BattlePhase.INITIATIVE)

func _handle_cleanup_state() -> void:
	_cleanup_battle()

# Helper functions
func _can_perform_action(unit: Character, action: UnitAction) -> bool:
	if not unit in active_units or unit != current_unit:
		return false
	
	if not action_points.has(unit) or action_points[unit] < _get_action_cost(action):
		return false
	
	return true

func _get_action_cost(action: UnitAction) -> int:
	match action:
		UnitAction.MOVE:
			return 1
		UnitAction.ATTACK:
			return 2
		UnitAction.DASH:
			return 2
		UnitAction.ITEMS:
			return 1
		UnitAction.SNAP_FIRE:
			return 1
		UnitAction.FREE_ACTION:
			return 0
		UnitAction.BRAWL:
			return 2
		_:
			return 1

func _roll_initiative() -> void:
	for unit in active_units:
		unit.roll_initiative()

func _sort_units_by_initiative() -> void:
	active_units.sort_custom(func(a, b): return a.initiative > b.initiative)

func _process_unit_movement(unit: Character) -> void:
	if not battlefield_manager:
		return
	
	var movement_points = unit.get_movement_points()
	battlefield_manager.highlight_movement_range(unit, movement_points)

func _process_unit_actions(unit: Character) -> void:
	if not combat_resolver:
		return
	
	var available_actions = _get_available_actions(unit)
	combat_resolver.set_available_actions(unit, available_actions)

func _process_reactions() -> void:
	for opportunity in _reaction_opportunities:
		reaction_opportunity.emit(opportunity.unit, opportunity.type, opportunity.source)

func _cleanup_phase() -> void:
	_reaction_opportunities.clear()
	if current_unit:
		deactivate_unit(current_unit)

func _cleanup_battle() -> void:
	active_units.clear()
	action_points.clear()
	_completed_actions.clear()
	_reaction_opportunities.clear()
	current_unit = null

func _get_available_actions(unit: Character) -> Array[UnitAction]:
	var available: Array[UnitAction] = []
	var points = action_points.get(unit, 0)
	
	for action in UnitAction.values():
		if points >= _get_action_cost(action):
			available.append(action)
	
	return available

# Signal handlers
func _on_unit_moved(unit: Character, from: Vector2i, to: Vector2i) -> void:
	if unit == current_unit:
		perform_action(unit, UnitAction.MOVE)

func _on_unit_added(unit: Character, position: Vector2i) -> void:
	if not unit in active_units:
		active_units.append(unit)
		action_points[unit] = unit.get_max_action_points()

func _on_unit_removed(unit: Character, position: Vector2i) -> void:
	if unit in active_units:
		active_units.erase(unit)
		action_points.erase(unit)
		if unit == current_unit:
			deactivate_unit(unit)

func _on_combat_resolved(attacker: Character, target: Character, result: Dictionary) -> void:
	if result.get("hit", false):
		combat_effect_triggered.emit("hit", attacker, target)
	if result.get("critical", false):
		combat_effect_triggered.emit("critical", attacker, target)
	if result.get("killed", false):
		combat_effect_triggered.emit("killed", attacker, target) 