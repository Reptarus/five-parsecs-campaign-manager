@tool
extends Control

signal character_created(character)
signal character_edited(character)
signal creation_cancelled

const FiveParsecsCharacter = preload("res://src/core/character/Base/Character.gd")
const FiveParsecsCharacterStats = preload("res://src/core/character/Base/CharacterStats.gd")
const FiveParsecsCharacterTableRoller = preload("res://src/core/character/Generation/CharacterTableRoller.gd")
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

func _init() -> void:
	current_character = FiveParsecsCharacter.new()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
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
	# Disable locked DLC species entries in dropdown
	for i in range(origin_options.item_count):
		var item_text: String = origin_options.get_item_text(i)
		for species_name in locked_species:
			if species_name in item_text and "Required" in item_text:
				origin_options.set_item_disabled(i, true)
				var dlc_name: String = "Fixer's Guidebook DLC" if species_name == "Prison Planet" else "Trailblazer's Toolkit DLC"
				origin_options.set_item_tooltip(i, "Requires " + dlc_name)
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
	# Bonuses are relative to Human baseline: R1/S4/CS+0/T3/Sa+0
	match origin_id:
		GlobalEnums.Origin.BOT:
			# Bot: R2/S4/CS+1/T4/Sa+2 (p.15)
			current_bonuses.origin["REACTIONS"] = 1
			current_bonuses.origin["COMBAT_SKILL"] = 1
			current_bonuses.origin["TOUGHNESS"] = 1
			current_bonuses.origin["SAVVY"] = 2
		GlobalEnums.Origin.ENGINEER:
			# Engineer: R1/S4/CS+0/T2/Sa+1 (p.16)
			current_bonuses.origin["TOUGHNESS"] = -1
			current_bonuses.origin["SAVVY"] = 1
		GlobalEnums.Origin.KERIN:
			# K'Erin: R1/S4/CS+0/T4/Sa+0 (p.16)
			current_bonuses.origin["TOUGHNESS"] = 1
		GlobalEnums.Origin.SOULLESS:
			# Soulless: R1/S4/CS+0/T4/Sa+1 (p.17)
			current_bonuses.origin["TOUGHNESS"] = 1
			current_bonuses.origin["SAVVY"] = 1
		GlobalEnums.Origin.PRECURSOR:
			# Precursor: R1/S5/CS+0/T2/Sa+0 (p.17)
			# Precursor characters begin with one randomly determined Psionic Power (p.17)
			current_bonuses.origin["SPEED"] = 1
			current_bonuses.origin["TOUGHNESS"] = -1
			_grant_random_psionic_power()
		GlobalEnums.Origin.FERAL:
			# Feral: R1/S4/CS+0/T3/Sa+0 (p.18) — same as Human
			pass
		GlobalEnums.Origin.SWIFT:
			# Swift: R1/S5/CS+0/T3/Sa+0 (p.18)
			current_bonuses.origin["SPEED"] = 1
		GlobalEnums.Origin.KRAG:
			current_bonuses.origin["TOUGHNESS"] = 1
			current_bonuses.origin["SAVVY"] = -1
		GlobalEnums.Origin.SKULKER:
			current_bonuses.origin["SPEED"] = 1
			current_bonuses.origin["TOUGHNESS"] = -1
		GlobalEnums.Origin.PRISON_PLANET:
			current_bonuses.origin["TOUGHNESS"] = 1
			current_bonuses.origin["COMBAT"] = 1
		# HUMAN: no stat bonuses (R1/S4/CS+0/T3/Sa+0)

	_apply_bonuses(current_bonuses.origin)


func _grant_random_psionic_power() -> void:
	## Grant a random psionic power to the current character (Precursor origin, Core Rules p.17)
	if not current_character:
		return
	var psionic_data: Dictionary = _load_psionic_powers()
	if psionic_data.is_empty():
		return
	var power_ids: Array = psionic_data.keys()
	var chosen_id: String = power_ids[randi() % power_ids.size()]
	current_character.psionic_power = chosen_id


func _load_psionic_powers() -> Dictionary:
	var path := "res://data/psionic_powers.json"
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}


func _apply_background_bonuses(bg_id: int) -> void:
	if not current_character:
		return
	_remove_bonuses(current_bonuses.background)
	current_bonuses.background.clear()

	# Five Parsecs background stat bonuses (pp.24-25)
	match bg_id:
		GlobalEnums.Background.PEACEFUL_HIGH_TECH_COLONY:
			current_bonuses.background["SAVVY"] = 1
		GlobalEnums.Background.GIANT_OVERCROWDED_CITY:
			current_bonuses.background["SPEED"] = 1
		GlobalEnums.Background.MINING_COLONY:
			current_bonuses.background["TOUGHNESS"] = 1
		GlobalEnums.Background.MILITARY_BRAT:
			current_bonuses.background["COMBAT_SKILL"] = 1
		GlobalEnums.Background.MILITARY_OUTPOST:
			current_bonuses.background["REACTIONS"] = 1
		GlobalEnums.Background.FRONTIER_GANG:
			current_bonuses.background["COMBAT_SKILL"] = 1
		GlobalEnums.Background.WAR_TORN_HELLHOLE:
			current_bonuses.background["REACTIONS"] = 1
		GlobalEnums.Background.TECH_GUILD:
			current_bonuses.background["SAVVY"] = 1
		GlobalEnums.Background.LONG_TERM_SPACE_MISSION:
			current_bonuses.background["SAVVY"] = 1
		GlobalEnums.Background.RESEARCH_OUTPOST:
			current_bonuses.background["SAVVY"] = 1
		GlobalEnums.Background.PRIMITIVE_WORLD:
			current_bonuses.background["TOUGHNESS"] = 1
		GlobalEnums.Background.WASTELAND_NOMADS:
			current_bonuses.background["REACTIONS"] = 1
		# LOW_TECH_COLONY, SPACE_STATION, DRIFTER,
		# LOWER_MEGACITY_CLASS, WEALTHY_MERCHANT_FAMILY,
		# RELIGIOUS_CULT, SUBJUGATED_COLONY,
		# ORPHAN_UTILITY_PROGRAM, ISOLATIONIST_ENCLAVE,
		# COMFORTABLE_MEGACITY, INDUSTRIAL_WORLD,
		# BUREAUCRAT, ALIEN_CULTURE: no stat bonuses

	_apply_bonuses(current_bonuses.background)

func _apply_class_bonuses(class_id: int) -> void:
	if not current_character:
		return
	_remove_bonuses(current_bonuses["class"])
	current_bonuses["class"].clear()

	# Five Parsecs class stat bonuses (pp.26-27)
	match class_id:
		GlobalEnums.CharacterClass.WORKING_CLASS:
			current_bonuses["class"]["SAVVY"] = 1
			current_bonuses["class"]["LUCK"] = 1
		GlobalEnums.CharacterClass.TECHNICIAN:
			current_bonuses["class"]["SAVVY"] = 1
		GlobalEnums.CharacterClass.SCIENTIST:
			current_bonuses["class"]["SAVVY"] = 1
		GlobalEnums.CharacterClass.HACKER:
			current_bonuses["class"]["SAVVY"] = 1
		GlobalEnums.CharacterClass.SOLDIER:
			current_bonuses["class"]["COMBAT_SKILL"] = 1
		GlobalEnums.CharacterClass.MERCENARY:
			current_bonuses["class"]["COMBAT_SKILL"] = 1
		GlobalEnums.CharacterClass.PRIMITIVE:
			current_bonuses["class"]["SPEED"] = 1
		GlobalEnums.CharacterClass.STARSHIP_CREW:
			current_bonuses["class"]["SAVVY"] = 1
		GlobalEnums.CharacterClass.PETTY_CRIMINAL:
			current_bonuses["class"]["SPEED"] = 1
		GlobalEnums.CharacterClass.GANGER:
			current_bonuses["class"]["REACTIONS"] = 1
		GlobalEnums.CharacterClass.SCOUNDREL:
			current_bonuses["class"]["SPEED"] = 1
		GlobalEnums.CharacterClass.ENFORCER:
			current_bonuses["class"]["COMBAT_SKILL"] = 1
		GlobalEnums.CharacterClass.SPECIAL_AGENT:
			current_bonuses["class"]["REACTIONS"] = 1
		GlobalEnums.CharacterClass.TROUBLESHOOTER:
			current_bonuses["class"]["REACTIONS"] = 1
		GlobalEnums.CharacterClass.BOUNTY_HUNTER:
			current_bonuses["class"]["SPEED"] = 1
		# AGITATOR, ARTIST, NEGOTIATOR, TRADER,
		# NOMAD, EXPLORER, PUNK, SCAVENGER: no stat bonuses

	_apply_bonuses(current_bonuses["class"])

func _apply_motivation_bonuses(motivation_id: int) -> void:
	if not current_character:
		return
	_remove_bonuses(current_bonuses.motivation)
	current_bonuses.motivation.clear()

	# Motivations give narrative effects; a few grant direct stat bonuses.
	# Resource-based bonuses (credits, story points) are applied at campaign
	# level in CampaignFinalizationService, not here.
	# Five Parsecs motivation stat bonuses (Core Rules p.26)
	match motivation_id:
		GlobalEnums.Motivation.GLORY:
			current_bonuses.motivation["COMBAT_SKILL"] = 1
		GlobalEnums.Motivation.SURVIVAL:
			current_bonuses.motivation["TOUGHNESS"] = 1
		GlobalEnums.Motivation.ESCAPE:
			current_bonuses.motivation["SPEED"] = 1
		GlobalEnums.Motivation.TECHNOLOGY:
			current_bonuses.motivation["SAVVY"] = 1
		GlobalEnums.Motivation.DISCOVERY:
			current_bonuses.motivation["SAVVY"] = 1
		# WEALTH: +1D6 credits applied in CampaignFinalizationService
		# FAME: +1 story point applied in CampaignFinalizationService
		# REVENGE/POWER/FREEDOM: +2 XP applied in CampaignFinalizationService

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

	var origin_entry = ORIGIN_ITEMS[randi() % ORIGIN_ITEMS.size()]
	_set_character_property(current_character, "origin", origin_entry[1])

	var class_entry = CLASS_ITEMS[randi() % CLASS_ITEMS.size()]
	_set_character_property(current_character, "character_class", class_entry[1])

	var bg_entry = BACKGROUND_ITEMS[randi() % BACKGROUND_ITEMS.size()]
	_set_character_property(current_character, "background", bg_entry[1])

	var mot_entry = MOTIVATION_ITEMS[randi() % MOTIVATION_ITEMS.size()]
	_set_character_property(current_character, "motivation", mot_entry[1])

	# Apply all bonuses (origin, background, class, motivation)
	_apply_origin_bonuses(origin_entry[1])
	_apply_background_bonuses(bg_entry[1])
	_apply_class_bonuses(class_entry[1])
	_apply_motivation_bonuses(mot_entry[1])

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
	_set_character_property(current_character, "origin", enum_value)
	_apply_origin_bonuses(enum_value)
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

	var char_name: String = _get_character_property(current_character, "character_name", "")
	var origin_idx: int = _get_character_property(current_character, "origin", 0)
	var bg_idx: int = _get_character_property(current_character, "background", 0)
	var cls_idx: int = _get_character_property(current_character, "character_class", 0)
	var mot_idx: int = _get_character_property(current_character, "motivation", 0)

	var origin_name: String = _safe_enum_name(GlobalEnums.Origin, origin_idx)
	var bg_name: String = _safe_enum_name(GlobalEnums.Background, bg_idx)
	var cls_name: String = _safe_enum_name(GlobalEnums.CharacterClass, cls_idx)
	var mot_name: String = _safe_enum_name(GlobalEnums.Motivation, mot_idx)

	var portrait_path: String = _get_character_property(
		current_character, "portrait_path", "")
	if portrait_path.is_empty():
		portrait_path = "res://assets/BookImages/portrait_02.png"

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

	preview_info.text = bbcode

func _safe_enum_name(enum_dict: Dictionary, value: int) -> String:
	for key in enum_dict:
		if enum_dict[key] == value:
			return key.capitalize()
	return "Unknown"
