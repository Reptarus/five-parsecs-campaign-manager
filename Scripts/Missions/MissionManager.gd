# Scripts/Missions/MissionManager.gd
class_name MissionManager
extends Node

var game_state: GameStateManager

func _init(_game_state: GameStateManager):
    game_state = _game_state

func generate_missions() -> Array[Mission]:
    var missions: Array[Mission] = []
    missions.append_array(generate_standard_missions())
    missions.append_array(generate_patron_missions())
    
    if game_state.expanded_missions_enabled:
        missions.append_array(generate_stealth_missions())
        missions.append_array(generate_street_fight_missions())
        missions.append_array(generate_salvage_missions())
        missions.append_array(generate_fringe_world_strife_missions())
    
    return missions

func generate_standard_missions() -> Array[Mission]:
    var missions: Array[Mission] = []
    var num_missions = randi() % 3 + 1  # Generate 1-3 standard missions
    
    for i in range(num_missions):
        var mission = Mission.new()
        mission.type = GlobalEnums.Type.STANDARD
        mission.title = "Standard Mission " + str(i + 1)
        mission.description = "A standard mission in the current location."
        mission.objective = GlobalEnums.MissionObjective.values().pick_random()
        mission.difficulty = randi() % 5 + 1
        mission.time_limit = randi() % 5 + 3
        mission.location = game_state.current_location
        mission.rewards = generate_rewards(mission.difficulty)
        missions.append(mission)
    
    return missions

func generate_patron_missions() -> Array[Mission]:
    var missions: Array[Mission] = []
    
    for patron in game_state.patrons:
        if randf() < 0.3:  # 30% chance for each patron to offer a mission
            var mission = Mission.new()
            mission.type = GlobalEnums.Type.PATRON
            mission.title = patron.name + "'s Mission"
            mission.description = "A mission from " + patron.name
            mission.objective = GlobalEnums.MissionObjective.values().pick_random()
            mission.difficulty = randi() % 5 + 1
            mission.time_limit = randi() % 5 + 3
            mission.location = game_state.current_location
            mission.rewards = generate_rewards(mission.difficulty)
            mission.patron = patron
            missions.append(mission)
    
    return missions

func generate_stealth_missions() -> Array[Mission]:
    var missions: Array[Mission] = []
    if randf() < 0.2:  # 20% chance to generate a stealth mission
        var mission = Mission.new()
        mission.type = GlobalEnums.Type.INFILTRATION
        mission.title = "Stealth Operation"
        mission.description = "A covert mission requiring stealth and subterfuge."
        mission.objective = GlobalEnums.MissionObjective.INFILTRATION
        mission.difficulty = randi() % 5 + 1
        mission.time_limit = randi() % 3 + 2
        mission.location = game_state.current_location
        mission.rewards = generate_rewards(mission.difficulty)
        mission.detection_level = 0
        missions.append(mission)
    return missions

func generate_street_fight_missions() -> Array[Mission]:
    var missions: Array[Mission] = []
    if randf() < 0.2:  # 20% chance to generate a street fight mission
        var mission = Mission.new()
        mission.type = GlobalEnums.Type.STREET_FIGHT
        mission.title = "Street Brawl"
        mission.description = "A violent confrontation in the streets."
        mission.objective = GlobalEnums.MissionObjective.FIGHT_OFF
        mission.difficulty = randi() % 5 + 1
        mission.time_limit = 1
        mission.location = game_state.current_location
        mission.rewards = generate_rewards(mission.difficulty)
        mission.street_fight_type = GlobalEnums.StreetFightType.values().pick_random()
        missions.append(mission)
    return missions

func generate_salvage_missions() -> Array[Mission]:
    var missions: Array[Mission] = []
    if randf() < 0.2:  # 20% chance to generate a salvage mission
        var mission = Mission.new()
        mission.type = GlobalEnums.Type.SALVAGE_JOB
        mission.title = "Salvage Operation"
        mission.description = "A mission to recover valuable salvage from a dangerous location."
        mission.objective = GlobalEnums.MissionObjective.ACQUIRE
        mission.difficulty = randi() % 5 + 1
        mission.time_limit = randi() % 3 + 2
        mission.location = game_state.current_location
        mission.rewards = generate_rewards(mission.difficulty)
        mission.salvage_units = 0
        missions.append(mission)
    return missions

func generate_fringe_world_strife_missions() -> Array[Mission]:
    var missions: Array[Mission] = []
    if randf() < 0.1:  # 10% chance to generate a fringe world strife mission
        var mission = Mission.new()
        mission.type = GlobalEnums.Type.FRINGE_WORLD_STRIFE
        mission.title = "Fringe World Conflict"
        mission.description = "A mission to deal with rising tensions on a fringe world."
        mission.objective = GlobalEnums.MissionObjective.values().pick_random()
        mission.difficulty = randi() % 5 + 1
        mission.time_limit = randi() % 5 + 3
        mission.location = game_state.current_location
        mission.rewards = generate_rewards(mission.difficulty)
        mission.instability = GlobalEnums.FringeWorldInstability.values().pick_random()
        missions.append(mission)
    return missions

func generate_rewards(difficulty: int) -> Dictionary:
    var base_credits = 100 * difficulty
    return {
        "credits": base_credits + randi() % int(base_credits / 2.0),
        "reputation": difficulty,
        "item": randf() < 0.3  # 30% chance for item reward
    }

func resolve_mission(mission: Mission) -> bool:
    var success_chance = _calculate_success_chance(mission)
    var roll = randf()
    var success = roll < success_chance
    
    if success:
        _handle_mission_success(mission)
    else:
        _handle_mission_failure(mission)
    
    return success

func _calculate_success_chance(mission: Mission) -> float:
    var base_chance = 0.5
    var difficulty_modifier = 0.1 * (game_state.current_crew.get_average_level() - mission.difficulty)
    
    match mission.type:
        GlobalEnums.Type.INFILTRATION:
            base_chance = 0.4
            difficulty_modifier -= 0.1 * mission.detection_level
        GlobalEnums.Type.STREET_FIGHT:
            base_chance = 0.6
            difficulty_modifier = 0.1 * (game_state.current_crew.get_average_combat_skill() - mission.difficulty)
        GlobalEnums.Type.SALVAGE_JOB:
            difficulty_modifier = 0.1 * (game_state.current_crew.get_average_savvy() - mission.difficulty)
        GlobalEnums.Type.FRINGE_WORLD_STRIFE:
            base_chance = 0.4
            difficulty_modifier -= 0.05 * GlobalEnums.FringeWorldInstability.values().find(mission.instability)
    
    return base_chance + difficulty_modifier

func _handle_mission_success(mission: Mission) -> void:
    mission.complete()
    var reward_multiplier = 1.0
    var reputation_multiplier = 1.0
    
    match mission.type:
        GlobalEnums.Type.INFILTRATION:
            reward_multiplier = 1.2
        GlobalEnums.Type.STREET_FIGHT:
            reputation_multiplier = 1.5
        GlobalEnums.Type.SALVAGE_JOB:
            var salvage_value = mission.salvage_units * 50
            game_state.add_credits(salvage_value)
        GlobalEnums.Type.FRINGE_WORLD_STRIFE:
            reward_multiplier = 1.5
            reputation_multiplier = 2.0
            game_state.reduce_fringe_world_instability(mission.location)
    
    game_state.add_credits(int(mission.rewards["credits"] * reward_multiplier))
    game_state.add_reputation(int(mission.rewards["reputation"] * reputation_multiplier))
    if mission.rewards["item"]:
        game_state.add_random_item()

func _handle_mission_failure(mission: Mission) -> void:
    mission.fail()
    match mission.type:
        GlobalEnums.Type.STREET_FIGHT:
            game_state.add_crew_injury()
        GlobalEnums.Type.FRINGE_WORLD_STRIFE:
            game_state.increase_fringe_world_instability(mission.location)

func get_available_missions() -> Array[Mission]:
    return game_state.available_missions

func add_mission(mission: Mission) -> void:
    game_state.available_missions.append(mission)

func remove_mission(mission: Mission) -> void:
    game_state.available_missions.erase(mission)

func update_mission_timers() -> void:
    for mission in game_state.available_missions:
        mission.time_limit -= 1
        if mission.time_limit <= 0:
            remove_mission(mission)
            if mission.patron:
                mission.patron.change_relationship(-2)

func get_mission_by_type(type: GlobalEnums.Type) -> Array[Mission]:
    return game_state.available_missions.filter(func(m): return m.type == type)

func get_active_missions() -> Array[Mission]:
    return game_state.available_missions.filter(func(m): return m.status == GlobalEnums.MissionStatus.ACTIVE)

func get_completed_missions() -> Array[Mission]:
    return game_state.available_missions.filter(func(m): return m.status == GlobalEnums.MissionStatus.COMPLETED)

func get_failed_missions() -> Array[Mission]:
    return game_state.available_missions.filter(func(m): return m.status == GlobalEnums.MissionStatus.FAILED)
