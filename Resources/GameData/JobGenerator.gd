class_name JobGenerator
extends MissionGeneratorBase

enum JobType {STANDARD, PATRON, RED_ZONE, BLACK_ZONE, OPPORTUNITY, RIVAL}

func generate_jobs(count: int, job_type: JobType = JobType.STANDARD) -> Array[Mission]:
    var available_jobs: Array[Mission] = []
    var current_world = game_state.world_generator.get_current_world()
    
    for _i in range(count):
        var job = _create_job(current_world, job_type)
        if _validate_mission_requirements(job):
            available_jobs.append(job)
    
    return available_jobs

func _create_job(world_data: Dictionary, job_type: JobType) -> Mission:
    var job = _create_base_mission()
    
    match job_type:
        JobType.PATRON:
            _apply_patron_job_modifiers(job)
        JobType.RED_ZONE:
            if !_check_red_zone_eligibility():
                return null
            _apply_red_zone_modifiers(job)
        JobType.BLACK_ZONE:
            if !_check_black_zone_eligibility():
                return null
            _apply_black_zone_modifiers(job)
        JobType.OPPORTUNITY:
            _apply_opportunity_modifiers(job)
        JobType.RIVAL:
            _apply_rival_modifiers(job)
        _:
            _apply_standard_job_modifiers(job, world_data)
    
    return job

func _apply_patron_job_modifiers(job: Mission) -> void:
    job.type = GlobalEnums.Type.PATRON
    job.difficulty += 1
    job.rewards["credits"] *= 1.2
    job.rewards["reputation"] += 1

func _check_red_zone_eligibility() -> bool:
    return game_state.campaign_turns >= 10 and game_state.current_crew.get_member_count() >= 7

func _apply_red_zone_modifiers(job: Mission) -> void:
    job.type = GlobalEnums.Type.RED_ZONE
    job.difficulty += 2
    job.rewards["credits"] *= 1.5
    job.required_crew_size += 1

func _check_black_zone_eligibility() -> bool:
    return _check_red_zone_eligibility() and game_state.current_crew.has_red_zone_license

func _apply_black_zone_modifiers(job: Mission) -> void:
    job.type = GlobalEnums.Type.BLACK_ZONE
    job.difficulty += 3
    job.rewards["credits"] *= 2.0
    job.required_crew_size += 2
    job.setup_black_zone_opposition()

func _apply_opportunity_modifiers(job: Mission) -> void:
    job.type = GlobalEnums.Type.OPPORTUNITY
    job.time_limit = randi() % 2 + 2  # 2-3 turns
    job.rewards["credits"] *= 1.1

func _apply_rival_modifiers(job: Mission) -> void:
    job.type = GlobalEnums.Type.RIVAL
    job.difficulty += 1
    job.rewards["reputation"] += 2
    job.required_crew_size = game_state.current_crew.get_member_count()

func _apply_standard_job_modifiers(job: Mission, world_data: Dictionary) -> void:
    job.type = _get_job_type_for_world(world_data)
    job.difficulty = _calculate_difficulty_for_world(world_data)
    job.rewards = _calculate_rewards(job.difficulty)
    job.required_crew_size = _calculate_required_crew_size()

func _calculate_difficulty_for_world(world_data: Dictionary) -> int:
    var base_difficulty = randi() % 3 + 1
    if world_data.type == GlobalEnums.Background.HIGH_TECH_COLONY:
        base_difficulty += 1
    return base_difficulty

func _calculate_required_crew_size() -> int:
    return maxi(2, game_state.current_crew.get_member_count() - 1)

func _get_job_type_for_world(world_data: Dictionary) -> GlobalEnums.Type:
    var possible_types = []
    match world_data.type:
        GlobalEnums.Background.MINING_COLONY:
            possible_types = [
                GlobalEnums.Type.RESCUE,
                GlobalEnums.Type.DEFENSE,
                GlobalEnums.Type.ESCORT
            ]
        GlobalEnums.Background.HIGH_TECH_COLONY:
            possible_types = [
                GlobalEnums.Type.SABOTAGE,
                GlobalEnums.Type.ASSASSINATION,
                GlobalEnums.Type.QUEST
            ]
        _:
            possible_types = [GlobalEnums.Type.OPPORTUNITY]
    
    return possible_types.pick_random()

func _calculate_rewards(difficulty: int) -> Dictionary:
    var base_credits = difficulty * 100
    var base_reputation = difficulty
    
    # Add random variation to credits
    var credits = base_credits + randi() % int(base_credits * 0.5)
    
    # Add potential bonus rewards based on difficulty
    var rewards = {
        "credits": credits,
        "reputation": base_reputation
    }
    
    # Add special rewards for higher difficulties
    if difficulty >= 3:
        rewards["item"] = true
    if difficulty >= 4:
        rewards["story_points"] = 1
        
    return rewards
