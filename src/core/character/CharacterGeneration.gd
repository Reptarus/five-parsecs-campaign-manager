@tool
extends RefCounted
class_name FiveParsecsCharacterGeneration

## Five Parsecs Character Generation System
##
## Implements character creation following Five Parsecs From Home Core Rules
## - Attribute generation using 2D6 / 3.0 rounded up formula
## - Character class and background system
## - Five Parsecs specific traits and equipment
## - Hybrid approach: Type-safe enums + Rich JSON data

# GlobalEnums available as autoload singleton
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const UniversalResourceLoader = preload("res://src/core/systems/UniversalResourceLoader.gd")
# DataManager accessed via autoload singleton (not preload)
const SafeDataAccess = preload("res://src/utils/SafeDataAccess.gd")
const SpeciesData = preload("res://src/core/character/SpeciesDataService.gd")

# Data-driven character creation tables
# Note: _skills_data + character_skills.json removed Sprint B Phase B.1
# (2026-05-24) — 5PFH has no skill system; loaded value had zero readers.
static var _character_data: Dictionary = {}
static var _backgrounds_data: Dictionary = {}
static var _is_data_loaded: bool = false

# JSON-loaded creation tables (lazy-loaded on first access)
static var _creation_tables_loaded: bool = false

# Name generation tables (lazy-loaded)

static func _ensure_creation_tables_loaded() -> void:
	if _creation_tables_loaded:
		return
	_creation_tables_loaded = true
	BACKGROUND_TABLE = _load_d100_table("res://data/character_creation_tables/background_table.json")
	MOTIVATION_TABLE = _load_d100_table("res://data/character_creation_tables/motivation_table.json")
	CLASS_TABLE = _load_d100_table("res://data/character_creation_tables/class_table.json")

## Load a D100 table from JSON and convert to the {roll_min, roll_max, name, ...} format
static func _load_d100_table(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("CharacterGeneration: Failed to open %s" % path)
		return []
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		push_error("CharacterGeneration: Failed to parse %s" % path)
		file.close()
		return []
	file.close()
	var data: Dictionary = json.data
	var entries: Dictionary = data.get("entries", {})
	var result: Array = []
	for range_key in entries:
		var entry: Dictionary = entries[range_key]
		var parts: PackedStringArray = range_key.split("-")
		if parts.size() != 2:
			continue
		var roll_min: int = parts[0].to_int()
		var roll_max: int = parts[1].to_int()
		var converted := {"roll_min": roll_min, "roll_max": roll_max, "name": entry.get("name", "")}
		if entry.has("enum_key"):
			converted["enum_key"] = str(entry["enum_key"])
		# Map JSON keys to the format expected by _roll_on_table consumers
		var stat_bonuses: Dictionary = entry.get("stat_bonuses", {})
		var special: Dictionary = entry.get("special", {})
		# Merge stat_bonuses and special into stat_bonus
		var stat_bonus := {}
		for k in stat_bonuses:
			stat_bonus[k] = stat_bonuses[k]
		for k in special:
			# XP is not a stat. It goes to `xp`, which roll_character_tables() sums into
			# resources.xp; folded in here it reached no arm and was dropped.
			if k == "xp":
				converted["xp"] = int(special[k])
			else:
				stat_bonus[k] = special[k]
		if not stat_bonus.is_empty():
			converted["stat_bonus"] = stat_bonus
		var resources: Dictionary = entry.get("resources", {})
		if resources.has("credits_roll"):
			converted["credits_dice"] = 1
		if resources.has("story_points"):
			converted["story_points"] = int(resources["story_points"])
		var equip_rolls: Array = entry.get("equipment_rolls", [])
		if not equip_rolls.is_empty():
			converted["starting_rolls"] = equip_rolls
		# Pass through resource counts from JSON (cast to int — JSON may store as bool)
		if entry.has("patron"):
			converted["patron"] = int(entry["patron"])
		if entry.has("rival"):
			converted["rival"] = int(entry["rival"])
		if entry.has("rumors"):
			converted["rumors"] = int(entry["rumors"])
		if entry.has("xp"):
			converted["xp"] = int(entry["xp"])
		if resources.has("patron"):
			converted["patron"] = int(resources["patron"])
		if resources.has("rival"):
			converted["rival"] = int(resources["rival"])
		if resources.has("rumors"):
			converted["rumors"] = int(resources["rumors"])
		if resources.has("quest_rumors"):
			converted["rumors"] = int(resources["quest_rumors"])
		if resources.has("xp"):
			converted["xp"] = int(resources["xp"])
		result.append(converted)
	# Sort by roll_min
	result.sort_custom(func(a, b): return a["roll_min"] < b["roll_min"])
	return result

## The three D100 creation tables (Core Rules pp.25-27), loaded from
## data/character_creation_tables/ on the first roll. They used to start as hand-copied
## literals: a second copy of the book that had drifted from the JSON.
static var BACKGROUND_TABLE: Array = []
static var MOTIVATION_TABLE: Array = []
static var CLASS_TABLE: Array = []

## Roll on a D100 table and return the matching entry
static func _roll_on_table(table: Array, context: String = "Creation Table") -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var dice: Node = tree.root.get_node_or_null("/root/DiceManager") if tree else null
	var roll: int = int(dice.roll_d100(context)) if dice and dice.has_method("roll_d100") \
			else randi_range(1, 100)
	for entry in table:
		if roll >= entry.get("roll_min", 0) and roll <= entry.get("roll_max", 0):
			var result = entry.duplicate(true)
			result["roll"] = roll
			return result
	# Fallback to first entry if no match (shouldn't happen)
	if table.size() > 0:
		var fallback = table[0].duplicate(true)
		fallback["roll"] = roll
		return fallback
	return {"roll": roll, "name": "Unknown"}

## Roll on all three character creation tables and aggregate resources
## Returns: {background_result, motivation_result, class_result, extra_results,
## resources}, or {} for a species that makes no creation rolls.
##
## With a species_id it follows that species' creation rules, as the creation
## wizard does: Bots and Assault Bots roll nothing (p.15, p.21); a forced
## Background or Motivation replaces the roll (Mutant, Manipulator, Primitive,
## De-converted, Unity Agent, Emo-suppressed, Traveler); Hakshan gain Truth on top
## of their roll (p.20); Mysterious Past roll two Backgrounds (p.20) and Feelers
## two Motivations (p.22).
static func roll_character_tables(species_id: String = "") -> Dictionary:
	_ensure_creation_tables_loaded()
	if not species_id.is_empty() and not SpeciesData.can_roll_creation_tables(species_id):
		return {}
	var bg_result = _roll_on_table(BACKGROUND_TABLE, "Background Table (p.25)")
	var mot_result = _roll_on_table(MOTIVATION_TABLE, "Motivation Table (p.26)")
	var class_result = _roll_on_table(CLASS_TABLE, "Class Table (p.27)")
	var extras: Array = []
	if not species_id.is_empty():
		var forced_bg: String = SpeciesData.get_forced_background(species_id)
		if not forced_bg.is_empty():
			bg_result = _row_for_key(BACKGROUND_TABLE, forced_bg, bg_result)
		var forced_mot: String = SpeciesData.get_forced_motivation(species_id)
		if not forced_mot.is_empty():
			if SpeciesData.is_motivation_additional(species_id):
				extras.append(_tag(_row_for_key(MOTIVATION_TABLE, forced_mot, {}), "Motivation"))
			else:
				mot_result = _row_for_key(MOTIVATION_TABLE, forced_mot, mot_result)
		if SpeciesData.has_double_background(species_id):
			extras.append(_tag(_roll_on_table(BACKGROUND_TABLE, "Background Table (p.25)"),
					"Background"))
		if SpeciesData.has_double_motivation(species_id):
			extras.append(_tag(_roll_on_table(MOTIVATION_TABLE, "Motivation Table (p.26)"),
					"Motivation"))

	# Aggregate resources from all three tables
	var resources = {
		"patrons": 0,
		"rivals": 0,
		"rumors": 0,
		"story_points": 0,
		"credits_dice": 0, # Number of D6 to roll for credits
		"xp": 0,
		"starting_rolls": [] # Equipment rolls to make
	}

	# Sum up all resources
	for result in [bg_result, mot_result, class_result] + extras:
		resources.patrons += result.get("patron", 0)
		resources.rivals += result.get("rival", 0)
		resources.rumors += result.get("rumors", 0)
		resources.story_points += result.get("story_points", 0)
		resources.credits_dice += result.get("credits_dice", 0)
		resources.xp += result.get("xp", 0)
		resources.starting_rolls.append_array(result.get("starting_rolls", []))

	# Roll for bonus credits
	var bonus_credits = 0
	for i in resources.credits_dice:
		bonus_credits += randi_range(1, 6)
	resources["bonus_credits"] = bonus_credits

	return {
		"background_result": bg_result,
		"motivation_result": mot_result,
		"class_result": class_result,
		"extra_results": extras,
		"resources": resources
	}


## The row a forced key names (an enum key like "LOWER_MEGACITY_CLASS" or a name
## like "truth"), or the fallback when the table has no such row.
static func _row_for_key(table: Array, key: String, fallback: Dictionary) -> Dictionary:
	var want := key.to_upper()
	var non_word := RegEx.create_from_string("[^A-Z0-9]+")
	for row: Dictionary in table:
		var by_name: String = non_word.sub(str(row.get("name", "")).to_upper(), "_", true) \
			.trim_prefix("_").trim_suffix("_")
		if str(row.get("enum_key", "")).to_upper() == want or by_name == want:
			return row.duplicate(true)
	return fallback


static func _tag(row: Dictionary, table_label: String) -> Dictionary:
	if not row.is_empty():
		row["_table"] = table_label
	return row


## One stat step with the creation clamps, for table rows and species modifiers.
static func _add_stat(character: Character, stat_name: String, bonus: int) -> void:
	match stat_name:
		"combat":
			character.combat = clampi(character.combat + bonus, 0, 5)
		"reactions", "reaction":
			character.reactions = clampi(character.reactions + bonus, 1, 6)
		"toughness":
			character.toughness = clampi(character.toughness + bonus, 1, 6)
		"speed":
			character.speed = clampi(character.speed + bonus, 4, 8)
		"savvy":
			character.savvy = clampi(character.savvy + bonus, 0, 5)
		"luck":
			character.luck = clampi(character.luck + bonus, 0, 3)

## Apply table results to a character (stat bonuses and traits)
static func apply_table_results_to_character(character: Character, table_results: Dictionary) -> void:
	# Apply stat bonuses from all three tables
	for result_key in ["background_result", "motivation_result", "class_result"]:
		var result = table_results.get(result_key, {})
		var stat_bonuses = result.get("stat_bonus", {})

		for stat_name in stat_bonuses:
			_add_stat(character, str(stat_name), int(stat_bonuses[stat_name]))

		# Add trait for the table result
		var result_name = result.get("name", "")
		if result_name != "":
			match result_key:
				"background_result":
					character.add_trait("Background: " + result_name)
				"motivation_result":
					character.add_trait("Motivation: " + result_name)
				"class_result":
					character.add_trait("Class: " + result_name)

		# The rolled result IS the character's background, motivation and class. It was
		# kept only as a trait, so the field kept create_character()'s default
		# (MILITARY, SURVIVAL, SOLDIER) and every screen that reads the field showed a
		# background the character never rolled.
		var key: String = _enum_key_for(result_key, result)
		if not key.is_empty():
			match result_key:
				"background_result":
					character.background = key
				"motivation_result":
					character.motivation = key
				"class_result":
					character.character_class = key

	# The species' extra rows (a second Background or Motivation, Hakshan's Truth)
	# give their bonuses and a trait; the field keeps the main roll.
	for extra: Dictionary in table_results.get("extra_results", []):
		var extra_bonuses: Dictionary = extra.get("stat_bonus", {})
		for stat_name in extra_bonuses:
			_add_stat(character, str(stat_name), int(extra_bonuses[stat_name]))
		if str(extra.get("name", "")) != "":
			character.add_trait("%s: %s" % [str(extra.get("_table", "Background")),
				str(extra.get("name", ""))])

	# Apply the creation-table XP (Core Rules pp.26-27: Revenge, Power, Freedom,
	# Explorer and Punk are +2 XP). It wrote `experience_points`, which Character does
	# not have, and the loader had folded the XP into the stat bonuses where no arm
	# read it, so those five rows granted nothing.
	#
	# A "rookie_crew" house rule used to zero this instead. It was invented
	# (tagged "source": "Community", no book page) and was removed 2026-09-04.
	var resources = table_results.get("resources", {})
	var xp_bonus: int = int(resources.get("xp", 0))
	if xp_bonus > 0:
		character.experience += xp_bonus

	# No credits here. Rolled credits are a crew resource, and the only caller is the
	# recruit path, where errata v1.06 says "IGNORE ALL CREDITS". They used to land on
	# `credits_earned`, the character's career tally, as money nobody earned.

	# Store table results on character for later reference
	character.set_meta("creation_table_results", table_results)
	character.set_meta("creation_resources", resources)

	pass # Table results and resources applied


## The enum key a rolled table row stands for, or "". Background names do not
## transcribe to their members (p.25 prints "Giant, Overcrowded, Dystopian City" for
## GIANT_OVERCROWDED_CITY), so that table carries an explicit enum_key. Motivation and
## Class names upper-case to their members exactly; test_creation_table_results pins it.
static func _enum_key_for(result_key: String, result: Dictionary) -> String:
	var members: Dictionary = {}
	match result_key:
		"background_result":
			members = GlobalEnums.Background
		"motivation_result":
			members = GlobalEnums.Motivation
		"class_result":
			members = GlobalEnums.CharacterClass
	var key: String = str(result.get("enum_key", ""))
	if key.is_empty():
		var non_word := RegEx.create_from_string("[^A-Z0-9]+")
		key = non_word.sub(str(result.get("name", "")).to_upper(), "_", true) \
			.trim_prefix("_").trim_suffix("_")
	return key if members.has(key) else ""


## A Patron from a character's creation rolls (Core Rules pp.24-27). The book
## gives a Patron a TYPE from the p.83 Patron Table and nothing else, so it is built
## by PatronContact like every other new Patron. This used to pick from six
## invented types ("Trade Guild", "Religious Order" ...) that no Patron table
## has, so the job a creation Patron later offered rolled its p.83 Benefits,
## Hazards and Conditions against a type the thresholds do not know.
static func _create_starting_patron(index: int, source_character: String = "") -> Dictionary:
	var patron: Dictionary = load("res://src/core/patrons/PatronContact.gd").make("creation")
	patron["id"] = "starting_patron_%d_%d" % [Time.get_unix_time_from_system(), index]
	patron["is_starting_patron"] = true
	patron["source_character"] = source_character
	return patron

## A Rival from a character's creation rolls. Core Rules p.92: "You can also use
## that table [the p.94 Enemy Table] to set up new, unexpected Rivals", and "Once a
## Rival has been established, they will always be the same type." Built by
## RivalContact like every other new Rival. This used to pick from five invented
## types ("Gang", "Personal Enemy" ...) that are not enemy types, with an
## invented strength and hostility, so the type pinned nothing at its first battle.
static func _create_starting_rival(index: int, source_character: String = "") -> Dictionary:
	var rival: Dictionary = load("res://src/core/campaign/RivalContact.gd").make("creation", "",
		{"id": "starting_rival_%d_%d" % [Time.get_unix_time_from_system(), index]})
	rival["is_starting_rival"] = true
	rival["source_character"] = source_character
	return rival

## Legacy no-op. The fabricated character_creation_data.json / character_backgrounds.json
## parallel creation data was removed in the 2026-06-01 rules-accuracy consolidation.
## Canonical creation data now lives in data/character_creation_tables/ (D100 tables, loaded
## by _ensure_creation_tables_loaded) and data/character_species.json (species baselines and
## modifiers, applied by set_character_flags()).
static func _load_character_data() -> void:
	_is_data_loaded = true


## Generate d66 for tables (two d6 read as tens and ones)
static func roll_d66() -> int:
	var tens := randi_range(1, 6)
	var ones := randi_range(1, 6)
	return tens * 10 + ones

## Generate d10 for combat resolution
static func roll_d10() -> int:
	return randi_range(1, 10)

## Create a complete Five Parsecs character following official rules
static func create_character(config: Dictionary = {}) -> Character:
	_load_character_data()
	
	# Validate config parameter type
	if not config is Dictionary:
		push_error("CharacterGeneration: config parameter must be a Dictionary, got %s. Using empty config." % typeof(config))
		config = {}
	
	# Debug: Check if Character class is available
	if not Character:
		push_error("CharacterGeneration: Character class not available")
		return null
	
	# Try to create the character with better error handling
	var character: Character
	character = Character.new()
	if not character:
		push_error("CharacterGeneration: Character.new() returned null")
		return null
	

	# Basic identity from config or defaults
	var config_dict = SafeDataAccess.safe_dict_access(config, "character name configuration")
	character.character_name = SafeDataAccess.safe_get(config_dict, "name", "New Character", "character name lookup")
	
	# Handle class assignment - accept both String and int values
	var class_value = SafeDataAccess.safe_get(config_dict, "class", "SOLDIER", "character class lookup")
	if class_value is String:
		var p_class_name: String = class_value
		if p_class_name in GlobalEnums.CharacterClass:
			character.character_class = p_class_name
		else:
			character.character_class = "SOLDIER"
	elif class_value is int:
		character.character_class = GlobalEnums.to_string_value("character_class", class_value)
	else:
		character.character_class = "SOLDIER"
	
	# Handle background assignment - accept both String and int values
	var background_value = SafeDataAccess.safe_get(config_dict, "background", "MILITARY", "character background lookup")
	if background_value is String:
		var p_background_name: String = background_value
		if p_background_name in GlobalEnums.Background:
			character.background = p_background_name
		else:
			character.background = "MILITARY"
	elif background_value is int:
		character.background = background_value
	else:
		character.background = "MILITARY"
	
	# Handle motivation assignment - accept both String and int values  
	var motivation_value = SafeDataAccess.safe_get(config_dict, "motivation", "SURVIVAL", "character motivation lookup")
	if motivation_value is String:
		if motivation_value in GlobalEnums.Motivation:
			character.motivation = motivation_value
		else:
			character.motivation = "SURVIVAL"
	elif motivation_value is int:
		character.motivation = motivation_value
	else:
		character.motivation = "SURVIVAL"
	
	# Handle origin assignment - accept both String and int values
	var origin_value = SafeDataAccess.safe_get(config_dict, "origin", "HUMAN", "character origin lookup")
	if origin_value is String:
		if origin_value in GlobalEnums.Origin:
			character.origin = origin_value
		else:
			character.origin = "HUMAN"
	elif origin_value is int:
		var global_enums = Engine.get_singleton("GlobalEnums")
		character.origin = global_enums.to_string_value("origin", origin_value) if global_enums else "HUMAN"
	else:
		character.origin = "HUMAN"

	# A species from the p.14 Crew Type table (Core Rules p.78: "Each recruit rolls
	# using the random method in the character creation process"). A primary species
	# is also an Origin key; a Strange Character is recorded by name, as the creation
	# wizard records it.
	var species_id: String = str(config.get("species_id", "")).to_lower()
	var is_primary: bool = species_id.to_upper() in GlobalEnums.Origin
	if not species_id.is_empty():
		character.origin = species_id.to_upper() if is_primary \
				else SpeciesData.get_species_name(species_id)
		character.species_id = species_id
		character.special_rules.assign(SpeciesData.get_special_rules(species_id))

	# Five Parsecs base profile + species modifiers (Core Rules pp.15-22, p.27)
	generate_character_attributes(character)
	set_character_flags(character)
	# set_character_flags() knows the primary species only; a Strange Character's
	# modifiers are in character_species.json (pp.19-23).
	if not species_id.is_empty() and not is_primary:
		var mods: Dictionary = SpeciesData.get_stat_modifiers(species_id)
		for stat_name in mods:
			_add_stat(character, str(stat_name), int(mods[stat_name]))

	# Background / Class / Motivation: roll on the canonical D100 creation tables
	# (data/character_creation_tables/) and apply their stat bonuses + traits.
	# Replaces the fabricated character_backgrounds.json bonus path (removed 2026-06-01).
	var table_results := roll_character_tables(species_id)
	if not table_results.is_empty():
		apply_table_results_to_character(character, table_results)

	# Health (Core Rules: Toughness + 2)
	character.max_health = character.toughness + 2
	character.health = character.max_health

	# Starting equipment -> canonical Character.equipment (Array[String]).
	# Core Rules p.77: recruits are armed with a Handgun; class-table starting_rolls
	# (from the D100 tables above) add extra weapons/gear via the enhanced generator.
	var roll_resources: Dictionary = table_results.get("resources", {})
	if "starting_rolls" in character:
		character.starting_rolls = roll_resources.get("starting_rolls", [])
	var equip_dict: Dictionary = _generate_starting_equipment_enhanced(character)
	var equip_list: Array[String] = []
	for cat in ["weapons", "armor", "gear"]:
		for item in equip_dict.get(cat, []):
			if item is String:
				equip_list.append(item)
			elif item is Dictionary and item.has("name"):
				equip_list.append(str(item["name"]))
	if equip_list.is_empty():
		equip_list.append("Handgun")
	character.equipment = equip_list

	return character

## Set the Five Parsecs base profile (Core Rules p.27).
## Species modifiers are applied separately by set_character_flags(); Background /
## Class / Motivation bonuses come from the canonical D100 creation tables via
## roll_character_tables() + apply_table_results_to_character(). The old "2D6 / 3
## rounded up" attribute roll was a fabrication (not in the rulebook) and was
## removed in the 2026-06-01 rules-accuracy consolidation.
static func generate_character_attributes(character: Character) -> void:
	character.reactions = 1   # Reactions 1
	character.speed = 4       # Speed 4"
	character.combat = 0      # Combat +0
	character.toughness = 3   # Toughness 3
	character.savvy = 0       # Savvy +0
	character.luck = 0        # Luck 0 (Humans may exceed via set_character_flags)

	# Health (Core Rules: Toughness + 2)
	character.max_health = character.toughness + 2
	character.health = character.max_health

# NOTE (2026-06-01 rules-accuracy consolidation): the fabricated background-bonus
# chain (apply_background_bonuses / _apply_background_data_bonuses / _apply_stat_bonus /
# _get_background_data_for_character / _get_background_id_from_string /
# _apply_enum_background_bonuses) was REMOVED. It read the deleted character_backgrounds.json
# (and the dead, commented-out DataManager.get_background_data) and double-applied stat
# bonuses on top of the canonical D100 CLASS/BACKGROUND/MOTIVATION tables. Background stat
# bonuses now come solely from apply_table_results_to_character().


# NOTE (2026-06-01 rules-accuracy consolidation): the fabricated origin/background
# equipment chain (generate_starting_equipment / _get_starting_equipment_data /
# _get_background_equipment_data / _merge_equipment_data / _convert_gear_array_to_dict /
# _apply_equipment_data / _apply_basic_equipment) was REMOVED. It read the deleted
# character_creation_data.json + character_backgrounds.json (and dead, commented-out
# DataManager.get_origin_data / get_background_data) and fabricated a flat 1000-credit
# loadout. Starting equipment now comes from _generate_starting_equipment_enhanced()
# (StartingEquipmentGenerator + gear_database.json) per Core Rules p.77.

## Set character flags based on origin (Five Parsecs p.18-20)
## Note: Origin-based properties like is_bot(), is_human() are derived from origin string
## so we only need to apply the stat modifiers and traits here
static func set_character_flags(character: Character) -> void:
	## Apply species stat_modifiers and special rules from character_species.json (VERIFIED).
	## Stat modifiers are RELATIVE to whatever generate_character_attributes() produced.
	match character.origin:
		"HUMAN":
			# Human: Can exceed 1 Luck (Core Rules p.15). No stat modifiers.
			character.luck = clampi(character.luck + 1, 0, 3)
		"BOT":
			# Bot: R+1, C+1, T+1, Sv+2 (Core Rules p.15). 6+ Armor. No creation tables.
			character.reactions = clampi(character.reactions + 1, 1, 6)
			character.combat = clampi(character.combat + 1, 0, 5)
			character.toughness = clampi(character.toughness + 1, 3, 8)
			character.savvy = clampi(character.savvy + 2, 0, 5)
			character.add_trait("Bot: 6+ Armor Save, no XP (upgrade via credits), no consumables/implants")
		"SOULLESS":
			# Soulless: T+1, Sv+1 (Core Rules p.16). 6+ Armor. Bot injury table.
			character.toughness = clampi(character.toughness + 1, 3, 6)
			character.savvy = clampi(character.savvy + 1, 0, 5)
			character.add_trait("Soulless: 6+ Armor Save, no consumables/implants, Bot injury table")
		"ENGINEER":
			# Engineer: T-1, Sv+1 (Core Rules p.16). +1 repair. Toughness max 4.
			character.toughness = clampi(character.toughness - 1, 2, 4)
			character.savvy = clampi(character.savvy + 1, 0, 5)
			character.add_trait("Engineer: +1 to repair rolls, Toughness cannot exceed 4")
		"KERIN":
			# K'Erin: T+1 (Core Rules p.16). Brawl reroll. Must charge if in range.
			character.toughness = clampi(character.toughness + 1, 3, 6)
			character.add_trait("K'Erin: Roll twice in Brawling (pick better), must move to Brawl if enemy in range")
		"PRECURSOR":
			# Precursor: T-1, Sp+1 (Core Rules p.17). Roll 2 char events. Psionic power.
			character.toughness = clampi(character.toughness - 1, 2, 6)
			character.speed = clampi(character.speed + 1, 4, 8)
			character.add_trait("Precursor: Roll twice on events, keep preferred")
			_grant_precursor_psionic_power(character)
		"FERAL":
			# Feral: No stat modifiers (Core Rules p.18). Ignore seize penalties. Reaction 1 priority.
			character.add_trait("Feral: Enemy Seize the Initiative penalties ignored, Reaction Roll 1 goes to Feral")
		"SWIFT":
			# Swift: Sp+1 (Core Rules p.18). Glide/leap. Multi-shot same target.
			character.speed = clampi(character.speed + 1, 4, 8)
			character.add_trait("Swift: Glide to lower position, leap 4\" gaps, jump from any height, multi-shot same target")
		"KRAG":
			# Krag: T+1 (Compendium p.12-15). Cannot Dash. Reroll 1 vs Rivals.
			character.toughness = clampi(character.toughness + 1, 3, 6)
			character.add_trait("Krag: Cannot Dash, reroll natural 1 vs Rivals")
		"SKULKER":
			# Skulker: Sp+2, Sv+1 (Compendium p.14-17). Ignore difficult ground. Poison resist 3+.
			character.speed = clampi(character.speed + 2, 4, 8)
			character.savvy = clampi(character.savvy + 1, 0, 5)
			character.add_trait("Skulker: Ignore difficult ground, ignore obstacles up to 1\", poison resist 3+")

## Grant a random psionic power to a Precursor character (Core Rules p.17)
static func _grant_precursor_psionic_power(character: Character) -> void:
	var path := "res://data/psionic_powers.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		character.add_trait("Precursor: Psionic (power data unavailable)")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	if not json.data is Dictionary:
		return
	var power_ids: Array = json.data.keys()
	if power_ids.is_empty():
		return
	var chosen_id: String = power_ids[randi() % power_ids.size()]
	if "psionic_power" in character:
		character.psionic_power = chosen_id
	else:
		character.set_meta("psionic_power", chosen_id)
	character.add_trait("Psionic Power: %s" % chosen_id)


## Enhanced equipment generation with DiceManager integration
static func _generate_starting_equipment_enhanced(character: Character) -> Dictionary:
	# Get DiceManager through AutoloadManager for safe access
	var dice_manager = AutoloadManager.get_autoload_safe("DiceManager")
	if not dice_manager:
		push_error("CharacterGeneration: DiceManager not available for equipment generation")
		return _generate_fallback_equipment(character)
	
	# Use StartingEquipmentGenerator for proper Five Parsecs equipment generation
	if not ResourceLoader.exists("res://src/core/character/Equipment/StartingEquipmentGenerator.gd"):
		push_error("CharacterGeneration: StartingEquipmentGenerator not found")
		return _generate_fallback_equipment(character)
	
	var equipment_generator = preload("res://src/core/character/Equipment/StartingEquipmentGenerator.gd")
	var equipment = equipment_generator.generate_starting_equipment(character, dice_manager)
	
	if equipment.is_empty():
		push_warning("CharacterGeneration: StartingEquipmentGenerator failed, using fallback")
		return _generate_fallback_equipment(character)
	
	# Apply equipment conditions using dice
	equipment_generator.apply_equipment_condition(equipment, dice_manager)
	
	pass # Equipment generated
	
	return equipment

## Fallback equipment generation when DiceManager/StartingEquipmentGenerator unavailable
static func _generate_fallback_equipment(character: Character) -> Dictionary:
	var equipment = {
		"weapons": [],
		"armor": [],
		"gear": [],
		"credits": 0, # Credits set by campaign creation (Core Rules p.28)
		"condition_modifiers": {}
	}

	# Core Rules p.77: recruits come armed with a Handgun.
	# Class-specific starting rolls (weapons, gear, gadgets) are handled
	# by CLASS_TABLE entries via roll_character_tables(). This fallback
	# just ensures every character has at least a Handgun.
	equipment.weapons.append("Handgun")
	
	return equipment

## Public API for UI access
## These methods wrap the private implementations for external use
