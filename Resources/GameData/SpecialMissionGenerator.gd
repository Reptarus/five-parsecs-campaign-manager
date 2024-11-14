class_name SpecialMissionGenerator
extends MissionGeneratorBase

func generate_special_mission(mission_type: GlobalEnums.MissionType) -> Mission:
    var mission = Mission.new()
    mission.type = mission_type
    
    match mission_type:
        GlobalEnums.MissionType.ASSASSINATION:
            _setup_assassination_mission(mission)
        GlobalEnums.MissionType.SABOTAGE:
            _setup_sabotage_mission(mission)
        GlobalEnums.MissionType.RESCUE:
            _setup_rescue_mission(mission)
        GlobalEnums.MissionType.DEFENSE:
            _setup_defense_mission(mission)
        GlobalEnums.MissionType.ESCORT:
            _setup_escort_mission(mission)
    
    return mission

func _setup_assassination_mission(mission: Mission) -> void:
    mission.objective = GlobalEnums.MissionObjective.ELIMINATE
    mission.deployment_type = GlobalEnums.DeploymentType.CONCEALED
    mission.victory_condition = GlobalEnums.VictoryConditionType.ELIMINATION
    mission.ai_behavior = GlobalEnums.AIBehavior.TACTICAL
    mission.difficulty += 2
    mission.rewards["credits"] *= 1.5

func _setup_sabotage_mission(mission: Mission) -> void:
    mission.objective = GlobalEnums.MissionObjective.DESTROY
    mission.deployment_type = GlobalEnums.DeploymentType.INFILTRATION
    mission.victory_condition = GlobalEnums.VictoryConditionType.ELIMINATION
    mission.ai_behavior = GlobalEnums.AIBehavior.DEFENSIVE
    mission.difficulty += 1
    mission.rewards["reputation"] += 1

func _setup_rescue_mission(mission: Mission) -> void:
    mission.objective = GlobalEnums.MissionObjective.RESCUE
    mission.deployment_type = GlobalEnums.DeploymentType.SCATTERED
    mission.victory_condition = GlobalEnums.VictoryConditionType.EXTRACTION
    mission.ai_behavior = GlobalEnums.AIBehavior.AGGRESSIVE
    mission.time_limit += 1

func _setup_defense_mission(mission: Mission) -> void:
    mission.objective = GlobalEnums.MissionObjective.DEFEND
    mission.deployment_type = GlobalEnums.DeploymentType.DEFENSIVE
    mission.victory_condition = GlobalEnums.VictoryConditionType.SURVIVAL
    mission.ai_behavior = GlobalEnums.AIBehavior.AGGRESSIVE
    mission.required_crew_size += 1

func _setup_escort_mission(mission: Mission) -> void:
    mission.objective = GlobalEnums.MissionObjective.ESCORT
    mission.deployment_type = GlobalEnums.DeploymentType.BOLSTERED_LINE
    mission.victory_condition = GlobalEnums.VictoryConditionType.EXTRACTION
    mission.ai_behavior = GlobalEnums.AIBehavior.TACTICAL
    mission.time_limit += 2
