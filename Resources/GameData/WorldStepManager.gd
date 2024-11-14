class_name WorldStepManager
extends Node

signal step_completed(step: GlobalEnums.WorldPhase)
signal world_phase_completed

var game_state: GameState
var current_step: GlobalEnums.WorldPhase = GlobalEnums.WorldPhase.UPKEEP
var world_economy_manager: WorldEconomyManager
var game_state_manager: GameStateManager

# Managers
var mission_manager: MissionManager
var loan_manager: LoanManager
var crew_task_manager: CrewTaskManager
var patron_job_manager: PatronJobManager
var equipment_manager: EquipmentManager
var rumor_manager: RumorManager
var job_generator: JobGenerator
var special_mission_generator: SpecialMissionGenerator

func _init(_game_state: GameState) -> void:
    if not _game_state:
        push_error("GameState is required for WorldStepManager")
        return
    game_state = _game_state
    _initialize_managers()

func initialize(gsm: GameStateManager) -> void:
    game_state_manager = gsm
    job_generator = JobGenerator.new(gsm.game_state)
    special_mission_generator = SpecialMissionGenerator.new(gsm.game_state)
    world_economy_manager = WorldEconomyManager.new(gsm.game_state.current_location.location, gsm.game_state.economy_manager)
    world_economy_manager.initialize(gsm.game_state.economy_manager)

func _initialize_managers() -> void:
    if not game_state:
        push_error("GameState not initialized")
        return
        
    mission_manager = MissionManager.new(game_state)
    loan_manager = LoanManager.new(game_state)
    crew_task_manager = CrewTaskManager.new(game_state)
    patron_job_manager = PatronJobManager.new(game_state)
    equipment_manager = EquipmentManager.new()
    equipment_manager.initialize(game_state)
    rumor_manager = _create_rumor_manager()

func _create_rumor_manager() -> RumorManager:
    return RumorManager.new(game_state)

func process_step() -> void:
    match current_step:
        GlobalEnums.WorldPhase.UPKEEP:
            _process_upkeep()
        GlobalEnums.WorldPhase.SHIP_REPAIRS:
            _process_ship_repairs()
        GlobalEnums.WorldPhase.LOAN_CHECK:
            _process_loan_check()
        GlobalEnums.WorldPhase.CREW_TASKS:
            _process_crew_tasks()
        GlobalEnums.WorldPhase.JOB_OFFERS:
            _process_job_offers()
        GlobalEnums.WorldPhase.EQUIPMENT:
            _process_equipment()
        GlobalEnums.WorldPhase.RUMORS:
            _process_rumors()
        GlobalEnums.WorldPhase.BATTLE_PREP:
            _process_battle_prep()

func _process_upkeep() -> void:
    var upkeep_cost = world_economy_manager.calculate_upkeep()
    if world_economy_manager.pay_upkeep(game_state.crew):
        game_state.apply_upkeep_effects()
    else:
        game_state.crew.decrease_morale()
    step_completed.emit(current_step)

func _process_ship_repairs() -> void:
    var ship = game_state.current_ship
    if ship.needs_repairs() and game_state.can_afford_repairs():
        ship.perform_repairs()
    step_completed.emit(current_step)

func _process_loan_check() -> void:
    loan_manager.update_loans()
    loan_manager.roll_for_loan_event()
    step_completed.emit(current_step)

func _process_crew_tasks() -> void:
    for crew_member in game_state.current_crew.available_members:
        var task = crew_member.get_assigned_task()
        if task:
            var result = crew_task_manager.execute_task(crew_member, task)
            crew_task_manager.apply_task_results(result)
    step_completed.emit(current_step)

func _process_job_offers() -> void:
    var new_jobs = job_generator.generate_jobs(3)
    game_state.available_missions.append_array(new_jobs)
    if game_state.campaign_turns >= 10:
        var special_mission = special_mission_generator.generate_special_mission(game_state.campaign_turns)
        if special_mission:
            game_state.available_missions.append(special_mission)
    step_completed.emit(current_step)

func _process_equipment() -> void:
    equipment_manager.optimize_equipment_distribution()
    equipment_manager.repair_damaged_equipment()
    step_completed.emit(current_step)

func _process_rumors() -> void:
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
    
    step_completed.emit(current_step)

func _process_battle_prep() -> void:
    if game_state.current_mission:
        game_state.prepare_for_battle()
        game_state.transition_to_phase(GlobalEnums.CampaignPhase.BATTLE)
        step_completed.emit(current_step)
        world_phase_completed.emit()
    else:
        push_warning("No mission selected for battle preparation")
        step_completed.emit(current_step)

func advance_step() -> void:
    var next_step = (current_step + 1) % GlobalEnums.WorldPhase.size()
    if next_step == GlobalEnums.WorldPhase.UPKEEP:
        world_phase_completed.emit()
    else:
        current_step = next_step
        process_step()

func get_current_step_description() -> String:
    return GlobalEnums.WorldPhase.keys()[current_step].capitalize().replace("_", " ")