class_name WorldStepManager
extends Node

signal step_completed
signal world_phase_completed

var game_state: GameState
var current_step: GlobalEnums.WorldPhase = GlobalEnums.WorldPhase.UPKEEP

# Managers
var mission_manager: MissionManager
var loan_manager: LoanManager
var crew_task_manager: CrewTaskManager
var patron_job_manager: PatronJobManager
var equipment_manager: EquipmentManager
var rumor_manager: RumorManager

func _init(_game_state: GameState) -> void:
    game_state = _game_state
    _initialize_managers()

func _initialize_managers() -> void:
    mission_manager = MissionManager.new(game_state)
    loan_manager = LoanManager.new(game_state)
    crew_task_manager = CrewTaskManager.new(game_state)
    patron_job_manager = PatronJobManager.new(game_state)
    equipment_manager = EquipmentManager.new()
    equipment_manager.initialize(game_state)
    rumor_manager = _create_rumor_manager()

func _create_rumor_manager() -> RumorManager:
    var manager = RumorManager.new()
    manager.initialize(game_state)
    return manager

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
    var upkeep_cost = game_state.calculate_upkeep()
    if game_state.pay_upkeep(upkeep_cost):
        game_state.apply_upkeep_effects()
    else:
        game_state.handle_upkeep_failure()
    step_completed.emit()

func _process_ship_repairs() -> void:
    var ship = game_state.current_ship
    if ship.needs_repairs() and game_state.can_afford_repairs():
        ship.perform_repairs()
    step_completed.emit()

func _process_loan_check() -> void:
    loan_manager.update_loans()
    loan_manager.roll_for_loan_event()
    step_completed.emit()

func _process_crew_tasks() -> void:
    for crew_member in game_state.current_crew.available_members:
        var task = crew_member.get_assigned_task()
        if task:
            var result = crew_task_manager.execute_task(crew_member, task)
            crew_task_manager.apply_task_results(result)
    step_completed.emit()

func _process_job_offers() -> void:
    var new_jobs = patron_job_manager.generate_available_jobs()
    game_state.update_available_jobs(new_jobs)
    step_completed.emit()

func _process_equipment() -> void:
    equipment_manager.update_market()
    step_completed.emit()

func _process_rumors() -> void:
    rumor_manager.generate_rumors()
    step_completed.emit()

func _process_battle_prep() -> void:
    if game_state.current_mission:
        game_state.prepare_for_battle()
        game_state.transition_to_phase(GlobalEnums.CampaignPhase.BATTLE)
    step_completed.emit()

func advance_step() -> void:
    var next_step = (current_step + 1) % GlobalEnums.WorldPhase.size()
    if next_step == GlobalEnums.WorldPhase.UPKEEP:
        world_phase_completed.emit()
    else:
        current_step = next_step
        process_step()

func get_current_step_description() -> String:
    return GlobalEnums.WorldPhase.keys()[current_step].capitalize().replace("_", " ")