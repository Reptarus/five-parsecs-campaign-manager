class_name WorldStepManager
extends Node

signal step_completed(step: int)
signal phase_completed

enum WorldStep {
    UPKEEP,
    SHIP_REPAIRS,
    LOAN_CHECK,
    CREW_TASKS,
    JOB_OFFERS,
    EQUIPMENT,
    RUMORS,
    BATTLE_PREP
}

var current_step: WorldStep = WorldStep.UPKEEP
var game_state: MockGameState
var world_economy_manager: WorldEconomyManager
var job_generator: JobGenerator
var special_mission_generator: SpecialMissionGenerator

func _init() -> void:
    job_generator = JobGenerator.new(game_state)
    special_mission_generator = SpecialMissionGenerator.new(game_state)

func process_step() -> void:
    match current_step:
        WorldStep.UPKEEP:
            process_upkeep()
        WorldStep.SHIP_REPAIRS:
            process_ship_repairs()
        WorldStep.LOAN_CHECK:
            process_loan_check()
        WorldStep.CREW_TASKS:
            process_crew_tasks()
        WorldStep.JOB_OFFERS:
            process_job_offers()
        WorldStep.EQUIPMENT:
            process_equipment()
        WorldStep.RUMORS:
            process_rumors()
        WorldStep.BATTLE_PREP:
            process_battle_prep()

func process_upkeep() -> void:
    var upkeep_cost = world_economy_manager.calculate_upkeep()
    if world_economy_manager.pay_upkeep(game_state.crew):
        step_completed.emit(WorldStep.UPKEEP)
    else:
        game_state.crew.decrease_morale()
        step_completed.emit(WorldStep.UPKEEP)

func process_ship_repairs() -> void:
    var repair_amount = game_state.current_ship.auto_repair()
    step_completed.emit(WorldStep.SHIP_REPAIRS)

func process_loan_check() -> void:
    if game_state.current_ship.has_loan():
        var roll = game_state.roll_dice(2, 6)
        if roll <= game_state.current_ship.loan_risk:
            game_state.trigger_loan_enforcement()
    step_completed.emit(WorldStep.LOAN_CHECK)

func process_crew_tasks() -> void:
    var available_tasks = game_state.get_available_tasks()
    for crew_member in game_state.crew.members:
        if not crew_member.is_injured():
            var task = crew_member.select_task(available_tasks)
            var result = crew_member.perform_task(task)
            game_state.apply_task_result(result)
    step_completed.emit(WorldStep.CREW_TASKS)


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

func process_equipment() -> void:
    game_state.equipment_manager.optimize_equipment_distribution()
    game_state.equipment_manager.repair_damaged_equipment()
    step_completed.emit(WorldStep.EQUIPMENT)

func process_rumors() -> void:
    var current_rumors = game_state.get_current_rumors()
    for rumor in current_rumors:
        if game_state.roll_dice(1, 6) >= 4:  # 50% chance to resolve rumor
            var mission = game_state.mission_generator.generate_from_rumor(rumor)
            if mission:
                game_state.available_missions.append(mission)
            game_state.remove_rumor(rumor)
    
    # Generate new rumors
    var new_rumor_count = game_state.roll_dice(1, 3)
    for i in range(new_rumor_count):
        var new_rumor = game_state.rumor_generator.generate_rumor()
        game_state.add_rumor(new_rumor)
    
    step_completed.emit(WorldStep.RUMORS)

func process_battle_prep() -> void:
    if game_state.current_mission != null:
        game_state.equipment_manager.prepare_for_battle()
        game_state.crew.prepare_for_battle()
        step_completed.emit(WorldStep.BATTLE_PREP)
        phase_completed.emit()
    else:
        push_warning("No mission selected for battle preparation")
        step_completed.emit(WorldStep.BATTLE_PREP)

func advance_step() -> void:
    var next_step = (current_step + 1) % WorldStep.size()
    if next_step == WorldStep.UPKEEP:
        phase_completed.emit()
    else:
        current_step = next_step
