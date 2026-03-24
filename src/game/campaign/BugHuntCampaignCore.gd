class_name BugHuntCampaignCore
extends Resource

## Bug Hunt Campaign Core Resource
## Stores complete Bug Hunt campaign data for save/load operations.
## Follows the same to_dictionary/from_dictionary/save_to_file/load_from_file
## pattern as FiveParsecsCampaignCore, but with Bug Hunt-specific data model:
## - No ship, no patrons/rivals, no world exploration
## - Military squad: 3-4 Main Characters + expendable Grunts in Combat Teams
## - 3-stage campaign turn (Special Assignments → Mission → Post-Battle)
## - Reputation as expendable resource, Movie Magic one-time abilities

@export var schema_version: int = 1
@export var campaign_name: String = ""
@export var campaign_id: String = ""
@export var campaign_type: String = "bug_hunt"

## Regiment info (flavor only)
@export var regiment_name: String = ""
@export var uniform_color: String = ""

## Difficulty (index into bug_hunt_missions.json difficulty_settings)
@export var difficulty: String = "mess_me_up"

## Campaign state
@export var created_at: String = ""
@export var last_modified: String = ""
@export var version: String = "1.0"
@export var game_phase: String = "creation"  # "creation", "active", "completed"
@export var campaign_turn: int = 0
@export var missions_in_current_operation: int = 0

## Squad reputation (expendable resource pool)
@export var reputation: int = 0

## Operational progress modifier (cumulative from post-battle table)
@export var operational_progress_modifier: int = 0
## Extra contact markers from operational progress
@export var extra_contact_markers: int = 0
## Extra support rolls from operational progress
@export var extra_support_rolls: int = 0

## Main characters (Array of Dictionaries from Character.to_dictionary())
var main_characters: Array = []

## Grunt pool (Array of Dictionaries - simplified stat blocks)
var grunts: Array = []

## Combat team assignments (Array of Dictionaries: {name, member_ids})
var combat_teams: Array = []

## Movie Magic abilities (Dictionary: ability_id -> bool, true = used)
var movie_magic_used: Dictionary = {}

## Support teams available for next mission (Array of support team ids)
var support_teams_available: Array = []

## Characters in Sick Bay (Dictionary: character_id -> turns_remaining)
var sick_bay: Dictionary = {}

## Completed assignments per character (Dictionary: character_id -> Array[assignment_id])
var completed_assignments: Dictionary = {}

## Military life modifiers (Dictionary for tracking temporary effects)
var military_life_modifiers: Dictionary = {}

## Campaign escalation option (if using fixed priority sequence)
var use_campaign_escalation: bool = false

## DLC flags snapshot (for save integrity)
var dlc_flags: Dictionary = {}

## Current mission data (populated during mission phase)
var current_mission: Dictionary = {}

## Progress tracking
var total_objectives_completed: int = 0
var total_missions_played: int = 0


func _init() -> void:
	created_at = Time.get_datetime_string_from_system()
	last_modified = created_at
	# Initialize movie magic from JSON (Compendium pp.182-183), fallback to hardcoded
	_init_movie_magic()

func _init_movie_magic() -> void:
	var json_path := "res://data/bug_hunt/bug_hunt_movie_magic.json"
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			var abilities: Array = json.data.get("abilities", [])
			for ability in abilities:
				var ability_id: String = ability.get("id", "")
				if not ability_id.is_empty():
					movie_magic_used[ability_id] = false
			file.close()
			if not movie_magic_used.is_empty():
				return
		file.close()
	# Fallback to hardcoded IDs
	for ability_id in ["barricade", "double_up", "escape", "evac", "extra_support",
			"lucky_find", "reinforcements", "remove_contact", "survived", "you_want_some_too"]:
		movie_magic_used[ability_id] = false


func get_campaign_id() -> String:
	if campaign_id.is_empty() and not campaign_name.is_empty():
		var ts := str(int(Time.get_unix_time_from_system()))
		campaign_id = campaign_name.to_lower().replace(" ", "_") + "_bh_" + ts
	elif campaign_id.is_empty():
		campaign_id = "bughunt_" + str(int(Time.get_unix_time_from_system()))
	return campaign_id


## ============================================================================
## DATA INITIALIZATION (used during campaign creation)
## ============================================================================

func set_config(data: Dictionary) -> void:
	if data.has("campaign_name"):
		campaign_name = data.campaign_name
	elif data.has("name"):
		campaign_name = data.name
	if data.has("regiment_name"):
		regiment_name = data.regiment_name
	if data.has("uniform_color"):
		uniform_color = data.uniform_color
	if data.has("difficulty"):
		difficulty = data.difficulty
	if data.has("use_campaign_escalation"):
		use_campaign_escalation = data.use_campaign_escalation
	_update_modified_time()


func initialize_squad(characters: Array, grunt_data: Array) -> void:
	main_characters = characters.duplicate(true)
	grunts = grunt_data.duplicate(true)
	_update_modified_time()


func set_combat_teams(teams: Array) -> void:
	combat_teams = teams.duplicate(true)
	_update_modified_time()


func add_main_character(char_dict: Dictionary) -> void:
	main_characters.append(char_dict.duplicate(true))
	_update_modified_time()


func remove_main_character(character_id: String) -> void:
	for i in range(main_characters.size() - 1, -1, -1):
		if main_characters[i].get("id", "") == character_id or \
				main_characters[i].get("character_id", "") == character_id:
			main_characters.remove_at(i)
			break
	_update_modified_time()


func get_main_character_by_id(character_id: String) -> Variant:
	for mc in main_characters:
		if mc is Dictionary:
			if mc.get("id", "") == character_id or mc.get("character_id", "") == character_id:
				return mc
	return null


func get_active_main_characters() -> Array:
	## Returns main characters not in sick bay
	var active: Array = []
	for mc in main_characters:
		var cid: String = mc.get("id", mc.get("character_id", ""))
		if not sick_bay.has(cid) or sick_bay[cid] <= 0:
			active.append(mc)
	return active


## ============================================================================
## MOVIE MAGIC
## ============================================================================

func use_movie_magic(ability_id: String) -> bool:
	if movie_magic_used.get(ability_id, true):
		return false  # Already used or unknown
	movie_magic_used[ability_id] = true
	_update_modified_time()
	return true


func is_movie_magic_available(ability_id: String) -> bool:
	return not movie_magic_used.get(ability_id, true)


func get_available_movie_magic() -> Array[String]:
	var available: Array[String] = []
	for ability_id in movie_magic_used:
		if not movie_magic_used[ability_id]:
			available.append(ability_id)
	return available


## ============================================================================
## SICK BAY
## ============================================================================

func add_to_sick_bay(character_id: String, turns: int) -> void:
	sick_bay[character_id] = turns
	_update_modified_time()


func tick_sick_bay() -> Array[String]:
	## Decrement sick bay turns, return IDs of characters who are recovered
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
## REPUTATION
## ============================================================================

func spend_reputation(amount: int) -> bool:
	if reputation < amount:
		return false
	reputation -= amount
	_update_modified_time()
	return true


func add_reputation(amount: int) -> void:
	reputation += amount
	_update_modified_time()


## ============================================================================
## VALIDATION
## ============================================================================

func validate() -> bool:
	if campaign_name.is_empty():
		return false
	if main_characters.size() < 3:
		return false
	return true


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if campaign_name.is_empty():
		errors.append("Campaign name is required")
	if main_characters.size() < 3:
		errors.append("Bug Hunt requires at least 3 main characters")
	if main_characters.size() > 4:
		errors.append("Bug Hunt allows at most 4 main characters")
	return errors


## ============================================================================
## CAMPAIGN SUMMARY
## ============================================================================

func get_campaign_summary() -> Dictionary:
	return {
		"name": campaign_name,
		"type": "bug_hunt",
		"regiment": regiment_name,
		"difficulty": difficulty,
		"main_characters": main_characters.size(),
		"reputation": reputation,
		"campaign_turn": campaign_turn,
		"missions_played": total_missions_played,
		"created": created_at,
		"status": game_phase,
		"movie_magic_remaining": get_available_movie_magic().size()
	}


func start_campaign() -> void:
	game_phase = "active"
	_update_modified_time()


func advance_turn() -> void:
	campaign_turn += 1
	_update_modified_time()


func apply_assignments(completed: Array) -> void:
	## Apply results of special assignments to characters.
	for slot in completed:
		if slot is not Dictionary:
			continue
		var char_id: String = slot.get("character_id", "")
		var assignment_id: String = slot.get("assignment_id", "")
		var result: String = slot.get("result", "")
		if assignment_id.is_empty() or result != "success":
			continue
		# Track that this character completed this assignment
		if not completed_assignments.has(char_id):
			completed_assignments[char_id] = []
		if assignment_id not in completed_assignments[char_id]:
			completed_assignments[char_id].append(assignment_id)


## ============================================================================
## SERIALIZATION
## ============================================================================

func to_dictionary() -> Dictionary:
	return {
		"campaign_id": get_campaign_id(),
		"campaign_type": "bug_hunt",
		"meta": {
			"campaign_id": get_campaign_id(),
			"campaign_name": campaign_name,
			"campaign_type": "bug_hunt",
			"schema_version": schema_version,
			"created_at": created_at,
			"last_modified": last_modified,
			"version": version,
			"game_phase": game_phase
		},
		"config": {
			"name": campaign_name,
			"regiment_name": regiment_name,
			"uniform_color": uniform_color,
			"difficulty": difficulty,
			"use_campaign_escalation": use_campaign_escalation
		},
		"squad": {
			"main_characters": main_characters.duplicate(true),
			"grunts": grunts.duplicate(true),
			"combat_teams": combat_teams.duplicate(true)
		},
		"state": {
			"campaign_turn": campaign_turn,
			"missions_in_current_operation": missions_in_current_operation,
			"reputation": reputation,
			"operational_progress_modifier": operational_progress_modifier,
			"extra_contact_markers": extra_contact_markers,
			"extra_support_rolls": extra_support_rolls,
			"total_objectives_completed": total_objectives_completed,
			"total_missions_played": total_missions_played
		},
		"movie_magic_used": movie_magic_used.duplicate(),
		"sick_bay": sick_bay.duplicate(),
		"completed_assignments": completed_assignments.duplicate(true),
		"military_life_modifiers": military_life_modifiers.duplicate(true),
		"support_teams_available": support_teams_available.duplicate(),
		"current_mission": current_mission.duplicate(true),
		"dlc_flags": dlc_flags.duplicate()
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
		regiment_name = config.get("regiment_name", "")
		uniform_color = config.get("uniform_color", "")
		difficulty = config.get("difficulty", "mess_me_up")
		use_campaign_escalation = config.get("use_campaign_escalation", false)

	# Squad
	if data.has("squad"):
		var squad: Dictionary = data.squad
		main_characters = squad.get("main_characters", []).duplicate(true)
		grunts = squad.get("grunts", []).duplicate(true)
		combat_teams = squad.get("combat_teams", []).duplicate(true)

	# State
	if data.has("state"):
		var state: Dictionary = data.state
		campaign_turn = state.get("campaign_turn", 0)
		missions_in_current_operation = state.get("missions_in_current_operation", 0)
		reputation = state.get("reputation", 0)
		operational_progress_modifier = state.get("operational_progress_modifier", 0)
		extra_contact_markers = state.get("extra_contact_markers", 0)
		extra_support_rolls = state.get("extra_support_rolls", 0)
		total_objectives_completed = state.get("total_objectives_completed", 0)
		total_missions_played = state.get("total_missions_played", 0)

	# Remaining sections
	movie_magic_used = data.get("movie_magic_used", {}).duplicate()
	sick_bay = data.get("sick_bay", {}).duplicate()
	completed_assignments = data.get("completed_assignments", {}).duplicate(true)
	military_life_modifiers = data.get("military_life_modifiers", {}).duplicate(true)
	support_teams_available = data.get("support_teams_available", []).duplicate()
	current_mission = data.get("current_mission", {}).duplicate(true)
	dlc_flags = data.get("dlc_flags", {}).duplicate()

	# Re-initialize any missing movie magic entries
	for ability_id in ["barricade", "double_up", "escape", "evac", "extra_support",
			"lucky_find", "reinforcements", "remove_contact", "survived", "you_want_some_too"]:
		if not movie_magic_used.has(ability_id):
			movie_magic_used[ability_id] = false


## ============================================================================
## FILE I/O
## ============================================================================

func save_to_file(path: String) -> Error:
	_update_modified_time()
	var data := to_dictionary()

	# Strip non-serializable Resource references from characters
	var clean_chars: Array = []
	for mc in data.get("squad", {}).get("main_characters", []):
		if mc is Dictionary:
			var clean: Dictionary = mc.duplicate(true)
			clean.erase("character_object")
			clean_chars.append(clean)
		elif mc is Resource and mc.has_method("to_dictionary"):
			clean_chars.append(mc.to_dictionary())
		else:
			clean_chars.append(mc)
	if data.has("squad"):
		data["squad"]["main_characters"] = clean_chars

	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var error := FileAccess.get_open_error()
		push_error("BugHuntCampaignCore: Failed to save: %s (error: %d)" % [path, error])
		return error

	file.store_string(json_string)
	file.close()
	return OK


static func load_from_file(path: String) -> BugHuntCampaignCore:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		return null

	var campaign := BugHuntCampaignCore.new()
	campaign.from_dictionary(json.data)
	return campaign


static func create_new_campaign(name: String, difficulty_id: String = "mess_me_up") -> BugHuntCampaignCore:
	var campaign := BugHuntCampaignCore.new()
	campaign.campaign_name = name
	campaign.difficulty = difficulty_id
	return campaign


## ============================================================================
## PRIVATE
## ============================================================================

func _update_modified_time() -> void:
	last_modified = Time.get_datetime_string_from_system()
