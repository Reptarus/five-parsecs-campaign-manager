@tool
extends Resource
class_name CampaignConfig

## Production-Grade Campaign Configuration Resource
## Fully typed replacement for broken backup file
## Enterprise validation and serialization included

# Import validation result class
const ValidationResult = preload("res://src/core/validation/ValidationResult.gd")

# Core configuration properties with explicit typing
@export var campaign_name: String = ""
@export var difficulty_level: int = 1
@export var starting_credits: int = 1000
@export var max_crew_size: int = 6
@export var campaign_length: int = 100  # number of turns

# Advanced configuration options
@export var enable_permadeath: bool = true
@export var story_track_enabled: bool = true
@export var battle_difficulty_modifier: float = 1.0
@export var economic_modifier: float = 1.0

# Metadata and tracking
@export var creation_date: String = ""
@export var last_modified: String = ""
@export var version: String = "1.0.0"

func _init() -> void:
	if creation_date.is_empty():
		creation_date = Time.get_datetime_string_from_system()
	last_modified = creation_date

## Comprehensive validation following Five Parsecs rules
func validate() -> ValidationResult:
	var result = ValidationResult.new()
	
	# Campaign name validation
	if campaign_name.strip_edges().is_empty():
		result.valid = false
		result.error = "Campaign name is required"
		return result
	
	if campaign_name.length() < 3:
		result.valid = false
		result.error = "Campaign name must be at least 3 characters"
		return result
	
	# Difficulty validation
	if difficulty_level < 1 or difficulty_level > 5:
		result.valid = false
		result.error = "Difficulty level must be between 1 and 5"
		return result
	
	# Credits validation
	if starting_credits < 0:
		result.valid = false
		result.error = "Starting credits cannot be negative"
		return result
	
	if starting_credits > 10000:
		result.add_warning("Starting credits above 10,000 may unbalance gameplay")
	
	# Crew size validation
	if max_crew_size < 1 or max_crew_size > 8:
		result.valid = false
		result.error = "Maximum crew size must be between 1 and 8"
		return result
	
	# Campaign length validation
	if campaign_length < 10:
		result.valid = false
		result.error = "Campaign length must be at least 10 turns"
		return result
	
	if campaign_length > 1000:
		result.add_warning("Campaign length over 1000 turns may impact performance")
	
	# Modifier validation
	if battle_difficulty_modifier < 0.1 or battle_difficulty_modifier > 5.0:
		result.valid = false
		result.error = "Battle difficulty modifier must be between 0.1 and 5.0"
		return result
	
	if economic_modifier < 0.1 or economic_modifier > 5.0:
		result.valid = false
		result.error = "Economic modifier must be between 0.1 and 5.0"
		return result
	
	# Success with any warnings collected
	result.valid = true
	return result

## Serialization for save/load systems
func to_dictionary() -> Dictionary:
	return {
		"campaign_name": campaign_name,
		"difficulty_level": difficulty_level,
		"starting_credits": starting_credits,
		"max_crew_size": max_crew_size,
		"campaign_length": campaign_length,
		"enable_permadeath": enable_permadeath,
		"story_track_enabled": story_track_enabled,
		"battle_difficulty_modifier": battle_difficulty_modifier,
		"economic_modifier": economic_modifier,
		"creation_date": creation_date,
		"last_modified": last_modified,
		"version": version
	}

## Deserialization from saved data
static func from_dictionary(data: Dictionary) -> CampaignConfig:
	var config = CampaignConfig.new()
	
	config.campaign_name = data.get("campaign_name", "")
	config.difficulty_level = data.get("difficulty_level", 1)
	config.starting_credits = data.get("starting_credits", 1000)
	config.max_crew_size = data.get("max_crew_size", 6)
	config.campaign_length = data.get("campaign_length", 100)
	config.enable_permadeath = data.get("enable_permadeath", true)
	config.story_track_enabled = data.get("story_track_enabled", true)
	config.battle_difficulty_modifier = data.get("battle_difficulty_modifier", 1.0)
	config.economic_modifier = data.get("economic_modifier", 1.0)
	config.creation_date = data.get("creation_date", "")
	config.last_modified = data.get("last_modified", "")
	config.version = data.get("version", "1.0.0")
	
	return config
