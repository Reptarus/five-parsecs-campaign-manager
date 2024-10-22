class_name World
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

# Properties
var world_name: String = ""
var terrain_type: GlobalEnums.TerrainType = GlobalEnums.TerrainType.CITY
var faction_type: GlobalEnums.FactionType = GlobalEnums.FactionType.NEUTRAL
var strife_type: GlobalEnums.StrifeType = GlobalEnums.StrifeType.RESOURCE_CONFLICT

# Variables
var mock_game_state: MockGameState
var world_step: WorldPhaseUI
var world_economy_manager: WorldEconomyManager
var world_generator: WorldGenerator
var game_state: MockGameState

var _mission_selection_scene = preload("res://Resources/WorldPhase/MissionSelectionUI.tscn")

# Initialization and Setup
func _init(param = null) -> void:
	if param is MockGameState:
		_init_with_mock_game_state(param)
	elif param is Dictionary:
		_init_with_dict(param)
	else:
		push_error("Invalid parameter type for World constructor")

func _init_with_mock_game_state(_game_state_param: MockGameState) -> void:
	mock_game_state = _game_state_param
	game_state = mock_game_state.get_internal_game_state()
	world_step = WorldPhaseUI.new()
	
	var current_location = game_state.current_location
	var economy_manager = game_state.economy_manager
	
	if current_location != null and economy_manager != null:
		world_economy_manager = WorldEconomyManager.new(current_location, economy_manager)
	else:
		push_error("Missing current_location or economy_manager in game state")
	
	world_generator = mock_game_state.world_generator

func _init_with_dict(world_data: Dictionary) -> void:
	world_name = world_data.get("name", "")
	terrain_type = world_data.get("type", GlobalEnums.TerrainType.CITY)
	faction_type = world_data.get("faction", GlobalEnums.FactionType.NEUTRAL)
	strife_type = world_data.get("instability", GlobalEnums.StrifeType.RESOURCE_CONFLICT)
	# Initialize other necessary properties here

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

func get_world_traits() -> Array[GlobalEnums.WorldTrait]:
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

static func deserialize(data: Dictionary) -> World:
	var new_mock_game_state = MockGameState.new()
	new_mock_game_state.deserialize(data["game_state"])
	var world = World.new(new_mock_game_state)
	world.world_economy_manager.deserialize(data["world_economy"])
	world.world_generator.deserialize(data["world_generator"])
	return world

# Private Methods
func _handle_upkeep_and_repairs() -> void:
	var upkeep_cost = world_economy_manager.calculate_upkeep()
	if world_economy_manager.pay_upkeep(upkeep_cost):
		print("Upkeep paid: %d credits" % upkeep_cost)
	else:
		print("Not enough credits to pay upkeep. Crew morale decreases.")
		game_state.crew.get_characters()[0].decrease_morale()  # Assuming the first crew member for simplicity
	
	var repair_amount = game_state.current_ship.auto_repair()
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
	
	game_state.campaign_turn += 1
	
	if game_state.check_victory_conditions():
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

func get_terrain_type() -> GlobalEnums.TerrainType:
	return terrain_type

func get_faction_type() -> GlobalEnums.FactionType:
	return faction_type

func get_strife_type() -> GlobalEnums.StrifeType:
	return strife_type
