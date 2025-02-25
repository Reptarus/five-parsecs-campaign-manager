## Resource System Test Suite
## Tests the functionality of the campaign resource management system
@tool
extends GameTest

# Type-safe script references
const ResourceSystem := preload("res://src/core/systems/ResourceSystem.gd")

# Type-safe instance variables
var _resource_system: Node = null
var _resource_state: Node = null

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize game state
	_resource_state = create_test_game_state()
	if not _resource_state:
		push_error("Failed to create game state")
		return
	add_child_autofree(_resource_state)
	track_test_node(_resource_state)
	
	# Initialize resource system
	_resource_system = ResourceSystem.new()
	if not _resource_system:
		push_error("Failed to create resource system")
		return
	add_child_autofree(_resource_system)
	track_test_node(_resource_system)
	
	await stabilize_engine()

func after_each() -> void:
	_resource_system = null
	_resource_state = null
	await super.after_each()

# System Initialization Tests
func test_system_initialization() -> void:
	assert_not_null(_resource_system, "Resource system should be initialized")
	
	var resources: Dictionary = TypeSafeMixin._safe_method_call_dict(_resource_system, "get_all_resources", [])
	assert_true(resources.size() > 0, "Should have default resources")
	
	var is_initialized: bool = TypeSafeMixin._safe_method_call_bool(_resource_system, "is_initialized", [])
	assert_true(is_initialized, "System should be initialized")

# Resource Management Tests
func test_resource_management() -> void:
	watch_signals(_resource_system)
	
	# Test resource addition
	var success: bool = TypeSafeMixin._safe_method_call_bool(_resource_system, "add_resource", [GameEnums.ResourceType.CREDITS, 100])
	assert_true(success, "Should add resource")
	verify_signal_emitted(_resource_system, "resource_added")
	
	# Test resource value
	var value: int = TypeSafeMixin._safe_method_call_int(_resource_system, "get_resource", [GameEnums.ResourceType.CREDITS])
	assert_eq(value, 100, "Resource value should match")
	
	# Test resource removal
	success = TypeSafeMixin._safe_method_call_bool(_resource_system, "remove_resource", [GameEnums.ResourceType.CREDITS, 50])
	assert_true(success, "Should remove resource")
	verify_signal_emitted(_resource_system, "resource_removed")
	
	value = TypeSafeMixin._safe_method_call_int(_resource_system, "get_resource", [GameEnums.ResourceType.CREDITS])
	assert_eq(value, 50, "Resource value should be updated")

# Resource Type Tests
func test_resource_types() -> void:
	watch_signals(_resource_system)
	
	# Test type registration
	var type_data := {
		"id": GameEnums.ResourceType.CREDITS,
		"name": "Credits",
		"max_value": 1000
	}
	
	var success: bool = TypeSafeMixin._safe_method_call_bool(_resource_system, "register_resource_type", [type_data])
	assert_true(success, "Should register resource type")
	verify_signal_emitted(_resource_system, "type_registered")
	
	# Test type info
	var info: Dictionary = TypeSafeMixin._safe_method_call_dict(_resource_system, "get_type_info", [GameEnums.ResourceType.CREDITS])
	assert_eq(info.name, "Credits", "Type info should match")

# Resource Limits Tests
func test_resource_limits() -> void:
	watch_signals(_resource_system)
	
	# Test limit setting
	var success: bool = TypeSafeMixin._safe_method_call_bool(_resource_system, "set_resource_limit", [GameEnums.ResourceType.CREDITS, 1000])
	assert_true(success, "Should set resource limit")
	verify_signal_emitted(_resource_system, "limit_changed")
	
	# Test limit enforcement
	success = TypeSafeMixin._safe_method_call_bool(_resource_system, "add_resource", [GameEnums.ResourceType.CREDITS, 1500])
	assert_false(success, "Should not exceed resource limit")
	verify_signal_emitted(_resource_system, "limit_exceeded")

# Resource Conversion Tests
func test_resource_conversion() -> void:
	watch_signals(_resource_system)
	
	# Test conversion rate setting
	var rate_data := {
		"from_type": GameEnums.ResourceType.CREDITS,
		"to_type": GameEnums.ResourceType.SUPPLIES,
		"rate": 2.0
	}
	
	var success: bool = TypeSafeMixin._safe_method_call_bool(_resource_system, "set_conversion_rate", [rate_data])
	assert_true(success, "Should set conversion rate")
	verify_signal_emitted(_resource_system, "rate_changed")
	
	# Test resource conversion
	TypeSafeMixin._safe_method_call_bool(_resource_system, "add_resource", [GameEnums.ResourceType.CREDITS, 100])
	success = TypeSafeMixin._safe_method_call_bool(_resource_system, "convert_resource", [GameEnums.ResourceType.CREDITS, GameEnums.ResourceType.SUPPLIES, 50])
	assert_true(success, "Should convert resources")
	verify_signal_emitted(_resource_system, "resources_converted")

# Resource Generation Tests
func test_resource_generation() -> void:
	watch_signals(_resource_system)
	
	# Test generator setup
	var generator_data := {
		"type": GameEnums.ResourceType.CREDITS,
		"rate": 10,
		"interval": 1.0
	}
	
	var success: bool = TypeSafeMixin._safe_method_call_bool(_resource_system, "add_resource_generator", [generator_data])
	assert_true(success, "Should add resource generator")
	verify_signal_emitted(_resource_system, "generator_added")
	
	# Test generation
	await get_tree().create_timer(1.1).timeout
	var value: int = TypeSafeMixin._safe_method_call_int(_resource_system, "get_resource", [GameEnums.ResourceType.CREDITS])
	assert_eq(value, 10, "Should generate resources")

# Resource Consumption Tests
func test_resource_consumption() -> void:
	watch_signals(_resource_system)
	
	# Test consumer setup
	var consumer_data := {
		"type": GameEnums.ResourceType.SUPPLIES,
		"rate": 5,
		"interval": 1.0
	}
	
	var success: bool = TypeSafeMixin._safe_method_call_bool(_resource_system, "add_resource_consumer", [consumer_data])
	assert_true(success, "Should add resource consumer")
	verify_signal_emitted(_resource_system, "consumer_added")
	
	# Test consumption
	TypeSafeMixin._safe_method_call_bool(_resource_system, "add_resource", [GameEnums.ResourceType.SUPPLIES, 20])
	await get_tree().create_timer(1.1).timeout
	var value: int = TypeSafeMixin._safe_method_call_int(_resource_system, "get_resource", [GameEnums.ResourceType.SUPPLIES])
	assert_eq(value, 15, "Should consume resources")

# Resource State Tests
func test_resource_state() -> void:
	watch_signals(_resource_system)
	
	# Test state thresholds
	var threshold_data := {
		"type": GameEnums.ResourceType.CREDITS,
		"low": 50,
		"critical": 20
	}
	
	var success: bool = TypeSafeMixin._safe_method_call_bool(_resource_system, "set_state_thresholds", [threshold_data])
	assert_true(success, "Should set state thresholds")
	verify_signal_emitted(_resource_system, "thresholds_changed")
	
	# Test state checks
	TypeSafeMixin._safe_method_call_bool(_resource_system, "add_resource", [GameEnums.ResourceType.CREDITS, 30])
	var is_low: bool = TypeSafeMixin._safe_method_call_bool(_resource_system, "is_resource_low", [GameEnums.ResourceType.CREDITS])
	assert_true(is_low, "Resource should be in low state")

# Resource Persistence Tests
func test_resource_persistence() -> void:
	watch_signals(_resource_system)
	
	# Test state saving
	TypeSafeMixin._safe_method_call_bool(_resource_system, "add_resource", [GameEnums.ResourceType.CREDITS, 100])
	var save_data: Dictionary = TypeSafeMixin._safe_method_call_dict(_resource_system, "save_state", [])
	assert_true(save_data.has("resources"), "Should save resource data")
	verify_signal_emitted(_resource_system, "state_saved")
	
	# Test state loading
	var success: bool = TypeSafeMixin._safe_method_call_bool(_resource_system, "load_state", [save_data])
	assert_true(success, "Should load resource data")
	verify_signal_emitted(_resource_system, "state_loaded")
	
	var value: int = TypeSafeMixin._safe_method_call_int(_resource_system, "get_resource", [GameEnums.ResourceType.CREDITS])
	assert_eq(value, 100, "Resource value should be restored")

# Error Handling Tests
func test_error_handling() -> void:
	watch_signals(_resource_system)
	
	# Test invalid resource type
	var success: bool = TypeSafeMixin._safe_method_call_bool(_resource_system, "add_resource", [-1, 100])
	assert_false(success, "Should not add invalid resource type")
	verify_signal_not_emitted(_resource_system, "resource_added")
	
	# Test invalid value
	success = TypeSafeMixin._safe_method_call_bool(_resource_system, "add_resource", [GameEnums.ResourceType.CREDITS, -100])
	assert_false(success, "Should not add negative value")
	verify_signal_not_emitted(_resource_system, "resource_added")

# System State Tests
func test_system_state() -> void:
	watch_signals(_resource_system)
	
	# Test system pause
	TypeSafeMixin._safe_method_call_bool(_resource_system, "pause_system", [])
	var is_paused: bool = TypeSafeMixin._safe_method_call_bool(_resource_system, "is_paused", [])
	assert_true(is_paused, "System should be paused")
	verify_signal_emitted(_resource_system, "system_paused")
	
	# Test system resume
	TypeSafeMixin._safe_method_call_bool(_resource_system, "resume_system", [])
	is_paused = TypeSafeMixin._safe_method_call_bool(_resource_system, "is_paused", [])
	assert_false(is_paused, "System should be resumed")
	verify_signal_emitted(_resource_system, "system_resumed")
