class_name PlanetfallCampaignCore
extends Resource

## Planetfall Campaign Core Resource
## Stores complete Planetfall colony campaign data for save/load operations.
## Follows the same to_dictionary/from_dictionary/save_to_file/load_from_file
## pattern as FiveParsecsCampaignCore and BugHuntCampaignCore.
##
## Key differences from other campaign types:
## - Colony management: Integrity, Morale, Buildings, Research, Tech Tree
## - 18-step campaign turn (vs 9 in 5PFH, 3 in Bug Hunt)
## - 3 character classes (Scientist/Scout/Trooper) + Grunts + Bot
## - Central equipment store (characters don't own items)
## - Grid map with sector states (6x6 to 10x10)
## - Procedural lifeform generation + evolution
## - 7 milestones → 4 campaign endings
## - No ship, no patrons/rivals, no credits, no Luck stat

@export var schema_version: int = 1
@export var campaign_name: String = ""
@export var campaign_id: String = ""
@export var campaign_type: String = "planetfall"

## Colony info
@export var colony_name: String = ""
@export var expedition_type: String = ""

## Difficulty
@export var difficulty: String = "normal"

## Campaign state
@export var created_at: String = ""
@export var last_modified: String = ""
@export var version: String = "1.0"
@export var game_phase: String = "creation"  # "creation", "tutorial", "active", "endgame", "completed"
@export var campaign_turn: int = 0

## Colony Statistics (Planetfall p.55, Colony Tracking Sheet p.190)
@export var colony_morale: int = 0
@export var colony_integrity: int = 0
@export var build_points_per_turn: int = 1
@export var research_points_per_turn: int = 1
@export var repair_capacity: int = 1
@export var colony_defenses: int = 0
@export var raw_materials: int = 0
@export var story_points: int = 5
@export var augmentation_points: int = 0

## Grunt count (not individual tracking — Planetfall p.16)
@export var grunts: int = 12

## Milestone progression (7 required for End Game — Planetfall p.156)
@export var milestones_completed: int = 0
@export var calamity_points: int = 0

## Mission Data counter (4 breakthroughs — Planetfall p.169)
@export var mission_data: int = 0
@export var mission_data_breakthroughs: int = 0

## Bot state (1 per campaign — Planetfall p.17)
@export var bot_operational: bool = true

## Character roster (Array of Dictionaries — lightweight, like Bug Hunt)
## Dict keys: id, name, class, subspecies, reactions, speed, combat_skill,
## toughness, savvy, xp, kp, loyalty, motivation, prior_experience,
## notable_event, abilities, is_imported, source_campaign
var roster: Array = []

## Equipment pool — central colony store, NOT per-character (Planetfall p.23)
var equipment_pool: Array = []

## Grunt upgrades unlocked (Array of upgrade IDs — Planetfall p.79)
var grunt_upgrades: Array = []

## Colony map (Dictionary — grid sectors with states)
## Structure: {grid_size: [rows, cols], home_sector: [r, c], sectors: {}}
var map_data: Dictionary = {}

## Research state (Dictionary — theories/applications unlocked)
## Structure: {unlocked_theories: [], unlocked_applications: [], current_research: {}}
var research_data: Dictionary = {}

## Buildings (Dictionary — constructed + in-progress)
## Structure: {constructed: [], in_progress: {building_id: bp_remaining}}
var buildings_data: Dictionary = {}

## Lifeform Encounter Table (10-slot, persists permanently — Planetfall p.146)
## Each slot: Dictionary with generated lifeform profile
var lifeform_table: Array = []

## Lifeform evolutions applied (Array of evolution IDs)
var lifeform_evolutions: Array = []

## Battlefield Condition Table (10-slot, persists — Planetfall p.110)
var condition_table: Array = []

## Tactical Enemies (3 total, appear at milestones 1, 2, 5 — Planetfall p.50)
## Each: {type, profile, enemy_info: int, boss_located: bool, strongpoint_located: bool, defeated: bool, occupied_sectors: []}
var tactical_enemies: Array = []

## Enemy Information per enemy (keyed by enemy index)
var enemy_info: Dictionary = {}

## Ancient Signs discovered (sector coordinates)
var ancient_signs: Array = []

## Active calamities (Array of Dictionaries)
var active_calamities: Array = []

## Tutorial missions completed (Planetfall pp.44-45)
var tutorial_missions: Dictionary = {
	"beacons": false,
	"analysis": false,
	"perimeter": false
}

## Tutorial mission bonuses earned
var tutorial_bonuses: Dictionary = {}

## Sick Bay (character_id → turns_remaining)
var sick_bay: Dictionary = {}

## DLC flags snapshot
var dlc_flags: Dictionary = {}

## Stashed equipment from imported characters (for export back)
var stashed_equipment: Dictionary = {}

## Original character snapshots from import (for lossless export)
var original_character_snapshots: Dictionary = {}


func _init() -> void:
	created_at = Time.get_datetime_string_from_system()
	last_modified = created_at


func get_campaign_id() -> String:
	if campaign_id.is_empty() and not campaign_name.is_empty():
		var ts := str(int(Time.get_unix_time_from_system()))
		campaign_id = campaign_name.to_lower().replace(" ", "_") + "_pf_" + ts
	elif campaign_id.is_empty():
		campaign_id = "planetfall_" + str(int(Time.get_unix_time_from_system()))
	return campaign_id


## ============================================================================
## DATA INITIALIZATION (used during campaign creation)
## ============================================================================

func set_config(data: Dictionary) -> void:
	if data.has("campaign_name"):
		campaign_name = data.campaign_name
	elif data.has("name"):
		campaign_name = data.name
	if data.has("colony_name"):
		colony_name = data.colony_name
	if data.has("expedition_type"):
		expedition_type = data.expedition_type
	if data.has("difficulty"):
		difficulty = data.difficulty
	_update_modified_time()


func initialize_roster(characters: Array) -> void:
	roster = characters.duplicate(true)
	_update_modified_time()


func add_roster_character(char_dict: Dictionary) -> void:
	roster.append(char_dict.duplicate(true))
	_update_modified_time()


func remove_roster_character(character_id: String) -> void:
	for i in range(roster.size() - 1, -1, -1):
		if roster[i].get("id", "") == character_id:
			roster.remove_at(i)
			break
	_update_modified_time()


func get_roster_character_by_id(character_id: String) -> Variant:
	for char_dict in roster:
		if char_dict is Dictionary:
			if char_dict.get("id", "") == character_id:
				return char_dict
	return null


func get_active_roster() -> Array:
	## Returns roster characters not in sick bay or dead
	var active: Array = []
	for char_dict in roster:
		var cid: String = char_dict.get("id", "")
		if not sick_bay.has(cid) or sick_bay[cid] <= 0:
			active.append(char_dict)
	return active


func initialize_map(data: Dictionary) -> void:
	map_data = data.duplicate(true)
	_update_modified_time()


func initialize_equipment_pool(weapons: Array) -> void:
	equipment_pool = weapons.duplicate(true)
	_update_modified_time()


## ============================================================================
## COLONY MANAGEMENT
## ============================================================================

func adjust_morale(amount: int) -> void:
	colony_morale += amount
	_update_modified_time()


func adjust_integrity(amount: int) -> void:
	colony_integrity += amount
	_update_modified_time()


func spend_raw_materials(amount: int) -> bool:
	if raw_materials < amount:
		return false
	raw_materials -= amount
	_update_modified_time()
	return true


func add_raw_materials(amount: int) -> void:
	raw_materials += amount
	_update_modified_time()


func spend_story_point() -> bool:
	if story_points <= 0:
		return false
	story_points -= 1
	_update_modified_time()
	return true


func add_story_points(amount: int) -> void:
	story_points += amount
	_update_modified_time()


## ============================================================================
## SICK BAY
## ============================================================================

func add_to_sick_bay(character_id: String, turns: int) -> void:
	sick_bay[character_id] = turns
	_update_modified_time()


func tick_sick_bay() -> Array[String]:
	var recovered: Array[String] = []
	var to_remove: Array[String] = []
	for cid in sick_bay:
		sick_bay[cid] -= 1
		if sick_bay[cid] <= 0:
			recovered.append(cid)
			to_remove.append(cid)
	for cid in to_remove:
		sick_bay.erase(cid)
	if not recovered.is_empty():
		_update_modified_time()
	return recovered


## ============================================================================
## GRUNT MANAGEMENT
## ============================================================================

func lose_grunt() -> void:
	if grunts > 0:
		grunts -= 1
		_update_modified_time()


func gain_grunts(amount: int) -> void:
	grunts += amount
	_update_modified_time()


## ============================================================================
## MILESTONE & PROGRESSION
## ============================================================================

func add_milestone() -> void:
	milestones_completed += 1
	_update_modified_time()


func is_endgame_eligible() -> bool:
	return milestones_completed >= 7


## ============================================================================
## TURN-STEP HELPERS (used by PlanetfallPhaseManager + panels)
## ============================================================================

func apply_morale_adjustments(casualties: int, colony_damage: int) -> void:
	## Step 11: Automatic morale changes (Planetfall p.68).
	## -1 per turn, -1 per battle casualty, -1 per colony damage this turn.
	var total: int = -1 - casualties - colony_damage
	colony_morale += total
	_update_modified_time()


func check_colony_integrity() -> bool:
	## Step 16: Returns true if integrity failure test is needed (≤ -3).
	## Planetfall p.69, p.87.
	return colony_integrity <= -3


func apply_colony_event(event_data: Dictionary) -> void:
	## Apply the effects of a colony event (Step 5). Planetfall pp.63-64.
	## Panels will call specific mutation methods; this is a convenience stub
	## for events that only need simple stat changes.
	if event_data.has("colony_morale"):
		colony_morale += event_data.get("colony_morale", 0)
	if event_data.has("research_points"):
		var rp: int = event_data.get("research_points", 0)
		if research_data.has("current_rp"):
			research_data["current_rp"] += rp
		else:
			research_data["current_rp"] = rp
	if event_data.has("build_points"):
		var bp: int = event_data.get("build_points", 0)
		if buildings_data.has("current_bp"):
			buildings_data["current_bp"] += bp
		else:
			buildings_data["current_bp"] = bp
	if event_data.has("ancient_signs"):
		for _i in range(event_data.get("ancient_signs", 0)):
			ancient_signs.append({})
	if event_data.has("grunts"):
		grunts += event_data.get("grunts", 0)
	_update_modified_time()


func apply_enemy_activity(activity_data: Dictionary) -> void:
	## Apply enemy activity effects (Step 4). Planetfall p.62.
	## Colony damage from raids is the primary effect.
	if activity_data.has("colony_damage"):
		var dmg: int = activity_data.get("colony_damage", 0)
		colony_integrity -= dmg
	_update_modified_time()


func repair_colony(points: int) -> void:
	## Step 2: Restore colony integrity. Planetfall p.59.
	colony_integrity += points
	_update_modified_time()


## ============================================================================
## RESEARCH & BUILDING STATE (Sprint 2)
## ============================================================================

func get_research_summary() -> Dictionary:
	var rd: Dictionary = research_data
	return {
		"current_rp": rd.get("current_rp", 0),
		"completed_theories": rd.get("completed_theories", []).size(),
		"unlocked_applications": rd.get("unlocked_applications", []).size()
	}


func get_building_summary() -> Dictionary:
	var bd: Dictionary = buildings_data
	return {
		"current_bp": bd.get("current_bp", 0),
		"constructed": bd.get("constructed", []).size(),
		"in_progress": bd.get("in_progress", {}).size()
	}


func get_augmentation_count() -> int:
	return research_data.get("augmentations_owned", []).size()


## ============================================================================
## VALIDATION
## ============================================================================

func validate() -> bool:
	if campaign_name.is_empty():
		return false
	if roster.size() < 3:
		return false
	return true


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if campaign_name.is_empty():
		errors.append("Campaign name is required")
	if roster.size() < 3:
		errors.append("Planetfall requires at least 3 roster characters")
	if roster.size() > 10:
		errors.append("Planetfall allows at most 10 roster characters")
	# Check class minimums
	var class_counts := {"scientist": 0, "scout": 0, "trooper": 0}
	for char_dict in roster:
		var cls: String = char_dict.get("class", "")
		if class_counts.has(cls):
			class_counts[cls] += 1
	for cls in class_counts:
		if class_counts[cls] < 1:
			errors.append("Roster must include at least one %s" % cls)
	return errors


## ============================================================================
## CAMPAIGN SUMMARY
## ============================================================================

func get_campaign_summary() -> Dictionary:
	return {
		"name": campaign_name,
		"type": "planetfall",
		"colony": colony_name,
		"expedition": expedition_type,
		"difficulty": difficulty,
		"roster_size": roster.size(),
		"grunts": grunts,
		"campaign_turn": campaign_turn,
		"milestones": milestones_completed,
		"morale": colony_morale,
		"integrity": colony_integrity,
		"story_points": story_points,
		"created": created_at,
		"status": game_phase
	}


func start_campaign() -> void:
	game_phase = "active"
	_update_modified_time()


func advance_turn() -> void:
	campaign_turn += 1
	_update_modified_time()


## ============================================================================
## SERIALIZATION
## ============================================================================

func to_dictionary() -> Dictionary:
	return {
		"campaign_id": get_campaign_id(),
		"campaign_type": "planetfall",
		"meta": {
			"campaign_id": get_campaign_id(),
			"campaign_name": campaign_name,
			"campaign_type": "planetfall",
			"schema_version": schema_version,
			"created_at": created_at,
			"last_modified": last_modified,
			"version": version,
			"game_phase": game_phase
		},
		"config": {
			"name": campaign_name,
			"colony_name": colony_name,
			"expedition_type": expedition_type,
			"difficulty": difficulty
		},
		"roster": roster.duplicate(true),
		"colony": {
			"colony_morale": colony_morale,
			"colony_integrity": colony_integrity,
			"build_points_per_turn": build_points_per_turn,
			"research_points_per_turn": research_points_per_turn,
			"repair_capacity": repair_capacity,
			"colony_defenses": colony_defenses,
			"raw_materials": raw_materials,
			"story_points": story_points,
			"augmentation_points": augmentation_points,
			"grunts": grunts,
			"bot_operational": bot_operational
		},
		"progression": {
			"campaign_turn": campaign_turn,
			"milestones_completed": milestones_completed,
			"calamity_points": calamity_points,
			"mission_data": mission_data,
			"mission_data_breakthroughs": mission_data_breakthroughs
		},
		"map_data": map_data.duplicate(true),
		"research_data": research_data.duplicate(true),
		"buildings_data": buildings_data.duplicate(true),
		"equipment_pool": equipment_pool.duplicate(true),
		"grunt_upgrades": grunt_upgrades.duplicate(),
		"lifeform_table": lifeform_table.duplicate(true),
		"lifeform_evolutions": lifeform_evolutions.duplicate(),
		"condition_table": condition_table.duplicate(true),
		"tactical_enemies": tactical_enemies.duplicate(true),
		"enemy_info": enemy_info.duplicate(),
		"ancient_signs": ancient_signs.duplicate(true),
		"active_calamities": active_calamities.duplicate(true),
		"tutorial_missions": tutorial_missions.duplicate(),
		"tutorial_bonuses": tutorial_bonuses.duplicate(),
		"sick_bay": sick_bay.duplicate(),
		"dlc_flags": dlc_flags.duplicate(),
		"stashed_equipment": stashed_equipment.duplicate(true),
		"original_character_snapshots": original_character_snapshots.duplicate(true)
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
		colony_name = config.get("colony_name", "")
		expedition_type = config.get("expedition_type", "")
		difficulty = config.get("difficulty", "normal")

	# Roster
	roster = data.get("roster", []).duplicate(true)

	# Colony stats
	if data.has("colony"):
		var colony: Dictionary = data.colony
		colony_morale = colony.get("colony_morale", 0)
		colony_integrity = colony.get("colony_integrity", 0)
		build_points_per_turn = colony.get("build_points_per_turn", 1)
		research_points_per_turn = colony.get("research_points_per_turn", 1)
		repair_capacity = colony.get("repair_capacity", 1)
		colony_defenses = colony.get("colony_defenses", 0)
		raw_materials = colony.get("raw_materials", 0)
		story_points = colony.get("story_points", 5)
		augmentation_points = colony.get("augmentation_points", 0)
		grunts = colony.get("grunts", 12)
		bot_operational = colony.get("bot_operational", true)

	# Progression
	if data.has("progression"):
		var prog: Dictionary = data.progression
		campaign_turn = prog.get("campaign_turn", 0)
		milestones_completed = prog.get("milestones_completed", 0)
		calamity_points = prog.get("calamity_points", 0)
		mission_data = prog.get("mission_data", 0)
		mission_data_breakthroughs = prog.get("mission_data_breakthroughs", 0)

	# Complex data
	map_data = data.get("map_data", {}).duplicate(true)
	research_data = data.get("research_data", {}).duplicate(true)
	buildings_data = data.get("buildings_data", {}).duplicate(true)
	equipment_pool = data.get("equipment_pool", []).duplicate(true)
	grunt_upgrades = data.get("grunt_upgrades", []).duplicate()
	lifeform_table = data.get("lifeform_table", []).duplicate(true)
	lifeform_evolutions = data.get("lifeform_evolutions", []).duplicate()
	condition_table = data.get("condition_table", []).duplicate(true)
	tactical_enemies = data.get("tactical_enemies", []).duplicate(true)
	enemy_info = data.get("enemy_info", {}).duplicate()
	ancient_signs = data.get("ancient_signs", []).duplicate(true)
	active_calamities = data.get("active_calamities", []).duplicate(true)
	tutorial_missions = data.get("tutorial_missions", {"beacons": false, "analysis": false, "perimeter": false}).duplicate()
	tutorial_bonuses = data.get("tutorial_bonuses", {}).duplicate()
	sick_bay = data.get("sick_bay", {}).duplicate()
	dlc_flags = data.get("dlc_flags", {}).duplicate()
	stashed_equipment = data.get("stashed_equipment", {}).duplicate(true)
	original_character_snapshots = data.get("original_character_snapshots", {}).duplicate(true)


func save_to_file(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	var json := JSON.new()
	file.store_string(json.stringify(to_dictionary(), "\t"))
	file.close()
	return OK


static func load_from_file(path: String) -> PlanetfallCampaignCore:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return null
	file.close()
	if json.data is not Dictionary:
		return null
	var campaign := PlanetfallCampaignCore.new()
	campaign.from_dictionary(json.data)
	return campaign


## ============================================================================
## INTERNAL
## ============================================================================

func _update_modified_time() -> void:
	last_modified = Time.get_datetime_string_from_system()
