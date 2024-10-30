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

func _check_red_zone_eligibility() -> bool:
    return game_state.campaign_turns >= 10 and game_state.current_crew.get_member_count() >= 7

func _check_black_zone_eligibility() -> bool:
    return _check_red_zone_eligibility() and game_state.current_crew.has_red_zone_license

func _apply_standard_job_modifiers(job: Mission, world_data: Dictionary) -> void:
    job.type = _get_job_type_for_world(world_data)
    job.difficulty = _calculate_difficulty_for_world(world_data)
    job.rewards = _calculate_rewards(job.difficulty)
    job.required_crew_size = _calculate_required_crew_size()

func _apply_patron_job_modifiers(job: Mission) -> void:
    var patron = _select_available_patron()
    if patron:
        job.type = GlobalEnums.Type.PATRON
        job.patron = patron
        var conditions = _generate_patron_conditions(patron)
        job.benefits = conditions.benefits
        job.hazards = conditions.hazards
        job.conditions = conditions.conditions
        _modify_rewards(job, 1.2)  # 20% bonus for patron missions

func _apply_opportunity_modifiers(job: Mission) -> void:
    job.type = GlobalEnums.Type.OPPORTUNITY
    job.title = "Opportunity Mission"
    job.description = "A sudden opportunity has arisen"
    job.objective = GlobalEnums.MissionObjective.values().pick_random()
    _modify_rewards(job, 1.1)  # 10% bonus for opportunity missions

func _apply_rival_modifiers(job: Mission) -> void:
    job.type = GlobalEnums.Type.RIVAL
    job.title = "Rival Confrontation"
    job.description = "A rival crew is causing trouble"
    job.objective = GlobalEnums.MissionObjective.FIGHT_OFF
    job.required_crew_size = game_state.current_ship.crew.size()
    _modify_rewards(job, 1.3)  # 30% bonus for rival missions

func _get_job_type_for_world(world_data: Dictionary) -> int:
    var possible_types = []
    match world_data.type:
        GlobalEnums.Background.MINING_COLONY:
            possible_types = [
                GlobalEnums.MissionType.RESOURCE_GATHERING,
                GlobalEnums.MissionType.SITE_DEFENSE,
                GlobalEnums.MissionType.ESCORT
            ]
        GlobalEnums.Background.HIGH_TECH_COLONY:
            possible_types = [
                GlobalEnums.MissionType.DATA_RETRIEVAL,
                GlobalEnums.MissionType.TECH_RECOVERY,
                GlobalEnums.MissionType.SABOTAGE
            ]
        _:
            possible_types = [GlobalEnums.MissionType.PATROL]
    
    return possible_types.pick_random()

func _select_available_patron() -> Patron:
    var available_patrons = game_state.patrons.filter(func(p): return _can_generate_patron_job(p))
    return available_patrons.pick_random() if available_patrons.size() > 0 else null

func _can_generate_patron_job(patron: Patron) -> bool:
    return randf() < 0.2 + (patron.relationship / 200.0)

func _calculate_difficulty_for_world(world_data: Dictionary) -> int:
    var base_difficulty = _calculate_base_difficulty()
    match world_data.type:
        GlobalEnums.Background.HIGH_TECH_COLONY:
            base_difficulty += 1
        GlobalEnums.Background.MINING_COLONY:
            base_difficulty += randi() % 2
    return base_difficulty
