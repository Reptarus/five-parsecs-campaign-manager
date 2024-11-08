class_name BattleCheckpoint
extends Control

signal checkpoint_validated(result: Dictionary)
signal checkpoint_failed(reason: String)

@onready var enemy_count_input := $VBoxContainer/EnemySection/EnemyCountSpinBox
@onready var objective_list := $VBoxContainer/ObjectiveSection/ObjectiveList
@onready var notes_input := $VBoxContainer/NotesSection/NotesInput
@onready var validation_label := $VBoxContainer/ValidationLabel

var initial_state: Dictionary
var current_mission: Mission

func initialize(mission: Mission, battle_state: Dictionary) -> void:
    current_mission = mission
    initial_state = battle_state
    _setup_form()

func _setup_form() -> void:
    # Set maximum enemy count
    enemy_count_input.max_value = initial_state.total_enemies
    
    # Setup objective checklist based on mission type
    _setup_objectives()
    
    # Add mission-specific inputs
    _add_mission_specific_inputs()

func _setup_objectives() -> void:
    for objective in current_mission.objectives:
        var checkbox = CheckBox.new()
        checkbox.text = objective.description
        objective_list.add_child(checkbox)

func validate_checkpoint() -> bool:
    # Basic validation
    if enemy_count_input.value > initial_state.total_enemies:
        checkpoint_failed.emit("Enemy count exceeds initial number")
        return false
        
    # Mission-specific validation
    if not _validate_mission_specific():
        return false
        
    # Core Rules constraints
    if not _validate_core_rules():
        return false
    
    # Create checkpoint data
    var checkpoint_data = {
        "enemies_defeated": enemy_count_input.value,
        "objectives_completed": _get_completed_objectives(),
        "notes": notes_input.text,
        "mission_specific": _get_mission_specific_data()
    }
    
    checkpoint_validated.emit(checkpoint_data)
    return true

func _validate_mission_specific() -> bool:
    match current_mission.type:
        GlobalEnums.MissionType.RESCUE:
            return _validate_rescue_mission()
        GlobalEnums.MissionType.SABOTAGE:
            return _validate_sabotage_mission()
        # Add other mission types
        _:
            return true

func _validate_core_rules() -> bool:
    # Check against Core Rules constraints
    # Return false if any rules are violated
    return true

func _get_completed_objectives() -> Array:
    var completed = []
    for checkbox in objective_list.get_children():
        if checkbox.pressed:
            completed.append(checkbox.text)
    return completed 

func _add_mission_specific_inputs() -> void:
    match current_mission.type:
        GlobalEnums.MissionType.RESCUE:
            _add_rescue_mission_inputs()
        GlobalEnums.MissionType.SABOTAGE:
            _add_sabotage_mission_inputs()
        _:
            pass

func _get_mission_specific_data() -> Dictionary:
    match current_mission.type:
        GlobalEnums.MissionType.RESCUE:
            return {
                "rescued_units": _get_rescued_units(),
                "extraction_point_reached": _check_extraction_point()
            }
        GlobalEnums.MissionType.SABOTAGE:
            return {
                "targets_destroyed": _get_destroyed_targets(),
                "stealth_maintained": _check_stealth_status()
            }
        _:
            return {}

func _validate_rescue_mission() -> bool:
    var rescued_count = _get_rescued_units().size()
    return rescued_count >= current_mission.required_rescues

func _validate_sabotage_mission() -> bool:
    var destroyed_count = _get_destroyed_targets().size()
    return destroyed_count >= current_mission.required_targets

func _add_rescue_mission_inputs() -> void:
    var rescue_container = VBoxContainer.new()
    rescue_container.name = "RescueInputs"
    
    var rescue_count = SpinBox.new()
    rescue_count.name = "RescueCountSpinBox"
    rescue_count.min_value = 0
    rescue_count.max_value = current_mission.total_rescuable_units
    rescue_container.add_child(rescue_count)
    
    var extraction_check = CheckBox.new()
    extraction_check.name = "ExtractionCheckBox"
    extraction_check.text = "Extraction Point Reached"
    rescue_container.add_child(extraction_check)
    
    add_child(rescue_container)

func _add_sabotage_mission_inputs() -> void:
    var sabotage_container = VBoxContainer.new()
    sabotage_container.name = "SabotageInputs"
    
    var target_count = SpinBox.new()
    target_count.name = "TargetCountSpinBox"
    target_count.min_value = 0
    target_count.max_value = current_mission.total_targets
    sabotage_container.add_child(target_count)
    
    var stealth_check = CheckBox.new()
    stealth_check.name = "StealthCheckBox"
    stealth_check.text = "Stealth Maintained"
    sabotage_container.add_child(stealth_check)
    
    add_child(sabotage_container)

func _get_rescued_units() -> Array:
    var rescue_count = get_node("RescueInputs/RescueCountSpinBox")
    if rescue_count:
        return range(rescue_count.value)
    return []

func _check_extraction_point() -> bool:
    var extraction_check = get_node("RescueInputs/ExtractionCheckBox")
    return extraction_check != null and extraction_check.button_pressed

func _get_destroyed_targets() -> Array:
    var target_count = get_node("SabotageInputs/TargetCountSpinBox")
    if target_count:
        return range(target_count.value)
    return []

func _check_stealth_status() -> bool:
    var stealth_check = get_node("SabotageInputs/StealthCheckBox")
    return stealth_check != null and stealth_check.button_pressed