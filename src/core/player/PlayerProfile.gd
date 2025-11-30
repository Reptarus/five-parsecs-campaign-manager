class_name PlayerProfile
extends Resource

## Cross-Campaign Player Achievement System
##
## Manages Elite Ranks earned by completing campaigns with Victory Conditions.
## Provides persistent bonuses that carry over between campaigns.
##
## Core Rules Reference: p.65 Elite Ranks
## - Each Victory Condition can award Elite Rank ONLY ONCE
## - Bonuses scale with total ranks earned
## - Persists to user://player_profile.json

## ============================================================================
## SIGNALS
## ============================================================================

## Emitted when Elite Ranks change
signal elite_ranks_changed(old_rank: int, new_rank: int)

## Emitted when a new Victory Condition is completed
signal victory_unlocked(victory_type: int)

## Emitted after successful save
signal profile_saved()

## Emitted after successful load
signal profile_loaded()


## ============================================================================
## CONSTANTS
## ============================================================================

const SAVE_PATH := "user://player_profile.json"
const SCHEMA_VERSION := 1

## Bonus scaling thresholds
const EXTRA_CHARACTER_EVERY := 3  # Every 3 ranks = +1 starting character
const STARS_BONUS_EVERY := 5      # Every 5 ranks = +1 Stars of the Story use


## ============================================================================
## EXPORTED PROPERTIES (Persistent Data)
## ============================================================================

## Total Elite Ranks earned across all campaigns
@export var elite_ranks: int = 0

## Array of VictoryCondition.Type enum values that have awarded Elite Rank
## Each victory can only award rank ONCE
@export var completed_victory_conditions: Array[int] = []

## Total campaigns completed with a Victory Condition
@export var total_campaigns_completed: int = 0

## Total campaigns started (for statistics)
@export var total_campaigns_started: int = 0

## Profile creation timestamp (ISO 8601 format)
@export var created_at: String = ""

## Last save timestamp (ISO 8601 format)
@export var last_saved_at: String = ""


## ============================================================================
## SINGLETON INSTANCE
## ============================================================================

static var _instance: PlayerProfile = null


## Returns the singleton instance, creating and loading if necessary
static func get_instance() -> PlayerProfile:
	if _instance == null:
		var script := load("res://src/core/player/PlayerProfile.gd") as GDScript
		_instance = script.new()
		_instance.load_from_disk()
	return _instance


## Resets the singleton (primarily for testing)
static func reset_instance() -> void:
	_instance = null


## ============================================================================
## INITIALIZATION
## ============================================================================

func _init() -> void:
	if created_at.is_empty():
		created_at = Time.get_datetime_string_from_system(true)


## ============================================================================
## ELITE RANK MANAGEMENT
## ============================================================================

## Awards an Elite Rank for completing a Victory Condition
## Returns true if rank was awarded, false if already completed
func award_elite_rank(victory_condition: int) -> bool:
	# Prevent duplicate awards
	if has_completed_victory(victory_condition):
		push_warning("PlayerProfile: Victory condition %d already completed - cannot award Elite Rank twice" % victory_condition)
		return false

	# Validate victory condition type using GlobalEnums
	if victory_condition < 0 or victory_condition >= GlobalEnums.FiveParsecsCampaignVictoryType.size():
		push_error("PlayerProfile: Invalid victory condition type %d" % victory_condition)
		return false

	var old_rank := elite_ranks

	# Award the rank
	elite_ranks += 1
	completed_victory_conditions.append(victory_condition)
	total_campaigns_completed += 1

	# Emit signals
	elite_ranks_changed.emit(old_rank, elite_ranks)
	victory_unlocked.emit(victory_condition)

	# Auto-save
	save_to_disk()

	print("PlayerProfile: Elite Rank awarded! %d → %d (Victory: %s)" % [
		old_rank,
		elite_ranks,
		GlobalEnums.FiveParsecsCampaignVictoryType.keys()[victory_condition]
	])

	return true


## Checks if a specific Victory Condition has been completed
func has_completed_victory(victory_condition: int) -> bool:
	return completed_victory_conditions.has(victory_condition)


## Increments total campaigns started (called at campaign creation)
func register_campaign_start() -> void:
	total_campaigns_started += 1
	save_to_disk()


## ============================================================================
## BONUS CALCULATIONS (Core Rules p.65)
## ============================================================================

## Returns bonus story points at campaign start
## Formula: +1 per Elite Rank
func get_starting_story_point_bonus() -> int:
	return elite_ranks


## Returns bonus XP at campaign start (distributable to any characters)
## Formula: +2 XP per Elite Rank
func get_starting_xp_bonus() -> int:
	return elite_ranks * 2


## Returns number of extra starting characters to roll
## Formula: +1 per 3 Elite Ranks (rounded down)
func get_extra_starting_characters() -> int:
	return elite_ranks / EXTRA_CHARACTER_EVERY


## Returns how many times "Stars of the Story" abilities can be used
## Formula: Base 1 + (elite_ranks / 5)
func get_stars_of_story_bonus_uses() -> int:
	return 1 + (elite_ranks / STARS_BONUS_EVERY)


## Returns a summary of all bonuses for display
func get_bonus_summary() -> Dictionary:
	return {
		"elite_ranks": elite_ranks,
		"story_points": get_starting_story_point_bonus(),
		"bonus_xp": get_starting_xp_bonus(),
		"extra_characters": get_extra_starting_characters(),
		"stars_uses": get_stars_of_story_bonus_uses(),
		"campaigns_completed": total_campaigns_completed,
		"campaigns_started": total_campaigns_started
	}


## ============================================================================
## PERSISTENCE (JSON Format)
## ============================================================================

## Saves the profile to disk
func save_to_disk() -> void:
	last_saved_at = Time.get_datetime_string_from_system(true)
	
	var data := {
		"schema_version": SCHEMA_VERSION,
		"elite_ranks": elite_ranks,
		"completed_victory_conditions": completed_victory_conditions,
		"total_campaigns_completed": total_campaigns_completed,
		"total_campaigns_started": total_campaigns_started,
		"created_at": created_at,
		"last_saved_at": last_saved_at
	}
	
	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	
	if file == null:
		push_error("PlayerProfile: Failed to save - %s" % FileAccess.get_open_error())
		return
	
	file.store_string(json_string)
	file.close()
	
	profile_saved.emit()
	print("PlayerProfile: Saved to %s (Elite Ranks: %d)" % [SAVE_PATH, elite_ranks])


## Loads the profile from disk (or creates default if not exists)
func load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("PlayerProfile: No existing profile found - creating new")
		save_to_disk()
		profile_loaded.emit()
		return
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	
	if file == null:
		push_error("PlayerProfile: Failed to load - %s" % FileAccess.get_open_error())
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	
	if parse_result != OK:
		push_error("PlayerProfile: JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return
	
	var data: Dictionary = json.data
	
	# Validate schema version
	if not data.has("schema_version") or data.schema_version != SCHEMA_VERSION:
		push_warning("PlayerProfile: Schema version mismatch - migration may be needed")
		# Future: Add migration logic here
	
	# Load data
	elite_ranks = data.get("elite_ranks", 0)
	completed_victory_conditions = data.get("completed_victory_conditions", [])
	total_campaigns_completed = data.get("total_campaigns_completed", 0)
	total_campaigns_started = data.get("total_campaigns_started", 0)
	created_at = data.get("created_at", "")
	last_saved_at = data.get("last_saved_at", "")
	
	profile_loaded.emit()
	print("PlayerProfile: Loaded successfully (Elite Ranks: %d, Completed Victories: %d)" % [
		elite_ranks,
		completed_victory_conditions.size()
	])


## Resets the profile to default state (DESTRUCTIVE - use with caution)
func reset_profile() -> void:
	var old_rank := elite_ranks
	
	elite_ranks = 0
	completed_victory_conditions.clear()
	total_campaigns_completed = 0
	total_campaigns_started = 0
	created_at = Time.get_datetime_string_from_system(true)
	last_saved_at = ""
	
	save_to_disk()
	elite_ranks_changed.emit(old_rank, 0)
	
	push_warning("PlayerProfile: Profile reset to default state")


## ============================================================================
## EXPORT/IMPORT (For Backup/Transfer)
## ============================================================================

## Exports the profile to a portable JSON string
func export_to_json() -> String:
	var data := {
		"schema_version": SCHEMA_VERSION,
		"elite_ranks": elite_ranks,
		"completed_victory_conditions": completed_victory_conditions,
		"total_campaigns_completed": total_campaigns_completed,
		"total_campaigns_started": total_campaigns_started,
		"created_at": created_at,
		"last_saved_at": last_saved_at,
		"export_timestamp": Time.get_datetime_string_from_system(true)
	}
	return JSON.stringify(data, "\t")


## Imports profile data from a JSON string (validates before overwriting)
func import_from_json(json_string: String) -> bool:
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	
	if parse_result != OK:
		push_error("PlayerProfile: Import failed - JSON parse error at line %d: %s" % [
			json.get_error_line(),
			json.get_error_message()
		])
		return false
	
	var data: Dictionary = json.data
	
	# Validate required fields
	if not data.has("elite_ranks") or not data.has("completed_victory_conditions"):
		push_error("PlayerProfile: Import failed - missing required fields")
		return false
	
	# Import data (overwrites current profile)
	var old_rank := elite_ranks
	
	elite_ranks = data.get("elite_ranks", 0)
	completed_victory_conditions = data.get("completed_victory_conditions", [])
	total_campaigns_completed = data.get("total_campaigns_completed", 0)
	total_campaigns_started = data.get("total_campaigns_started", 0)
	created_at = data.get("created_at", Time.get_datetime_string_from_system(true))
	
	save_to_disk()
	elite_ranks_changed.emit(old_rank, elite_ranks)
	
	print("PlayerProfile: Imported successfully (Elite Ranks: %d)" % elite_ranks)
	return true


## ============================================================================
## DEBUG/TESTING HELPERS
## ============================================================================

## Returns a human-readable debug string
func _to_string() -> String:
	return "PlayerProfile(elite_ranks=%d, completed_victories=%d, campaigns=%d/%d)" % [
		elite_ranks,
		completed_victory_conditions.size(),
		total_campaigns_completed,
		total_campaigns_started
	]
