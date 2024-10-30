class_name ValidationManager
extends Resource

enum ValidationError {
    NONE,
    INSUFFICIENT_RESOURCES,
    INVALID_CREW_SIZE,
    MISSING_REQUIREMENTS,
    FACTION_CONFLICT,
    INVALID_LOCATION,
    MISSION_TIME_EXPIRED,
    INVALID_ZONE_ACCESS
}

var game_state: GameState
var resource_manager: ResourceManager

func _init(_game_state: GameState) -> void:
    game_state = _game_state
    resource_manager = ResourceManager.new()
    resource_manager.game_state = game_state

func validate_mission_start(mission: Mission) -> Dictionary:
    var result = {
        "valid": true,
        "errors": [],
        "warnings": []
    }
    
    # Check crew requirements
    var crew_check = _validate_crew(mission)
    if crew_check.error != ValidationError.NONE:
        result.valid = false
        result.errors.append(crew_check)
    
    # Check resource requirements
    var resource_check = _validate_resources(mission)
    if resource_check.error != ValidationError.NONE:
        result.valid = false
        result.errors.append(resource_check)
    
    # Check zone access
    var zone_check = _validate_zone_access(mission)
    if zone_check.error != ValidationError.NONE:
        result.valid = false
        result.errors.append(zone_check)
    
    # Check faction requirements
    var faction_check = _validate_faction_relations(mission)
    if faction_check.error != ValidationError.NONE:
        result.warnings.append(faction_check)
    
    # Check mission time limit
    var time_check = _validate_time_limit(mission)
    if time_check.error != ValidationError.NONE:
        result.warnings.append(time_check)
    
    return result

func _validate_crew(mission: Mission) -> Dictionary:
    var result = {"error": ValidationError.NONE, "message": ""}
    
    if game_state.current_crew.size() < mission.required_crew_size:
        result.error = ValidationError.INVALID_CREW_SIZE
        result.message = "Insufficient crew size. Required: %d, Current: %d" % [
            mission.required_crew_size,
            game_state.current_crew.size()
        ]
    
    return result

func _validate_resources(mission: Mission) -> Dictionary:
    var result = {"error": ValidationError.NONE, "message": ""}
    
    if not resource_manager.validate_mission_resources(mission):
        result.error = ValidationError.INSUFFICIENT_RESOURCES
        result.message = "Insufficient resources for mission duration"
    
    return result

func _validate_zone_access(mission: Mission) -> Dictionary:
    var result = {"error": ValidationError.NONE, "message": ""}
    
    match mission.mission_type:
        GlobalEnums.Type.RED_ZONE:
            if not game_state.current_crew.has_red_zone_license:
                result.error = ValidationError.INVALID_ZONE_ACCESS
                result.message = "Red Zone License required"
        GlobalEnums.Type.BLACK_ZONE:
            if not game_state.current_crew.has_black_zone_access:
                result.error = ValidationError.INVALID_ZONE_ACCESS
                result.message = "Black Zone clearance required"
    
    return result

func _validate_faction_relations(mission: Mission) -> Dictionary:
    var result = {"error": ValidationError.NONE, "message": ""}
    
    if mission.faction:
        var standing = game_state.get_faction_standing(mission.faction)
        if standing < mission.faction.get("required_standing", 0):
            result.error = ValidationError.FACTION_CONFLICT
            result.message = "Insufficient faction standing"
    
    return result

func _validate_time_limit(mission: Mission) -> Dictionary:
    var result = {"error": ValidationError.NONE, "message": ""}
    
    if mission.time_limit <= 1:
        result.error = ValidationError.MISSION_TIME_EXPIRED
        result.message = "Mission time limit nearly expired"
    
    return result
