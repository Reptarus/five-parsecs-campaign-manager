# ExpandedFactionManager.gd
class_name ExpandedFactionManager
extends Node

enum FactionType {
	CORPORATION,
	LOCAL_GOVERNMENT,
	SECTOR_GOVERNMENT,
	WEALTHY_INDIVIDUAL,
	PRIVATE_ORGANIZATION,
	SECRETIVE_GROUP,
	CRIMINAL_SYNDICATE,
	REBEL_FACTION
}

const MIN_FACTION_STRENGTH: int = 2
const MAX_FACTION_STRENGTH: int = 7
const MIN_FACTION_POWER: int = 3
const MAX_FACTION_POWER: int = 5

var game_state: GameState
var factions: Array[Dictionary] = []

func _init(_game_state: GameState) -> void:
	game_state = _game_state

func generate_factions(num_factions: int) -> void:
	for i in range(num_factions):
		factions.append(generate_faction())

func generate_faction() -> Dictionary:
	var faction_type: FactionType = FactionType.values()[randi() % FactionType.size()]
	
	return {
		"name": generate_faction_name(),
		"type": faction_type,
		"strength": randi_range(MIN_FACTION_STRENGTH, MAX_FACTION_STRENGTH),
		"power": randi_range(MIN_FACTION_POWER, MAX_FACTION_POWER),
		"influence": randi_range(1, 5),
		"loyalty": {}
	}

func generate_faction_name() -> String:
	var prefixes: Array[String] = ["New", "United", "Free", "Imperial", "Republic of"]
	var suffixes: Array[String] = ["Corp", "Syndicate", "Alliance", "Federation", "Collective"]
	return prefixes[randi() % prefixes.size()] + " " + suffixes[randi() % suffixes.size()]

func update_faction_relations(faction: Dictionary, change: float) -> void:
	faction["influence"] = clamp(faction["influence"] + change, 1.0, 5.0)

func get_faction_mission(faction: Dictionary) -> Mission:
	# Generate a mission based on the faction's type and influence
	return game_state.mission_generator.generate_mission_for_faction(faction)

func resolve_faction_conflict() -> void:
	var attacker = factions[randi() % factions.size()]
	var defender = factions[randi() % factions.size()]
	
	if attacker == defender:
		return
	
	var attacker_roll = randi() % 6 + 1 + attacker["power"]
	var defender_roll = randi() % 6 + 1 + defender["power"]
	
	if attacker_roll > defender_roll:
		defender["strength"] = max(1, defender["strength"] - 1)
		attacker["influence"] = min(5, attacker["influence"] + 1)
	elif defender_roll > attacker_roll:
		attacker["strength"] = max(1, attacker["strength"] - 1)
		defender["influence"] = min(5, defender["influence"] + 1)

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
	var target = factions[randi() % factions.size()]
	if target != faction and randi() % 6 + 1 >= 5:
		var stat_to_decrease = "power" if randi() % 2 == 0 else "influence"
		target[stat_to_decrease] = max(1, target[stat_to_decrease] - 1)

func hostile_takeover(faction: Dictionary) -> void:
	if faction["influence"] >= 3:
		var target = factions[randi() % factions.size()]
		if target != faction and randi() % 6 + 1 > target["influence"]:
			target["influence"] = max(1, target["influence"] - 1)
			faction["influence"] = min(5, faction["influence"] + 1)

func public_relations_campaign(faction: Dictionary) -> void:
	if randi() % 6 + 1 > faction["influence"]:
		faction["influence"] = min(5, faction["influence"] + 1)

func capitalize_on_events(faction: Dictionary) -> void:
	var stat_to_increase = "influence" if faction["influence"] <= faction["power"] else "power"
	faction[stat_to_increase] = min(5, faction[stat_to_increase] + 1)

func lay_low(_faction: Dictionary) -> void:
	# No action taken
	pass

func defensive_posture(faction: Dictionary) -> void:
	if faction["power"] >= 3:
		faction["temporary_defense"] = true

func faction_struggle(faction: Dictionary) -> void:
	if faction["power"] >= 3:
		resolve_faction_conflict()

func office_party(faction: Dictionary) -> void:
	for character in game_state.current_crew.members:
		var loyalty = character.get_faction_standing(faction["name"])
		game_state.current_crew.add_credits(loyalty)

func plans_within_plans(faction: Dictionary) -> void:
	if faction["influence"] >= 3:
		game_state.add_quest(game_state.quest_generator.generate_quest_for_faction(faction))

func day_to_day_operations(faction: Dictionary) -> void:
	game_state.add_job_offer(get_faction_mission(faction))

func update_factions() -> void:
	for faction in factions:
		perform_faction_activity(faction)

func get_faction_job(faction: Dictionary) -> bool:
	if randi() % 6 + 1 <= faction["influence"]:
		var job = get_faction_mission(faction)
		game_state.add_job_offer(job)
		return true
	return false

func gain_faction_loyalty(faction: Dictionary, character) -> void:
	var current_loyalty = character.get_faction_standing(faction["name"])
	if randi() % 6 + 1 > current_loyalty:
		character.set_faction_standing(faction["name"], current_loyalty + 1)

func call_in_faction_favor(faction: Dictionary, character) -> bool:
	var current_loyalty = character.get_faction_standing(faction["name"])
	var roll = randi() % 6 + 1
	if roll <= current_loyalty:
		character.set_faction_standing(faction["name"], current_loyalty - roll)
		return true
	return false

func serialize() -> Dictionary:
	return {
		"factions": factions
	}

static func deserialize(data: Dictionary) -> ExpandedFactionManager:
	var manager = ExpandedFactionManager.new(null)  # GameState will be set later
	manager.factions = data["factions"]
	return manager
