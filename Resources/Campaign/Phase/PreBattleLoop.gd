# PreBattleLoop.gd
class_name PreBattleLoop
extends Node

## Dependencies
const GameEnums = preload("../../Core/Systems/GlobalEnums.gd")
const StoryQuestData = preload("../../Core/Story/StoryQuestData.gd")
const GameState = preload("../../Core/GameState/GameState.gd")
const Character = preload("../../Core/Character/Base/Character.gd")

## Optional dependencies that may not exist
var _terrain_system_script = preload("../../Battle/Terrain/UnifiedTerrainSystem.gd") if FileAccess.file_exists("res://Resources/Battle/Terrain/UnifiedTerrainSystem.gd") else null
var _battle_ui_script = preload("../../Battle/UI/PreBattleUI.gd") if FileAccess.file_exists("res://Resources/Battle/UI/PreBattleUI.gd") else null

## Signals
signal battle_ready(mission_data: Dictionary)
signal phase_completed
signal crew_selection_changed(crew: Array[Character])
signal deployment_updated(zones: Array[Dictionary])
signal error_occurred(message: String)

## Node references
@onready var ui: Node = $UI  # Will be cast to PreBattleUI if available
@onready var terrain_system: Node = $TerrainSystem  # Will be cast to UnifiedTerrainSystem if available

## Mission data
var current_mission: StoryQuestData
var selected_crew: Array[Character]
var deployment_zones: Array[Dictionary]
var game_state: GameState

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
		return

	if ui.has_signal("crew_selected") and not ui.crew_selected.is_connected(_on_crew_selected):
		ui.crew_selected.connect(_on_crew_selected)
	if ui.has_signal("deployment_confirmed") and not ui.deployment_confirmed.is_connected(_on_deployment_confirmed):
		ui.deployment_confirmed.connect(_on_deployment_confirmed)

## Start the pre-battle phase with mission data
func start_phase(mission: StoryQuestData, state: GameState) -> void:
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

## Validate mission data structure
func _validate_mission(mission: StoryQuestData) -> bool:
	if not mission:
		return false
		
	if not mission.battle_type in GameEnums.BattleType.values():
		return false
		
	if mission.enemy_force.is_empty():
		return false
		
	return true

## Setup the battle preview
func _setup_battle_preview() -> void:
	if not ui or not current_mission:
		error_occurred.emit("Missing UI or mission data")
		return
		
	var preview_data := {
		"title": current_mission.title,
		"description": current_mission.description,
		"battle_type": current_mission.battle_type,
		"enemy_force": current_mission.enemy_force,
		"deployment_rules": current_mission.deployment_rules,
		"victory_conditions": current_mission.victory_conditions,
		"special_conditions": current_mission.special_conditions,
		"difficulty": current_mission.difficulty
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
		"mission": current_mission.serialize(),
		"crew": selected_crew,
		"deployment_zones": deployment_zones,
		"terrain_data": terrain_data,
		"battle_type": current_mission.battle_type,
		"difficulty": current_mission.difficulty
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
