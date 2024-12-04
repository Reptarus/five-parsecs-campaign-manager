extends Node

enum WorldPhase {
    UPKEEP,
    CREW_TASKS,
    JOB_OFFERS,
    EQUIPMENT,
    RUMORS,
    BATTLE_PREP
}

signal phase_completed(phase: int)
signal world_phase_completed

var current_phase: WorldPhase = WorldPhase.UPKEEP
var game_state: Node  # Will be cast to GameState at runtime
var crew_task_manager: Node  # Will be cast to CrewTaskManager at runtime
var job_offers_panel: Node  # Will be cast to JobOffersPanel at runtime
var equipment_manager: Node  # Will be cast to EquipmentManager at runtime
var rumor_manager: Node  # Will be cast to RumorManager at runtime

func _ready() -> void:
    game_state = get_node("/root/GameStateManager")
    if not game_state:
        push_error("GameStateManager instance not found")
        queue_free()
        return
        
    initialize_managers()
    connect_signals()

func initialize_managers() -> void:
    crew_task_manager = Node.new()  # Will be replaced with CrewTaskManager at runtime
    job_offers_panel = Node.new()  # Will be replaced with JobOffersPanel at runtime
    equipment_manager = Node.new()  # Will be replaced with EquipmentManager at runtime
    rumor_manager = Node.new()  # Will be replaced with RumorManager at runtime
    
    add_child(crew_task_manager)
    add_child(job_offers_panel)
    add_child(equipment_manager)
    add_child(rumor_manager)

func connect_signals() -> void:
    if game_state:
        game_state.connect("state_changed", _on_game_state_changed)
    
    crew_task_manager.connect("tasks_completed", _on_crew_tasks_completed)
    job_offers_panel.connect("job_selected", _on_job_selected)
    equipment_manager.connect("equipment_phase_completed", _on_equipment_phase_completed)
    rumor_manager.connect("rumors_resolved", _on_rumors_resolved)

func start_world_phase() -> void:
    current_phase = WorldPhase.UPKEEP
    handle_upkeep()

func handle_upkeep() -> void:
    var upkeep_cost = game_state.calculate_upkeep()
    if game_state.can_afford(upkeep_cost):
        game_state.spend_credits(upkeep_cost)
        game_state.perform_ship_repairs()
    else:
        handle_failed_upkeep()
    
    advance_phase()

func handle_crew_tasks() -> void:
    crew_task_manager.start_crew_tasks()

func handle_job_offers() -> void:
    job_offers_panel.populate_jobs(game_state.available_missions)

func handle_equipment() -> void:
    equipment_manager.start_equipment_phase()

func handle_rumors() -> void:
    rumor_manager.process_rumors()

func handle_battle_prep() -> void:
    if game_state.current_mission:
        game_state.prepare_for_battle()
        advance_phase()
    else:
        push_error("No mission selected for battle prep")

func advance_phase() -> void:
    var phases = WorldPhase.values()
    var current_index = phases.find(current_phase)
    if current_index < phases.size() - 1:
        current_phase = phases[current_index + 1]
        handle_current_phase()
    else:
        world_phase_completed.emit()

func handle_current_phase() -> void:
    match current_phase:
        WorldPhase.UPKEEP:
            handle_upkeep()
        WorldPhase.CREW_TASKS:
            handle_crew_tasks()
        WorldPhase.JOB_OFFERS:
            handle_job_offers()
        WorldPhase.EQUIPMENT:
            handle_equipment()
        WorldPhase.RUMORS:
            handle_rumors()
        WorldPhase.BATTLE_PREP:
            handle_battle_prep()

func handle_failed_upkeep() -> void:
    game_state.apply_failed_upkeep_consequences()
    advance_phase()

func _on_game_state_changed() -> void:
    if game_state.current_state == GlobalEnums.GameState.CAMPAIGN:
        start_world_phase()

func _on_crew_tasks_completed() -> void:
    advance_phase()

func _on_job_selected(job: Node) -> void:  # Will accept Mission at runtime
    game_state.current_mission = job
    advance_phase()

func _on_equipment_phase_completed() -> void:
    advance_phase()

func _on_rumors_resolved() -> void:
    advance_phase() 