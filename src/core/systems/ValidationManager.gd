extends Resource

signal validation_completed(result: Dictionary)
signal validation_failed(context: String, errors: Array)
signal validation_cache_updated

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
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

func _init(_game_state: FiveParsecsGameState) -> void:
    game_state = _game_state
    error_logger = ErrorLogger.new()
    _valid_phases = GameEnums.CampaignPhase.values()
    _last_cache_clear_time = Time.get_unix_time_from_system()

# Main validation functions
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

func validate_campaign() -> Dictionary:
    if _check_cache("campaign"):
        return _validation_cache.campaign
        
    var result = {
        "valid": true,
        "errors": [],
        "warnings": [],
        "context": "campaign"
    }
    
    if not game_state.current_campaign:
        result.valid = false
        result.errors.append("No active campaign")
        return _cache_result("campaign", result)
    
    # Validate campaign fields
    var campaign = game_state.current_campaign
    var required_fields = ["name", "difficulty", "story_points", "credits", "reputation"]
    
    for field in required_fields:
        if not campaign.get(field):
            result.valid = false
            result.errors.append("Missing required campaign field: " + field)
    
    # Validate campaign values
    if campaign.credits < 0:
        result.valid = false
        result.errors.append("Invalid credits value")
    
    if campaign.reputation < 0:
        result.valid = false
        result.errors.append("Invalid reputation value")
    
    if campaign.story_points < 0:
        result.valid = false
        result.errors.append("Invalid story points value")
    
    return _cache_result("campaign", result)

func validate_phase_state() -> Dictionary:
    if _check_cache("phase_state"):
        return _validation_cache.phase_state
        
    var result = {
        "valid": true,
        "errors": [],
        "warnings": [],
        "context": "phase_state"
    }
    
    # Validate current phase
    if not game_state.current_phase in _valid_phases:
        result.valid = false
        result.errors.append("Invalid current phase")
    
    # Validate phase data
    if not game_state.phase_data:
        result.valid = false
        result.errors.append("Missing phase data")
    else:
        # Validate phase-specific data
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

func validate_crew() -> Dictionary:
    if _check_cache("crew"):
        return _validation_cache.crew
        
    var result = {
        "valid": true,
        "errors": [],
        "warnings": [],
        "context": "crew"
    }
    
    if not game_state.current_crew:
        result.valid = false
        result.errors.append("No active crew")
        return _cache_result("crew", result)
    
    # Validate each crew member
    for member in game_state.current_crew.get_members():
        var member_result = _validate_crew_member(member)
        if not member_result.valid:
            result.valid = false
            result.errors.append_array(member_result.errors)
    
    return _cache_result("crew", result)

func validate_mission_start(mission: Mission) -> Dictionary:
    if _check_cache("mission_" + str(mission.get_instance_id())):
        return _validation_cache["mission_" + str(mission.get_instance_id())]
        
    var result = {
        "valid": true,
        "errors": [],
        "warnings": [],
        "context": "mission"
    }
    
    # Check crew size
    if game_state.current_crew.get_member_count() < mission.required_crew_size:
        result.valid = false
        result.errors.append("Not enough crew members")
    
    # Check mission type requirements
    match mission.mission_type:
        GameEnums.MissionType.RED_ZONE:
            if not _validate_red_zone_requirements():
                result.valid = false
                result.errors.append("Red Zone requirements not met")
        GameEnums.MissionType.BLACK_ZONE:
            if not _validate_black_zone_requirements():
                result.valid = false
                result.errors.append("Black Zone requirements not met")
        GameEnums.MissionType.PATRON:
            if not _validate_patron_requirements(mission):
                result.valid = false
                result.errors.append("Patron requirements not met")
    
    # Check deployment requirements
    if not _validate_deployment_requirements(mission.deployment_type):
        result.valid = false
        result.errors.append("Deployment requirements not met")
    
    return _cache_result("mission_" + str(mission.get_instance_id()), result)

# Private helper functions
func _validate_crew_member(member: Character) -> Dictionary:
    var result = {"valid": true, "errors": []}
    
    # Check required fields
    for field in CREW_SCHEMA.required_fields:
        if not member.get(field):
            result.valid = false
            result.errors.append("Missing required field: " + field)
    
    # Validate stats
    if member.has("stats"):
        for stat_name in CREW_SCHEMA.stat_ranges:
            var value = member.stats.get(stat_name, 0)
            var range = CREW_SCHEMA.stat_ranges[stat_name]
            if value < range.min or value > range.max:
                result.valid = false
                result.errors.append("Invalid " + stat_name + " value")
    
    return result

func _validate_story_phase_data(data: Dictionary) -> bool:
    return data.has("available_events") and data.has("selected_event")

func _validate_campaign_phase_data(data: Dictionary) -> bool:
    return data.has("available_missions") and data.has("current_location")

func _validate_red_zone_requirements() -> bool:
    return game_state.campaign_turns >= 10 and game_state.current_crew.get_member_count() >= 7

func _validate_black_zone_requirements() -> bool:
    return _validate_red_zone_requirements() and game_state.current_crew.has_red_zone_license

func _validate_patron_requirements(mission: Mission) -> bool:
    if not mission.patron:
        return false
    return game_state.faction_standings.get(mission.patron.faction, 0) >= mission.patron.required_standing

func _validate_deployment_requirements(deployment_type: GameEnums.DeploymentType) -> bool:
    match deployment_type:
        GameEnums.DeploymentType.INFILTRATION, GameEnums.DeploymentType.CONCEALED:
            return game_state.current_crew.has_stealth_specialist()
        GameEnums.DeploymentType.BOLSTERED_LINE, GameEnums.DeploymentType.LINE:
            return game_state.current_crew.get_member_count() >= 5
        _:
            return true

# Cache management
func _check_cache(key: String) -> bool:
    var current_time = Time.get_unix_time_from_system()
    
    # Clear cache if timeout has elapsed
    if current_time - _last_cache_clear_time > _cache_timeout:
        _clear_validation_cache()
        _last_cache_clear_time = current_time
        
    return _validation_cache.has(key) and current_time - _validation_cache[key].timestamp < _cache_timeout

func _cache_result(key: String, result: Dictionary) -> Dictionary:
    result.timestamp = Time.get_unix_time_from_system()
    _validation_cache[key] = result
    validation_cache_updated.emit()
    
    if not result.valid:
        validation_failed.emit(result.context, result.errors)
        # Log each error
        for error in result.errors:
            error_logger.log_error(
                error,
                ErrorLogger.ErrorCategory.VALIDATION,
                ErrorLogger.ErrorSeverity.ERROR if result.context != "game_state" else ErrorLogger.ErrorSeverity.CRITICAL,
                {
                    "context": result.context,
                    "validation_key": key,
                    "warnings": result.warnings
                }
            )
    
    return result

func _clear_validation_cache() -> void:
    _validation_cache.clear()
    validation_cache_updated.emit()
