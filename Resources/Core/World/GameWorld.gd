## GameWorld class manages the game world state and progression
class_name GameWorld
extends Node

## Dependencies
const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")
const GameStateManager = preload("res://Resources/Core/GameState/GameStateManager.gd")
const EventManager = preload("res://Resources/Core/Managers/EventManager.gd")

## World state
var current_location: Location = null
var visited_locations: Array = []
var strife_level: GameEnums.StrifeType = GameEnums.StrifeType.NONE
var peace_timer: int = 0

## Systems
var event_manager: EventManager = null
var state_manager: GameStateManager = null

## Initialize the game world
func initialize() -> void:
	state_manager = GameStateManager.new()
	event_manager = EventManager.new()
	
	state_manager.initialize()
	if event_manager:
		event_manager.initialize(state_manager.get_game_state())
	
	_setup_initial_world()
	_initialize_strife_system()
	_connect_signals()

## Connect signals
func _connect_signals() -> void:
	if event_manager:
		event_manager.event_triggered.connect(_on_event_triggered)
		event_manager.event_resolved.connect(_on_event_resolved)

## Setup the initial world state
func _setup_initial_world() -> void:
	current_location = Location.new()
	visited_locations = []
	strife_level = GameEnums.StrifeType.NONE
	peace_timer = 0

## Initialize the strife system
func _initialize_strife_system() -> void:
	# Start with base peace time
	peace_timer = 10
	_update_strife_state()

## Update the world state
func update_world() -> void:
	_update_strife_state()
	_update_locations()
	if event_manager:
		event_manager.update()

## Update the strife state
func _update_strife_state() -> void:
	if peace_timer > 0:
		peace_timer -= 1
		if peace_timer <= 0:
			_trigger_strife_event()
	
	if strife_level != GameEnums.StrifeType.NONE:
		_handle_active_strife()

## Handle active strife in the world
func _handle_active_strife() -> void:
	if not current_location:
		return
		
	# Update location based on strife
	current_location.update_strife_effects(strife_level)
	
	# Check for strife resolution
	if _check_strife_resolution():
		_resolve_strife()

## Check if strife should be resolved
func _check_strife_resolution() -> bool:
	return strife_level != GameEnums.StrifeType.NONE and randf() < 0.1  # 10% chance per update

## Resolve current strife
func _resolve_strife() -> void:
	strife_level = GameEnums.StrifeType.NONE
	peace_timer = randi() % 10 + 5  # 5-15 turns of peace

## Trigger a strife event
func _trigger_strife_event() -> void:
	var strife_types = [
		GameEnums.StrifeType.RESOURCE_CONFLICT,
		GameEnums.StrifeType.POLITICAL_UNREST,
		GameEnums.StrifeType.CRIMINAL_UPRISING
	]
	strife_level = strife_types[randi() % strife_types.size()]
	
	# Trigger corresponding global event
	if event_manager:
		match strife_level:
			GameEnums.StrifeType.RESOURCE_CONFLICT:
				event_manager.trigger_event(GameEnums.GlobalEvent.RESOURCE_CONFLICT)
			GameEnums.StrifeType.POLITICAL_UNREST:
				event_manager.trigger_event(GameEnums.GlobalEvent.POLITICAL_UNREST)
			GameEnums.StrifeType.CRIMINAL_UPRISING:
				event_manager.trigger_event(GameEnums.GlobalEvent.CRIMINAL_UPRISING)

## Update all locations
func _update_locations() -> void:
	if current_location:
		current_location.update()
	
	for location in visited_locations:
		location.update()

## Event handlers
func _on_event_triggered(event_type: GameEnums.GlobalEvent) -> void:
	match event_type:
		GameEnums.GlobalEvent.RESOURCE_CONFLICT:
			strife_level = GameEnums.StrifeType.RESOURCE_CONFLICT
		GameEnums.GlobalEvent.POLITICAL_UNREST:
			strife_level = GameEnums.StrifeType.POLITICAL_UNREST
		GameEnums.GlobalEvent.CRIMINAL_UPRISING:
			strife_level = GameEnums.StrifeType.CRIMINAL_UPRISING
		GameEnums.GlobalEvent.CORPORATE_WAR:
			strife_level = GameEnums.StrifeType.CORPORATE_WAR
		GameEnums.GlobalEvent.CIVIL_WAR:
			strife_level = GameEnums.StrifeType.CIVIL_WAR
		GameEnums.GlobalEvent.INVASION:
			strife_level = GameEnums.StrifeType.INVASION

func _on_event_resolved(event_type: GameEnums.GlobalEvent) -> void:
	# Check if the resolved event matches current strife
	var matching_strife = match_event_to_strife(event_type)
	if matching_strife == strife_level:
		_resolve_strife()

## Helper function to match global events to strife types
func match_event_to_strife(event_type: GameEnums.GlobalEvent) -> GameEnums.StrifeType:
	match event_type:
		GameEnums.GlobalEvent.RESOURCE_CONFLICT:
			return GameEnums.StrifeType.RESOURCE_CONFLICT
		GameEnums.GlobalEvent.POLITICAL_UNREST:
			return GameEnums.StrifeType.POLITICAL_UNREST
		GameEnums.GlobalEvent.CRIMINAL_UPRISING:
			return GameEnums.StrifeType.CRIMINAL_UPRISING
		GameEnums.GlobalEvent.CORPORATE_WAR:
			return GameEnums.StrifeType.CORPORATE_WAR
		GameEnums.GlobalEvent.CIVIL_WAR:
			return GameEnums.StrifeType.CIVIL_WAR
		GameEnums.GlobalEvent.INVASION:
			return GameEnums.StrifeType.INVASION
		_:
			return GameEnums.StrifeType.NONE

## Get the current strife description
func get_strife_description() -> String:
	match strife_level:
		GameEnums.StrifeType.NONE:
			return "Peace"
		GameEnums.StrifeType.RESOURCE_CONFLICT:
			return "Resource Conflict"
		GameEnums.StrifeType.POLITICAL_UNREST:
			return "Political Unrest"
		GameEnums.StrifeType.CRIMINAL_UPRISING:
			return "Criminal Uprising"
		GameEnums.StrifeType.CORPORATE_WAR:
			return "Corporate War"
		GameEnums.StrifeType.CIVIL_WAR:
			return "Civil War"
		GameEnums.StrifeType.INVASION:
			return "Invasion"
		_:
			return "Unknown"

## Save the world state
func serialize() -> Dictionary:
	var data := {
		"strife_level": strife_level,
		"peace_timer": peace_timer,
		"current_location": current_location.serialize() if current_location else null,
		"visited_locations": [],
		"event_manager": event_manager.serialize() if event_manager else {}
	}
	
	for location in visited_locations:
		data.visited_locations.append(location.serialize())
	
	return data

## Load the world state
func deserialize(data: Dictionary) -> void:
	strife_level = data.get("strife_level", GameEnums.StrifeType.NONE)
	peace_timer = data.get("peace_timer", 0)
	
	if data.has("current_location") and data.current_location:
		current_location = Location.new()
		current_location.deserialize(data.current_location)
	
	visited_locations.clear()
	for loc_data in data.get("visited_locations", []):
		var location := Location.new()
		location.deserialize(loc_data)
		visited_locations.append(location)
		
	if event_manager and data.has("event_manager"):
		event_manager.deserialize(data.event_manager)