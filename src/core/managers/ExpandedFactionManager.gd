# ExpandedFactionManager.gd
@tool
# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Node

const Self = preload("res://src/core/managers/ExpandedFactionManager.gd")
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const MissionClass = preload("res://src/core/systems/Mission.gd")
# Using a temporary character reference until Character is properly implemented

# Constants
const MIN_FACTION_STRENGTH: int = 1
const MAX_FACTION_STRENGTH: int = 10
const MIN_FACTION_INFLUENCE: int = 1
const MAX_FACTION_INFLUENCE: int = 5
const MIN_FACTION_POWER: int = 3
const MAX_FACTION_POWER: int = 5
const MAX_TECH_LEVEL: int = 5
const MIN_TECH_LEVEL: int = 1
const FACTION_TYPE_COUNT: int = 19 # Number of faction types in the enum
const REPUTATION_MIN = -100
const REPUTATION_MAX = 100
const REPUTATION_NEUTRAL = 0
const REPUTATION_FRIENDLY = 50
const REPUTATION_ALLIED = 80
const REPUTATION_HOSTILE = -50
const REPUTATION_ENEMY = -80

# State
@export var game_state_manager: Node # Will be cast to GameStateManager
var factions: Dictionary = {
	"government": [],
	"criminal": [],
	"corporate": [],
	"religious": [],
	"rebel": [],
	"alien": []
}
var faction_data: Dictionary = {}
var _factions: Dictionary = {}
var _faction_relationships: Dictionary = {}
var _faction_territories: Dictionary = {}
var player_faction_id: String = ""
var game_state: FiveParsecsGameState

# Add missing signals
signal faction_created(faction_id: String)
signal faction_reputation_changed(faction_id: String, old_value: int, new_value: int)
signal faction_territory_changed(faction_id: String, planet_id: String, controlling: bool)
signal faction_war_declared(faction_id: String, target_faction_id: String)
signal faction_alliance_formed(faction_id: String, ally_faction_id: String)
signal faction_mission_available(faction_id: String, mission_data: Resource)

func _init(_game_state_manager: Node = null) -> void:
	game_state_manager = _game_state_manager
	load_faction_data()

func _ready() -> void:
	# Connect to autoloads if we're not in the editor
	if not Engine.is_editor_hint():
		await get_tree().process_frame
		_connect_signals()

func _connect_signals() -> void:
	# Find autoloaded dependencies
	if not game_state:
		var state = get_node_or_null("/root/GameState")
		if state:
			game_state = state

func load_faction_data() -> void:
	var file := FileAccess.open("res://data/RulesReference/Factions.json", FileAccess.READ)
	faction_data = JSON.parse_string(file.get_as_text())["factions"]
	file.close()

func generate_factions(num_factions: int) -> void:
	for i in range(num_factions):
		factions["government"].append(generate_faction())

func generate_faction() -> Dictionary:
	var faction_type: int = randi() % FACTION_TYPE_COUNT
	
	return {
		"name": generate_faction_name(),
		"type": faction_type,
		"strength": randi_range(MIN_FACTION_STRENGTH, MAX_FACTION_STRENGTH),
		"power": randi_range(MIN_FACTION_POWER, MAX_FACTION_POWER),
		"influence": randi_range(MIN_FACTION_INFLUENCE, MAX_FACTION_INFLUENCE),
		"tech_level": randi_range(MIN_TECH_LEVEL, MAX_TECH_LEVEL),
		"loyalty": {},
		"temporary_defense": false
	}

func generate_faction_name() -> String:
	var prefixes: Array[String] = ["New", "United", "Free", "Imperial", "Republic of"]
	var suffixes: Array[String] = ["Corp", "Syndicate", "Alliance", "Federation", "Collective"]
	return prefixes[randi() % prefixes.size()] + " " + suffixes[randi() % suffixes.size()]

func update_faction_relations(faction: Dictionary, change: float) -> void:
	faction["influence"] = clamp(faction["influence"] + change, MIN_FACTION_INFLUENCE, MAX_FACTION_INFLUENCE)

func get_faction_mission(faction: Dictionary) -> Resource:
	if not game_state_manager:
		return null
	return game_state_manager.mission_generator.generate_mission_for_faction(faction)

func resolve_faction_conflict() -> void:
	var attacker = factions["government"][randi() % factions["government"].size()]
	var defender = factions["government"][randi() % factions["government"].size()]
	
	if attacker == defender:
		return
	
	var attacker_roll = randi() % 6 + 1 + attacker["power"]
	var defender_roll = randi() % 6 + 1 + defender["power"]
	
	if defender["temporary_defense"]:
		defender_roll += 2
		defender["temporary_defense"] = false
	
	if attacker_roll > defender_roll:
		defender["strength"] = max(1, defender["strength"] - 1)
		attacker["influence"] = min(MAX_FACTION_INFLUENCE, attacker["influence"] + 1)
	elif defender_roll > attacker_roll:
		attacker["strength"] = max(1, attacker["strength"] - 1)
		defender["influence"] = min(MAX_FACTION_INFLUENCE, defender["influence"] + 1)

func perform_faction_activity(faction: Dictionary) -> void:
	var activity_roll = randi() % 100 + 1
	
	match activity_roll:
		1, 2, 3, 4, 5, 6, 7, 8, 9, 10:
			consolidate_power(faction)
		11, 12, 13, 14, 15:
			undermine_faction(faction)
		16, 17, 18, 19, 20:
			hostile_takeover(faction)
		21, 22, 23, 24, 25, 26, 27, 28, 29, 30:
			public_relations_campaign(faction)
		31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45:
			capitalize_on_events(faction)
		46, 47, 48, 49, 50, 51, 52, 53, 54, 55:
			lay_low(faction)
		56, 57, 58, 59, 60:
			defensive_posture(faction)
		61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75:
			faction_struggle(faction)
		76, 77, 78, 79, 80:
			office_party(faction)
		81, 82, 83, 84, 85, 86, 87, 88, 89, 90:
			plans_within_plans(faction)
		_:
			day_to_day_operations(faction)

func consolidate_power(faction: Dictionary) -> void:
	if randi() % 6 + 1 > faction["power"]:
		faction["power"] = min(MAX_FACTION_POWER, faction["power"] + 1)

func undermine_faction(faction: Dictionary) -> void:
	var target = factions["government"][randi() % factions["government"].size()]
	if target != faction and randi() % 6 + 1 >= 5:
		var stat_to_decrease = "power" if randi() % 2 == 0 else "influence"
		target[stat_to_decrease] = max(1, target[stat_to_decrease] - 1)

func hostile_takeover(faction: Dictionary) -> void:
	if faction["influence"] >= 3:
		var target = factions["government"][randi() % factions["government"].size()]
		if target != faction and randi() % 6 + 1 > target["influence"]:
			target["influence"] = max(MIN_FACTION_INFLUENCE, target["influence"] - 1)
			faction["influence"] = min(MAX_FACTION_INFLUENCE, faction["influence"] + 1)

func public_relations_campaign(faction: Dictionary) -> void:
	if randi() % 6 + 1 > faction["influence"]:
		faction["influence"] = min(MAX_FACTION_INFLUENCE, faction["influence"] + 1)

func capitalize_on_events(faction: Dictionary) -> void:
	var stat_to_increase = "influence" if faction["influence"] <= faction["power"] else "power"
	faction[stat_to_increase] = min(MAX_FACTION_POWER, faction[stat_to_increase] + 1)

func lay_low(_faction: Dictionary) -> void:
	pass

func defensive_posture(faction: Dictionary) -> void:
	if faction["power"] >= 3:
		faction["temporary_defense"] = true

func faction_struggle(faction: Dictionary) -> void:
	if faction["power"] >= 3:
		resolve_faction_conflict()

func office_party(faction: Dictionary) -> void:
	if not game_state_manager or not game_state_manager.has_method("get_game_state"):
		return
		
	var game_state = game_state_manager.get_game_state()
	if not game_state:
		return
		
	var crew = game_state.get_crew()
	if not crew:
		return
		
	for character in crew:
		if character and character.has_method("get_faction_standing"):
			var loyalty = character.get_faction_standing(faction["name"])
			if loyalty > 0:
				game_state.add_credits(loyalty)

func plans_within_plans(faction: Dictionary) -> void:
	if not game_state_manager or not game_state_manager.has_method("get_game_state"):
		return
		
	var game_state = game_state_manager.get_game_state()
	if not game_state:
		return
		
	if faction["influence"] >= 3:
		var quest_generator = game_state_manager.get_quest_generator()
		if quest_generator and quest_generator.has_method("generate_quest_for_faction"):
			var quest = quest_generator.generate_quest_for_faction(faction)
			if quest:
				game_state.add_quest(quest)

func day_to_day_operations(faction: Dictionary) -> void:
	if not game_state_manager or not game_state_manager.has_method("get_game_state"):
		return
		
	var game_state = game_state_manager.get_game_state()
	if not game_state:
		return
		
	var job = get_faction_mission(faction)
	if job:
		game_state.add_job_offer(job)

func update_factions() -> void:
	for faction in factions["government"]:
		perform_faction_activity(faction)

func get_faction_job(faction: Dictionary) -> bool:
	if not game_state_manager or not game_state_manager.game_state:
		return false
		
	if randi() % 6 + 1 <= faction.get("influence", 0):
		var job_resource: Resource = get_faction_mission(faction)
		if job_resource:
			game_state_manager.game_state.add_job_offer(job_resource)
			return true
	return false

func gain_faction_loyalty(faction: Dictionary, character: Node) -> void:
	if character.has_method("get_faction_standing"):
		var current_loyalty = character.get_faction_standing(faction["name"])
		if randi() % 6 + 1 > current_loyalty:
			character.set_faction_standing(faction["name"], current_loyalty + 1)

func call_in_faction_favor(faction: Dictionary, character: Node) -> bool:
	if character.has_method("get_faction_standing"):
		var current_loyalty = character.get_faction_standing(faction["name"])
		var roll = randi() % 6 + 1
		if roll <= current_loyalty:
			# Character successfully called in a favor
			character.set_faction_standing(faction["name"], current_loyalty - 1)
			return true
	return false

func serialize() -> Dictionary:
	return {
		"factions": _factions.duplicate(true),
		"faction_relationships": _faction_relationships.duplicate(true),
		"faction_territories": _faction_territories.duplicate(true),
		"player_faction_id": player_faction_id
	}

static func deserialize(data: Dictionary) -> Node:
	var manager = Self.new(null) # MockGameState will be set later
	manager._factions = data["factions"]
	manager._faction_relationships = data["faction_relationships"]
	manager._faction_territories = data["faction_territories"]
	manager.player_faction_id = data["player_faction_id"]
	return manager

static func deserialize_faction(data: Dictionary) -> Dictionary:
	return data

func get_faction_by_name(faction_name: String) -> Dictionary:
	for faction_type in factions.keys():
		for faction in factions[faction_type]:
			if faction["name"] == faction_name:
				return faction
	return {}

func get_faction_by_type(type_value: int) -> Dictionary:
	for faction in factions:
		if faction.get("type", -1) == type_value:
			return faction
	return {}

func get_strongest_faction() -> Dictionary:
	if factions.is_empty():
		return {}
		
	var strongest_faction: Dictionary = {}
	var found_any = false
	
	for faction_type in factions.keys():
		for faction in factions[faction_type]:
			if not found_any or faction.get("strength", 0) > strongest_faction.get("strength", 0):
				strongest_faction = faction
				found_any = true
	
	return strongest_faction

func get_weakest_faction() -> Dictionary:
	if factions.is_empty():
		return {}
		
	var weakest_faction: Dictionary = {}
	var found_any = false
	
	for faction_type in factions.keys():
		for faction in factions[faction_type]:
			if not found_any or faction.get("strength", 0) < weakest_faction.get("strength", 0):
				weakest_faction = faction
				found_any = true
	
	return weakest_faction

func get_most_influential_faction() -> Dictionary:
	if factions.is_empty():
		return {}
		
	var most_influential_faction: Dictionary = {}
	var found_any = false
	
	for faction_type in factions.keys():
		for faction in factions[faction_type]:
			if not found_any or faction.get("influence", 0) > most_influential_faction.get("influence", 0):
				most_influential_faction = faction
				found_any = true
	
	return most_influential_faction

func get_least_influential_faction() -> Dictionary:
	if factions.is_empty():
		return {}
		
	var least_influential_faction: Dictionary = {}
	var found_any = false
	
	for faction_type in factions.keys():
		for faction in factions[faction_type]:
			if not found_any or faction.get("influence", 0) < least_influential_faction.get("influence", 0):
				least_influential_faction = faction
				found_any = true
	
	return least_influential_faction

func get_faction_power_ranking() -> Array[Dictionary]:
	var sorted_factions: Array[Dictionary] = []
	
	# Collect all factions from all types
	for faction_type in factions.keys():
		for faction in factions[faction_type]:
			sorted_factions.append(faction)
	
	# Sort by power
	sorted_factions.sort_custom(func(a, b): return a["power"] > b["power"])
	return sorted_factions

func get_faction_influence_ranking() -> Array[Dictionary]:
	var sorted_factions: Array[Dictionary] = []
	
	# Collect all factions from all types
	for faction_type in factions.keys():
		for faction in factions[faction_type]:
			sorted_factions.append(faction)
	
	# Sort by influence
	sorted_factions.sort_custom(func(a, b): return a["influence"] > b["influence"])
	return sorted_factions

func get_faction_strength_ranking() -> Array[Dictionary]:
	var sorted_factions: Array[Dictionary] = []
	
	# Collect all factions from all types
	for faction_type in factions.keys():
		for faction in factions[faction_type]:
			sorted_factions.append(faction)
	
	# Sort by strength
	sorted_factions.sort_custom(func(a, b): return a["strength"] > b["strength"])
	return sorted_factions

func get_total_faction_power() -> int:
	var total_power = 0
	for faction_type in factions.keys():
		for faction in factions[faction_type]:
			total_power += faction["power"]
	return total_power

func get_total_faction_influence() -> int:
	var total_influence = 0
	for faction_type in factions.keys():
		for faction in factions[faction_type]:
			total_influence += faction["influence"]
	return total_influence

func get_total_faction_strength() -> int:
	var total_strength = 0
	for faction_type in factions.keys():
		for faction in factions[faction_type]:
			total_strength += faction["strength"]
	return total_strength

func get_average_faction_power() -> float:
	var total_factions = get_total_faction_count()
	if total_factions == 0:
		return 0.0
	return float(get_total_faction_power()) / total_factions

func get_average_faction_influence() -> float:
	var total_factions = get_total_faction_count()
	if total_factions == 0:
		return 0.0
	return float(get_total_faction_influence()) / total_factions

func get_average_faction_strength() -> float:
	var total_factions = get_total_faction_count()
	if total_factions == 0:
		return 0.0
	return float(get_total_faction_strength()) / total_factions

func get_total_faction_count() -> int:
	var count = 0
	for faction_type in factions.keys():
		count += factions[faction_type].size()
	return count

func remove_faction(faction: Dictionary) -> void:
	for faction_type in factions.keys():
		var index = factions[faction_type].find(faction)
		if index != -1:
			factions[faction_type].remove_at(index)
			return

func add_faction(faction: Dictionary) -> void:
	var faction_type = "government" # Default type
	
	# Determine faction type from the faction data
	if faction.has("type"):
		match faction["type"]:
			0: faction_type = "government"
			1: faction_type = "criminal"
			2: faction_type = "corporate"
			3: faction_type = "religious"
			4: faction_type = "rebel"
			5: faction_type = "alien"
	
	# Add to the appropriate array in the dictionary
	if factions.has(faction_type):
		factions[faction_type].append(faction)
	else:
		push_warning("Unknown faction type: " + str(faction_type))

func merge_factions(faction1: Dictionary, faction2: Dictionary) -> Dictionary:
	var merged_faction = generate_faction()
	merged_faction["name"] = faction1["name"] + "-" + faction2["name"]
	merged_faction["strength"] = min(MAX_FACTION_STRENGTH, faction1["strength"] + faction2["strength"])
	merged_faction["power"] = min(MAX_FACTION_POWER, faction1["power"] + faction2["power"])
	merged_faction["influence"] = min(5, max(faction1["influence"], faction2["influence"]) + 1)
	remove_faction(faction1)
	remove_faction(faction2)
	add_faction(merged_faction)
	return merged_faction

func split_faction(faction: Dictionary) -> Array[Dictionary]:
	var faction1 = generate_faction()
	var faction2 = generate_faction()
	faction1["strength"] = max(MIN_FACTION_STRENGTH, faction["strength"] / 2)
	faction2["strength"] = max(MIN_FACTION_STRENGTH, faction["strength"] - faction1["strength"])
	faction1["power"] = max(MIN_FACTION_POWER, faction["power"] / 2)
	faction2["power"] = max(MIN_FACTION_POWER, faction["power"] - faction1["power"])
	faction1["influence"] = max(1, faction["influence"] / 2)
	faction2["influence"] = max(1, faction["influence"] - faction1["influence"])
	remove_faction(faction)
	add_faction(faction1)
	add_faction(faction2)
	return [faction1, faction2]

func process_global_event(event_type: GameEnums.GlobalEvent, affected_factions: Array[Dictionary]) -> void:
	match event_type:
		GameEnums.GlobalEvent.TECH_BREAKTHROUGH:
			for faction in affected_factions:
				faction["tech_level"] = min(MAX_TECH_LEVEL, faction["tech_level"] + 1)
		GameEnums.GlobalEvent.RESOURCE_CONFLICT:
			for faction in affected_factions:
				faction["tech_level"] = max(MIN_TECH_LEVEL, faction["tech_level"] - 1)
		_:
			push_warning("Unhandled global event type: %s" % GameEnums.GlobalEvent.keys()[event_type])

func create_faction(faction_data: Dictionary) -> bool:
	if not _validate_faction_data(faction_data):
		push_error("Invalid faction data")
		return false
		
	var faction_id = faction_data.id
	
	if _factions.has(faction_id):
		push_error("Faction already exists: %s" % faction_id)
		return false
		
	# Add faction to dictionary
	_factions[faction_id] = faction_data.duplicate(true)
	
	# Initialize relationships dictionary
	_faction_relationships[faction_id] = {}
	
	# Initialize territories
	_faction_territories[faction_id] = []
	
	# Assign initial territories if specified
	if faction_data.has("territories") and faction_data.territories is Array:
		for territory in faction_data.territories:
			_faction_territories[faction_id].append(territory)
			
	# Emit signal
	faction_created.emit(faction_id)
	
	return true

func _validate_faction_data(faction_data: Dictionary) -> bool:
	# Required fields
	var required_fields = ["id", "name", "description"]
	
	for field in required_fields:
		if not faction_data.has(field):
			push_error("Faction missing required field: %s" % field)
			return false
			
	return true

func get_faction(faction_id: String) -> Dictionary:
	if not _factions.has(faction_id):
		return {}
		
	return _factions[faction_id].duplicate(true)

func get_all_factions() -> Array:
	var factions = []
	
	for faction_id in _factions.keys():
		factions.append(_factions[faction_id].duplicate(true))
		
	return factions

func set_player_faction(faction_id: String) -> bool:
	if not _factions.has(faction_id):
		push_error("Faction does not exist: %s" % faction_id)
		return false
		
	player_faction_id = faction_id
	return true

func get_player_faction() -> Dictionary:
	if player_faction_id.is_empty() or not _factions.has(player_faction_id):
		return {}
		
	return _factions[player_faction_id].duplicate(true)

func get_reputation(faction_id: String) -> int:
	if player_faction_id.is_empty() or not _factions.has(faction_id):
		return REPUTATION_NEUTRAL
		
	return _get_relationship(player_faction_id, faction_id)

func change_reputation(faction_id: String, amount: int) -> bool:
	if player_faction_id.is_empty() or not _factions.has(faction_id):
		push_error("Invalid faction ID or player faction not set")
		return false
		
	var old_value = get_reputation(faction_id)
	var new_value = clamp(old_value + amount, REPUTATION_MIN, REPUTATION_MAX)
	
	_set_relationship(player_faction_id, faction_id, new_value)
	
	faction_reputation_changed.emit(faction_id, old_value, new_value)
	
	return true

func _get_relationship(faction_a: String, faction_b: String) -> int:
	# Self-relationship is always maximum
	if faction_a == faction_b:
		return REPUTATION_MAX
		
	# Check if both factions exist
	if not _faction_relationships.has(faction_a) or not _faction_relationships.has(faction_b):
		return REPUTATION_NEUTRAL
		
	# Get relationship value
	if _faction_relationships[faction_a].has(faction_b):
		return _faction_relationships[faction_a][faction_b]
		
	# Default to neutral
	return REPUTATION_NEUTRAL

func _set_relationship(faction_a: String, faction_b: String, value: int) -> void:
	# Check if both factions exist
	if not _faction_relationships.has(faction_a) or not _faction_relationships.has(faction_b):
		return
		
	# Set bidirectional relationship
	_faction_relationships[faction_a][faction_b] = value
	_faction_relationships[faction_b][faction_a] = value

func declare_war(aggressor_id: String, target_id: String) -> bool:
	if not _factions.has(aggressor_id) or not _factions.has(target_id):
		push_error("Invalid faction ID")
		return false
		
	_set_relationship(aggressor_id, target_id, REPUTATION_ENEMY)
	
	faction_war_declared.emit(aggressor_id, target_id)
	
	return true

func form_alliance(faction_a: String, faction_b: String) -> bool:
	if not _factions.has(faction_a) or not _factions.has(faction_b):
		push_error("Invalid faction ID")
		return false
		
	_set_relationship(faction_a, faction_b, REPUTATION_ALLIED)
	
	faction_alliance_formed.emit(faction_a, faction_b)
	
	return true

func add_territory(faction_id: String, planet_id: String) -> bool:
	if not _factions.has(faction_id):
		push_error("Invalid faction ID")
		return false
		
	if not _faction_territories.has(faction_id):
		_faction_territories[faction_id] = []
		
	if planet_id in _faction_territories[faction_id]:
		return false
		
	# Check if another faction controls this planet
	for f_id in _faction_territories.keys():
		if f_id != faction_id and planet_id in _faction_territories[f_id]:
			_faction_territories[f_id].erase(planet_id)
			faction_territory_changed.emit(f_id, planet_id, false)
			
	_faction_territories[faction_id].append(planet_id)
	
	faction_territory_changed.emit(faction_id, planet_id, true)
	
	return true

func remove_territory(faction_id: String, planet_id: String) -> bool:
	if not _factions.has(faction_id) or not _faction_territories.has(faction_id):
		push_error("Invalid faction ID")
		return false
		
	if not planet_id in _faction_territories[faction_id]:
		return false
		
	_faction_territories[faction_id].erase(planet_id)
	
	faction_territory_changed.emit(faction_id, planet_id, false)
	
	return true

func get_territories(faction_id: String) -> Array:
	if not _factions.has(faction_id) or not _faction_territories.has(faction_id):
		return []
		
	return _faction_territories[faction_id].duplicate()

func generate_faction_mission(faction_id: String) -> Resource:
	if not _factions.has(faction_id):
		push_error("Invalid faction ID")
		return null
		
	# Create a new mission
	var mission = MissionClass.new()
	
	# Set mission properties
	mission.mission_id = "faction_mission_%s_%d" % [faction_id, Time.get_unix_time_from_system()]
	mission.mission_title = _generate_faction_mission_title(faction_id)
	mission.mission_description = _generate_faction_mission_description(faction_id)
	# Use a numeric value instead of the enum if it's not defined
	mission.mission_type = 3 # Faction mission type
	mission.mission_difficulty = _calculate_faction_mission_difficulty(faction_id)
	mission.reward_credits = _calculate_faction_mission_reward(faction_id)
	
	if game_state:
		mission.turn_offered = game_state.turn_number
	
	# Emit signal
	faction_mission_available.emit(faction_id, mission)
	
	return mission

func _generate_faction_mission_title(faction_id: String) -> String:
	var faction = _factions[faction_id]
	var faction_name = faction.name
	
	var title_templates = [
		"%s Contract",
		"%s Operation",
		"Mission for %s",
		"%s Assignment",
		"Work with %s"
	]
	
	var template = title_templates[randi() % title_templates.size()]
	return template % faction_name

func _generate_faction_mission_description(faction_id: String) -> String:
	var faction = _factions[faction_id]
	var faction_name = faction.name
	
	var description_templates = [
		"The %s faction has requested your assistance with an operation. Complete this mission to improve your standing with them.",
		"Representatives from %s have a job offer for your crew. The payment is good and they will remember your help.",
		"An opportunity to work with %s has arisen. This could be a chance to strengthen your relationship with this faction.",
		"The %s faction needs skilled operatives for a delicate matter. Your crew's reputation has caught their attention."
	]
	
	var template = description_templates[randi() % description_templates.size()]
	return template % faction_name

func _calculate_faction_mission_difficulty(faction_id: String) -> int:
	var reputation = get_reputation(faction_id)
	
	# Higher reputation = higher trust = more difficult (and rewarding) missions
	if reputation >= REPUTATION_ALLIED:
		return 2 # HARD difficulty level
	elif reputation >= REPUTATION_FRIENDLY:
		return 1 # MEDIUM difficulty level
	else:
		return 0 # EASY difficulty level

func _calculate_faction_mission_reward(faction_id: String) -> int:
	var reputation = get_reputation(faction_id)
	var base_reward = 100
	
	# Higher reputation = better rewards
	if reputation >= REPUTATION_ALLIED:
		return base_reward * 3
	elif reputation >= REPUTATION_FRIENDLY:
		return base_reward * 2
	else:
		return base_reward
