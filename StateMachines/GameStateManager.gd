extends Node

# Preload all required resources
const GlobalEnums := preload("res://Resources/GameData/GlobalEnums.gd")
const GameStateResource := preload("res://Resources/GameData/GameState.gd")
const Mission := preload("res://Resources/GameData/Mission.gd") 
const MissionGenerator := preload("res://Resources/GameData/MissionGenerator.gd")
const StoryTrack := preload("res://Resources/CampaignManagement/StoryTrack.gd")
const WorldGenerator := preload("res://Resources/GameData/WorldGenerator.gd")
const ExpandedFactionManager := preload("res://Resources/ExpansionContent/ExpandedFactionManager.gd")
const CombatManager := preload("res://Resources/BattlePhase/CombatManager.gd")
const DeploymentManager := preload("res://Resources/GameData/EnemyDeploymentManager.gd")
const EquipmentManager := preload("res://Resources/CampaignManagement/EquipmentManager.gd")
const TerrainGenerator := preload("res://Resources/GameData/TerrainGenerator.gd")
const PatronJobManager := preload("res://Resources/CampaignManagement/PatronJobManager.gd")
const Battle := preload("res://Resources/BattlePhase/battle.gd")
const TutorialSystem := preload("res://Resources/GameData/TutorialSystem.gd")
const UIManager = preload("res://UI/UIManager.gd")

# Platform-specific constants
const PLATFORM_CONFIG := {
	"Android": {
		"max_fps": 60,
		"vsync": true,
		"save_path": "user://",
		"texture_compression": true
	},
	"iOS": {
		"max_fps": 60,
		"vsync": true,
		"save_path": "user://",
		"texture_compression": true
	},
	"Windows": {
		"max_fps": 0, # Unlimited
		"vsync": true,
		"save_path": "user://",
		"texture_compression": false
	}
}

class FringeWorldStrifeManager extends Node:
	var strife_level: int = GlobalEnums.FringeWorldInstability.STABLE
	
	func update_strife() -> void:
		pass

# Scene constants
const BATTLE_SCENE: PackedScene = preload("res://Resources/BattlePhase/Scenes/Battle.tscn")
const POST_BATTLE_SCENE: PackedScene = preload("res://Resources/BattlePhase/PreBattle.tscn")
const INITIAL_CREW_CREATION_SCENE: String = "res://Scenes/Management/InitialCrewCreation.tscn"
const SETTINGS_FILE_PATH := "user://settings.save"
const SAVE_GAME_FILE_PATH := "user://savegame.json"

# Signals
signal state_changed(new_state: GlobalEnums.GameState)
signal battle_ended(victory: bool)
signal tutorial_step_changed(step_id: String)
signal tutorial_track_completed(track_id: String)
signal tutorial_step_completed
signal tutorial_completed
signal settings_changed
signal campaign_victory_achieved(victory_type: GlobalEnums.CampaignVictoryType)

# Singleton instance
static var instance: GameStateManager

# Game state and managers
var game_state: GameStateResource
var mission_generator: MissionGenerator
var equipment_manager: EquipmentManager
var patron_job_manager: PatronJobManager
var current_battle: Battle
var fringe_world_strife_manager: FringeWorldStrifeManager
var story_track: StoryTrack
var world_generator: WorldGenerator
var expanded_faction_manager: ExpandedFactionManager
var combat_manager: CombatManager
var tutorial_system: TutorialSystem

# State machines
var battle_state: LocalBattleStateMachine
var campaign_state: LocalCampaignStateMachine
var main_game_state: LocalMainGameStateMachine

# Settings and state tracking
var settings: Dictionary = {
	"disable_tutorial_popup": false,
	"difficulty": GlobalEnums.DifficultyMode.NORMAL,
	"enable_permadeath": true,
	"enable_tutorials": true
}

var current_tutorial_type: GlobalEnums.TutorialType = GlobalEnums.TutorialType.QUICK_START
var current_tutorial_stage: GlobalEnums.TutorialStage = GlobalEnums.TutorialStage.INTRODUCTION
var current_tutorial_track: GlobalEnums.TutorialTrack = GlobalEnums.TutorialTrack.CORE_RULES
var completed_tutorials: Dictionary = {}
var campaign_victory_condition: GlobalEnums.CampaignVictoryType

# Resource management
var _resource_cache: Dictionary = {}
var _pending_resources: Array = []
var _android_initialized := false
const MAX_RESOURCES_PER_FRAME := 5

# Platform-specific properties
var _current_platform: String
var _is_mobile: bool
var _screen_orientation: int = DisplayServer.SCREEN_PORTRAIT
var _safe_area: Rect2

# Add safe area and orientation constants
const SAFE_AREA_MARGIN := 10
const MIN_TOUCH_TARGET := 44  # Minimum touch target size in pixels

# Add UI manager preload and variable
var ui_manager: UIManager

func _init() -> void:
	if instance != null:
		push_error("GameStateManager already exists!")
		return
	
	instance = self
	_initialize_platform()
	_initialize_resource_cache()

func _initialize_platform() -> void:
	_current_platform = OS.get_name()
	_is_mobile = _current_platform in ["Android", "iOS"]
	
	if _is_mobile:
		_configure_mobile_platform()
	else:
		_configure_desktop_platform()

func _configure_mobile_platform() -> void:
	var config = PLATFORM_CONFIG[_current_platform]
	
	# Configure mobile-specific settings
	Engine.max_fps = config.max_fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if config.vsync else DisplayServer.VSYNC_DISABLED)
	
	# Set default orientation
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	
	# Keep screen on - using Window property instead
	get_window().mode = Window.MODE_FULLSCREEN
	get_window().keep_screen_on = true
	
	# Initialize safe area
	_safe_area = DisplayServer.get_display_safe_area()
	
	# Configure touch settings
	Input.use_accumulated_input = false  # Better touch response
	
	# Enable haptic feedback if available
	if _is_mobile and OS.has_feature("vibrate"):
		Input.vibrate_handheld(50)  # Short vibration to test availability

func _update_safe_area() -> void:
	_safe_area = DisplayServer.get_display_safe_area()
	if is_instance_valid(ui_manager):
		ui_manager.update_layout()

func _handle_orientation_change() -> void:
	if not _is_mobile:
		return
		
	var window_size = DisplayServer.window_get_size()
	var is_portrait = window_size.y > window_size.x
	
	# Update orientation using correct constants
	_screen_orientation = DisplayServer.SCREEN_PORTRAIT if is_portrait else DisplayServer.SCREEN_LANDSCAPE
	DisplayServer.screen_set_orientation(_screen_orientation)
	
	# Update safe area and UI
	_update_safe_area()
	if is_instance_valid(ui_manager):
		ui_manager.update_layout()

# Single window size change handler
func _on_window_size_changed() -> void:
	if _is_mobile:
		_handle_orientation_change()
		_update_safe_area()
		
		if is_instance_valid(ui_manager):
			ui_manager.update_layout()
	
	# Always clear resource cache, regardless of platform
	_resource_cache.clear()

func trigger_haptic_feedback(feedback_type: String = "light") -> void:
	if not _is_mobile or not OS.has_feature("vibrate"):
		return
		
	match feedback_type:
		"light":
			Input.vibrate_handheld(50)
		"medium":
			Input.vibrate_handheld(100)
		"heavy":
			Input.vibrate_handheld(200)
		"error":
			Input.vibrate_handheld(250)

func _handle_window_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			trigger_haptic_feedback("light")
	elif event is InputEventScreenDrag:
		# Handle drag events if needed
		pass

func _input(event: InputEvent) -> void:
	if _is_mobile:
		if event is InputEventScreenTouch:
			if event.pressed:
				trigger_haptic_feedback("light")
		elif event is InputEventKey:
			if event.keycode == KEY_BACK:
				_handle_back_button()
				get_viewport().set_input_as_handled()

func _configure_desktop_platform() -> void:
	var config = PLATFORM_CONFIG[_current_platform]
	Engine.max_fps = config.max_fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if config.vsync else DisplayServer.VSYNC_DISABLED)

static func get_instance() -> GameStateManager:
	return instance

func _ready() -> void:
	if OS.get_name() == "Android":
		_setup_android_initialization()
	else:
		_initialize_game_systems()

func _setup_android_initialization() -> void:
	call_deferred("_initialize_game_systems")
	
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = 60
	Engine.physics_jitter_fix = 0.0
	
	if not _android_initialized:
		get_tree().set_auto_accept_quit(false)
		# Connect window size change signal only once
		if not get_tree().root.is_connected("size_changed", _on_window_size_changed):
			get_tree().root.connect("size_changed", _on_window_size_changed)
		_android_initialized = true

func _initialize_game_systems() -> void:
	game_state = GameStateResource.new()
	game_state.current_state = GlobalEnums.GameState.SETUP
	
	# Initialize UI manager first
	ui_manager = UIManager.new()
	add_child(ui_manager)
	
	initialize_managers()
	initialize_state_machines()
	_initialize_tutorial_system()
	
	settings = _load_settings()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			if _is_mobile:
				_handle_mobile_pause()
		NOTIFICATION_APPLICATION_RESUMED:
			if _is_mobile:
				_handle_mobile_resume()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_handle_back_button()

func _handle_android_pause() -> void:
	if game_state and is_instance_valid(game_state):
		save_game()
	
	_cleanup_resources()
	
	# Request garbage collection via Engine singleton
	if Engine.has_singleton("GarbageCollector"):
		Engine.get_singleton("GarbageCollector").collect()

func _handle_back_button() -> void:
	if game_state.current_state == GlobalEnums.GameState.BATTLE:
		_show_exit_dialog()
	else:
		get_tree().quit()

func _cleanup_resources() -> void:
	if current_battle and is_instance_valid(current_battle):
		current_battle.cleanup()
	
	if combat_manager and is_instance_valid(combat_manager):
		combat_manager.cleanup()
	
	if ui_manager and is_instance_valid(ui_manager):
		ui_manager.cleanup()
	
	# Clear resource cache
	_resource_cache.clear()
	
	# Force immediate memory cleanup
	Engine.get_main_loop().root.propagate_notification(NOTIFICATION_PREDELETE)
	get_tree().call_group("cleanup_group", "cleanup")
	
	# Request garbage collection
	if Engine.has_singleton("GarbageCollector"):
		Engine.get_singleton("GarbageCollector").collect()

func initialize_managers() -> void:
	mission_generator = MissionGenerator.new(game_state)
	equipment_manager = EquipmentManager.new()
	patron_job_manager = PatronJobManager.new(game_state)
	fringe_world_strife_manager = FringeWorldStrifeManager.new()
	story_track = StoryTrack.new()
	world_generator = WorldGenerator.new()
	expanded_faction_manager = ExpandedFactionManager.new()
	combat_manager = CombatManager.new()

func initialize_state_machines() -> void:
	battle_state = LocalBattleStateMachine.new()
	campaign_state = LocalCampaignStateMachine.new()
	main_game_state = LocalMainGameStateMachine.new()
	
	add_child(battle_state)
	add_child(campaign_state)
	add_child(main_game_state)
	
	battle_state.setup(self)
	campaign_state.setup(self)
	main_game_state.setup(self)
	
	# Set initial campaign phase
	main_game_state.current_campaign_phase = GlobalEnums.CampaignPhase.UPKEEP

func _initialize_tutorial_system() -> void:
	tutorial_system = TutorialSystem.new()
	add_child(tutorial_system)
	
	tutorial_system.tutorial_step_changed.connect(_on_tutorial_step_changed)
	tutorial_system.tutorial_completed.connect(_on_tutorial_completed)
	tutorial_system.tutorial_step_completed.connect(_on_tutorial_step_completed)
	tutorial_system.tutorial_track_completed.connect(_on_tutorial_track_completed)

func get_current_game_state() -> GlobalEnums.GameState:
	return main_game_state.current_state

func get_current_campaign_phase() -> GlobalEnums.CampaignPhase:
	return main_game_state.current_campaign_phase

func transition_to_state(new_state: GlobalEnums.GameState) -> void:
	game_state.current_state = new_state
	state_changed.emit(new_state)

func _load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_FILE_PATH):
		return settings
		
	var file := FileAccess.open(SETTINGS_FILE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open settings file")
		return settings
		
	var json := JSON.new()
	var parse_result: Error = json.parse(file.get_as_text())
	if parse_result == OK:
		var data = json.get_data()
		if data is Dictionary:
			return data
			
	push_error("Invalid settings data format")
	return settings

func save_settings() -> void:
	var file: FileAccess = FileAccess.open(SETTINGS_FILE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(settings))
	settings_changed.emit()

func _handle_battle_setup() -> void:
	if current_battle:
		current_battle.setup_battlefield()

func _handle_battle_round() -> void:
	if current_battle:
		current_battle.process_round()

func _handle_battle_cleanup() -> void:
	if current_battle:
		current_battle.cleanup()

func handle_game_over(victory: bool) -> void:
	print("Game %s!" % ("Won" if victory else "Over"))
	transition_to_state(GlobalEnums.GameState.GAME_OVER)

# Game state getters
func get_game_state() -> GameStateResource:
	return game_state

func get_current_ship() -> Ship:
	return game_state.current_ship

func is_objective_completed() -> bool:
	return game_state.current_objective.is_completed()

func get_casualties_this_round() -> int:
	return game_state.current_battle.casualties

func get_panic_range() -> int:
	return game_state.current_battle.panic_range

func get_random_enemy() -> Character:
	var enemies: Array = game_state.current_battle.enemies
	return enemies[randi() % enemies.size()] if not enemies.is_empty() else null

func remove_enemy(enemy: Character) -> void:
	var enemies: Array = game_state.current_battle.enemies
	if enemy in enemies:
		enemies.erase(enemy)
		print("Enemy removed: ", enemy.name)

# State machine classes
class LocalBattleStateMachine extends Node:
	var current_state: int = GlobalEnums.BattlePhase.SETUP
	var game_manager: GameStateManager
	
	func setup(manager: GameStateManager) -> void:
		game_manager = manager
		
	func transition_to(new_state: int) -> void:
		if new_state not in GlobalEnums.BattlePhase.values():
			push_error("Invalid battle phase state: %d" % new_state)
			return
			
		current_state = new_state
		match current_state:
			GlobalEnums.BattlePhase.SETUP:
				game_manager._handle_battle_setup()
			GlobalEnums.BattlePhase.COMBAT:
				game_manager._handle_battle_round()
			GlobalEnums.BattlePhase.CLEANUP:
				game_manager._handle_battle_cleanup()

class LocalCampaignStateMachine extends Node:
	var current_state: int = GlobalEnums.CampaignPhase.UPKEEP
	var game_manager: GameStateManager
	
	func setup(manager: GameStateManager) -> void:
		game_manager = manager

class LocalMainGameStateMachine extends Node:
	var current_state: int = GlobalEnums.GameState.SETUP
	var current_campaign_phase: int = GlobalEnums.CampaignPhase.UPKEEP
	var game_manager: GameStateManager
	
	func setup(manager: GameStateManager) -> void:
		game_manager = manager

# Crew Management
func get_crew() -> Array:
	return game_state.current_ship.crew if game_state and game_state.current_ship else []

func add_crew_member(character: CrewMember) -> void:
	if game_state and game_state.current_ship:
		game_state.current_ship.add_crew_member(character)

func remove_crew_member(character: CrewMember) -> void:
	if game_state and game_state.current_ship:
		game_state.current_ship.remove_crew_member(character)

# Game State Management
func start_new_game() -> void:
	game_state = GameStateResource.new()
	transition_to_state(GlobalEnums.GameState.SETUP)

func load_game() -> void:
	if FileAccess.file_exists(SAVE_GAME_FILE_PATH):
		var file = FileAccess.open(SAVE_GAME_FILE_PATH, FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		file.close()
		
		if parse_result == OK:
			game_state.deserialize(json.get_data())
			transition_to_state(GlobalEnums.GameState.CAMPAIGN)

func save_game() -> void:
	if not game_state:
		return
	
	var save_data := game_state.serialize()
	var save_path := _get_save_file_path()
	
	# Ensure directory exists
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	
	var error := _write_save_file(save_path, save_data)
	if error != OK:
		push_error("Failed to save game: %d" % error)

func _write_save_file(path: String, data: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	
	file.store_string(JSON.stringify(data))
	return OK

func _get_save_file_path() -> String:
	var base_path: String = PLATFORM_CONFIG[_current_platform].save_path
	return base_path.path_join("savegame.json")

# Tutorial Management
func start_tutorial_campaign(tutorial_type: GlobalEnums.TutorialType, track: GlobalEnums.TutorialTrack = GlobalEnums.TutorialTrack.CORE_RULES) -> void:
	current_tutorial_type = tutorial_type
	current_tutorial_track = track
	current_tutorial_stage = GlobalEnums.TutorialStage.INTRODUCTION
	game_state.is_tutorial_active = true
	
	tutorial_system.start_tutorial(tutorial_type)
	
	var setup = _get_tutorial_setup(tutorial_type)
	_configure_tutorial_campaign(setup)

func _get_tutorial_setup(type: int) -> Dictionary:
	match type:
		GlobalEnums.TutorialType.QUICK_START:
			return {
				"crew_size": 3,
				"difficulty": GlobalEnums.DifficultyMode.EASY,
				"mission_type": GlobalEnums.MissionType.TUTORIAL,
				"victory_condition": GlobalEnums.VictoryConditionType.TURNS
			}
		GlobalEnums.TutorialType.ADVANCED:
			return {
				"crew_size": 5,
				"difficulty": GlobalEnums.DifficultyMode.NORMAL,
				"mission_type": GlobalEnums.MissionType.TUTORIAL,
				"enable_advanced_features": true
			}
		GlobalEnums.TutorialType.BATTLE_TUTORIAL:
			return {
				"enemy_count": 2,
				"terrain_type": GlobalEnums.TerrainType.CITY,
				"objective": GlobalEnums.MissionObjective.DEFEND,
				"mission_type": GlobalEnums.MissionType.TUTORIAL,
				"difficulty": GlobalEnums.DifficultyMode.EASY
			}
		GlobalEnums.TutorialType.CAMPAIGN_TUTORIAL:
			return {
				"crew_size": 4,
				"difficulty": GlobalEnums.DifficultyMode.NORMAL,
				"victory_condition": GlobalEnums.VictoryConditionType.TURNS,
				"mission_type": GlobalEnums.MissionType.TUTORIAL,
				"enable_faction_mechanics": false
			}
		GlobalEnums.TutorialType.STORY_TUTORIAL:
			var layout = story_track.get_story_layout("introduction")
			return {
				"type": GlobalEnums.MissionType.TUTORIAL,
				"story_elements": layout.story_elements,
				"battlefield": layout.terrain,
				"objectives": layout.objectives,
				"enemies": layout.enemies,
				"crew_size": 3
			}
		_:
			return {}

func _configure_tutorial_campaign(setup: Dictionary) -> void:
	game_state.crew_size = setup.get("crew_size", 4)
	game_state.difficulty_mode = setup.get("difficulty", GlobalEnums.DifficultyMode.NORMAL)
	game_state.victory_condition = setup.get("victory_condition", GlobalEnums.VictoryConditionType.TURNS)
	
	var mission = Mission.new()
	mission.initialize_tutorial(setup)
	
	if game_state.current_ship.crew.is_empty():
		var character_creation = load("res://Resources/CharacterCreationLogic.gd").new()
		game_state.current_ship.add_crew_member(character_creation.create_tutorial_character())
	
	transition_to_state(GlobalEnums.GameState.TUTORIAL)
	_start_tutorial_phase()

func advance_tutorial_stage() -> void:
	var current_stage = current_tutorial_stage
	current_tutorial_stage = GlobalEnums.TutorialStage.values()[(current_stage + 1) % GlobalEnums.TutorialStage.size()]
	
	if current_tutorial_stage == GlobalEnums.TutorialStage.INTRODUCTION:
		complete_current_tutorial()

func complete_current_tutorial() -> void:
	if not completed_tutorials.has(current_tutorial_track):
		completed_tutorials[current_tutorial_track] = []
	completed_tutorials[current_tutorial_track].append(current_tutorial_type)
	
	game_state.is_tutorial_active = false
	tutorial_completed.emit()
	
	# Transition to appropriate state based on tutorial type
	if current_tutorial_type == GlobalEnums.TutorialType.QUICK_START:
		transition_to_state(GlobalEnums.GameState.CAMPAIGN)
	else:
		transition_to_state(GlobalEnums.GameState.CAMPAIGN)

func reset_turn_specific_data() -> void:
	game_state.reset_turn_specific_data()
	mission_generator.refresh_available_missions()
	patron_job_manager.refresh_available_jobs()
	fringe_world_strife_manager.update_strife()

func handle_campaign_phase(phase: GlobalEnums.CampaignPhase) -> void:
	match phase:
		GlobalEnums.CampaignPhase.WORLD_STEP:
			_handle_world_step_phase()
		_:
			# Handle other phases
			pass

func _start_tutorial_phase() -> void:
	if not game_state:
		push_error("Game state not initialized")
		return
		
	game_state.current_state = GlobalEnums.GameState.TUTORIAL
	game_state.is_tutorial_active = true
	
	settings["difficulty"] = GlobalEnums.DifficultyMode.EASY
	settings["enable_tutorials"] = true
	
	match current_tutorial_type:
		GlobalEnums.TutorialType.BATTLE_TUTORIAL:
			main_game_state.current_campaign_phase = GlobalEnums.CampaignPhase.BATTLE
		GlobalEnums.TutorialType.CAMPAIGN_TUTORIAL:
			main_game_state.current_campaign_phase = GlobalEnums.CampaignPhase.WORLD_STEP
		_:
			main_game_state.current_campaign_phase = GlobalEnums.CampaignPhase.CREW_CREATION
	
	state_changed.emit(GlobalEnums.GameState.TUTORIAL)

func check_campaign_victory_condition() -> bool:
	if not game_state:
		return false
		
	match campaign_victory_condition:
		GlobalEnums.CampaignVictoryType.WEALTH_5000:
			if game_state.credits >= 5000:
				campaign_victory_achieved.emit(campaign_victory_condition)
				return true
		GlobalEnums.CampaignVictoryType.REPUTATION_NOTORIOUS:
			if game_state.reputation >= 10:
				campaign_victory_achieved.emit(campaign_victory_condition)
				return true
		GlobalEnums.CampaignVictoryType.STORY_COMPLETE:
			if story_track.is_completed():
				campaign_victory_achieved.emit(campaign_victory_condition)
				return true
		GlobalEnums.CampaignVictoryType.BLACK_ZONE_MASTER:
			if game_state.completed_black_zone_jobs >= 3:
				campaign_victory_achieved.emit(campaign_victory_condition)
				return true
		GlobalEnums.CampaignVictoryType.RED_ZONE_VETERAN:
			if game_state.completed_red_zone_jobs >= 5:
				campaign_victory_achieved.emit(campaign_victory_condition)
				return true
		GlobalEnums.CampaignVictoryType.QUEST_MASTER:
			if game_state.completed_quests >= 10:
				campaign_victory_achieved.emit(campaign_victory_condition)
				return true
	return false

# Resource Management
func get_cached_resource(category: String, id: String) -> Resource:
	return _resource_cache.get(category, {}).get(id)

func cache_resource(category: String, id: String, resource: Resource) -> void:
	if not _resource_cache.has(category):
		_resource_cache[category] = {}
	_resource_cache[category][id] = resource

func _initialize_resource_cache() -> void:
	_resource_cache = {
		"battle_scenes": {},
		"ui_elements": {},
		"effects": {},
		"sounds": {}
	}

# Tutorial Signal Handlers
func _on_tutorial_step_changed(step_id: String) -> void:
	tutorial_step_changed.emit(step_id)

func _on_tutorial_completed(track_id: String) -> void:
	tutorial_completed.emit()
	game_state.is_tutorial_active = false
	_start_world_phase()

func _on_tutorial_step_completed() -> void:
	tutorial_step_completed.emit()

func _on_tutorial_track_completed(track_id: String) -> void:
	tutorial_track_completed.emit(track_id)

func _start_world_phase() -> void:
	if not game_state:
		push_error("Game state not initialized")
		return
		
	game_state.current_state = GlobalEnums.GameState.CAMPAIGN
	main_game_state.current_campaign_phase = GlobalEnums.CampaignPhase.WORLD_STEP
	
	world_generator.generate_current_world()
	expanded_faction_manager.update_factions()
	mission_generator.refresh_available_missions()
	patron_job_manager.refresh_available_jobs()
	
	state_changed.emit(GlobalEnums.GameState.CAMPAIGN)

func _handle_mobile_pause() -> void:
	save_game()
	_cleanup_resources()
	
	# Force garbage collection
	Engine.get_singleton("GarbageCollector").collect()

func _handle_mobile_resume() -> void:
	_initialize_resource_cache()
	if game_state and is_instance_valid(game_state):
		_reload_game_resources()

func _reload_game_resources() -> void:
	if game_state.current_state == GlobalEnums.GameState.BATTLE:
		get_tree().reload_current_scene()
	else:
		_initialize_resource_cache()

func _show_exit_dialog() -> void:
	if is_instance_valid(ui_manager):
		var choice = await ui_manager.show_dialog(
			"Exit Game",
			"Are you sure you want to exit? Any unsaved progress will be lost.",
			["Yes", "No"]
		)
		
		if choice == "Yes":
			get_tree().quit()

# Update campaign phase transition to use correct enum
func transition_to_campaign_phase(phase: GlobalEnums.CampaignPhase) -> void:
	if phase == GlobalEnums.CampaignPhase.WORLD_STEP:
		handle_world_step()
	else:
		handle_campaign_phase(phase)

func handle_world_step() -> void:
	# Handle world step specific logic
	if game_state and is_instance_valid(game_state):
		game_state.current_state = GlobalEnums.GameState.CAMPAIGN
		state_changed.emit(GlobalEnums.GameState.CAMPAIGN)

func _handle_world_step_phase() -> void:
	if game_state and is_instance_valid(game_state):
		# Set state to CAMPAIGN since we're in campaign flow
		game_state.current_state = GlobalEnums.GameState.CAMPAIGN
		state_changed.emit(GlobalEnums.GameState.CAMPAIGN)
		# Handle world step specific logic here
		pass
