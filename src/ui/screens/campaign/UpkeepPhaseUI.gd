extends Control

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const GameState := preload("res://src/core/state/GameState.gd")
const GameStateManager := preload("res://src/core/managers/GameStateManager.gd")

# UI References
@onready var crew_upkeep_value := $Panel/MarginContainer/VBoxContainer/UpkeepSection/UpkeepInfo/CrewUpkeepValue
@onready var ship_maintenance_value := $Panel/MarginContainer/VBoxContainer/UpkeepSection/UpkeepInfo/ShipMaintenanceValue
@onready var total_value := $Panel/MarginContainer/VBoxContainer/UpkeepSection/UpkeepInfo/TotalValue
@onready var pay_upkeep_button := $Panel/MarginContainer/VBoxContainer/UpkeepSection/PayUpkeepButton
@onready var skip_upkeep_button := $Panel/MarginContainer/VBoxContainer/UpkeepSection/SkipUpkeepButton

@onready var hull_damage_value := $Panel/MarginContainer/VBoxContainer/ShipRepairSection/ShipInfo/HullDamageValue
@onready var repair_points_spin := $Panel/MarginContainer/VBoxContainer/ShipRepairSection/ShipInfo/RepairPointsSpinBox
@onready var repair_button := $Panel/MarginContainer/VBoxContainer/ShipRepairSection/RepairButton

@onready var medical_crew_list := $Panel/MarginContainer/VBoxContainer/MedicalSection/CrewList
@onready var medical_turns_spin := $Panel/MarginContainer/VBoxContainer/MedicalSection/MedicalInfo/TurnsSpinBox
@onready var medical_cost_value := $Panel/MarginContainer/VBoxContainer/MedicalSection/MedicalInfo/CostValue
@onready var provide_care_button := $Panel/MarginContainer/VBoxContainer/MedicalSection/ProvideCareButton

@onready var task_crew_list := $Panel/MarginContainer/VBoxContainer/TaskSection/CrewList
@onready var task_option := $Panel/MarginContainer/VBoxContainer/TaskSection/TaskOptionButton
@onready var assign_task_button := $Panel/MarginContainer/VBoxContainer/TaskSection/AssignTaskButton

@onready var complete_phase_button := $Panel/MarginContainer/VBoxContainer/ButtonContainer/CompletePhaseButton

var game_state: GameState
var current_costs: Dictionary
var selected_medical_crew: Resource
var selected_task_crew: Resource

enum CrewTask {
    NONE,
    REPAIR,
    SCAVENGE,
    GUARD,
    TRADE,
    MEDICAL,
    MAINTENANCE,
    TRAINING
}

func _ready() -> void:
    # Try to get GameState from GameStateManager first
    var game_state_manager = get_node_or_null("/root/GameStateManager")
    if game_state_manager and game_state_manager.has_method("get_game_state"):
        game_state = game_state_manager.get_game_state()
    else:
        # Fallback to direct access if the method doesn't exist
        game_state = game_state_manager.game_state if game_state_manager else null
    
    # If still no game_state, try other methods
    if not game_state:
        game_state = get_node_or_null("/root/GameState")
    
    if not game_state:
        push_error("GameState not found")
        queue_free()
        return
    
    _connect_signals()
    _initialize_ui()
    _calculate_upkeep()

func _connect_signals() -> void:
    pay_upkeep_button.pressed.connect(_on_pay_upkeep_pressed)
    skip_upkeep_button.pressed.connect(_on_skip_upkeep_pressed)
    repair_button.pressed.connect(_on_repair_pressed)
    provide_care_button.pressed.connect(_on_provide_care_pressed)
    assign_task_button.pressed.connect(_on_assign_task_pressed)
    complete_phase_button.pressed.connect(_on_complete_phase_pressed)
    
    medical_crew_list.item_selected.connect(_on_medical_crew_selected)
    task_crew_list.item_selected.connect(_on_task_crew_selected)
    medical_turns_spin.value_changed.connect(_on_medical_turns_changed)

func _initialize_ui() -> void:
    _update_cost_display()
    _update_ship_display()
    _update_crew_lists()
    _populate_task_options()
    _update_button_states()

func _calculate_upkeep() -> void:
    current_costs = {
        "crew_upkeep": _calculate_crew_upkeep(),
        "ship_maintenance": _calculate_ship_maintenance(),
        "total": 0
    }
    current_costs.total = current_costs.crew_upkeep + current_costs.ship_maintenance

func _calculate_crew_upkeep() -> int:
    var base_cost := 0
    for crew_member in game_state.current_crew:
        if crew_member.is_active:
            base_cost += 2 # Base upkeep per crew member
    
    # Apply difficulty modifiers
    match game_state.difficulty_level:
        GameEnums.DifficultyLevel.EASY:
            base_cost = int(base_cost * 0.8)
        GameEnums.DifficultyLevel.NORMAL:
            base_cost = int(base_cost * 1.0)
        GameEnums.DifficultyLevel.HARD:
            base_cost = int(base_cost * 1.2)
        GameEnums.DifficultyLevel.HARDCORE:
            base_cost = int(base_cost * 1.5)
        GameEnums.DifficultyLevel.ELITE:
            base_cost = int(base_cost * 2.0)
    
    return base_cost

func _calculate_ship_maintenance() -> int:
    if not game_state.ship_hull_points:
        return 0
        
    var base_cost := int(game_state.ship_hull_points / 10)
    var damage_penalty := int((game_state.ship_hull_points - game_state.ship_hull_points) / 5)
    
    return base_cost + damage_penalty

func _update_cost_display() -> void:
    crew_upkeep_value.text = str(current_costs.crew_upkeep) + " credits"
    ship_maintenance_value.text = str(current_costs.ship_maintenance) + " credits"
    total_value.text = str(current_costs.total) + " credits"

func _update_ship_display() -> void:
    if game_state.ship_hull_points:
        hull_damage_value.text = str(game_state.ship_hull_points)
        repair_points_spin.max_value = min(game_state.ship_hull_points, game_state.credits / 2)
    else:
        hull_damage_value.text = "No Ship"
        repair_points_spin.max_value = 0

func _update_crew_lists() -> void:
    medical_crew_list.clear()
    task_crew_list.clear()
    
    for crew_member in game_state.current_crew:
        if crew_member.status == GameEnums.CharacterStatus.INJURED:
            medical_crew_list.add_item(crew_member.character_name)
        
        if crew_member.status == GameEnums.CharacterStatus.HEALTHY:
            task_crew_list.add_item(crew_member.character_name)

func _populate_task_options() -> void:
    task_option.clear()
    task_option.add_item("None", CrewTask.NONE)
    task_option.add_item("Repair", CrewTask.REPAIR)
    task_option.add_item("Scavenge", CrewTask.SCAVENGE)
    task_option.add_item("Guard", CrewTask.GUARD)
    task_option.add_item("Trade", CrewTask.TRADE)
    task_option.add_item("Medical", CrewTask.MEDICAL)
    task_option.add_item("Maintenance", CrewTask.MAINTENANCE)
    task_option.add_item("Training", CrewTask.TRAINING)

func _update_button_states() -> void:
    pay_upkeep_button.disabled = game_state.credits < current_costs.total
    repair_button.disabled = not game_state.ship_hull_points or repair_points_spin.value == 0
    provide_care_button.disabled = not selected_medical_crew
    assign_task_button.disabled = not selected_task_crew or task_option.selected == CrewTask.NONE
    complete_phase_button.disabled = game_state.credits < current_costs.total

func _on_pay_upkeep_pressed() -> void:
    if game_state.credits >= current_costs.total:
        game_state.credits -= current_costs.total
        _update_button_states()

func _on_skip_upkeep_pressed() -> void:
    # Apply penalties for skipping upkeep
    for crew_member in game_state.current_crew:
        if crew_member.is_active and randf() < 0.2: # 20% chance per crew member
            crew_member.status = GameEnums.CharacterStatus.INJURED
    
    if game_state.ship_hull_points and randf() < 0.3: # 30% chance of ship damage
        game_state.ship_hull_points = max(0, game_state.ship_hull_points - 1)
    
    _update_crew_lists()
    _update_ship_display()
    _update_button_states()

func _on_repair_pressed() -> void:
    var points = repair_points_spin.value
    var cost = points * 2
    
    if game_state.credits >= cost:
        game_state.credits -= cost
        game_state.ship_hull_points = min(game_state.ship_hull_points + points, game_state.ship_hull_points)
        _update_ship_display()
        _update_button_states()

func _on_medical_crew_selected(index: int) -> void:
    selected_medical_crew = game_state.current_crew[index]
    _update_medical_cost()
    _update_button_states()

func _on_medical_turns_changed(value: float) -> void:
    _update_medical_cost()

func _update_medical_cost() -> void:
    var turns = medical_turns_spin.value
    medical_cost_value.text = str(turns * 4) + " credits"

func _on_provide_care_pressed() -> void:
    if selected_medical_crew:
        var turns = medical_turns_spin.value
        var cost = turns * 4
        
        if game_state.credits >= cost:
            game_state.credits -= cost
            if turns >= 2: # Full recovery requires at least 2 turns of care
                selected_medical_crew.status = GameEnums.CharacterStatus.HEALTHY
            _update_crew_lists()
            _update_button_states()

func _on_task_crew_selected(index: int) -> void:
    selected_task_crew = game_state.current_crew[index]
    _update_button_states()

func _on_assign_task_pressed() -> void:
    if selected_task_crew:
        var task = task_option.get_selected_id()
        selected_task_crew.current_task = task
        _update_crew_lists()
        _update_button_states()

func _on_complete_phase_pressed() -> void:
    queue_free()