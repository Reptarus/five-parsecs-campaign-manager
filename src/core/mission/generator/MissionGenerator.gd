@tool
extends Node

## Mission Generator for Five Parsecs
## Handles creation of random missions with appropriate difficulty and rewards

signal mission_generated(mission)
signal mission_generation_failed(reason)

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Mission = preload("res://src/core/mission/base/mission.gd")
const MissionReward = preload("res://src/core/mission/base/MissionReward.gd")

# Define enums to match the test file
# These values match the test file enum which is simplified compared to the global enums
enum MissionType {BATTLE = 0, RECON = 1, SALVAGE = 2}

# Map of test enum values to global enum values 
const MISSION_TYPE_MAP = {
	MissionType.BATTLE: GameEnums.MissionType.BLACK_ZONE, # Using BLACK_ZONE as BATTLE
	MissionType.RECON: GameEnums.MissionType.PATROL, # Using PATROL as RECON
	MissionType.SALVAGE: GameEnums.MissionType.RAID # Using RAID as SALVAGE
}

# Fix unsafe enum usages
func _has_key(dict, key):
	if dict == null:
		return false
	if dict is Dictionary:
		return dict.has(key)
	return false

func _has_value(dict, value):
	if dict == null:
		return false
	if dict is Dictionary:
		return dict.values().has(value)
	return false

# Safe method check
func _has_method(obj, method_name):
	if obj == null:
		return false
	if obj is Object:
		return obj.has_method(method_name)
	return false

# Configuration variables
@export var min_difficulty: int = 1
@export var max_difficulty: int = 5
@export var enable_scaling: bool = true
@export var mission_templates: Array[Dictionary] = []

# Current state
var current_mission: Dictionary = {}
var rng = RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()
	_load_mission_templates()

func _ready() -> void:
	# Ensure proper initialization in scene tree
	if mission_templates.is_empty():
		_load_mission_templates()

## Generate a mission with the specified type or random type if none specified
func generate_mission(mission_type: int = -1) -> Resource:
	# Create base mission instance
	var mission = Mission.new()
	
	# Set basic properties
	mission.mission_id = str(randi())
	mission.mission_name = _generate_mission_name(mission_type)
	mission.description = _generate_mission_description(mission_type)
	
	# Handle mission type conversion between test enum and global enum
	var actual_type = mission_type
	if mission_type < 0:
		actual_type = _random_mission_type()
	
	# Convert from test mission type to global mission type if necessary
	if _has_key(MISSION_TYPE_MAP, actual_type):
		# When system requires global enum, convert it
		if _has_method(mission, "set_mission_type"):
			mission.set_mission_type(MISSION_TYPE_MAP[actual_type])
		else:
			mission.mission_type = MISSION_TYPE_MAP[actual_type]
	else:
		# Direct assignment for test
		mission.mission_type = actual_type
	
	# Set difficulty
	var difficulty = rng.randi_range(min_difficulty, max_difficulty)
	mission.difficulty = difficulty
	
	# Create and set reward
	var reward = _generate_reward(difficulty)
	if reward:
		if _has_method(mission, "set_reward"):
			mission.set_reward(reward)
		else:
			mission.rewards = reward.to_dict()
	
	# Emit signal
	mission_generated.emit(mission)
	
	return mission

## Generate a mission specifically of the given type
func generate_mission_of_type(mission_type: int) -> Resource:
	return generate_mission(mission_type)

## Load mission templates from configuration
func _load_mission_templates() -> void:
	# In a real implementation, this would load from files
	# For now, we'll create some basic templates programmatically
	mission_templates = [
		{
			"type": MissionType.BATTLE,
			"name_templates": ["Battle at %s", "Conflict in %s", "Skirmish on %s"],
			"description_templates": ["Engage enemy forces at %s.", "Defeat opponents in combat at %s."]
		},
		{
			"type": MissionType.RECON,
			"name_templates": ["Reconnaissance of %s", "Recon Mission: %s", "Scout %s"],
			"description_templates": ["Gather intelligence in %s without being detected.", "Scout the area of %s and report findings."]
		},
		{
			"type": MissionType.SALVAGE,
			"name_templates": ["Salvage Operation: %s", "Recovery at %s", "Retrieve from %s"],
			"description_templates": ["Recover valuable materials from %s.", "Salvage critical components in the ruins of %s."]
		}
	]

## Generate a random mission name
func _generate_mission_name(mission_type: int) -> String:
	var template = _get_name_template(mission_type)
	var location = _generate_random_location()
	return template % location

## Generate a mission description
func _generate_mission_description(mission_type: int) -> String:
	var template = _get_description_template(mission_type)
	var location = _generate_random_location()
	return template % location

## Get name template based on mission type
func _get_name_template(mission_type: int) -> String:
	for template in mission_templates:
		if template.type == mission_type:
			var templates = template.name_templates
			return templates[rng.randi() % templates.size()]
	
	# Default template if type not found
	return "Mission to %s"

## Get description template based on mission type
func _get_description_template(mission_type: int) -> String:
	for template in mission_templates:
		if template.type == mission_type:
			var templates = template.description_templates
			return templates[rng.randi() % templates.size()]
	
	# Default template if type not found
	return "Complete objectives at %s."

## Generate a random location name
func _generate_random_location() -> String:
	var locations = [
		"Alpha Base", "Zeta Station", "Epsilon Outpost", "Gamma Complex",
		"Proxima IV", "Cygnus Ruins", "Orion's Belt", "Nova Prime",
		"Sector 7", "The Wastes", "Abandoned Colony", "The Frontier"
	]
	return locations[rng.randi() % locations.size()]

## Generate a random mission type
func _random_mission_type() -> int:
	var types = [
		MissionType.BATTLE,
		MissionType.RECON,
		MissionType.SALVAGE
	]
	return types[rng.randi() % types.size()]

## Generate rewards based on difficulty
func _generate_reward(difficulty: int) -> Resource:
	var reward = MissionReward.new()
	
	# Base rewards
	var base_credits = 100 * difficulty
	reward.credits = base_credits
	reward.reputation = difficulty
	
	# Apply scaling if enabled
	if enable_scaling:
		reward.apply_difficulty_scaling(difficulty)
	
	return reward