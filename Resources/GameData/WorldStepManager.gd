class_name WorldStepManager
extends Node

var job_generator: JobGenerator
var special_mission_generator: SpecialMissionGenerator

func _init() -> void:
    job_generator = JobGenerator.new(game_state)
    special_mission_generator = SpecialMissionGenerator.new(game_state)

func process_job_offers_step() -> void:
    # Generate new jobs
    var new_jobs = job_generator.generate_jobs(3)
    game_state.available_missions.append_array(new_jobs)
    
    # Generate special jobs if conditions are met
    if game_state.campaign_turns >= 10:
        var special_mission = special_mission_generator.generate_special_mission(
            SpecialMissionGenerator.MissionTier.RED_ZONE if game_state.current_crew.has_red_zone_license 
            else SpecialMissionGenerator.MissionTier.NORMAL
        )
        if special_mission:
            game_state.available_missions.append(special_mission) 