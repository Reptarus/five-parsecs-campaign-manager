@tool
extends Resource

signal validation_completed(result: Dictionary)
signal validation_failed(context: String, errors: Array)
signal validation_cache_updated

const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Management/CharacterDataManager.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const StoryQuestData = preload("res://src/core/story/StoryQuestData.gd")
const Location = preload("res://src/core/world/Location.gd")
const SaveManager = preload("res://src/core/state/SaveManager.gd")
const ErrorLogger = preload("res://src/core/systems/ErrorLogger.gd")

# Validation Schemas
const CREW_SCHEMA = {
    "required_fields": ["name", "class", "level", "experience", "stats", "skills", "abilities", "equipment"],
    "stat_ranges": {
        "health": {"min": 0, "max": 100},
        "morale": {"min": 0, "max": 100},
        "combat": {"min": 1, "max": 10},
        "agility": {"min": 1, "max": 10},
        "savvy": {"min": 1, "max": 10}
    }
}

const EQUIPMENT_SCHEMA = {
    "required_fields": ["name", "type", "quantity", "condition"],
    "condition_range": {"min": 0, "max": 100},
    "quantity_range": {"min": 0, "max": 999}
}

const MISSION_SCHEMA = {
    "required_fields": ["name", "type", "difficulty", "objectives", "rewards"],
    "difficulty_range": {"min": 1, "max": 5}
}

const PHASE_STATE_SCHEMA_FIELDS = {
    "required_fields": ["current_phase", "previous_phase", "phase_data", "completed_actions"]
}

var _valid_phases: Array = []
var game_state: FiveParsecsGameState
var _validation_cache: Dictionary = {}
var _last_cache_clear_time: float = 0.0
var _cache_timeout: float = 5.0 # Cache timeout in seconds
var error_logger: ErrorLogger

## Initialize the ValidationManager
## @param _game_state The game state to validate
func _init(_game_state: FiveParsecsGameState) -> void:
    # Ensure resource has valid path for serialization
    if resource_path.is_empty():
        var timestamp = Time.get_unix_time_from_system()
        resource_path = "res://tests/generated/validation_manager_%d.tres" % timestamp
        
    game_state = _game_state
    error_logger = ErrorLogger.new()
    
    if not is_instance_valid(error_logger):
        push_error("Failed to create ErrorLogger instance")
        
    _valid_phases = GameEnums.CampaignPhase.values()
    _last_cache_clear_time = Time.get_unix_time_from_system()

## Validate the current game state
## @return Result dictionary with validation status
func validate_game_state() -> Dictionary:
    if _check_cache("game_state"):
        return _validation_cache.game_state
        
    var result = {
        "valid": true,
        "errors": [],
        "warnings": [],
        "context": "game_state"
    }
    
    if not game_state:
        result.valid = false
        result.errors.append("Game state is null")
        return _cache_result("game_state", result)
        
    if not is_instance_valid(game_state):
        result.valid = false
        result.errors.append("Game state is not a valid instance")
        return _cache_result("game_state", result)
    
    # Validate campaign data
    var campaign_result = validate_campaign()
    if not campaign_result.valid:
        result.valid = false
        result.errors.append_array(campaign_result.errors)
    
    # Validate phase state
    var phase_result = validate_phase_state()
    if not phase_result.valid:
        result.valid = false
        result.errors.append_array(phase_result.errors)
    
    # Validate crew
    var crew_result = validate_crew()
    if not crew_result.valid:
        result.valid = false
        result.errors.append_array(crew_result.errors)
    
    return _cache_result("game_state", result)

## Validate the active campaign
## @return Result dictionary with validation status
func validate_campaign() -> Dictionary:
    if _check_cache("campaign"):
        return _validation_cache.campaign
        
    var result = {
        "valid": true,
        "errors": [],
        "warnings": [],
        "context": "campaign"
    }
    
    if not game_state:
        result.valid = false
        result.errors.append("Game state is null")
        return _cache_result("campaign", result)
        
    if not is_instance_valid(game_state):
        result.valid = false
        result.errors.append("Game state is not a valid instance")
        return _cache_result("campaign", result)
    
    if not game_state.current_campaign:
        result.valid = false
        result.errors.append("No active campaign")
        return _cache_result("campaign", result)
        
    if not is_instance_valid(game_state.current_campaign):
        result.valid = false
        result.errors.append("Active campaign is not a valid instance")
        return _cache_result("campaign", result)
    
    # Validate campaign fields
    var campaign = game_state.current_campaign
    var required_fields = ["name", "difficulty", "story_points", "credits", "reputation"]
    
    for field in required_fields:
        # Replace get() with checking if property exists
        if field in campaign:
            if campaign[field] == null:
                result.valid = false
                result.errors.append("Required campaign field is null: " + field)
        else:
            result.valid = false
            result.errors.append("Missing required campaign field: " + field)
    
    # Validate campaign values
    if "credits" in campaign and campaign.credits < 0:
        result.valid = false
        result.errors.append("Invalid credits value: " + str(campaign.credits))
    
    if "reputation" in campaign and campaign.reputation < 0:
        result.valid = false
        result.errors.append("Invalid reputation value: " + str(campaign.reputation))
    
    if "story_points" in campaign and campaign.story_points < 0:
        result.valid = false
        result.errors.append("Invalid story points value: " + str(campaign.story_points))
    
    return _cache_result("campaign", result)

## Validate the current phase state
## @return Result dictionary with validation status
func validate_phase_state() -> Dictionary:
    if _check_cache("phase_state"):
        return _validation_cache.phase_state
        
    var result = {
        "valid": true,
        "errors": [],
        "warnings": [],
        "context": "phase_state"
    }
    
    if not game_state:
        result.valid = false
        result.errors.append("Game state is null")
        return _cache_result("phase_state", result)
        
    if not is_instance_valid(game_state):
        result.valid = false
        result.errors.append("Game state is not a valid instance")
        return _cache_result("phase_state", result)
    
    # Validate current phase
    if not "current_phase" in game_state or not game_state.current_phase in _valid_phases:
        result.valid = false
        var phase_value = "UNKNOWN"
        if "current_phase" in game_state:
            phase_value = str(game_state.current_phase)
        result.errors.append("Invalid current phase: " + phase_value)
    
    # Validate phase data
    if not "phase_data" in game_state or not game_state.phase_data:
        result.valid = false
        result.errors.append("Missing phase data")
    else:
        # Validate phase-specific data
        if "current_phase" in game_state:
            match game_state.current_phase:
                GameEnums.CampaignPhase.STORY:
                    if not _validate_story_phase_data(game_state.phase_data):
                        result.valid = false
                        result.errors.append("Invalid story phase data")
                GameEnums.CampaignPhase.CAMPAIGN:
                    if not _validate_campaign_phase_data(game_state.phase_data):
                        result.valid = false
                        result.errors.append("Invalid campaign phase data")
                # Add other phase validations...
    
    return _cache_result("phase_state", result)

## Validate the crew
## @return Result dictionary with validation status
func validate_crew() -> Dictionary:
    if _check_cache("crew"):
        return _validation_cache.crew
        
    var result = {
        "valid": true,
        "errors": [],
        "warnings": [],
        "context": "crew"
    }
    
    if not game_state:
        result.valid = false
        result.errors.append("Game state is null")
        return _cache_result("crew", result)
        
    if not is_instance_valid(game_state):
        result.valid = false
        result.errors.append("Game state is not a valid instance")
        return _cache_result("crew", result)
    
    if not "current_crew" in game_state or not game_state.current_crew:
        result.valid = false
        result.errors.append("No active crew")
        return _cache_result("crew", result)
        
    if not is_instance_valid(game_state.current_crew):
        result.valid = false
        result.errors.append("Current crew is not a valid instance")
        return _cache_result("crew", result)
    
    # Make sure the get_members method exists before calling it
    if not game_state.current_crew.has_method("get_members"):
        result.valid = false
        result.errors.append("Crew object missing get_members method")
        return _cache_result("crew", result)
    
    # Validate each crew member
    var members = game_state.current_crew.get_members()
    if not members:
        result.warnings.append("Crew is empty")
        return _cache_result("crew", result)
        
    for member in members:
        var member_result = _validate_crew_member(member)
        if not member_result.valid:
            result.valid = false
            for error in member_result.errors:
                result.errors.append("Crew member error: " + error)
    
    return _cache_result("crew", result)

## Validate a mission before starting
## @param mission The mission to validate
## @return Result dictionary with validation status
func validate_mission_start(mission: Mission) -> Dictionary:
    if not is_instance_valid(mission):
        return {
            "valid": false,
            "errors": ["Invalid mission instance"],
            "warnings": [],
            "context": "mission_start"
        }
        
    var mission_id = str(mission.get_instance_id())
    if _check_cache("mission_" + mission_id):
        return _validation_cache["mission_" + mission_id]
        
    var result = {
        "valid": true,
        "errors": [],
        "warnings": [],
        "context": "mission_start"
    }
    
    # Validate mission has required fields
    for field in MISSION_SCHEMA.required_fields:
        if not field in mission:
            result.valid = false
            result.errors.append("Missing required mission field: " + field)
    
    # Validate mission difficulty
    if "difficulty" in mission:
        var difficulty = mission.difficulty
        if difficulty < MISSION_SCHEMA.difficulty_range.min or difficulty > MISSION_SCHEMA.difficulty_range.max:
            result.valid = false
            result.errors.append("Invalid mission difficulty: " + str(difficulty))
    
    # Validate mission objectives
    if "objectives" in mission and mission.objectives:
        for objective in mission.objectives:
            if not "description" in objective or not "completed" in objective:
                result.valid = false
                result.errors.append("Invalid mission objective format")
                break
    
    # Validate crew readiness
    var crew_result = validate_crew()
    if not crew_result.valid:
        result.valid = false
        result.errors.append("Crew not ready for mission")
        result.errors.append_array(crew_result.errors)
    
    return _cache_result("mission_" + mission_id, result)

## Check if a result is cached
## @param key The cache key
## @return Whether the result is cached
func _check_cache(key: String) -> bool:
    # Check if we should clear the cache based on timeout
    var current_time = Time.get_unix_time_from_system()
    if current_time - _last_cache_clear_time > _cache_timeout:
        _validation_cache.clear()
        _last_cache_clear_time = current_time
        validation_cache_updated.emit()
        return false
    
    # Check if the key exists in the cache
    return key in _validation_cache

## Cache a validation result
## @param key The cache key
## @param result The result to cache
## @return The cached result
func _cache_result(key: String, result: Dictionary) -> Dictionary:
    _validation_cache[key] = result
    
    # If validation failed, emit signal
    if not result.valid:
        validation_failed.emit(result.context, result.errors)
    
    # Emit validation completed signal
    validation_completed.emit(result)
    
    return result

## Validate a crew member
## @param member The crew member to validate
## @return Result dictionary with validation status
func _validate_crew_member(member: Dictionary) -> Dictionary:
    var result = {
        "valid": true,
        "errors": [],
        "warnings": []
    }
    
    # Check required fields
    for field in CREW_SCHEMA.required_fields:
        if not field in member:
            result.valid = false
            result.errors.append("Missing required field: " + field)
    
    # Check stats
    if "stats" in member and member.stats:
        for stat_name in CREW_SCHEMA.stat_ranges:
            if not stat_name in member.stats:
                result.valid = false
                result.errors.append("Missing required stat: " + stat_name)
            else:
                var value = member.stats[stat_name]
                var range_data = CREW_SCHEMA.stat_ranges[stat_name]
                if value < range_data.min or value > range_data.max:
                    result.valid = false
                    result.errors.append("Invalid " + stat_name + " value: " + str(value))
    
    return result

## Validate story phase data
## @param phase_data The phase data to validate
## @return Whether the data is valid
func _validate_story_phase_data(phase_data: Dictionary) -> bool:
    if not phase_data:
        return false
        
    # Check for required fields
    var required_fields = ["current_story", "story_progress"]
    for field in required_fields:
        if not field in phase_data:
            return false
    
    # Check story progress is valid
    if "story_progress" in phase_data and (phase_data.story_progress < 0 or phase_data.story_progress > 100):
        return false
    
    return true

## Validate campaign phase data
## @param phase_data The phase data to validate
## @return Whether the data is valid
func _validate_campaign_phase_data(phase_data: Dictionary) -> bool:
    if not phase_data:
        return false
        
    # Check for required fields
    var required_fields = ["current_location", "available_missions", "completed_missions"]
    for field in required_fields:
        if not field in phase_data:
            return false
    
    # Check locations
    if "current_location" in phase_data and phase_data.current_location:
        if not phase_data.current_location is String and not phase_data.current_location is Dictionary:
            return false
    
    # Check missions array
    if "available_missions" in phase_data and not phase_data.available_missions is Array:
        return false
        
    if "completed_missions" in phase_data and not phase_data.completed_missions is Array:
        return false
    
    return true

## Clear the validation cache
func clear_cache() -> void:
    _validation_cache.clear()
    _last_cache_clear_time = Time.get_unix_time_from_system()
    validation_cache_updated.emit()
