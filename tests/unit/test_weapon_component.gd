extends "res://addons/gut/test.gd"

const WeaponsComponent = preload("res://src/core/ships/components/WeaponsComponent.gd")

var weapons: WeaponsComponent

func before_each() -> void:
    weapons = WeaponsComponent.new()

func after_each() -> void:
    weapons = null

func test_initialization() -> void:
    assert_eq(weapons.name, "Weapons System", "Should initialize with correct name")
    assert_eq(weapons.description, "Standard weapons system", "Should initialize with correct description")
    assert_eq(weapons.cost, 400, "Should initialize with correct cost")
    assert_eq(weapons.power_draw, 3, "Should initialize with correct power draw")
    
    # Test weapon-specific properties
    assert_eq(weapons.damage, 10, "Should initialize with base damage")
    assert_eq(weapons.range, 100.0, "Should initialize with base range")
    assert_eq(weapons.accuracy, 0.8, "Should initialize with base accuracy")
    assert_eq(weapons.fire_rate, 1.0, "Should initialize with base fire rate")
    assert_eq(weapons.ammo_capacity, 100, "Should initialize with base ammo capacity")
    assert_eq(weapons.weapon_slots, 2, "Should initialize with base weapon slots")
    assert_eq(weapons.current_ammo, weapons.ammo_capacity, "Should initialize with full ammo")
    assert_eq(weapons.equipped_weapons.size(), 0, "Should initialize with no equipped weapons")

func test_upgrade_effects() -> void:
    # Store initial values
    var initial_damage = weapons.damage
    var initial_range = weapons.range
    var initial_accuracy = weapons.accuracy
    var initial_fire_rate = weapons.fire_rate
    var initial_ammo_capacity = weapons.ammo_capacity
    var initial_weapon_slots = weapons.weapon_slots
    
    # Perform upgrade
    weapons.upgrade()
    
    # Test improvements
    assert_eq(weapons.damage, initial_damage + 5, "Should increase damage on upgrade")
    assert_eq(weapons.range, initial_range + 20.0, "Should increase range on upgrade")
    assert_eq(weapons.accuracy, initial_accuracy + 0.05, "Should increase accuracy on upgrade")
    assert_eq(weapons.fire_rate, initial_fire_rate + 0.1, "Should increase fire rate on upgrade")
    assert_eq(weapons.ammo_capacity, initial_ammo_capacity + 25, "Should increase ammo capacity on upgrade")
    assert_eq(weapons.current_ammo, weapons.ammo_capacity, "Should refill ammo on upgrade")
    
    # Test weapon slots increase on even levels
    weapons.upgrade() # Second upgrade
    assert_eq(weapons.weapon_slots, initial_weapon_slots + 1, "Should increase weapon slots on even level upgrade")

func test_efficiency_effects() -> void:
    # Test base values at full efficiency
    assert_eq(weapons.get_damage(), 10, "Should return base damage at full efficiency")
    assert_eq(weapons.get_range(), 100.0, "Should return base range at full efficiency")
    assert_eq(weapons.get_accuracy(), 0.8, "Should return base accuracy at full efficiency")
    assert_eq(weapons.get_fire_rate(), 1.0, "Should return base fire rate at full efficiency")
    
    # Test values at reduced efficiency
    weapons.take_damage(50) # 50% efficiency
    assert_eq(weapons.get_damage(), 5, "Should reduce damage with efficiency")
    assert_eq(weapons.get_range(), 50.0, "Should reduce range with efficiency")
    assert_eq(weapons.get_accuracy(), 0.4, "Should reduce accuracy with efficiency")
    assert_eq(weapons.get_fire_rate(), 0.5, "Should reduce fire rate with efficiency")

func test_weapon_slot_management() -> void:
    assert_eq(weapons.get_available_slots(), 2, "Should start with all slots available")
    
    var test_weapon = {
        "name": "Test Weapon",
        "damage": 15,
        "range": 120.0
    }
    
    # Test equipping weapons
    assert_true(weapons.can_equip_weapon(test_weapon), "Should be able to equip weapon when slots available")
    weapons.equipped_weapons.append(test_weapon)
    assert_eq(weapons.get_available_slots(), 1, "Should have one slot remaining")
    
    weapons.equipped_weapons.append(test_weapon)
    assert_eq(weapons.get_available_slots(), 0, "Should have no slots remaining")
    assert_false(weapons.can_equip_weapon(test_weapon), "Should not be able to equip weapon when no slots available")
    
    # Test inactive system
    weapons.is_active = false
    assert_false(weapons.can_equip_weapon(test_weapon), "Should not be able to equip weapon when system inactive")

func test_serialization() -> void:
    # Modify weapon system state
    weapons.damage = 15
    weapons.range = 120.0
    weapons.accuracy = 0.9
    weapons.fire_rate = 1.2
    weapons.ammo_capacity = 150
    weapons.weapon_slots = 3
    weapons.current_ammo = 75
    weapons.level = 2
    weapons.durability = 75
    
    var test_weapon = {
        "name": "Test Weapon",
        "damage": 15,
        "range": 120.0
    }
    weapons.equipped_weapons.append(test_weapon)
    
    # Serialize and deserialize
    var data = weapons.serialize()
    var new_weapons = WeaponsComponent.deserialize(data)
    
    # Verify weapon-specific properties
    assert_eq(new_weapons.damage, weapons.damage, "Should preserve damage")
    assert_eq(new_weapons.range, weapons.range, "Should preserve range")
    assert_eq(new_weapons.accuracy, weapons.accuracy, "Should preserve accuracy")
    assert_eq(new_weapons.fire_rate, weapons.fire_rate, "Should preserve fire rate")
    assert_eq(new_weapons.ammo_capacity, weapons.ammo_capacity, "Should preserve ammo capacity")
    assert_eq(new_weapons.weapon_slots, weapons.weapon_slots, "Should preserve weapon slots")
    assert_eq(new_weapons.current_ammo, weapons.current_ammo, "Should preserve current ammo")
    assert_eq(new_weapons.equipped_weapons.size(), weapons.equipped_weapons.size(), "Should preserve equipped weapons")
    
    # Verify inherited properties
    assert_eq(new_weapons.level, weapons.level, "Should preserve level")
    assert_eq(new_weapons.durability, weapons.durability, "Should preserve durability")
    assert_eq(new_weapons.power_draw, weapons.power_draw, "Should preserve power draw")