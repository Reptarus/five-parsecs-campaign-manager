class_name FiveParsecsCampaignCore
extends Resource

## Five Parsecs Campaign Core Resource
## Framework Bible compliant: Simple data container with validation
## Stores complete campaign data for save/load operations

## Schema version for save file migration (CRITICAL for data integrity)
@export var schema_version: int = 1

@export var campaign_name: String = ""
@export var campaign_id: String = ""
@export var difficulty: int = 0
@export var ironman_mode: bool = false
@export var created_at: String = ""
@export var last_modified: String = ""
@export var version: String = "1.0"
@export var game_phase: String = "creation"

# Core campaign data sections
var crew_data: Dictionary = {}
var captain_data: Dictionary = {}
var ship_data: Dictionary = {}
var equipment_data: Dictionary = {}
var world_data: Dictionary = {}
var progress_data: Dictionary = {}

# Campaign resources (accumulated from character creation)
var credits: int = 0
var story_points: int = 0
var supplies: int = 0
var reputation: int = 0
var patrons: Array = []
var rivals: Array = []
var quest_rumors: int = 0
var victory_conditions: Dictionary = {}  # Victory condition configuration

# SPRINT 6.1: House rules configuration (persisted from wizard)
var house_rules: Array = []

# SPRINT 6.2: Story track setting (persisted from wizard)
var story_track_enabled: bool = false

# Phase 30: Red Zone Jobs (Core Rules Appendix III)
var red_zone_licensed: bool = false
var red_zone_turns_completed: int = 0

# Phase 30: Being Without a Ship (Core Rules p.59)
var has_ship: bool = true
var ship_debt: int = 0  # Remaining loan amount (max financed 70cr)

# QoL data stored for deferred loading (scene tree not ready during _init)
var _pending_qol_data: Dictionary = {}

func _init() -> void:
	created_at = Time.get_datetime_string_from_system()
	last_modified = created_at
	# BUG-031 FIX: Initialize progress_data with default counters
	# so they're never null on first save/load cycle
	progress_data = {
		"turns_played": 0,
		"credits": credits,
		"supplies": supplies,
		"reputation": reputation,
		"story_points": story_points,
		"missions_completed": 0,
		"battles_won": 0,
		"battles_lost": 0,
	}

func get_campaign_id() -> String:
	if campaign_id.is_empty() and not campaign_name.is_empty():
		var ts = str(int(Time.get_unix_time_from_system()))
		campaign_id = campaign_name.to_lower().replace(" ", "_") + "_" + ts
	elif campaign_id.is_empty():
		campaign_id = "campaign_" + str(int(Time.get_unix_time_from_system()))
	return campaign_id

## Data Initialization Methods

func initialize_crew(data: Dictionary) -> void:
	## Initialize crew data from campaign creation
	crew_data = data.duplicate(true)
	_update_modified_time()

func set_captain(data: Dictionary) -> void:
	## Set captain data
	captain_data = data.duplicate(true)
	_update_modified_time()

func initialize_ship(data: Dictionary) -> void:
	## Initialize ship data
	ship_data = data.duplicate(true)
	_update_modified_time()

func set_starting_equipment(data: Dictionary) -> void:
	## Set starting equipment data
	equipment_data = data.duplicate(true)
	_update_modified_time()

func initialize_world(data: Dictionary) -> void:
	## Initialize world generation data
	world_data = data.duplicate(true)
	_update_modified_time()

func set_config(data: Dictionary) -> void:
	## Set campaign configuration
	if data.has("name"):
		campaign_name = data.name
	if data.has("difficulty"):
		difficulty = data.difficulty
	if data.has("ironman_mode"):
		ironman_mode = data.ironman_mode
	_update_modified_time()

func initialize_resources(data: Dictionary) -> void:
	## Initialize campaign resources from character creation
	credits = data.get("credits", 0)
	story_points = data.get("story_points", 0)
	supplies = data.get("supplies", 0)
	reputation = data.get("reputation", 0)
	patrons = data.get("patrons", []).duplicate()
	rivals = data.get("rivals", []).duplicate()
	var rumors = data.get("quest_rumors", [])
	quest_rumors = rumors.size() if rumors is Array else rumors
	_update_modified_time()

func get_resources() -> Dictionary:
	## Get campaign resources
	return {
		"credits": credits,
		"story_points": story_points,
		"supplies": supplies,
		"reputation": reputation,
		"patrons": patrons.duplicate(),
		"rivals": rivals.duplicate(),
		"quest_rumors": quest_rumors
	}

## SPRINT 6.1: House Rules Methods

func set_house_rules(rules: Array) -> void:
	## Set house rules configuration from wizard
	house_rules = rules.duplicate()
	_update_modified_time()

func get_house_rules() -> Array:
	## Get house rules configuration
	return house_rules.duplicate()

## SPRINT 6.2: Story Track Methods

func set_story_track_enabled(enabled: bool) -> void:
	## Set story track enabled setting
	story_track_enabled = enabled
	_update_modified_time()

func get_story_track_enabled() -> bool:
	## Get story track enabled setting
	return story_track_enabled

## Victory Conditions Methods

func set_victory_conditions(conditions: Dictionary) -> void:
	## Set victory conditions configuration
	victory_conditions = conditions.duplicate(true)
	_update_modified_time()

func get_victory_conditions() -> Dictionary:
	## Get victory conditions configuration
	return victory_conditions.duplicate(true)

## Validation Methods

func validate() -> bool:
	## Basic campaign validation
	if campaign_name.is_empty():
		return false
	if crew_data.is_empty():
		return false
	if captain_data.is_empty():
		return false
	return true

func get_validation_errors() -> Array[String]:
	## Get detailed validation errors
	var errors: Array[String] = []
	
	if campaign_name.is_empty():
		errors.append("Campaign name is required")
	
	if crew_data.is_empty():
		errors.append("Crew data is missing")
	elif not crew_data.has("members") or crew_data.members.size() == 0:
		errors.append("Campaign must have at least one crew member")
	
	if captain_data.is_empty():
		errors.append("Captain data is missing")
	elif not captain_data.has("name") or captain_data.name.is_empty():
		errors.append("Captain must have a name")
	
	return errors

## Serialization Methods

func to_dictionary() -> Dictionary:
	## Convert campaign to dictionary for saving
	return {
		"campaign_id": get_campaign_id(),
		"meta": {
			"campaign_id": get_campaign_id(),
			"campaign_name": campaign_name,
			"schema_version": schema_version,
			"difficulty": difficulty,
			"ironman_mode": ironman_mode,
			"created_at": created_at,
			"last_modified": last_modified,
			"version": version,
			"game_phase": game_phase
		},
		"config": {
			"name": campaign_name,
			"difficulty": difficulty,
			"ironman_mode": ironman_mode,
			# SPRINT 6.1/6.2: Include house rules and story track in config
			"house_rules": house_rules.duplicate(),
			"story_track_enabled": story_track_enabled
		},
		"crew": crew_data,
		"captain": captain_data,
		"ship": ship_data,
		"equipment": equipment_data,
		"world": world_data,
		"progress": progress_data,
		"resources": {
			"credits": credits,
			"story_points": story_points,
			"supplies": supplies,
			"reputation": reputation,
			"patrons": patrons.duplicate(),
			"rivals": rivals.duplicate(),
			"quest_rumors": quest_rumors
		},
		# SPRINT 6.1/6.2: Top-level for easy access
		"house_rules": house_rules.duplicate(),
		"story_track_enabled": story_track_enabled,
		# Phase 30: Red Zone Jobs + Shipless State
		"red_zone_licensed": red_zone_licensed,
		"red_zone_turns_completed": red_zone_turns_completed,
		"has_ship": has_ship,
		"ship_debt": ship_debt,
		"victory_conditions": victory_conditions.duplicate(true),
		"qol_data": _build_qol_data()
	}

func _build_qol_data() -> Dictionary:
	## Collect QoL system data for campaign save
	var qol: Dictionary = {}
	var tree = Engine.get_main_loop() if Engine.get_main_loop() else null
	var root = tree.root if tree else null
	if not root:
		return qol
	var journal = root.get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("save_to_dict"):
		qol["journal"] = journal.save_to_dict()
	var npc_tracker = root.get_node_or_null("/root/NPCTracker")
	if npc_tracker and npc_tracker.has_method("serialize"):
		qol["npc_tracker"] = npc_tracker.serialize()
	var checklist = root.get_node_or_null("/root/TurnPhaseChecklist")
	if checklist and checklist.has_method("save_to_dict"):
		qol["turn_checklist"] = checklist.save_to_dict()
	return qol

func from_dictionary(data: Dictionary) -> void:
	## Load campaign from dictionary
	if data.has("meta"):
		var meta = data.meta
		campaign_id = meta.get("campaign_id", "")
		campaign_name = meta.get("campaign_name", "")
		difficulty = meta.get("difficulty", 0)
		ironman_mode = meta.get("ironman_mode", false)
		created_at = meta.get("created_at", "")
		last_modified = meta.get("last_modified", "")
		version = meta.get("version", "1.0")
		game_phase = meta.get("game_phase", "creation")

	# Top-level campaign_id fallback
	if campaign_id.is_empty() and data.has("campaign_id"):
		campaign_id = data.get("campaign_id", "")

	# Load data sections
	crew_data = data.get("crew", {})
	captain_data = data.get("captain", {})
	ship_data = data.get("ship", {})
	equipment_data = data.get("equipment", {})
	world_data = data.get("world", {})
	progress_data = data.get("progress", {})
	# BUG-031 FIX: Ensure counter fields have defaults for saves from older versions
	if not progress_data.has("missions_completed"):
		progress_data["missions_completed"] = 0
	if not progress_data.has("battles_won"):
		progress_data["battles_won"] = 0
	if not progress_data.has("battles_lost"):
		progress_data["battles_lost"] = 0

	# Load resources
	if data.has("resources"):
		var res = data.resources
		credits = res.get("credits", 0)
		story_points = res.get("story_points", 0)
		supplies = res.get("supplies", 0)
		reputation = res.get("reputation", 0)
		patrons = res.get("patrons", []).duplicate()
		rivals = res.get("rivals", []).duplicate()
		quest_rumors = res.get("quest_rumors", 0)
	# Sync resource fields into progress_data for save persistence consistency
	if not progress_data.has("credits") or progress_data["credits"] == null:
		progress_data["credits"] = credits
	if not progress_data.has("supplies") or progress_data["supplies"] == null:
		progress_data["supplies"] = supplies
	if not progress_data.has("reputation") or progress_data["reputation"] == null:
		progress_data["reputation"] = reputation
	if not progress_data.has("story_points") or progress_data["story_points"] == null:
		progress_data["story_points"] = story_points

	# SPRINT 6.1/6.2: Load house rules, story track, and victory conditions
	# Check top-level first, then config for backwards compatibility
	if data.has("house_rules"):
		house_rules = data.get("house_rules", []).duplicate()
	elif data.has("config") and data.config.has("house_rules"):
		house_rules = data.config.get("house_rules", []).duplicate()

	if data.has("story_track_enabled"):
		story_track_enabled = data.get("story_track_enabled", false)
	elif data.has("config") and data.config.has("story_track_enabled"):
		story_track_enabled = data.config.get("story_track_enabled", false)

	# Phase 30: Red Zone Jobs + Shipless State
	if data.has("red_zone_licensed"):
		red_zone_licensed = data.get("red_zone_licensed", false)
	if data.has("red_zone_turns_completed"):
		red_zone_turns_completed = data.get("red_zone_turns_completed", 0)
	if data.has("has_ship"):
		has_ship = data.get("has_ship", true)
	if data.has("ship_debt"):
		ship_debt = data.get("ship_debt", 0)

	if data.has("victory_conditions"):
		victory_conditions = data.get("victory_conditions", {}).duplicate(true)

	# Store QoL data for deferred loading by autoloads
	# (from_dictionary runs during GameState._init before scene tree is ready)
	if data.has("qol_data"):
		_pending_qol_data = data.duplicate(true)

func apply_pending_qol_data() -> void:
	## Called after scene tree is ready to load QoL data into autoloads
	if _pending_qol_data.is_empty():
		return
	var tree = Engine.get_main_loop() if Engine.get_main_loop() else null
	var root = tree.root if tree else null
	if not root:
		return
	var journal = root.get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("load_from_save"):
		journal.load_from_save(_pending_qol_data)
	var npc_tracker = root.get_node_or_null("/root/NPCTracker")
	if npc_tracker and npc_tracker.has_method("deserialize"):
		var qol: Dictionary = _pending_qol_data.get("qol_data", {})
		var npc_data: Dictionary = qol.get("npc_tracker", {})
		if not npc_data.is_empty():
			npc_tracker.deserialize(npc_data)
	var checklist = root.get_node_or_null("/root/TurnPhaseChecklist")
	if checklist and checklist.has_method("load_from_save"):
		checklist.load_from_save(_pending_qol_data)
	_pending_qol_data = {}

## Campaign Management Methods

func start_campaign() -> void:
	## Mark campaign as started (move from creation to active play)
	game_phase = "active"
	_update_modified_time()

func get_campaign_summary() -> Dictionary:
	## Get campaign summary for UI display
	var crew_count = crew_data.get("members", []).size()
	var captain_name = captain_data.get("name", "Unknown")
	var ship_name = ship_data.get("name", "Unnamed Ship")
	
	return {
		"name": campaign_name,
		"difficulty": difficulty,
		"crew_size": crew_count,
		"captain": captain_name,
		"ship": ship_name,
		"created": created_at,
		"status": game_phase,
		"ironman": ironman_mode
	}

func get_crew_members() -> Array:
	## Get crew members array
	return crew_data.get("members", [])

## Returns the crew size for travel cost calculations (GameState compatibility)
func get_crew_size() -> int:
	var members = crew_data.get("members", [])
	if members is Array:
		return members.size()
	return 0

## Returns a crew member by their ID (GameState compatibility for injury/XP systems)
func get_crew_member_by_id(character_id: String) -> Variant:
	var members = crew_data.get("members", [])
	for member in members:
		if member is Dictionary and member.get("id", "") == character_id:
			return member
		elif member is Object and member.get("id") == character_id:
			return member
	return null

func get_current_mission() -> Dictionary:
	## Get current mission data from progress_data (set during world phase)
	return progress_data.get("current_mission", {})

func get_all_equipment() -> Array:
	## Get all equipment items as a flat array, regardless of storage format.
	## Handles both split format (weapons/armor/gear keys) and flat format (equipment key).
	var items: Array = []
	if equipment_data.has("equipment"):
		var eq_list = equipment_data.get("equipment", [])
		if eq_list is Array:
			items.append_array(eq_list)
	for key in ["weapons", "armor", "gear"]:
		var category_items = equipment_data.get(key, [])
		if category_items is Array:
			items.append_array(category_items)
	return items

func get_captain() -> Dictionary:
	## Get captain data
	return captain_data

func get_ship() -> Dictionary:
	## Get ship data
	return ship_data

## Private Methods

func _update_modified_time() -> void:
	## Update last modified timestamp
	last_modified = Time.get_datetime_string_from_system()

## Static Factory Methods

static func create_new_campaign(name: String, difficulty: int = 0) -> FiveParsecsCampaignCore:
	## Create a new campaign with basic settings
	var campaign = FiveParsecsCampaignCore.new()
	campaign.campaign_name = name
	campaign.difficulty = difficulty
	return campaign

static func load_from_file(path: String) -> FiveParsecsCampaignCore:
	## Load campaign from save file
	if not FileAccess.file_exists(path):
		return null

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return null

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		return null

	var campaign = FiveParsecsCampaignCore.new()
	campaign.from_dictionary(json.data)
	return campaign

## JSON-based save (consistent with load_from_file)

func save_to_file(path: String) -> Error:
	## Save campaign to JSON file.
	_update_modified_time()
	var data = to_dictionary()

	# Strip non-serializable Resource references from crew members
	if data.has("crew") and data["crew"] is Dictionary and data["crew"].has("members"):
		var clean_members: Array = []
		for member in data["crew"]["members"]:
			if member is Dictionary:
				var clean = member.duplicate(true)
				clean.erase("character_object")
				clean_members.append(clean)
			elif member is Resource and member.has_method("to_dictionary"):
				clean_members.append(member.to_dictionary())
			else:
				clean_members.append(member)
		data["crew"]["members"] = clean_members

	var json_string = JSON.stringify(data, "\t")

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var error = FileAccess.get_open_error()
		push_error("FiveParsecsCampaignCore: Failed to save: %s (error: %d)" % [path, error])
		return error

	file.store_string(json_string)
	file.close()

	return OK
