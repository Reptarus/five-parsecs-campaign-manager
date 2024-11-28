extends Node

class_name GameManager

signal game_state_changed(new_state: int)
signal battlefield_generated(battlefield_data: Dictionary)

const BattlefieldGeneratorScene := preload("res://Resources/BattlePhase/BattlefieldGenerator.gd")
const GameOverScreenScene := preload("res://Resources/Utilities/GameOverScreen.tscn")
const GameSettingsResource := preload("res://Resources/GameData/GameSettings.gd")
const UIManager := preload("res://UI/UIManager.gd")
const TerrainGenerator := preload("res://Resources/GameData/TerrainGenerator.gd")
const GalacticWarManager := preload("res://Resources/CampaignManagement/GalacticWarManager.gd")

var game_state: GameState
var ui_manager: Node
var terrain_generator: Node
var galactic_war_manager: Node
var settings: GameSettingsResource
var battlefield_generator: Node

# Add deferred loading variables
var _scenes_to_load: Dictionary = {}
var _is_initialized: bool = false

# Add deferred loading for heavy resources
var _loaded_resources := {}
var _loading_queue := []

# Add platform-specific constants
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

# Add platform-specific properties
var _current_platform: String
var _is_mobile: bool
var _screen_orientation: int = DisplayServer.WINDOW_MODE_FULLSCREEN
var _safe_area: Rect2
var _android_initialized := false

# Update platform-specific constants to use correct DisplayServer enums
const SCREEN_ORIENTATIONS := {
	"PORTRAIT": 0,  # DisplayServer.SCREEN_VERTICAL
	"LANDSCAPE": 1, # DisplayServer.SCREEN_HORIZONTAL
	"REVERSE_LANDSCAPE": 2, # DisplayServer.SCREEN_HORIZONTAL_REVERSE
	"SENSOR_LANDSCAPE": 3  # DisplayServer.SCREEN_SENSOR_LANDSCAPE 
}

# Add resource cache initialization
var _resource_cache: Dictionary = {}

func _init() -> void:
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
	DisplayServer.screen_set_orientation(_screen_orientation)
	
	# Initialize safe area
	_safe_area = DisplayServer.get_display_safe_area()
	
	# Configure touch settings
	Input.use_accumulated_input = false
	
	if _current_platform == "Android":
		_setup_android_initialization()

func _configure_desktop_platform() -> void:
	var config = PLATFORM_CONFIG[_current_platform]
	Engine.max_fps = config.max_fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if config.vsync else DisplayServer.VSYNC_DISABLED)

func _setup_android_initialization() -> void:
	if not _android_initialized:
		get_tree().set_auto_accept_quit(false)
		if not get_tree().root.is_connected("size_changed", _on_window_size_changed):
			get_tree().root.connect("size_changed", _on_window_size_changed)
		_android_initialized = true

func _on_window_size_changed() -> void:
	if _is_mobile:
		_handle_orientation_change()
		_update_safe_area()
		if ui_manager and is_instance_valid(ui_manager):
			ui_manager.update_layout()

func _handle_orientation_change() -> void:
	if not _is_mobile:
		return
		
	var window_size = DisplayServer.window_get_size()
	var is_portrait = window_size.y > window_size.x
	
	# Use window mode instead of orientation
	if is_portrait:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_window().mode = Window.MODE_FULLSCREEN
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_window().mode = Window.MODE_FULLSCREEN

func _update_safe_area() -> void:
	_safe_area = DisplayServer.get_display_safe_area()

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

func _handle_mobile_pause() -> void:
	save_settings()
	_cleanup_resources()

func _handle_mobile_resume() -> void:
	_initialize_resource_cache()
	if game_state and is_instance_valid(game_state):
		_reload_game_resources()

func _handle_back_button() -> void:
	if game_state.current_state == GlobalEnums.GameState.BATTLE:
		_show_exit_dialog()
	else:
		get_tree().quit()

func _show_exit_dialog() -> void:
	if ui_manager and is_instance_valid(ui_manager):
		var choice = await ui_manager.show_dialog(
			"Exit Game",
			"Are you sure you want to exit? Any unsaved progress will be lost.",
			["Yes", "No"]
		)
		
		if choice == "Yes":
			get_tree().quit()

func _cleanup_resources() -> void:
	_resource_cache.clear()
	_loading_queue.clear()
	
	# Request garbage collection
	if Engine.has_singleton("GarbageCollector"):
		Engine.get_singleton("GarbageCollector").collect()

func _reload_game_resources() -> void:
	_initialize_resource_cache()
	if _loading_queue.is_empty():
		return
	
	# Reload essential resources
	for path in _scenes_to_load.values():
		if not path in _loading_queue:
			_loading_queue.append(path)
	
	_process_loading_queue()

func initialize() -> void:
	if _is_initialized:
		return
	
	for key in _scenes_to_load:
		var scene = load(_scenes_to_load[key])
		if scene:
			_scenes_to_load[key] = scene
		else:
			push_error("Failed to load scene: " + _scenes_to_load[key])
	
	_is_initialized = true

# Add cleanup method
func cleanup() -> void:
	if _is_initialized:
		_scenes_to_load.clear()
		_is_initialized = false

func _ready() -> void:
	_initialize_resource_cache()
	
	game_state = GameState.new()
	game_state.current_state = GlobalEnums.GameState.SETUP
	
	# Initialize managers as Nodes with their scripts
	ui_manager = Node.new()
	ui_manager.set_script(UIManager)
	add_child(ui_manager)
	
	terrain_generator = Node.new()
	terrain_generator.set_script(TerrainGenerator)
	add_child(terrain_generator)
	
	galactic_war_manager = Node.new()
	galactic_war_manager.set_script(GalacticWarManager)
	galactic_war_manager.initialize(game_state)
	add_child(galactic_war_manager)
	
	battlefield_generator = Node.new()
	battlefield_generator.set_script(BattlefieldGeneratorScene)
	add_child(battlefield_generator)
	
	settings = load_settings()

func start_new_game() -> void:
	game_state.current_state = GlobalEnums.GameState.CAMPAIGN
	game_state_changed.emit(GlobalEnums.GameState.CAMPAIGN)
	ui_manager.change_screen(GlobalEnums.ScreenType.CAMPAIGN_SETUP)
	game_state.crew_size = 5  # Default crew size, can be adjusted
	galactic_war_manager.initialize_factions()

func start_campaign_turn() -> void:
	game_state.current_state = GlobalEnums.GameState.CAMPAIGN
	game_state_changed.emit(GlobalEnums.GameState.CAMPAIGN)
	game_state.campaign_turn += 1
	ui_manager.change_screen(GlobalEnums.ScreenType.WORLD_VIEW)
	# Note: update_mission_list() method is not present in the provided GameState.gd
	# You may need to implement this method or adjust the logic accordingly
	galactic_war_manager.process_galactic_war_turn()

func start_mission(mission: Mission) -> void:
	if mission.start_mission(game_state.current_crew.members):
		game_state.current_state = GlobalEnums.GameState.BATTLE
		game_state_changed.emit(GlobalEnums.GameState.BATTLE)
		ui_manager.change_screen(GlobalEnums.ScreenType.BATTLE)
		# Note: combat_manager is not present in the provided GameState.gd
		# You may need to implement this or adjust the logic accordingly
		generate_battlefield()
	else:
		ui_manager.show_message("Cannot start mission. Check crew requirements.")

func end_mission(victory: bool) -> void:
	game_state.current_state = GlobalEnums.GameState.CAMPAIGN
	game_state_changed.emit(GlobalEnums.GameState.CAMPAIGN)
	ui_manager.change_screen(GlobalEnums.ScreenType.POST_BATTLE)
	process_mission_results(victory)

func process_mission_results(victory: bool) -> void:
	var rewards: Dictionary = game_state.current_mission.get_reward()
	if victory:
		game_state.add_credits(rewards.credits)
		game_state.current_crew.gain_experience(rewards.xp)
		handle_loot(rewards.loot)
	else:
		game_state.current_crew.apply_casualties()
	
	game_state.remove_mission(game_state.current_mission)
	game_state.current_mission = null
	check_campaign_progress()

func generate_new_world() -> void:
	var new_world: Location = game_state.world_generator.generate_world()
	game_state.available_locations.append(new_world)
func travel_to_world(world: GameWorld) -> void:
	game_state.current_location = world
	ui_manager.update_world_info()
	game_state.fringe_world_strife_manager.update_world_strife(world)

func recruit_crew_member(character: Character) -> void:
	if game_state.current_crew.can_add_member():
		game_state.current_crew.add_member(character)
		ui_manager.update_crew_info()
	else:
		ui_manager.show_message("Crew is at maximum capacity.")

func upgrade_character(character: Character, upgrade: Dictionary) -> void:
	if character.can_apply_upgrade(upgrade):
		character.apply_upgrade(upgrade)
		ui_manager.update_crew_info()
	else:
		ui_manager.show_message("Upgrade not available for this character.")

func buy_equipment(item: Equipment) -> void:
	if game_state.remove_credits(item.value):
		game_state.current_crew.add_equipment(item)
		ui_manager.update_crew_info()
	else:
		ui_manager.show_message("Not enough credits to buy this item.")

func sell_equipment(item: Equipment) -> void:
	game_state.add_credits(item.get_effectiveness())
	game_state.current_crew.remove_equipment(item)
	ui_manager.update_crew_info()

func handle_game_over(victory: bool) -> void:
	ui_manager.show_game_over_screen(victory)
	game_state.current_state = GlobalEnums.GameState.GAME_OVER
	game_state_changed.emit(GlobalEnums.GameState.GAME_OVER)
	SaveGame.change_scene_to_file(GameOverScreenScene)

func generate_battlefield() -> void:
	battlefield_generator.initialize()
	var battlefield_data = battlefield_generator.generate_battlefield(game_state.current_mission)
	
	# Update game state with the generated battlefield data
	game_state.current_mission.battlefield_data = battlefield_data
	# Emit signal to notify UI or other systems about the generated battlefield
	emit_signal("battlefield_generated", battlefield_data)
	
	# Place objectives using the combat manager
	game_state.combat_manager.place_objectives(battlefield_data)

func handle_loot(loot: Array) -> void:
	for item in loot:
		if item is Equipment:
				game_state.add_to_ship_stash(item)
	ui_manager.update_inventory()

func check_campaign_progress() -> void:
	if game_state.check_victory_conditions():
		handle_game_over(true)
	elif game_state.check_defeat_conditions():
		handle_game_over(false)

static func roll_dice(num_dice: int, sides: int) -> int:
	var total := 0
	for i in range(num_dice):
		total += randi() % sides + 1
	return total

func handle_player_action(action: int, params: Dictionary = {}) -> void:
	match action:
		GlobalEnums.PlayerAction.MOVE:
			game_state.combat_manager.handle_move(params.character, params.new_position)
		GlobalEnums.PlayerAction.ATTACK:
			game_state.combat_manager.handle_attack(params.attacker, params.target)
		GlobalEnums.PlayerAction.END_TURN:
			game_state.combat_manager.handle_end_turn()
		_:
			push_warning("Unhandled player action: %s" % action)

func start_battle(scene_tree: SceneTree) -> void:
	var battle_scene: PackedScene = preload("res://Resources/BattlePhase/Scenes/Battle.tscn")
	var battle_instance: Node = battle_scene.instantiate()
	battle_instance.initialize(game_state, game_state.current_mission)
	scene_tree.root.add_child(battle_instance)
	game_state.current_state = GlobalEnums.GameState.BATTLE
	game_state_changed.emit(GlobalEnums.GameState.BATTLE)

func start_story_track_tutorial() -> void:
	game_state.current_state = GlobalEnums.GameState.CAMPAIGN
	game_state_changed.emit(GlobalEnums.GameState.CAMPAIGN)
	ui_manager.change_screen(str(GlobalEnums.ScreenType.TUTORIAL_STORY_TRACK))

func open_compendium() -> void:
	print_debug("Opening compendium")
	ui_manager.change_screen(str(GlobalEnums.ScreenType.COMPENDIUM))

func save_settings() -> Error:
	var save_path = "user://settings.tres"
	return ResourceSaver.save(settings, save_path)

func load_settings() -> GameSettingsResource:
	var save_path = "user://settings.tres"
	if ResourceLoader.exists(save_path):
		var loaded = ResourceLoader.load(save_path)
		if loaded is GameSettingsResource:
			return loaded
		push_error("Invalid settings resource type")
	return GameSettingsResource.new()

func load_resource(path: String) -> void:
	if OS.get_name() == "Android":
		if not path in _loading_queue:
			_loading_queue.append(path)
			_process_loading_queue()
	else:
		return ResourceLoader.load(path)

func _process_loading_queue() -> void:
	if _loading_queue.is_empty():
		return
		
	var path = _loading_queue[0]
	var status = ResourceLoader.load_threaded_get_status(path)
	
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_loaded_resources[path] = ResourceLoader.load_threaded_get(path)
			_loading_queue.pop_front()
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			pass # Still loading
		_:
			_loading_queue.pop_front() # Error occurred

func _initialize_resource_cache() -> void:
	_resource_cache = {
		"battle_scenes": {},
		"ui_elements": {},
		"effects": {},
		"sounds": {}
	}
