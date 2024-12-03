class_name WorldStepManagerSystem
extends Resource

var game_state: GameState
var game_state_manager: Node  # Will be set at runtime

# Managers
var world_economy_manager: WorldEconomyManager
var crew_task_manager: CrewTaskManagerSystem
var patron_job_manager: PatronJobManager
var equipment_manager: GameEquipmentManager
var rumor_manager: RumorManager
var job_generator: JobGenerator
var special_mission_generator: Node  # Will be replaced at runtime

func _init(game_state_ref: GameState) -> void:
    game_state = game_state_ref
    _initialize_managers()

func _initialize_managers() -> void:
    if not game_state:
        push_error("GameState not initialized")
        return
        
    crew_task_manager = CrewTaskManagerSystem.new(game_state)
    patron_job_manager = PatronJobManager.new(game_state)
    equipment_manager = GameEquipmentManager.new()
    equipment_manager.initialize(game_state)
    rumor_manager = _create_rumor_manager()

func initialize(gsm: Node) -> void:
    game_state_manager = gsm
    job_generator = JobGenerator.new(game_state)
    special_mission_generator = Node.new()  # Will be replaced at runtime
    world_economy_manager = WorldEconomyManager.new()
    world_economy_manager.initialize(game_state.economy_manager)

func _create_rumor_manager() -> RumorManager:
    var manager = RumorManager.new(game_state)
    return manager