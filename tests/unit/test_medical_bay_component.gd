@tool
extends GameTest

const MedicalBayComponentScript: GDScript = preload("res://src/core/ships/components/MedicalBayComponent.gd")

# Type-safe component reference
var medical_bay: Node

# Type-safe test lifecycle
func before_each() -> void:
    await super.before_each()
    medical_bay = Node.new()
    medical_bay.set_script(MedicalBayComponentScript)
    if not medical_bay.get_script() == MedicalBayComponentScript:
        push_error("Failed to set MedicalBayComponent script")
        return
    add_child_autofree(medical_bay)
    track_test_node(medical_bay)

func after_each() -> void:
    medical_bay = null
    await super.after_each()

# Type-safe property access
func _get_medical_bay_property(property: String, default_value: Variant = null) -> Variant:
    if not medical_bay:
        push_error("Trying to access property '%s' on null medical bay" % property)
        return default_value
    if not property in medical_bay:
        push_error("Medical bay missing required property: %s" % property)
        return default_value
    return medical_bay.get(property)

# Type-safe test methods
func test_initialization() -> void:
    assert_not_null(medical_bay, "Medical bay should exist")
    
    var name: String = _get_medical_bay_property("name", "")
    var description: String = _get_medical_bay_property("description", "")
    var cost: int = _safe_cast_int(_get_medical_bay_property("cost", 0), "Cost should be an integer")
    var power_draw: int = _safe_cast_int(_get_medical_bay_property("power_draw", 0), "Power draw should be an integer")
    
    assert_eq(name, "Medical Bay", "Should initialize with correct name")
    assert_eq(description, "Standard medical bay", "Should initialize with correct description")
    assert_eq(cost, 300, "Should initialize with correct cost")
    assert_eq(power_draw, 2, "Should initialize with correct power draw")
    
    # Test medical bay-specific properties
    var healing_rate: float = _get_medical_bay_property("healing_rate", 0.0)
    var treatment_capacity: int = _safe_cast_int(_get_medical_bay_property("treatment_capacity", 0), "Treatment capacity should be an integer")
    var medical_supplies: int = _safe_cast_int(_get_medical_bay_property("medical_supplies", 0), "Medical supplies should be an integer")
    var treatment_quality: float = _get_medical_bay_property("treatment_quality", 0.0)
    var patients: Array = _safe_cast_array(_get_medical_bay_property("patients", []), "Patients should be an array")
    
    assert_eq(healing_rate, 1.0, "Should initialize with base healing rate")
    assert_eq(treatment_capacity, 2, "Should initialize with base treatment capacity")
    assert_eq(medical_supplies, 100, "Should initialize with base medical supplies")
    assert_eq(treatment_quality, 1.0, "Should initialize with base treatment quality")
    assert_eq(patients.size(), 0, "Should initialize with no patients")

func test_upgrade_effects() -> void:
    # Store initial values with type safety
    var initial_healing_rate: float = _get_medical_bay_property("healing_rate", 0.0)
    var initial_treatment_capacity: int = _safe_cast_int(_get_medical_bay_property("treatment_capacity", 0), "Treatment capacity should be an integer")
    var initial_medical_supplies: int = _safe_cast_int(_get_medical_bay_property("medical_supplies", 0), "Medical supplies should be an integer")
    var initial_treatment_quality: float = _get_medical_bay_property("treatment_quality", 0.0)
    
    # Perform upgrade with type-safe method call
    _call_node_method(medical_bay, "upgrade")
    
    # Test improvements with type safety
    var new_healing_rate: float = _get_medical_bay_property("healing_rate", 0.0)
    var new_treatment_capacity: int = _safe_cast_int(_get_medical_bay_property("treatment_capacity", 0), "Treatment capacity should be an integer")
    var new_medical_supplies: int = _safe_cast_int(_get_medical_bay_property("medical_supplies", 0), "Medical supplies should be an integer")
    var new_treatment_quality: float = _get_medical_bay_property("treatment_quality", 0.0)
    
    assert_eq(new_healing_rate, initial_healing_rate + 0.2, "Should increase healing rate on upgrade")
    assert_eq(new_treatment_capacity, initial_treatment_capacity + 1, "Should increase treatment capacity on upgrade")
    assert_eq(new_medical_supplies, initial_medical_supplies + 25, "Should increase medical supplies on upgrade")
    assert_eq(new_treatment_quality, initial_treatment_quality + 0.1, "Should increase treatment quality on upgrade")

func test_efficiency_effects() -> void:
    # Test base values at full efficiency with type-safe method calls
    var base_healing_rate: float = _call_node_method(medical_bay, "get_healing_rate")
    var base_treatment_quality: float = _call_node_method(medical_bay, "get_treatment_quality")
    
    assert_eq(base_healing_rate, 1.0, "Should return base healing rate at full efficiency")
    assert_eq(base_treatment_quality, 1.0, "Should return base treatment quality at full efficiency")
    
    # Test values at reduced efficiency
    _call_node_method(medical_bay, "take_damage", [50]) # 50% efficiency
    
    var reduced_healing_rate: float = _call_node_method(medical_bay, "get_healing_rate")
    var reduced_treatment_quality: float = _call_node_method(medical_bay, "get_treatment_quality")
    
    assert_eq(reduced_healing_rate, 0.5, "Should reduce healing rate with efficiency")
    assert_eq(reduced_treatment_quality, 0.5, "Should reduce treatment quality with efficiency")

func test_patient_management() -> void:
    var test_patient: Dictionary = {
        "id": "test_1",
        "name": "Test Patient",
        "health": 50,
        "max_health": 100,
        "treatment_time": 0.0
    }
    
    # Test adding patients with type-safe method calls
    var can_accept: bool = _call_node_method_bool(medical_bay, "can_accept_patient", [test_patient])
    assert_true(can_accept, "Should be able to accept patient when capacity available")
    
    _call_node_method(medical_bay, "add_patient", [test_patient])
    var patients: Array = _safe_cast_array(_get_medical_bay_property("patients", []), "Patients should be an array")
    assert_eq(patients.size(), 1, "Should have one patient")
    assert_true(test_patient in patients, "Should contain added patient")
    
    # Test capacity limits
    var treatment_capacity: int = _safe_cast_int(_get_medical_bay_property("treatment_capacity", 0), "Treatment capacity should be an integer")
    var patients_to_fill: int = treatment_capacity - 1
    
    for i in range(patients_to_fill):
        var new_patient: Dictionary = test_patient.duplicate()
        new_patient.id = "test_%d" % (i + 2)
        _call_node_method(medical_bay, "add_patient", [new_patient])
    
    var overflow_patient: Dictionary = test_patient.duplicate()
    overflow_patient.id = "overflow"
    can_accept = _call_node_method_bool(medical_bay, "can_accept_patient", [overflow_patient])
    assert_false(can_accept, "Should not accept patients beyond capacity")
    
    # Test removing patients
    _call_node_method(medical_bay, "remove_patient", [test_patient])
    patients = _safe_cast_array(_get_medical_bay_property("patients", []), "Patients should be an array")
    assert_eq(patients.size(), patients_to_fill, "Should remove patient")
    assert_false(test_patient in patients, "Should not contain removed patient")

func test_healing_process() -> void:
    var test_patient: Dictionary = {
        "id": "test_1",
        "name": "Test Patient",
        "health": 50,
        "max_health": 100,
        "treatment_time": 0.0
    }
    
    _call_node_method(medical_bay, "add_patient", [test_patient])
    
    # Test healing tick with type-safe method calls
    _call_node_method(medical_bay, "process_healing", [1.0]) # 1 second tick
    assert_eq(test_patient.health, 51, "Should heal patient by healing rate * delta")
    
    var medical_supplies: int = _safe_cast_int(_get_medical_bay_property("medical_supplies", 0), "Medical supplies should be an integer")
    assert_eq(medical_supplies, 99, "Should consume medical supplies")
    
    # Test healing cap
    test_patient.health = 99
    _call_node_method(medical_bay, "process_healing", [1.0])
    assert_eq(test_patient.health, 100, "Should not heal beyond max health")
    
    # Test no healing when inactive
    _set_property_safe(medical_bay, "is_active", false)
    test_patient.health = 50
    _call_node_method(medical_bay, "process_healing", [1.0])
    assert_eq(test_patient.health, 50, "Should not heal when inactive")
    
    # Test no healing without supplies
    _set_property_safe(medical_bay, "is_active", true)
    _set_property_safe(medical_bay, "medical_supplies", 0)
    _call_node_method(medical_bay, "process_healing", [1.0])
    assert_eq(test_patient.health, 50, "Should not heal without supplies")

func test_treatment_time_tracking() -> void:
    var test_patient: Dictionary = {
        "id": "test_1",
        "name": "Test Patient",
        "health": 50,
        "max_health": 100,
        "treatment_time": 0.0
    }
    
    _call_node_method(medical_bay, "add_patient", [test_patient])
    
    # Test time accumulation with type-safe method calls
    _call_node_method(medical_bay, "process_healing", [1.0])
    assert_eq(test_patient.treatment_time, 1.0, "Should track treatment time")
    
    _call_node_method(medical_bay, "process_healing", [2.0])
    assert_eq(test_patient.treatment_time, 3.0, "Should accumulate treatment time")

func test_serialization() -> void:
    # Modify medical bay state with type-safe property access
    _set_property_safe(medical_bay, "healing_rate", 1.5)
    _set_property_safe(medical_bay, "treatment_capacity", 3)
    _set_property_safe(medical_bay, "medical_supplies", 75)
    _set_property_safe(medical_bay, "treatment_quality", 1.2)
    _set_property_safe(medical_bay, "level", 2)
    _set_property_safe(medical_bay, "durability", 75)
    
    var test_patient: Dictionary = {
        "id": "test_1",
        "name": "Test Patient",
        "health": 50,
        "max_health": 100,
        "treatment_time": 5.0
    }
    _call_node_method(medical_bay, "add_patient", [test_patient])
    
    # Serialize and deserialize with type-safe method calls
    var data: Dictionary = _call_node_method_dict(medical_bay, "serialize")
    var new_medical_bay: Node = Node.new()
    new_medical_bay.set_script(MedicalBayComponentScript)
    track_test_node(new_medical_bay)
    _call_node_method(new_medical_bay, "deserialize", [data])
    
    # Verify medical bay-specific properties with type safety
    assert_eq(_get_medical_bay_property(new_medical_bay, "healing_rate"), 1.5, "Should preserve healing rate")
    assert_eq(_safe_cast_int(_get_medical_bay_property(new_medical_bay, "treatment_capacity")), 3, "Should preserve treatment capacity")
    assert_eq(_safe_cast_int(_get_medical_bay_property(new_medical_bay, "medical_supplies")), 75, "Should preserve medical supplies")
    assert_eq(_get_medical_bay_property(new_medical_bay, "treatment_quality"), 1.2, "Should preserve treatment quality")
    
    var new_patients: Array = _safe_cast_array(_get_medical_bay_property(new_medical_bay, "patients", []), "Patients should be an array")
    assert_eq(new_patients.size(), 1, "Should preserve patients")
    
    # Verify inherited properties with type safety
    assert_eq(_safe_cast_int(_get_medical_bay_property(new_medical_bay, "level")), 2, "Should preserve level")
    assert_eq(_safe_cast_int(_get_medical_bay_property(new_medical_bay, "durability")), 75, "Should preserve durability")
    assert_eq(_safe_cast_int(_get_medical_bay_property(new_medical_bay, "power_draw")), 2, "Should preserve power draw")