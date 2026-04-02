@tool
class_name FiveParsecsConstants
extends RefCounted

## Five Parsecs Constants - Complement to GlobalEnums.gd
## Provides constants for table access, dice thresholds, and UI configurations
## Eliminates magic numbers and improves type safety

# Crew Task Difficulty Thresholds — loaded from data/crew_tasks.json
# Fallback values here match Core Rules 3e pp.77-78 (VERIFIED Mar 22, 2026)
static var CREW_TASK_DIFFICULTIES = {}
static var _crew_tasks_loaded: bool = false

static func _ensure_crew_tasks_loaded() -> void:
	if _crew_tasks_loaded:
		return
	_crew_tasks_loaded = true
	var path := "res://data/crew_tasks.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		_load_crew_task_fallbacks()
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		_load_crew_task_fallbacks()
		return
	file.close()
	var data: Dictionary = json.data
	var enum_map := {
		"FIND_PATRON": GlobalEnums.CrewTaskType.FIND_PATRON,
		"TRAIN": GlobalEnums.CrewTaskType.TRAIN,
		"TRADE": GlobalEnums.CrewTaskType.TRADE,
		"RECRUIT": GlobalEnums.CrewTaskType.RECRUIT,
		"EXPLORE": GlobalEnums.CrewTaskType.EXPLORE,
		"TRACK": GlobalEnums.CrewTaskType.TRACK,
		"REPAIR": GlobalEnums.CrewTaskType.REPAIR,
		"DECOY": GlobalEnums.CrewTaskType.DECOY,
	}
	for task: Dictionary in data.get("tasks", []):
		var key_str: String = task.get("enum_key", "")
		if key_str in enum_map:
			CREW_TASK_DIFFICULTIES[enum_map[key_str]] = int(task.get("dice_target", 0))

static func _load_crew_task_fallbacks() -> void:
	push_warning("FiveParsecsConstants: crew_tasks.json not found, using hardcoded fallbacks")
	CREW_TASK_DIFFICULTIES = {
		GlobalEnums.CrewTaskType.FIND_PATRON: 5,
		GlobalEnums.CrewTaskType.TRAIN: 0,
		GlobalEnums.CrewTaskType.TRADE: 0,
		GlobalEnums.CrewTaskType.RECRUIT: 6,
		GlobalEnums.CrewTaskType.EXPLORE: 0,
		GlobalEnums.CrewTaskType.TRACK: 6,
		GlobalEnums.CrewTaskType.REPAIR: 6,
		GlobalEnums.CrewTaskType.DECOY: 0,
	}

# Dice Types for Consistent Rolling
const DICE_TYPES = {
	"d6": "1d6",
	"2d6": "2d6",
	"d10": "1d10",
	"d100": "1d100",
	"attribute": "2d6_divide_3" # Five Parsecs attribute generation
}

# Table Names for Data Manager Access
const TABLE_NAMES = {
	"patron_contact": "patron_contact_table",
	"exploration_results": "exploration_results_table",
	"trade_opportunities": "trade_opportunities_table",
	"crew_recruitment": "crew_recruitment_table",
	"training_results": "training_results_table",
	"world_traits": "world_traits_table",
	"mission_complications": "mission_complications_table",
	"character_events": "character_events_table",
	"campaign_events": "campaign_events_table"
}

# World Phase Processing Times (milliseconds)
const PROCESSING_LIMITS = {
	"crew_task_resolution": 50, # Max time per crew task
	"table_lookup": 10, # Max time per table lookup
	"ui_update": 16, # Target 60fps UI updates
	"dice_animation": 1500, # Dice roll animation duration
	"phase_transition": 1000 # Phase change animation
}

# Game data loaded from res://data/campaign_config.json
static var _cc_data: Dictionary = {}
static var _cc_loaded: bool = false

static func _ensure_cc_loaded() -> void:
	if _cc_loaded:
		return
	_cc_loaded = true
	var file := FileAccess.open("res://data/campaign_config.json", FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_cc_data = json.data
	file.close()

# Five Parsecs Character Stat Ranges (loaded from JSON)
static var STAT_RANGES: Dictionary: # @no-lint:variable-name
	get:
		_ensure_cc_loaded()
		var d: Dictionary = _cc_data.get("stat_ranges", {})
		if d.is_empty():
			return {"min": 1, "max": 6, "average": 3, "elite": 5}
		return d

# Character Generation Constants (loaded from JSON)
static var CHARACTER_CREATION: Dictionary: # @no-lint:variable-name
	get:
		_ensure_cc_loaded()
		var d: Dictionary = _cc_data.get("character_creation", {})
		if d.is_empty():
			return {"starting_credits": 1, "max_crew_size": 8, "min_crew_size": 4, "attribute_dice": "2d6", "attribute_divisor": 3}
		return d

# Campaign Turn Constants (loaded from JSON)
static var CAMPAIGN_TURNS: Dictionary: # @no-lint:variable-name
	get:
		_ensure_cc_loaded()
		var d: Dictionary = _cc_data.get("campaign_turns_config", {})
		if d.is_empty():
			return {"max_turns": 100, "short_campaign": 20, "medium_campaign": 50, "long_campaign": 100, "story_quest_minimum": 3}
		return d

# Economic System Constants (loaded from JSON) — VERIFIED against Core Rules 3e
static var ECONOMY: Dictionary: # @no-lint:variable-name
	get:
		_ensure_cc_loaded()
		var d: Dictionary = _cc_data.get("economy", {})
		# Strip metadata
		var result := {}
		for k in d:
			if k != "source":
				result[k] = d[k]
		if result.is_empty():
			return {"starting_debt": 75, "upkeep_threshold": 4, "upkeep_cap": 6, "base_upkeep": 1}
		return result

# Combat System Constants (loaded from JSON) — Core Rules pp.40, 44, 112
static var COMBAT: Dictionary: # @no-lint:variable-name
	get:
		_ensure_cc_loaded()
		var d: Dictionary = _cc_data.get("combat", {})
		var result := {}
		for k in d:
			if k != "source":
				result[k] = d[k]
		if result.is_empty():
			return {"seize_initiative_target": 10, "stun_knockout_threshold": 3, "to_hit_open_close": 3, "to_hit_standard": 5, "to_hit_cover": 6}
		return result

# Mission Generation Constants — Use patron_generation.json for canonical D10 tables.
# These are app-level defaults; JSON data is authoritative where it exists.
const MISSIONS = {
	# Note: credit_rewards.json DELETED (was fabricated). Use patron_generation.json for all payment tables.
	# Danger pay: D10 table in patron_generation.json (1-4:+1cr, 5-8:+2cr, 9:+3cr, 10+:+3cr+reroll). VERIFIED p.83.
	# Mission pay: D6 base (Core Rules p.120). VERIFIED.
	"story_mission_frequency": 6, # APP_SPECIFIC — not a Core Rules value, controls app story pacing
}

# Tutorial System Configuration
const TUTORIAL = {
	"auto_advance_delay": 3.0, # Seconds before auto-advance
	"highlight_pulse_speed": 1.0, # Animation speed for highlights
	"tooltip_offset": Vector2(10, -30), # Tooltip position offset
	"fade_duration": 0.3, # Fade in/out duration
	"step_validation_timeout": 5.0 # Max time to wait for step completion
}

# UI Layout Constants
const UI_LAYOUT = {
	"panel_padding": 10, # Standard panel padding
	"button_spacing": 5, # Button spacing
	"text_margin": 15, # Text margins
	"highlight_alpha": 0.2, # Highlight overlay alpha
	"dimmed_alpha": 0.7, # Dimmed overlay alpha
	"animation_speed": 0.3, # Standard animation speed
	"tooltip_max_width": 300 # Maximum tooltip width
}

# Error and Success Messages
const MESSAGES = {
	"errors": {
		"crew_not_found": "Crew member not found",
		"insufficient_credits": "Insufficient credits for this action",
		"invalid_task_type": "Invalid crew task type specified",
		"table_lookup_failed": "Failed to lookup data in table",
		"dice_roll_failed": "Dice roll calculation failed",
		"save_data_corrupt": "Save data is corrupted or invalid",
		"tutorial_step_invalid": "Tutorial step configuration invalid",
		"mission_generation_failed": "Failed to generate mission",
		"equipment_not_available": "Equipment not available for purchase"
	},
	"success": {
		"crew_task_completed": "Crew task completed successfully",
		"patron_found": "New patron contact established",
		"training_successful": "Training completed with skill improvement",
		"exploration_successful": "Exploration yielded valuable discoveries",
		"trade_profitable": "Trade completed with profit",
		"mission_completed": "Mission completed successfully",
		"equipment_purchased": "Equipment purchased successfully",
		"character_advanced": "Character advancement applied"
	}
}

# Signal Names for Enhanced Communication
const SIGNALS = {
	"crew_task_started": "crew_task_started",
	"crew_task_rolling": "crew_task_rolling",
	"crew_task_completed": "crew_task_completed",
	"world_phase_started": "world_phase_started",
	"world_phase_completed": "world_phase_completed",
	"campaign_phase_changed": "campaign_phase_changed",
	"character_injured": "character_injured",
	"equipment_damaged": "equipment_damaged",
	"mission_available": "mission_available",
	"tutorial_step_completed": "tutorial_step_completed"
}

# Resource File Paths
const PATHS = {
	"data": "res://data/",
	"tables": "res://data/campaign_tables/",
	"characters": "res://data/Characters/",
	"equipment": "res://data/Equipment/",
	"missions": "res://data/Missions/",
	"tutorials": "res://data/Tutorials/",
	"saves": "user://saves/",
	"backups": "user://backups/",
	"logs": "user://logs/"
}

# Version Information
const VERSION = {
	"major": 1,
	"minor": 0,
	"patch": 0,
	"build": "production",
	"five_parsecs_rules": "2023 Edition",
	"godot_version": "4.4"
}

## Helper Methods for Constant Access

static func get_crew_task_difficulty(task_type: GlobalEnums.CrewTaskType) -> int:
	## Get difficulty threshold for crew task type
	_ensure_crew_tasks_loaded()
	return CREW_TASK_DIFFICULTIES.get(task_type, 7)

static func get_table_name(table_key: String) -> String:
	## Get full table name from key
	return TABLE_NAMES.get(table_key, table_key + "_table")

static func get_error_message(error_key: String) -> String:
	## Get localized error message
	return MESSAGES.errors.get(error_key, "Unknown error occurred")

static func get_success_message(success_key: String) -> String:
	## Get localized success message
	return MESSAGES.success.get(success_key, "Operation completed successfully")

static func get_dice_type_name(dice_key: String) -> String:
	## Get standardized dice notation
	return DICE_TYPES.get(dice_key, "1d6")

static func get_processing_limit(operation: String) -> int:
	## Get performance limit for operation (milliseconds)
	return PROCESSING_LIMITS.get(operation, 50)

static func get_ui_constant(ui_key: String) -> Variant:
	## Get UI layout constant
	return UI_LAYOUT.get(ui_key, 0)

static func get_signal_name(signal_key: String) -> String:
	## Get standardized signal name
	return SIGNALS.get(signal_key, signal_key)

static func get_resource_path(path_key: String) -> String:
	## Get standardized resource path
	return PATHS.get(path_key, "res://")

static func is_valid_stat_value(value: int) -> bool:
	## Validate character stat value
	return value >= STAT_RANGES.min and value <= STAT_RANGES.max

static func clamp_stat_value(value: int) -> int:
	## Clamp stat value to valid range
	return clamp(value, STAT_RANGES.min, STAT_RANGES.max)

static func get_range_band_name(distance: int) -> String:
	## Get combat range band for distance
	var ranges = COMBAT.range_bands
	if distance <= ranges.point_blank:
		return "Point Blank"
	elif distance <= ranges.short:
		return "Short"
	elif distance <= ranges.medium:
		return "Medium"
	elif distance <= ranges.long:
		return "Long"
	else:
		return "Extreme"

static func calculate_upkeep_cost(crew_size: int) -> int:
	## Calculate crew upkeep cost
	if crew_size < ECONOMY.upkeep_threshold:
		return 0
	var base_cost = ECONOMY.base_upkeep
	var additional_crew = max(0, crew_size - 6) # Crew beyond 6 cost extra
	return base_cost + (additional_crew * ECONOMY.additional_crew_cost)

static func get_tutorial_config(config_key: String) -> Variant:
	## Get tutorial configuration value
	return TUTORIAL.get(config_key, null)

static func get_version_string() -> String:
	## Get formatted version string
	return "%d.%d.%d-%s" % [VERSION.major, VERSION.minor, VERSION.patch, VERSION.build]

static func get_combat_constant(constant_key: String) -> Variant:
	## Get combat system constant
	return COMBAT.get(constant_key, 0)

static func get_mission_constant(constant_key: String) -> Variant:
	## Get mission system constant
	return MISSIONS.get(constant_key, 0)

static func get_economy_constant(constant_key: String) -> Variant:
	## Get economy system constant
	return ECONOMY.get(constant_key, 0)

static func get_character_creation_constant(constant_key: String) -> Variant:
	## Get character creation constant
	return CHARACTER_CREATION.get(constant_key, 0)

## Validation Methods

static func validate_crew_task_type(task_type: int) -> bool:
	## Validate crew task type is in valid range
	return task_type >= GlobalEnums.CrewTaskType.NONE and task_type < GlobalEnums.CrewTaskType.size()

static func validate_campaign_phase(phase: int) -> bool:
	## Validate campaign phase is in valid range
	return phase >= GlobalEnums.FiveParsecsCampaignPhase.NONE and phase < GlobalEnums.FiveParsecsCampaignPhase.size()

static func validate_credits_amount(amount: int) -> bool:
	## Validate credits amount is non-negative
	return amount >= 0

static func validate_crew_size(size: int) -> bool:
	## Validate crew size is within game limits
	return size >= CHARACTER_CREATION.min_crew_size and size <= CHARACTER_CREATION.max_crew_size

static func validate_turn_number(turn: int) -> bool:
	## Validate campaign turn number
	return turn >= 1 and turn <= CAMPAIGN_TURNS.max_turns

static func validate_dice_roll(dice_count: int, die_size: int) -> bool:
	## Validate dice roll parameters
	return dice_count > 0 and dice_count <= 10 and die_size > 0 and die_size <= 100

## Performance Monitoring Methods

static func start_performance_timer(operation: String) -> int:
	## Start performance timer for operation
	return Time.get_ticks_msec()

static func check_performance_limit(start_time: int, operation: String) -> bool:
	## Check if operation exceeds performance limit
	var elapsed = Time.get_ticks_msec() - start_time
	var limit = get_processing_limit(operation)
	return elapsed <= limit

static func log_performance_warning(operation: String, elapsed: int) -> void:
	## Log performance warning for slow operation
	var limit = get_processing_limit(operation)
	if elapsed > limit:
		push_warning("Performance warning: %s took %dms (limit: %dms)" % [operation, elapsed, limit])