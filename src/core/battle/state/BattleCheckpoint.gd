extends Control

signal checkpoint_validated(result: Dictionary)
signal checkpoint_failed(reason: String)
signal checkpoint_completed

@export_group("UI Elements")
@onready var enemy_count_input := $VBoxContainer/EnemySection/EnemyCountSpinBox
@onready var objective_list := $VBoxContainer/ObjectiveSection/ObjectiveList
@onready var notes_input := $VBoxContainer/NotesSection/NotesInput
@onready var validation_label := $VBoxContainer/ValidationLabel
@onready var ui_elements := {
    "enemy_count": enemy_count_input,
    "objective_list": objective_list,
    "notes": notes_input,
    "validation": validation_label
}

var game_state_manager: GameStateManager
var current_mission: Mission
var initial_state: Dictionary
var mission_specific_inputs: Dictionary = {}

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Core Setup Functions

func _ready() -> void:
    initialize_from_autoload()
    setup_ui()
    connect_signals()

func initialize_from_autoload() -> void:
    game_state_manager = get_node("/root/GameStateManager") as GameStateManager
    if not game_state_manager:
        push_error("Failed to get GameStateManager")
        return

func initialize(mission: Mission, battle_state: Dictionary) -> void:
    if not mission:
        push_error("Invalid mission provided to BattleCheckpoint")
        return
        
    current_mission = mission
    initial_state = battle_state
    _setup_form()

# UI Setup and Management

func setup_ui() -> void:
    if not _validate_ui_elements():
        push_error("Required UI elements not found in BattleCheckpoint")
        return
    
    _setup_base_ui()
    _setup_mission_specific_ui()

func _validate_ui_elements() -> bool:
    for element_name in ui_elements:
        if not ui_elements[element_name]:
            return false
    return true

func _setup_base_ui() -> void:
    enemy_count_input.max_value = initial_state.get("total_enemies", 0)
    enemy_count_input.value = 0
    notes_input.text = ""
    validation_label.text = ""

func _setup_mission_specific_ui() -> void:
    _setup_objectives()
    _add_mission_specific_inputs()

func connect_signals() -> void:
    for element in ui_elements.values():
        if element is SpinBox:
            element.value_changed.connect(_on_value_changed)
        elif element is CheckBox:
            element.toggled.connect(_on_checkbox_toggled)

# Form Setup and Validation

func _setup_form() -> void:
    enemy_count_input.max_value = initial_state.total_enemies
    _setup_objectives()
    _add_mission_specific_inputs()

func _setup_objectives() -> void:
    for objective in current_mission.objectives:
        var checkbox = CheckBox.new()
        checkbox.text = objective.description
        checkbox.toggled.connect(_on_objective_toggled.bind(checkbox))
        objective_list.add_child(checkbox)

func validate_checkpoint() -> bool:
    validation_label.text = "Validating checkpoint..."
    
    if not _validate_basic_requirements():
        return false
    
    if not _validate_mission_specific():
        return false
    
    if not _validate_core_rules():
        return false
    
    var checkpoint_data = _create_checkpoint_data()
    checkpoint_validated.emit(checkpoint_data)
    checkpoint_completed.emit()
    return true

func _validate_basic_requirements() -> bool:
    if enemy_count_input.value > initial_state.total_enemies:
        _show_validation_error("Enemy count exceeds initial number")
        return false
    
    if _count_completed_objectives() == 0:
        _show_validation_error("No objectives completed")
        return false
    
    return true

func _validate_mission_specific() -> bool:
    match current_mission.mission_type:
        GameEnums.MissionType.RESCUE:
            return _validate_rescue_mission()
        GameEnums.MissionType.SABOTAGE:
            return _validate_sabotage_mission()
        _:
            return true

func _validate_rescue_mission() -> bool:
    var rescued = _get_rescued_units()
    if rescued.is_empty():
        _show_validation_error("No units rescued")
        return false
    
    if not _check_extraction_point():
        _show_validation_error("Extraction point not reached")
        return false
    
    return true

func _validate_sabotage_mission() -> bool:
    var destroyed = _get_destroyed_targets()
    if destroyed.is_empty():
        _show_validation_error("No targets destroyed")
        return false
    
    return true

func _validate_core_rules() -> bool:
    # Add core rule validations here
    return true

# Data Collection and Management

func _create_checkpoint_data() -> Dictionary:
    var data = {
        "enemies_remaining": enemy_count_input.value,
        "objectives_completed": _get_completed_objectives(),
        "notes": notes_input.text,
        "mission_specific": {}
    }
    
    match current_mission.mission_type:
        GameEnums.MissionType.RESCUE:
            data.mission_specific["rescued_units"] = _get_rescued_units()
            data.mission_specific["extraction_reached"] = _check_extraction_point()
        GameEnums.MissionType.SABOTAGE:
            data.mission_specific["destroyed_targets"] = _get_destroyed_targets()
            data.mission_specific["stealth_maintained"] = _check_stealth_status()
    
    return data

# Mission-specific UI Management

func _add_mission_specific_inputs() -> void:
    match current_mission.mission_type:
        GameEnums.MissionType.RESCUE:
            _add_rescue_mission_inputs()
        GameEnums.MissionType.SABOTAGE:
            _add_sabotage_mission_inputs()

func _add_rescue_mission_inputs() -> void:
    var container = _create_mission_container("RescueInputs")
    
    var rescue_count = SpinBox.new()
    rescue_count.name = "RescueCountSpinBox"
    rescue_count.min_value = 0
    rescue_count.max_value = current_mission.total_rescuable_units
    container.add_child(rescue_count)
    
    var extraction_check = CheckBox.new()
    extraction_check.name = "ExtractionCheckBox"
    extraction_check.text = "Extraction Point Reached"
    container.add_child(extraction_check)
    
    _add_mission_container(container, "rescue")

func _add_sabotage_mission_inputs() -> void:
    var container = _create_mission_container("SabotageInputs")
    
    var target_count = SpinBox.new()
    target_count.name = "TargetCountSpinBox"
    target_count.min_value = 0
    target_count.max_value = current_mission.total_targets
    container.add_child(target_count)
    
    var stealth_check = CheckBox.new()
    stealth_check.name = "StealthCheckBox"
    stealth_check.text = "Stealth Maintained"
    container.add_child(stealth_check)
    
    _add_mission_container(container, "sabotage")

# Helper Functions

func _create_mission_container(_name: String) -> VBoxContainer:
    var container = VBoxContainer.new()
    container.name = name
    return container

func _add_mission_container(container: VBoxContainer, type: String) -> void:
    add_child(container)
    mission_specific_inputs[type] = container

func _show_validation_error(message: String) -> void:
    validation_label.text = "Error: " + message
    checkpoint_failed.emit(message)

# Signal Handlers

func _on_value_changed(_value: float) -> void:
    validate_checkpoint()

func _on_checkbox_toggled(_button_pressed: bool) -> void:
    validate_checkpoint()

func _on_objective_toggled(_button_pressed: bool, _checkbox: CheckBox) -> void:
    validate_checkpoint()

# Data Collection Helpers

func _get_completed_objectives() -> Array:
    var completed = []
    for checkbox in objective_list.get_children():
        if checkbox.button_pressed:
            completed.append(checkbox.text)
    return completed

func _count_completed_objectives() -> int:
    return _get_completed_objectives().size()

func _get_rescued_units() -> Array:
    var rescue_container = mission_specific_inputs.get("rescue")
    if not rescue_container:
        return []
    
    var rescue_count = rescue_container.get_node("RescueCountSpinBox")
    if not rescue_count:
        return []
    
    return range(rescue_count.value)

func _check_extraction_point() -> bool:
    var rescue_container = mission_specific_inputs.get("rescue")
    if not rescue_container:
        return false
    
    var extraction_check = rescue_container.get_node("ExtractionCheckBox")
    return extraction_check and extraction_check.button_pressed

func _get_destroyed_targets() -> Array:
    var sabotage_container = mission_specific_inputs.get("sabotage")
    if not sabotage_container:
        return []
    
    var target_count = sabotage_container.get_node("TargetCountSpinBox")
    if not target_count:
        return []
    
    return range(target_count.value)

func _check_stealth_status() -> bool:
    var sabotage_container = mission_specific_inputs.get("sabotage")
    if not sabotage_container:
        return false
    
    var stealth_check = sabotage_container.get_node("StealthCheckBox")
    return stealth_check and stealth_check.button_pressed