# PreBattleLoop.gd
extends Node

## Dependencies
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Management/CharacterDataManager.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const UnifiedTerrainSystem = preload("res://src/core/terrain/UnifiedTerrainSystem.gd")
const PreBattleUI = preload("res://src/ui/screens/battle/PreBattleUI.gd")

## Optional dependencies that may not exist
var _terrain_system_script = preload("res://src/core/terrain/UnifiedTerrainSystem.gd") if FileAccess.file_exists("res://src/core/terrain/UnifiedTerrainSystem.gd") else null
var _battle_ui_script = preload("res://src/ui/screens/battle/PreBattleUI.gd") if FileAccess.file_exists("res://src/ui/screens/battle/PreBattleUI.gd") else null

## Signals
signal battle_ready(mission_data: Dictionary)
signal phase_completed
signal crew_selection_changed(crew: Array[Character])
signal deployment_updated(zones: Array[Dictionary])
signal error_occurred(message: String)
signal pre_battle_completed

## Node references
@onready var ui: Node = $UI # Will be cast to PreBattleUI if available
@onready var terrain_system: Node = $TerrainSystem # Will be cast to UnifiedTerrainSystem if available

## Mission data
var current_mission: StoryQuestData
var selected_crew: Array[Character]
var deployment_zones: Array[Dictionary]
var game_state: FiveParsecsGameState

func _init() -> void:
	selected_crew = []
	deployment_zones = []

func _ready() -> void:
	_initialize_systems()
	_connect_signals()

## Initialize required systems
func _initialize_systems() -> void:
	if not ui or not terrain_system:
		error_occurred.emit("Required nodes not found")
		push_error("PreBattleLoop: Required nodes not found")
		return

	if _battle_ui_script and ui:
		ui.set_script(_battle_ui_script)
	
	if _terrain_system_script and terrain_system:
		terrain_system.set_script(_terrain_system_script)

## Connect to UI signals
func _connect_signals() -> void:
	if not ui:
		push_error("PreBattleLoop: UI node not found")
		return

	# Connect UI signals using safe connection methods
	_connect_ui_signal("crew_selected", _on_crew_selected)
	_connect_ui_signal("deployment_confirmed", _on_deployment_confirmed)

## Safe signal connection helper
func _connect_ui_signal(signal_name: String, callback: Callable) -> void:
	if not ui:
		push_error("PreBattleLoop: Cannot connect signal '%s' - UI node not found" % signal_name)
		return
		
	if not ui.has_signal(signal_name):
		push_warning("PreBattleLoop: UI missing signal '%s'" % signal_name)
		return
		
	var signal_is_connected := false
	for connection in ui.get_signal_connection_list(signal_name):
		if connection.callable.get_method() == callback.get_method():
			signal_is_connected = true
			break
			
	if not signal_is_connected:
		ui.connect(signal_name, callback)

## Start the pre-battle phase with mission data
func start_phase(mission: StoryQuestData, state: FiveParsecsGameState) -> void:
	if not mission or not state:
		error_occurred.emit("Invalid mission or game state")
		push_error("PreBattleLoop: Invalid mission or game state")
		return
		
	if not _validate_mission(mission):
		error_occurred.emit("Invalid mission data")
		push_error("PreBattleLoop: Invalid mission data")
		return
		
	current_mission = mission
	game_state = state
	_setup_battle_preview()
	_setup_crew_selection()

## Safe Property Access Methods
func _get_mission_property(mission: StoryQuestData, property: String, default_value = null) -> Variant:
	if not mission:
		push_error("Trying to access property '%s' on null mission" % property)
		return default_value
	if not property in mission:
		return default_value
	return mission.get(property)

func _get_mission_title(mission: StoryQuestData) -> String:
	return _get_mission_property(mission, "title", "Unknown Mission")

func _get_mission_description(mission: StoryQuestData) -> String:
	return _get_mission_property(mission, "description", "No description available")

func _get_mission_battle_type(mission: StoryQuestData) -> int:
	return _get_mission_property(mission, "battle_type", GameEnums.BattleType.NONE)

func _get_mission_enemy_force(mission: StoryQuestData) -> Array:
	return _get_mission_property(mission, "enemy_force", [])

func _get_mission_deployment_rules(mission: StoryQuestData) -> Dictionary:
	return _get_mission_property(mission, "deployment_rules", {})

func _get_mission_victory_conditions(mission: StoryQuestData) -> Array:
	return _get_mission_property(mission, "victory_conditions", [])

func _get_mission_special_conditions(mission: StoryQuestData) -> Array:
	return _get_mission_property(mission, "special_conditions", [])

func _get_mission_difficulty(mission: StoryQuestData) -> int:
	return _get_mission_property(mission, "difficulty", GameEnums.DifficultyLevel.NORMAL)

## Setup the battle preview
func _setup_battle_preview() -> void:
	if not ui or not current_mission:
		error_occurred.emit("Missing UI or mission data")
		return
		
	var preview_data := {
		"title": _get_mission_title(current_mission),
		"description": _get_mission_description(current_mission),
		"battle_type": _get_mission_battle_type(current_mission),
		"enemy_force": _get_mission_enemy_force(current_mission),
		"deployment_rules": _get_mission_deployment_rules(current_mission),
		"victory_conditions": _get_mission_victory_conditions(current_mission),
		"special_conditions": _get_mission_special_conditions(current_mission),
		"difficulty": _get_mission_difficulty(current_mission)
	}
	
	if ui.has_method("setup_preview"):
		ui.setup_preview(preview_data)

## Setup crew selection interface
func _setup_crew_selection() -> void:
	if not ui or not game_state:
		error_occurred.emit("Missing UI or game state")
		return
		
	var available_crew: Array[Character] = game_state.get_crew()
	if ui.has_method("setup_crew_selection"):
		ui.setup_crew_selection(available_crew)

## Handle crew selection
func _on_crew_selected(crew: Array[Character]) -> void:
	selected_crew = crew
	crew_selection_changed.emit(crew)
	_validate_battle_readiness()

## Handle deployment confirmation
func _on_deployment_confirmed() -> void:
	if _validate_battle_readiness():
		var battle_data := _prepare_battle_data()
		battle_ready.emit(battle_data)
		phase_completed.emit()

## Validate if battle can begin
func _validate_battle_readiness() -> bool:
	if selected_crew.is_empty():
		error_occurred.emit("No crew selected")
		return false
		
	if not current_mission:
		error_occurred.emit("No mission data")
		return false
		
	if not terrain_system or not terrain_system.has_method("is_terrain_ready") or not terrain_system.is_terrain_ready():
		error_occurred.emit("Terrain not ready")
		return false
		
	return true

## Prepare battle data for next phase
func _prepare_battle_data() -> Dictionary:
	var terrain_data := {}
	if terrain_system and terrain_system.has_method("get_terrain_data"):
		terrain_data = terrain_system.get_terrain_data()
	
	return {
		"mission": current_mission.serialize() if current_mission else {},
		"crew": selected_crew,
		"deployment_zones": deployment_zones,
		"terrain_data": terrain_data,
		"battle_type": _get_mission_battle_type(current_mission),
		"difficulty": _get_mission_difficulty(current_mission)
	}

## Update deployment zones
func update_deployment_zones(zones: Array[Dictionary]) -> void:
	deployment_zones = zones
	deployment_updated.emit(zones)

## Get current mission
func get_current_mission() -> StoryQuestData:
	return current_mission

## Get selected crew
func get_selected_crew() -> Array[Character]:
	return selected_crew

## Get deployment zones
func get_deployment_zones() -> Array[Dictionary]:
	return deployment_zones

## Cleanup
func cleanup() -> void:
	current_mission = null
	selected_crew.clear()
	deployment_zones.clear()
	game_state = null

## Validate mission data structure
func _validate_mission(mission: StoryQuestData) -> bool:
	if not mission:
		return false
		
	if _get_mission_battle_type(mission) == GameEnums.BattleType.NONE:
		return false
		
	if _get_mission_enemy_force(mission).is_empty():
		return false
		
	return true
