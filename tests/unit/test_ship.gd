extends "res://addons/gut/test.gd"

const Ship = preload("res://src/core/ships/Ship.gd")
const EngineComponent = preload("res://src/core/ships/components/EngineComponent.gd")
const HullComponent = preload("res://src/core/ships/components/HullComponent.gd")
const WeaponsComponent = preload("res://src/core/ships/components/WeaponsComponent.gd")
const MedicalBayComponent = preload("res://src/core/ships/components/MedicalBayComponent.gd")

var ship: Ship

func before_each() -> void:
    ship = Ship.new()

func after_each() -> void:
    ship = null

func test_initialization() -> void:
    assert_eq(ship.name, "Ship", "Should initialize with default name")
    assert_eq(ship.description, "Standard ship", "Should initialize with default description")
    assert_eq(ship.credits, 1000, "Should initialize with starting credits")
    assert_eq(ship.power_available, 10, "Should initialize with base power")
    assert_eq(ship.power_used, 0, "Should initialize with no power used")
    assert_eq(ship.components.size(), 0, "Should initialize with no components")
    assert_eq(ship.crew.size(), 0, "Should initialize with no crew")

func test_component_management() -> void:
    var engine = EngineComponent.new()
    var hull = HullComponent.new()
    var weapons = WeaponsComponent.new()
    var medical = MedicalBayComponent.new()
    
    # Test adding components
    assert_true(ship.add_component(engine), "Should successfully add engine")
    assert_true(ship.add_component(hull), "Should successfully add hull")
    assert_true(ship.add_component(weapons), "Should successfully add weapons")
    assert_true(ship.add_component(medical), "Should successfully add medical bay")
    
    assert_eq(ship.components.size(), 4, "Should have all components added")
    assert_eq(ship.power_used, engine.power_draw + hull.power_draw + weapons.power_draw + medical.power_draw,
             "Should track total power consumption")
    
    # Test power limits
    ship.power_available = 5
    var extra_weapons = WeaponsComponent.new()
    assert_false(ship.add_component(extra_weapons), "Should not add component beyond power capacity")
    
    # Test removing components
    assert_true(ship.remove_component(weapons), "Should successfully remove component")
    assert_eq(ship.components.size(), 3, "Should have one less component")
    assert_false(weapons in ship.components, "Should not contain removed component")
    assert_eq(ship.power_used, engine.power_draw + hull.power_draw + medical.power_draw,
             "Should update power consumption after removal")

func test_crew_management() -> void:
    var test_crew_member = {
        "id": "crew_1",
        "name": "Test Crew",
        "health": 100,
        "max_health": 100,
        "skills": ["pilot", "engineer"]
    }
    
    # Test adding crew
    assert_true(ship.add_crew_member(test_crew_member), "Should successfully add crew member")
    assert_eq(ship.crew.size(), 1, "Should have one crew member")
    assert_true(test_crew_member in ship.crew, "Should contain added crew member")
    
    # Test crew capacity
    var hull = ship.get_component("hull") as HullComponent
    if not hull:
        hull = HullComponent.new()
        ship.add_component(hull)
    
    var crew_to_fill = hull.crew_capacity - 1
    for i in range(crew_to_fill):
        var new_crew = test_crew_member.duplicate()
        new_crew.id = "crew_%d" % (i + 2)
        ship.add_crew_member(new_crew)
    
    var overflow_crew = test_crew_member.duplicate()
    overflow_crew.id = "overflow"
    assert_false(ship.add_crew_member(overflow_crew), "Should not add crew beyond capacity")
    
    # Test removing crew
    assert_true(ship.remove_crew_member(test_crew_member), "Should successfully remove crew member")
    assert_eq(ship.crew.size(), crew_to_fill, "Should have one less crew member")
    assert_false(test_crew_member in ship.crew, "Should not contain removed crew member")

func test_power_management() -> void:
    var engine = EngineComponent.new()
    var weapons = WeaponsComponent.new()
    
    ship.add_component(engine)
    assert_eq(ship.power_used, engine.power_draw, "Should track power usage")
    
    ship.add_component(weapons)
    assert_eq(ship.power_used, engine.power_draw + weapons.power_draw, "Should accumulate power usage")
    
    # Test power upgrades
    var initial_power = ship.power_available
    ship.upgrade_power_system()
    assert_eq(ship.power_available, initial_power + 5, "Should increase available power on upgrade")

func test_damage_and_repair() -> void:
    var hull = HullComponent.new()
    ship.add_component(hull)
    
    # Test component damage
    ship.take_damage(30)
    assert_eq(hull.durability, 70, "Should damage hull component")
    
    # Test repair
    ship.repair_all()
    assert_eq(hull.durability, 100, "Should repair all components")
    
    # Test system failure
    ship.take_damage(100)
    assert_false(hull.is_active, "Should deactivate components at zero durability")

func test_maintenance() -> void:
    var engine = EngineComponent.new()
    var weapons = WeaponsComponent.new()
    ship.add_component(engine)
    ship.add_component(weapons)
    
    var initial_credits = ship.credits
    var maintenance_cost = engine.get_maintenance_cost() + weapons.get_maintenance_cost()
    
    ship.perform_maintenance()
    assert_eq(ship.credits, initial_credits - maintenance_cost, "Should deduct maintenance costs")

func test_component_upgrades() -> void:
    var engine = EngineComponent.new()
    ship.add_component(engine)
    
    var initial_credits = ship.credits
    var upgrade_cost = engine.upgrade_cost
    
    assert_true(ship.upgrade_component(engine), "Should successfully upgrade component")
    assert_eq(ship.credits, initial_credits - upgrade_cost, "Should deduct upgrade cost")
    assert_eq(engine.level, 2, "Should increase component level")
    
    # Test insufficient funds
    ship.credits = 0
    assert_false(ship.upgrade_component(engine), "Should not upgrade without sufficient credits")

func test_serialization() -> void:
    # Setup ship state
    ship.name = "Test Ship"
    ship.description = "Test Description"
    ship.credits = 2000
    ship.power_available = 15
    
    var engine = EngineComponent.new()
    var hull = HullComponent.new()
    ship.add_component(engine)
    ship.add_component(hull)
    
    var test_crew = {
        "id": "crew_1",
        "name": "Test Crew",
        "health": 100,
        "max_health": 100,
        "skills": ["pilot", "engineer"]
    }
    ship.add_crew_member(test_crew)
    
    # Serialize and deserialize
    var data = ship.serialize()
    var new_ship = Ship.deserialize(data)
    
    # Verify ship properties
    assert_eq(new_ship.name, ship.name, "Should preserve name")
    assert_eq(new_ship.description, ship.description, "Should preserve description")
    assert_eq(new_ship.credits, ship.credits, "Should preserve credits")
    assert_eq(new_ship.power_available, ship.power_available, "Should preserve power available")
    assert_eq(new_ship.power_used, ship.power_used, "Should preserve power used")
    assert_eq(new_ship.components.size(), ship.components.size(), "Should preserve components")
    assert_eq(new_ship.crew.size(), ship.crew.size(), "Should preserve crew")