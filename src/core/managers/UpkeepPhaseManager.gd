extends Resource

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const GameState := preload("res://src/core/state/GameState.gd")

signal upkeep_completed
signal upkeep_failed(reason: String)
signal resource_updated(type: int, amount: int)
signal crew_state_updated(crew_member: Resource)
signal ship_state_updated
signal medical_care_available(crew_member: Resource, cost: int)
signal task_available(crew_member: Resource, available_tasks: Array)

var game_state: GameState

# Upkeep phase state tracking
var upkeep_paid: bool = false
var ship_maintained: bool = false
var medical_care_processed: bool = false
var tasks_assigned: bool = false

func _init(_game_state: GameState) -> void:
    game_state = _game_state

func start_upkeep_phase() -> void:
    # Reset phase state
    upkeep_paid = false
    ship_maintained = false
    medical_care_processed = false
    tasks_assigned = false
    
    # Calculate initial costs
    _calculate_upkeep_costs()

func _calculate_upkeep_costs() -> Dictionary:
    var costs = {
        "crew_upkeep": _calculate_crew_upkeep(),
        "ship_maintenance": _calculate_ship_maintenance(),
        "medical_costs": _calculate_medical_costs(),
        "total": 0
    }
    
    costs.total = costs.crew_upkeep + costs.ship_maintenance
    return costs

func _calculate_crew_upkeep() -> int:
    var crew_size = game_state.crew.size()
    var upkeep_cost = 1 # Base cost for 4-6 crew
    
    if crew_size > 6:
        upkeep_cost += crew_size - 6 # +1 credit per crew over 6
    
    # Apply difficulty modifiers
    match game_state.difficulty_mode:
        GameEnums.DifficultyMode.EASY:
            upkeep_cost = int(upkeep_cost * 0.8)
        GameEnums.DifficultyMode.CHALLENGING:
            upkeep_cost = int(upkeep_cost * 1.2)
        GameEnums.DifficultyMode.HARDCORE:
            upkeep_cost = int(upkeep_cost * 1.5)
        GameEnums.DifficultyMode.INSANITY:
            upkeep_cost = int(upkeep_cost * 2.0)
    
    return upkeep_cost

func _calculate_ship_maintenance() -> int:
    if not game_state.ship or not game_state.ship.hull_damage:
        return 0
    
    # 1 point repairs automatically
    var remaining_damage = max(0, game_state.ship.hull_damage - 1)
    return remaining_damage # 1 credit per point of damage

func _calculate_medical_costs() -> Dictionary:
    var costs = {}
    
    for crew_member in game_state.crew:
        if crew_member.is_in_sickbay:
            costs[crew_member] = 4 # 4 credits per turn reduction
    
    return costs

func pay_upkeep(amount: int) -> bool:
    if game_state.credits >= amount:
        game_state.credits -= amount
        upkeep_paid = true
        resource_updated.emit(GameEnums.ResourceType.CREDITS, game_state.credits)
        return true
    return false

func maintain_ship(repair_points: int) -> void:
    if not game_state.ship:
        return
    
    # Automatic 1 point repair
    game_state.ship.hull_damage = max(0, game_state.ship.hull_damage - 1)
    
    # Additional repairs
    if repair_points > 0 and game_state.credits >= repair_points:
        game_state.ship.hull_damage = max(0, game_state.ship.hull_damage - repair_points)
        game_state.credits -= repair_points
        resource_updated.emit(GameEnums.ResourceType.CREDITS, game_state.credits)
    
    ship_maintained = true
    ship_state_updated.emit()

func process_medical_care(crew_member: Resource, turns_to_reduce: int) -> void:
    if not crew_member.is_in_sickbay:
        return
    
    var cost = turns_to_reduce * 4
    if game_state.credits >= cost:
        crew_member.sickbay_turns = max(0, crew_member.sickbay_turns - turns_to_reduce)
        game_state.credits -= cost
        resource_updated.emit(GameEnums.ResourceType.CREDITS, game_state.credits)
        crew_state_updated.emit(crew_member)
    
    if crew_member.sickbay_turns == 0:
        crew_member.is_in_sickbay = false

func get_available_tasks(crew_member: Resource) -> Array:
    if crew_member.is_in_sickbay or not upkeep_paid:
        return []
    
    return [
        {"name": "Find a Patron", "type": GameEnums.ResourceType.PATRON},
        {"name": "Train", "type": GameEnums.ResourceType.XP},
        {"name": "Trade", "type": GameEnums.ResourceType.CREDITS},
        {"name": "Scavenge", "type": GameEnums.ResourceType.SUPPLIES},
        {"name": "Explore", "type": GameEnums.ResourceType.QUEST_RUMOR},
        {"name": "Track", "type": GameEnums.ResourceType.RIVAL},
        {"name": "Repair", "type": GameEnums.ResourceType.SUPPLIES},
        {"name": "Guard", "type": GameEnums.ResourceType.STORY_POINT}
    ]

func assign_crew_task(crew_member: Resource, task: int) -> void:
    if not crew_member or crew_member.is_in_sickbay:
        return
    
    crew_member.current_task = task
    crew_state_updated.emit(crew_member)
    
    # Check if all available crew have tasks assigned
    var all_tasks_assigned = true
    for member in game_state.crew:
        if not member.is_in_sickbay and member.current_task == GameEnums.ResourceType.NONE:
            all_tasks_assigned = false
            break
    
    tasks_assigned = all_tasks_assigned
    if tasks_assigned:
        upkeep_completed.emit()

func check_phase_completion() -> bool:
    return upkeep_paid and ship_maintained and medical_care_processed and tasks_assigned

func skip_upkeep() -> void:
    # Apply penalties for skipping upkeep
    game_state.morale -= 1
    game_state.reputation = max(0, game_state.reputation - 1)
    
    # Mark phase as complete
    upkeep_paid = true
    ship_maintained = true
    medical_care_processed = true
    tasks_assigned = true
    
    upkeep_completed.emit()