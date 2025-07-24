extends Node

## Central router for managing scene transitions in Five Parsecs Campaign Manager
## Handles navigation between all game screens and maintains navigation history

signal scene_changed(new_scene: String, previous_scene: String)
signal navigation_error(scene_name: String, error: String)

# Scene paths organized by category
const SCENE_PATHS = {
	# Main screens
	"main_menu": "res://src/ui/screens/mainmenu/MainMenu.tscn",
	"main_game": "res://src/scenes/main/MainGameScene.tscn",

	# Campaign management
	"campaign_creation": "res://src/ui/screens/campaign/CampaignCreationUI.tscn",
	"campaign_dashboard": "res://src/ui/screens/campaign/CampaignDashboard.tscn",
	"campaign_setup": "res://src/ui/screens/campaign/CampaignSetupDialog.tscn",
	"campaign_turn_controller": "res://src/ui/screens/campaign/CampaignTurnController.tscn",
	"victory_progress": "res://src/ui/screens/campaign/VictoryProgressPanel.tscn",

	# Character management
	"character_creator": "res://src/ui/screens/character/CharacterCreator.tscn",
	"character_sheet": "res://src/ui/screens/character/CharacterSheet.tscn",
	"character_progression": "res://src/ui/screens/character/CharacterProgression.tscn",
	"advancement_manager": "res://src/ui/screens/character/AdvancementManager.tscn",
	"crew_creation": "res://src/ui/screens/crew/InitialCrewCreation.tscn",

	# Equipment and ship management
	"equipment_manager": "res://src/ui/screens/equipment/EquipmentManager.tscn",
	"ship_manager": "res://src/ui/screens/ships/ShipManager.tscn",
	"ship_inventory": "res://src/ui/screens/ships/ShipInventory.tscn",

	# World and exploration
	"world_phase": "res://src/ui/screens/world/WorldPhaseUI.tscn",
	"job_selection": "res://src/ui/screens/world/JobSelectionUI.tscn",
	"mission_selection": "res://src/ui/screens/world/MissionSelectionUI.tscn",
	"patron_rival_manager": "res://src/ui/screens/world/PatronRivalManager.tscn",
	"travel_phase": "res://src/ui/screens/travel/TravelPhaseUI.tscn",

	# Battle system
	"pre_battle": "res://src/ui/screens/battle/PreBattle.tscn",
	"battlefield_main": "res://src/ui/screens/battle/BattlefieldMain.tscn",
	"tactical_battle": "res://src/ui/screens/battle/TacticalBattleUI.tscn",
	"battle_resolution": "res://src/ui/screens/battle/BattleResolutionUI.tscn",
	"post_battle": "res://src/ui/screens/battle/PostBattle.tscn",
	"post_battle_results": "res://src/ui/screens/battle/PostBattleResultsUI.tscn",
	"post_battle_sequence": "res://src/ui/screens/postbattle/PostBattleSequence.tscn",

	# Events and story
	"campaign_events": "res://src/ui/screens/events/CampaignEventsManager.tscn",
	# "story_phase": REMOVED - not official Five Parsecs phase

	# Campaign phases
	# "upkeep_phase": REMOVED - functionality moved to World Phase Step 1
	# "advancement_phase": REMOVED - part of Post-Battle Phase
	# "battle_setup_phase": REMOVED - part of Battle Phase
	# "battle_resolution_phase": REMOVED - part of Post-Battle Phase
	# "trade_phase": REMOVED - part of World Phase
	# "end_phase": REMOVED - campaigns cycle, don't end

	# Utility screens
	"save_load": "res://src/ui/screens/utils/SaveLoadUI.tscn",
	"game_over": "res://src/ui/screens/utils/GameOverScreen.tscn",
	"logbook": "res://src/ui/screens/utils/logbook.tscn",
	"settings": "res://src/ui/dialogs/SettingsDialog.tscn",

	# Tutorial
	"tutorial_selection": "res://src/ui/screens/tutorial/TutorialSelection.tscn",
	"new_campaign_tutorial": "res://src/ui/screens/tutorial/NewCampaignTutorial.tscn"
}

# Navigation history for back button functionality
var navigation_history: Array[String] = []
var current_scene: String = ""
var max_history_size: int = 20

func _ready() -> void:
	print("SceneRouter: Initialized with ", SCENE_PATHS.size(), " registered scenes")
	# Validate critical scenes on startup
	_validate_critical_scenes()
	
	# Set initial scene name if we're starting from main menu
	if get_tree().current_scene and get_tree().current_scene.scene_file_path.ends_with("MainMenu.tscn"):
		current_scene = "main_menu"

## Navigate to a specific scene

func navigate_to(scene_name: String, add_to_history: bool = true) -> void:
	print("SceneRouter: Navigating to ", scene_name)

	if not SCENE_PATHS.has(scene_name):
		var error_msg: String = "Scene not found: " + str(scene_name)
		push_error("SceneRouter: " + error_msg)
		navigation_error.emit(scene_name, error_msg)
		return

	@warning_ignore("untyped_declaration")
	var scene_path = SCENE_PATHS[scene_name]

	# Check if scene file exists
	@warning_ignore("unsafe_call_argument")
	if not FileAccess.file_exists(scene_path):
		var error_msg: String = "Scene file not found: " + scene_path
		push_error("SceneRouter: " + error_msg)
		navigation_error.emit(scene_name, error_msg)
		return

	# Add current scene to _history if requested
	if add_to_history and not current_scene.is_empty():
		_add_to_history(current_scene)

	@warning_ignore("untyped_declaration")
	var previous_scene = current_scene
	current_scene = scene_name

	# Perform scene transition
	# call_deferred returns void, so we use immediate transition with error checking
	var error: int = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		var error_msg: String = "Failed to load scene: " + scene_path + " (Error: " + str(error) + ")"
		push_error("SceneRouter: " + error_msg)
		navigation_error.emit(scene_name, error_msg)
		# Restore previous scene reference on failure
		current_scene = previous_scene
		return

	scene_changed.emit(scene_name, previous_scene)

## Navigate back to the previous scene
func navigate_back() -> void:
	if navigation_history.is_empty():
		print("SceneRouter: No history available for back navigation")
		return

	@warning_ignore("untyped_declaration")
	var previous_scene = navigation_history.pop_back()
	print("SceneRouter: Navigating back to ", previous_scene)
	@warning_ignore("unsafe_call_argument")
	navigate_to(previous_scene, false) # Don't add to history when going back

## Get the name of the current scene
func get_current_scene() -> String:
	return current_scene

## Get navigation history
func get_navigation_history() -> Array[String]:
	return navigation_history.duplicate()

## Clear navigation history
func clear_history() -> void:
	navigation_history.clear()
	print("SceneRouter: Navigation history cleared")

## Check if a scene exists in the router

func has_scene(scene_name: String) -> bool:
	return SCENE_PATHS.has(scene_name)

## Get the file path for a scene
func get_scene_path(scene_name: String) -> String:
	return SCENE_PATHS.get(scene_name, "")

## Get all available scene names
func get_available_scenes() -> Array[String]:
	var scenes: Array[String] = []
	@warning_ignore("untyped_declaration")
	for scene_name in SCENE_PATHS:
		scenes.append(scene_name)
	return scenes

## Get scenes by category
func get_scenes_by_category(category: String) -> Array[String]:
	var scenes: Array[String] = []
	match category.to_lower():
		"campaign":
			scenes = ["campaign_creation", "campaign_dashboard", "campaign_setup", "victory_progress"]
		"character":
			scenes = ["character_creator", "character_sheet", "character_progression", "advancement_manager", "crew_creation"]
		"equipment":
			scenes = ["equipment_manager", "ship_manager", "ship_inventory"]
		"world":
			scenes = ["world_phase", "job_selection", "mission_selection", "patron_rival_manager", "travel_phase"]
		"battle":
			scenes = ["pre_battle", "battlefield_main", "tactical_battle", "battle_resolution", "post_battle", "post_battle_results", "post_battle_sequence"]
		"events":
			scenes = ["campaign_events"]
		"phases":
			# Official Five Parsecs Four-Phase structure
			scenes = ["travel_phase", "world_phase", "post_battle_sequence"]
		"utility":
			scenes = ["save_load", "game_over", "logbook", "settings"]
		"tutorial":
			scenes = ["tutorial_selection", "new_campaign_tutorial"]
	return scenes

## Campaign phase navigation helpers
func navigate_to_campaign_phase(phase: String) -> void:
	# Navigate to a specific campaign phase
	@warning_ignore("untyped_declaration")
	var phase_scene_map = {
		"travel": "travel_phase",
		"world": "world_phase",
		"pre_battle": "pre_battle",
		"battle": "battlefield_main",
		"post_battle": "post_battle_sequence"
		# Note: Battle phase handled by BattlefieldCompanion system
		# Note: Deprecated phases removed (upkeep, story) - functionality integrated into official phases
	}

	@warning_ignore("untyped_declaration")
	var scene_name = phase_scene_map.get(phase.to_lower(), "")
	@warning_ignore("unsafe_method_access")
	if not scene_name.is_empty():
		@warning_ignore("unsafe_call_argument")
		navigate_to(scene_name)
	else:
		print("SceneRouter: Unknown campaign phase: ", phase)

## Quick navigation methods for common flows

func start_new_campaign() -> void:
	# Start the new campaign flow
	clear_history()
	navigate_to("campaign_creation")

func return_to_main_menu() -> void:
	# Return to main menu
	clear_history()
	navigate_to("main_menu")

func enter_main_game() -> void:
	# Enter the main game scene
	navigate_to("main_game")

func navigate_to_main_game() -> void:
	# Navigate to the main game scene - alias for enter_main_game
	enter_main_game()

func change_scene(scene_path: String) -> void:
	# Direct scene change using file path - for compatibility
	print("SceneRouter: Direct scene change to ", scene_path)
	get_tree().call_deferred("change_scene_to_file", scene_path)

func open_character_management() -> void:
	# Open character management
	navigate_to("advancement_manager")

func open_equipment_management() -> void:
	# Open equipment management
	navigate_to("equipment_manager")

func open_ship_management() -> void:
	# Open ship management
	navigate_to("ship_manager")

func start_battle_sequence() -> void:
	# Start the battle sequence
	navigate_to("pre_battle")

func start_post_battle_sequence() -> void:
	# Start the post-battle sequence
	navigate_to("post_battle_sequence")

## Private helper methods

func _add_to_history(scene_name: String) -> void:
	# Add a scene to navigation history
	# Avoid duplicate consecutive entries
	if not navigation_history.is_empty() and navigation_history.back() == scene_name:
		return

	navigation_history.append(scene_name)

	# Limit history size
	if navigation_history.size() > max_history_size:
		navigation_history.pop_front()

func _validate_critical_scenes() -> void:
	# Validate that critical scenes exist on startup
	var critical_scenes: Array[String] = [
		"main_menu",
		"campaign_creation", 
		"crew_creation",
		"main_game"
	]
	
	var missing_critical: Array[String] = []
	for scene_name in critical_scenes:
		var scene_path = SCENE_PATHS.get(scene_name, "")
		if scene_path.is_empty() or not FileAccess.file_exists(scene_path):
			missing_critical.append(scene_name)
	
	if not missing_critical.is_empty():
		push_error("SceneRouter: CRITICAL - Missing essential scenes: " + str(missing_critical))
		print("SceneRouter: These scenes are required for basic functionality")
	else:
		print("SceneRouter: All critical scenes validated successfully")

func validate_all_scenes() -> bool:
	# Validate that all registered scene files exist
	@warning_ignore("untyped_declaration")
	var results = {"valid": [], "missing": []}

	@warning_ignore("untyped_declaration")
	for scene_name in SCENE_PATHS:
		@warning_ignore("untyped_declaration")
		var scene_path = SCENE_PATHS[scene_name]
		@warning_ignore("unsafe_call_argument")
		if FileAccess.file_exists(scene_path):
			@warning_ignore("unsafe_method_access")
			results.valid.append(scene_name)
		else:
			@warning_ignore("unsafe_method_access")
			results.missing.append(scene_name)

	return results

## Debug and utility methods
func print_validation_results() -> void:
	# Print validation results for all scenes
	@warning_ignore("untyped_declaration")
	var results = validate_all_scenes()
	print("SceneRouter Validation Results:")
	@warning_ignore("unsafe_method_access")
	print("Valid scenes (", results.valid.size(), "): ", results.valid)
	@warning_ignore("unsafe_method_access")
	if results.missing.size() > 0:
		@warning_ignore("unsafe_method_access")
		print("Missing scenes (", results.missing.size(), "): ", results.missing)
	else:
		print("All scenes validated successfully!")

func get_scene_info() -> Dictionary:
	# Get comprehensive scene information
	@warning_ignore("untyped_declaration")
	var results = validate_all_scenes()
	return {
		"total_scenes": SCENE_PATHS.size(),
		"valid_scenes": results.valid.size(),
		"missing_scenes": results.missing.size(),
		"current_scene": current_scene,
		"history_size": navigation_history.size(),
		"missing_scene_list": results.missing
	}
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	@warning_ignore("unsafe_method_access")
	if obj is Object and obj.has_method(method_name):
		@warning_ignore("unsafe_method_access")
		return obj.callv(method_name, args)
	return null
