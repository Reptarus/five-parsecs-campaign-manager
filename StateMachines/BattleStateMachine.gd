class_name BattleStateMachine
extends Node

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const Character = preload("res://Resources/CrewAndCharacters/Character.gd")

signal state_changed(new_state: int)  # BattleState

@export var game_state_manager: GameStateManager

enum BattleState {SETUP, ROUND, CLEANUP}
enum UnitAction {MOVE, ATTACK, DASH, ITEMS, SNAP_FIRE, FREE_ACTION, STUNNED, BRAWL, OTHER}

var current_battle_state: int = BattleState.SETUP
var current_round_phase: int = GlobalEnums.BattlePhase.REACTION_ROLL
var is_transitioning := false

# Add frame budgeting for state transitions
const MAX_TRANSITIONS_PER_FRAME := 3
var _pending_transitions: Array = []

func transition_to(new_state: int) -> void:
	if OS.get_name() == "Android":
		_pending_transitions.append(new_state)
		_process_pending_transitions()
	else:
		_direct_transition(new_state)

func _process_pending_transitions() -> void:
	var processed := 0
	while not _pending_transitions.is_empty() and processed < MAX_TRANSITIONS_PER_FRAME:
		var next_state = _pending_transitions.pop_front()
		_direct_transition(next_state)
		processed += 1

func _direct_transition(new_state: int) -> void:
	if is_transitioning:
		push_warning("State transition already in progress")
		return
	
	await _cleanup_current_state()
	current_battle_state = new_state
	await _initialize_new_state()
	
	state_changed.emit(new_state)

func transition_to_round_phase(new_phase: int) -> void:
	current_round_phase = new_phase
	match new_phase:
		GlobalEnums.BattlePhase.REACTION_ROLL:
			perform_reaction_roll()
		GlobalEnums.BattlePhase.QUICK_ACTIONS:
			handle_quick_actions()
		GlobalEnums.BattlePhase.ENEMY_ACTIONS:
			handle_enemy_actions()
		GlobalEnums.BattlePhase.SLOW_ACTIONS:
			handle_slow_actions()
		GlobalEnums.BattlePhase.END_PHASE:
			end_round()

func perform_unit_action(unit: Character, action: int) -> void:
	match action:
		UnitAction.MOVE:
			unit.move()
		UnitAction.ATTACK:
			unit.attack()
		UnitAction.DASH:
			unit.dash()
		UnitAction.ITEMS:
			unit.use_item()
		UnitAction.SNAP_FIRE:
			unit.snap_fire()
		UnitAction.FREE_ACTION:
			unit.free_action()
		UnitAction.STUNNED:
			unit.stunned_action()
		UnitAction.BRAWL:
			unit.brawl()
		UnitAction.OTHER:
			unit.other_action()

# State cleanup and initialization
func _cleanup_current_state() -> void:
	match current_battle_state:
		BattleState.SETUP:
			# Cleanup setup state
			pass
		BattleState.ROUND:
			# Cleanup round state
			pass
		BattleState.CLEANUP:
			# Cleanup cleanup state
			pass

func _initialize_new_state() -> void:
	match current_battle_state:
		BattleState.SETUP:
			setup_battle()
		BattleState.ROUND:
			start_round()
		BattleState.CLEANUP:
			cleanup_battle()

# Phase handlers
func setup_battle() -> void:
	# Implementation
	pass

func start_round() -> void:
	# Implementation
	pass

func cleanup_battle() -> void:
	# Implementation
	pass

func perform_reaction_roll() -> void:
	# Implementation
	pass

func handle_quick_actions() -> void:
	# Implementation
	pass

func handle_enemy_actions() -> void:
	# Implementation
	pass

func handle_slow_actions() -> void:
	# Implementation
	pass

func end_round() -> void:
	# Implementation
	pass
