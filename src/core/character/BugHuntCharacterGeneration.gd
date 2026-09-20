class_name BugHuntCharacterGeneration
extends RefCounted

## Generates Bug Hunt main characters and grunts from D100 tables.
## Loads data from data/bug_hunt/bug_hunt_character_creation.json and
## data/bug_hunt/bug_hunt_regiment_names.json.

const DATA_PATH := "res://data/bug_hunt/bug_hunt_character_creation.json"
const REGIMENT_PATH := "res://data/bug_hunt/bug_hunt_regiment_names.json"
const WEAPONS_PATH := "res://data/bug_hunt/bug_hunt_weapons.json"
const ARMOR_PATH := "res://data/bug_hunt/bug_hunt_armor.json"
const GEAR_PATH := "res://data/bug_hunt/bug_hunt_gear.json"
const NAMES_PATH := "res://data/character_names.json"

var _creation_data: Dictionary = {}
var _regiment_data: Dictionary = {}
var _weapons_data: Dictionary = {}
var _armor_data: Dictionary = {}
var _gear_data: Dictionary = {}
var _names_data: Dictionary = {}
var _loaded: bool = false


func _init() -> void:
	_load_data()


func _load_data() -> void:
	_creation_data = _load_json(DATA_PATH)
	_regiment_data = _load_json(REGIMENT_PATH)
	_weapons_data = _load_json(WEAPONS_PATH)
	_armor_data = _load_json(ARMOR_PATH)
	_gear_data = _load_json(GEAR_PATH)
	_names_data = _load_json(NAMES_PATH)
	_loaded = not _creation_data.is_empty() and not _regiment_data.is_empty()


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("BugHuntCharacterGeneration: Could not open file: %s" % path)
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
	# int() on every read. Godot's JSON parser returns EVERY number as a float, so
	# base_stats hands back 3.0 for Toughness; the float then travels through
	# to_dictionary() into the save, and any surface that prints it with str()
	# renders "3.0". That is the T11-33/T11-34 defect found on a real device walk
	# (DisplayText.gd:12-17). Bug Hunt stats are whole numbers in the book
	# (Compendium p.171) and int literals in the shipped JSON, so the coercion is
	# faithful -- and it belongs HERE, not in each renderer, because a renderer-side
	# fix still leaves "toughness": 3.0 on disk.
	var stats := {
		"reactions": int(base.get("reactions", 1)),
		"speed": int(base.get("speed", 4)),
		"combat_skill": int(base.get("combat_skill", 0)),
		"toughness": int(base.get("toughness", 3)),
		"savvy": int(base.get("savvy", 0)),
		"luck": 0  # Bug Hunt does not use Luck
	}

	var xp: int = 0
	var completed_missions: int = 0
	var reputation_bonus: int = 0
	var commendation_xp: int = 0
	var commendation_rep: int = 0

	# Roll Origin (D100)
	var origin_roll := _roll_d100("Bug Hunt Origin")
	var origin: Dictionary = _find_in_table(_creation_data.get("origin_table", []), origin_roll)
	if not origin.is_empty():
		_apply_stat_bonuses(stats, origin.get("stat_bonuses", {}))
		var adv: Dictionary = origin.get("advantages", {})
		xp += adv.get("xp", 0)
		completed_missions += adv.get("completed_missions", 0)
		reputation_bonus += adv.get("reputation", 0)

	# Roll Basic Training (D100)
	var training_roll := _roll_d100("Bug Hunt Basic Training")
	var training: Dictionary = _find_in_table(_creation_data.get("basic_training_table", []), training_roll)
	if not training.is_empty():
		_apply_stat_bonuses(stats, training.get("stat_bonuses", {}))
		var adv: Dictionary = training.get("advantages", {})
		xp += adv.get("xp", 0)
		completed_missions += adv.get("completed_missions", 0)
		reputation_bonus += adv.get("reputation", 0)

	# Roll Service History (D100)
	var service_roll := _roll_d100("Bug Hunt Service History")
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
		character_name = _generate_random_name()

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
		grunt_name = _generate_random_name()

	return {
		"id": grunt_id,
		"character_id": grunt_id,
		"name": grunt_name,
		"character_name": grunt_name,
		"game_mode": "bug_hunt",
		"is_grunt": true,
		# int() for the same reason as generate_main_character: JSON numbers are
		# floats, and a grunt is serialized into the same save.
		"reactions": int(grunt_stats.get("reactions", 1)),
		"speed": int(grunt_stats.get("speed", 4)),
		"combat_skill": int(grunt_stats.get("combat_skill", 0)),
		"toughness": int(grunt_stats.get("toughness", 4)),
		"savvy": int(grunt_stats.get("savvy", 0)),
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

	var color_entry := _find_in_table(_regiment_data.get("uniform_color", []),
		_roll_d100("Bug Hunt Regiment: uniform colour"))
	var color_name: String = color_entry.get("name", "Grey")

	var part1_entry := _find_in_table(_regiment_data.get("title_part_1", []),
		_roll_d100("Bug Hunt Regiment: title part 1"))
	var part1: String = part1_entry.get("name", "Star")

	# Handle special substitutions
	if part1 == "[color]":
		part1 = color_name
	elif part1 == "[number]":
		part1 = str(_roll_d6("Bug Hunt Regiment: number"))  # D6 for the number
		# Re-roll part1 to get the descriptive word.
		#
		# ⚠ NOT "... title part 1 reroll". DiceManager._take_forced matches a queued
		# key as a case-insensitive SUBSTRING of the context (DiceManager.gd:104-122),
		# so that spelling would have "Bug Hunt Regiment: title part 1" as a prefix and
		# a second value queued under the part-1 key would be eaten here instead.
		# Keep every roll context prefix-free of every other one.
		var reroll_entry := _find_in_table(_regiment_data.get("title_part_1", []),
			_roll_d100("Bug Hunt Regiment: title reroll"))
		var reroll_name: String = reroll_entry.get("name", "Star")
		if reroll_name == "[color]":
			reroll_name = color_name
		elif reroll_name == "[number]":
			reroll_name = "Star"  # Fallback to avoid infinite recursion
		part1 = part1 + _ordinal_suffix(int(part1)) + " " + reroll_name

	var part2_entry := _find_in_table(_regiment_data.get("title_part_2", []),
		_roll_d100("Bug Hunt Regiment: title part 2"))
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

func _generate_random_name() -> String:
	## ISSUE-056: Generate a real name from character_names.json
	var firsts: Array = _names_data.get("first_names", [])
	var lasts: Array = _names_data.get("last_names", [])
	if firsts.is_empty() or lasts.is_empty():
		return "Trooper " + str(randi() % 9000 + 1000)
	var first: String = firsts[randi() % firsts.size()]
	var last: String = lasts[randi() % lasts.size()]
	return first + " " + last


func _roll_d100(context: String = "Bug Hunt D100") -> int:
	var dm: Node = _dice_manager()
	if dm:
		return int(dm.roll_d100(context))
	return randi_range(1, 100)


func _find_in_table(table: Array, roll: int) -> Dictionary:
	for entry in table:
		if entry is Dictionary and entry.has("d100_range"):
			var range_val: Array = entry.d100_range
			if range_val.size() >= 2 and roll >= range_val[0] and roll <= range_val[1]:
				return entry
	return {}


func _apply_stat_bonuses(stats: Dictionary, bonuses: Dictionary) -> void:
	## Both operands are coerced: the bonus comes from JSON (so it is a float), and
	## += would re-float a stat the caller had already coerced. See the note in
	## generate_main_character for why this is fixed at the source.
	for stat_name in bonuses:
		if stats.has(stat_name):
			stats[stat_name] = int(stats[stat_name]) + int(bonuses[stat_name])


func _check_commendation() -> Dictionary:
	## Roll 2D6 for combat operations. Each 6 gives +1 XP and +1 Reputation.
	var xp_bonus: int = 0
	var rep_bonus: int = 0
	for i in range(2):
		var die := _roll_d6("Bug Hunt Commendation: die %d" % (i + 1))
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


## ============================================================================
## EQUIPMENT LOOKUP (Bug Hunt weapons/armor/gear from Compendium JSON)
## ============================================================================

func get_weapon_by_id(weapon_id: String) -> Dictionary:
	## Look up weapon stats from bug_hunt_weapons.json by ID
	for weapon in _weapons_data.get("weapons", []):
		if weapon.get("id", "") == weapon_id:
			return weapon
	return {}

func get_armor_by_id(armor_id: String) -> Dictionary:
	## Look up armor stats from bug_hunt_armor.json by ID
	for armor in _armor_data.get("armor", []):
		if armor.get("id", "") == armor_id:
			return armor
	return {}

func get_gear_by_id(gear_id: String) -> Dictionary:
	## Look up gear stats from bug_hunt_gear.json by ID
	for gear in _gear_data.get("gear", []):
		if gear.get("id", "") == gear_id:
			return gear
	return {}

func get_all_weapons() -> Array:
	## Get all Bug Hunt weapons
	return _weapons_data.get("weapons", [])

func get_all_armor() -> Array:
	## Get all Bug Hunt armor types
	return _armor_data.get("armor", [])

func get_all_gear() -> Array:
	## Get all Bug Hunt gear items
	return _gear_data.get("gear", [])

func get_standard_issue_weapons() -> Array:
	## Get weapons marked as standard issue
	var result: Array = []
	for weapon in _weapons_data.get("weapons", []):
		if weapon.get("is_standard_issue", false):
			result.append(weapon)
	return result

func resolve_equipment(equipment_ids: Array) -> Array:
	## Convert equipment ID list to full stat block dictionaries
	var resolved: Array = []
	for eq_id in equipment_ids:
		var weapon := get_weapon_by_id(eq_id)
		if not weapon.is_empty():
			resolved.append(weapon)
			continue
		var armor := get_armor_by_id(eq_id)
		if not armor.is_empty():
			resolved.append(armor)
			continue
		var gear := get_gear_by_id(eq_id)
		if not gear.is_empty():
			resolved.append(gear)
			continue
		resolved.append({"id": eq_id, "name": eq_id, "type": "unknown"})
	return resolved


## ── Dice routing ────────────────────────────────────────────────────────────
## Book table rolls go through the DiceManager autoload so they are recorded in
## the roll history and can be forced from the QA dialog in a debug build.
##
## This is RefCounted, so it reaches the autoload through
## Engine.get_main_loop().root — a bare get_node_or_null() from a .new() object
## does not return null, it ERRORS and aborts the enclosing function.
##
## Map PLACEMENT (contact sectors, spawn edges, signal positions) is deliberately
## left on raw randi(): 5PFH's BattlefieldGenerator.gd has zero DiceManager
## references and seeds a local RNG for placement. Routing it would flood the
## forced-roll queue with entries a tester never asked to control.
func _dice_manager() -> Node:
	if Engine.get_main_loop() == null:
		return null
	return Engine.get_main_loop().root.get_node_or_null("/root/DiceManager")


func _roll_d6(context: String) -> int:
	var dm: Node = _dice_manager()
	if dm:
		return int(dm.roll_d6(context))
	return randi_range(1, 6)
