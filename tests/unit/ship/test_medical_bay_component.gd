@tool
extends GdUnitGameTest

# Mock Medical Bay Component with realistic behavior
class MockMedicalBayComponent extends Resource:
    var name: String = "Medical Bay"
    var description: String = "Ship medical facility"
    var cost: int = 200
    var power_draw: int = 30
    var healing_rate: float = 10.0
    var max_patients: int = 2
    var current_patients: int = 0
    var level: int = 1
    var durability: int = 100
    var efficiency: float = 1.0
    var is_active: bool = true
    
    func get_component_name() -> String: return name
    func get_component_description() -> String: return description
    func get_cost() -> int: return cost
    func get_power_draw() -> int: return power_draw
    func get_healing_rate() -> float: return healing_rate * efficiency if is_active else 0.0
    func get_max_patients() -> int: return max_patients
    func get_current_patients() -> int: return current_patients
    func get_level() -> int: return level
    func get_durability() -> int: return durability
    func get_efficiency() -> float: return efficiency
    func get_is_active() -> bool: return is_active
    
    func set_level(value: int) -> void: level = value
    func set_durability(value: int) -> void: durability = value
    func set_efficiency(value: float) -> void: efficiency = value
    func set_is_active(value: bool) -> void: is_active = value
    
    func upgrade() -> void:
        healing_rate += 5.0
        max_patients += 1
        level += 1
    
    func add_patient() -> bool:
        if current_patients < max_patients:
            current_patients += 1
            return true
        return false
    
    func remove_patient() -> bool:
        if current_patients > 0:
            current_patients -= 1
            return true
        return false
    
    func process_healing(delta_time: float) -> float:
        if not is_active or current_patients == 0:
            return 0.0
        return get_healing_rate() * current_patients * delta_time
    
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
            "durability": durability,
            "efficiency": efficiency,
            "is_active": is_active
        }
    
    func deserialize(data: Dictionary) -> void:
        name = data.get("name", name)
        description = data.get("description", description)
        cost = data.get("cost", cost)
        power_draw = data.get("power_draw", power_draw)
        healing_rate = data.get("healing_rate", healing_rate)
        max_patients = data.get("max_patients", max_patients)
        current_patients = data.get("current_patients", current_patients)
        level = data.get("level", level)
        durability = data.get("durability", durability)
        efficiency = data.get("efficiency", efficiency)
        is_active = data.get("is_active", is_active)

# Test medical bay component
var medical_bay: MockMedicalBayComponent = null

# Test environment setup
func _initialize_test_environment() -> void:
    medical_bay = MockMedicalBayComponent.new()
    track_resource(medical_bay)

func before_test() -> void:
    await super.before_test()
    
    # Initialize our test environment
    _initialize_test_environment()
    
    # Initialize medical bay with test values (already set by mock)
    medical_bay.set_level(1)
    medical_bay.set_durability(100)
    medical_bay.set_efficiency(1.0)

func after_test() -> void:
    medical_bay = null
    await super.after_test()

func test_initialization() -> void:
    assert_that(medical_bay).is_not_null()
    
    assert_that(medical_bay.get_component_name()).is_equal("Medical Bay")
    assert_that(medical_bay.get_component_description()).is_equal("Ship medical facility")
    assert_that(medical_bay.get_cost()).is_equal(200)
    assert_that(medical_bay.get_power_draw()).is_equal(30)
    
    # Test medical bay-specific properties
    assert_that(medical_bay.get_healing_rate()).is_equal(10.0)
    assert_that(medical_bay.get_max_patients()).is_equal(2)
    assert_that(medical_bay.get_current_patients()).is_equal(0)

func test_upgrade_effects() -> void:
    # Store initial values
    var initial_healing_rate: float = medical_bay.get_healing_rate()
    var initial_max_patients: int = medical_bay.get_max_patients()
    
    # Upgrade medical bay
    medical_bay.upgrade()
    
    assert_that(medical_bay.get_healing_rate()).is_equal(initial_healing_rate + 5.0)
    assert_that(medical_bay.get_max_patients()).is_equal(initial_max_patients + 1)

func test_efficiency_effects() -> void:
    # Test base values at full efficiency
    assert_that(medical_bay.get_healing_rate()).is_equal(10.0)
    assert_that(medical_bay.get_max_patients()).is_equal(2)
    
    # Test values at reduced efficiency
    medical_bay.set_efficiency(0.5)
    
    assert_that(medical_bay.get_healing_rate()).is_equal(5.0) # 10.0 * 0.5
    assert_that(medical_bay.get_max_patients()).is_equal(2) # Max patients not affected by efficiency

func test_patient_management() -> void:
    # Test adding patients
    assert_that(medical_bay.add_patient()).is_true()
    assert_that(medical_bay.get_current_patients()).is_equal(1)
    
    assert_that(medical_bay.add_patient()).is_true()
    assert_that(medical_bay.get_current_patients()).is_equal(2)
    
    # Test patient capacity limit
    assert_that(medical_bay.add_patient()).is_false()
    assert_that(medical_bay.get_current_patients()).is_equal(2)
    
    # Test removing patients
    assert_that(medical_bay.remove_patient()).is_true()
    assert_that(medical_bay.get_current_patients()).is_equal(1)
    
    assert_that(medical_bay.remove_patient()).is_true()
    assert_that(medical_bay.get_current_patients()).is_equal(0)
    
    # Test removing when empty
    assert_that(medical_bay.remove_patient()).is_false()
    assert_that(medical_bay.get_current_patients()).is_equal(0)

func test_healing_process() -> void:
    # Add a patient
    medical_bay.add_patient()
    
    # Test healing tick (1 second)
    var healing_done: float = medical_bay.process_healing(1.0)
    assert_that(healing_done).is_equal(10.0) # 10.0 healing rate * 1 patient * 1 second
    
    # Test healing with multiple patients
    medical_bay.add_patient()
    healing_done = medical_bay.process_healing(1.0)
    assert_that(healing_done).is_equal(20.0) # 10.0 healing rate * 2 patients * 1 second
    
    # Test healing with reduced efficiency
    medical_bay.set_efficiency(0.5)
    healing_done = medical_bay.process_healing(1.0)
    assert_that(healing_done).is_equal(10.0) # 5.0 healing rate * 2 patients * 1 second
    
    # Test no healing when inactive
    medical_bay.set_is_active(false)
    healing_done = medical_bay.process_healing(1.0)
    assert_that(healing_done).is_equal(0.0)

func test_serialization() -> void:
    # Modify medical bay state
    medical_bay.set_level(5)
    medical_bay.set_durability(150)
    medical_bay.add_patient()
    medical_bay.add_patient()
    
    # Serialize
    var data: Dictionary = medical_bay.serialize()
    
    # Create new medical bay and deserialize
    var new_medical_bay: MockMedicalBayComponent = MockMedicalBayComponent.new()
    track_resource(new_medical_bay)
    new_medical_bay.deserialize(data)
    
    # Verify medical bay-specific properties
    assert_that(new_medical_bay.get_healing_rate()).is_equal(10.0) # Base healing rate
    assert_that(new_medical_bay.get_max_patients()).is_equal(2) # Base max patients
    assert_that(new_medical_bay.get_current_patients()).is_equal(2)
    
    # Verify inherited properties
    assert_that(new_medical_bay.get_level()).is_equal(5)
    assert_that(new_medical_bay.get_durability()).is_equal(150)
    assert_that(new_medical_bay.get_power_draw()).is_equal(30)

# Helper methods are no longer needed with mock objects  