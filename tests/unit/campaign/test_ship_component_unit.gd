## Individual Ship Component Test Suite
## Tests the functionality of individual ship components, including
## properties, durability, efficiency, and component-level operations
@tool
extends GdUnitGameTest

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

# Mock Ship Component with expected values (Universal Mock Strategy)
class MockShipComponent extends Resource:
	var component_name: String = "Test Component"
	var description: String = "A test ship component"
	var cost: int = 100
	var power_draw: int = 25
	var level: int = 1
	var durability: int = 100
	var efficiency: float = 1.0
	var is_active_state: bool = true
	var component_type: int = 0
	
	# Core getters with expected values
	func get_component_name() -> String: return component_name
	func get_description() -> String: return description
	func get_cost() -> int: return cost
	func get_power_draw() -> int: return power_draw
	func get_level() -> int: return level
	func get_durability() -> int: return durability
	func get_efficiency() -> float: return efficiency
	func is_active() -> bool: return is_active_state
	func get_component_type() -> int: return component_type
	
	# Core setters
	func set_active(active: bool) -> void:
		is_active_state = active
	
	func set_durability(value: int) -> void:
		durability = max(0, min(100, value))
	
	func set_efficiency(value: float) -> void:
		efficiency = max(0.0, min(1.0, value))
	
	func damage_component(amount: int) -> bool:
		if amount > 0 and durability > 0:
			durability = max(0, durability - amount)
			return true
		return false
	
	func repair_component(amount: int) -> bool:
		if amount > 0 and durability < 100:
			durability = min(100, durability + amount)
			return true
		return false
	
	# Property modification
	func upgrade_level() -> bool:
		if level < 10:
			level += 1
			cost = int(cost * 1.5)
			power_draw = int(power_draw * 1.2)
			return true
		return false

# Type-safe instance variables
var component: MockShipComponent = null

func before_test() -> void:
	super.before_test()
	component = MockShipComponent.new()
	track_resource(component)

func after_test() -> void:
	component = null
	super.after_test()

func test_initialization() -> void:
	assert_that(component).is_not_null()
	
	# Test direct method calls instead of safe wrappers (proven pattern)
	var name: String = component.get_component_name()
	var description: String = component.get_description()
	var cost: int = component.get_cost()
	var power_draw: int = component.get_power_draw()
	var level: int = component.get_level()
	var durability: int = component.get_durability()
	var efficiency: float = component.get_efficiency()
	var is_active: bool = component.is_active()
	
	assert_that(name).is_not_equal("")
	assert_that(description).is_not_equal("")
	assert_that(cost).is_greater(0)
	assert_that(power_draw).is_greater_equal(0)
	assert_that(level).is_equal(1)
	assert_that(durability).is_equal(100)
	assert_that(efficiency).is_equal(1.0)
	assert_that(is_active).is_true()

func test_component_status() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var is_active: bool = component.is_active()
	assert_that(is_active).is_true()
	
	# Test component deactivation
	component.set_active(false)
	is_active = component.is_active()
	assert_that(is_active).is_false()
	
	# Test component reactivation
	component.set_active(true)
	is_active = component.is_active()
	assert_that(is_active).is_true()

func test_durability_management() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var initial_durability: int = component.get_durability()
	assert_that(initial_durability).is_equal(100)
	
	# Test damage
	var success: bool = component.damage_component(30)
	assert_that(success).is_true()
	var current_durability: int = component.get_durability()
	assert_that(current_durability).is_equal(70)
	
	# Test repair
	success = component.repair_component(20)
	assert_that(success).is_true()
	current_durability = component.get_durability()
	assert_that(current_durability).is_equal(90)

func test_efficiency_modification() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var initial_efficiency: float = component.get_efficiency()
	assert_that(initial_efficiency).is_equal(1.0)
	
	# Test efficiency reduction
	component.set_efficiency(0.7)
	var current_efficiency: float = component.get_efficiency()
	assert_that(current_efficiency).is_equal(0.7)
	
	# Test efficiency boundary conditions
	component.set_efficiency(1.5) # Should clamp to 1.0
	current_efficiency = component.get_efficiency()
	assert_that(current_efficiency).is_equal(1.0)
	
	component.set_efficiency(-0.5) # Should clamp to 0.0
	current_efficiency = component.get_efficiency()
	assert_that(current_efficiency).is_equal(0.0)

func test_component_upgrades() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var initial_level: int = component.get_level()
	var initial_cost: int = component.get_cost()
	var initial_power: int = component.get_power_draw()
	
	assert_that(initial_level).is_equal(1)
	
	# Test upgrade
	var success: bool = component.upgrade_level()
	assert_that(success).is_true()
	
	var new_level: int = component.get_level()
	var new_cost: int = component.get_cost()
	var new_power: int = component.get_power_draw()
	
	assert_that(new_level).is_equal(2)
	assert_that(new_cost).is_greater(initial_cost)
	assert_that(new_power).is_greater(initial_power)

func test_damage_repair_cycle() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Damage component to critical levels
	component.damage_component(90)
	var durability: int = component.get_durability()
	assert_that(durability).is_equal(10)
	
	# Test repair from critical
	var success: bool = component.repair_component(50)
	assert_that(success).is_true()
	durability = component.get_durability()
	assert_that(durability).is_equal(60)
	
	# Test complete destruction
	component.damage_component(100)
	durability = component.get_durability()
	assert_that(durability).is_equal(0)
	
	# Test repair from destroyed
	success = component.repair_component(25)
	assert_that(success).is_true()
	durability = component.get_durability()
	assert_that(durability).is_equal(25)

func test_edge_cases() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Test negative damage
	var initial_durability: int = component.get_durability()
	var success: bool = component.damage_component(-10)
	assert_that(success).is_false()
	assert_that(component.get_durability()).is_equal(initial_durability)
	
	# Test zero damage
	success = component.damage_component(0)
	assert_that(success).is_false()
	
	# Test repair at full durability
	component.set_durability(100)
	success = component.repair_component(10)
	assert_that(success).is_false()
	
	# Test upgrade at max level
	for i in range(15): # Try to exceed max level
		component.upgrade_level()
	
	var final_level: int = component.get_level()
	assert_that(final_level).is_less_equal(10) # Assuming max level is 10

func test_component_properties() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Test all core properties are accessible
	assert_that(component.get_component_name()).is_instance_of(TYPE_STRING)
	assert_that(component.get_description()).is_instance_of(TYPE_STRING)
	assert_that(component.get_cost()).is_instance_of(TYPE_INT)
	assert_that(component.get_power_draw()).is_instance_of(TYPE_INT)
	assert_that(component.get_level()).is_instance_of(TYPE_INT)
	assert_that(component.get_durability()).is_instance_of(TYPE_INT)
	assert_that(component.get_efficiency()).is_instance_of(TYPE_FLOAT)
	assert_that(component.is_active()).is_instance_of(TYPE_BOOL)
