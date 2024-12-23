class_name ValidationManager
extends Node

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState := preload("res://src/data/resources/GameState/GameState.gd")

var game_state: FiveParsecsGameState

func _init(_game_state: FiveParsecsGameState) -> void:
    game_state = _game_state

func validate_mission_start(mission: Mission) -> Dictionary:
    var result = {
        "valid": true,
        "errors": []
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
    
    return result

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

# Add robust error handling
func validate_game_state() -> Dictionary:
    var validation = {"valid": true, "errors": []}
    
    if not game_state:
        validation.valid = false
        validation.errors.append("Game state is null")
    
    return validation
