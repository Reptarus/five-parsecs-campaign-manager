class_name TacticsCampaignCore
extends Resource

## TacticsCampaignCore - Tactics Campaign Core Resource
## Stores complete Tactics campaign data for save/load operations.
## Follows the same to_dictionary/from_dictionary/save_to_file/load_from_file
## pattern as BugHuntCampaignCore, with Tactics-specific data model:
## - Points-based army roster (500/750/1000 pts)
## - Operational campaign map (regions, zones, Cohesion, Army Strength)
## - Campaign Points (CP) for unit upgrades
## - 8-step operational turns
## - Squad-based units with veteran skills
## Source: Five Parsecs: Tactics rulebook pp.81-88, 155-168

@export var schema_version: int = 1
@export var campaign_name: String = ""
@export var campaign_id: String = ""
@export var campaign_type: String = "tactics"

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

func record_battle(result: Dictionary) -> void:
	battle_history.append(result.duplicate(true))
	# Award CP per Tactics rules (p.160)
	var cp: int = 1  # CP per battle fought
	if result.get("won", false):
		cp += 1  # +1 for victory
	if result.get("secondary_completed", false):
		cp += 1  # +1 for secondary objective
	earn_cp(cp)
	_update_modified_time()


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
		errors.append("Campaign name is required")
	if species_id.is_empty():
		errors.append("Species must be selected")
	if roster_entries.is_empty():
		errors.append("Roster must have at least one unit")
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
	campaign_units = data.get("campaign_units", []).duplicate(true)

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


## ============================================================================
## FILE I/O
## ============================================================================

func save_to_file(path: String) -> Error:
	_update_modified_time()
	var data := to_dictionary()

	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var error := FileAccess.get_open_error()
		push_error("TacticsCampaignCore: Failed to save: %s (error: %d)" % [path, error])
		return error

	file.store_string(json_string)
	file.close()
	return OK


static func load_from_file(path: String) -> TacticsCampaignCore:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		return null

	var _Self = load("res://src/game/campaign/TacticsCampaignCore.gd")
	var campaign = _Self.new()
	campaign.from_dictionary(json.data)
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
