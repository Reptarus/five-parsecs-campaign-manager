class_name MissionGenerator
extends MissionGeneratorBase

const MISSION_TYPES = {
    GlobalEnums.MissionType.GREEN_ZONE: {
        "min_difficulty": 1,
        "max_difficulty": 2,
        "reward_multiplier": 1.0,
        "enemy_types": ["GRUNT", "PUNKS", "RAIDERS"],
        "deployment_types": [
            GlobalEnums.DeploymentType.STANDARD,
            GlobalEnums.DeploymentType.LINE
        ]
    },
    GlobalEnums.MissionType.YELLOW_ZONE: {
        "min_difficulty": 2,
        "max_difficulty": 3,
        "reward_multiplier": 1.5,
        "enemy_types": ["CULTISTS", "ANARCHISTS", "PIRATES"],
        "deployment_types": [
            GlobalEnums.DeploymentType.FLANK,
            GlobalEnums.DeploymentType.SCATTERED
        ]
    },
    GlobalEnums.MissionType.RED_ZONE: {
        "min_difficulty": 3,
        "max_difficulty": 4,
        "reward_multiplier": 2.0,
        "enemy_types": ["TECH_GANGERS", "ENFORCERS", "BLACK_OPS"],
        "deployment_types": [
            GlobalEnums.DeploymentType.DEFENSIVE,
            GlobalEnums.DeploymentType.CONCEALED
        ]
    }
}

func generate_mission_for_location(location: Planet, difficulty_override: int = -1) -> Mission:
    var mission = Mission.new()
    
    # Determine mission type based on location and threat level
    mission.mission_type = _determine_mission_type(location)
    
    # Set difficulty
    mission.difficulty = difficulty_override if difficulty_override >= 0 else _calculate_difficulty(location, mission.mission_type)
    
    # Generate mission parameters
    _generate_objectives(mission, location)
    _generate_enemy_force(mission, location)
    _setup_deployment(mission)
    _calculate_rewards(mission, location)
    
    return mission

func _determine_mission_type(location: Planet) -> int:
    var available_types = []
    
    # Add mission types based on threat level
    if location.threat_level >= 3:
        available_types.append(GlobalEnums.MissionType.RED_ZONE)
    elif location.threat_level >= 2:
        available_types.append(GlobalEnums.MissionType.YELLOW_ZONE)
    else:
        available_types.append(GlobalEnums.MissionType.GREEN_ZONE)
    
    # Add special mission types based on location traits
    if GlobalEnums.WorldTrait.MILITARY_PRESENCE in location.traits or \
       GlobalEnums.WorldTrait.MILITARY_BASE in location.traits:
        available_types.append(GlobalEnums.MissionType.BLACK_ZONE)
    
    return available_types[randi() % available_types.size()]

func _calculate_difficulty(location: Planet, mission_type: int) -> int:
    var mission_config = MISSION_TYPES[mission_type]
    var base_difficulty = mission_config.min_difficulty
    
    # Adjust for location traits
    if GlobalEnums.WorldTrait.PIRATE_HAVEN in location.traits or \
       GlobalEnums.WorldTrait.LAWLESS in location.traits:
        base_difficulty += 1
    if GlobalEnums.WorldTrait.MILITARY_PRESENCE in location.traits or \
       GlobalEnums.WorldTrait.MILITARY_BASE in location.traits:
        base_difficulty += 1
    
    # Clamp to mission type limits
    return clampi(base_difficulty, mission_config.min_difficulty, mission_config.max_difficulty)

# Override base class methods
func _get_mission_config(mission_type: int) -> Dictionary:
    return MISSION_TYPES[mission_type]

# ... continue with other mission generation methods ... 