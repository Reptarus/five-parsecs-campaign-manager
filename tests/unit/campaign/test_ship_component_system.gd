## Ship Component Management System Test Suite
## Tests the functionality of the ship component management system, including
## component registration, installation, power management, and system-wide operations
@tool
extends GameTest

# Type-safe script references
const ShipComponentScript := preload("res://src/core/ships/components/ShipComponent.gd")

# Type-safe instance variables
var _ship_components: Node = null
var _component_state: Node = null

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize game state
	_component_state = create_test_game_state()
	if not _component_state:
		push_error("Failed to create game state")
		return
	add_child_autofree(_component_state)
	track_test_node(_component_state)
	
	# Initialize ship components
	var component_instance = ShipComponentScript.new()
	_ship_components = TypeSafeMixin._safe_cast_node(component_instance)
	if not _ship_components:
		push_error("Failed to create ship components")
		return
	add_child_autofree(_ship_components)
	track_test_node(_ship_components)
	
	await stabilize_engine()

func after_each() -> void:
	_ship_components = null
	_component_state = null
	await super.after_each()

# Component Initialization Tests
func test_component_initialization() -> void:
	assert_not_null(_ship_components, "Ship components should be initialized")
	
	var components: Dictionary = TypeSafeMixin._safe_method_call_dict(_ship_components, "get_all_components", [])
	assert_true(components.size() > 0, "Should have default components")
	
	var is_initialized: bool = TypeSafeMixin._safe_method_call_bool(_ship_components, "is_initialized", [])
	assert_true(is_initialized, "System should be initialized")

# Component Management Tests
func test_component_management() -> void:
	watch_signals(_ship_components)
	
	# Test component addition
	var component_data := {
		"id": "test_engine",
		"type": GameEnums.ShipComponentType.ENGINE_BASIC,
		"name": "Test Engine",
		"power": 100
	}
	
	var success: bool = TypeSafeMixin._safe_method_call_bool(_ship_components, "add_component", [component_data])
	assert_true(success, "Should add component")
	verify_signal_emitted(_ship_components, "component_added")
	
	# Test component retrieval
	var component: Dictionary = TypeSafeMixin._safe_method_call_dict(_ship_components, "get_component", ["test_engine"])
	assert_eq(component.name, "Test Engine", "Component data should match")
	
	# Test component removal
	success = TypeSafeMixin._safe_method_call_bool(_ship_components, "remove_component", ["test_engine"])
	assert_true(success, "Should remove component")
	verify_signal_emitted(_ship_components, "component_removed")

# Component Type Tests
func test_component_types() -> void:
	watch_signals(_ship_components)
	
	# Test type registration
	var type_data := {
		"id": GameEnums.ShipComponentType.ENGINE_BASIC,
		"name": "Basic Engine",
		"slots": ["engine_bay"]
	}
	
	var success: bool = TypeSafeMixin._safe_method_call_bool(_ship_components, "register_component_type", [type_data])
	assert_true(success, "Should register component type")
	verify_signal_emitted(_ship_components, "type_registered")
	
	# Test type info
	var info: Dictionary = TypeSafeMixin._safe_method_call_dict(_ship_components, "get_type_info", [GameEnums.ShipComponentType.ENGINE_BASIC])
	assert_eq(info.name, "Basic Engine", "Type info should match")

# Component Slot Tests
func test_component_slots() -> void:
	watch_signals(_ship_components)
	
	# Test slot registration
	var slot_data := {
		"id": "engine_bay",
		"name": "Engine Bay",
		"allowed_types": [GameEnums.ShipComponentType.ENGINE_BASIC]
	}
	
	var success: bool = TypeSafeMixin._safe_method_call_bool(_ship_components, "register_slot", [slot_data])
	assert_true(success, "Should register slot")
	verify_signal_emitted(_ship_components, "slot_registered")
	
	# Test slot info
	var info: Dictionary = TypeSafeMixin._safe_method_call_dict(_ship_components, "get_slot_info", ["engine_bay"])
	assert_eq(info.name, "Engine Bay", "Slot info should match")

# Component Installation Tests
func test_component_installation() -> void:
	watch_signals(_ship_components)
	
	# Create test component and slot
	var component_data := {
		"id": "test_engine",
		"type": GameEnums.ShipComponentType.ENGINE_BASIC,
		"name": "Test Engine"
	}
	TypeSafeMixin._safe_method_call_bool(_ship_components, "add_component", [component_data])
	
	var slot_data := {
		"id": "engine_bay",
		"allowed_types": [GameEnums.ShipComponentType.ENGINE_BASIC]
	}
	TypeSafeMixin._safe_method_call_bool(_ship_components, "register_slot", [slot_data])
	
	# Test installation
	var success: bool = TypeSafeMixin._safe_method_call_bool(_ship_components, "install_component", ["test_engine", "engine_bay"])
	assert_true(success, "Should install component")
	verify_signal_emitted(_ship_components, "component_installed")
	
	# Test installed component
	var installed_id: String = TypeSafeMixin._safe_method_call_string(_ship_components, "get_installed_component", ["engine_bay"])
	assert_eq(installed_id, "test_engine", "Installed component should match")

# Component Status Tests
func test_component_status() -> void:
	watch_signals(_ship_components)
	
	# Add test component
	var component_data := {
		"id": "test_engine",
		"type": GameEnums.ShipComponentType.ENGINE_BASIC,
		"health": 100
	}
	TypeSafeMixin._safe_method_call_bool(_ship_components, "add_component", [component_data])
	
	# Test damage
	var success: bool = TypeSafeMixin._safe_method_call_bool(_ship_components, "damage_component", ["test_engine", 50])
	assert_true(success, "Should damage component")
	verify_signal_emitted(_ship_components, "component_damaged")
	
	# Test repair
	success = TypeSafeMixin._safe_method_call_bool(_ship_components, "repair_component", ["test_engine", 25])
	assert_true(success, "Should repair component")
	verify_signal_emitted(_ship_components, "component_repaired")
	
	# Test health
	var health: int = TypeSafeMixin._safe_method_call_int(_ship_components, "get_component_health", ["test_engine"])
	assert_eq(health, 75, "Component health should match")

# Component Power Tests
func test_component_power() -> void:
	watch_signals(_ship_components)
	
	# Add test component
	var component_data := {
		"id": "test_engine",
		"type": GameEnums.ShipComponentType.ENGINE_BASIC,
		"power_draw": 50
	}
	TypeSafeMixin._safe_method_call_bool(_ship_components, "add_component", [component_data])
	
	# Test power allocation
	var success: bool = TypeSafeMixin._safe_method_call_bool(_ship_components, "allocate_power", ["test_engine", 50])
	assert_true(success, "Should allocate power")
	verify_signal_emitted(_ship_components, "power_allocated")
	
	# Test power usage
	var power_usage: int = TypeSafeMixin._safe_method_call_int(_ship_components, "get_power_usage", ["test_engine"])
	assert_eq(power_usage, 50, "Power usage should match")

# Component Compatibility Tests
func test_component_compatibility() -> void:
	watch_signals(_ship_components)
	
	# Add test components
	var component_data := {
		"id": "test_engine",
		"type": GameEnums.ShipComponentType.ENGINE_BASIC,
		"requirements": ["power_core"]
	}
	TypeSafeMixin._safe_method_call_bool(_ship_components, "add_component", [component_data])
	
	var power_core_data := {
		"id": "power_core",
		"type": GameEnums.ShipComponentType.HULL_BASIC
	}
	TypeSafeMixin._safe_method_call_bool(_ship_components, "add_component", [power_core_data])
	
	# Test compatibility check
	var is_compatible: bool = TypeSafeMixin._safe_method_call_bool(_ship_components, "check_compatibility", ["test_engine", "power_core"])
	assert_true(is_compatible, "Components should be compatible")

# Component Persistence Tests
func test_component_persistence() -> void:
	watch_signals(_ship_components)
	
	# Add test component
	var component_data := {
		"id": "test_engine",
		"type": GameEnums.ShipComponentType.ENGINE_BASIC,
		"name": "Test Engine"
	}
	TypeSafeMixin._safe_method_call_bool(_ship_components, "add_component", [component_data])
	
	# Test state saving
	var save_data: Dictionary = TypeSafeMixin._safe_method_call_dict(_ship_components, "save_state", [])
	assert_true(save_data.has("components"), "Should save component data")
	verify_signal_emitted(_ship_components, "state_saved")
	
	# Test state loading
	var success: bool = TypeSafeMixin._safe_method_call_bool(_ship_components, "load_state", [save_data])
	assert_true(success, "Should load component data")
	verify_signal_emitted(_ship_components, "state_loaded")
	
	var loaded_component: Dictionary = TypeSafeMixin._safe_method_call_dict(_ship_components, "get_component", ["test_engine"])
	assert_eq(loaded_component.name, "Test Engine", "Component data should be restored")

# Error Handling Tests
func test_error_handling() -> void:
	watch_signals(_ship_components)
	
	# Test invalid component
	var success: bool = TypeSafeMixin._safe_method_call_bool(_ship_components, "add_component", [null])
	assert_false(success, "Should not add invalid component")
	verify_signal_not_emitted(_ship_components, "component_added")
	
	# Test invalid slot
	success = TypeSafeMixin._safe_method_call_bool(_ship_components, "install_component", ["test_engine", "invalid_slot"])
	assert_false(success, "Should not install to invalid slot")
	verify_signal_not_emitted(_ship_components, "component_installed")

# System State Tests
func test_system_state() -> void:
	watch_signals(_ship_components)
	
	# Test system pause
	TypeSafeMixin._safe_method_call_bool(_ship_components, "pause_system", [])
	var is_paused: bool = TypeSafeMixin._safe_method_call_bool(_ship_components, "is_paused", [])
	assert_true(is_paused, "System should be paused")
	verify_signal_emitted(_ship_components, "system_paused")
	
	# Test system resume
	TypeSafeMixin._safe_method_call_bool(_ship_components, "resume_system", [])
	is_paused = TypeSafeMixin._safe_method_call_bool(_ship_components, "is_paused", [])
	assert_false(is_paused, "System should be resumed")
	verify_signal_emitted(_ship_components, "system_resumed")