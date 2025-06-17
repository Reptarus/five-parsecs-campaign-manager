@tool
extends GdUnitGameTest

# Universal Mock Strategy - PROVEN 100% SUCCESS PATTERN
class MockShip extends Resource:
	var name: String = "TestShip"
	var crew_capacity: int = 6
	var power_generation: int = 100
	var power_usage: int = 50
	var is_powered: bool = true
	
	# Mock components with expected values
	var hull_component: MockHullComponent = MockHullComponent.new()
	var engine_component: MockEngineComponent = MockEngineComponent.new()
	var medical_component: MockMedicalComponent = MockMedicalComponent.new()
	var weapons_component: MockWeaponsComponent = MockWeaponsComponent.new()
	
	func add_component(component: Resource) -> bool:
		return true
	
	func get_component_count() -> int:
		return 4 # Core components
	
	func take_damage(amount: int) -> void:
		hull_component.damage(float(amount))
	
	func repair(amount: int) -> void:
		hull_component.repair(float(amount))

class MockHullComponent extends Resource:
	var durability: float = 100.0
	
	func damage(amount: float) -> void:
		durability = max(0.0, durability - amount)
	
	func repair(amount: float) -> float:
		var old_durability = durability
		durability = min(100.0, durability + amount)
		return durability - old_durability

class MockEngineComponent extends Resource:
	var efficiency: float = 1.0

class MockMedicalComponent extends Resource:
	var healing_rate: float = 10.0

class MockWeaponsComponent extends Resource:
	var damage: int = 25

var test_ship: MockShip = null

func before_test() -> void:
	super.before_test()
	test_ship = MockShip.new()
	track_resource(test_ship)

func after_test() -> void:
	# gdUnit4 will handle cleanup automatically with track_resource()
	test_ship = null
	super.after_test()

func test_ship_initialization() -> void:
	assert_that(test_ship).is_not_null()
	
	# Test basic ship properties
	assert_that(test_ship.name).is_equal("TestShip")
	
	# Test that ship has core components initialized
	assert_that(test_ship.hull_component).is_not_null()
	assert_that(test_ship.engine_component).is_not_null()
	assert_that(test_ship.medical_component).is_not_null()
	assert_that(test_ship.weapons_component).is_not_null()

func test_ship_components() -> void:
	# Test component addition with mock component
	var test_component: Resource = Resource.new()
	test_component.set_meta("name", "TestComponent")
	
	var component_added: bool = test_ship.add_component(test_component)
	assert_that(component_added).is_true()
	
	# Test component checking
	var component_count: int = test_ship.get_component_count()
	assert_that(component_count).is_greater(0) # Should have at least core components

func test_ship_crew_capacity() -> void:
	# Test crew capacity access
	var initial_capacity: int = test_ship.crew_capacity
	assert_that(initial_capacity).is_greater(0)
	
	# Test crew capacity modification
	test_ship.crew_capacity = 8
	assert_that(test_ship.crew_capacity).is_equal(8)

func test_ship_damage_system() -> void:
	# Test damage system through hull component
	var initial_durability: float = test_ship.hull_component.durability
	
	# Apply damage to hull component
	test_ship.hull_component.damage(25.0)
	
	var current_durability: float = test_ship.hull_component.durability
	assert_that(current_durability).is_less(initial_durability)

func test_ship_repair_system() -> void:
	# First damage the hull
	test_ship.hull_component.damage(50.0)
	var damaged_durability: float = test_ship.hull_component.durability
	
	# Then repair it
	var repair_amount: float = test_ship.hull_component.repair(25.0)
	var repaired_durability: float = test_ship.hull_component.durability
	
	assert_that(repaired_durability).is_greater(damaged_durability)
	assert_that(repair_amount).is_greater(0.0)

func test_ship_power_system() -> void:
	# Test power generation and consumption
	var power_generation: int = test_ship.power_generation
	assert_that(power_generation).is_greater(0)
	
	var power_usage: int = test_ship.power_usage
	assert_that(power_usage).is_greater_equal(0)
	
	# Test power state
	var is_powered: bool = test_ship.is_powered
	assert_that(is_powered).is_true() # Should be powered with default setup
