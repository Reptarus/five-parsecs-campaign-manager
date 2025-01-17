class_name Campaign
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

signal campaign_started
signal campaign_ended
signal phase_changed(new_phase: GameEnums.CampaignPhase)
signal resources_changed(resource_type: GameEnums.ResourceType, amount: int)

# Campaign Data
var campaign_name: String
var difficulty: GameEnums.DifficultyLevel = GameEnums.DifficultyLevel.NORMAL
var current_phase: GameEnums.CampaignPhase = GameEnums.CampaignPhase.SETUP
var campaign_turn: int = 0

# Crew Data
var crew_members: Array[Character] = []
var captain: Character

# Resources
var resources: Dictionary = {
	GameEnums.ResourceType.CREDITS: 1000,
	GameEnums.ResourceType.SUPPLIES: 5,
	GameEnums.ResourceType.TECH_PARTS: 0,
	GameEnums.ResourceType.PATRON: 0
}

# Campaign Progress
var story_points: int = 0
var completed_missions: Array = []
var available_missions: Array = []
var faction_standings: Dictionary = {}

func start_campaign(config: Dictionary) -> void:
	campaign_name = config.get("name", "New Campaign")
	difficulty = config.get("difficulty", GameEnums.DifficultyLevel.NORMAL)
	
	# Set initial resources based on difficulty
	resources[GameEnums.ResourceType.CREDITS] = config.get("starting_credits", 1000)
	resources[GameEnums.ResourceType.SUPPLIES] = config.get("starting_supplies", 5)
	
	# Set crew data
	crew_members = config.get("crew", [])
	captain = config.get("captain", null)
	
	campaign_started.emit()

func end_campaign() -> void:
	campaign_ended.emit()

func advance_phase(new_phase: GameEnums.CampaignPhase) -> void:
	current_phase = new_phase
	phase_changed.emit(new_phase)

func get_resource(type: GameEnums.ResourceType) -> int:
	return resources.get(type, 0)

func set_resource(type: GameEnums.ResourceType, amount: int) -> void:
	resources[type] = amount
	resources_changed.emit(type, amount)

func add_resource(type: GameEnums.ResourceType, amount: int) -> void:
	var current = get_resource(type)
	set_resource(type, current + amount)

func remove_resource(type: GameEnums.ResourceType, amount: int) -> bool:
	var current = get_resource(type)
	if current >= amount:
		set_resource(type, current - amount)
		return true
	return false

func has_enough_resource(type: GameEnums.ResourceType, amount: int) -> bool:
	return get_resource(type) >= amount

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