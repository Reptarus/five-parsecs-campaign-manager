@tool
extends Resource
class_name FiveParsecsCampaignCore

## Five Parsecs Campaign Resource
## Manages campaign-level data and progression

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
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

@export var difficulty: int = GlobalEnums.DifficultyLevel.STANDARD:
	set(_value):
		if not _value in GlobalEnums.DifficultyLevel.values():
			push_error("Invalid difficulty level")
			return
		difficulty = _value

@export var victory_condition: int = GlobalEnums.FiveParsecsCampaignVictoryType.STORY_COMPLETE
@export var current_phase: int = GlobalEnums.FiveParsecsCampaignPhase.NONE
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

func _init() -> void:
	if not Engine.is_editor_hint():
		_initialize_campaign()
	campaign_crew = []

func _initialize_campaign() -> void:
	resources = {
		GlobalEnums.ResourceType.CREDITS: 1000,
		GlobalEnums.ResourceType.SUPPLIES: 5
	}
	resources_changed.emit(resources)

func start_campaign() -> void:
	var old_phase: int = current_phase
	current_phase = safe_get_property(GlobalEnums, "FiveParsecsCampaignPhase").SETUP
	campaign_started.emit()
	phase_changed.emit(old_phase, current_phase)
	phase_started.emit(current_phase)

func end_campaign(victory: bool = false) -> void:
	var old_phase: int = current_phase
	phase_completed.emit(current_phase) # warning: return value discarded (intentional)
	# Note: END phase removed from official enum - campaigns now cycle through phases
	phase_changed.emit(old_phase, current_phase) # warning: return value discarded (intentional)
	campaign_ended.emit(victory) # warning: return value discarded (intentional)

func change_phase(new_phase: int) -> void:
	if new_phase == current_phase:
		return

	if not new_phase in safe_get_property(GlobalEnums, "FiveParsecsCampaignPhase").values():
		push_error("Invalid campaign _phase: %d" % new_phase)
		return

	var old_phase: int = current_phase
	phase_completed.emit(current_phase) # warning: return value discarded (intentional)
	current_phase = new_phase
	phase_changed.emit(old_phase, new_phase) # warning: return value discarded (intentional)
	phase_started.emit(current_phase) # warning: return value discarded (intentional)

func add_resources(resource_type: int, amount: int) -> void:
	if not resource_type in GlobalEnums.ResourceType.values():
		push_error("Invalid resource _type: %d" % resource_type)
		return

	if not resources.has(resource_type):
		resources[resource_type] = 0

	resources[resource_type] += amount
	resources_changed.emit(resources) # warning: return value discarded (intentional)

func remove_resources(resource_type: int, amount: int) -> bool:
	if not resource_type in GlobalEnums.ResourceType.values():
		push_error("Invalid resource _type: %d" % resource_type)
		return false

	if not resources.has(resource_type) or resources[resource_type] < amount:
		return false

	resources[resource_type] -= amount
	resources_changed.emit(resources) # warning: return value discarded (intentional)
	return true

func get_resource(resource_type: int) -> int:
	if not resource_type in GlobalEnums.ResourceType.values():
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
		"use_story_track": use_story_track
	}

func deserialize(data: Dictionary) -> void:
	campaign_name = data.get("name", campaign_name)
	difficulty = data.get("difficulty", difficulty)
	victory_condition = data.get("victory_condition", victory_condition)
	current_phase = data.get("current_phase", current_phase)
	resources = data.get("resources", {}).duplicate()
	crew_size = data.get("crew_size", crew_size)
	use_story_track = data.get("use_story_track", use_story_track)

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
		"faction_standings": faction_standings.duplicate()
	}

func from_dictionary(data: Dictionary) -> void:
	campaign_name = data.get("campaign_name", "New Campaign")
	difficulty = data.get("difficulty", GlobalEnums.DifficultyLevel.STANDARD)
	current_phase = data.get("current_phase", GlobalEnums.FiveParsecsCampaignPhase.SETUP)
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
