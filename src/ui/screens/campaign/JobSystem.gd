class_name JobSystem
extends Node

const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal job_generated(job: Mission)
signal job_completed(job: Mission)
signal job_failed(job: Mission)

var game_state: FiveParsecsGameState
var patron_jobs: Array[Mission] = []
var red_zone_jobs: Array[Mission] = []
var black_zone_jobs: Array[Mission] = []

# Consolidate from PatronJobManager and RedZoneJobManager
func _init(_game_state: FiveParsecsGameState) -> void:
    game_state = _game_state

func generate_job(job_type: GameEnums.MissionType) -> Mission:
    var job: Mission
    match job_type:
        GameEnums.MissionType.PATRON:
            job = _generate_patron_job()
        GameEnums.MissionType.RED_ZONE:
            job = _generate_red_zone_job()
        GameEnums.MissionType.BLACK_ZONE:
            job = _generate_black_zone_job()
        _:
            job = _generate_standard_job()
    
    if job:
        job_generated.emit(job)
    return job

func accept_job(job: Mission) -> bool:
    if not _validate_job_requirements(job):
        return false
        
    game_state.current_mission = job
    _remove_from_available_jobs(job)
    return true
func complete_job(job: Mission) -> void:
    job.complete(true) # Pass true to indicate successful completion
    _apply_job_rewards(job)
    if job.patron:
        job.patron.change_relationship(10)
    game_state.current_mission = null
    job_completed.emit(job)
func fail_job(job: Mission) -> void:
    job.fail(false) # Pass false to indicate failure
    if job.patron:
        job.patron.change_relationship(-5)
    game_state.current_mission = null
    _apply_failure_consequences(job)
    job_failed.emit(job)

# Private helper methods
func _validate_job_requirements(job: Mission) -> bool:
    match job.mission_type:
        GameEnums.MissionType.RED_ZONE:
            return _check_red_zone_requirements()
        GameEnums.MissionType.BLACK_ZONE:
            return _check_black_zone_requirements()
        GameEnums.MissionType.PATRON:
            return _check_patron_requirements(job)
        _:
            return true

func _check_red_zone_requirements() -> bool:
    return game_state.campaign_turn >= 10 and game_state.current_crew.get_member_count() >= 7

func _check_black_zone_requirements() -> bool:
    return _check_red_zone_requirements() and game_state.current_crew.has_red_zone_license

func _check_patron_requirements(job: Mission) -> bool:
    if not job.patron:
        return false
    return game_state.faction_standings.get(job.patron.faction, 0) >= job.patron.required_standing

func _generate_patron_job() -> Mission:
    var job = Mission.new()
    # Set patron job specific properties
    return job

func _generate_red_zone_job() -> Mission:
    var job = Mission.new()
    # Set red zone specific properties
    return job

func _generate_black_zone_job() -> Mission:
    var job = _generate_red_zone_job()
    # Add black zone modifiers
    return job

func _generate_standard_job() -> Mission:
    var job = Mission.new()
    # Set standard job properties
    return job

func _apply_job_rewards(job: Mission) -> void:
    game_state.add_credits(job.rewards.get("credits", 0))
    game_state.add_reputation(job.rewards.get("reputation", 0))
    
    if job.rewards.has("equipment"):
        for item in job.rewards.equipment:
            game_state.current_crew.add_equipment(item)

func _apply_failure_consequences(job: Mission) -> void:
    if job.hazards.size() > 0:
        game_state.current_crew.apply_casualties()
    
    if job.conditions.has("Reputation Required"):
        game_state.decrease_reputation(5)

func _remove_from_available_jobs(job: Mission) -> void:
    patron_jobs.erase(job)
    red_zone_jobs.erase(job)
    black_zone_jobs.erase(job)