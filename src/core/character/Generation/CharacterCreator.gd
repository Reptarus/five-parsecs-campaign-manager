@tool
extends Control

signal character_created(character)
signal character_edited(character)
signal creation_cancelled

const FiveParsecsCharacter = preload("res://src/core/character/Base/Character.gd")
const FiveParsecsCharacterStats = preload("res://src/core/character/Base/CharacterStats.gd")
const FiveParsecsCharacterTableRoller = preload("res://src/core/character/Generation/CharacterTableRoller.gd")
const StartingEquipmentGen = preload("res://src/core/character/Equipment/StartingEquipmentGenerator.gd")
enum CreatorMode {
	CHARACTER,
	CAPTAIN,
	INITIAL_CREW
}

# Maps CharacterStats enum values to flat property names on BaseCharacterResource
const STAT_PROPERTY_MAP := {
	"COMBAT_SKILL": "combat",
	"REACTIONS": "reaction",
	"TOUGHNESS": "toughness",
	"SAVVY": "savvy",
	"LUCK": "luck",
	"SPEED": "speed",
	# CREDITS removed — not a character stat. WEALTH motivation credits
	# applied at campaign level in CampaignFinalizationService
}

# Rulebook-order dropdown items: [display_name, enum_value]
# These match the Five Parsecs character creation tables
const ORIGIN_ITEMS: Array = [
	["Human", 1],       # GlobalEnums.Origin.HUMAN
	["Engineer", 2],    # GlobalEnums.Origin.ENGINEER
	["Kerin", 4],       # GlobalEnums.Origin.KERIN
	["Soulless", 6],    # GlobalEnums.Origin.SOULLESS
	["Precursor", 5],   # GlobalEnums.Origin.PRECURSOR
	["Feral", 3],       # GlobalEnums.Origin.FERAL
	["Swift", 7],       # GlobalEnums.Origin.SWIFT
	["Bot", 8],         # GlobalEnums.Origin.BOT
]

const BACKGROUND_ITEMS: Array = [
	["Peaceful High Tech Colony", 12],        # PEACEFUL_HIGH_TECH_COLONY
	["Giant Overcrowded Dystopian City", 13], # GIANT_OVERCROWDED_CITY
	["Low Tech Colony", 14],                  # LOW_TECH_COLONY
	["Mining Colony", 15],                    # MINING_COLONY
	["Military Brat", 16],                    # MILITARY_BRAT
	["Space Station", 17],                    # SPACE_STATION
	["Military Outpost", 18],                 # MILITARY_OUTPOST
	["Drifter", 19],                          # DRIFTER
	["Lower Megacity Class", 20],             # LOWER_MEGACITY_CLASS
	["Wealthy Merchant Family", 21],          # WEALTHY_MERCHANT_FAMILY
	["Frontier Gang", 22],                    # FRONTIER_GANG
	["Religious Cult", 23],                   # RELIGIOUS_CULT
	["War Torn Hell Hole", 24],               # WAR_TORN_HELLHOLE
	["Tech Guild", 25],                       # TECH_GUILD
	["Subjugated Colony", 26],                # SUBJUGATED_COLONY
	["Long Term Space Mission", 27],          # LONG_TERM_SPACE_MISSION
	["Research Outpost", 28],                 # RESEARCH_OUTPOST
	["Primitive World", 29],                  # PRIMITIVE_WORLD
	["Orphan Utility Program", 30],           # ORPHAN_UTILITY_PROGRAM
	["Isolationist Enclave", 31],             # ISOLATIONIST_ENCLAVE
	["Comfortable Megacity Class", 32],       # COMFORTABLE_MEGACITY
	["Industrial World", 33],                 # INDUSTRIAL_WORLD
	["Bureaucrat", 34],                       # BUREAUCRAT
	["Wasteland Nomads", 35],                 # WASTELAND_NOMADS
	["Alien Culture", 36],                    # ALIEN_CULTURE
]

const CLASS_ITEMS: Array = [
	["Working Class", 9],     # WORKING_CLASS
	["Technician", 10],       # TECHNICIAN
	["Scientist", 11],        # SCIENTIST
	["Hacker", 12],           # HACKER
	["Soldier", 1],           # SOLDIER
	["Mercenary", 13],        # MERCENARY
	["Agitator", 14],         # AGITATOR
	["Primitive", 15],        # PRIMITIVE
	["Artist", 16],           # ARTIST
	["Negotiator", 17],       # NEGOTIATOR
	["Trader", 18],           # TRADER
	["Starship Crew", 19],    # STARSHIP_CREW
	["Petty Criminal", 20],   # PETTY_CRIMINAL
	["Ganger", 21],           # GANGER
	["Scoundrel", 22],        # SCOUNDREL
	["Enforcer", 23],         # ENFORCER
	["Special Agent", 24],    # SPECIAL_AGENT
	["Troubleshooter", 25],   # TROUBLESHOOTER
	["Bounty Hunter", 26],    # BOUNTY_HUNTER
	["Nomad", 27],            # NOMAD
	["Explorer", 28],         # EXPLORER
	["Punk", 29],             # PUNK
	["Scavenger", 30],        # SCAVENGER
]

const MOTIVATION_ITEMS: Array = [
	["Wealth", 1],       # WEALTH
	["Fame", 13],        # FAME
	["Glory", 3],        # GLORY
	["Survival", 7],     # SURVIVAL
	["Escape", 14],      # ESCAPE
	["Adventure", 15],   # ADVENTURE
	["Truth", 16],       # TRUTH
	["Technology", 17],  # TECHNOLOGY
	["Discovery", 10],   # DISCOVERY
	["Loyalty", 8],      # LOYALTY
	["Revenge", 2],      # REVENGE
	["Romance", 18],     # ROMANCE
	["Faith", 19],       # FAITH
	["Political", 20],   # POLITICAL
	["Power", 5],        # POWER
	["Order", 21],       # ORDER
	["Freedom", 9],      # FREEDOM
]

@onready var name_input: LineEdit = %NameInput
@onready var origin_options: OptionButton = %OriginOptions
@onready var background_options: OptionButton = %BackgroundOptions
@onready var class_options: OptionButton = %ClassOptions
@onready var motivation_options: OptionButton = %MotivationOptions
@onready var randomize_btn: Button = %RandomizeButton
@onready var clear_btn: Button = %ClearButton
@onready var confirm_btn: Button = %AddToCrewButton
@onready var back_btn: Button = %BackButton
@onready var preview_info: RichTextLabel = %PreviewInfo
@onready var portrait_dialog: FileDialog = %PortraitDialog

var current_character
var creator_mode: CreatorMode = CreatorMode.CHARACTER
var _is_editing: bool = false
var current_bonuses: Dictionary = {
	"origin": {},
	"background": {},
	"class": {},
	"motivation": {}
}
## Bonus tables loaded from character_creation_bonuses.json (Core Rules pp.15-18, 24-27)
var _bonus_tables: Dictionary = {}
## D100/2D6 creation tables loaded from data/character_creation_tables/
var _background_d100: Dictionary = {}
var _class_d100: Dictionary = {}
var _motivation_d100: Dictionary = {}
## Maps origin OptionButton item index → species_id string (Core Rules pp.15-22)
var _origin_species_ids: Array[String] = []

func _init() -> void:
	current_character = FiveParsecsCharacter.new()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_load_bonus_tables()
	_load_creation_tables()
	_populate_dropdowns()
	name_input.text_changed.connect(_on_name_changed)
	origin_options.item_selected.connect(_on_origin_changed)
	background_options.item_selected.connect(_on_background_changed)
	class_options.item_selected.connect(_on_class_changed)
	motivation_options.item_selected.connect(_on_motivation_changed)
	randomize_btn.pressed.connect(_on_randomize_pressed)
	clear_btn.pressed.connect(_on_clear_pressed)
	confirm_btn.pressed.connect(_on_confirm_pressed)
	back_btn.pressed.connect(_on_cancel_pressed)
	preview_info.meta_clicked.connect(_on_preview_meta_clicked)
	_update_preview()

func _populate_dropdowns() -> void:
	# Build origin list with DLC species if enabled
	var origins: Array = ORIGIN_ITEMS.duplicate()
	var dlc = Engine.get_main_loop().root.get_node_or_null(
		"/root/DLCManager") if Engine.get_main_loop() else null
	# Track which DLC species are locked (shown but disabled)
	var locked_species: Array[String] = []
	if dlc and dlc.has_method("is_feature_enabled"):
		var flags = dlc.get("ContentFlag") if dlc.has_method("get") else null
		if not flags and "ContentFlag" in dlc:
			flags = dlc.ContentFlag
		if flags:
			if "SPECIES_KRAG" in flags:
				if dlc.is_feature_enabled(flags.SPECIES_KRAG):
					origins.append(["Krag (DLC)", GlobalEnums.Origin.KRAG])
				else:
					origins.append(["Krag (DLC Required)", GlobalEnums.Origin.KRAG])
					locked_species.append("Krag")
			if "SPECIES_SKULKER" in flags:
				if dlc.is_feature_enabled(flags.SPECIES_SKULKER):
					origins.append(["Skulker (DLC)", GlobalEnums.Origin.SKULKER])
				else:
					origins.append(["Skulker (DLC Required)", GlobalEnums.Origin.SKULKER])
					locked_species.append("Skulker")
			if "PRISON_PLANET_CHARACTER" in flags:
				if dlc.is_feature_enabled(flags.PRISON_PLANET_CHARACTER):
					origins.append(["Prison Planet (DLC)", GlobalEnums.Origin.PRISON_PLANET])
				else:
					origins.append(["Prison Planet (DLC Required)", GlobalEnums.Origin.PRISON_PLANET])
					locked_species.append("Prison Planet")
	_populate_option_button(origin_options, origins)

	# Build parallel species_id map for primary + DLC species
	_origin_species_ids.clear()
	for item in origins:
		# Map display name → species_id (lowercase, underscored)
		var display: String = item[0].split(" (")[0]  # strip "(DLC)" etc.
		_origin_species_ids.append(
			display.to_lower().replace(" ", "_").replace("'", ""))

	# Disable locked DLC species entries in dropdown
	for i in range(origin_options.item_count):
		var item_text: String = origin_options.get_item_text(i)
		for species_name in locked_species:
			if species_name in item_text and "Required" in item_text:
				origin_options.set_item_disabled(i, true)
				var dlc_name: String = (
					"Fixer's Guidebook DLC"
					if species_name == "Prison Planet"
					else "Trailblazer's Toolkit DLC")
				origin_options.set_item_tooltip(
					i, "Requires " + dlc_name)

	# Add Strange Characters from JSON (Core Rules pp.19-22)
	SpeciesDataService._ensure_loaded()
	var strange_species: Array[Dictionary] = []
	for sp in SpeciesDataService.get_all_species():
		if sp.get("category") == "strange_characters":
			strange_species.append(sp)
	if not strange_species.is_empty():
		origin_options.add_separator("── Strange Characters ──")
		_origin_species_ids.append("")  # separator placeholder
		for sp in strange_species:
			var idx: int = origin_options.item_count
			origin_options.add_item(sp.get("name", "Unknown"))
			# Negative IDs = non-enum Strange Characters
			origin_options.set_item_id(idx, -(idx + 100))
			_origin_species_ids.append(sp.get("id", ""))

	_populate_option_button(background_options, BACKGROUND_ITEMS)
	_populate_option_button(class_options, CLASS_ITEMS)
	_populate_option_button(motivation_options, MOTIVATION_ITEMS)

func _populate_option_button(btn: OptionButton, items: Array) -> void:
	btn.clear()
	for item in items:
		btn.add_item(item[0])
		btn.set_item_id(btn.item_count - 1, item[1])

func start_creation(mode = CreatorMode.CHARACTER) -> void:
	if mode is bool:
		# Legacy compatibility: convert bool to enum
		creator_mode = CreatorMode.CAPTAIN if mode else CreatorMode.CHARACTER
	else:
		creator_mode = mode as CreatorMode
	_is_editing = false
	clear()
	if is_inside_tree() and not Engine.is_editor_hint():
		# BUG-030 FIX: Initialize character properties from default dropdown
		# selections AFTER clear() creates a new character. Godot OptionButton
		# doesn't fire item_selected for the default index 0, so properties
		# like origin would stay at NONE if the player doesn't interact.
		_on_origin_changed(origin_options.selected)
		_on_background_changed(background_options.selected)
		_on_class_changed(class_options.selected)
		_on_motivation_changed(motivation_options.selected)
		_sync_ui_from_character()
		_update_mode_ui()
		_update_preview()
	show()

func edit_character(character: FiveParsecsCharacter) -> void:
	_is_editing = true
	current_character = character
	_load_character_data(character)
	if is_inside_tree() and not Engine.is_editor_hint():
		_sync_ui_from_character()
		_update_preview()
	show()

func clear() -> void:
	current_character = FiveParsecsCharacter.new()
	_set_base_stats()
	if creator_mode == CreatorMode.CAPTAIN:
		_setup_captain_bonuses()

	current_bonuses.clear()
	current_bonuses = {
		"origin": {},
		"background": {},
		"class": {},
		"motivation": {}
	}

	_validate_character()

## Safe Property Access Methods
func _get_character_property(character, property: String, default_value = null) -> Variant:
	if not character:
		push_error("Trying to access property '%s' on null character" % property)
		return default_value
	if not property in character:
		return default_value
	return character.get(property)

func _set_character_property(character, property: String, value: Variant) -> void:
	if not character:
		push_error("Trying to set property '%s' on null character" % property)
		return
	if not property in character:
		push_error("Character missing required property: %s" % property)
		return
	character.set(property, value)

func _load_character_data(character: FiveParsecsCharacter) -> void:
	if not character:
		push_error("Invalid character provided for editing")
		return

	_set_character_property(current_character, "character_name", _get_character_property(character, "character_name", ""))
	_set_character_property(current_character, "origin", _get_character_property(character, "origin", 0))
	_set_character_property(current_character, "character_class", _get_character_property(character, "character_class", 0))
	_set_character_property(current_character, "background", _get_character_property(character, "background", 0))
	_set_character_property(current_character, "motivation", _get_character_property(character, "motivation", 0))
	_set_character_property(current_character, "portrait_path", _get_character_property(character, "portrait_path", ""))

	# Copy flat stats directly
	current_character.combat = character.combat
	current_character.reaction = character.reaction
	current_character.toughness = character.toughness
	current_character.speed = character.speed
	current_character.savvy = character.savvy
	current_character.luck = character.luck

	_validate_character()

func _set_base_stats() -> void:
	## Five Parsecs from Home base character stats (core rules)
	if not current_character:
		return
	current_character.reaction = 1
	current_character.speed = 4
	current_character.combat = 0
	current_character.toughness = 3
	current_character.savvy = 0
	current_character.luck = 0

func _setup_captain_bonuses() -> void:
	if not current_character:
		return
	# Captain gets +1 combat and +1 luck (Five Parsecs core rules)
	current_character.combat += 1
	current_character.luck += 1

func _apply_stat_bonus(stat_key: String, bonus: int) -> void:
	## Apply a stat bonus using the STAT_PROPERTY_MAP key name
	var prop_name: String = STAT_PROPERTY_MAP.get(stat_key, "")
	if prop_name.is_empty() or not current_character:
		return
	var raw_val = current_character.get(prop_name)
	if raw_val == null:
		# Property doesn't exist on character (e.g., "credits" is campaign-level)
		return
	var current_val: int = raw_val
	current_character.set(prop_name, current_val + bonus)

func _remove_bonuses(bonus_dict: Dictionary) -> void:
	for stat_key in bonus_dict:
		_apply_stat_bonus(stat_key, -bonus_dict[stat_key])

func _apply_bonuses(bonus_dict: Dictionary) -> void:
	for stat_key in bonus_dict:
		_apply_stat_bonus(stat_key, bonus_dict[stat_key])

func _apply_origin_bonuses(origin_id: int) -> void:
	if not current_character:
		return
	_remove_bonuses(current_bonuses.origin)
	current_bonuses.origin.clear()

	# Five Parsecs species/origin stat bonuses (Core Rules pp.15-18)
	# Loaded from character_creation_bonuses.json
	var bonuses: Dictionary = _lookup_bonuses("origin_bonuses", origin_id)
	for key in bonuses:
		current_bonuses.origin[key] = bonuses[key]

	# Precursor characters begin with one randomly determined Psionic Power (p.17)
	if origin_id == GlobalEnums.Origin.PRECURSOR:
		_grant_random_psionic_power()

	_apply_bonuses(current_bonuses.origin)

func _apply_strange_character_stats(species_id: String) -> void:
	## Apply stat modifiers from character_species.json for Strange Characters
	if not current_character or species_id.is_empty():
		return
	_remove_bonuses(current_bonuses.origin)
	current_bonuses.origin.clear()
	var mods: Dictionary = SpeciesDataService.get_stat_modifiers(
		species_id)
	for stat_key in mods:
		var val: int = mods[stat_key]
		if val != 0:
			current_bonuses.origin[stat_key] = val
	_apply_bonuses(current_bonuses.origin)

func _enforce_species_constraints(species_id: String) -> void:
	## Lock/unlock dropdowns based on Strange Character rules (Core Rules pp.19-22)
	if not is_inside_tree() or Engine.is_editor_hint():
		return
	# Reset all to enabled
	background_options.disabled = false
	class_options.disabled = false
	motivation_options.disabled = false

	if species_id.is_empty():
		return

	# Assault Bot: no creation tables (Core Rules p.21)
	if not SpeciesDataService.can_roll_creation_tables(species_id):
		background_options.disabled = true
		class_options.disabled = true
		motivation_options.disabled = true
		return

	# Forced motivation (De-converted→Revenge, Unity Agent→Order, etc.)
	var forced_mot: String = SpeciesDataService.get_forced_motivation(
		species_id)
	if not forced_mot.is_empty():
		var mot_idx := _find_item_index_by_name(
			MOTIVATION_ITEMS, forced_mot.capitalize())
		if mot_idx >= 0:
			_set_character_property(
				current_character, "motivation",
				MOTIVATION_ITEMS[mot_idx][1])
			_apply_motivation_bonuses(MOTIVATION_ITEMS[mot_idx][1])
			for i in range(motivation_options.item_count):
				if motivation_options.get_item_id(i) == MOTIVATION_ITEMS[mot_idx][1]:
					motivation_options.select(i)
					break
			motivation_options.disabled = true

	# Forced background (Mutant→Lower Megacity, Manipulator→Bureaucrat, etc.)
	var forced_bg: String = SpeciesDataService.get_forced_background(
		species_id)
	if not forced_bg.is_empty():
		# Convert snake_case JSON id to display name for matching
		var bg_display: String = forced_bg.replace(
			"_", " ").capitalize()
		var bg_idx := _find_item_index_by_name(
			BACKGROUND_ITEMS, bg_display)
		if bg_idx >= 0:
			_set_character_property(
				current_character, "background",
				BACKGROUND_ITEMS[bg_idx][1])
			_apply_background_bonuses(BACKGROUND_ITEMS[bg_idx][1])
			for i in range(background_options.item_count):
				if background_options.get_item_id(i) == BACKGROUND_ITEMS[bg_idx][1]:
					background_options.select(i)
					break
			background_options.disabled = true

func _grant_random_psionic_power() -> void:
	## Grant a random psionic power to the current character (Precursor origin, Core Rules p.17)
	if not current_character:
		return
	var psionic_data: Dictionary = _load_psionic_powers()
	if psionic_data.is_empty():
		return
	var power_ids: Array = psionic_data.keys()
	var chosen_id: String = power_ids[randi() % power_ids.size()]
	# Use safe setter — BaseCharacterResource may not have psionic_power property
	if "psionic_power" in current_character:
		current_character.psionic_power = chosen_id
	else:
		# Store as metadata for later transfer to full Character object
		current_character.set_meta("psionic_power", chosen_id)


func _load_psionic_powers() -> Dictionary:
	var path := "res://data/psionic_powers.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("CharacterCreator: Could not open %s" % path)
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}


func _load_bonus_tables() -> void:
	var path := "res://data/character_creation_bonuses.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("CharacterCreator: Could not open character_creation_bonuses.json, using fallback")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("CharacterCreator: Failed to parse character_creation_bonuses.json")
		return
	if json.data is Dictionary:
		_bonus_tables = json.data

func _load_creation_tables() -> void:
	## Load D100/2D6 weighted creation tables (Core Rules pp.24-27)
	_background_d100 = _load_json_file("res://data/character_creation_tables/background_table.json")
	_class_d100 = _load_json_file("res://data/character_creation_tables/class_table.json")
	_motivation_d100 = _load_json_file("res://data/character_creation_tables/motivation_table.json")

func _load_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("CharacterCreator: Could not open %s" % path)
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}

# Cached gear_database.json for creation bonus lookups
var _gear_db_for_bonuses: Dictionary = {}

func _roll_and_store_creation_bonuses(character) -> void:
	## Roll creation bonuses from gear_database.json using character's actual
	## background/motivation/class. Stores concrete rolled results on
	## character.creation_bonuses so all downstream consumers read one source.
	## Core Rules pp.23-28: resources are pooled at crew level, but we track
	## per-character contributions for display and attribution.
	if not character:
		return
	if _gear_db_for_bonuses.is_empty():
		_gear_db_for_bonuses = _load_json_file(
			"res://data/gear_database.json")
	var bonuses := {
		"bonus_credits": 0,
		"patrons": 0,
		"rivals": 0,
		"story_points": 0,
		"quest_rumors": 0,
		"xp": 0,
		"starting_rolls": [] as Array,
		"rolled_items": [] as Array,
		"credits_dice_sources": [] as Array,
	}
	if _gear_db_for_bonuses.is_empty():
		_set_character_property(character, "creation_bonuses", bonuses)
		return

	var lookups := {
		"backgrounds": _get_character_property(
			character, "background", 0),
		"motivations": _get_character_property(
			character, "motivation", 0),
		"classes": _get_character_property(
			character, "character_class", 0),
	}
	for table_key in lookups:
		var enum_val = lookups[table_key]
		var enum_name: String = ""
		if enum_val is String and not enum_val.is_empty():
			enum_name = enum_val.to_lower()
		elif enum_val is int:
			var enum_dict: Dictionary = {}
			match table_key:
				"backgrounds":
					enum_dict = GlobalEnums.Background
				"motivations":
					enum_dict = GlobalEnums.Motivation
				"classes":
					enum_dict = GlobalEnums.CharacterClass
			for key in enum_dict:
				if enum_dict[key] == enum_val:
					enum_name = key.to_lower()
					break
		if enum_name.is_empty() or enum_name == "none":
			continue
		var table: Array = _gear_db_for_bonuses.get(
			table_key, [])
		for entry in table:
			if not entry is Dictionary:
				continue
			if entry.get("id", "") != enum_name:
				continue
			var res: Dictionary = entry.get("resources", {})
			bonuses.patrons += res.get("patron", 0)
			bonuses.rivals += res.get("rival", 0)
			bonuses.quest_rumors += res.get(
				"quest_rumors", 0)
			bonuses.story_points += res.get(
				"story_points", 0)
			bonuses.xp += res.get("xp", 0)
			bonuses.starting_rolls.append_array(
				entry.get("starting_rolls", []))
			var dice_str: String = res.get(
				"credits_dice", "")
			if not dice_str.is_empty():
				var rolled: int = 0
				var d := dice_str.to_lower()
				if d == "2d6":
					rolled = randi_range(1, 6) + randi_range(1, 6)
				elif d in ["1d6", "d6"]:
					rolled = randi_range(1, 6)
				bonuses.bonus_credits += rolled
				bonuses.credits_dice_sources.append({
					"source": table_key.trim_suffix("s"),
					"dice": dice_str,
					"rolled": rolled,
				})
			break
	# Roll actual item names from D100 tables for display
	if not bonuses.starting_rolls.is_empty():
		var wt: Dictionary = _gear_db_for_bonuses.get(
			"weapon_tables", {})
		for roll_type in bonuses.starting_rolls:
			var table_key: String = str(roll_type)
			var table: Array = wt.get(table_key, [])
			if table.is_empty():
				continue
			var roll: int = randi_range(1, 100)
			var item_name: String = ""
			for entry in table:
				var r: Array = entry.get("roll_range", [0, 0])
				if roll >= r[0] and roll <= r[1]:
					item_name = entry.get("name", "")
					break
			if item_name.is_empty() and table.size() > 0:
				item_name = table[-1].get("name", "Unknown")
			if not item_name.is_empty():
				bonuses.rolled_items.append({
					"name": item_name,
					"type": table_key.replace(
						"_", " ").capitalize(),
				})
	# Strange Character creation bonus adjustments (Core Rules pp.19-22)
	var sid: String = _get_character_property(
		character, "species_id", "").to_lower()
	if not sid.is_empty():
		match sid:
			"mysterious_past":
				# Bonus story points from tables are ignored (p.20)
				bonuses.story_points = 0
			"genetic_uplift":
				# Background bonus credits ignored, +1 rival (p.21)
				bonuses.bonus_credits = 0
				bonuses.credits_dice_sources.clear()
				bonuses.rivals += 1
			"minor_alien":
				# Bonus credits/story points reduced by 1 (p.22)
				bonuses.bonus_credits = maxi(
					bonuses.bonus_credits - 1, 0)
				bonuses.story_points = maxi(
					bonuses.story_points - 1, 0)
				# Roll XP discount stat (Core Rules p.22)
				# 1=Reactions, 2-3=Speed, 4=Combat, 5=Toughness, 6=Savvy
				var disc_roll: int = randi_range(1, 6)
				var disc_stat: String = ""
				match disc_roll:
					1: disc_stat = "reactions"
					2, 3: disc_stat = "speed"
					4: disc_stat = "combat"
					5: disc_stat = "toughness"
					6: disc_stat = "savvy"
				_set_character_property(
					character, "xp_discount_stat", disc_stat)
			"traveler":
				# +2 story points, +2 quest rumors (p.22)
				bonuses.story_points += 2
				bonuses.quest_rumors += 2
			"hopeful_rookie":
				# Begin with 1 Luck (p.21)
				_set_character_property(character, "luck", 1)

	_set_character_property(character, "creation_bonuses", bonuses)

func _roll_d100_table(table: Dictionary) -> String:
	## Roll D100 and return the matching entry name from a creation table.
	## Table format: { "entries": { "1-4": { "name": "..." }, "5-9": { ... } } }
	var entries: Dictionary = table.get("entries", {})
	if entries.is_empty():
		return ""
	var roll: int = (randi() % 100) + 1  # 1-100
	for range_key in entries:
		var parts: PackedStringArray = range_key.split("-")
		if parts.size() == 2:
			var low: int = int(parts[0])
			var high: int = int(parts[1])
			if roll >= low and roll <= high:
				return entries[range_key].get("name", "")
	return ""

func _roll_2d6_table(table: Dictionary) -> String:
	## Roll 2D6 (as D66: tens + units) and return the matching entry name.
	## Table format: { "11": { "name": "..." }, "12": { ... } }
	var d1: int = (randi() % 6) + 1
	var d2: int = (randi() % 6) + 1
	var key: String = str(d1) + str(d2)
	if key in table:
		return table[key].get("name", "")
	return ""

func _find_item_index_by_name(items: Array, entry_name: String) -> int:
	## Find the index in a const items array whose display name best matches entry_name.
	for i in range(items.size()):
		if items[i][0].to_lower().replace("-", " ").replace("'", "") == entry_name.to_lower().replace("-", " ").replace("'", ""):
			return i
		# Partial match fallback (e.g. "Peaceful High-Tech Colony" vs "Peaceful High Tech Colony")
		if items[i][0].to_lower().begins_with(entry_name.to_lower().left(10)):
			return i
	return -1

func _lookup_bonuses(table_key: String, id: int) -> Dictionary:
	## Look up stat bonuses from JSON by enum int value. Returns empty dict if not found.
	var table: Dictionary = _bonus_tables.get(table_key, {})
	var entry: Dictionary = table.get(str(id), {})
	# Strip _comment keys — only return stat bonus keys
	var result: Dictionary = {}
	for key in entry:
		if key != "_comment":
			result[key] = entry[key]
	return result

func _apply_background_bonuses(bg_id: int) -> void:
	if not current_character:
		return
	_remove_bonuses(current_bonuses.background)
	current_bonuses.background.clear()

	# Five Parsecs background stat bonuses (pp.24-25)
	# Loaded from character_creation_bonuses.json
	var bonuses: Dictionary = _lookup_bonuses("background_bonuses", bg_id)
	for key in bonuses:
		current_bonuses.background[key] = bonuses[key]

	_apply_bonuses(current_bonuses.background)

func _apply_class_bonuses(class_id: int) -> void:
	if not current_character:
		return
	_remove_bonuses(current_bonuses["class"])
	current_bonuses["class"].clear()

	# Five Parsecs class stat bonuses (pp.26-27)
	# Loaded from character_creation_bonuses.json
	var bonuses: Dictionary = _lookup_bonuses("class_bonuses", class_id)
	for key in bonuses:
		current_bonuses["class"][key] = bonuses[key]

	_apply_bonuses(current_bonuses["class"])

func _apply_motivation_bonuses(motivation_id: int) -> void:
	if not current_character:
		return
	_remove_bonuses(current_bonuses.motivation)
	current_bonuses.motivation.clear()

	# Motivations give narrative effects; a few grant direct stat bonuses (Core Rules p.26).
	# Resource-based bonuses (credits, story points, XP) are applied at campaign
	# level in CampaignFinalizationService, not here.
	# Loaded from character_creation_bonuses.json
	var bonuses: Dictionary = _lookup_bonuses("motivation_bonuses", motivation_id)
	for key in bonuses:
		current_bonuses.motivation[key] = bonuses[key]

	_apply_bonuses(current_bonuses.motivation)

func _validate_character() -> bool:
	if not current_character:
		return false

	var char_name = _get_character_property(current_character, "character_name", "")
	var is_valid = char_name.length() > 0

	return is_valid

func _on_confirm_pressed() -> void:
	if _validate_character():
		if _is_editing:
			character_edited.emit(current_character)
		else:
			character_created.emit(current_character)
		hide()

func _on_cancel_pressed() -> void:
	creation_cancelled.emit()
	hide()

func _on_randomize_pressed() -> void:
	if not current_character:
		return

	# Generate random character data using curated rulebook arrays
	# Prefer Compendium name generation (DLC) if available, else use base tables
	var rand_name: String = ""
	var CompendiumWorldOptions = load("res://src/data/compendium_world_options.gd")
	if CompendiumWorldOptions:
		rand_name = CompendiumWorldOptions.generate_name("")
	if rand_name.is_empty():
		rand_name = FiveParsecsCharacterTableRoller.generate_random_name()
	_set_character_property(current_character, "character_name", rand_name)

	# Origin: flat random from all available species (including Strange Characters)
	var origin_idx: int = randi() % _origin_species_ids.size()
	# Skip separator entries (empty species_id)
	while origin_idx < _origin_species_ids.size() and _origin_species_ids[origin_idx].is_empty():
		origin_idx = randi() % _origin_species_ids.size()
	# Skip disabled items (DLC-locked)
	if origin_idx < origin_options.item_count and origin_options.is_item_disabled(origin_idx):
		origin_idx = randi() % ORIGIN_ITEMS.size()  # fallback to primary
	var species_id: String = (
		_origin_species_ids[origin_idx]
		if origin_idx < _origin_species_ids.size() else "")
	var origin_enum: int = (
		origin_options.get_item_id(origin_idx)
		if origin_idx < origin_options.item_count else 1)

	# Set origin — enum int for primary, display name for Strange
	if origin_enum > 0:
		_set_character_property(
			current_character, "origin", origin_enum)
	else:
		_set_character_property(
			current_character, "origin",
			origin_options.get_item_text(origin_idx))
	_set_character_property(
		current_character, "species_id", species_id)
	var sp_rules: Array = SpeciesDataService.get_special_rules(
		species_id)
	if current_character.has_method("set"):
		current_character.set(
			"special_rules", sp_rules.duplicate())

	# Check Strange Character creation constraints
	var can_roll: bool = SpeciesDataService.can_roll_creation_tables(
		species_id)

	# Background: D100 weighted roll (Core Rules pp.24-25)
	var bg_entry = BACKGROUND_ITEMS[randi() % BACKGROUND_ITEMS.size()]
	if can_roll:
		# Check forced background first
		var forced_bg: String = SpeciesDataService.get_forced_background(
			species_id)
		if not forced_bg.is_empty():
			var bg_display: String = forced_bg.replace(
				"_", " ").capitalize()
			var fb_idx := _find_item_index_by_name(
				BACKGROUND_ITEMS, bg_display)
			if fb_idx >= 0:
				bg_entry = BACKGROUND_ITEMS[fb_idx]
		elif not _background_d100.is_empty():
			var bg_name: String = _roll_d100_table(_background_d100)
			if not bg_name.is_empty():
				var idx: int = _find_item_index_by_name(
					BACKGROUND_ITEMS, bg_name)
				if idx >= 0:
					bg_entry = BACKGROUND_ITEMS[idx]
	if can_roll:
		_set_character_property(
			current_character, "background", bg_entry[1])

	# Class: D100 weighted roll (Core Rules pp.26-27)
	var class_entry = CLASS_ITEMS[randi() % CLASS_ITEMS.size()]
	if can_roll:
		if not _class_d100.is_empty():
			var cls_name: String = _roll_d100_table(_class_d100)
			if not cls_name.is_empty():
				var idx: int = _find_item_index_by_name(
					CLASS_ITEMS, cls_name)
				if idx >= 0:
					class_entry = CLASS_ITEMS[idx]
		# Hulker: Technician/Scientist/Hacker → Primitive (Core Rules p.21)
		if species_id == "hulker":
			var cls_name_str: String = class_entry[0]
			if cls_name_str in [
				"Technician", "Scientist", "Hacker"]:
				class_entry = ["Primitive", 15]
		_set_character_property(
			current_character, "character_class", class_entry[1])

	# Motivation: D100 weighted roll (Core Rules p.26)
	var mot_entry = MOTIVATION_ITEMS[randi() % MOTIVATION_ITEMS.size()]
	if can_roll:
		# Check forced motivation first
		var forced_mot: String = SpeciesDataService.get_forced_motivation(
			species_id)
		if not forced_mot.is_empty():
			var fm_idx := _find_item_index_by_name(
				MOTIVATION_ITEMS, forced_mot.capitalize())
			if fm_idx >= 0:
				mot_entry = MOTIVATION_ITEMS[fm_idx]
		elif not _motivation_d100.is_empty():
			var mot_name: String = _roll_d100_table(
				_motivation_d100)
			if not mot_name.is_empty():
				var idx: int = _find_item_index_by_name(
					MOTIVATION_ITEMS, mot_name)
				if idx >= 0:
					mot_entry = MOTIVATION_ITEMS[idx]
		_set_character_property(
			current_character, "motivation", mot_entry[1])

	# Apply all bonuses (origin, background, class, motivation)
	if origin_enum > 0:
		_apply_origin_bonuses(origin_enum)
	else:
		_apply_strange_character_stats(species_id)
	if can_roll:
		_apply_background_bonuses(bg_entry[1])
		_apply_class_bonuses(class_entry[1])
		_apply_motivation_bonuses(mot_entry[1])

	# Roll and store creation bonuses (Core Rules pp.23-28)
	_roll_and_store_creation_bonuses(current_character)

	_validate_character()
	if is_inside_tree() and not Engine.is_editor_hint():
		_sync_ui_from_character()
		_update_preview()

## UI Handler Methods

func _on_name_changed(text: String) -> void:
	_set_character_property(current_character, "character_name", text)
	var is_valid = _validate_character()
	if confirm_btn:
		confirm_btn.disabled = not is_valid
	_update_preview()

func _on_origin_changed(index: int) -> void:
	var enum_value: int = origin_options.get_item_id(index)
	var species_id: String = (
		_origin_species_ids[index]
		if index < _origin_species_ids.size() else "")

	# Standard species (positive enum ID) vs Strange Character (negative)
	if enum_value > 0:
		_set_character_property(
			current_character, "origin", enum_value)
		_apply_origin_bonuses(enum_value)
	else:
		# Strange Character — store display name as origin string
		var species_name: String = origin_options.get_item_text(index)
		_set_character_property(
			current_character, "origin", species_name)
		# Apply stat modifiers from JSON
		_apply_strange_character_stats(species_id)

	# Set species_id and special_rules on character
	if current_character:
		_set_character_property(
			current_character, "species_id", species_id)
		var rules: Array = SpeciesDataService.get_special_rules(
			species_id)
		if current_character.has_method("set"):
			current_character.set(
				"special_rules", rules.duplicate())

	_enforce_species_constraints(species_id)
	_update_preview()

func _on_background_changed(index: int) -> void:
	var enum_value: int = background_options.get_item_id(index)
	_set_character_property(current_character, "background", enum_value)
	_apply_background_bonuses(enum_value)
	_update_preview()

func _on_class_changed(index: int) -> void:
	var enum_value: int = class_options.get_item_id(index)
	_set_character_property(current_character, "character_class", enum_value)
	_apply_class_bonuses(enum_value)
	_update_preview()

func _on_motivation_changed(index: int) -> void:
	var enum_value: int = motivation_options.get_item_id(index)
	_set_character_property(current_character, "motivation", enum_value)
	_apply_motivation_bonuses(enum_value)
	_update_preview()

func _on_clear_pressed() -> void:
	clear()
	if is_inside_tree() and not Engine.is_editor_hint():
		_sync_ui_from_character()
		_update_preview()

func _on_preview_meta_clicked(meta) -> void:
	if str(meta) == "select_portrait" and portrait_dialog:
		portrait_dialog.popup_centered()

## UI Sync Methods

func _update_mode_ui() -> void:
	if not confirm_btn:
		return
	match creator_mode:
		CreatorMode.CAPTAIN:
			confirm_btn.text = "Create Captain"
		CreatorMode.INITIAL_CREW:
			confirm_btn.text = "Confirm"
		_:
			confirm_btn.text = "Add to Crew"

func _sync_ui_from_character() -> void:
	if not current_character or not is_inside_tree():
		return
	if name_input:
		name_input.text = _get_character_property(
			current_character, "character_name", "")
	if origin_options:
		var origin_val: int = _get_character_property(
			current_character, "origin", 0)
		origin_options.select(
			_find_item_by_id(origin_options, origin_val))
	if background_options:
		var bg_val: int = _get_character_property(
			current_character, "background", 0)
		background_options.select(
			_find_item_by_id(background_options, bg_val))
	if class_options:
		var cls_val: int = _get_character_property(
			current_character, "character_class", 0)
		class_options.select(
			_find_item_by_id(class_options, cls_val))
	if motivation_options:
		var mot_val: int = _get_character_property(
			current_character, "motivation", 0)
		motivation_options.select(
			_find_item_by_id(motivation_options, mot_val))
	if confirm_btn:
		confirm_btn.disabled = not _validate_character()

func _find_item_by_id(btn: OptionButton, id: int) -> int:
	for i in range(btn.item_count):
		if btn.get_item_id(i) == id:
			return i
	return 0

func _get_portrait_size() -> int:
	var vp = get_viewport()
	if not vp:
		return 100
	var w: float = vp.get_visible_rect().size.x
	if w < 600:
		return 64
	elif w < 1200:
		return 80
	return 100

func _update_preview() -> void:
	if not preview_info or not current_character:
		return

	var char_name: String = _get_character_property(
		current_character, "character_name", "")
	var origin_val = _get_character_property(
		current_character, "origin", 0)
	var bg_val = _get_character_property(
		current_character, "background", 0)
	var cls_val = _get_character_property(
		current_character, "character_class", 0)
	var mot_val = _get_character_property(
		current_character, "motivation", 0)

	# Handle both int (primary species) and String (Strange Characters)
	var origin_name: String = (
		str(origin_val).capitalize()
		if origin_val is String
		else _safe_enum_name(GlobalEnums.Origin, origin_val))
	var bg_name: String = (
		str(bg_val).capitalize()
		if bg_val is String
		else _safe_enum_name(GlobalEnums.Background, bg_val))
	var cls_name: String = (
		str(cls_val).capitalize()
		if cls_val is String
		else _safe_enum_name(
			GlobalEnums.CharacterClass, cls_val))
	var mot_name: String = (
		str(mot_val).capitalize()
		if mot_val is String
		else _safe_enum_name(
			GlobalEnums.Motivation, mot_val))

	var portrait_path: String = _get_character_property(
		current_character, "portrait_path", "")
	if portrait_path.is_empty():
		portrait_path = "res://assets/portraits/portrait_01.jpg"

	var portrait_size: int = _get_portrait_size()
	var bbcode := "[center][bgcolor=black][img=%dx%d]%s[/img][/bgcolor]\n" % [
		portrait_size, portrait_size, portrait_path]
	bbcode += "[url=select_portrait]Select Portrait[/url][/center]\n\n"
	bbcode += "[color=lime]Name:[/color] %s\n\n" % char_name
	bbcode += "[color=lime]Origin:[/color] %s\n\n" % origin_name
	bbcode += "[color=lime]Background:[/color] %s\n\n" % bg_name
	bbcode += "[color=lime]Class:[/color] %s\n\n" % cls_name
	bbcode += "[color=lime]Motivation:[/color] %s\n\n" % mot_name
	bbcode += "[color=lime]Stats:[/color]\n"
	bbcode += "[color=yellow]Reactions:[/color] %d\n" % current_character.reaction
	bbcode += "[color=yellow]Speed:[/color] %d\"\n" % current_character.speed
	bbcode += "[color=yellow]Combat Skill:[/color] +%d\n" % current_character.combat
	bbcode += "[color=yellow]Toughness:[/color] %d\n" % current_character.toughness
	bbcode += "[color=yellow]Savvy:[/color] +%d\n" % current_character.savvy
	bbcode += "[color=yellow]Luck:[/color] %d\n" % current_character.luck

	# Species rules for Strange Characters (Core Rules pp.19-22)
	var sp_rules: Array = _get_character_property(
		current_character, "special_rules", [])
	if sp_rules is Array and not sp_rules.is_empty():
		bbcode += "\n[color=#D97706]Species Rules:[/color]\n"
		for rule in sp_rules:
			bbcode += "[color=#808080]• %s[/color]\n" % str(rule)

	preview_info.text = bbcode

func _safe_enum_name(enum_dict: Dictionary, value: int) -> String:
	for key in enum_dict:
		if enum_dict[key] == value:
			return key.capitalize()
	return "Unknown"
