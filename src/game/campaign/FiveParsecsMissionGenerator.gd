# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends BaseMissionGenerator

const Self = preload("res://src/game/campaign/FiveParsecsMissionGenerator.gd")
const BaseMissionGenerator = preload("res://src/base/campaign/BaseMissionGenerator.gd")
# Five Parsecs specific mission types
enum FiveParsecsMissionType {
	BATTLE = 0,
	PATRON_JOB = 1,
	STORY_MISSION = 2,
	RIVAL_ENCOUNTER = 3,
	SALVAGE_RUN = 4,
	RESCUE_OPERATION = 5,
	BOUNTY_HUNT = 6,
	EXPLORATION = 7,
	CONVOY_ESCORT = 8,
	DEFENSE = 9
}

# Five Parsecs specific mission properties — loaded from mission_generation_data.json
var mission_locations: Array = []
var enemy_factions: Array = []
## Mission generation data loaded from JSON
var _mission_gen_data: Dictionary = {}

func _init() -> void:
	# Initialize signals
	if not has_signal("generation_started"):
		add_user_signal("generation_started")
	if not has_signal("mission_generated"):
		add_user_signal("mission_generated")
	if not has_signal("generation_completed"):
		add_user_signal("generation_completed")

	# Ensure mission_types is initialized
	if mission_types == null:
		mission_types = {}

	# Override mission types with Five Parsecs specific types
	mission_types = {
		FiveParsecsMissionType.BATTLE: "Battle",
		FiveParsecsMissionType.PATRON_JOB: "Patron Job",
		FiveParsecsMissionType.STORY_MISSION: "Story Mission",
		FiveParsecsMissionType.RIVAL_ENCOUNTER: "Rival Encounter",
		FiveParsecsMissionType.SALVAGE_RUN: "Salvage Run",
		FiveParsecsMissionType.RESCUE_OPERATION: "Rescue Operation",
		FiveParsecsMissionType.BOUNTY_HUNT: "Bounty Hunt",
		FiveParsecsMissionType.EXPLORATION: "Exploration",
		FiveParsecsMissionType.CONVOY_ESCORT: "Convoy Escort",
		FiveParsecsMissionType.DEFENSE: "Defense"
	}

	# Load mission generation data from JSON
	_load_mission_gen_data()

	# Apply loaded data (or fallback)
	if mission_locations.is_empty():
		mission_locations = _mission_gen_data.get("locations", [
			"Abandoned Outpost", "Derelict Ship", "Urban Ruins", "Mining Facility",
			"Research Station", "Jungle Wilderness", "Desert Wasteland", "Space Station",
			"Underground Complex", "Orbital Platform"
		])
	if enemy_factions.is_empty():
		enemy_factions = _mission_gen_data.get("enemy_factions", [
			"Marauders", "Corporate Security", "Alien Horde", "Rogue AI",
			"Rival Crew", "Government Forces", "Cultists", "Mercenaries",
			"Rebels", "Pirates"
		])

func _load_mission_gen_data() -> void:
	var path := "res://data/mission_generation_data.json"
	if not FileAccess.file_exists(path):
		push_warning("FiveParsecsMissionGenerator: mission_generation_data.json not found")
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("FiveParsecsMissionGenerator: Failed to parse mission_generation_data.json")
		return
	if json.data is Dictionary:
		_mission_gen_data = json.data

func generate_mission(difficulty: int = 2, type: int = -1) -> Dictionary:
	# Emit generation started signal
	emit_signal("generation_started", {"difficulty": difficulty, "type": type})
	
	# Validate required systems
	if not has_method("set_game_state") or not has_method("set_world_manager"):
		# If we don't have the necessary methods, we can't generate a mission
		emit_signal("generation_completed", {"success": false, "error": "Missing required systems"})
		return {}
	
	# Select a random mission type if not specified
	if type < 0:
		type = randi() % FiveParsecsMissionType.size()
	
	# Determine terrain theme from location
	var location_name: String = mission_locations[randi() % mission_locations.size()]
	var terrain_themes: Array = _mission_gen_data.get("terrain_themes", ["urban", "wilderness", "industrial", "space_station", "wasteland"])
	var terrain_theme: String = terrain_themes[randi() % terrain_themes.size()]

	var mission = {
		"id": str(randi()),
		"type": type,
		"difficulty": difficulty,
		"title": generate_mission_title(type),
		"description": generate_mission_description(type, difficulty),
		"reward": calculate_mission_reward(difficulty, type),
		"location": location_name,
		"enemy_faction": enemy_factions[randi() % enemy_factions.size()],
		"enemy_count": calculate_enemy_count(difficulty, type),
		"special_rules": generate_special_rules(type),
		"objectives": generate_objectives(type),
		"loot_table": generate_loot_table(difficulty),
		"terrain": terrain_theme,
		"theme": terrain_theme,
		"completed": false,
		"success": false
	}
	
	# Emit mission generated signal
	emit_signal("mission_generated", mission)
	
	# Emit generation completed signal
	emit_signal("generation_completed", {"success": true})
	
	return mission

func generate_mission_title(type: int) -> String:
	# Safety check - if titles dict is malformed, return a safe default
	if not mission_types or not mission_types.has(type):
		return "Generic Mission"

	# Load titles from JSON (keyed by type int as string)
	var all_titles: Dictionary = _mission_gen_data.get("titles", {})
	var type_key: String = str(type)
	if all_titles.has(type_key) and all_titles[type_key] is Array and all_titles[type_key].size() > 0:
		var title_list: Array = all_titles[type_key]
		return title_list[randi() % title_list.size()]

	return mission_types.get(type, "Five Parsecs Mission")

func generate_mission_description(type: int, difficulty: int) -> String:
	# Load descriptions from JSON
	var diff_descs: Dictionary = _mission_gen_data.get("difficulty_descriptions", {})
	var type_descs: Dictionary = _mission_gen_data.get("type_descriptions", {})

	var difficulty_desc: String = diff_descs.get(str(difficulty), "A standard operation.")
	var type_desc: String = type_descs.get(str(type), "Complete the mission objectives.")

	return type_desc + " " + difficulty_desc

func calculate_mission_reward(difficulty: int, type: int) -> int:
	# Basic reward calculation based on difficulty
	var base_reward = difficulty * 100

	# Adjust based on mission type using JSON multipliers
	var multipliers: Dictionary = _mission_gen_data.get("reward_multipliers", {})
	var type_key: String = str(type)
	if multipliers.has(type_key):
		base_reward = int(base_reward * float(multipliers[type_key]))

	return base_reward

func calculate_enemy_count(difficulty: int, type: int) -> int:
	var base_count = difficulty + 2
	
	# Adjust based on mission type
	match type:
		FiveParsecsMissionType.BATTLE:
			base_count += 2
		FiveParsecsMissionType.RIVAL_ENCOUNTER:
			base_count = 5 # Rival crews are typically 5 members
		FiveParsecsMissionType.DEFENSE:
			base_count += 3 # Defense missions have more enemies
	
	# Add some randomness
	base_count += randi() % 3 - 1
	
	# Ensure minimum of 2 enemies
	return max(2, base_count)

func generate_special_rules(type: int) -> Array:
	var special_rules = []

	# 50% chance to have a special rule
	if randf() < 0.5:
		var possible_rules: Array = _mission_gen_data.get("special_rules", [
			"Limited Visibility", "Hazardous Environment", "Reinforcements",
			"Time Limit", "Restricted Equipment", "Unstable Ground",
			"Extreme Weather", "Radiation Zone", "Automated Defenses", "Civilian Presence"
		]).duplicate()

		# Add 1-2 special rules
		var rule_count = randi() % 2 + 1
		for i in range(rule_count):
			if possible_rules.size() > 0:
				var rule_index = randi() % possible_rules.size()
				special_rules.append(possible_rules[rule_index])
				possible_rules.remove_at(rule_index)

	return special_rules

func generate_objectives(type: int) -> Array:
	var objectives = []

	# Load objectives from JSON by type
	var all_objectives: Dictionary = _mission_gen_data.get("objectives", {})
	var type_key: String = str(type)
	if all_objectives.has(type_key) and all_objectives[type_key] is Array:
		for obj in all_objectives[type_key]:
			objectives.append(obj)
	else:
		objectives.append("Complete the mission objectives")

	# 30% chance to add a bonus objective
	if randf() < 0.3:
		var bonus_list: Array = _mission_gen_data.get("bonus_objectives", [
			"Recover the hidden data cache", "Eliminate the enemy leader",
			"Avoid triggering alarms", "Complete the mission without casualties",
			"Find and secure the secret weapon"
		])
		if bonus_list.size() > 0:
			objectives.append("BONUS: " + bonus_list[randi() % bonus_list.size()])

	return objectives

func generate_loot_table(difficulty: int) -> Array:
	var loot_table = []
	
	# Base number of loot rolls based on difficulty
	var loot_rolls = difficulty + 1
	
	# Generate loot entries
	for i in range(loot_rolls):
		var loot_type = randi() % 5
		var loot_entry = {}
		
		match loot_type:
			0: # Credits
				loot_entry = {
					"type": "credits",
					"amount": (randi() % 5 + 1) * 100
				}
			1: # Item
				loot_entry = {
					"type": "item",
					"rarity": min(randi() % (difficulty + 1), 4) # 0-4 rarity based on difficulty
				}
			2: # Weapon
				loot_entry = {
					"type": "weapon",
					"rarity": min(randi() % (difficulty + 1), 4)
				}
			3: # Armor
				loot_entry = {
					"type": "armor",
					"rarity": min(randi() % (difficulty + 1), 4)
				}
			4: # Resource
				var resources: Array = _mission_gen_data.get("resource_types", ["medical_supplies", "spare_parts", "salvage", "ammunition"])
				loot_entry = {
					"type": "resource",
					"resource": resources[randi() % resources.size()],
					"amount": randi() % 3 + 1
				}
		
		loot_table.append(loot_entry)
	
	return loot_table

func serialize_mission(mission_data: Dictionary) -> Dictionary:
	# Add validation
	if mission_data == null or typeof(mission_data) != TYPE_DICTIONARY:
		push_error("Invalid mission data provided to serialize_mission")
		return {}
		
	# Create serialized copy of mission data
	var data = mission_data.duplicate(true)
	
	# Add any Five Parsecs specific serialization logic here
	
	return data

func deserialize_mission(serialized_data: Dictionary) -> Dictionary:
	# Add validation
	if serialized_data == null or typeof(serialized_data) != TYPE_DICTIONARY:
		push_error("Invalid serialized data provided to deserialize_mission")
		return {}
		
	# Create mission from serialized data
	var mission = serialized_data.duplicate(true)
	
	# Add any Five Parsecs specific deserialization logic here
	
	return mission

# Special method to support usage from Node contexts
# Since this class extends RefCounted (through BaseMissionGenerator)
# we need a way to safely use it in Node contexts without type errors
static func create_node_wrapper() -> Node:
	var wrapper = Node.new()
	wrapper.name = "FiveParsecsMissionGeneratorWrapper"
	
	# Create the actual generator
	var generator = Self.new()
	
	# Attach generator to the wrapper node using meta
	wrapper.set_meta("generator", generator)
	
	# Forward methods to the generator
	wrapper.set_script(load("res://src/game/campaign/FiveParsecsMissionGeneratorWrapper.gd"))
	
	return wrapper

# Method to create a generator instance from saved state
static func create_from_save(save_data: Dictionary) -> Self:
	var generator = Self.new()
	
	# Initialize from saved state if valid data provided
	if save_data != null and typeof(save_data) == TYPE_DICTIONARY:
		# Restore mission types if saved
		if save_data.has("mission_types") and typeof(save_data.mission_types) == TYPE_DICTIONARY:
			generator.mission_types = save_data.mission_types.duplicate()
			
		# Restore mission locations if saved
		if save_data.has("mission_locations") and typeof(save_data.mission_locations) == TYPE_ARRAY:
			generator.mission_locations = save_data.mission_locations.duplicate()
			
		# Restore enemy factions if saved
		if save_data.has("enemy_factions") and typeof(save_data.enemy_factions) == TYPE_ARRAY:
			generator.enemy_factions = save_data.enemy_factions.duplicate()
			
		# Restore other state as needed
		# Add any additional state restoration here
	
	return generator
	
func generate_mission_with_type(type: int) -> Dictionary:
	return generate_mission(2, type)
