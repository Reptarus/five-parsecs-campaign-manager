# PreBattleLoop.gd
extends Node

## Dependencies
# GlobalEnums available as autoload singleton
const CoreGameState = preload("res://src/core/state/GameState.gd")
# Character/CharacterDataManager reference removed - file does not exist
const FPCMCharacter = preload("res://src/core/character/Character.gd")
const MissionSystem = preload("res://src/core/systems/Mission.gd")
const FPCMTerrainSystem = preload("res://src/core/terrain/UnifiedTerrainSystem.gd")
const BattleUI = preload("res://src/ui/screens/battle/PreBattleUI.gd")

## Optional dependencies that may not exist
var _terrain_system_script: Resource = preload("res://src/core/terrain/UnifiedTerrainSystem.gd") if FileAccess.file_exists("res://src/core/terrain/UnifiedTerrainSystem.gd") else null
var _battle_ui_script: Resource = preload("res://src/ui/screens/battle/PreBattleUI.gd") if FileAccess.file_exists("res://src/ui/screens/battle/PreBattleUI.gd") else null

## Signals
signal battle_ready(mission_data: Dictionary)
signal phase_completed
signal crew_selection_changed(crew: Array)
signal deployment_updated(zones: Array[Dictionary])
signal error_occurred(message: String)
signal pre_battle_completed
signal initiative_rolled(seized: bool, roll_result: int, savvy_bonus: int)
signal equipment_phase_started()
signal equipment_locked()

## Node references
@onready var ui: Node = $UI # Will be cast to PreBattleUI if available
@onready var terrain_system: Node = $TerrainSystem # Will be cast to UnifiedTerrainSystem if available

## Mission data
var current_mission: StoryQuestData
var selected_crew: Array
var deployment_zones: Array[Dictionary]
var game_state: CoreGameState

## Initiative state
var initiative_seized: bool = false
var initiative_roll_result: int = 0
var initiative_savvy_bonus: int = 0

## PHASE 3: Equipment management state
var _equipment_is_locked: bool = false
var equipment_manager: Node = null

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
	
	# PHASE 3: Connect to EquipmentManager
	equipment_manager = get_node_or_null("/root/EquipmentManager")
	if equipment_manager:
		print("PreBattleLoop: Connected to EquipmentManager")

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
## Accepts either StoryQuestData Resource or Dictionary for flexibility
func start_phase(mission: Variant, state: Variant) -> void:
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
## All methods accept Variant (StoryQuestData Resource or Dictionary)
func _get_mission_property(mission: Variant, property: String, default_value: Variant = null) -> Variant:
	if not mission:
		push_error("Trying to access property '%s' on null mission" % property)
		return default_value
	if not property in mission:
		return default_value

	return mission.get(property)

func _get_mission_title(mission: Variant) -> String:
	return _get_mission_property(mission, "title", "Unknown Mission")

func _get_mission_description(mission: Variant) -> String:
	return _get_mission_property(mission, "description", "No description available")

func _get_mission_battle_type(mission: Variant) -> int:
	return _get_mission_property(mission, "battle_type", GlobalEnums.BattleType.NONE)

func _get_mission_enemy_force(mission: Variant) -> Array:
	return _get_mission_property(mission, "enemy_force", [])

func _get_mission_deployment_rules(mission: Variant) -> Dictionary:
	return _get_mission_property(mission, "deployment_rules", {})

func _get_mission_victory_conditions(mission: Variant) -> Array:
	return _get_mission_property(mission, "victory_conditions", [])

func _get_mission_special_conditions(mission: Variant) -> Array:
	return _get_mission_property(mission, "special_conditions", [])

func _get_mission_difficulty(mission: Variant) -> int:
	return _get_mission_property(mission, "difficulty", GlobalEnums.DifficultyLevel.STANDARD)

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

	if ui and ui.has_method("setup_preview"):
		ui.setup_preview(preview_data)

## Setup crew selection interface
func _setup_crew_selection() -> void:
	if not ui or not game_state:
		error_occurred.emit("Missing UI or game state")
		return

	var available_crew: Array[Character] = game_state.get_crew()
	if ui and ui.has_method("setup_crew_selection"):
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
	if safe_call_method(selected_crew, "is_empty") == true:
		error_occurred.emit("No crew selected")
		return false

	if not current_mission:
		error_occurred.emit("No mission data")
		return false

	if not terrain_system or not terrain_system and terrain_system.has_method("is_terrain_ready") or not terrain_system.is_terrain_ready():
		error_occurred.emit("Terrain not ready")
		return false

	return true

## Prepare battle data for next phase
func _prepare_battle_data() -> Dictionary:
	var terrain_data := {}
	if terrain_system and terrain_system and terrain_system.has_method("get_terrain_data"):
		terrain_data = terrain_system.get_terrain_data()

	# Roll for initiative before battle
	roll_seize_initiative()
	
	# Lock equipment if not already locked
	if not _equipment_is_locked:
		lock_crew_equipment()

	return {
		"mission": current_mission.serialize() if current_mission and current_mission.has_method("serialize") else {},
		"crew": selected_crew,
		"crew_equipment": _get_crew_equipment_snapshot(),
		"deployment_zones": deployment_zones,
		"terrain_data": terrain_data,
		"battle_type": _get_mission_battle_type(current_mission),
		"difficulty": _get_mission_difficulty(current_mission),
		"initiative_seized": initiative_seized,
		"initiative_roll": initiative_roll_result,
		"initiative_savvy_bonus": initiative_savvy_bonus,
		"equipment_locked": _equipment_is_locked
	}

## PHASE 3: Equipment Management Methods

## Start the equipment phase
func start_equipment_phase() -> void:
	_equipment_is_locked = false
	equipment_phase_started.emit()
	print("PreBattleLoop: Equipment phase started - crew can modify loadouts")

## Lock equipment assignments (called before deployment)
func lock_crew_equipment() -> void:
	_equipment_is_locked = true
	equipment_locked.emit()
	print("PreBattleLoop: Equipment locked for battle")

## Check if equipment is locked
func is_equipment_locked() -> bool:
	return _equipment_is_locked

## Get snapshot of crew equipment for battle
func _get_crew_equipment_snapshot() -> Dictionary:
	var snapshot := {}
	
	if not equipment_manager:
		return snapshot
	
	for character: Variant in selected_crew:
		if character == null:
			continue
		
		var char_id := ""
		if character is Object:
			if "id" in character:
				char_id = character.id
			elif "character_name" in character:
				char_id = character.character_name
		
		if not char_id.is_empty() and equipment_manager.has_method("get_character_equipment"):
			snapshot[char_id] = equipment_manager.get_character_equipment(char_id)
	
	return snapshot

## Get ship stash items
func get_ship_stash() -> Array:
	if equipment_manager and equipment_manager.has_method("get_ship_stash"):
		return equipment_manager.get_ship_stash()
	return []

## Roll to Seize the Initiative (Five Parsecs Core Rules)
## Roll 2D6 + highest Savvy in crew, succeed on 9+
func roll_seize_initiative() -> bool:
	# Get highest Savvy from selected crew
	initiative_savvy_bonus = _get_highest_crew_savvy()

	# Roll 2D6
	var die1 := randi_range(1, 6)
	var die2 := randi_range(1, 6)
	initiative_roll_result = die1 + die2 + initiative_savvy_bonus

	# Seize initiative on 9+
	initiative_seized = initiative_roll_result >= 9

	print("PreBattleLoop: Seize Initiative - Roll: %d + %d, Savvy: +%d, Total: %d - %s" % [
		die1, die2, initiative_savvy_bonus, initiative_roll_result,
		"SEIZED!" if initiative_seized else "Failed"
	])

	initiative_rolled.emit(initiative_seized, initiative_roll_result, initiative_savvy_bonus)
	return initiative_seized

## Get highest Savvy stat from selected crew
func _get_highest_crew_savvy() -> int:
	var highest_savvy := 0

	for character: Variant in selected_crew:
		if character == null:
			continue

		var savvy := 0
		# Try different ways to access Savvy stat
		if character is Object:
			if character.has_method("get_savvy"):
				savvy = character.get_savvy()
			elif "savvy" in character:
				savvy = character.savvy
			elif character.has_method("get_stat"):
				savvy = character.get_stat("savvy")
			elif "stats" in character and character.stats is Dictionary:
				savvy = character.stats.get("savvy", 0)

		if savvy > highest_savvy:
			highest_savvy = savvy

	return highest_savvy

## Get initiative result for display
func get_initiative_result() -> Dictionary:
	return {
		"seized": initiative_seized,
		"roll": initiative_roll_result,
		"savvy_bonus": initiative_savvy_bonus,
		"threshold": 9
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
	initiative_seized = false
	initiative_roll_result = 0
	initiative_savvy_bonus = 0
	_equipment_is_locked = false

## Validate mission data structure
## Accepts either StoryQuestData Resource or Dictionary

func _validate_mission(mission: Variant) -> bool:
	if not mission:
		return false

	if _get_mission_battle_type(mission) == GlobalEnums.BattleType.NONE:
		return false

	if _get_mission_enemy_force(mission).is_empty():
		return false

	return true
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
