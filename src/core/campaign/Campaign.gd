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
	# Sprint 26.2: Build on to_dictionary() for key consistency, then add extra fields
	var base = to_dictionary()

	# Add additional fields not in to_dictionary()
	base["victory_condition"] = victory_condition
	base["crew_size"] = crew_size
	base["use_story_track"] = use_story_track
	base["current_world"] = current_world
	base["galactic_war_progress"] = galactic_war_progress
	base["story_track"] = story_track
	base["quests"] = quests.duplicate()
	base["battle_history"] = battle_history.duplicate()
	base["rivals"] = rivals.duplicate()
	base["patrons"] = patrons.duplicate()
	base["quest_rumors"] = quest_rumors
	base["visited_planets"] = visited_planets.duplicate(true)
	base["current_planet_id"] = current_planet_id

	return base

func deserialize(data: Dictionary) -> void:
	# Sprint 26.2: Call from_dictionary() first for core fields, then handle extras
	from_dictionary(data)

	# Handle additional fields not in from_dictionary()
	victory_condition = data.get("victory_condition", victory_condition)
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

## Returns the user-selected crew size (affects enemy scaling, patron jobs, etc.)
## Use get_active_crew_count() if you need the actual number of crew members
func get_crew_size() -> int:
	# Return stored crew_size if set, otherwise fall back to actual member count
	return crew_size if crew_size > 0 else crew_members.size()

## Returns the actual number of crew members currently in the roster
## Use this for upkeep calculations, display, etc.
func get_active_crew_count() -> int:
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

## Get a specific crew member by their character_id
## Required by GameState.add_crew_experience() for XP distribution
func get_crew_member_by_id(character_id: String) -> Character:
	for member in crew_members:
		if member.character_id == character_id:
			return member

	push_warning("Campaign.get_crew_member_by_id: Character not found: %s" % character_id)
	return null

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
	captain = null  # Reset captain to avoid duplication

	for member_data in data.get("crew_members", []):
		var member := Character.new()
		member.from_dictionary(member_data)
		crew_members.append(member)

		# FIX: Check if this member is the captain - avoid duplication
		if member.is_captain:
			captain = member

	# Load captain data ONLY if not found in crew_members
	# This prevents captain duplication
	var captain_data = data.get("captain", null)
	if captain_data and captain == null:
		# Check if captain is already in crew_members by ID or name
		var captain_id = captain_data.get("character_id", "")
		var captain_name = captain_data.get("name", captain_data.get("character_name", ""))
		var found_in_crew = false

		for member in crew_members:
			if (captain_id and member.character_id == captain_id) or \
			   (captain_name and member.name == captain_name):
				captain = member
				captain.is_captain = true
				found_in_crew = true
				break

		# Only create new captain if not found in crew
		if not found_in_crew:
			captain = Character.new()
			captain.from_dictionary(captain_data)
			captain.is_captain = true
			# Add to crew_members if not already there
			if captain not in crew_members:
				crew_members.append(captain)

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

## Initialize crew from creation data - called by CampaignFinalizationService
func initialize_crew(data: Dictionary) -> void:
	"""Initialize crew_members from creation data dictionary."""
	crew_members.clear()
	crew_data = []

	var members = data.get("members", data.get("crew_data", []))
	if members.is_empty() and data.size() > 0 and not data.has("members"):
		# Data might be the members array directly
		members = data.values() if data is Dictionary else []

	for member_data in members:
		if member_data is Dictionary:
			var character = Character.new()
			if character.has_method("initialize_from_creation_data"):
				character.initialize_from_creation_data(member_data)
			elif character.has_method("from_dictionary"):
				character.from_dictionary(member_data)
			crew_members.append(character)
			crew_data.append(member_data)

	crew_size = crew_members.size()
	print("Campaign.initialize_crew(): Initialized %d crew members" % crew_size)

## Set captain from creation data - called by CampaignFinalizationService
func set_captain(captain_data: Dictionary) -> void:
	"""Set captain from dictionary data."""
	if captain_data.is_empty():
		return

	# Check if captain_data has nested character_data
	var char_data = captain_data.get("character_data", captain_data)

	captain = Character.new()
	if captain.has_method("initialize_from_creation_data"):
		captain.initialize_from_creation_data(char_data)
	elif captain.has_method("from_dictionary"):
		captain.from_dictionary(char_data)

	captain.is_captain = true
	print("Campaign.set_captain(): Set captain - %s" % captain.character_name)

	# Ensure captain is in crew_members
	var captain_in_crew = false
	for member in crew_members:
		if member.character_id == captain.character_id:
			captain_in_crew = true
			break

	if not captain_in_crew:
		crew_members.append(captain)
		crew_size = crew_members.size()

## Initialize ship from creation data - called by CampaignFinalizationService
func initialize_ship(ship_data: Dictionary) -> void:
	"""Store ship data from creation."""
	if ship_data.is_empty():
		return

	settings["ship"] = ship_data.duplicate(true)
	print("Campaign.initialize_ship(): Ship data stored - %s" % ship_data.get("name", "Unnamed Ship"))

## Set starting equipment from creation data - called by CampaignFinalizationService
func set_starting_equipment(equipment_data: Dictionary) -> void:
	"""Set starting equipment and credits."""
	if equipment_data.is_empty():
		return

	# Extract credits
	var starting_credits = equipment_data.get("starting_credits", equipment_data.get("credits", 1000))
	credits = starting_credits
	resources["credits"] = starting_credits

	# Store equipment list
	var equipment_list = equipment_data.get("equipment", equipment_data.get("items", []))
	settings["starting_equipment"] = equipment_list
	print("Campaign.set_starting_equipment(): Set %d credits, %d items" % [starting_credits, equipment_list.size()])

## Initialize world from creation data - called by CampaignFinalizationService
func initialize_world(world_data: Dictionary) -> void:
	"""Set starting world information."""
	if world_data.is_empty():
		return

	current_world = world_data.get("name", world_data.get("world_name", "New Hope"))
	settings["starting_world"] = world_data.duplicate(true)
	print("Campaign.initialize_world(): Starting world - %s" % current_world)

## Set house rules from creation config - called by CampaignFinalizationService
func set_house_rules(enabled_rules: Array) -> void:
	"""Store enabled house rule IDs from campaign creation."""
	settings["house_rules"] = enabled_rules.duplicate()
	print("Campaign.set_house_rules(): %d house rules enabled" % enabled_rules.size())

## Get enabled house rules for gameplay systems
func get_house_rules() -> Array:
	"""Get the array of enabled house rule IDs."""
	return settings.get("house_rules", [])

## Check if a specific house rule is enabled
func is_house_rule_enabled(rule_id: String) -> bool:
	"""Check if a specific house rule is enabled."""
	var enabled_rules = get_house_rules()
	return rule_id in enabled_rules

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
	
	# Merge new data into existing data (overwrite=true to update existing keys)
	visited_planets[planet_id].merge(new_data, true)
	print("Campaign: Updated planet %s state" % planet_id)

## Get list of all visited planet IDs
func get_all_visited_planets() -> Array:
	return visited_planets.keys()
