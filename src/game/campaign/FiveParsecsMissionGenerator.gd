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
	# Load mission objectives + danger pay from canonical patron_generation.json (Core Rules pp.83-91)
	var gen_path := "res://data/patron_generation.json"
	var gen_file := FileAccess.open(gen_path, FileAccess.READ)
	if gen_file:
		var gen_json := JSON.new()
		if gen_json.parse(gen_file.get_as_text()) == OK and gen_json.data is Dictionary:
			var gen_data: Dictionary = gen_json.data
			if gen_data.has("mission_objectives"):
				_mission_gen_data["core_rules_objectives"] = gen_data["mission_objectives"]
			# Load danger pay table (Core Rules p.83) for reward calculation
			var danger_table: Dictionary = gen_data.get("danger_pay_table", {})
			if danger_table.has("entries"):
				_mission_gen_data["danger_pay_entries"] = danger_table["entries"]
		gen_file.close()

	# Load supplementary data from mission_generation_data.json (locations, terrain, etc.)
	var path := "res://data/mission_generation_data.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("FiveParsecsMissionGenerator: Failed to parse mission_generation_data.json")
		return
	if json.data is Dictionary:
		# Merge supplementary data without overwriting core rules objectives
		var supp: Dictionary = json.data
		for key in supp:
			if not _mission_gen_data.has(key):
				_mission_gen_data[key] = supp[key]

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
	# Core Rules p.120: Mission pay = D6 credits base
	var base_reward: int = randi_range(1, 6)

	# Core Rules p.83: Danger pay from D10 table (loaded from patron_generation.json)
	var danger_pay: int = 0
	var core_objs: Dictionary = _mission_gen_data.get("core_rules_objectives", {})
	# Danger pay table is loaded alongside patron data
	var danger_table: Array = _mission_gen_data.get("danger_pay_entries", [])
	if danger_table.size() > 0:
		var danger_roll: int = randi_range(1, 10)
		for entry in danger_table:
			var r: Array = entry.get("roll_range", [0, 0])
			if danger_roll >= r[0] and danger_roll <= r[1]:
				danger_pay = entry.get("danger_pay", 1)
				# 10+: roll twice for base pay, pick higher
				if entry.get("bonus_pay_rule", "") == "roll_twice_pick_higher":
					var second_roll: int = randi_range(1, 6)
					base_reward = maxi(base_reward, second_roll)
				break
	else:
		# Fallback: flat +1 danger pay if JSON unavailable
		danger_pay = 1

	# Higher difficulty missions add +1 danger pay (app-specific scaling)
	if difficulty >= 4:
		danger_pay += 1

	return base_reward + danger_pay

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
	var objectives: Array = []

	# Use Core Rules D10 objective tables from patron_generation.json (pp.89-91)
	var core_objs: Dictionary = _mission_gen_data.get("core_rules_objectives", {})
	if not core_objs.is_empty():
		# Select table based on mission type
		var table_key: String = "opportunity_objectives"
		if type == FiveParsecsMissionType.PATRON_JOB:
			table_key = "patron_objectives"
		elif type == FiveParsecsMissionType.STORY_MISSION:
			table_key = "quest_objectives"

		var table: Dictionary = core_objs.get(table_key, {})
		var entries: Array = table.get("entries", [])
		if entries.size() > 0:
			# Roll D10 on the appropriate table
			var roll: int = randi_range(1, 10)
			for entry in entries:
				var r: Array = entry.get("roll_range", [0, 0])
				if roll >= r[0] and roll <= r[1]:
					var obj_name: String = entry.get("objective", "Fight Off")
					# Look up full description
					var descs: Dictionary = core_objs.get("objective_descriptions", {})
					var desc: Dictionary = descs.get(obj_name, {})
					var full_desc: String = desc.get("description", obj_name)
					objectives.append(obj_name + ": " + full_desc)
					break

	# Fallback to legacy data if Core Rules tables unavailable
	if objectives.is_empty():
		var all_objectives: Dictionary = _mission_gen_data.get("objectives", {})
		var type_key: String = str(type)
		if all_objectives.has(type_key) and all_objectives[type_key] is Array:
			for obj in all_objectives[type_key]:
				objectives.append(obj)
		else:
			objectives.append("Complete the mission objectives")

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
			0: # Credits (Core Rules single-digit economy)
				loot_entry = {
					"type": "credits",
					"amount": randi_range(1, 3)
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
