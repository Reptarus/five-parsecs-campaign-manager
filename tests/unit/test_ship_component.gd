extends "res://addons/gut/test.gd"

var component: ShipComponent

func before_each() -> void:
    component = ShipComponent.new()

func after_each() -> void:
    component = null

func test_initialization() -> void:
    assert_eq(component.name, "", "Should initialize with empty name")
    assert_eq(component.description, "", "Should initialize with empty description")
    assert_eq(component.cost, 0, "Should initialize with zero cost")
    assert_eq(component.level, 1, "Should initialize at level 1")
    assert_eq(component.max_level, 3, "Should initialize with max level 3")
    assert_true(component.is_active, "Should initialize as active")
    assert_eq(component.upgrade_cost, 100, "Should initialize with default upgrade cost")
    assert_eq(component.maintenance_cost, 10, "Should initialize with default maintenance cost")
    assert_eq(component.durability, 100, "Should initialize with full durability")
    assert_eq(component.max_durability, 100, "Should initialize with default max durability")
    assert_eq(component.efficiency, 1.0, "Should initialize with full efficiency")
    assert_eq(component.power_draw, 1, "Should initialize with default power draw")
    assert_eq(component.status_effects.size(), 0, "Should initialize with no status effects")

func test_upgrade_mechanics() -> void:
    assert_true(component.can_upgrade(), "Should be upgradeable at level 1")
    
    # Test successful upgrade
    assert_true(component.upgrade(), "Should successfully upgrade")
    assert_eq(component.level, 2, "Should increase level after upgrade")
    assert_eq(component.efficiency, 1.2, "Should increase efficiency after upgrade")
    assert_eq(component.max_durability, 125, "Should increase max durability after upgrade")
    assert_eq(component.durability, 125, "Should set durability to new max after upgrade")
    
    # Test upgrade limits
    component.level = component.max_level
    assert_false(component.can_upgrade(), "Should not be upgradeable at max level")
    assert_false(component.upgrade(), "Should fail to upgrade at max level")

func test_damage_and_repair() -> void:
    # Test taking damage
    component.take_damage(30)
    assert_eq(component.durability, 70, "Should reduce durability when taking damage")
    assert_true(component.is_active, "Should remain active with partial damage")
    
    # Test repair
    component.repair(20)
    assert_eq(component.durability, 90, "Should increase durability when repaired")
    
    # Test repair cap
    component.repair(20)
    assert_eq(component.durability, 100, "Should not exceed max durability when repaired")
    
    # Test deactivation on zero durability
    component.take_damage(100)
    assert_eq(component.durability, 0, "Should have zero durability")
    assert_false(component.is_active, "Should deactivate at zero durability")

func test_efficiency_calculation() -> void:
    # Test base efficiency
    assert_eq(component.get_efficiency(), 1.0, "Should have base efficiency at full durability")
    
    # Test efficiency with damage
    component.take_damage(50)
    assert_eq(component.get_efficiency(), 0.5, "Should reduce efficiency with damage")
    
    # Test efficiency with level bonus
    component.durability = component.max_durability # Reset durability
    component.level = 2
    assert_eq(component.get_efficiency(), 1.2, "Should increase efficiency with higher level")
    
    # Test combined effects
    component.take_damage(50)
    var efficiency = component.get_efficiency()
    assert_true(efficiency > 0.59 and efficiency < 0.61, "Should combine durability and level effects")

func test_power_consumption() -> void:
    assert_eq(component.get_power_consumption(), 1, "Should have base power consumption")
    
    component.level = 2
    assert_eq(component.get_power_consumption(), 2, "Should increase power consumption with level")
    
    component.level = 3
    assert_eq(component.get_power_consumption(), 3, "Should scale power consumption with level")

func test_maintenance_cost() -> void:
    assert_eq(component.get_maintenance_cost(), 10, "Should have base maintenance cost")
    
    component.level = 2
    assert_eq(component.get_maintenance_cost(), 20, "Should increase maintenance cost with level")
    
    component.level = 3
    assert_eq(component.get_maintenance_cost(), 30, "Should scale maintenance cost with level")

func test_status_effects() -> void:
    var effect = {"type": "damage_over_time", "amount": 5}
    
    # Test adding effect
    component.add_status_effect(effect)
    assert_eq(component.status_effects.size(), 1, "Should add status effect")
    assert_true(effect in component.status_effects, "Should contain added effect")
    
    # Test removing effect
    component.remove_status_effect(effect)
    assert_eq(component.status_effects.size(), 0, "Should remove status effect")
    
    # Test clearing effects
    component.add_status_effect(effect)
    component.add_status_effect({"type": "power_drain", "amount": 2})
    component.clear_status_effects()
    assert_eq(component.status_effects.size(), 0, "Should clear all status effects")

func test_serialization() -> void:
    component.name = "Test Component"
    component.description = "Test Description"
    component.cost = 500
    component.level = 2
    component.is_active = false
    component.durability = 75
    component.add_status_effect({"type": "damage_over_time", "amount": 5})
    
    var data = component.serialize()
    var new_component = ShipComponent.deserialize(data)
    
    assert_eq(new_component.name, component.name, "Should preserve name")
    assert_eq(new_component.description, component.description, "Should preserve description")
    assert_eq(new_component.cost, component.cost, "Should preserve cost")
    assert_eq(new_component.level, component.level, "Should preserve level")
    assert_eq(new_component.is_active, component.is_active, "Should preserve active state")
    assert_eq(new_component.durability, component.durability, "Should preserve durability")
    assert_eq(new_component.status_effects.size(), component.status_effects.size(), "Should preserve status effects")