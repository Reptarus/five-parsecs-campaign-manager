class_name BugHuntCharacterGeneration
extends RefCounted

## Generates Bug Hunt main characters and grunts from D100 tables.
## Loads data from data/bug_hunt/bug_hunt_character_creation.json and
## data/bug_hunt/bug_hunt_regiment_names.json.

const DATA_PATH := "res://data/bug_hunt/bug_hunt_character_creation.json"
const REGIMENT_PATH := "res://data/bug_hunt/bug_hunt_regiment_names.json"

var _creation_data: Dictionary = {}
var _regiment_data: Dictionary = {}
var _loaded: bool = false


func _init() -> void:
	_load_data()


func _load_data() -> void:
	_creation_data = _load_json(DATA_PATH)
	_regiment_data = _load_json(REGIMENT_PATH)
	_loaded = not _creation_data.is_empty() and not _regiment_data.is_empty()


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("BugHuntCharacterGeneration: File not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("BugHuntCharacterGeneration: JSON parse error in %s" % path)
		return {}
	return json.data if json.data is Dictionary else {}


## ============================================================================
## MAIN CHARACTER GENERATION
## ============================================================================

func generate_main_character(character_name: String = "") -> Dictionary:
	## Generate a single Bug Hunt main character using D100 tables.
	## Returns a Dictionary compatible with Character.to_dictionary() format.
	if not _loaded:
		push_warning("BugHuntCharacterGeneration: Data not loaded")
		return {}

	var base: Dictionary = _creation_data.get("base_stats", {})
	var stats := {
		"reactions": base.get("reactions", 1),
		"speed": base.get("speed", 4),
		"combat_skill": base.get("combat_skill", 0),
		"toughness": base.get("toughness", 3),
		"savvy": base.get("savvy", 0),
		"luck": 0  # Bug Hunt does not use Luck
	}

	var xp: int = 0
	var completed_missions: int = 0
	var reputation_bonus: int = 0
	var commendation_xp: int = 0
	var commendation_rep: int = 0

	# Roll Origin (D100)
	var origin_roll := _roll_d100()
	var origin: Dictionary = _find_in_table(_creation_data.get("origin_table", []), origin_roll)
	if not origin.is_empty():
		_apply_stat_bonuses(stats, origin.get("stat_bonuses", {}))
		var adv: Dictionary = origin.get("advantages", {})
		xp += adv.get("xp", 0)
		completed_missions += adv.get("completed_missions", 0)
		reputation_bonus += adv.get("reputation", 0)

	# Roll Basic Training (D100)
	var training_roll := _roll_d100()
	var training: Dictionary = _find_in_table(_creation_data.get("basic_training_table", []), training_roll)
	if not training.is_empty():
		_apply_stat_bonuses(stats, training.get("stat_bonuses", {}))
		var adv: Dictionary = training.get("advantages", {})
		xp += adv.get("xp", 0)
		completed_missions += adv.get("completed_missions", 0)
		reputation_bonus += adv.get("reputation", 0)

	# Roll Service History (D100)
	var service_roll := _roll_d100()
	var service: Dictionary = _find_in_table(_creation_data.get("service_history_table", []), service_roll)
	if not service.is_empty():
		_apply_stat_bonuses(stats, service.get("stat_bonuses", {}))
		var adv: Dictionary = service.get("advantages", {})
		xp += adv.get("xp", 0)
		completed_missions += adv.get("completed_missions", 0)
		reputation_bonus += adv.get("reputation", 0)

		# Combat Operation commendation check
		if service.get("is_combat_operation", false):
			var commendation := _check_commendation()
			commendation_xp = commendation.get("xp", 0)
			commendation_rep = commendation.get("reputation", 0)
			xp += commendation_xp
			reputation_bonus += commendation_rep

	var char_id := "bh_mc_" + str(randi())
	if character_name.is_empty():
		character_name = "Trooper " + str(randi() % 9000 + 1000)

	return {
		"id": char_id,
		"character_id": char_id,
		"name": character_name,
		"character_name": character_name,
		"game_mode": "bug_hunt",
		"is_grunt": false,
		"reactions": stats.reactions,
		"speed": stats.speed,
		"combat_skill": stats.combat_skill,
		"toughness": stats.toughness,
		"savvy": stats.savvy,
		"luck": 0,
		"xp": xp,
		"completed_missions_count": completed_missions,
		"reputation_contribution": reputation_bonus,
		"origin": origin.get("name", "Unknown"),
		"origin_roll": origin_roll,
		"basic_training": training.get("name", "Unknown"),
		"training_roll": training_roll,
		"service_history": service.get("name", "Unknown"),
		"service_roll": service_roll,
		"commendation_xp": commendation_xp,
		"commendation_rep": commendation_rep,
		"equipment": ["service_pistol", "trooper_armor"],
		"status": "active"
	}


func generate_squad(names: Array = []) -> Dictionary:
	## Generate a full Bug Hunt squad (3-4 main characters).
	## Returns {main_characters: Array, total_reputation: int}
	var count := 4 if names.size() >= 4 else maxi(names.size(), 3)
	var characters: Array = []
	var total_reputation: int = 0

	for i in range(count):
		var char_name: String = names[i] if i < names.size() else ""
		var mc := generate_main_character(char_name)
		total_reputation += mc.get("reputation_contribution", 0)
		characters.append(mc)

	return {
		"main_characters": characters,
		"total_reputation": total_reputation
	}


## ============================================================================
## GRUNT GENERATION
## ============================================================================

func generate_grunt(grunt_name: String = "") -> Dictionary:
	## Generate a standard grunt (fixed stats, no D100 rolls).
	var grunt_stats: Dictionary = _creation_data.get("grunt_stats", {})
	var grunt_id := "bh_grunt_" + str(randi())
	if grunt_name.is_empty():
		grunt_name = "Grunt " + str(randi() % 9000 + 1000)

	return {
		"id": grunt_id,
		"character_id": grunt_id,
		"name": grunt_name,
		"character_name": grunt_name,
		"game_mode": "bug_hunt",
		"is_grunt": true,
		"reactions": grunt_stats.get("reactions", 1),
		"speed": grunt_stats.get("speed", 4),
		"combat_skill": grunt_stats.get("combat_skill", 0),
		"toughness": grunt_stats.get("toughness", 4),
		"savvy": grunt_stats.get("savvy", 0),
		"luck": 0,
		"equipment": ["combat_rifle", "trooper_armor"],
		"status": "active"
	}


func generate_fire_team(count: int = 4) -> Array:
	## Generate a fire team of grunts.
	var team: Array = []
	for i in range(count):
		team.append(generate_grunt())
	return team


## ============================================================================
## REGIMENT NAME GENERATION
## ============================================================================

func generate_regiment_name() -> Dictionary:
	## Generate a random regiment name from D100 tables.
	## Returns {full_name: String, part_1: String, part_2: String, uniform_color: String}
	if _regiment_data.is_empty():
		return {"full_name": "Unknown Regiment", "part_1": "", "part_2": "", "uniform_color": ""}

	var color_entry := _find_in_table(_regiment_data.get("uniform_color", []), _roll_d100())
	var color_name: String = color_entry.get("name", "Grey")

	var part1_entry := _find_in_table(_regiment_data.get("title_part_1", []), _roll_d100())
	var part1: String = part1_entry.get("name", "Star")

	# Handle special substitutions
	if part1 == "[color]":
		part1 = color_name
	elif part1 == "[number]":
		part1 = str(randi() % 6 + 1)  # D6 for the number
		# Re-roll part1 to get the descriptive word
		var reroll_entry := _find_in_table(_regiment_data.get("title_part_1", []), _roll_d100())
		var reroll_name: String = reroll_entry.get("name", "Star")
		if reroll_name == "[color]":
			reroll_name = color_name
		elif reroll_name == "[number]":
			reroll_name = "Star"  # Fallback to avoid infinite recursion
		part1 = part1 + _ordinal_suffix(int(part1)) + " " + reroll_name

	var part2_entry := _find_in_table(_regiment_data.get("title_part_2", []), _roll_d100())
	var part2: String = part2_entry.get("name", "Wolves")

	var full_name: String
	if part1.contains(" "):
		# Already has number prefix like "4th Renegade"
		full_name = part1 + " " + part2
	else:
		full_name = part1 + " " + part2

	return {
		"full_name": full_name,
		"part_1": part1,
		"part_2": part2,
		"uniform_color": color_name
	}


## ============================================================================
## HELPERS
## ============================================================================

func _roll_d100() -> int:
	return (randi() % 100) + 1


func _find_in_table(table: Array, roll: int) -> Dictionary:
	for entry in table:
		if entry is Dictionary and entry.has("d100_range"):
			var range_val: Array = entry.d100_range
			if range_val.size() >= 2 and roll >= range_val[0] and roll <= range_val[1]:
				return entry
	return {}


func _apply_stat_bonuses(stats: Dictionary, bonuses: Dictionary) -> void:
	for stat_name in bonuses:
		if stats.has(stat_name):
			stats[stat_name] += bonuses[stat_name]


func _check_commendation() -> Dictionary:
	## Roll 2D6 for combat operations. Each 6 gives +1 XP and +1 Reputation.
	var xp_bonus: int = 0
	var rep_bonus: int = 0
	for i in range(2):
		var die := (randi() % 6) + 1
		if die == 6:
			xp_bonus += 1
			rep_bonus += 1
	return {"xp": xp_bonus, "reputation": rep_bonus}


func _ordinal_suffix(n: int) -> String:
	if n % 100 >= 11 and n % 100 <= 13:
		return "th"
	match n % 10:
		1: return "st"
		2: return "nd"
		3: return "rd"
		_: return "th"
