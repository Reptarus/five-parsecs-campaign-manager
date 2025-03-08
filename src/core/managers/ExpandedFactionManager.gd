# ExpandedFactionManager.gd
@tool
# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Node

const Self = preload("res://src/core/managers/ExpandedFactionManager.gd")
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
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

func _init(_game_state_manager: Node = null) -> void:
	game_state_manager = _game_state_manager
	load_faction_data()

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

func get_faction_mission(faction: Dictionary) -> Mission:
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
		var job := get_faction_mission(faction)
		if job:
			game_state_manager.game_state.add_job_offer(job)
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
		"factions": factions
	}

static func deserialize(data: Dictionary) -> Node:
	var manager = Self.new(null) # MockGameState will be set later
	manager.factions = data["factions"]
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
