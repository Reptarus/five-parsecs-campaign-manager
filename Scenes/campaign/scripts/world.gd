class_name GameWorld
extends Node

signal world_step_completed
signal mission_selection_requested(available_missions: Array[Mission])
signal phase_completed
signal game_over
signal ui_update_requested

const BASE_UPKEEP_COST: int = 10
const ADDITIONAL_CREW_COST: int = 2

var game_state: GameState
var world_step: WorldStep

var _mission_selection_scene = preload("res://Scripts/Missions/MissionSelection.gd")

func _init(_game_state: GameState) -> void:
	game_state = _game_state
	world_step = WorldStep.new(game_state)

func _ready() -> void:
	world_step.phase_completed.connect(_on_phase_completed)
	world_step.mission_selection_requested.connect(_on_mission_selection_requested)

# Public methods
func execute_world_step() -> void:
	print("Beginning world step...")
	
	_handle_upkeep_and_repairs()
	world_step.assign_and_resolve_crew_tasks()
	world_step.determine_job_offers()
	world_step.assign_equipment()
	world_step.resolve_rumors()
	world_step.choose_battle()
	
	print("World step completed.")
	world_step_completed.emit()

func get_world_traits() -> Array[String]:
	return game_state.current_location.get_traits()

func serialize() -> Dictionary:
	return {
		"game_state": game_state.serialize()
	}

static func deserialize(data: Dictionary) -> GameWorld:
	var world = GameWorld.new(GameState.deserialize(data["game_state"]))
	return world

# Private methods
func _handle_upkeep_and_repairs() -> void:
	var upkeep_cost = _calculate_upkeep_cost()
	if game_state.current_crew.pay_upkeep(upkeep_cost):
		print("Upkeep paid: %d credits" % upkeep_cost)
	else:
		print("Not enough credits to pay upkeep. Crew morale decreases.")
		game_state.current_crew.decrease_morale()
	
	var repair_amount = game_state.current_crew.ship.auto_repair()
	print("Ship auto-repaired %d hull points" % repair_amount)

func _calculate_upkeep_cost() -> int:
	var crew_size = game_state.current_crew.get_member_count()
	var additional_cost = max(0, crew_size - 6) * ADDITIONAL_CREW_COST
	return BASE_UPKEEP_COST + additional_cost

# ... (other private methods)

func _on_phase_completed() -> void:
	print("Phase completed")
	
	game_state.current_turn += 1
	
	if game_state.check_end_game_conditions():
		game_over.emit()
		return
	
	world_step.start_next_phase()
	
	ui_update_requested.emit()

func _on_mission_selection_requested(available_missions: Array) -> void:
	var mission_selection = _mission_selection_scene.instantiate()
	add_child(mission_selection)
	mission_selection.populate_missions(available_missions)
	mission_selection.mission_selected.connect(_on_mission_selected)

func _on_mission_selected(mission: Mission) -> void:
	game_state.current_mission = mission
	game_state.remove_mission(mission)
	phase_completed.emit()
