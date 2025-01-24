extends "res://addons/gut/test.gd"

var hull: HullComponent

func before_each() -> void:
    hull = HullComponent.new()

func after_each() -> void:
    hull = null

func test_initialization() -> void:
    assert_eq(hull.name, "Hull", "Should initialize with correct name")
    assert_eq(hull.description, "Standard ship hull", "Should initialize with correct description")
    assert_eq(hull.cost, 500, "Should initialize with correct cost")
    assert_eq(hull.power_draw, 1, "Should initialize with correct power draw")
    
    # Test hull-specific properties
    assert_eq(hull.armor, 10, "Should initialize with base armor")
    assert_eq(hull.shield, 0, "Should initialize with no shield")
    assert_eq(hull.cargo_capacity, 100, "Should initialize with base cargo capacity")
    assert_eq(hull.crew_capacity, 4, "Should initialize with base crew capacity")
    assert_eq(hull.shield_recharge_rate, 0.1, "Should initialize with base shield recharge rate")
    
    # Test current values
    assert_eq(hull.current_shield, 0, "Should initialize with no current shield")
    assert_eq(hull.current_cargo, 0, "Should initialize with no cargo")
    assert_eq(hull.current_crew, 0, "Should initialize with no crew")

func test_upgrade_effects() -> void:
    # Store initial values
    var initial_armor = hull.armor
    var initial_shield = hull.shield
    var initial_cargo_capacity = hull.cargo_capacity
    var initial_crew_capacity = hull.crew_capacity
    var initial_shield_recharge_rate = hull.shield_recharge_rate
    
    # Perform upgrade
    hull.upgrade()
    
    # Test improvements
    assert_eq(hull.armor, initial_armor + 5, "Should increase armor on upgrade")
    assert_eq(hull.shield, initial_shield + 5, "Should increase shield on upgrade")
    assert_eq(hull.cargo_capacity, initial_cargo_capacity + 25, "Should increase cargo capacity on upgrade")
    assert_eq(hull.crew_capacity, initial_crew_capacity + 1, "Should increase crew capacity on upgrade")
    assert_eq(hull.shield_recharge_rate, initial_shield_recharge_rate + 0.05, "Should increase shield recharge rate on upgrade")
    assert_eq(hull.current_shield, hull.shield, "Should set current shield to new maximum")

func test_efficiency_effects() -> void:
    hull.shield = 10 # Set some shield for testing
    
    # Test base values at full efficiency
    assert_eq(hull.get_armor(), 10, "Should return base armor at full efficiency")
    assert_eq(hull.get_shield(), 10, "Should return base shield at full efficiency")
    assert_eq(hull.get_cargo_capacity(), 100, "Should return base cargo capacity at full efficiency")
    assert_eq(hull.get_crew_capacity(), 4, "Should return base crew capacity")
    assert_eq(hull.get_shield_recharge_rate(), 0.1, "Should return base shield recharge rate at full efficiency")
    
    # Test values at reduced efficiency
    hull.take_damage(50) # 50% efficiency
    assert_eq(hull.get_armor(), 5, "Should reduce armor with efficiency")
    assert_eq(hull.get_shield(), 5, "Should reduce shield with efficiency")
    assert_eq(hull.get_cargo_capacity(), 50, "Should reduce cargo capacity with efficiency")
    assert_eq(hull.get_crew_capacity(), 4, "Should not reduce crew capacity with efficiency")
    assert_eq(hull.get_shield_recharge_rate(), 0.05, "Should reduce shield recharge rate with efficiency")

func test_damage_system() -> void:
    hull.shield = 10
    hull.current_shield = 10
    
    # Test shield absorption
    hull.take_damage(5)
    assert_eq(hull.current_shield, 5, "Shield should absorb damage")
    assert_eq(hull.durability, 100, "Hull should not take damage when shield absorbs it")
    
    # Test damage overflow
    hull.take_damage(10)
    assert_eq(hull.current_shield, 0, "Shield should be depleted")
    assert_eq(hull.durability, 95, "Hull should take overflow damage")
    
    # Test direct hull damage
    hull.take_damage(20)
    assert_eq(hull.durability, 75, "Hull should take full damage when no shield remains")

func test_shield_recharge() -> void:
    hull.shield = 10
    hull.current_shield = 0
    
    # Test single recharge tick
    hull.recharge_shield(1.0) # 1 second tick
    assert_eq(hull.current_shield, 1, "Should recharge shield by rate * delta")
    
    # Test recharge cap
    hull.current_shield = 9
    hull.recharge_shield(1.0)
    assert_eq(hull.current_shield, 10, "Should not exceed maximum shield")
    
    # Test no recharge when inactive
    hull.is_active = false
    hull.current_shield = 5
    hull.recharge_shield(1.0)
    assert_eq(hull.current_shield, 5, "Should not recharge when inactive")

func test_cargo_management() -> void:
    # Test adding cargo
    assert_true(hull.add_cargo(50), "Should successfully add cargo within capacity")
    assert_eq(hull.current_cargo, 50, "Should update current cargo")
    
    # Test cargo capacity limit
    assert_false(hull.add_cargo(60), "Should fail to add cargo beyond capacity")
    assert_eq(hull.current_cargo, 50, "Should not change cargo on failed add")
    
    # Test removing cargo
    assert_true(hull.remove_cargo(30), "Should successfully remove available cargo")
    assert_eq(hull.current_cargo, 20, "Should update current cargo after removal")
    
    # Test removing unavailable cargo
    assert_false(hull.remove_cargo(30), "Should fail to remove unavailable cargo")
    assert_eq(hull.current_cargo, 20, "Should not change cargo on failed removal")

func test_crew_management() -> void:
    # Test adding crew
    assert_true(hull.add_crew(2), "Should successfully add crew within capacity")
    assert_eq(hull.current_crew, 2, "Should update current crew")
    
    # Test crew capacity limit
    assert_false(hull.add_crew(3), "Should fail to add crew beyond capacity")
    assert_eq(hull.current_crew, 2, "Should not change crew on failed add")
    
    # Test removing crew
    assert_true(hull.remove_crew(1), "Should successfully remove available crew")
    assert_eq(hull.current_crew, 1, "Should update current crew after removal")
    
    # Test removing unavailable crew
    assert_false(hull.remove_crew(2), "Should fail to remove unavailable crew")
    assert_eq(hull.current_crew, 1, "Should not change crew on failed removal")

func test_serialization() -> void:
    # Modify hull state
    hull.armor = 15
    hull.shield = 10
    hull.cargo_capacity = 150
    hull.crew_capacity = 6
    hull.shield_recharge_rate = 0.2
    hull.current_shield = 5
    hull.current_cargo = 50
    hull.current_crew = 3
    hull.level = 2
    hull.durability = 75
    
    # Serialize and deserialize
    var data = hull.serialize()
    var new_hull = HullComponent.deserialize(data)
    
    # Verify hull-specific properties
    assert_eq(new_hull.armor, hull.armor, "Should preserve armor")
    assert_eq(new_hull.shield, hull.shield, "Should preserve shield")
    assert_eq(new_hull.cargo_capacity, hull.cargo_capacity, "Should preserve cargo capacity")
    assert_eq(new_hull.crew_capacity, hull.crew_capacity, "Should preserve crew capacity")
    assert_eq(new_hull.shield_recharge_rate, hull.shield_recharge_rate, "Should preserve shield recharge rate")
    assert_eq(new_hull.current_shield, hull.current_shield, "Should preserve current shield")
    assert_eq(new_hull.current_cargo, hull.current_cargo, "Should preserve current cargo")
    assert_eq(new_hull.current_crew, hull.current_crew, "Should preserve current crew")
    
    # Verify inherited properties
    assert_eq(new_hull.level, hull.level, "Should preserve level")
    assert_eq(new_hull.durability, hull.durability, "Should preserve durability")
    assert_eq(new_hull.power_draw, hull.power_draw, "Should preserve power draw")