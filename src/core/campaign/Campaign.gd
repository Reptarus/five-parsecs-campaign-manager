@tool
extends Resource
class_name FiveParsecsCampaign

## Five Parsecs Campaign Resource
## Manages campaign-level data and progression

# GlobalEnums available as autoload singleton
const Character = preload("res://src/core/character/Character.gd")

signal campaign_started
signal campaign_ended(victory: bool)
signal phase_changed(old_phase: int, new_phase: int)
signal phase_completed(phase: int)
signal phase_started(phase: int)
signal resources_changed(resources: Dictionary)
signal campaign_event_occurred(event_type: String, data: Dictionary)
signal phase_advanced(new_phase: int)
signal resource_changed(resource_type: int, amount: int)
signal reputation_changed(new_reputation: int)
signal turn_advanced(new_turn: int)

@export var campaign_name: String = "":
	set(_value):
		if _value.length() == 0:
			push_error("Campaign name cannot be empty")
			return
		campaign_name = _value

@export var difficulty: int = 1:
	set(_value):
		if _value < 0 or _value > 3:
			push_error("Invalid difficulty level")
			return
		difficulty = _value

@export var victory_condition: int = 0
@export var current_phase: int = 0
@export var resources: Dictionary = {}
@export var crew_size: int = 4
@export var use_story_track: bool = true
@export var starting_reputation: int = 0
@export var credits: int = 1000

var campaign_turn: int = 0:
	set(_value):
		assert(_value >= 0, "Campaign turn cannot be negative")
		campaign_turn = _value

# Crew Data
var crew_members: Array[Character] = []
var captain: Character:
	set(_value):
		assert(_value != null, "Captain cannot be null")
		captain = _value

# Campaign Progress
var story_points: int = 0
var completed_missions: Array = []
var available_missions: Array = []
var faction_standings: Dictionary = {}
var turns_completed: int = 0
var crew_data: Array = []
var settings: Dictionary = {}
var campaign_crew: Array[Character] = []
var current_world: String = "New Hope"
var galactic_war_progress: int = 0
var story_track: Dictionary = {}
var rivals: Array = []
var patrons: Array = []
var quest_rumors: int = 0
var quests: Array = []  # Active and completed quests
var battle_history: Array = []  # History of all battles fought

# Planet persistence - stores data for visited planets
var visited_planets: Dictionary = {}  # planet_id -> planet_data Dictionary
var current_planet_id: String = ""

# Deferred Events System - events that trigger on future conditions
# Each event: {id, trigger_type, event_name, crew_id, effect, turn_created, expires_turn, consumed}
var pending_events: Array = []

func _init() -> void:
	if not Engine.is_editor_hint():
		_initialize_campaign()
	campaign_crew = []

func _initialize_campaign() -> void:
	resources = {
		"credits": 1000,
		"supplies": 5
	}
	resources_changed.emit(resources)

func start_campaign() -> void:
	var old_phase: int = current_phase
	current_phase = 1  # SETUP phase
	campaign_started.emit()
	phase_changed.emit(old_phase, current_phase)
	phase_started.emit(current_phase)

func end_campaign(victory: bool = false) -> void:
	var old_phase: int = current_phase
	phase_completed.emit(current_phase)
	phase_changed.emit(old_phase, current_phase)
	campaign_ended.emit(victory)

func change_phase(new_phase: int) -> void:
	if new_phase == current_phase:
		return

	if new_phase < 0 or new_phase > 5:
		push_error("Invalid campaign _phase: %d" % new_phase)
		return

	var old_phase: int = current_phase
	phase_completed.emit(current_phase)
	current_phase = new_phase
	phase_changed.emit(old_phase, new_phase)
	phase_started.emit(current_phase)

func add_resources(resource_type: int, amount: int) -> void:
	if resource_type < 0:
		push_error("Invalid resource _type: %d" % resource_type)
		return

	if not resources.has(resource_type):
		resources[resource_type] = 0

	resources[resource_type] += amount
	resources_changed.emit(resources)

func remove_resources(resource_type: int, amount: int) -> bool:
	if resource_type < 0:
		push_error("Invalid resource _type: %d" % resource_type)
		return false

	if not resources.has(resource_type) or resources[resource_type] < amount:
		return false

	resources[resource_type] -= amount
	resources_changed.emit(resources)
	return true

func get_resource(resource_type: int) -> int:
	if resource_type < 0:
		push_error("Invalid resource _type: %d" % resource_type)
		return 0

	return resources.get(resource_type, 0)

func serialize() -> Dictionary:
	return {
		"name": campaign_name,
		"difficulty": difficulty,
		"victory_condition": victory_condition,
		"current_phase": current_phase,
		"resources": resources.duplicate(),
		"crew_size": crew_size,
		"use_story_track": use_story_track,
		"current_world": current_world,
		"galactic_war_progress": galactic_war_progress,
		"story_track": story_track,
		"quests": quests.duplicate(),
		"battle_history": battle_history.duplicate(),
		"rivals": rivals.duplicate(),
		"patrons": patrons.duplicate(),
		"quest_rumors": quest_rumors,
		"visited_planets": visited_planets.duplicate(true),
		"current_planet_id": current_planet_id
	}

func deserialize(data: Dictionary) -> void:
	campaign_name = data.get("name", campaign_name)
	difficulty = data.get("difficulty", difficulty)
	victory_condition = data.get("victory_condition", victory_condition)
	current_phase = data.get("current_phase", current_phase)
	resources = data.get("resources", {}).duplicate()
	crew_size = data.get("crew_size", crew_size)
	use_story_track = data.get("use_story_track", use_story_track)
	current_world = data.get("current_world", "New Hope")
	galactic_war_progress = data.get("galactic_war_progress", 0)
	story_track = data.get("story_track", {})
	quests = data.get("quests", [])
	battle_history = data.get("battle_history", [])
	rivals = data.get("rivals", [])
	patrons = data.get("patrons", [])
	quest_rumors = data.get("quest_rumors", 0)
	visited_planets = data.get("visited_planets", {}).duplicate(true)
	current_planet_id = data.get("current_planet_id", "")

func add_mission(mission: Dictionary) -> void:
	available_missions.append(mission)

func complete_mission(mission: Dictionary) -> void:
	if mission in available_missions:
		available_missions.erase(mission)
		completed_missions.append(mission)

func set_faction_standing(faction: String, _value: float) -> void:
	faction_standings[faction] = clampf(_value, -100.0, 100.0)

func get_faction_standing(faction: String) -> float:
	return faction_standings.get(faction, 0.0)

func get_crew_size() -> int:
	return crew_members.size()

func get_crew_members() -> Array:
	"""Get crew members array for external access"""
	print("Campaign.get_crew_members() called - crew_members.size(): %d" % crew_members.size())

	var crew_data: Array = []
	for member in crew_members:
		print("  Processing crew member: %s (type: %s)" % [member.name if member.has_method("get") else "unknown", member.get_class() if member.has_method("get_class") else "unknown"])
		if member.has_method("to_dictionary"):
			var dict = member.to_dictionary()
			print("    Converted to dictionary with name: %s" % dict.get("character_name", "MISSING"))
			crew_data.append(dict)
		else:
			print("    Already dictionary")
			crew_data.append(member)  # Already dictionary

	print("Campaign.get_crew_members() returning %d crew members" % crew_data.size())
	return crew_data

func has_equipment(equipment_id: int) -> bool:
	for member in crew_members:
		if member.has_equipment(equipment_id):
			return true
	return false

# Serialization
func to_dictionary() -> Dictionary:
	var crew_data: Array = []
	for member in crew_members:
		crew_data.append(member.to_dictionary())

	return {
		"campaign_name": campaign_name,
		"difficulty": difficulty,
		"current_phase": current_phase,
		"campaign_turn": campaign_turn,
		"crew_members": crew_data,
		"captain": captain.to_dictionary() if captain else null,
		"resources": resources.duplicate(),
		"story_points": story_points,
		"completed_missions": completed_missions.duplicate(),
		"available_missions": available_missions.duplicate(),
		"faction_standings": faction_standings.duplicate(),
		"pending_events": pending_events.duplicate(true)
	}

func from_dictionary(data: Dictionary) -> void:
	campaign_name = data.get("campaign_name", "New Campaign")
	difficulty = data.get("difficulty", 1)
	current_phase = data.get("current_phase", 1)
	campaign_turn = data.get("campaign_turn", 0)

	# Load crew data
	crew_members.clear()
	for member_data in data.get("crew_members", []):
		var member := Character.new()
		member.from_dictionary(member_data)
		crew_members.append(member)

	# Load captain data
	var captain_data = data.get("captain", null)
	if captain_data:
		captain = Character.new()
		captain.from_dictionary(captain_data)

	resources = data.get("resources", {}).duplicate()
	story_points = data.get("story_points", 0)
	completed_missions = data.get("completed_missions", []).duplicate()
	available_missions = data.get("available_missions", []).duplicate()
	faction_standings = data.get("faction_standings", {}).duplicate()
	pending_events = data.get("pending_events", []).duplicate(true)

func configure(config: Dictionary) -> void:
	if config.has("name"):
		campaign_name = config.name
	if config.has("difficulty"):
		difficulty = config.difficulty

func set_crew(crew: Array) -> void:
	crew_data = crew.duplicate(true)

func set_resources(new_resources: Dictionary) -> void:
	resources = new_resources.duplicate(true)

func add_resource(resource_type: int, amount: int) -> void:
	if not resources.has(resource_type):
		resources[resource_type] = 0
	resources[resource_type] += amount
	resource_changed.emit(resource_type, resources[resource_type])

func advance_phase() -> void:
	current_phase += 1
	phase_advanced.emit(current_phase)

func save_data() -> Dictionary:
	return {
		"campaign_name": campaign_name,
		"difficulty": difficulty,
		"current_phase": current_phase,
		"turns_completed": turns_completed,
		"crew_data": crew_data,
		"resources": resources,
		"settings": settings
	}

func load_data(data: Dictionary) -> void:
	campaign_name = data.get("campaign_name", "")
	difficulty = data.get("difficulty", 1)
	current_phase = data.get("current_phase", 0)
	turns_completed = data.get("turns_completed", 0)
	crew_data = data.get("crew_data", [])
	resources = data.get("resources", {})
	settings = data.get("settings", {})

func advance_turn() -> void:
	campaign_turn += 1
	turn_advanced.emit(campaign_turn)

func modify_reputation(amount: int) -> void:
	starting_reputation += amount
	reputation_changed.emit(starting_reputation)

func check_galactic_war_progress() -> void:
	var roll = randi() % 100 + 1
	if roll > 90:
		galactic_war_progress += 1
		campaign_event_occurred.emit("galactic_war_progress", {"progress": galactic_war_progress})

func get_current_world() -> String:
	return current_world

func set_current_world(world_name: String) -> void:
	current_world = world_name

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_get_property(obj: Object, property: String, default_value: Variant = null) -> Variant:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
		var value = obj.get(property)
		return value if value != null else default_value
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null

## SPRINT 6.2: Campaign Creation Data Initialization

func initialize_from_dict(creation_data: Dictionary) -> void:
	"""Initialize campaign from campaign creation data structure"""
	print("FiveParsecsCampaign: Initializing from creation data...")
	
	# Basic campaign info
	campaign_name = creation_data.get("campaign_name", "New Campaign")
	
	# Get campaign config section
	var config = creation_data.get("campaign_config", {})
	campaign_name = config.get("campaign_name", campaign_name)
	difficulty = config.get("difficulty", 1)
	victory_condition = config.get("victory_condition", 0)
	use_story_track = config.get("use_story_track", true)
	
	# Initialize crew from creation data
	var crew_section = creation_data.get("crew", {})
	if crew_section.has("members"):
		crew_data = crew_section.get("members", [])
		crew_size = crew_data.size()
		print("FiveParsecsCampaign: Initialized %d crew members" % crew_size)
		
		# Initialize crew_members array from crew_data
		crew_members.clear()
		for member_data in crew_data:
			var character = Character.new()
			character.initialize_from_creation_data(member_data)
			crew_members.append(character)
	
	# Initialize captain from creation data
	var captain_section = creation_data.get("captain", {})
	if captain_section.has("character_data"):
		captain = Character.new()
		captain.initialize_from_creation_data(captain_section.get("character_data", {}))
		print("FiveParsecsCampaign: Initialized captain: %s" % captain.character_name)
	
	# Initialize resources from equipment/config
	var equipment_section = creation_data.get("equipment", {})
	var starting_credits = equipment_section.get("starting_credits", 1000)
	resources = {
		"credits": starting_credits,
		"supplies": 5,
		"story_points": 0
	}
	credits = starting_credits
	
	# Initialize world info
	var world_section = creation_data.get("world", {})
	current_world = world_section.get("name", "New Hope")
	
	# Initialize ship data if available
	var ship_section = creation_data.get("ship", {})
	if ship_section.size() > 0:
		# Store ship data in campaign settings for later use
		settings["ship"] = ship_section
	
	# Campaign progression setup
	current_phase = 1  # Start in Travel phase
	campaign_turn = 1
	story_points = 0
	turns_completed = 0
	
	# Initialize arrays
	completed_missions = []
	available_missions = []
	faction_standings = {}
	
	print("FiveParsecsCampaign: Initialization complete - %s (Difficulty: %d)" % [campaign_name, difficulty])

func get_creation_summary() -> Dictionary:
	"""Get summary of campaign creation for display purposes"""
	return {
		"name": campaign_name,
		"difficulty": difficulty,
		"crew_size": crew_size,
		"captain_name": captain.character_name if captain else "Unknown",
		"starting_credits": credits,
		"current_world": current_world,
		"victory_condition": victory_condition
	}

## Planet Persistence Methods

## Record a visit to a planet with associated data
func visit_planet(planet_id: String, planet_data: Dictionary) -> void:
	if planet_id.is_empty():
		push_error("Campaign.visit_planet: planet_id cannot be empty")
		return
	
	# Store or update planet data
	if not visited_planets.has(planet_id):
		visited_planets[planet_id] = {}
	
	# Merge new data with existing data
	visited_planets[planet_id].merge(planet_data)
	
	# Update current planet if not set
	if current_planet_id.is_empty():
		current_planet_id = planet_id
	
	print("Campaign: Visited planet %s" % planet_id)

## Check if a planet has been visited
func has_visited_planet(planet_id: String) -> bool:
	return visited_planets.has(planet_id)

## Get data for a visited planet
func get_visited_planet(planet_id: String) -> Dictionary:
	if not visited_planets.has(planet_id):
		return {}
	return visited_planets[planet_id].duplicate(true)

## Update planet state by merging new data with existing data
func update_planet_state(planet_id: String, new_data: Dictionary) -> void:
	if not visited_planets.has(planet_id):
		push_warning("Campaign.update_planet_state: Planet %s not yet visited, creating entry" % planet_id)
		visited_planets[planet_id] = {}
	
	# Merge new data into existing data
	visited_planets[planet_id].merge(new_data)
	print("Campaign: Updated planet %s state" % planet_id)

## Get list of all visited planet IDs
func get_all_visited_planets() -> Array:
	return visited_planets.keys()
