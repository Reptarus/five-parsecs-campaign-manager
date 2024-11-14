# ExpandedFactionManager.gd
class_name ExpandedFactionManager
extends Resource

# Use the GlobalEnums.Faction enum
const MIN_FACTION_STRENGTH: int = 2
const MAX_FACTION_STRENGTH: int = 7
const MIN_FACTION_POWER: int = 3
const MAX_FACTION_POWER: int = 5

var game_state_manager: GameStateManager
var factions: Array[Dictionary] = []
var faction_data: Dictionary

func _init(_game_state_manager: GameStateManager = null) -> void:
	game_state_manager = _game_state_manager
	load_faction_data()

func load_faction_data() -> void:
	var file = FileAccess.open("res://data/RulesReference/Factions.json", FileAccess.READ)
	faction_data = JSON.parse_string(file.get_as_text())["factions"]
	file.close()

func generate_factions(num_factions: int) -> void:
	for i in range(num_factions):
		factions.append(generate_faction())
func generate_faction() -> Dictionary:
	var faction_type = GlobalEnums.Faction.values()[randi() % GlobalEnums.Faction.size()]
	
	return {
		"name": generate_faction_name(),
		"type": faction_type,
		"strength": randi_range(MIN_FACTION_STRENGTH, MAX_FACTION_STRENGTH),
		"power": randi_range(MIN_FACTION_POWER, MAX_FACTION_POWER),
		"influence": randi_range(1, 5),
		"loyalty": {},
		"temporary_defense": false
	}

func generate_faction_name() -> String:
	var prefixes: Array[String] = ["New", "United", "Free", "Imperial", "Republic of"]
	var suffixes: Array[String] = ["Corp", "Syndicate", "Alliance", "Federation", "Collective"]
	return prefixes[randi() % prefixes.size()] + " " + suffixes[randi() % suffixes.size()]

func update_faction_relations(faction: Dictionary, change: float) -> void:
	faction["influence"] = clamp(faction["influence"] + change, 1.0, 5.0)

func get_faction_mission(faction: Dictionary) -> Mission:
	return game_state_manager.mission_generator.generate_mission_for_faction(faction)

func resolve_faction_conflict() -> void:
	var attacker = factions[randi() % factions.size()]
	var defender = factions[randi() % factions.size()]
	
	if attacker == defender:
		return
	
	var attacker_roll = randi() % 6 + 1 + attacker["power"]
	var defender_roll = randi() % 6 + 1 + defender["power"]
	
	if defender["temporary_defense"]:
		defender_roll += 2
		defender["temporary_defense"] = false
	
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
	pass

func defensive_posture(faction: Dictionary) -> void:
	if faction["power"] >= 3:
		faction["temporary_defense"] = true

func faction_struggle(faction: Dictionary) -> void:
	if faction["power"] >= 3:
		resolve_faction_conflict()

func office_party(faction: Dictionary) -> void:
	for character in game_state_manager.game_state.get_crew():
		var loyalty = character.get_faction_standing(faction["name"])
		game_state_manager.game_state.credits += loyalty

func plans_within_plans(faction: Dictionary) -> void:
	if faction["influence"] >= 3:
		game_state_manager.game_state.add_quest(
			game_state_manager.quest_generator.generate_quest_for_faction(faction)
		)

func day_to_day_operations(faction: Dictionary) -> void:
	game_state_manager.game_state.add_job_offer(get_faction_mission(faction))

func update_factions() -> void:
	for faction in factions:
		perform_faction_activity(faction)

func get_faction_job(faction: Dictionary) -> bool:
	if randi() % 6 + 1 <= faction["influence"]:
		var job = get_faction_mission(faction)
		game_state_manager.game_state.add_job_offer(job)
		return true
	return false

func gain_faction_loyalty(faction: Dictionary, character: CrewMember) -> void:
	var current_loyalty = character.get_faction_standing(faction["name"])
	if randi() % 6 + 1 > current_loyalty:
		character.set_faction_standing(faction["name"], current_loyalty + 1)

func call_in_faction_favor(faction: Dictionary, character: CrewMember) -> bool:
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
	var manager = ExpandedFactionManager.new(null)  # MockGameState will be set later
	manager.factions = data["factions"]
	return manager

static func deserialize_faction(data: Dictionary) -> Dictionary:
	return data

func get_faction_by_name(faction_name: String) -> Dictionary:
	for faction in factions:
		if faction["name"] == faction_name:
			return faction
	return {}

func get_faction_by_type(faction_type: String) -> Dictionary:
	for faction in factions:
		if faction["type"] == faction_type:
			return faction
	return {}

func get_strongest_faction() -> Dictionary:
	var strongest_faction = factions[0]
	for faction in factions:
		if faction["strength"] > strongest_faction["strength"]:
			strongest_faction = faction
	return strongest_faction

func get_weakest_faction() -> Dictionary:
	var weakest_faction = factions[0]
	for faction in factions:
		if faction["strength"] < weakest_faction["strength"]:
			weakest_faction = faction
	return weakest_faction

func get_most_influential_faction() -> Dictionary:
	var most_influential_faction = factions[0]
	for faction in factions:
		if faction["influence"] > most_influential_faction["influence"]:
			most_influential_faction = faction
	return most_influential_faction

func get_least_influential_faction() -> Dictionary:
	var least_influential_faction = factions[0]
	for faction in factions:
		if faction["influence"] < least_influential_faction["influence"]:
			least_influential_faction = faction
	return least_influential_faction

func get_faction_power_ranking() -> Array[Dictionary]:
	var sorted_factions = factions.duplicate()
	sorted_factions.sort_custom(func(a, b): return a["power"] > b["power"])
	return sorted_factions

func get_faction_influence_ranking() -> Array[Dictionary]:
	var sorted_factions = factions.duplicate()
	sorted_factions.sort_custom(func(a, b): return a["influence"] > b["influence"])
	return sorted_factions

func get_faction_strength_ranking() -> Array[Dictionary]:
	var sorted_factions = factions.duplicate()
	sorted_factions.sort_custom(func(a, b): return a["strength"] > b["strength"])
	return sorted_factions

func get_total_faction_power() -> int:
	var total_power = 0
	for faction in factions:
		total_power += faction["power"]
	return total_power

func get_total_faction_influence() -> int:
	var total_influence = 0
	for faction in factions:
		total_influence += faction["influence"]
	return total_influence

func get_total_faction_strength() -> int:
	var total_strength = 0
	for faction in factions:
		total_strength += faction["strength"]
	return total_strength

func get_average_faction_power() -> float:
	return float(get_total_faction_power()) / factions.size()

func get_average_faction_influence() -> float:
	return float(get_total_faction_influence()) / factions.size()

func get_average_faction_strength() -> float:
	return float(get_total_faction_strength()) / factions.size()

func remove_faction(faction: Dictionary) -> void:
	factions.erase(faction)

func add_faction(faction: Dictionary) -> void:
	factions.append(faction)

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

func update_faction_relations_global_event(event: GlobalEnums.GlobalEvent) -> void:
	match event:
		GlobalEnums.GlobalEvent.MARKET_CRASH:
			for faction in factions:
				faction["influence"] = max(1, faction["influence"] - 1)
		GlobalEnums.GlobalEvent.ALIEN_INVASION:
			for faction in factions:
				faction["strength"] = max(MIN_FACTION_STRENGTH, faction["strength"] - 2)
				faction["influence"] = max(1, faction["influence"] - 1)
		GlobalEnums.GlobalEvent.CORPORATE_WAR:
			if factions.size() >= 2:
				var acquirer = factions[randi() % factions.size()]
				var target = factions[randi() % factions.size()]
				while target == acquirer:
					target = factions[randi() % factions.size()]
				merge_factions(acquirer, target)
		GlobalEnums.GlobalEvent.PIRATE_RAIDS:
			for faction in factions:
				faction["power"] = max(MIN_FACTION_POWER, faction["power"] - 1)
		GlobalEnums.GlobalEvent.PLAGUE_OUTBREAK:
			for faction in factions:
				faction["influence"] = max(1, min(5, faction["influence"] + randi() % 3 - 1))
