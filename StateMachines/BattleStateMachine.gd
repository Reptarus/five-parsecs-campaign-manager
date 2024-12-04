class_name BattleStateMachine
extends Node

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const Character = preload("res://Resources/CrewAndCharacters/Character.gd")

signal state_changed(new_state: int)  # BattleState
signal phase_changed(new_phase: int)  # BattlePhase
signal round_started(round_number: int)
signal round_ended(round_number: int)
signal unit_action_completed(unit: Character, action: int)
signal battle_ended(victory: bool)

@export var game_state_manager: GameStateManager

enum BattleState {SETUP, ROUND, CLEANUP}
enum BattlePhase {INITIATIVE, MOVEMENT, ACTION, REACTION, END}
enum UnitAction {MOVE, ATTACK, DASH, ITEMS, SNAP_FIRE, FREE_ACTION, STUNNED, BRAWL, OTHER}

var current_state: BattleState = BattleState.SETUP
var current_phase: BattlePhase = BattlePhase.INITIATIVE
var current_round: int = 1
var is_battle_complete: bool = false

# Track unit actions
var _completed_actions: Dictionary = {}
var _reaction_opportunities: Array[Dictionary] = []

func _ready() -> void:
	if not game_state_manager:
		push_error("BattleStateMachine requires GameStateManager")

func start_battle() -> void:
	current_state = BattleState.SETUP
	current_round = 1
	is_battle_complete = false
	_completed_actions.clear()
	transition_to(BattleState.ROUND)

func transition_to(new_state: BattleState) -> void:
	if new_state == current_state:
		return
		
	match new_state:
		BattleState.SETUP:
			await _handle_setup_state()
		BattleState.ROUND:
			await _handle_round_state()
		BattleState.CLEANUP:
			await _handle_cleanup_state()
	
	current_state = new_state
	state_changed.emit(new_state)

func transition_to_phase(new_phase: BattlePhase) -> void:
	if new_phase == current_phase:
		return
		
	match new_phase:
		BattlePhase.INITIATIVE:
			await _handle_initiative_phase()
		BattlePhase.MOVEMENT:
			await _handle_movement_phase()
		BattlePhase.ACTION:
			await _handle_action_phase()
		BattlePhase.REACTION:
			await _handle_reaction_phase()
		BattlePhase.END:
			await _handle_end_phase()
	
	current_phase = new_phase
	phase_changed.emit(new_phase)

func _handle_setup_state() -> void:
	# Initialize battle setup
	_completed_actions.clear()
	_reaction_opportunities.clear()
	current_phase = BattlePhase.INITIATIVE

func _handle_round_state() -> void:
	round_started.emit(current_round)
	await transition_to_phase(BattlePhase.INITIATIVE)

func _handle_cleanup_state() -> void:
	if is_battle_complete:
		var victory = game_state_manager.check_victory_conditions()
		battle_ended.emit(victory)

func _handle_initiative_phase() -> void:
	var units = game_state_manager.get_all_units()
	units.sort_custom(func(a, b): return a.get_initiative() > b.get_initiative())
	
	for unit in units:
		unit.reset_actions()
	
	await transition_to_phase(BattlePhase.MOVEMENT)

func _handle_movement_phase() -> void:
	var units = game_state_manager.get_all_units()
	
	for unit in units:
		if unit.can_move():
			await unit.handle_movement()
			_completed_actions[unit] = _completed_actions.get(unit, [])
			_completed_actions[unit].append(UnitAction.MOVE)
	
	await transition_to_phase(BattlePhase.ACTION)

func _handle_action_phase() -> void:
	var units = game_state_manager.get_all_units()
	
	for unit in units:
		if unit.can_act():
			var action = await unit.decide_action()
			await _execute_unit_action(unit, action)
	
	await transition_to_phase(BattlePhase.REACTION)

func _handle_reaction_phase() -> void:
	while not _reaction_opportunities.is_empty():
		var reaction = _reaction_opportunities.pop_front()
		await _handle_reaction(reaction)
	
	await transition_to_phase(BattlePhase.END)

func _handle_end_phase() -> void:
	if game_state_manager.check_battle_end():
		is_battle_complete = true
		transition_to(BattleState.CLEANUP)
	else:
		current_round += 1
		round_ended.emit(current_round - 1)
		transition_to(BattleState.ROUND)

func _execute_unit_action(unit: Character, action: int) -> void:
	_completed_actions[unit] = _completed_actions.get(unit, [])
	_completed_actions[unit].append(action)
	
	match action:
		UnitAction.ATTACK:
			await unit.perform_attack()
		UnitAction.DASH:
			await unit.perform_dash()
		UnitAction.ITEMS:
			await unit.use_item()
		UnitAction.SNAP_FIRE:
			await unit.perform_snap_fire()
		UnitAction.BRAWL:
			await unit.perform_brawl()
		_:
			await unit.perform_other_action()
	
	unit_action_completed.emit(unit, action)

func _handle_reaction(reaction: Dictionary) -> void:
	var reactor = reaction.get("unit") as Character
	var trigger = reaction.get("trigger")
	var action = reaction.get("action")
	
	if reactor and reactor.can_react():
		await _execute_unit_action(reactor, action)

func add_reaction_opportunity(unit: Character, trigger: String, action: int) -> void:
	_reaction_opportunities.append({
		"unit": unit,
		"trigger": trigger,
		"action": action
	})

func get_unit_actions(unit: Character) -> Array:
	return _completed_actions.get(unit, [])

func has_unit_performed_action(unit: Character, action: int) -> bool:
	return action in get_unit_actions(unit)
