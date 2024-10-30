class_name CrewManager
extends Resource

var game_state: GameState

func _init(_game_state: GameState) -> void:
    game_state = _game_state

func validate_crew_for_mission(mission: Mission) -> Dictionary:
    var result = {
        "valid": true,
        "errors": [],
        "warnings": []
    }
    
    var available_members = game_state.current_crew.get_available_members_for_mission(mission)
    
    if available_members.size() < mission.required_crew_size:
        result.valid = false
        result.errors.append("Insufficient available crew members")
    
    # Check for required roles
    for required_role in mission.required_roles:
        var has_role = false
        for member in available_members:
            if member.role == required_role:
                has_role = true
                break
        if not has_role:
            result.warnings.append("Missing recommended role: " + str(required_role))
    
    # Check for hazard gear in red zone missions
    if mission.mission_type == GlobalEnums.Type.RED_ZONE:
        var has_hazard_gear = false
        for member in available_members:
            if member.has_hazard_gear():
                has_hazard_gear = true
                break
        if not has_hazard_gear:
            result.errors.append("Hazard gear required for Red Zone mission")
    
    return result

func assign_crew_to_mission(mission: Mission, selected_members: Array[Character]) -> bool:
    if selected_members.size() < mission.required_crew_size:
        return false
    
    for member in selected_members:
        member.mission_ready = false
        member.current_task = "On Mission: " + mission.title
    
    return true

func return_crew_from_mission(members: Array[Character]) -> void:
    for member in members:
        member.mission_ready = true
        member.current_task = ""
        if member.status == GlobalEnums.CharacterStatus.INJURED:
            member.decrease_morale()
