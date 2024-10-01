class_name GameWorld
extends Node

# Signals
signal world_step_completed
@warning_ignore("unused_signal")
signal mission_selection_requested(available_missions: Array[Mission])
signal phase_completed
signal game_over
signal ui_update_requested
signal local_event_triggered(event_description: String)
signal economy_updated

# Constants
const BASE_UPKEEP_COST: int = 10
const ADDITIONAL_CREW_COST: int = 2
const LOCAL_EVENT_CHANCE: float = 0.2

# Variables
var game_state: GameState
var world_step: WorldStep
var world_economy_manager: WorldEconomyManager
var world_generator: WorldGenerator

var _mission_selection_scene = preload("res://Scenes/campaign/NewCampaignSetup/MissionSelectionUI.tscn")

# Initialization and Setup
func _init(_game_state: GameState) -> void:
	game_state = _game_state
	world_step = WorldStep.new(game_state)
	world_economy_manager = WorldEconomyManager.new(game_state.current_location, game_state.economy_manager)
	world_generator = WorldGenerator.new()
	world_generator.initialize(game_state)

func _ready() -> void:
	world_step.phase_completed.connect(_on_phase_completed)
	world_step.mission_selection_requested.connect(_on_mission_selection_requested)
	world_economy_manager.local_event_triggered.connect(_on_local_event_triggered)
	world_economy_manager.economy_updated.connect(_on_economy_updated)

# Public Methods
func execute_world_step() -> void:
	print("Beginning world step...")
	
	_handle_upkeep_and_repairs()
	world_step.assign_and_resolve_crew_tasks()
	world_step.determine_job_offers()
	world_step.assign_equipment()
	world_step.resolve_rumors()
	_update_local_economy()
	world_step.choose_battle()
	
	print("World step completed.")
	world_step_completed.emit()

func get_world_traits() -> Array[String]:
	return game_state.current_location.get_traits()

func generate_new_world() -> void:
	var new_world = world_generator.generate_world()
	game_state.set_current_location(new_world)
	world_economy_manager = WorldEconomyManager.new(new_world, game_state.economy_manager)

func schedule_world_invasion() -> void:
	world_generator.schedule_world_invasion()

# Serialization
func serialize() -> Dictionary:
	return {
		"game_state": game_state.serialize(),
		"world_economy": world_economy_manager.serialize(),
		"world_generator": world_generator.serialize()
	}

static func deserialize(data: Dictionary) -> GameWorld:
	var new_game_state = GameState.new()
	if new_game_state.deserialize(data["game_state"]):
		var world = GameWorld.new(new_game_state)
		world.world_economy_manager.deserialize(data["world_economy"])
		world.world_generator.deserialize(data["world_generator"])
		return world
	else:
		push_error("Failed to deserialize GameStateManager")
		return null

# Private Methods
func _handle_upkeep_and_repairs() -> void:
	var upkeep_cost = world_economy_manager.calculate_upkeep()
	if world_economy_manager.pay_upkeep(game_state.current_crew):
		print("Upkeep paid: %d credits" % upkeep_cost)
	else:
		print("Not enough credits to pay upkeep. Crew morale decreases.")
		game_state.current_crew.decrease_morale()
	
	var repair_amount = game_state.current_crew.ship.auto_repair()
	print("Ship auto-repaired %d hull points" % repair_amount)

func _update_local_economy() -> void:
	world_economy_manager.update_local_economy()

# Signal Handlers
func _on_mission_selection_requested(available_missions: Array[Mission]) -> void:
	var mission_selection_instance = _mission_selection_scene.instantiate()
	mission_selection_instance.populate_missions(available_missions)
	mission_selection_instance.mission_selected.connect(_on_mission_selected)
	add_child(mission_selection_instance)
	mission_selection_instance.get_node("PopupPanel").popup_centered()

func _on_mission_selected(mission: Mission) -> void:
	game_state.current_mission = mission
	print("Selected mission: ", mission.title)
	# Implement any additional logic needed when a mission is selected

func _on_phase_completed() -> void:
	print("Phase completed")
	phase_completed.emit()
	
	game_state.current_turn += 1
	
	if game_state.check_end_game_conditions():
		game_over.emit()
		return
	
	world_step.start_next_phase()
	
	ui_update_requested.emit()

func _on_local_event_triggered(event_description: String) -> void:
	print("Local event: ", event_description)
	local_event_triggered.emit(event_description)

func _on_economy_updated() -> void:
	print("Local economy updated")
	economy_updated.emit()
