@tool
extends "res://tests/fixtures/base/game_test.gd"

const MedicalBayComponent: GDScript = preload("res://src/core/ships/components/MedicalBayComponent.gd")

var medical_bay: MedicalBayComponent = null

func before_each() -> void:
    await super.before_each()
    medical_bay = MedicalBayComponent.new()
    if not medical_bay:
        push_error("Failed to create medical bay component")
        return
    track_test_resource(medical_bay)
    await get_tree().process_frame

func after_each() -> void:
    await super.after_each()
    medical_bay = null

func test_initialization() -> void:
    assert_not_null(medical_bay, "Medical bay component should be initialized")
    
    var name: String = TypeSafeMixin._safe_method_call_string(medical_bay, "get_name", [], "")
    var description: String = TypeSafeMixin._safe_method_call_string(medical_bay, "get_description", [], "")
    var cost: int = TypeSafeMixin._safe_method_call_int(medical_bay, "get_cost", [], 0)
    var power_draw: int = TypeSafeMixin._safe_method_call_int(medical_bay, "get_power_draw", [], 0)
    
    assert_eq(name, "Medical Bay", "Should initialize with correct name")
    assert_eq(description, "Ship medical facility", "Should initialize with correct description")
    assert_eq(cost, GameEnums.MEDICAL_BAY_BASE_COST, "Should initialize with correct cost")
    assert_eq(power_draw, GameEnums.MEDICAL_BAY_POWER_DRAW, "Should initialize with correct power draw")
    
    # Test medical bay-specific properties
    var healing_rate: float = TypeSafeMixin._safe_method_call_float(medical_bay, "get_healing_rate", [], 0.0)
    var max_patients: int = TypeSafeMixin._safe_method_call_int(medical_bay, "get_max_patients", [], 0)
    var current_patients: int = TypeSafeMixin._safe_method_call_int(medical_bay, "get_current_patients", [], 0)
    
    assert_eq(healing_rate, GameEnums.MEDICAL_BAY_BASE_HEALING_RATE, "Should initialize with base healing rate")
    assert_eq(max_patients, GameEnums.MEDICAL_BAY_BASE_MAX_PATIENTS, "Should initialize with base max patients")
    assert_eq(current_patients, 0, "Should initialize with no patients")

func test_upgrade_effects() -> void:
    # Store initial values
    var initial_healing_rate: float = TypeSafeMixin._safe_method_call_float(medical_bay, "get_healing_rate", [], 0.0)
    var initial_max_patients: int = TypeSafeMixin._safe_method_call_int(medical_bay, "get_max_patients", [], 0)
    
    # Perform upgrade
    TypeSafeMixin._safe_method_call_bool(medical_bay, "upgrade", [])
    
    # Test improvements
    var new_healing_rate: float = TypeSafeMixin._safe_method_call_float(medical_bay, "get_healing_rate", [], 0.0)
    var new_max_patients: int = TypeSafeMixin._safe_method_call_int(medical_bay, "get_max_patients", [], 0)
    
    assert_eq(new_healing_rate, initial_healing_rate + GameEnums.MEDICAL_BAY_UPGRADE_HEALING_RATE, "Should increase healing rate on upgrade")
    assert_eq(new_max_patients, initial_max_patients + GameEnums.MEDICAL_BAY_UPGRADE_MAX_PATIENTS, "Should increase max patients on upgrade")

func test_efficiency_effects() -> void:
    # Test base values at full efficiency
    var base_healing_rate: float = TypeSafeMixin._safe_method_call_float(medical_bay, "get_healing_rate", [], 0.0)
    var base_max_patients: int = TypeSafeMixin._safe_method_call_int(medical_bay, "get_max_patients", [], 0)
    
    assert_eq(base_healing_rate, GameEnums.MEDICAL_BAY_BASE_HEALING_RATE, "Should return base healing rate at full efficiency")
    assert_eq(base_max_patients, GameEnums.MEDICAL_BAY_BASE_MAX_PATIENTS, "Should return base max patients at full efficiency")
    
    # Test values at reduced efficiency
    TypeSafeMixin._safe_method_call_bool(medical_bay, "set_efficiency", [GameEnums.HALF_EFFICIENCY])
    
    var reduced_healing_rate: float = TypeSafeMixin._safe_method_call_float(medical_bay, "get_healing_rate", [], 0.0)
    var reduced_max_patients: int = TypeSafeMixin._safe_method_call_int(medical_bay, "get_max_patients", [], 0)
    
    assert_eq(reduced_healing_rate, GameEnums.MEDICAL_BAY_BASE_HEALING_RATE * GameEnums.HALF_EFFICIENCY, "Should reduce healing rate with efficiency")
    assert_eq(reduced_max_patients, GameEnums.MEDICAL_BAY_BASE_MAX_PATIENTS, "Should not reduce max patients with efficiency")

func test_patient_management() -> void:
    # Test adding patients
    var success: bool = TypeSafeMixin._safe_method_call_bool(medical_bay, "add_patient", [], false)
    assert_true(success, "Should successfully add patient within capacity")
    
    var current_patients: int = TypeSafeMixin._safe_method_call_int(medical_bay, "get_current_patients", [], 0)
    assert_eq(current_patients, 1, "Should update current patients")
    
    success = TypeSafeMixin._safe_method_call_bool(medical_bay, "add_patient", [], false)
    assert_true(success, "Should successfully add second patient")
    
    current_patients = TypeSafeMixin._safe_method_call_int(medical_bay, "get_current_patients", [], 0)
    assert_eq(current_patients, 2, "Should update current patients")
    
    # Test patient capacity limit
    success = TypeSafeMixin._safe_method_call_bool(medical_bay, "add_patient", [], false)
    assert_false(success, "Should fail to add patient beyond capacity")
    
    current_patients = TypeSafeMixin._safe_method_call_int(medical_bay, "get_current_patients", [], 0)
    assert_eq(current_patients, GameEnums.MEDICAL_BAY_BASE_MAX_PATIENTS, "Should not change patients on failed add")
    
    # Test removing patients
    success = TypeSafeMixin._safe_method_call_bool(medical_bay, "remove_patient", [], false)
    assert_true(success, "Should successfully remove patient")
    
    current_patients = TypeSafeMixin._safe_method_call_int(medical_bay, "get_current_patients", [], 0)
    assert_eq(current_patients, 1, "Should update current patients after removal")
    
    success = TypeSafeMixin._safe_method_call_bool(medical_bay, "remove_patient", [], false)
    assert_true(success, "Should successfully remove last patient")
    
    current_patients = TypeSafeMixin._safe_method_call_int(medical_bay, "get_current_patients", [], 0)
    assert_eq(current_patients, 0, "Should update current patients after removal")
    
    # Test removing when empty
    success = TypeSafeMixin._safe_method_call_bool(medical_bay, "remove_patient", [], false)
    assert_false(success, "Should fail to remove patient when empty")
    
    current_patients = TypeSafeMixin._safe_method_call_int(medical_bay, "get_current_patients", [], 0)
    assert_eq(current_patients, 0, "Should not change patients on failed removal")

func test_healing_process() -> void:
    # Add a patient
    TypeSafeMixin._safe_method_call_bool(medical_bay, "add_patient", [], false)
    
    # Test healing tick
    var healing_done: float = TypeSafeMixin._safe_method_call_float(medical_bay, "process_healing", [GameEnums.HEALING_TICK_TIME], 0.0)
    assert_eq(healing_done, GameEnums.MEDICAL_BAY_BASE_HEALING_RATE, "Should heal at base rate")
    
    # Test healing with multiple patients
    TypeSafeMixin._safe_method_call_bool(medical_bay, "add_patient", [], false)
    healing_done = TypeSafeMixin._safe_method_call_float(medical_bay, "process_healing", [GameEnums.HEALING_TICK_TIME], 0.0)
    assert_eq(healing_done, GameEnums.MEDICAL_BAY_BASE_HEALING_RATE * 2.0, "Should heal multiple patients")
    
    # Test healing with reduced efficiency
    TypeSafeMixin._safe_method_call_bool(medical_bay, "set_efficiency", [GameEnums.HALF_EFFICIENCY])
    healing_done = TypeSafeMixin._safe_method_call_float(medical_bay, "process_healing", [GameEnums.HEALING_TICK_TIME], 0.0)
    assert_eq(healing_done, GameEnums.MEDICAL_BAY_BASE_HEALING_RATE, "Should heal at reduced rate with reduced efficiency")
    
    # Test no healing when inactive
    TypeSafeMixin._safe_method_call_bool(medical_bay, "set_is_active", [false])
    healing_done = TypeSafeMixin._safe_method_call_float(medical_bay, "process_healing", [GameEnums.HEALING_TICK_TIME], 0.0)
    assert_eq(healing_done, 0.0, "Should not heal when inactive")

func test_serialization() -> void:
    # Modify medical bay state
    TypeSafeMixin._safe_method_call_bool(medical_bay, "set_healing_rate", [GameEnums.MEDICAL_BAY_MAX_HEALING_RATE])
    TypeSafeMixin._safe_method_call_bool(medical_bay, "set_max_patients", [GameEnums.MEDICAL_BAY_MAX_PATIENTS])
    TypeSafeMixin._safe_method_call_bool(medical_bay, "add_patient", [])
    TypeSafeMixin._safe_method_call_bool(medical_bay, "add_patient", [])
    TypeSafeMixin._safe_method_call_bool(medical_bay, "set_level", [GameEnums.MEDICAL_BAY_MAX_LEVEL])
    TypeSafeMixin._safe_method_call_bool(medical_bay, "set_durability", [GameEnums.MEDICAL_BAY_MAX_DURABILITY])
    
    # Serialize and deserialize
    var data: Dictionary = TypeSafeMixin._safe_method_call_dict(medical_bay, "serialize", [], {})
    var new_medical_bay: MedicalBayComponent = MedicalBayComponent.new()
    track_test_resource(new_medical_bay)
    TypeSafeMixin._safe_method_call_bool(new_medical_bay, "deserialize", [data])
    
    # Verify medical bay-specific properties
    var healing_rate: float = TypeSafeMixin._safe_method_call_float(new_medical_bay, "get_healing_rate", [], 0.0)
    var max_patients: int = TypeSafeMixin._safe_method_call_int(new_medical_bay, "get_max_patients", [], 0)
    var current_patients: int = TypeSafeMixin._safe_method_call_int(new_medical_bay, "get_current_patients", [], 0)
    
    assert_eq(healing_rate, GameEnums.MEDICAL_BAY_MAX_HEALING_RATE, "Should preserve healing rate")
    assert_eq(max_patients, GameEnums.MEDICAL_BAY_MAX_PATIENTS, "Should preserve max patients")
    assert_eq(current_patients, 2, "Should preserve current patients")
    
    # Verify inherited properties
    var level: int = TypeSafeMixin._safe_method_call_int(new_medical_bay, "get_level", [], 0)
    var durability: int = TypeSafeMixin._safe_method_call_int(new_medical_bay, "get_durability", [], 0)
    var power_draw: int = TypeSafeMixin._safe_method_call_int(new_medical_bay, "get_power_draw", [], 0)
    
    assert_eq(level, GameEnums.MEDICAL_BAY_MAX_LEVEL, "Should preserve level")
    assert_eq(durability, GameEnums.MEDICAL_BAY_MAX_DURABILITY, "Should preserve durability")
    assert_eq(power_draw, GameEnums.MEDICAL_BAY_POWER_DRAW, "Should preserve power draw")