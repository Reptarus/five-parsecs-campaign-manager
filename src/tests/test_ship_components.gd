extends Node

const Ship = preload("res://src/core/ships/Ship.gd")

var ship: Ship

func _ready() -> void:
    ship = Ship.new()
    run_tests()

func run_tests() -> void:
    test_hull_component()
    test_engine_component()
    test_medical_component()
    test_weapons_component()
    test_power_management()
    test_component_upgrades()
    test_damage_and_repair()
    print("All tests completed!")

func test_hull_component() -> void:
    print("\nTesting Hull Component:")
    var hull = ship.hull_component
    
    # Test initial values
    print("Initial armor: ", hull.get_armor())
    print("Initial shield: ", hull.get_shield())
    print("Initial cargo capacity: ", hull.get_cargo_capacity())
    print("Initial crew capacity: ", hull.get_crew_capacity())
    
    # Test cargo management
    assert(hull.add_cargo(50))
    print("Added 50 cargo, space available: ", hull.get_cargo_space_available())
    assert(hull.remove_cargo(20))
    print("Removed 20 cargo, space available: ", hull.get_cargo_space_available())
    
    # Test crew management
    assert(hull.add_crew(2))
    print("Added 2 crew, space available: ", hull.get_crew_space_available())
    assert(hull.remove_crew(1))
    print("Removed 1 crew, space available: ", hull.get_crew_space_available())
    
    # Test shield mechanics
    print("Initial shield: ", hull.current_shield)
    hull.recharge_shield(1.0)
    print("Shield after recharge: ", hull.current_shield)
    hull.take_damage(15)
    print("Shield after damage: ", hull.current_shield)

func test_engine_component() -> void:
    print("\nTesting Engine Component:")
    var engine = ship.engine_component
    
    # Test initial values
    print("Initial speed: ", engine.get_speed())
    print("Initial maneuverability: ", engine.get_maneuverability())
    print("Initial fuel efficiency: ", engine.get_fuel_efficiency())
    
    # Test movement
    var distance = engine.calculate_travel_cost(Vector3(100, 0, 0))
    print("Travel cost for 100 units: ", distance)
    
    # Test fuel management
    print("Initial fuel: ", engine.get_fuel_remaining())
    engine.consume_fuel(10)
    print("Fuel after consumption: ", engine.get_fuel_remaining())
    engine.refuel(20)
    print("Fuel after refuel: ", engine.get_fuel_remaining())

func test_medical_component() -> void:
    print("\nTesting Medical Component:")
    var medbay = ship.medical_component
    
    # Test initial values
    print("Initial healing rate: ", medbay.get_healing_rate())
    print("Initial treatment quality: ", medbay.get_treatment_quality())
    print("Initial supplies efficiency: ", medbay.get_supplies_efficiency())
    
    # Test patient management
    var patient = {"id": 1, "name": "Test Patient", "health": 50, "max_health": 100}
    assert(medbay.admit_patient(patient))
    print("Available beds after admission: ", medbay.get_available_beds())
    
    # Test treatment
    print("Initial treatment progress: ", medbay.get_treatment_progress(patient))
    medbay.update_treatment(1.0)
    print("Treatment progress after update: ", medbay.get_treatment_progress(patient))
    
    medbay.discharge_patient(patient)
    print("Available beds after discharge: ", medbay.get_available_beds())

func test_weapons_component() -> void:
    print("\nTesting Weapons Component:")
    var weapons = ship.weapons_component
    
    # Test initial values
    print("Initial damage: ", weapons.get_damage())
    print("Initial range: ", weapons.get_range())
    print("Initial accuracy: ", weapons.get_accuracy())
    print("Initial fire rate: ", weapons.get_fire_rate())
    
    # Test weapon management
    var weapon = {"id": 1, "name": "Test Weapon", "type": "laser"}
    assert(weapons.equip_weapon(weapon))
    print("Available slots after equip: ", weapons.get_available_slots())
    
    # Test firing
    var target = Vector3(50, 0, 0)
    var result = weapons.fire_weapon(weapon, target)
    print("Fire result: ", result)
    
    weapons.unequip_weapon(weapon)
    print("Available slots after unequip: ", weapons.get_available_slots())

func test_power_management() -> void:
    print("\nTesting Power Management:")
    print("Initial power usage: ", ship.get_power_usage())
    print("Available power: ", ship.get_power_available())
    
    # Test power state changes
    ship.power_generation = 3  # Reduce power to force some components to deactivate
    ship.update_power_state()
    print("Active components after power reduction: ", ship.get_active_components().size())
    print("Inactive components after power reduction: ", ship.get_inactive_components().size())
    
    ship.power_generation = 20  # Restore power
    ship.update_power_state()
    print("Active components after power restoration: ", ship.get_active_components().size())

func test_component_upgrades() -> void:
    print("\nTesting Component Upgrades:")
    
    # Test hull upgrade
    var hull = ship.hull_component
    print("Hull armor before upgrade: ", hull.get_armor())
    assert(ship.upgrade_component(hull))
    print("Hull armor after upgrade: ", hull.get_armor())
    
    # Test engine upgrade
    var engine = ship.engine_component
    print("Engine speed before upgrade: ", engine.get_speed())
    assert(ship.upgrade_component(engine))
    print("Engine speed after upgrade: ", engine.get_speed())
    
    # Test medical upgrade
    var medbay = ship.medical_component
    print("Healing rate before upgrade: ", medbay.get_healing_rate())
    assert(ship.upgrade_component(medbay))
    print("Healing rate after upgrade: ", medbay.get_healing_rate())
    
    # Test weapons upgrade
    var weapons = ship.weapons_component
    print("Weapon damage before upgrade: ", weapons.get_damage())
    assert(ship.upgrade_component(weapons))
    print("Weapon damage after upgrade: ", weapons.get_damage())

func test_damage_and_repair() -> void:
    print("\nTesting Damage and Repair:")
    var hull = ship.hull_component
    
    # Test taking damage
    print("Initial durability: ", hull.durability)
    ship.take_damage(20)
    print("Durability after damage: ", hull.durability)
    
    # Test repair
    ship.repair(10)
    print("Durability after repair: ", hull.durability) 