@tool
extends Node

## Mission Generator for Five Parsecs
## Handles creation of random missions with appropriate difficulty and rewards

signal mission_generated(mission)
signal mission_generation_failed(reason)
const Mission = preload("res://src/core/mission/base/mission.gd")
const MissionReward = preload("res://src/core/mission/base/MissionReward.gd")

# Define enums to match the test file
# These values match the test file enum which is simplified compared to the global enums
enum MissionType {BATTLE = 0, RECON = 1, SALVAGE = 2}

# Map of test enum values to global enum values 
const MISSION_TYPE_MAP = {
	MissionType.BATTLE: GlobalEnums.MissionType.BLACK_ZONE, # Using BLACK_ZONE as BATTLE
	MissionType.RECON: GlobalEnums.MissionType.PATROL, # Using PATROL as RECON
	MissionType.SALVAGE: GlobalEnums.MissionType.RAID # Using RAID as SALVAGE
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
var _mission_locations: Array = []

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

## Load mission templates from JSON configuration
func _load_mission_templates() -> void:
	var file := FileAccess.open("res://data/mission_templates.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			var json_data: Dictionary = json.data
			_mission_locations = json_data.get("mission_locations", [])
			var json_templates: Array = json_data.get("mission_templates", [])
			# Map JSON type strings to our local enum
			var type_map: Dictionary = {
				"OPPORTUNITY": MissionType.SALVAGE,
				"PATRON": MissionType.BATTLE,
				"QUEST": MissionType.RECON,
				"RIVAL": MissionType.BATTLE,
			}
			for tmpl in json_templates:
				var type_str: String = tmpl.get("type", "")
				var mapped_type: int = type_map.get(type_str, MissionType.BATTLE)
				# Convert {LOCATION} placeholder to %s for compatibility
				var name_tmpls: Array = []
				for t in tmpl.get("title_templates", []):
					name_tmpls.append(t.replace("{LOCATION}", "%s").replace("{OBJECTIVE}", "complete the mission"))
				var desc_tmpls: Array = []
				for t in tmpl.get("description_templates", []):
					desc_tmpls.append(t.replace("{LOCATION}", "%s").replace("{OBJECTIVE}", "complete the objective"))
				# Only add if we don't already have this type (first match wins)
				var already_has := false
				for existing in mission_templates:
					if existing.get("type", -1) == mapped_type:
						already_has = true
						# Merge additional templates into existing entry
						existing.get("name_templates", []).append_array(name_tmpls)
						existing.get("description_templates", []).append_array(desc_tmpls)
						break
				if not already_has:
					mission_templates.append({
						"type": mapped_type,
						"name_templates": name_tmpls,
						"description_templates": desc_tmpls,
					})
		file.close()

	# Fallback if JSON load failed or was empty
	if mission_templates.is_empty():
		push_warning("MissionGenerator: Failed to load mission_templates.json, using fallback")
		mission_templates = [
			{"type": MissionType.BATTLE, "name_templates": ["Battle at %s"], "description_templates": ["Engage enemy forces at %s."]},
			{"type": MissionType.RECON, "name_templates": ["Reconnaissance of %s"], "description_templates": ["Gather intelligence in %s."]},
			{"type": MissionType.SALVAGE, "name_templates": ["Salvage Operation: %s"], "description_templates": ["Recover materials from %s."]},
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

## Generate a random location name from JSON data
func _generate_random_location() -> String:
	if not _mission_locations.is_empty():
		return _mission_locations[rng.randi() % _mission_locations.size()]
	# Fallback
	return ["Alpha Base", "Zeta Station", "Mining Settlement", "Research Station"].pick_random()

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