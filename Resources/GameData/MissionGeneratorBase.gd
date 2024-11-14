class_name MissionGeneratorBase
extends Resource

var game_state: GameState

func _init(_game_state: GameState) -> void:
    game_state = _game_state

func _create_base_mission() -> Mission:
    var mission = Mission.new()
    mission.type = GlobalEnums.MissionType.OPPORTUNITY
    mission.objective = GlobalEnums.ObjectiveType.FIGHT_OFF
    mission.deployment_type = GlobalEnums.DeploymentType.LINE
    mission.victory_condition = GlobalEnums.VictoryConditionType.TURNS
    mission.ai_behavior = GlobalEnums.AIBehavior.TACTICAL
    mission.terrain_type = GlobalEnums.TerrainType.INDUSTRIAL
    
    # Set default values
    mission.difficulty = 1
    mission.time_limit = 3
    mission.required_crew_size = 4
    mission.rewards = {
        "credits": 100,
        "reputation": 1
    }
    
    return mission

func _validate_mission_requirements(mission: Mission) -> bool:
    # Basic validation
    if not mission:
        return false
        
    # Check crew size requirements
    if game_state.current_crew.get_member_count() < mission.required_crew_size:
        return false
        
    # Check mission type specific requirements
    match mission.type:
        GlobalEnums.MissionType.RED_ZONE:
            if not _check_red_zone_requirements():
                return false
        GlobalEnums.MissionType.BLACK_ZONE:
            if not _check_black_zone_requirements():
                return false
        GlobalEnums.MissionType.PATRON:
            if not _check_patron_requirements(mission):
                return false
    
    return true

func _check_red_zone_requirements() -> bool:
    return game_state.campaign_turns >= 10 and game_state.current_crew.get_member_count() >= 7

func _check_black_zone_requirements() -> bool:
    return _check_red_zone_requirements() and game_state.current_crew.has_red_zone_license

func _check_patron_requirements(mission: Mission) -> bool:
    if not mission.patron:
        return false
    return game_state.faction_standings.get(mission.patron.faction, 0) >= mission.patron.required_standing

func _generate_enemy_composition(difficulty: int) -> Array[Enemy]:
    var enemies: Array[Enemy] = []
    var base_count = difficulty + 1
    
    for i in range(base_count):
        var enemy_type = _select_enemy_type(difficulty)
        var enemy = Enemy.new()
        enemies.append(enemy)
    
    return enemies

func _select_enemy_type(difficulty: int) -> GlobalEnums.EnemyType:
    if difficulty >= 4:
        return GlobalEnums.EnemyType.ELITE
    elif difficulty >= 3:
        return GlobalEnums.EnemyType.SPECIALIST
    elif difficulty >= 2:
        return GlobalEnums.EnemyType.SUPPORT
    else:
        return GlobalEnums.EnemyType.GRUNT

func _generate_deployment_type(mission_type: GlobalEnums.MissionType) -> GlobalEnums.DeploymentType:
    match mission_type:
        GlobalEnums.MissionType.ASSASSINATION:
            return GlobalEnums.DeploymentType.CONCEALED
        GlobalEnums.MissionType.SABOTAGE:
            return GlobalEnums.DeploymentType.INFILTRATION
        GlobalEnums.MissionType.DEFENSE:
            return GlobalEnums.DeploymentType.DEFENSIVE
        GlobalEnums.MissionType.ESCORT:
            return GlobalEnums.DeploymentType.BOLSTERED_LINE
        _:
            return GlobalEnums.DeploymentType.LINE
