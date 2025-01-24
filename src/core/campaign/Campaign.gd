@tool
class_name FiveParcsecsCampaign
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

signal campaign_started
signal campaign_ended(victory: bool)
signal phase_changed(phase: int)
signal resources_changed(resources: Dictionary)

@export var campaign_name: String = "":
	set(value):
		if value.length() == 0:
			push_error("Campaign name cannot be empty")
			return
		campaign_name = value

@export var difficulty: int = GameEnums.DifficultyLevel.NORMAL:
	set(value):
		if not value in GameEnums.DifficultyLevel.values():
			push_error("Invalid difficulty level")
			return
		difficulty = value

@export var victory_condition: int = GameEnums.FiveParcsecsCampaignVictoryType.STANDARD
@export var current_phase: int = GameEnums.CampaignPhase.NONE
@export var resources: Dictionary = {}
@export var crew_size: int = GameEnums.CrewSize.FOUR
@export var use_story_track: bool = true

var campaign_turn: int = 0:
	set(value):
		assert(value >= 0, "Campaign turn cannot be negative")
		campaign_turn = value

# Crew Data
var crew_members: Array[Character] = []
var captain: Character:
	set(value):
		assert(value != null, "Captain cannot be null")
		captain = value

# Campaign Progress
var story_points: int = 0
var completed_missions: Array = []
var available_missions: Array = []
var faction_standings: Dictionary = {}

func _init() -> void:
	if not Engine.is_editor_hint():
		_initialize_campaign()

func _initialize_campaign() -> void:
	resources = {
		"credits": 100,
		"supplies": 50,
		"fuel": 20,
		"reputation": 0
	}
	resources_changed.emit(resources)

func start_campaign() -> void:
	current_phase = GameEnums.CampaignPhase.SETUP
	campaign_started.emit()
	phase_changed.emit(current_phase)

func end_campaign(victory: bool = false) -> void:
	current_phase = GameEnums.CampaignPhase.END
	campaign_ended.emit(victory)
	phase_changed.emit(current_phase)

func change_phase(new_phase: int) -> void:
	if new_phase == current_phase:
		return
	
	if not new_phase in GameEnums.CampaignPhase.values():
		push_error("Invalid campaign phase: %d" % new_phase)
		return
	
	current_phase = new_phase
	phase_changed.emit(current_phase)

func add_resources(resource_type: int, amount: int) -> void:
	if not resource_type in GameEnums.ResourceType.values():
		push_error("Invalid resource type: %d" % resource_type)
		return
	
	if not resources.has(resource_type):
		resources[resource_type] = 0
	
	resources[resource_type] += amount
	resources_changed.emit(resources)

func remove_resources(resource_type: int, amount: int) -> bool:
	if not resource_type in GameEnums.ResourceType.values():
		push_error("Invalid resource type: %d" % resource_type)
		return false
	
	if not resources.has(resource_type) or resources[resource_type] < amount:
		return false
	
	resources[resource_type] -= amount
	resources_changed.emit(resources)
	return true

func get_resource(resource_type: int) -> int:
	if not resource_type in GameEnums.ResourceType.values():
		push_error("Invalid resource type: %d" % resource_type)
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

func set_faction_standing(faction: String, value: float) -> void:
	faction_standings[faction] = clampf(value, -100.0, 100.0)

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
	var crew_data = []
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
	difficulty = data.get("difficulty", GameEnums.DifficultyLevel.NORMAL)
	current_phase = data.get("current_phase", GameEnums.CampaignPhase.SETUP)
	campaign_turn = data.get("campaign_turn", 0)
	
	# Load crew data
	crew_members.clear()
	for member_data in data.get("crew_members", []):
		var member = Character.new()
		member.from_dictionary(member_data)
		crew_members.append(member)
	
	# Load captain data
	var captain_data = data.get("captain")
	if captain_data:
		captain = Character.new()
		captain.from_dictionary(captain_data)
	
	resources = data.get("resources", {}).duplicate()
	story_points = data.get("story_points", 0)
	completed_missions = data.get("completed_missions", []).duplicate()
	available_missions = data.get("available_missions", []).duplicate()
	faction_standings = data.get("faction_standings", {}).duplicate()