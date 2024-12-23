extends Control

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const UpkeepPhaseManager := preload("res://src/data/resources/CampaignManagement/UpkeepPhaseManager.gd")

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

var upkeep_manager: UpkeepPhaseManager
var game_state: GameState
var current_costs: Dictionary
var selected_medical_crew: Resource
var selected_task_crew: Resource

func _ready() -> void:
    game_state = get_node("/root/GameState")
    if not game_state:
        push_error("GameState not found")
        queue_free()
        return
    
    upkeep_manager = UpkeepPhaseManager.new(game_state)
    _connect_signals()
    _initialize_ui()
    upkeep_manager.start_upkeep_phase()

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
    
    upkeep_manager.resource_updated.connect(_on_resource_updated)
    upkeep_manager.crew_state_updated.connect(_on_crew_state_updated)
    upkeep_manager.ship_state_updated.connect(_on_ship_state_updated)
    upkeep_manager.upkeep_completed.connect(_on_upkeep_completed)

func _initialize_ui() -> void:
    current_costs = upkeep_manager._calculate_upkeep_costs()
    _update_cost_display()
    _update_ship_display()
    _update_crew_lists()
    _populate_task_options()
    _update_button_states()

func _update_cost_display() -> void:
    crew_upkeep_value.text = str(current_costs.crew_upkeep) + " credits"
    ship_maintenance_value.text = str(current_costs.ship_maintenance) + " credits"
    total_value.text = str(current_costs.total) + " credits"

func _update_ship_display() -> void:
    if game_state.ship:
        hull_damage_value.text = str(game_state.ship.hull_damage)
        repair_points_spin.max_value = min(game_state.ship.hull_damage, game_state.credits)
    else:
        hull_damage_value.text = "No Ship"
        repair_points_spin.max_value = 0

func _update_crew_lists() -> void:
    medical_crew_list.clear()
    task_crew_list.clear()
    
    for crew_member in game_state.crew:
        if crew_member.is_in_sickbay:
            medical_crew_list.add_item(crew_member.character_name)
        
        if not crew_member.is_in_sickbay and crew_member.current_task == GameEnums.CrewTask.NONE:
            task_crew_list.add_item(crew_member.character_name)

func _populate_task_options() -> void:
    task_option.clear()
    var tasks = upkeep_manager.get_available_tasks(selected_task_crew)
    for task in tasks:
        task_option.add_item(task.name, task.type)

func _update_button_states() -> void:
    pay_upkeep_button.disabled = game_state.credits < current_costs.total or upkeep_manager.upkeep_paid
    repair_button.disabled = not game_state.ship or game_state.ship.hull_damage == 0 or not upkeep_manager.upkeep_paid
    provide_care_button.disabled = not selected_medical_crew or not upkeep_manager.upkeep_paid
    assign_task_button.disabled = not selected_task_crew or not upkeep_manager.upkeep_paid
    complete_phase_button.disabled = not upkeep_manager.check_phase_completion()

func _on_pay_upkeep_pressed() -> void:
    if upkeep_manager.pay_upkeep(current_costs.total):
        _update_button_states()

func _on_skip_upkeep_pressed() -> void:
    upkeep_manager.skip_upkeep()
    _update_button_states()

func _on_repair_pressed() -> void:
    var points = repair_points_spin.value
    upkeep_manager.maintain_ship(points)
    _update_ship_display()
    _update_button_states()

func _on_medical_crew_selected(index: int) -> void:
    selected_medical_crew = game_state.crew[index]
    _update_medical_cost()
    _update_button_states()

func _on_medical_turns_changed(value: float) -> void:
    _update_medical_cost()

func _update_medical_cost() -> void:
    var turns = medical_turns_spin.value
    medical_cost_value.text = str(turns * 4) + " credits"

func _on_provide_care_pressed() -> void:
    if selected_medical_crew:
        upkeep_manager.process_medical_care(selected_medical_crew, medical_turns_spin.value)
        _update_crew_lists()
        _update_button_states()

func _on_task_crew_selected(index: int) -> void:
    selected_task_crew = game_state.crew[index]
    _populate_task_options()
    _update_button_states()

func _on_assign_task_pressed() -> void:
    if selected_task_crew:
        var task_type = task_option.get_selected_id()
        upkeep_manager.assign_crew_task(selected_task_crew, task_type)
        _update_crew_lists()
        _update_button_states()

func _on_complete_phase_pressed() -> void:
    queue_free()

func _on_resource_updated(_type: int, _amount: int) -> void:
    _update_cost_display()
    _update_button_states()

func _on_crew_state_updated(_crew_member: Resource) -> void:
    _update_crew_lists()
    _update_button_states()

func _on_ship_state_updated() -> void:
    _update_ship_display()
    _update_button_states()

func _on_upkeep_completed() -> void:
    _update_button_states() 