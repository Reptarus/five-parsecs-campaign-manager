class_name TacticsCampaignCore
extends Resource

## Atomic save writer. All four cores share ONE implementation so the write path
## cannot drift between gamemodes again - see src/core/state/SaveFileWriter.gd.
const SaveFileWriterRef = preload("res://src/core/state/SaveFileWriter.gd")

## TacticsCampaignCore - Tactics Campaign Core Resource
## Stores complete Tactics campaign data for save/load operations.
## Follows the same to_dictionary/from_dictionary/save_to_file/load_from_file
## pattern as BugHuntCampaignCore, with Tactics-specific data model:
## - Points-based army roster (500/750/1000 pts)
## - Operational campaign map (regions, zones, Cohesion, Army Strength)
## - Campaign Points (CP) for unit upgrades
## - 8-step operational turns
## - Squad-based units with veteran skills
## Source: Five Parsecs: Tactics **pp.101-107** — the Campaign Play chapter
## (campaign structure, Campaign Points at pp.106-107).
## ⚠ CITE CORRECTED 2026-09-04 from "pp.81-88, 155-168". pp.81-88 is the **Scenario
## Types** chapter (objectives + D100 tables) and pp.155-168 is the **Lifeforms
## bestiary** — neither describes campaign state. The operational layer this core
## stores in `operational_map` is pp.92-100.

@export var schema_version: int = 1
@export var campaign_name: String = ""
@export var campaign_id: String = ""
@export var campaign_type: String = "tactics"

## QoL data captured during from_dictionary, applied to autoloads later.
## See apply_pending_qol_data() — called by GameState after the campaign is
## set as current. Mirrors FiveParsecsCampaignCore's pattern.
var _pending_qol_data: Dictionary = {}

## Army identity
@export var army_name: String = ""
@export var species_id: String = ""  # Which species book (e.g., "human_colonists")

## Points limit for army building
@export var points_limit: int = 500

## Organization type (platoon or company)
@export var org_type: String = "platoon"  # "platoon" or "company"
@export var platoon_count: int = 1

## Campaign state
@export var created_at: String = ""
@export var last_modified: String = ""
@export var version: String = "1.0"
@export var game_phase: String = "creation"  # "creation", "active", "completed"
@export var campaign_turn: int = 0
@export var operational_turn: int = 0

## Play mode
@export var play_mode: String = "solo"  # "solo", "gm", "versus"

## Campaign economy — Campaign Points
@export var campaign_points_earned: int = 0
@export var campaign_points_spent: int = 0

## Roster (Array of Dictionaries from TacticsRosterEntry.to_dict())
var roster_entries: Array = []

## Campaign units (Array of Dictionaries from TacticsCampaignUnit.to_dict())
## Persists between battles — tracks CP, veteran skills, casualties
var campaign_units: Array = []

## Named veteran characters imported from other modes (Tactics pp.184-185:
## "an old and well-known character show up on the battlefield as an officer or
## hero"). These are INDIVIDUAL figures attached to the force, NOT squad units —
## deliberately kept OUT of campaign_units[] so they never enter the points-cost /
## org-slot validation (the book uses "no points cost formula" for transfers, p.184).
var veteran_characters: Array = []

## Operational map state (Dictionary from TacticsOperationalMap.to_dict())
var operational_map: Dictionary = {}

## Battle history (Array of {turn, scenario, result, cp_earned, casualties})
var battle_history: Array = []

## Veteran skills acquired (Dictionary: unit_id -> Array[skill_dict])
var veteran_skills: Dictionary = {}

## Story events encountered (Array of {turn, event_id, description, effects})
var story_events: Array = []

## Current battle data (populated during battle phase)
var current_battle: Dictionary = {}

## DLC flags snapshot (for save integrity)
var dlc_flags: Dictionary = {}

## Mixed army: secondary species (empty = single species)
@export var secondary_species_id: String = ""


func _init() -> void:
	created_at = Time.get_datetime_string_from_system()
	last_modified = created_at


func get_campaign_id() -> String:
	if campaign_id.is_empty() and not campaign_name.is_empty():
		var ts := str(int(Time.get_unix_time_from_system()))
		campaign_id = campaign_name.to_lower().replace(" ", "_") + "_tac_" + ts
	elif campaign_id.is_empty():
		campaign_id = "tactics_" + str(int(Time.get_unix_time_from_system()))
	return campaign_id


## ============================================================================
## DATA INITIALIZATION (used during campaign creation)
## ============================================================================

func set_config(data: Dictionary) -> void:
	if data.has("campaign_name"):
		campaign_name = data.campaign_name
	elif data.has("name"):
		campaign_name = data.name
	if data.has("army_name"):
		army_name = data.army_name
	if data.has("species_id"):
		species_id = data.species_id
	if data.has("secondary_species_id"):
		secondary_species_id = data.secondary_species_id
	if data.has("points_limit"):
		points_limit = data.points_limit
	if data.has("org_type"):
		org_type = data.org_type
	if data.has("platoon_count"):
		platoon_count = data.platoon_count
	if data.has("play_mode"):
		play_mode = data.play_mode
	_update_modified_time()


func initialize_roster(entries: Array) -> void:
	roster_entries = entries.duplicate(true)
	_update_modified_time()


func initialize_campaign_units(units: Array) -> void:
	campaign_units = units.duplicate(true)
	_update_modified_time()


func initialize_operational_map(map_data: Dictionary) -> void:
	operational_map = map_data.duplicate(true)
	_update_modified_time()


## ============================================================================
## CAMPAIGN POINTS
## ============================================================================

## The Campaign Point SPEND catalogue — Tactics **pp.107-108**, prices verbatim.
##
## ⚠ THIS IS THE ONLY PLACE THESE PRICES EXIST. TacticsPostBattlePanel renders its
## explanatory card AND its buttons from this array, so the prose a player reads
## cannot drift from the CP they are charged. Putting a mechanic's numbers in a UI
## literal is exactly how the app came to offer three flat "1 CP" purchases against a
## book that prices ELEVEN distinct ones at 1-4 CP. Measured on deploy #35:
## "Unit Upgrade (1 CP): Acquire a veteran skill" rendered beside p.107's
## **Gain Veteran Skill (4 CP)** — a 4x under-charge on the single most expensive
## upgrade in the chapter.
##
## ⭐ This is the SPEND-side twin of the award bug fixed 2026-09-04. That one replaced
## a fabricated flat "1 CP +1 win +1 objective" with the p.106 3D6-drop-lowest roll;
## the auditor was reading what CP you EARN and never looked at what you PAY.
##
## ⚠ The EFFECTS are deliberately still unwired — see _on_spend_cp() in the panel,
## which explains why an entry with no unit picker would silently match nothing. This
## array fixes what a purchase COSTS, which is a rules value the book states outright.
const CP_PURCHASES: Array = [
	# Unit Upgrades — p.107
	{"id": "veteran_skill", "group": "Unit Upgrades",
		"name": "Gain Veteran Skill", "cost": 4,
		"desc": "A unit receives a veteran skill of choice (p.149 list)."},
	{"id": "retrain_unit", "group": "Unit Upgrades",
		"name": "Retrain Unit", "cost": 2,
		"desc": "A unit with a veteran skill replaces it with another pick."},
	{"id": "hero_trait", "group": "Unit Upgrades",
		"name": "Gain Hero Trait", "cost": 2,
		"desc": "An Individual figure is upgraded to Hero status."},
	# p.108
	{"id": "leader_trait", "group": "Unit Upgrades",
		"name": "Gain Leader Trait", "cost": 4,
		"desc": "An Individual figure is upgraded to Leader status."},
	# Roster Changes — p.108
	{"id": "unit_refit", "group": "Roster Changes",
		"name": "Unit Refit", "cost": 1,
		"desc": "Change a roster unit's listed weapon options."},
	{"id": "unit_customization", "group": "Roster Changes",
		"name": "Unit Customization", "cost": 1,
		"desc": "Add, replace or remove one weapon or option, even if unlisted."},
	{"id": "unit_replacement", "group": "Roster Changes",
		"name": "Unit Replacement", "cost": 1,
		"desc": "Discard a unit and replace it with one of the same general type."},
	{"id": "roster_addition", "group": "Roster Changes",
		"name": "Roster Addition", "cost": 3,
		"desc": "Add a new unit to your roster; it must fit an existing platoon."},
	{"id": "replace_destroyed", "group": "Roster Changes",
		"name": "Replace Destroyed Unit", "cost": 1,
		"desc": "Replace a permanently lost unit; it enters with no veteran skills."},
	# Battle Advantages — p.108
	{"id": "battle_support", "group": "Battle Advantages",
		"name": "Battle Support", "cost": 2,
		"desc": "Use Support (p.65) in one battle of your choosing."},
	{"id": "battle_finesse", "group": "Battle Advantages",
		"name": "Battle Finesse", "cost": 1,
		"desc": "Roll the Clock twice at end of round and pick; once per round."},
	{"id": "battle_luck", "group": "Battle Advantages",
		"name": "Battle Luck", "cost": 1,
		"desc": "Roll two sets of attacks for one figure and choose which applies."},
	{"id": "battle_initiative", "group": "Battle Advantages",
		"name": "Battle Initiative", "cost": 1,
		"desc": "Choose whether to take the first or second phase in round one."},
]


## Look up one catalogue entry by id. Returns {} when the id is unknown, so a caller
## that mistypes gets an empty dict rather than a plausible wrong price.
static func cp_purchase(purchase_id: String) -> Dictionary:
	for entry in CP_PURCHASES:
		if str(entry.get("id", "")) == purchase_id:
			return entry
	return {}


## The book price of one purchase, or 0 for an unknown id. ⚠ 0 is deliberately NOT a
## usable default — callers must treat it as "refuse the sale", never as "free".
static func cp_cost(purchase_id: String) -> int:
	return int(cp_purchase(purchase_id).get("cost", 0))


func get_available_cp() -> int:
	return campaign_points_earned - campaign_points_spent


func earn_cp(amount: int) -> void:
	campaign_points_earned += amount
	_update_modified_time()


func spend_cp(amount: int) -> bool:
	if get_available_cp() < amount:
		return false
	campaign_points_spent += amount
	_update_modified_time()
	return true


## ============================================================================
## BATTLE TRACKING
## ============================================================================

## Award Campaign Points for a completed battle.
##
## Tactics **pp.106-107**, "CAMPAIGN PROGRESSION" (the book's own index lists
## "Campaign Points (CP) 106"), verbatim:
##   "CP are awarded after every campaign game played. Roll three D6s and drop the
##    lowest result. The sum of the two remaining dice is the base number of CP
##    awarded."
##   "If the scenario played uses victory points (see page 73), 1 CP is awarded for
##    every VP earned."
##   "If the scenario did not us[e] victory points, award: 3 additional CP for a
##    victory, 2 additional CP for a draw, and 1 additional CP for a defeat or
##    inconclusive battle where neither side achieved anything."
##   Worked example from the book: "If the roll is a 2, 3, and 5, the base award is
##    8 CP. If I earned 3 VP in the battle, I would receive a total of 11 CP."
##
## ⚠ FIXED 2026-09-04. This used to award a flat 1, +1 for a win, +1 for a
## "secondary objective" — a maximum of 3 CP — cited to "p.160", which is a page in
## the **Lifeforms bestiary**. The book's base roll alone averages ~8.5 before any
## bonus, so a Tactics campaign earned roughly a QUARTER of the progression currency
## the book grants, and "secondary objective" is not a book category at all. CP gates
## every unit upgrade, roster change and battle advantage, so this throttled the
## whole campaign layer.
func record_battle(result: Dictionary) -> void:
	var awarded: int = campaign_points_for(
		result, [randi_range(1, 6), randi_range(1, 6), randi_range(1, 6)])
	# ⚠ STAMP WHAT THE HISTORY VIEW READS. TacticsDashboard._build_battle_history()
	# renders `entry.get("turn", 0)` and `entry.get("cp_earned", 0)`, and the live
	# producer (TacticsTurnController :365/:373) sets ONLY `won` — so every row read
	# "Turn 0 ... CP earned: 0" for the life of the campaign. A consumer read with no
	# producer write is a SILENT DEFAULT, never an error, which is why nothing caught
	# it. Measured on deploy #35: a Turn-1 victory that awarded 12 CP displayed as
	# "Turn 0: Victory — CP earned: 0".
	#
	# This is the right place because record_battle() is the chokepoint that both
	# appends the entry AND computes the award — stamping it at the producer keeps
	# the two from drifting, rather than teaching the view to re-derive them.
	var entry: Dictionary = result.duplicate(true)
	entry["turn"] = campaign_turn
	entry["cp_earned"] = awarded
	battle_history.append(entry)
	earn_cp(awarded)
	_update_modified_time()


## The p.106-107 award as a pure function, so it can be asserted without a battle
## and without touching the RNG.
##
## ⚠ The live producer (TacticsTurnController.gd:365/373) currently sets only
## `won`, so today every battle takes the victory (+3) or defeat (+1) row. The
## `draw` and `victory_points` keys are honoured here so that producer can be
## extended without the rule being rewritten.
static func campaign_points_for(result: Dictionary, dice: Array) -> int:
	var rolled: Array[int] = []
	for v in dice:
		rolled.append(int(v))
	rolled.sort()
	# "Roll three D6s and drop the lowest result" — sum the two highest.
	var base: int = 0
	if rolled.size() >= 3:
		base = rolled[rolled.size() - 1] + rolled[rolled.size() - 2]
	else:
		for v in rolled:
			base += v

	# "If the scenario played uses victory points ... 1 CP for every VP earned."
	# The VP branch REPLACES the victory/draw/defeat ladder, it does not stack.
	if result.has("victory_points"):
		return base + maxi(0, int(result.get("victory_points", 0)))

	if bool(result.get("won", false)):
		return base + 3
	if bool(result.get("draw", false)):
		return base + 2
	return base + 1


func get_battles_played() -> int:
	return battle_history.size()


func get_battles_won() -> int:
	var count: int = 0
	for b in battle_history:
		if b is Dictionary and b.get("won", false):
			count += 1
	return count


## ============================================================================
## CAMPAIGN UNIT ACCESS
## ============================================================================

func get_campaign_unit_by_id(unit_id: String) -> Dictionary:
	for unit in campaign_units:
		if unit is Dictionary and unit.get("unit_id", "") == unit_id:
			return unit
	return {}


func get_active_campaign_units() -> Array:
	var active: Array = []
	for unit in campaign_units:
		if unit is Dictionary and not unit.get("is_destroyed", false):
			active.append(unit)
	return active


## ============================================================================
## VETERAN CHARACTERS (cross-mode imports — Tactics pp.184-185)
## ============================================================================

func add_veteran_character(veteran: Dictionary) -> void:
	## Attach an imported named veteran (a hero / officer figure), NOT a squad unit.
	## Kept out of campaign_units[] so it never affects points validation.
	var v: Dictionary = veteran.duplicate(true)
	# Playability floor (NOT a book value): the book's "1 Kill Point per Luck point"
	# (p.184) yields 0 KP for a 0-Luck character, but a battlefield figure needs at
	# least 1 wound. Kept here, at the veteran layer, so convert_to_tactics() stays
	# book-exact. GAME_BALANCE_ESTIMATE.
	if int(v.get("kill_points", 0)) < 1:
		v["kill_points"] = 1
	veteran_characters.append(v)
	_update_modified_time()


func remove_veteran_character(veteran_id: String) -> bool:
	for i in range(veteran_characters.size()):
		var v = veteran_characters[i]
		if v is Dictionary and str(v.get("id", v.get("character_id", ""))) == veteran_id:
			veteran_characters.remove_at(i)
			_update_modified_time()
			return true
	return false


func get_veteran_characters() -> Array:
	return veteran_characters


## ============================================================================
## VALIDATION
## ============================================================================

func validate() -> bool:
	if campaign_name.is_empty():
		return false
	if species_id.is_empty():
		return false
	if roster_entries.is_empty():
		return false
	return true


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if campaign_name.is_empty():
		errors.append("Pick a name for your campaign. Anything memorable works.")
	if species_id.is_empty():
		errors.append("Pick a species for your army to continue.")
	if roster_entries.is_empty():
		errors.append("Your roster is empty. Add at least one unit to continue.")
	return errors


## ============================================================================
## CAMPAIGN SUMMARY
## ============================================================================

func get_campaign_summary() -> Dictionary:
	return {
		"name": campaign_name,
		"type": "tactics",
		"army_name": army_name,
		"species": species_id,
		"points_limit": points_limit,
		"org_type": org_type,
		"play_mode": play_mode,
		"campaign_turn": campaign_turn,
		"operational_turn": operational_turn,
		"battles_played": get_battles_played(),
		"battles_won": get_battles_won(),
		"cp_available": get_available_cp(),
		"units_active": get_active_campaign_units().size(),
		"created": created_at,
		"status": game_phase,
	}


func start_campaign() -> void:
	game_phase = "active"
	_update_modified_time()


func advance_turn() -> void:
	campaign_turn += 1
	_update_modified_time()


func advance_operational_turn() -> void:
	operational_turn += 1
	_update_modified_time()


## ============================================================================
## SERIALIZATION
## ============================================================================

func to_dictionary() -> Dictionary:
	return {
		"campaign_id": get_campaign_id(),
		"campaign_type": "tactics",
		"meta": {
			"campaign_id": get_campaign_id(),
			"campaign_name": campaign_name,
			"campaign_type": "tactics",
			"schema_version": schema_version,
			"created_at": created_at,
			"last_modified": last_modified,
			"version": version,
			"game_phase": game_phase,
		},
		"config": {
			"name": campaign_name,
			"army_name": army_name,
			"species_id": species_id,
			"secondary_species_id": secondary_species_id,
			"points_limit": points_limit,
			"org_type": org_type,
			"platoon_count": platoon_count,
			"play_mode": play_mode,
		},
		"roster": {
			"entries": roster_entries.duplicate(true),
		},
		"campaign_units": campaign_units.duplicate(true),
		"veteran_characters": veteran_characters.duplicate(true),
		"state": {
			"campaign_turn": campaign_turn,
			"operational_turn": operational_turn,
			"campaign_points_earned": campaign_points_earned,
			"campaign_points_spent": campaign_points_spent,
		},
		"operational_map": operational_map.duplicate(true),
		"battle_history": battle_history.duplicate(true),
		"veteran_skills": veteran_skills.duplicate(true),
		"story_events": story_events.duplicate(true),
		"current_battle": current_battle.duplicate(true),
		"dlc_flags": dlc_flags.duplicate(),
		"qol_data": _build_qol_data(),
	}


func from_dictionary(data: Dictionary) -> void:
	# Meta
	if data.has("meta"):
		var meta: Dictionary = data.meta
		campaign_id = meta.get("campaign_id", "")
		campaign_name = meta.get("campaign_name", "")
		schema_version = meta.get("schema_version", 1)
		created_at = meta.get("created_at", "")
		last_modified = meta.get("last_modified", "")
		version = meta.get("version", "1.0")
		game_phase = meta.get("game_phase", "creation")

	if campaign_id.is_empty() and data.has("campaign_id"):
		campaign_id = data.get("campaign_id", "")

	# Config
	if data.has("config"):
		var config: Dictionary = data.config
		if campaign_name.is_empty():
			campaign_name = config.get("name", "")
		army_name = config.get("army_name", "")
		species_id = config.get("species_id", "")
		secondary_species_id = config.get("secondary_species_id", "")
		points_limit = config.get("points_limit", 500)
		org_type = config.get("org_type", "platoon")
		platoon_count = config.get("platoon_count", 1)
		play_mode = config.get("play_mode", "solo")

	# Roster
	if data.has("roster"):
		var roster: Dictionary = data.roster
		roster_entries = roster.get("entries", []).duplicate(true)

	# Campaign units
	# ⚠ NORMALISE ON LOAD. These records round-trip verbatim in both directions
	# (duplicate(true) here and in to_dict()), so a key that reached disk once
	# survives every future save unless something removes it — the same rot that
	# kept `auto_load_last_campaign` alive in settings.cfg for months. normalize()
	# fills missing fields and drops the retired per-unit CP keys (Tactics p.106:
	# CP is a player-or-army pool, never per unit).
	campaign_units = data.get("campaign_units", []).duplicate(true)
	var UnitRecord = load("res://src/data/tactics/TacticsCampaignUnit.gd")
	for cu in campaign_units:
		if cu is Dictionary:
			UnitRecord.normalize(cu)
	veteran_characters = data.get("veteran_characters", []).duplicate(true)

	# State
	if data.has("state"):
		var state: Dictionary = data.state
		campaign_turn = state.get("campaign_turn", 0)
		operational_turn = state.get("operational_turn", 0)
		campaign_points_earned = state.get("campaign_points_earned", 0)
		campaign_points_spent = state.get("campaign_points_spent", 0)

	# Remaining sections
	operational_map = data.get("operational_map", {}).duplicate(true)
	battle_history = data.get("battle_history", []).duplicate(true)
	veteran_skills = data.get("veteran_skills", {}).duplicate(true)
	story_events = data.get("story_events", []).duplicate(true)
	current_battle = data.get("current_battle", {}).duplicate(true)
	dlc_flags = data.get("dlc_flags", {}).duplicate()

	# Capture qol_data for deferred apply (after autoloads are reachable).
	if data.has("qol_data"):
		_pending_qol_data = {"qol_data": data.get("qol_data", {}).duplicate(true)}


## ============================================================================
## QOL DATA (cross-mode journal persistence)
## ============================================================================

func _build_qol_data() -> Dictionary:
	## Collect QoL system data for save. Currently only the CampaignJournal —
	## other 5PFH-specific autoloads are not populated in Tactics mode.
	var qol: Dictionary = {}
	var tree = Engine.get_main_loop() if Engine.get_main_loop() else null
	var root = tree.root if tree else null
	if not root:
		return qol
	var journal = root.get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("save_to_dict"):
		qol["journal"] = journal.save_to_dict()
	return qol


func apply_pending_qol_data() -> void:
	## Called after scene tree is ready (boot auto-load) OR after mid-session
	## load (via GameState.load_campaign). Restores journal entries that the
	## campaign accumulated before save, AND clears any leftover planet state
	## from a previous 5PFH session (Tactics is points-based army play with no
	## per-planet progression).
	var tree = Engine.get_main_loop() if Engine.get_main_loop() else null
	var root = tree.root if tree else null
	if not root:
		return
	# Tactics doesn't use planet state; ALWAYS clear PlanetDataManager so stale
	# 5PFH visited_planets / travel_history can't bleed into this mode via the
	# shared autoload (Opus 4.8 audit B3 — Galaxy Log plan, 2026-06-01).
	var planet_mgr = root.get_node_or_null("/root/PlanetDataManager")
	if planet_mgr and planet_mgr.has_method("deserialize_all"):
		planet_mgr.deserialize_all({})
	if _pending_qol_data.is_empty():
		return
	var journal = root.get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("load_from_save"):
		journal.load_from_save(_pending_qol_data)
	_pending_qol_data = {}


## ============================================================================
## FILE I/O
## ============================================================================

func save_to_file(path: String) -> Error:
	_update_modified_time()
	var data := to_dictionary()

	# Compact, not pretty-printed. Tab indentation cost a MEASURED 24-27% on the
	# real save files, and save_campaign() runs ~8x per campaign turn, so that is
	# a quarter of every write on a phone spent on whitespace. Nothing parses the
	# indentation; to read a save by hand: py -m json.tool <file>
	var json_string := JSON.stringify(data)
	# ATOMIC write — see src/core/state/SaveFileWriter.gd. Opening the live path with
	# FileAccess.WRITE truncates it to 0 bytes immediately, so a kill mid-write
	# destroyed the campaign. Shared with the other three cores so the four write
	# paths cannot drift apart again.
	var write_err: Error = SaveFileWriterRef.write_text_atomic(path, json_string)
	if write_err != OK:
		push_error("TacticsCampaignCore: Failed to save: %s (error: %d)" % [path, write_err])
	return write_err


static func load_from_file(path: String) -> TacticsCampaignCore:
	## Reads through SaveFileWriter so the .bak generation written by save_to_file()
	## is actually consulted when the primary is truncated or unparseable.
	var data := SaveFileWriterRef.read_json_with_fallback(path)
	if data.is_empty():
		return null

	var _Self = load("res://src/game/campaign/TacticsCampaignCore.gd")
	var campaign = _Self.new()
	campaign.from_dictionary(data)
	return campaign


static func create_new_campaign(name: String, species: String, points: int = 500) -> TacticsCampaignCore:
	var _Self = load("res://src/game/campaign/TacticsCampaignCore.gd")
	var campaign = _Self.new()
	campaign.campaign_name = name
	campaign.species_id = species
	campaign.points_limit = points
	return campaign


## ============================================================================
## PRIVATE
## ============================================================================

func _update_modified_time() -> void:
	last_modified = Time.get_datetime_string_from_system()
