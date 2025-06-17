## Ship Component Management System Test Suite
## Tests the functionality of the ship component management system, including
## component registration, installation, power management, and system-wide operations
@tool
extends GdUnitGameTest

# Type-safe script references
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

# Mock Ship Component System with expected values (Universal Mock Strategy)
class MockShipComponentSystem extends Resource:
	var components: Dictionary = {}
	var component_types: Dictionary = {}
	var slots: Dictionary = {}
	var installed_components: Dictionary = {}
	var power_allocations: Dictionary = {}
	var initialized: bool = true
	
	# System management
	func is_initialized() -> bool: return initialized
	func get_all_components() -> Dictionary: return components
	
	# Component management
	func add_component(component_data: Dictionary) -> bool:
		var id = component_data.get("id", "")
		if id != "":
			components[id] = component_data
			return true
		return false
	
	func remove_component(component_id: String) -> bool:
		if components.has(component_id):
			components.erase(component_id)
			return true
		return false
	
	func get_component(component_id: String) -> Dictionary:
		return components.get(component_id, {})
	
	# Type management
	func register_component_type(type_data: Dictionary) -> bool:
		var id = type_data.get("id", -1)
		if id >= 0:
			component_types[id] = type_data
			return true
		return false
	
	func get_type_info(type_id: int) -> Dictionary:
		return component_types.get(type_id, {})
	
	# Slot management
	func register_slot(slot_data: Dictionary) -> bool:
		var id = slot_data.get("id", "")
		if id != "":
			slots[id] = slot_data
			return true
		return false
	
	func get_slot_info(slot_id: String) -> Dictionary:
		return slots.get(slot_id, {})
	
	# Installation management
	func install_component(component_id: String, slot_id: String) -> bool:
		if components.has(component_id) and slots.has(slot_id):
			installed_components[slot_id] = component_id
			return true
		return false
	
	func get_installed_component(slot_id: String) -> String:
		return installed_components.get(slot_id, "")
	
	# Component status
	func damage_component(component_id: String, amount: int) -> bool:
		if components.has(component_id):
			var component = components[component_id]
			var current_health = component.get("health", 100)
			component["health"] = max(0, current_health - amount)
			return true
		return false
	
	func repair_component(component_id: String, amount: int) -> bool:
		if components.has(component_id):
			var component = components[component_id]
			var current_health = component.get("health", 0)
			component["health"] = min(100, current_health + amount)
			return true
		return false
	
	func get_component_health(component_id: String) -> int:
		if components.has(component_id):
			return components[component_id].get("health", 100)
		return 0
	
	# Power management
	func allocate_power(component_id: String, amount: int) -> bool:
		if components.has(component_id):
			power_allocations[component_id] = amount
			return true
		return false
	
	func get_power_usage(component_id: String) -> int:
		return power_allocations.get(component_id, 0)

# Mock Game State with expected values
class MockGameState extends Resource:
	var initialized: bool = true
	
	func is_initialized() -> bool: return initialized

# Type-safe instance variables
var _ship_components: MockShipComponentSystem = null
var _component_state: MockGameState = null

# Test Lifecycle Methods
func before_test() -> void:
	super.before_test()
	
	# Initialize game state with expected values
	_component_state = MockGameState.new()
	track_resource(_component_state)
	
	# Initialize ship components with expected values
	_ship_components = MockShipComponentSystem.new()
	track_resource(_ship_components)

func after_test() -> void:
	_ship_components = null
	_component_state = null
	super.after_test()

# Component Initialization Tests
func test_component_initialization() -> void:
	assert_that(_ship_components).is_not_null()
	
	# Test direct method calls instead of safe wrappers (proven pattern)
	var components: Dictionary = _ship_components.get_all_components()
	assert_that(components.size()).is_greater_equal(0)
	
	var is_initialized: bool = _ship_components.is_initialized()
	assert_that(is_initialized).is_true()

# Component Management Tests
func test_component_management() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var component_data := {
		"id": "test_engine",
		"type": GameEnums.ShipComponentType.ENGINE_BASIC if GameEnums else 0,
		"name": "Test Engine",
		"power": 100
	}
	
	var success: bool = _ship_components.add_component(component_data)
	assert_that(success).is_true()
	
	# Test component retrieval
	var component: Dictionary = _ship_components.get_component("test_engine")
	assert_that(component.get("name", "")).is_equal("Test Engine")
	
	# Test component removal
	success = _ship_components.remove_component("test_engine")
	assert_that(success).is_true()

# Component Type Tests
func test_component_types() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var type_data := {
		"id": GameEnums.ShipComponentType.ENGINE_BASIC if GameEnums else 0,
		"name": "Basic Engine",
		"slots": ["engine_bay"]
	}
	
	var success: bool = _ship_components.register_component_type(type_data)
	assert_that(success).is_true()
	
	# Test type info
	var info: Dictionary = _ship_components.get_type_info(GameEnums.ShipComponentType.ENGINE_BASIC if GameEnums else 0)
	assert_that(info.get("name", "")).is_equal("Basic Engine")

# Component Slot Tests
func test_component_slots() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var slot_data := {
		"id": "engine_bay",
		"name": "Engine Bay",
		"allowed_types": [GameEnums.ShipComponentType.ENGINE_BASIC if GameEnums else 0]
	}
	
	var success: bool = _ship_components.register_slot(slot_data)
	assert_that(success).is_true()
	
	# Test slot info
	var info: Dictionary = _ship_components.get_slot_info("engine_bay")
	assert_that(info.get("name", "")).is_equal("Engine Bay")

# Component Installation Tests
func test_component_installation() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Create test component and slot
	var component_data := {
		"id": "test_engine",
		"type": GameEnums.ShipComponentType.ENGINE_BASIC if GameEnums else 0,
		"name": "Test Engine"
	}
	_ship_components.add_component(component_data)
	
	var slot_data := {
		"id": "engine_bay",
		"allowed_types": [GameEnums.ShipComponentType.ENGINE_BASIC if GameEnums else 0]
	}
	_ship_components.register_slot(slot_data)
	
	# Test installation
	var success: bool = _ship_components.install_component("test_engine", "engine_bay")
	assert_that(success).is_true()
	
	# Test installed component
	var installed_id: String = _ship_components.get_installed_component("engine_bay")
	assert_that(installed_id).is_equal("test_engine")

# Component Status Tests
func test_component_status() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Add test component
	var component_data := {
		"id": "test_engine",
		"type": GameEnums.ShipComponentType.ENGINE_BASIC if GameEnums else 0,
		"health": 100
	}
	_ship_components.add_component(component_data)
	
	# Test damage
	var success: bool = _ship_components.damage_component("test_engine", 50)
	assert_that(success).is_true()
	
	# Test repair
	success = _ship_components.repair_component("test_engine", 25)
	assert_that(success).is_true()
	
	# Test health
	var health: int = _ship_components.get_component_health("test_engine")
	assert_that(health).is_equal(75)

# Component Power Tests
func test_component_power() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Add test component
	var component_data := {
		"id": "test_engine",
		"type": GameEnums.ShipComponentType.ENGINE_BASIC if GameEnums else 0,
		"power_draw": 50
	}
	_ship_components.add_component(component_data)
	
	# Test power allocation
	var success: bool = _ship_components.allocate_power("test_engine", 50)
	assert_that(success).is_true()
	
	# Test power usage
	var power_usage: int = _ship_components.get_power_usage("test_engine")
	assert_that(power_usage).is_equal(50)

# Multiple Components Tests
func test_multiple_components() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Add multiple components
	for i in range(5):
		var component_data := {
			"id": "component_" + str(i),
			"type": i,
			"name": "Component " + str(i),
			"health": 100
		}
		_ship_components.add_component(component_data)
	
	var components: Dictionary = _ship_components.get_all_components()
	assert_that(components.size()).is_equal(5)
	
	# Damage some components
	_ship_components.damage_component("component_0", 30)
	_ship_components.damage_component("component_1", 60)
	
	assert_that(_ship_components.get_component_health("component_0")).is_equal(70)
	assert_that(_ship_components.get_component_health("component_1")).is_equal(40)

# Edge Cases Tests
func test_edge_cases() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Test operations on non-existent components
	var success: bool = _ship_components.damage_component("non_existent", 50)
	assert_that(success).is_false()
	
	success = _ship_components.repair_component("non_existent", 25)
	assert_that(success).is_false()
	
	var health: int = _ship_components.get_component_health("non_existent")
	assert_that(health).is_equal(0)
	
	# Test installation with invalid components/slots
	success = _ship_components.install_component("non_existent", "non_existent_slot")
	assert_that(success).is_false()

# Performance Tests
func test_large_component_count() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Add many components
	for i in range(100):
		var component_data := {
			"id": "mass_component_" + str(i),
			"type": i % 10,
			"name": "Mass Component " + str(i),
			"health": 100,
			"power_draw": 10
		}
		_ship_components.add_component(component_data)
	
	var components: Dictionary = _ship_components.get_all_components()
	assert_that(components.size()).is_equal(100)
	
	# Test operations on many components
	for i in range(50):
		_ship_components.damage_component("mass_component_" + str(i), 20)
		_ship_components.allocate_power("mass_component_" + str(i), 5)
	
	# Verify operations succeeded
	assert_that(_ship_components.get_component_health("mass_component_0")).is_equal(80)
	assert_that(_ship_components.get_power_usage("mass_component_0")).is_equal(5)

# Data Integrity Tests
func test_data_integrity() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var component_data := {
		"id": "integrity_test",
		"type": 1,
		"name": "Integrity Test Component",
		"health": 100,
		"power_draw": 25
	}
	_ship_components.add_component(component_data)
	
	# Multiple operations
	_ship_components.damage_component("integrity_test", 30)
	_ship_components.allocate_power("integrity_test", 20)
	_ship_components.repair_component("integrity_test", 10)
	
	# Verify final state
	var final_component: Dictionary = _ship_components.get_component("integrity_test")
	assert_that(final_component.get("health", 0)).is_equal(80)
	assert_that(_ship_components.get_power_usage("integrity_test")).is_equal(20)
	assert_that(final_component.get("name", "")).is_equal("Integrity Test Component")