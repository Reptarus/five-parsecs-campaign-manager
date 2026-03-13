extends Node

const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const GameState = preload("res://src/core/state/GameState.gd")

signal game_state_changed(new_state: int)
signal campaign_phase_changed(new_phase: int)
signal difficulty_changed(new_difficulty: int)
signal credits_changed(new_amount: int)
signal supplies_changed(new_amount: int)
signal reputation_changed(new_amount: int)
signal story_progress_changed(new_amount: int)

@export var initial_credits: int = 1000
@export var initial_supplies: int = 5
@export var initial_reputation: int = 0

var game_state: GameState = null
var campaign_phase: int = 0 # Using 0 as default (equivalent to NONE)
var difficulty_level: int = GameEnums.DifficultyLevel.NORMAL
var credits: int = initial_credits
var supplies: int = initial_supplies
var reputation: int = initial_reputation
var story_progress: int = 0

# Settings
var enable_tutorials: bool = true
var auto_save_enabled: bool = true
var language: String = "English"
var settings: Dictionary = {
	"disable_tutorial_popup": false,
	"tutorial_active": false,
}

# Temp data keys for inter-screen communication
const TEMP_KEY_SELECTED_CHARACTER := "selected_character"
const TEMP_KEY_CREW_ADD_MODE := "crew_add_mode"
const TEMP_KEY_RETURN_SCREEN := "return_screen"

# Temp data storage (cleared on scene change)
var _temp_data: Dictionary = {}

func _ready() -> void:
	# Initialize with default values
	set_credits(initial_credits)
	set_supplies(initial_supplies)
	set_reputation(initial_reputation)
	set_story_progress(0)
	load_settings()
	# Defer campaign sync to ensure all autoloads are ready
	call_deferred("_connect_campaign_signals")

func _connect_campaign_signals() -> void:
	var gs = get_node_or_null("/root/GameState")
	if not gs:
		return
	if gs.has_signal("campaign_loaded"):
		gs.campaign_loaded.connect(_on_campaign_loaded)
	# If a campaign was already auto-loaded before we connected, sync now
	var campaign = gs.get("current_campaign")
	if campaign != null:
		_on_campaign_loaded(campaign)

## Sync internal resource tracking from loaded campaign data
func _on_campaign_loaded(campaign) -> void:
	if campaign == null:
		return
	var loaded_credits = campaign.get("credits")
	if loaded_credits != null:
		set_credits(int(loaded_credits))
	var loaded_supplies = campaign.get("supplies")
	if loaded_supplies != null:
		supplies = int(loaded_supplies)
		supplies_changed.emit(supplies)
	var loaded_reputation = campaign.get("reputation")
	if loaded_reputation != null:
		reputation = int(loaded_reputation)
		reputation_changed.emit(reputation)
	var loaded_story = campaign.get("story_points")
	if loaded_story != null:
		story_progress = int(loaded_story)
		story_progress_changed.emit(story_progress)

# State management
func set_game_state(new_state: GameState) -> void:
	if game_state != new_state:
		game_state = new_state
		game_state_changed.emit(game_state)

func set_campaign_phase(new_phase: int) -> void:
	if campaign_phase != new_phase:
		campaign_phase = new_phase
		campaign_phase_changed.emit(campaign_phase)

func set_difficulty(new_difficulty: int) -> void:
	if difficulty_level != new_difficulty:
		difficulty_level = new_difficulty
		difficulty_changed.emit(difficulty_level)

# Settings management
func set_tutorials_enabled(enabled: bool) -> void:
	enable_tutorials = enabled
	
func set_auto_save_enabled(enabled: bool) -> void:
	auto_save_enabled = enabled
	
func set_language(language_name: String) -> void:
	language = language_name
	# You might want to emit a signal or perform additional actions here

# Resource management
func set_credits(new_amount: int) -> void:
	if credits != new_amount:
		credits = new_amount
		# Sync back to campaign Resource so saves persist the correct value
		if game_state and game_state.current_campaign and "credits" in game_state.current_campaign:
			game_state.current_campaign.credits = new_amount
		credits_changed.emit(credits)

func set_supplies(new_amount: int) -> void:
	if supplies != new_amount:
		supplies = new_amount
		# Sync back to campaign Resource so saves persist
		var camp = game_state.current_campaign if game_state else null
		if camp and "supplies" in camp:
			camp.supplies = new_amount
		supplies_changed.emit(supplies)

func set_reputation(new_amount: int) -> void:
	if reputation != new_amount:
		reputation = new_amount
		# Sync back to campaign Resource so saves persist the correct value
		var camp = game_state.current_campaign if game_state else null
		if camp and "reputation" in camp:
			camp.reputation = new_amount
		reputation_changed.emit(reputation)

func set_story_progress(new_amount: int) -> void:
	if story_progress != new_amount:
		story_progress = new_amount
		# Sync back to campaign Resource so saves persist the correct value
		var camp = game_state.current_campaign if game_state else null
		if camp and "story_points" in camp:
			camp.story_points = new_amount
		story_progress_changed.emit(story_progress)

# Getters
func get_game_state() -> GameState:
	return game_state

func get_campaign_phase() -> int:
	return campaign_phase

func get_difficulty() -> int:
	return difficulty_level

func get_credits() -> int:
	return credits

func get_supplies() -> int:
	return supplies

func get_reputation() -> int:
	return reputation

func get_story_progress() -> int:
	return story_progress

# Campaign lifecycle
func has_active_campaign() -> bool:
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("has_active_campaign"):
		return gs.has_active_campaign()
	return false

func start_new_campaign() -> void:
	# Campaign creation wizard handles actual campaign creation
	# via CampaignCreationUI → GameState.set_current_campaign()
	pass

func set_tutorial_state(enabled: bool) -> void:
	settings["tutorial_active"] = enabled

# Temp data methods for inter-screen communication
func set_temp_data(key: String, value) -> void:
	_temp_data[key] = value

func get_temp_data(key: String, default = null):
	return _temp_data.get(key, default)

func has_temp_data(key: String) -> bool:
	return _temp_data.has(key)

func clear_temp_data(key: String) -> void:
	_temp_data.erase(key)

func mark_campaign_modified() -> void:
	pass

# Navigation helpers
func navigate_to_screen(screen_name: String) -> void:
	var router = get_node_or_null("/root/SceneRouter")
	if router:
		router.navigate_to(screen_name)
	else:
		push_error("GameStateManager: SceneRouter not found")

func navigate_to_scene_path(scene_path: String) -> void:
	var router = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to_scene"):
		router.navigate_to_scene(scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)

# Save/load settings
func save_settings() -> void:
	var config = ConfigFile.new()
	for key in settings:
		config.set_value("settings", key, settings[key])
	config.save("user://game_settings.cfg")

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load("user://game_settings.cfg") == OK:
		for key in settings:
			settings[key] = config.get_value("settings", key, settings[key])

# --- Campaign data helper ---

func _get_campaign() -> Resource:
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_current_campaign"):
		return gs.get_current_campaign()
	return null

# --- Credit arithmetic ---

func add_credits(amount: int) -> void:
	set_credits(get_credits() + amount)

func remove_credits(amount: int) -> bool:
	var current = get_credits()
	if current < amount:
		return false
	set_credits(current - amount)
	return true

func modify_credits(amount: int) -> void:
	set_credits(max(0, get_credits() + amount))

# --- Story point / progress arithmetic ---

func add_story_points(amount: int) -> void:
	var c = _get_campaign()
	if c:
		c.story_points += amount

func modify_story_progress(amount: int) -> void:
	set_story_progress(max(0, get_story_progress() + amount))

# --- Reputation arithmetic ---

func add_reputation(amount: int) -> void:
	set_reputation(get_reputation() + amount)

# --- Crew data delegation ---

func get_crew_members() -> Array:
	var c = _get_campaign()
	if c and c.has_method("get_crew_members"):
		return c.get_crew_members()
	return []

func get_crew_size() -> int:
	var c = _get_campaign()
	if c and c.has_method("get_crew_size"):
		return c.get_crew_size()
	return 0

# --- Ship data delegation ---

func get_ship() -> Dictionary:
	var c = _get_campaign()
	if c and c.has_method("get_ship"):
		return c.get_ship()
	return {}

func get_ship_debt() -> int:
	var c = _get_campaign()
	if c:
		return c.ship_data.get("debt", 0)
	return 0

func set_ship_debt(amount: int) -> void:
	var c = _get_campaign()
	if c:
		c.ship_data["debt"] = amount

# --- World / Location delegation ---

func get_current_world() -> Dictionary:
	var c = _get_campaign()
	if c:
		return c.world_data
	return {}

func get_current_world_data() -> Dictionary:
	return get_current_world()

func get_location() -> String:
	var c = _get_campaign()
	if c:
		return c.world_data.get("current_location", "")
	return ""

func set_location(loc: String) -> void:
	var c = _get_campaign()
	if c:
		c.world_data["current_location"] = loc

# --- Patrons / Rivals delegation ---

func get_patrons() -> Array:
	var c = _get_campaign()
	if c:
		return c.patrons.duplicate()
	return []

func set_patrons(p: Array) -> void:
	var c = _get_campaign()
	if c:
		c.patrons = p.duplicate()

func get_rivals() -> Array:
	var c = _get_campaign()
	if c:
		return c.rivals.duplicate()
	return []

func set_rivals(r: Array) -> void:
	var c = _get_campaign()
	if c:
		c.rivals = r.duplicate()

# --- Mission / Battle (temp_data based) ---

func set_current_mission(mission: Dictionary) -> void:
	set_temp_data("current_mission", mission)

func set_pending_combat(combat_data: Dictionary) -> void:
	set_temp_data("pending_combat", combat_data)

# --- Victory conditions / Story track delegation ---

func get_victory_conditions() -> Dictionary:
	var c = _get_campaign()
	if c and c.has_method("get_victory_conditions"):
		return c.get_victory_conditions()
	return {}

func set_victory_conditions(conditions: Dictionary) -> void:
	var c = _get_campaign()
	if c and c.has_method("set_victory_conditions"):
		c.set_victory_conditions(conditions)

func is_story_track_enabled() -> bool:
	var c = _get_campaign()
	if c and c.has_method("get_story_track_enabled"):
		return c.get_story_track_enabled()
	return false

func set_story_track_enabled(enabled: bool) -> void:
	var c = _get_campaign()
	if c and c.has_method("set_story_track_enabled"):
		c.set_story_track_enabled(enabled)

func set_custom_victory_targets(targets: Dictionary) -> void:
	var c = _get_campaign()
	if c:
		c.victory_conditions["custom_targets"] = targets

func set_quest_rumors(count: int) -> void:
	var c = _get_campaign()
	if c:
		c.quest_rumors = count
