extends "res://addons/gut/test.gd"

const MedicalBayComponent = preload("res://src/core/ships/components/MedicalBayComponent.gd")

var medical_bay: MedicalBayComponent

func before_each() -> void:
    medical_bay = MedicalBayComponent.new()

func after_each() -> void:
    medical_bay = null

func test_initialization() -> void:
    assert_eq(medical_bay.name, "Medical Bay", "Should initialize with correct name")
    assert_eq(medical_bay.description, "Standard medical bay", "Should initialize with correct description")
    assert_eq(medical_bay.cost, 300, "Should initialize with correct cost")
    assert_eq(medical_bay.power_draw, 2, "Should initialize with correct power draw")
    
    # Test medical bay-specific properties
    assert_eq(medical_bay.healing_rate, 1.0, "Should initialize with base healing rate")
    assert_eq(medical_bay.treatment_capacity, 2, "Should initialize with base treatment capacity")
    assert_eq(medical_bay.medical_supplies, 100, "Should initialize with base medical supplies")
    assert_eq(medical_bay.treatment_quality, 1.0, "Should initialize with base treatment quality")
    assert_eq(medical_bay.patients.size(), 0, "Should initialize with no patients")

func test_upgrade_effects() -> void:
    # Store initial values
    var initial_healing_rate = medical_bay.healing_rate
    var initial_treatment_capacity = medical_bay.treatment_capacity
    var initial_medical_supplies = medical_bay.medical_supplies
    var initial_treatment_quality = medical_bay.treatment_quality
    
    # Perform upgrade
    medical_bay.upgrade()
    
    # Test improvements
    assert_eq(medical_bay.healing_rate, initial_healing_rate + 0.2, "Should increase healing rate on upgrade")
    assert_eq(medical_bay.treatment_capacity, initial_treatment_capacity + 1, "Should increase treatment capacity on upgrade")
    assert_eq(medical_bay.medical_supplies, initial_medical_supplies + 25, "Should increase medical supplies on upgrade")
    assert_eq(medical_bay.treatment_quality, initial_treatment_quality + 0.1, "Should increase treatment quality on upgrade")

func test_efficiency_effects() -> void:
    # Test base values at full efficiency
    assert_eq(medical_bay.get_healing_rate(), 1.0, "Should return base healing rate at full efficiency")
    assert_eq(medical_bay.get_treatment_quality(), 1.0, "Should return base treatment quality at full efficiency")
    
    # Test values at reduced efficiency
    medical_bay.take_damage(50) # 50% efficiency
    assert_eq(medical_bay.get_healing_rate(), 0.5, "Should reduce healing rate with efficiency")
    assert_eq(medical_bay.get_treatment_quality(), 0.5, "Should reduce treatment quality with efficiency")

func test_patient_management() -> void:
    var test_patient = {
        "id": "test_1",
        "name": "Test Patient",
        "health": 50,
        "max_health": 100,
        "treatment_time": 0.0
    }
    
    # Test adding patients
    assert_true(medical_bay.can_accept_patient(test_patient), "Should be able to accept patient when capacity available")
    medical_bay.add_patient(test_patient)
    assert_eq(medical_bay.patients.size(), 1, "Should have one patient")
    assert_true(test_patient in medical_bay.patients, "Should contain added patient")
    
    # Test capacity limits
    var patients_to_fill = medical_bay.treatment_capacity - 1
    for i in range(patients_to_fill):
        var new_patient = test_patient.duplicate()
        new_patient.id = "test_%d" % (i + 2)
        medical_bay.add_patient(new_patient)
    
    var overflow_patient = test_patient.duplicate()
    overflow_patient.id = "overflow"
    assert_false(medical_bay.can_accept_patient(overflow_patient), "Should not accept patients beyond capacity")
    
    # Test removing patients
    medical_bay.remove_patient(test_patient)
    assert_eq(medical_bay.patients.size(), patients_to_fill, "Should remove patient")
    assert_false(test_patient in medical_bay.patients, "Should not contain removed patient")

func test_healing_process() -> void:
    var test_patient = {
        "id": "test_1",
        "name": "Test Patient",
        "health": 50,
        "max_health": 100,
        "treatment_time": 0.0
    }
    
    medical_bay.add_patient(test_patient)
    
    # Test healing tick
    medical_bay.process_healing(1.0) # 1 second tick
    assert_eq(test_patient.health, 51, "Should heal patient by healing rate * delta")
    assert_eq(medical_bay.medical_supplies, 99, "Should consume medical supplies")
    
    # Test healing cap
    test_patient.health = 99
    medical_bay.process_healing(1.0)
    assert_eq(test_patient.health, 100, "Should not heal beyond max health")
    
    # Test no healing when inactive
    medical_bay.is_active = false
    test_patient.health = 50
    medical_bay.process_healing(1.0)
    assert_eq(test_patient.health, 50, "Should not heal when inactive")
    
    # Test no healing without supplies
    medical_bay.is_active = true
    medical_bay.medical_supplies = 0
    medical_bay.process_healing(1.0)
    assert_eq(test_patient.health, 50, "Should not heal without supplies")

func test_treatment_time_tracking() -> void:
    var test_patient = {
        "id": "test_1",
        "name": "Test Patient",
        "health": 50,
        "max_health": 100,
        "treatment_time": 0.0
    }
    
    medical_bay.add_patient(test_patient)
    
    # Test time accumulation
    medical_bay.process_healing(1.0)
    assert_eq(test_patient.treatment_time, 1.0, "Should track treatment time")
    
    medical_bay.process_healing(2.0)
    assert_eq(test_patient.treatment_time, 3.0, "Should accumulate treatment time")

func test_serialization() -> void:
    # Modify medical bay state
    medical_bay.healing_rate = 1.5
    medical_bay.treatment_capacity = 3
    medical_bay.medical_supplies = 75
    medical_bay.treatment_quality = 1.2
    medical_bay.level = 2
    medical_bay.durability = 75
    
    var test_patient = {
        "id": "test_1",
        "name": "Test Patient",
        "health": 50,
        "max_health": 100,
        "treatment_time": 5.0
    }
    medical_bay.add_patient(test_patient)
    
    # Serialize and deserialize
    var data = medical_bay.serialize()
    var new_medical_bay = MedicalBayComponent.deserialize(data)
    
    # Verify medical bay-specific properties
    assert_eq(new_medical_bay.healing_rate, medical_bay.healing_rate, "Should preserve healing rate")
    assert_eq(new_medical_bay.treatment_capacity, medical_bay.treatment_capacity, "Should preserve treatment capacity")
    assert_eq(new_medical_bay.medical_supplies, medical_bay.medical_supplies, "Should preserve medical supplies")
    assert_eq(new_medical_bay.treatment_quality, medical_bay.treatment_quality, "Should preserve treatment quality")
    assert_eq(new_medical_bay.patients.size(), medical_bay.patients.size(), "Should preserve patients")
    
    # Verify inherited properties
    assert_eq(new_medical_bay.level, medical_bay.level, "Should preserve level")
    assert_eq(new_medical_bay.durability, medical_bay.durability, "Should preserve durability")
    assert_eq(new_medical_bay.power_draw, medical_bay.power_draw, "Should preserve power draw")