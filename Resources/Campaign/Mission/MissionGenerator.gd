class_name MissionGenerator
extends Resource

const MISSION_TYPES = {
    "patrol": {
        "base_reward": 100,
        "difficulty_modifier": 1.2,
        "min_threat": 1,
        "max_threat": 3
    },
    "rescue": {
        "base_reward": 150,
        "difficulty_modifier": 1.5,
        "min_threat": 2,
        "max_threat": 4
    },
    "assassination": {
        "base_reward": 200,
        "difficulty_modifier": 1.8,
        "min_threat": 3,
        "max_threat": 5
    },
    "escort": {
        "base_reward": 120,
        "difficulty_modifier": 1.3,
        "min_threat": 1,
        "max_threat": 4
    },
    "sabotage": {
        "base_reward": 180,
        "difficulty_modifier": 1.6,
        "min_threat": 2,
        "max_threat": 5
    }
}

const JOB_TYPES = {
    "bounty": {
        "base_reward": 250,
        "difficulty_modifier": 2.0,
        "requires_license": true,
        "reputation_gain": 2
    },
    "smuggling": {
        "base_reward": 300,
        "difficulty_modifier": 1.7,
        "requires_license": false,
        "reputation_loss": 1
    },
    "exploration": {
        "base_reward": 200,
        "difficulty_modifier": 1.4,
        "requires_license": false,
        "reputation_gain": 1
    },
    "investigation": {
        "base_reward": 180,
        "difficulty_modifier": 1.5,
        "requires_license": true,
        "reputation_gain": 1
    }
}

var rng = RandomNumberGenerator.new()

func _init() -> void:
    rng.randomize()

func generate_mission(location: Location, difficulty: int = 1) -> Mission:
    var mission_type = _select_mission_type(location)
    var mission_data = MISSION_TYPES[mission_type]
    
    var reward = _calculate_reward(mission_data.base_reward, difficulty, mission_data.difficulty_modifier)
    var threat_level = clampi(
        rng.randi_range(mission_data.min_threat, mission_data.max_threat) + difficulty - 1,
        1, 5
    )
    
    var mission = Mission.new()
    mission.type = mission_type
    mission.difficulty = difficulty
    mission.reward = reward
    mission.threat_level = threat_level
    mission.location = location
    
    _add_mission_objectives(mission)
    _add_mission_complications(mission, difficulty)
    
    return mission

func generate_job(location: Location, reputation: int = 0) -> Dictionary:
    var available_jobs = JOB_TYPES.keys()
    if reputation < 3:  # Filter out jobs requiring licenses for low reputation
        available_jobs = available_jobs.filter(
            func(job): return !JOB_TYPES[job].requires_license
        )
    
    var job_type = available_jobs[rng.randi() % available_jobs.size()]
    var job_data = JOB_TYPES[job_type]
    
    var difficulty = _calculate_job_difficulty(location, reputation)
    var reward = _calculate_reward(job_data.base_reward, difficulty, job_data.difficulty_modifier)
    
    var job = {
        "type": job_type,
        "difficulty": difficulty,
        "reward": reward,
        "location": location,
        "requires_license": job_data.requires_license,
        "reputation_change": job_data.get("reputation_gain", 0) - job_data.get("reputation_loss", 0),
        "objectives": _generate_job_objectives(job_type, difficulty),
        "complications": _generate_job_complications(difficulty),
        "time_limit": _calculate_time_limit(job_type, difficulty)
    }
    
    return job

func _select_mission_type(location: Location) -> String:
    var available_types = MISSION_TYPES.keys()
    
    # Filter based on location type and faction
    match location.type:
        GlobalEnums.TerrainType.CITY:
            # Prefer urban missions
            if randf() < 0.7:
                available_types = ["patrol", "rescue", "assassination"]
        GlobalEnums.TerrainType.WILDERNESS:
            # Prefer wilderness missions
            if randf() < 0.7:
                available_types = ["escort", "sabotage"]
    
    # Factor in location faction
    if location.faction == GlobalEnums.FactionType.HOSTILE:
        # Increase chance of combat missions
        if randf() < 0.6:
            available_types = available_types.filter(
                func(type): return type in ["assassination", "sabotage"]
            )
    
    return available_types[rng.randi() % available_types.size()]

func _calculate_reward(base_reward: int, difficulty: int, modifier: float) -> int:
    var reward = base_reward * pow(modifier, difficulty - 1)
    reward *= (1.0 + randf_range(-0.1, 0.1))  # Add some randomness
    return roundi(reward)

func _add_mission_objectives(mission: Mission) -> void:
    match mission.type:
        "patrol":
            mission.objectives.append({
                "type": "patrol",
                "description": "Patrol the designated area",
                "target_points": rng.randi_range(3, 5)
            })
        "rescue":
            mission.objectives.append({
                "type": "rescue",
                "description": "Rescue the target",
                "target_count": 1
            })
        "assassination":
            mission.objectives.append({
                "type": "eliminate",
                "description": "Eliminate the target",
                "target_count": 1
            })
        "escort":
            mission.objectives.append({
                "type": "escort",
                "description": "Escort the VIP to safety",
                "target_points": 1
            })
        "sabotage":
            mission.objectives.append({
                "type": "sabotage",
                "description": "Sabotage the target",
                "target_count": rng.randi_range(1, 2)
            })

func _add_mission_complications(mission: Mission, difficulty: int) -> void:
    var complication_count = difficulty - 1
    if complication_count <= 0:
        return
    
    var possible_complications = [
        "reinforcements",
        "time_limit",
        "hazardous_terrain",
        "civilian_presence",
        "security_systems"
    ]
    
    for i in range(complication_count):
        if possible_complications.is_empty():
            break
        var complication_index = rng.randi() % possible_complications.size()
        var complication = possible_complications[complication_index]
        possible_complications.remove_at(complication_index)
        
        mission.complications.append({
            "type": complication,
            "severity": rng.randi_range(1, difficulty)
        })

func _calculate_job_difficulty(location: Location, reputation: int) -> int:
    var base_difficulty = 1
    
    # Factor in location threat level
    base_difficulty += location.threat_level - 1
    
    # Factor in reputation
    base_difficulty += floori(reputation / 3.0)
    
    # Add some randomness
    base_difficulty += rng.randi_range(-1, 1)
    
    return clampi(base_difficulty, 1, 5)

func _generate_job_objectives(job_type: String, difficulty: int) -> Array:
    var objectives = []
    
    match job_type:
        "bounty":
            objectives.append({
                "type": "capture",
                "description": "Capture or eliminate the target",
                "target_count": difficulty > 3 if 2 else 1
            })
        "smuggling":
            objectives.append({
                "type": "deliver",
                "description": "Deliver the cargo",
                "cargo_value": difficulty * 100
            })
        "exploration":
            objectives.append({
                "type": "explore",
                "description": "Map the unknown region",
                "area_size": difficulty * 2
            })
        "investigation":
            objectives.append({
                "type": "investigate",
                "description": "Gather evidence",
                "clue_count": difficulty + 1
            })
    
    return objectives

func _generate_job_complications(difficulty: int) -> Array:
    var complications = []
    var complication_count = difficulty - 1
    
    if complication_count <= 0:
        return complications
    
    var possible_complications = [
        "rival_interference",
        "weather_conditions",
        "equipment_malfunction",
        "local_authority_interest",
        "time_sensitive"
    ]
    
    for i in range(complication_count):
        if possible_complications.is_empty():
            break
        var complication_index = rng.randi() % possible_complications.size()
        var complication = possible_complications[complication_index]
        possible_complications.remove_at(complication_index)
        
        complications.append({
            "type": complication,
            "severity": rng.randi_range(1, difficulty)
        })
    
    return complications

func _calculate_time_limit(job_type: String, difficulty: int) -> int:
    var base_time = 0
    
    match job_type:
        "bounty":
            base_time = 48  # Hours
        "smuggling":
            base_time = 24
        "exploration":
            base_time = 72
        "investigation":
            base_time = 36
    
    # Adjust based on difficulty
    base_time = base_time * (1.0 - (difficulty - 1) * 0.1)  # Reduce time for higher difficulties
    
    return roundi(base_time)