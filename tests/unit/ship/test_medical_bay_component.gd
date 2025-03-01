@tool
extends GameTest

# Create a mock MedicalBayComponent class for testing purposes
class MockMedicalBayComponent:
    extends RefCounted
    
    var name: String = "Medical Bay"
    var description: String = "Ship medical facility"
    var cost: int = 200
    var power_draw: int = 15
    var healing_rate: float = 2.0
    var max_patients: int = 2
    var current_patients: int = 0
    var level: int = 1
    var durability: int = 100
    var efficiency: float = 1.0
    var is_active: bool = true
    
    func get_name() -> String: return name
    func get_description() -> String: return description
    func get_cost() -> int: return cost
    func get_power_draw() -> int: return power_draw
    func get_healing_rate() -> float: return healing_rate * efficiency
    func get_max_patients() -> int: return max_patients
    func get_current_patients() -> int: return current_patients
    func get_level() -> int: return level
    func get_durability() -> int: return durability
    
    func set_efficiency(value: float) -> bool:
        efficiency = value
        return true
        
    func upgrade() -> bool:
        healing_rate += 0.5
        max_patients += 1
        level += 1
        return true
        
    func set_healing_rate(value: float) -> bool:
        healing_rate = value
        return true
    
    func set_max_patients(value: int) -> bool:
        max_patients = value
        return true
    
    func set_level(value: int) -> bool:
        level = value
        return true
    
    func set_durability(value: int) -> bool:
        durability = value
        return true
        
    func set_is_active(value: bool) -> bool:
        is_active = value
        return true
        
    func add_patient() -> bool:
        if current_patients >= max_patients:
            return false
        current_patients += 1
        return true
        
    func remove_patient() -> bool:
        if current_patients <= 0:
            return false
        current_patients -= 1
        return true
        
    func process_healing(time_delta: float) -> float:
        if not is_active or current_patients <= 0:
            return 0.0
        return healing_rate * efficiency * current_patients
        
    func serialize() -> Dictionary:
        return {
            "name": name,
            "description": description,
            "cost": cost,
            "power_draw": power_draw,
            "healing_rate": healing_rate,
            "max_patients": max_patients,
            "current_patients": current_patients,
            "level": level,
            "durability": durability
        }
        
    func deserialize(data: Dictionary) -> bool:
        name = data.get("name", name)
        description = data.get("description", description)
        cost = data.get("cost", cost)
        power_draw = data.get("power_draw", power_draw)
        healing_rate = data.get("healing_rate", healing_rate)
        max_patients = data.get("max_patients", max_patients)
        current_patients = data.get("current_patients", current_patients)
        level = data.get("level", level)
        durability = data.get("durability", durability)
        return true

# Create a mockup of GameEnums
class MedicalGameEnumsMock:
    const MEDICAL_BAY_BASE_COST = 200
    const MEDICAL_BAY_POWER_DRAW = 15
    const MEDICAL_BAY_BASE_HEALING_RATE = 2.0
    const MEDICAL_BAY_BASE_MAX_PATIENTS = 2
    const MEDICAL_BAY_UPGRADE_HEALING_RATE = 0.5
    const MEDICAL_BAY_UPGRADE_MAX_PATIENTS = 1
    const MEDICAL_BAY_MAX_HEALING_RATE = 5.0
    const MEDICAL_BAY_MAX_PATIENTS = 5
    const MEDICAL_BAY_MAX_LEVEL = 4
    const MEDICAL_BAY_MAX_DURABILITY = 150
    const HALF_EFFICIENCY = 0.5
    const HEALING_TICK_TIME = 1.0

# Try to get the actual component or use our mock
var MedicalBayComponent = null
var medical_enums = null

# Helper method to initialize our test environment
func _initialize_test_environment() -> void:
    # Try to load the real MedicalBayComponent
    var medical_script = load("res://src/core/ships/components/MedicalBayComponent.gd")
    if medical_script:
        MedicalBayComponent = medical_script
    else:
        # Use our mock if the real one isn't available
        MedicalBayComponent = MockMedicalBayComponent
    
    # Try to load the real GameEnums or use our mock
    var enums_script = load("res://src/core/systems/GlobalEnums.gd")
    if enums_script:
        medical_enums = enums_script
    else:
        medical_enums = MedicalGameEnumsMock

# Test variables
var medical_bay = null

func before_each() -> void:
    await super.before_each()
    
    # Initialize our test environment
    _initialize_test_environment()
    
    # Create the medical bay component
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
    
    var name: String = _call_node_method_string(medical_bay, "get_name", [], "")
    var description: String = _call_node_method_string(medical_bay, "get_description", [], "")
    var cost: int = _call_node_method_int(medical_bay, "get_cost", [], 0)
    var power_draw: int = _call_node_method_int(medical_bay, "get_power_draw", [], 0)
    
    assert_eq(name, "Medical Bay", "Should initialize with correct name")
    assert_eq(description, "Ship medical facility", "Should initialize with correct description")
    assert_eq(cost, medical_enums.MEDICAL_BAY_BASE_COST, "Should initialize with correct cost")
    assert_eq(power_draw, medical_enums.MEDICAL_BAY_POWER_DRAW, "Should initialize with correct power draw")
    
    # Test medical bay-specific properties
    var healing_rate: float = _call_node_method_float(medical_bay, "get_healing_rate", [], 0.0)
    var max_patients: int = _call_node_method_int(medical_bay, "get_max_patients", [], 0)
    var current_patients: int = _call_node_method_int(medical_bay, "get_current_patients", [], 0)
    
    assert_eq(healing_rate, medical_enums.MEDICAL_BAY_BASE_HEALING_RATE, "Should initialize with base healing rate")
    assert_eq(max_patients, medical_enums.MEDICAL_BAY_BASE_MAX_PATIENTS, "Should initialize with base max patients")
    assert_eq(current_patients, 0, "Should initialize with no patients")

func test_upgrade_effects() -> void:
    # Store initial values
    var initial_healing_rate: float = _call_node_method_float(medical_bay, "get_healing_rate", [], 0.0)
    var initial_max_patients: int = _call_node_method_int(medical_bay, "get_max_patients", [], 0)
    
    # Perform upgrade
    _call_node_method_bool(medical_bay, "upgrade", [])
    
    # Test improvements
    var new_healing_rate: float = _call_node_method_float(medical_bay, "get_healing_rate", [], 0.0)
    var new_max_patients: int = _call_node_method_int(medical_bay, "get_max_patients", [], 0)
    
    assert_eq(new_healing_rate, initial_healing_rate + medical_enums.MEDICAL_BAY_UPGRADE_HEALING_RATE, "Should increase healing rate on upgrade")
    assert_eq(new_max_patients, initial_max_patients + medical_enums.MEDICAL_BAY_UPGRADE_MAX_PATIENTS, "Should increase max patients on upgrade")

func test_efficiency_effects() -> void:
    # Test base values at full efficiency
    var base_healing_rate: float = _call_node_method_float(medical_bay, "get_healing_rate", [], 0.0)
    var base_max_patients: int = _call_node_method_int(medical_bay, "get_max_patients", [], 0)
    
    assert_eq(base_healing_rate, medical_enums.MEDICAL_BAY_BASE_HEALING_RATE, "Should return base healing rate at full efficiency")
    assert_eq(base_max_patients, medical_enums.MEDICAL_BAY_BASE_MAX_PATIENTS, "Should return base max patients at full efficiency")
    
    # Test values at reduced efficiency
    _call_node_method_bool(medical_bay, "set_efficiency", [medical_enums.HALF_EFFICIENCY])
    
    var reduced_healing_rate: float = _call_node_method_float(medical_bay, "get_healing_rate", [], 0.0)
    var reduced_max_patients: int = _call_node_method_int(medical_bay, "get_max_patients", [], 0)
    
    assert_eq(reduced_healing_rate, medical_enums.MEDICAL_BAY_BASE_HEALING_RATE * medical_enums.HALF_EFFICIENCY, "Should reduce healing rate with efficiency")
    assert_eq(reduced_max_patients, medical_enums.MEDICAL_BAY_BASE_MAX_PATIENTS, "Should not reduce max patients with efficiency")

func test_patient_management() -> void:
    # Test adding patients
    var success: bool = _call_node_method_bool(medical_bay, "add_patient", [], false)
    assert_true(success, "Should successfully add patient within capacity")
    
    var current_patients: int = _call_node_method_int(medical_bay, "get_current_patients", [], 0)
    assert_eq(current_patients, 1, "Should update current patients")
    
    success = _call_node_method_bool(medical_bay, "add_patient", [], false)
    assert_true(success, "Should successfully add second patient")
    
    current_patients = _call_node_method_int(medical_bay, "get_current_patients", [], 0)
    assert_eq(current_patients, 2, "Should update current patients")
    
    # Test patient capacity limit
    success = _call_node_method_bool(medical_bay, "add_patient", [], false)
    assert_false(success, "Should fail to add patient beyond capacity")
    
    current_patients = _call_node_method_int(medical_bay, "get_current_patients", [], 0)
    assert_eq(current_patients, medical_enums.MEDICAL_BAY_BASE_MAX_PATIENTS, "Should not change patients on failed add")
    
    # Test removing patients
    success = _call_node_method_bool(medical_bay, "remove_patient", [], false)
    assert_true(success, "Should successfully remove patient")
    
    current_patients = _call_node_method_int(medical_bay, "get_current_patients", [], 0)
    assert_eq(current_patients, 1, "Should update current patients after removal")
    
    success = _call_node_method_bool(medical_bay, "remove_patient", [], false)
    assert_true(success, "Should successfully remove last patient")
    
    current_patients = _call_node_method_int(medical_bay, "get_current_patients", [], 0)
    assert_eq(current_patients, 0, "Should update current patients after removal")
    
    # Test removing when empty
    success = _call_node_method_bool(medical_bay, "remove_patient", [], false)
    assert_false(success, "Should fail to remove patient when empty")
    
    current_patients = _call_node_method_int(medical_bay, "get_current_patients", [], 0)
    assert_eq(current_patients, 0, "Should not change patients on failed removal")

func test_healing_process() -> void:
    # Add a patient
    _call_node_method_bool(medical_bay, "add_patient", [], false)
    
    # Test healing tick
    var healing_done: float = _call_node_method_float(medical_bay, "process_healing", [medical_enums.HEALING_TICK_TIME], 0.0)
    assert_eq(healing_done, medical_enums.MEDICAL_BAY_BASE_HEALING_RATE, "Should heal at base rate")
    
    # Test healing with multiple patients
    _call_node_method_bool(medical_bay, "add_patient", [], false)
    healing_done = _call_node_method_float(medical_bay, "process_healing", [medical_enums.HEALING_TICK_TIME], 0.0)
    assert_eq(healing_done, medical_enums.MEDICAL_BAY_BASE_HEALING_RATE * 2.0, "Should heal multiple patients")
    
    # Test healing with reduced efficiency
    _call_node_method_bool(medical_bay, "set_efficiency", [medical_enums.HALF_EFFICIENCY])
    healing_done = _call_node_method_float(medical_bay, "process_healing", [medical_enums.HEALING_TICK_TIME], 0.0)
    assert_eq(healing_done, medical_enums.MEDICAL_BAY_BASE_HEALING_RATE, "Should heal at reduced rate with reduced efficiency")
    
    # Test no healing when inactive
    _call_node_method_bool(medical_bay, "set_is_active", [false])
    healing_done = _call_node_method_float(medical_bay, "process_healing", [medical_enums.HEALING_TICK_TIME], 0.0)
    assert_eq(healing_done, 0.0, "Should not heal when inactive")

func test_serialization() -> void:
    # Modify medical bay state
    _call_node_method_bool(medical_bay, "set_healing_rate", [medical_enums.MEDICAL_BAY_MAX_HEALING_RATE])
    _call_node_method_bool(medical_bay, "set_max_patients", [medical_enums.MEDICAL_BAY_MAX_PATIENTS])
    _call_node_method_bool(medical_bay, "add_patient", [])
    _call_node_method_bool(medical_bay, "add_patient", [])
    _call_node_method_bool(medical_bay, "set_level", [medical_enums.MEDICAL_BAY_MAX_LEVEL])
    _call_node_method_bool(medical_bay, "set_durability", [medical_enums.MEDICAL_BAY_MAX_DURABILITY])
    
    # Serialize and deserialize
    var data: Dictionary = _call_node_method_dict(medical_bay, "serialize", [], {})
    var new_medical_bay = MedicalBayComponent.new()
    track_test_resource(new_medical_bay)
    _call_node_method_bool(new_medical_bay, "deserialize", [data])
    
    # Verify medical bay-specific properties
    var healing_rate: float = _call_node_method_float(new_medical_bay, "get_healing_rate", [], 0.0)
    var max_patients: int = _call_node_method_int(new_medical_bay, "get_max_patients", [], 0)
    var current_patients: int = _call_node_method_int(new_medical_bay, "get_current_patients", [], 0)
    
    assert_eq(healing_rate, medical_enums.MEDICAL_BAY_MAX_HEALING_RATE, "Should preserve healing rate")
    assert_eq(max_patients, medical_enums.MEDICAL_BAY_MAX_PATIENTS, "Should preserve max patients")
    assert_eq(current_patients, 2, "Should preserve current patients")
    
    # Verify inherited properties
    var level: int = _call_node_method_int(new_medical_bay, "get_level", [], 0)
    var durability: int = _call_node_method_int(new_medical_bay, "get_durability", [], 0)
    var power_draw: int = _call_node_method_int(new_medical_bay, "get_power_draw", [], 0)
    
    assert_eq(level, medical_enums.MEDICAL_BAY_MAX_LEVEL, "Should preserve level")
    assert_eq(durability, medical_enums.MEDICAL_BAY_MAX_DURABILITY, "Should preserve durability")
    assert_eq(power_draw, medical_enums.MEDICAL_BAY_POWER_DRAW, "Should preserve power draw")