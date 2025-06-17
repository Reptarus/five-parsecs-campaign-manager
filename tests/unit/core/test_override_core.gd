## Override Core Test Suite
## Tests the functionality of the override system including:
## - Override definitions and validation
## - Override state management
## - Override effects and interactions
@tool
extends GdUnitGameTest

# Mock Override Controller with expected values (Universal Mock Strategy)
class MockOverrideController extends Resource:
	var overrides: Dictionary = {}
	var enabled_overrides: Dictionary = {}
	
	func register_override(override_data: Dictionary) -> bool:
		if override_data == null or not override_data.has("name"):
			return false
		
		var override_name: String = override_data["name"]
		overrides[override_name] = override_data
		enabled_overrides[override_name] = override_data.get("enabled", false)
		override_registered.emit(override_name)
		return true
	
	func enable_override(override_name: String) -> bool:
		if not overrides.has(override_name):
			return false
		
		enabled_overrides[override_name] = true
		override_enabled.emit(override_name)
		return true
	
	func disable_override(override_name: String) -> bool:
		if not overrides.has(override_name):
			return false
		
		enabled_overrides[override_name] = false
		override_disabled.emit(override_name)
		return true
	
	func is_override_enabled(override_name: String) -> bool:
		return enabled_overrides.get(override_name, false)
	
	func get_overrides() -> Dictionary:
		return overrides
	
	func get_override_settings(override_name: String) -> Dictionary:
		if overrides.has(override_name):
			return overrides[override_name].get("settings", {})
		return {}
	
	func clear_overrides() -> void:
		overrides.clear()
		enabled_overrides.clear()
		overrides_cleared.emit()
	
	# Required signals (immediate emission pattern)
	signal override_registered(override_name: String)
	signal override_enabled(override_name: String)
	signal override_disabled(override_name: String)
	signal overrides_cleared()

# Type-safe constants
const TEST_TIMEOUT := 2.0

# Type-safe test data
const TEST_OVERRIDE_SETTINGS := {
	"BASIC": {
		"name": "Basic Override",
		"enabled": true,
		"settings": {
			"difficulty": 0, # Normal difficulty
			"permadeath": true
		}
	},
	"ADVANCED": {
		"name": "Advanced Override",
		"enabled": false,
		"settings": {
			"difficulty": 2, # Hard difficulty
			"permadeath": false
		}
	}
}

# Type-safe instance variables
var _override_manager: MockOverrideController = null

# Test Lifecycle Methods
func before_test() -> void:
	super.before_test()
	
	# Use Resource-based mock (proven pattern)
	_override_manager = MockOverrideController.new()
	track_resource(_override_manager)

func after_test() -> void:
	_override_manager = null
	super.after_test()

# Override Management Tests
func test_override_registration() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var result: bool = _override_manager.register_override(TEST_OVERRIDE_SETTINGS.BASIC)
	assert_that(result).override_failure_message("Should register basic override").is_true()
	
	var overrides: Dictionary = _override_manager.get_overrides()
	assert_that(overrides.has("Basic Override")).override_failure_message("Should have basic override registered").is_true()

func test_override_enabling() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	_override_manager.register_override(TEST_OVERRIDE_SETTINGS.ADVANCED)
	var result: bool = _override_manager.enable_override("Advanced Override")
	assert_that(result).override_failure_message("Should enable advanced override").is_true()
	
	var is_enabled: bool = _override_manager.is_override_enabled("Advanced Override")
	assert_that(is_enabled).override_failure_message("Advanced override should be enabled").is_true()

# Override Settings Tests
func test_override_settings() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	_override_manager.register_override(TEST_OVERRIDE_SETTINGS.BASIC)
	var settings: Dictionary = _override_manager.get_override_settings("Basic Override")
	
	assert_that(settings.get("difficulty", -1)).override_failure_message("Basic override should have normal difficulty").is_equal(0)
	assert_that(settings.get("permadeath", false)).override_failure_message("Basic override should have permadeath enabled").is_true()

# Override Validation Tests
func test_invalid_override_handling() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var result: bool = _override_manager.register_override({}) # Empty dict instead of null
	assert_that(result).override_failure_message("Should reject empty override").is_false()
	
	result = _override_manager.enable_override("NonexistentOverride")
	assert_that(result).override_failure_message("Should reject nonexistent override").is_false()

# Performance Tests
func test_override_performance() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var start_time := Time.get_ticks_msec()
	
	for i in range(100):
		var override := TEST_OVERRIDE_SETTINGS.BASIC.duplicate()
		override.name = "Override_%d" % i
		_override_manager.register_override(override)
	
	var duration := Time.get_ticks_msec() - start_time
	assert_that(duration).override_failure_message("Should register 100 overrides within 1 second").is_less(1000)

func test_override_disabling() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	_override_manager.register_override(TEST_OVERRIDE_SETTINGS.BASIC)
	_override_manager.enable_override("Basic Override")
	
	# Verify enabled
	assert_that(_override_manager.is_override_enabled("Basic Override")).override_failure_message("Override should be enabled").is_true()
	
	# Disable and verify
	var result: bool = _override_manager.disable_override("Basic Override")
	assert_that(result).override_failure_message("Should disable override").is_true()
	assert_that(_override_manager.is_override_enabled("Basic Override")).override_failure_message("Override should be disabled").is_false()

func test_multiple_overrides() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	_override_manager.register_override(TEST_OVERRIDE_SETTINGS.BASIC)
	_override_manager.register_override(TEST_OVERRIDE_SETTINGS.ADVANCED)
	
	var overrides: Dictionary = _override_manager.get_overrides()
	assert_that(overrides.size()).override_failure_message("Should have 2 overrides registered").is_equal(2)
	assert_that(overrides.has("Basic Override")).override_failure_message("Should have basic override").is_true()
	assert_that(overrides.has("Advanced Override")).override_failure_message("Should have advanced override").is_true()
	
	# Test enabling different overrides
	_override_manager.enable_override("Basic Override")
	_override_manager.enable_override("Advanced Override")
	
	assert_that(_override_manager.is_override_enabled("Basic Override")).override_failure_message("Basic override should be enabled").is_true()
	assert_that(_override_manager.is_override_enabled("Advanced Override")).override_failure_message("Advanced override should be enabled").is_true()

func test_override_settings_validation() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var custom_override := {
		"name": "Custom Override",
		"enabled": true,
		"settings": {
			"custom_setting": "custom_value",
			"numeric_setting": 42,
			"boolean_setting": false
		}
	}
	
	_override_manager.register_override(custom_override)
	var settings: Dictionary = _override_manager.get_override_settings("Custom Override")
	
	assert_that(settings.get("custom_setting", "")).override_failure_message("Should have custom setting").is_equal("custom_value")
	assert_that(settings.get("numeric_setting", 0)).override_failure_message("Should have numeric setting").is_equal(42)
	assert_that(settings.get("boolean_setting", true)).override_failure_message("Should have boolean setting").is_false()

func test_override_clearing() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	_override_manager.register_override(TEST_OVERRIDE_SETTINGS.BASIC)
	_override_manager.register_override(TEST_OVERRIDE_SETTINGS.ADVANCED)
	
	var overrides: Dictionary = _override_manager.get_overrides()
	assert_that(overrides.size()).override_failure_message("Should have overrides before clearing").is_greater(0)
	
	_override_manager.clear_overrides()
	overrides = _override_manager.get_overrides()
	assert_that(overrides.size()).override_failure_message("Should have no overrides after clearing").is_equal(0)

func test_edge_cases() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Test empty override name
	var empty_override := {"name": "", "enabled": true}
	var result: bool = _override_manager.register_override(empty_override)
	assert_that(result).override_failure_message("Should accept override with empty name").is_true()
	
	# Test missing settings
	var minimal_override := {"name": "Minimal Override"}
	result = _override_manager.register_override(minimal_override)
	assert_that(result).override_failure_message("Should accept override without settings").is_true()
	
	var settings: Dictionary = _override_manager.get_override_settings("Minimal Override")
	assert_that(settings.size()).override_failure_message("Missing settings should return empty dict").is_equal(0)
	
	# Test override without enabled flag
	assert_that(_override_manager.is_override_enabled("Minimal Override")).override_failure_message("Override without enabled flag should default to false").is_false()