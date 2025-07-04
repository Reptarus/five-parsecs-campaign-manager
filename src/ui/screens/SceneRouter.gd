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
	"story_phase": "res://src/ui/screens/campaign/phases/StoryPhasePanel.tscn",
	
	# Campaign phases
	"upkeep_phase": "res://src/ui/screens/campaign/UpkeepPhaseUI.tscn",
	"advancement_phase": "res://src/ui/screens/campaign/phases/AdvancementPhasePanel.tscn",
	"battle_setup_phase": "res://src/ui/screens/campaign/phases/BattleSetupPhasePanel.tscn",
	"battle_resolution_phase": "res://src/ui/screens/campaign/phases/BattleResolutionPhasePanel.tscn",
	"trade_phase": "res://src/ui/screens/campaign/phases/TradePhasePanel.tscn",
	"end_phase": "res://src/ui/screens/campaign/phases/EndPhasePanel.tscn",
	
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

## Navigate to a specific scene

func navigate_to(scene_name: String, add_to_history: bool = true) -> void:
	print("SceneRouter: Navigating to ", scene_name)
	
	if not SCENE_PATHS.has(scene_name):
		var error_msg: String = "Scene not found: " + scene_name
		push_error("SceneRouter: " + error_msg)
		navigation_error.emit(scene_name, error_msg) # warning: return value discarded (intentional)
		return
	
	var scene_path = SCENE_PATHS[scene_name]
	
	# Check if scene file exists
	if not FileAccess.file_exists(scene_path):
		var error_msg: String = "Scene file not found: " + scene_path
		push_error("SceneRouter: " + error_msg)
		navigation_error.emit(scene_name, error_msg) # warning: return value discarded (intentional)
		return
	
	# Add current scene to _history if requested
	if add_to_history and not current_scene.is_empty():
		_add_to_history(current_scene)
	
	var previous_scene = current_scene
	current_scene = scene_name
	
	# Perform scene transition
	var error = get_tree().call_deferred("change_scene_to_file", scene_path)
	if error != OK:
		var error_msg: String = "Failed to load scene: " + scene_path + " (Error: " + str(error) + ")"
		push_error("SceneRouter: " + error_msg)
		navigation_error.emit(scene_name, error_msg) # warning: return value discarded (intentional)
		return
	
	scene_changed.emit(scene_name, previous_scene) # warning: return value discarded (intentional)

## Navigate back to the previous scene
func navigate_back() -> void:
	if navigation_history.is_empty():
		print("SceneRouter: No history available for back navigation")
		return
	
	var previous_scene = navigation_history.pop_back()
	print("SceneRouter: Navigating back to ", previous_scene)
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
	for scene_name in SCENE_PATHS:
		scenes.append(scene_name) # warning: return value discarded (intentional)
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
			scenes = ["campaign_events", "story_phase"]
		"phases":
			scenes = ["upkeep_phase", "advancement_phase", "battle_setup_phase", "battle_resolution_phase", "trade_phase", "end_phase"]
		"utility":
			scenes = ["save_load", "game_over", "logbook", "settings"]
		"tutorial":
			scenes = ["tutorial_selection", "new_campaign_tutorial"]
	return scenes

## Campaign phase navigation helpers
func navigate_to_campaign_phase(phase: String) -> void:
	# Navigate to a specific campaign phase
	var phase_scene_map = {
		"upkeep": "upkeep_phase",
		"travel": "travel_phase",
		"world": "world_phase",
		"story": "story_phase",
		"pre_battle": "pre_battle",
		"battle": "battlefield_main",
		"post_battle": "post_battle_sequence",
		"advancement": "advancement_phase",
		"trade": "trade_phase",
		"end": "end_phase"
	}
	
	var scene_name = phase_scene_map.get(phase.to_lower(), "")
	if not scene_name.is_empty():
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
	
	navigation_history.append(scene_name) # warning: return value discarded (intentional)
	
	# Limit history size
	if navigation_history.size() > max_history_size:
		navigation_history.pop_front()

func validate_all_scenes() -> bool:
	# Validate that all registered scene files exist
	var results = {"valid": [], "missing": []}
	
	for scene_name in SCENE_PATHS:
		var scene_path = SCENE_PATHS[scene_name]
		if FileAccess.file_exists(scene_path):
			results.valid.append(scene_name)
		else:
			results.missing.append(scene_name)
	
	return results

## Debug and utility methods
func print_validation_results() -> void:
	# Print validation results for all scenes
	var results = validate_all_scenes()
	print("SceneRouter Validation Results:")
	print("Valid scenes (", results.valid.size(), "): ", results.valid)
	if results.missing.size() > 0:
		print("Missing scenes (", results.missing.size(), "): ", results.missing)
	else:
		print("All scenes validated successfully!")

func get_scene_info() -> Dictionary:
	# Get comprehensive scene information
	var results = validate_all_scenes()
	return {
		"total_scenes": SCENE_PATHS.size(),
		"valid_scenes": results.valid.size(),
		"missing_scenes": results.missing.size(),
		"current_scene": current_scene,
		"history_size": navigation_history.size(),
		"missing_scene_list": results.missing
	}