class_name UnifiedMissionGenerator
extends Resource

signal mission_generated(mission: Mission)

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")

var game_state: GameState
var rng := RandomNumberGenerator.new()

# Mission configuration constants
const BASE_REWARD_MULTIPLIER := 100
const DIFFICULTY_REWARD_MULTIPLIER := 1.5
const BASE_CREW_SIZE := 3
const MAX_MISSION_TIME_LIMIT := 10

func _init(_game_state: GameState = null) -> void:
    game_state = _game_state
    rng.randomize()

func generate_mission(params: Dictionary = {}) -> Mission:
    var mission = Mission.new()
    
    # Set base mission properties
    mission.mission_type = params.get("type", _random_mission_type())
    mission.difficulty = params.get("difficulty", _calculate_base_difficulty())
    
    # Setup mission based on type
    _setup_mission_by_type(mission)
    
    # Generate additional content
    _generate_objectives(mission)
    _generate_enemy_force(mission)
    _setup_deployment(mission)
    _calculate_rewards(mission)
    
    mission_generated.emit(mission)
    return mission

func generate_special_mission(mission_type: int) -> Mission:
    return generate_mission({"type": mission_type, "is_special": true})

func _setup_mission_by_type(mission: Mission) -> void:
    match mission.mission_type:
        GameEnums.MissionType.ASSASSINATION:
            _setup_assassination_mission(mission)
        GameEnums.MissionType.SABOTAGE:
            _setup_sabotage_mission(mission)
        GameEnums.MissionType.RESCUE:
            _setup_rescue_mission(mission)
        GameEnums.MissionType.DEFENSE:
            _setup_defense_mission(mission)
        GameEnums.MissionType.ESCORT:
            _setup_escort_mission(mission)
        _:
            _setup_standard_mission(mission)

func _setup_standard_mission(mission: Mission) -> void:
    mission.objective = GameEnums.MissionObjective.ELIMINATE
    mission.deployment_type = GameEnums.DeploymentType.STANDARD
    mission.victory_condition = GameEnums.VictoryConditionType.ELIMINATION
    mission.ai_behavior = GameEnums.AIBehavior.TACTICAL

func _setup_assassination_mission(mission: Mission) -> void:
    mission.objective = GameEnums.MissionObjective.ELIMINATE
    mission.deployment_type = GameEnums.DeploymentType.CONCEALED
    mission.victory_condition = GameEnums.VictoryConditionType.ELIMINATION
    mission.ai_behavior = GameEnums.AIBehavior.TACTICAL
    mission.difficulty += 2
    mission.rewards["credits"] = (mission.rewards.get("credits", 0) * 1.5) as int

func _setup_sabotage_mission(mission: Mission) -> void:
    mission.objective = GameEnums.MissionObjective.DESTROY
    mission.deployment_type = GameEnums.DeploymentType.INFILTRATION
    mission.victory_condition = GameEnums.VictoryConditionType.ELIMINATION
    mission.ai_behavior = GameEnums.AIBehavior.DEFENSIVE
    mission.difficulty += 1
    mission.rewards["reputation"] = mission.rewards.get("reputation", 0) + 1

func _setup_rescue_mission(mission: Mission) -> void:
    mission.objective = GameEnums.MissionObjective.RESCUE
    mission.deployment_type = GameEnums.DeploymentType.SCATTERED
    mission.victory_condition = GameEnums.VictoryConditionType.EXTRACTION
    mission.ai_behavior = GameEnums.AIBehavior.AGGRESSIVE
    mission.time_limit += 1

func _setup_defense_mission(mission: Mission) -> void:
    mission.objective = GameEnums.MissionObjective.DEFEND
    mission.deployment_type = GameEnums.DeploymentType.DEFENSIVE
    mission.victory_condition = GameEnums.VictoryConditionType.SURVIVAL
    mission.ai_behavior = GameEnums.AIBehavior.AGGRESSIVE
    mission.required_crew_size += 1

func _setup_escort_mission(mission: Mission) -> void:
    mission.objective = GameEnums.MissionObjective.ESCORT
    mission.deployment_type = GameEnums.DeploymentType.BOLSTERED_LINE
    mission.victory_condition = GameEnums.VictoryConditionType.EXTRACTION
    mission.ai_behavior = GameEnums.AIBehavior.TACTICAL
    mission.time_limit += 2

func _generate_objectives(mission: Mission) -> void:
    var primary_objective = _create_objective(mission.objective)
    var secondary_objective = _create_secondary_objective(mission.objective)
    
    mission.objectives = [primary_objective]
    if secondary_objective:
        mission.objectives.append(secondary_objective)

func _generate_enemy_force(mission: Mission) -> void:
    var force_size = _calculate_force_size(mission.difficulty)
    var enemy_types = _select_enemy_types(mission.mission_type)
    
    mission.enemy_force = {
        "size": force_size,
        "types": enemy_types,
        "equipment_level": mission.difficulty,
        "morale": _calculate_enemy_morale(mission)
    }

func _setup_deployment(mission: Mission) -> void:
    var deployment_zones = _calculate_deployment_zones(mission.deployment_type)
    var terrain_modifiers = _generate_terrain_modifiers(mission)
    
    mission.deployment = {
        "zones": deployment_zones,
        "terrain": terrain_modifiers,
        "restrictions": _get_deployment_restrictions(mission)
    }

func _calculate_rewards(mission: Mission) -> void:
    var base_reward = BASE_REWARD_MULTIPLIER * mission.difficulty
    var difficulty_bonus = (mission.difficulty * DIFFICULTY_REWARD_MULTIPLIER) as int
    
    mission.rewards = {
        "credits": base_reward + difficulty_bonus,
        "reputation": mission.difficulty,
        "equipment": _generate_equipment_rewards(mission)
    }

# Helper methods
func _random_mission_type() -> int:
    return rng.randi_range(0, GameEnums.MissionType.size() - 1)

func _calculate_base_difficulty() -> int:
    if not game_state:
        return 1
    return clamp(game_state.current_difficulty, 1, 5)

func _create_objective(objective_type: int) -> Dictionary:
    return {
        "type": objective_type,
        "description": _get_objective_description(objective_type),
        "completed": false
    }

func _create_secondary_objective(primary_type: int) -> Dictionary:
    var secondary_type = _get_compatible_secondary_objective(primary_type)
    if secondary_type != -1:
        return _create_objective(secondary_type)
    return {}

func _calculate_force_size(difficulty: int) -> int:
    return BASE_CREW_SIZE + difficulty

func _select_enemy_types(mission_type: int) -> Array:
    # Implementation depends on game's enemy type system
    return []

func _calculate_enemy_morale(mission: Mission) -> int:
    return 5 + mission.difficulty

func _calculate_deployment_zones(deployment_type: int) -> Array:
    # Implementation depends on game's deployment system
    return []

func _generate_terrain_modifiers(mission: Mission) -> Dictionary:
    # Implementation depends on game's terrain system
    return {}

func _get_deployment_restrictions(mission: Mission) -> Array:
    # Implementation depends on game's deployment rules
    return []

func _generate_equipment_rewards(mission: Mission) -> Array:
    # Implementation depends on game's equipment system
    return []

func _get_compatible_secondary_objective(primary_type: int) -> int:
    # Implementation depends on game's objective compatibility rules
    return -1

func _get_objective_description(objective_type: int) -> String:
    # Reuse the objective description logic from Mission class
    return Mission.new()._get_objective_description(objective_type) 