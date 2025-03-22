# PreBattleLoop.gd
@tool
extends Node
class_name PreBattleLoop

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
signal battle_prepared(battle_data: Dictionary)
signal quest_completed(quest_data: Dictionary)

## Node references
@onready var ui: Node = $UI # Will be cast to PreBattleUI if available
@onready var terrain_system: Node = $TerrainSystem # Will be cast to UnifiedTerrainSystem if available

## StoryQuestData definition using Dictionary instead of inner class
## This avoids caching issues by not using an inner class
var quest_template = {
	"id": "",
	"title": "",
	"description": "",
	"completed": false,
	"reward": {},
	"battle_type": 0,
	"enemy_force": [],
	"deployment_rules": {},
	"victory_conditions": [],
	"special_conditions": [],
	"difficulty": 0
}

## Mission data
var current_mission: Dictionary # Using Dictionary instead of StoryQuestData
var selected_crew: Array[Character]
var deployment_zones: Array[Dictionary]
var game_state: FiveParsecsGameState

# Member variables for story quests
var current_quests: Array = [] # Array of Dictionaries
var completed_quests: Array = [] # Array of Dictionaries
var campaign_progress: int = 0

func _init() -> void:
	selected_crew = []
	deployment_zones = []

func _ready() -> void:
	_initialize_systems()
	_connect_signals()
	
	# Initialize battle prep system if needed
	if current_quests.is_empty():
		initialize_story_quests()

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
func start_phase(mission: Dictionary, state: FiveParsecsGameState) -> void:
	if mission.is_empty() or not state:
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
func _get_mission_property(mission: Dictionary, property: String, default_value = null) -> Variant:
	if mission.is_empty():
		push_error("Trying to access property '%s' on empty mission dict" % property)
		return default_value
	return mission.get(property, default_value)

func _get_mission_title(mission: Dictionary) -> String:
	return _get_mission_property(mission, "title", "Unknown Mission")

func _get_mission_description(mission: Dictionary) -> String:
	return _get_mission_property(mission, "description", "No description available")

func _get_mission_battle_type(mission: Dictionary) -> int:
	return _get_mission_property(mission, "battle_type", GameEnums.BattleType.NONE)

func _get_mission_enemy_force(mission: Dictionary) -> Array:
	return _get_mission_property(mission, "enemy_force", [])

func _get_mission_deployment_rules(mission: Dictionary) -> Dictionary:
	return _get_mission_property(mission, "deployment_rules", {})

func _get_mission_victory_conditions(mission: Dictionary) -> Array:
	return _get_mission_property(mission, "victory_conditions", [])

func _get_mission_special_conditions(mission: Dictionary) -> Array:
	return _get_mission_property(mission, "special_conditions", [])

func _get_mission_difficulty(mission: Dictionary) -> int:
	return _get_mission_property(mission, "difficulty", GameEnums.DifficultyLevel.NORMAL)

## Setup the battle preview
func _setup_battle_preview() -> void:
	if not ui or current_mission.is_empty():
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
		
	if current_mission.is_empty():
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
		"mission": current_mission, # No need to serialize - it's already a dictionary
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
func get_current_mission() -> Dictionary:
	return current_mission

## Get selected crew
func get_selected_crew() -> Array[Character]:
	return selected_crew

## Get deployment zones
func get_deployment_zones() -> Array[Dictionary]:
	return deployment_zones

## Cleanup
func cleanup() -> void:
	current_mission = {}
	selected_crew.clear()
	deployment_zones.clear()
	game_state = null

## Validate mission data structure
func _validate_mission(mission: Dictionary) -> bool:
	if mission.is_empty():
		return false
		
	if _get_mission_battle_type(mission) == GameEnums.BattleType.NONE:
		return false
		
	if _get_mission_enemy_force(mission).is_empty():
		return false
		
	return true

# Factory method to create a story quest
func create_story_quest(id: String, title: String, description: String) -> Dictionary:
	var quest = quest_template.duplicate()
	quest["id"] = id
	quest["title"] = title
	quest["description"] = description
	return quest

# Initialize available story quests
func initialize_story_quests() -> void:
	# Setup initial story quests
	var starting_quest = create_story_quest(
		"sq_001",
		"First Steps",
		"Complete your first mission to establish your crew."
	)
	
	current_quests.append(starting_quest)

# Generate a random battle based on current campaign progress
func generate_battle(difficulty: int) -> Dictionary:
	var battle_data = {
		"id": "battle_" + str(randi()),
		"difficulty": difficulty,
		"enemies": generate_enemies(difficulty),
		"terrain": generate_terrain(),
		"objectives": generate_objectives(difficulty)
	}
	
	return battle_data

# Helper function to generate enemies
func generate_enemies(difficulty: int) -> Array:
	var enemies = []
	var enemy_count = 3 + difficulty
	
	for i in range(enemy_count):
		var enemy = {
			"id": "enemy_" + str(i),
			"type": randi() % 5, # Random enemy type
			"health": 50 + (10 * difficulty),
			"damage": 5 + (2 * difficulty)
		}
		enemies.append(enemy)
	
	return enemies

# Helper function to generate terrain
func generate_terrain() -> Dictionary:
	var terrain_types = ["forest", "urban", "desert", "swamp", "mountains"]
	var selected_terrain = terrain_types[randi() % terrain_types.size()]
	
	var terrain_data = {
		"type": selected_terrain,
		"cover_density": randf_range(0.2, 0.8),
		"hazards": randf() > 0.7 # 30% chance for hazards
	}
	
	return terrain_data

# Helper function to generate objectives
func generate_objectives(difficulty: int) -> Array:
	var objective_types = ["eliminate", "capture", "defend", "retrieve"]
	var primary_objective = objective_types[randi() % objective_types.size()]
	
	var objectives = [
		{
			"type": primary_objective,
			"description": "Complete the " + primary_objective + " objective",
			"reward": 100 * difficulty,
			"required": true
		}
	]
	
	# Add secondary objectives based on difficulty
	if difficulty > 1:
		var secondary_objective = objective_types[randi() % objective_types.size()]
		objectives.append({
			"type": secondary_objective,
			"description": "Complete the secondary " + secondary_objective + " objective",
			"reward": 50 * difficulty,
			"required": false
		})
	
	return objectives

# Prepare a battle based on a story quest
func prepare_battle_from_quest(quest: Dictionary) -> Dictionary:
	var battle_data = generate_battle(campaign_progress + 1)
	
	# Customize battle based on quest data
	battle_data["quest_id"] = quest.get("id", "")
	battle_data["quest_title"] = quest.get("title", "")
	
	# Add special objectives based on quest
	battle_data["special_conditions"] = "Complete the " + quest.get("title", "") + " mission."
	
	return battle_data

# Get available story quests
func get_available_quests() -> Array:
	return current_quests

# Get a specific story quest by ID
func get_quest_by_id(quest_id: String) -> Dictionary:
	for quest in current_quests:
		if quest.get("id", "") == quest_id:
			return quest
	
	# Return an empty dictionary if not found
	return {}

# Complete a story quest
func complete_quest(quest: Dictionary) -> void:
	var quest_idx = current_quests.find(quest)
	if quest_idx >= 0:
		# Mark as completed
		quest["completed"] = true
		
		# Remove from current and add to completed
		current_quests.remove_at(quest_idx)
		completed_quests.append(quest)
		
		# Generate rewards based on quest
		var reward = {
			"credits": 500 + (campaign_progress * 100),
			"experience": 50 + (campaign_progress * 10),
			"items": []
		}
		
		quest["reward"] = reward
		
		# Emit completion signal
		quest_completed.emit(quest)
		
		# Advance campaign progress
		campaign_progress += 1
	
	# Generate new quests based on progress
	generate_new_quests()

# Generate new quests based on campaign progress
func generate_new_quests() -> void:
	# Generate more complex quests as the campaign progresses
	var new_quest_id = "sq_" + str(100 + campaign_progress)
	var quest_titles = [
		"Expanding Horizons",
		"Making a Name",
		"Growing Reputation",
		"Dangerous Alliance",
		"Final Showdown"
	]
	
	var quest_title = quest_titles[min(campaign_progress, quest_titles.size() - 1)]
	
	var new_quest = create_story_quest(
		new_quest_id,
		quest_title,
		"Continue your adventure with increasingly difficult challenges."
	)
	
	current_quests.append(new_quest)

# Process battle results
func process_battle_results(results: Dictionary) -> void:
	# Update quest progress based on battle results
	if results.get("success", false):
		var quest_id = results.get("quest_id", "")
		if not quest_id.is_empty():
			var quest = get_quest_by_id(quest_id)
			if not quest.is_empty():
				complete_quest(quest)
	
	# Update campaign state based on results
	if results.get("campaign_impact", false):
		# Process any campaign-wide effects
		campaign_progress += results.get("progress_boost", 0)
	
	# Generate new opportunities based on battle outcome
	if results.get("success", false):
		# More favorable outcomes for successful missions
		pass
	else:
		# Consequences for failed missions
		pass
