extends Node

## Central router for managing scene transitions in Five Parsecs Campaign Manager
## Handles navigation between all game screens and maintains navigation history

signal scene_changed(new_scene: String, previous_scene: String)
signal navigation_error(scene_name: String, error: String)

## Sprint B1: Transition settings
var use_transitions: bool = true  # Enable/disable fade transitions
var transition_duration: float = 0.2  # Default 200ms

# Scene paths organized by category
const SCENE_PATHS = {
	# Main screens
	"main_menu": "res://src/ui/screens/mainmenu/MainMenu.tscn",
	"main_game": "res://src/scenes/main/MainGameScene.tscn",

	# Campaign management
	"campaign_creation": "res://src/ui/screens/campaign/CampaignCreationUI.tscn",
	"main_campaign": "res://src/ui/screens/campaign/MainCampaignScene.tscn",
	"campaign_turn": "res://src/ui/CampaignTurnUI.tscn",
	"campaign_dashboard": "res://src/ui/screens/campaign/CampaignDashboard.tscn",
	"campaign_setup": "res://src/ui/screens/campaign/CampaignSetupDialog.tscn",
	"campaign_turn_controller": "res://src/ui/screens/campaign/CampaignTurnController.tscn",
	"victory_progress": "res://src/ui/screens/campaign/VictoryProgressPanel.tscn",

	# Character management
	"character_creator": "res://src/ui/screens/character/SimpleCharacterCreator.tscn",
	"character_details": "res://src/ui/screens/character/CharacterDetailsScreen.tscn",
	"character_progression": "res://src/ui/screens/character/CharacterProgression.tscn",
	"advancement_manager": "res://src/ui/screens/character/AdvancementManager.tscn",
	# "crew_creation": DEPRECATED - CrewPanel handles crew creation in CampaignCreationUI wizard
	"crew_management": "res://src/ui/screens/crew/CrewManagementScreen.tscn",

	# Equipment and ship management
	"equipment_manager": "res://src/ui/screens/equipment/EquipmentManager.tscn",
	"equipment_generation": "res://src/ui/screens/equipment/EquipmentGenerationScene.tscn",
	"ship_manager": "res://src/ui/screens/ships/ShipManager.tscn",
	"ship_inventory": "res://src/ui/screens/ships/ShipInventory.tscn",

	# World and exploration
	"world_phase": "res://src/ui/screens/world/WorldPhaseController.tscn",
	"mission_selection": "res://src/ui/screens/world/MissionSelectionUI.tscn",
	"patron_rival_manager": "res://src/ui/screens/world/PatronRivalManager.tscn",
	"world_phase_summary": "res://src/ui/screens/world/WorldPhaseSummary.tscn",
	"travel_phase": "res://src/ui/screens/travel/TravelPhaseUI.tscn",

	# Battle system
	"pre_battle": "res://src/ui/screens/battle/PreBattle.tscn",
	"battlefield_main": "res://src/ui/screens/battle/BattlefieldMain.tscn",
	"tactical_battle": "res://src/ui/screens/battle/TacticalBattleUI.tscn",
	"post_battle": "res://src/ui/screens/postbattle/PostBattleSequence.tscn",
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
	"new_campaign_tutorial": "res://src/ui/screens/tutorial/NewCampaignTutorial.tscn",

	# Help / Library
	"help": "res://src/ui/help/HelpScreen.tscn",

	# Bug Hunt gamemode
	"bug_hunt_creation": "res://src/ui/screens/bug_hunt/BugHuntCreationUI.tscn",
	"bug_hunt_dashboard": "res://src/ui/screens/bug_hunt/BugHuntDashboard.tscn",
	"bug_hunt_turn_controller": "res://src/ui/screens/bug_hunt/BugHuntTurnController.tscn",
}

# Navigation history for back button functionality
var navigation_history: Array[String] = []
var current_scene: String = ""
var max_history_size: int = 20

# Scene preloading and caching for performance
var scene_cache: Dictionary = {} # String -> PackedScene
var loading_scenes: Dictionary = {} # String -> bool (currently loading)
var preload_enabled: bool = true
var max_cache_size: int = 10

# Campaign creation specific scenes for preloading
const CAMPAIGN_CREATION_SCENES = [
	"campaign_setup",
	"character_creator",
	"equipment_generation",
	"campaign_dashboard"
]

# Scene transition context storage
var scene_contexts: Dictionary = {} # String -> Dictionary

func _ready() -> void:
	# Validate critical scenes on startup
	_validate_critical_scenes()
	
	# Set initial scene name if we're starting from main menu
	if get_tree().current_scene and get_tree().current_scene.scene_file_path.ends_with("MainMenu.tscn"):
		current_scene = "main_menu"

## Navigate to a specific scene

func navigate_to(scene_name: String, context: Dictionary = {}, add_to_history: bool = true, with_transition: bool = true) -> void:

	if not SCENE_PATHS.has(scene_name):
		var error_msg: String = "Scene not found: " + str(scene_name)
		push_error("SceneRouter: " + error_msg)
		navigation_error.emit(scene_name, error_msg)
		return

	# Store context for the target scene
	if not context.is_empty():
		scene_contexts[scene_name] = context.duplicate()

	# Try to use cached scene first for better performance
	if preload_enabled and scene_cache.has(scene_name):
		var cached_scene = scene_cache[scene_name]
		if cached_scene and is_instance_valid(cached_scene):
			_transition_to_cached_scene(scene_name, cached_scene, add_to_history)
			return

	# Fall back to regular file loading
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

	# Use TransitionManager for smooth fade if available and enabled
	var tm = get_node_or_null("/root/TransitionManager")
	if with_transition and use_transitions and tm and tm.has_method("fade_to_scene") and not tm.is_transitioning():
		# TransitionManager handles fade-out, scene change, and fade-in internally
		tm.fade_to_scene(scene_path, transition_duration)
		scene_changed.emit(scene_name, previous_scene)
		_preload_campaign_flow_scenes(scene_name)
		return

	# Direct scene change (no transition)
	var error: int = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		var error_msg: String = "Failed to load scene: " + scene_path + " (Error: " + str(error) + ")"
		push_error("SceneRouter: " + error_msg)
		navigation_error.emit(scene_name, error_msg)
		# Restore previous scene reference on failure
		current_scene = previous_scene
		return

	scene_changed.emit(scene_name, previous_scene)

	# Preload next likely scenes for campaign creation flow
	_preload_campaign_flow_scenes(scene_name)

## Navigate back to the previous scene
func navigate_back() -> void:
	## Navigate back to the previous scene in history
	if navigation_history.is_empty():
		push_warning("SceneRouter: No navigation history to go back to")
		return
	
	var previous_scene = navigation_history.pop_back()
	@warning_ignore("unsafe_call_argument")
	navigate_to(previous_scene, {}, false) # Don't add to history when going back

## Get the name of the current scene
func get_current_scene() -> String:
	return current_scene

## Get navigation history
func get_navigation_history() -> Array[String]:
	return navigation_history.duplicate()

## Clear navigation history
func clear_history() -> void:
	navigation_history.clear()

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
			scenes = ["character_creator", "character_details", "character_progression", "advancement_manager", "crew_management"]
		"equipment":
			scenes = ["equipment_manager", "ship_manager", "ship_inventory"]
		"world":
			scenes = ["world_phase", "job_selection", "mission_selection", "patron_rival_manager", "travel_phase"]
		"battle":
			scenes = ["pre_battle", "battlefield_main", "tactical_battle", "post_battle", "post_battle_results", "post_battle_sequence"]
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
		pass

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

## Scene caching and preloading methods

func preload_scene(scene_name: String) -> void:
	## Preload a scene into cache for faster transitions
	if not SCENE_PATHS.has(scene_name):
		push_warning("SceneRouter: Cannot preload unknown scene: " + scene_name)
		return
	
	if scene_cache.has(scene_name):
		return # Already cached
	
	if loading_scenes.get(scene_name, false):
		return # Already loading
	
	loading_scenes[scene_name] = true
	
	var scene_path = SCENE_PATHS[scene_name]
	var packed_scene = load(scene_path) as PackedScene
	
	if packed_scene:
		_add_to_cache(scene_name, packed_scene)
	else:
		push_error("SceneRouter: Failed to preload scene: " + scene_path)
	
	loading_scenes[scene_name] = false

func preload_campaign_scenes() -> void:
	## Preload all campaign creation flow scenes
	for scene_name in CAMPAIGN_CREATION_SCENES:
		preload_scene(scene_name)

func get_scene_context(scene_name: String) -> Dictionary:
	## Get stored context for a scene
	return scene_contexts.get(scene_name, {})

func clear_scene_context(scene_name: String) -> void:
	## Clear stored context for a scene
	if scene_contexts.has(scene_name):
		scene_contexts.erase(scene_name)

func clear_scene_cache() -> void:
	## Clear all cached scenes
	scene_cache.clear()
	loading_scenes.clear()

func get_cache_info() -> Dictionary:
	## Get cache information for debugging
	return {
		"cached_scenes": scene_cache.keys(),
		"cache_size": scene_cache.size(),
		"max_cache_size": max_cache_size,
		"loading_scenes": loading_scenes.keys(),
		"preload_enabled": preload_enabled
	}

func _transition_to_cached_scene(scene_name: String, packed_scene: PackedScene, add_to_history: bool) -> void:
	## Transition to a cached scene
	# Add current scene to history if requested
	if add_to_history and not current_scene.is_empty():
		_add_to_history(current_scene)
	
	var previous_scene = current_scene
	current_scene = scene_name
	
	# Instantiate and change to cached scene
	var scene_instance = packed_scene.instantiate()
	if scene_instance:
		var old_scene = get_tree().current_scene
		get_tree().root.add_child(scene_instance)
		get_tree().current_scene = scene_instance
		if old_scene:
			old_scene.queue_free()

		scene_changed.emit(scene_name, previous_scene)
		_preload_campaign_flow_scenes(scene_name)
	else:
		push_error("SceneRouter: Failed to instantiate cached scene: " + scene_name)

func _add_to_cache(scene_name: String, packed_scene: PackedScene) -> void:
	## Add a scene to cache with size management
	# Remove oldest entries if cache is full
	if scene_cache.size() >= max_cache_size:
		var oldest_key = scene_cache.keys()[0]
		scene_cache.erase(oldest_key)
	
	scene_cache[scene_name] = packed_scene

func _preload_campaign_flow_scenes(current_scene_name: String) -> void:
	## Preload likely next scenes based on campaign creation flow
	if not preload_enabled:
		return
	
	# Determine which scenes to preload based on current scene
	var scenes_to_preload: Array[String] = []
	
	match current_scene_name:
		"campaign_setup":
			scenes_to_preload = ["campaign_creation"]
		"campaign_creation":
			scenes_to_preload = ["character_creator", "campaign_dashboard"]
		"character_creator":
			scenes_to_preload = ["campaign_creation", "campaign_dashboard"]
		"equipment_generation":
			scenes_to_preload = ["campaign_dashboard"]
		"world_phase":
			scenes_to_preload = ["pre_battle", "battlefield_main", "post_battle"]
		"campaign_dashboard":
			scenes_to_preload = ["world_phase"]
	
	# Preload scenes in background
	for scene_name in scenes_to_preload:
		if not scene_cache.has(scene_name) and not loading_scenes.get(scene_name, false):
			call_deferred("preload_scene", scene_name)

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
		"campaign_turn_controller"
	]
	
	var missing_critical: Array[String] = []
	for scene_name in critical_scenes:
		var scene_path = SCENE_PATHS.get(scene_name, "")
		if scene_path.is_empty() or not FileAccess.file_exists(scene_path):
			missing_critical.append(scene_name)
	
	if not missing_critical.is_empty():
		push_error("SceneRouter: CRITICAL - Missing essential scenes: " + str(missing_critical))
	else:
		pass

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
	@warning_ignore("unsafe_method_access")
	if results.missing.size() > 0:
		@warning_ignore("unsafe_method_access")
		push_warning("SceneRouter: Missing scenes (%d): %s" % [results.missing.size(), str(results.missing)])


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

## Legacy transition methods (navigate_to now handles transitions by default)

func navigate_to_with_transition(scene_name: String, context: Dictionary = {}, add_to_history: bool = true) -> void:
	## Delegates to navigate_to() which now uses transitions by default
	navigate_to(scene_name, context, add_to_history, true)

func navigate_back_with_transition() -> void:
	## Delegates to navigate_back() which now uses transitions by default
	navigate_back()

func set_transitions_enabled(enabled: bool) -> void:
	## Enable or disable scene transitions
	use_transitions = enabled

func set_transition_duration(duration: float) -> void:
	## Set the default transition duration (seconds)
	transition_duration = clampf(duration, 0.05, 2.0)
