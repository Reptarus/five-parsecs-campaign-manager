class_name FiveParsecsCampaignCore
extends Resource

## Five Parsecs Campaign Core Resource
## Framework Bible compliant: Simple data container with validation
## Stores complete campaign data for save/load operations

## Schema version for save file migration (CRITICAL for data integrity)
@export var schema_version: int = 1

@export var campaign_name: String = ""
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
var patrons: Array = []
var rivals: Array = []
var quest_rumors: int = 0
var victory_conditions: Dictionary = {}  # Victory condition configuration

func _init() -> void:
	created_at = Time.get_datetime_string_from_system()
	last_modified = created_at

## Data Initialization Methods

func initialize_crew(data: Dictionary) -> void:
	"""Initialize crew data from campaign creation"""
	crew_data = data.duplicate(true)
	_update_modified_time()
	print("FiveParsecsCampaignCore: Crew data initialized with %d members" % crew_data.get("members", []).size())

func set_captain(data: Dictionary) -> void:
	"""Set captain data"""
	captain_data = data.duplicate(true)
	_update_modified_time()
	print("FiveParsecsCampaignCore: Captain set - %s" % captain_data.get("name", "Unknown"))

func initialize_ship(data: Dictionary) -> void:
	"""Initialize ship data"""
	ship_data = data.duplicate(true)
	_update_modified_time()
	print("FiveParsecsCampaignCore: Ship initialized - %s" % ship_data.get("name", "Unnamed Ship"))

func set_starting_equipment(data: Dictionary) -> void:
	"""Set starting equipment data"""
	equipment_data = data.duplicate(true)
	_update_modified_time()
	print("FiveParsecsCampaignCore: Equipment initialized")

func initialize_world(data: Dictionary) -> void:
	"""Initialize world generation data"""
	world_data = data.duplicate(true)
	_update_modified_time()
	print("FiveParsecsCampaignCore: World initialized")

func set_config(data: Dictionary) -> void:
	"""Set campaign configuration"""
	if data.has("name"):
		campaign_name = data.name
	if data.has("difficulty"):
		difficulty = data.difficulty
	if data.has("ironman_mode"):
		ironman_mode = data.ironman_mode
	_update_modified_time()

func initialize_resources(data: Dictionary) -> void:
	"""Initialize campaign resources from character creation"""
	credits = data.get("credits", 0)
	story_points = data.get("story_points", 0)
	patrons = data.get("patrons", []).duplicate()
	rivals = data.get("rivals", []).duplicate()
	var rumors = data.get("quest_rumors", [])
	quest_rumors = rumors.size() if rumors is Array else rumors
	_update_modified_time()
	print("FiveParsecsCampaignCore: Resources initialized - Credits: %d, SP: %d, Patrons: %d, Rivals: %d, Rumors: %d" % [
		credits, story_points, patrons.size(), rivals.size(), quest_rumors
	])

func get_resources() -> Dictionary:
	"""Get campaign resources"""
	return {
		"credits": credits,
		"story_points": story_points,
		"patrons": patrons.duplicate(),
		"rivals": rivals.duplicate(),
		"quest_rumors": quest_rumors
	}

## Validation Methods

func validate() -> bool:
	"""Basic campaign validation"""
	if campaign_name.is_empty():
		return false
	if crew_data.is_empty():
		return false
	if captain_data.is_empty():
		return false
	return true

func get_validation_errors() -> Array[String]:
	"""Get detailed validation errors"""
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
	"""Convert campaign to dictionary for saving"""
	return {
		"meta": {
			"campaign_name": campaign_name,
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
			"ironman_mode": ironman_mode
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
			"patrons": patrons.duplicate(),
			"rivals": rivals.duplicate(),
			"quest_rumors": quest_rumors
		}
	}

func from_dictionary(data: Dictionary) -> void:
	"""Load campaign from dictionary"""
	if data.has("meta"):
		var meta = data.meta
		campaign_name = meta.get("campaign_name", "")
		difficulty = meta.get("difficulty", 0)
		ironman_mode = meta.get("ironman_mode", false)
		created_at = meta.get("created_at", "")
		last_modified = meta.get("last_modified", "")
		version = meta.get("version", "1.0")
		game_phase = meta.get("game_phase", "creation")
	
	# Load data sections
	crew_data = data.get("crew", {})
	captain_data = data.get("captain", {})
	ship_data = data.get("ship", {})
	equipment_data = data.get("equipment", {})
	world_data = data.get("world", {})
	progress_data = data.get("progress", {})

	# Load resources
	if data.has("resources"):
		var res = data.resources
		credits = res.get("credits", 0)
		story_points = res.get("story_points", 0)
		patrons = res.get("patrons", []).duplicate()
		rivals = res.get("rivals", []).duplicate()
		quest_rumors = res.get("quest_rumors", 0)

## Campaign Management Methods

func start_campaign() -> void:
	"""Mark campaign as started (move from creation to active play)"""
	game_phase = "active"
	_update_modified_time()
	print("FiveParsecsCampaignCore: Campaign started - %s" % campaign_name)

func get_campaign_summary() -> Dictionary:
	"""Get campaign summary for UI display"""
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
	"""Get crew members array"""
	return crew_data.get("members", [])

func get_captain() -> Dictionary:
	"""Get captain data"""
	return captain_data

func get_ship() -> Dictionary:
	"""Get ship data"""
	return ship_data

## Private Methods

func _update_modified_time() -> void:
	"""Update last modified timestamp"""
	last_modified = Time.get_datetime_string_from_system()

## Static Factory Methods

static func create_new_campaign(name: String, difficulty: int = 0) -> FiveParsecsCampaignCore:
	"""Create a new campaign with basic settings"""
	var campaign = FiveParsecsCampaignCore.new()
	campaign.campaign_name = name
	campaign.difficulty = difficulty
	return campaign

static func load_from_file(path: String) -> FiveParsecsCampaignCore:
	"""Load campaign from save file"""
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