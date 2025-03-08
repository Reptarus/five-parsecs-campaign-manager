## Override Core Test Suite
## Tests the functionality of the override system including:
## - Override definitions and validation
## - Override state management
## - Override effects and interactions
@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

# Type-safe script references
const OverrideController := preload("res://src/ui/components/combat/overrides/override_controller.gd")

# Type-safe constants
const TEST_TIMEOUT := 2.0

# Type-safe test data
const TEST_OVERRIDE_SETTINGS := {
    "BASIC": {
        "name": "Basic Override",
        "enabled": true,
        "settings": {
            "difficulty": GameEnums.DifficultyLevel.NORMAL,
            "permadeath": true
        }
    },
    "ADVANCED": {
        "name": "Advanced Override",
        "enabled": false,
        "settings": {
            "difficulty": GameEnums.DifficultyLevel.HARD,
            "permadeath": false
        }
    }
}

# Type-safe instance variables
var _override_manager: Node = null

# Test Lifecycle Methods
func before_each() -> void:
    await super.before_each()
    
    # Initialize override manager
    var override_instance: Node = OverrideController.new()
    _override_manager = TypeSafeMixin._safe_cast_to_node(override_instance)
    if not _override_manager:
        push_error("Failed to create override manager")
        return
    add_child_autofree(_override_manager)
    track_test_node(_override_manager)
    
    watch_signals(_override_manager)
    await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
    _override_manager = null
    await super.after_each()

# Override Management Tests
func test_override_registration() -> void:
    watch_signals(_override_manager)
    
    var result: bool = TypeSafeMixin._call_node_method_bool(_override_manager, "register_override", [TEST_OVERRIDE_SETTINGS.BASIC])
    assert_true(result, "Should register basic override")
    verify_signal_emitted(_override_manager, "override_registered")
    
    var overrides: Dictionary = TypeSafeMixin._call_node_method_dict(_override_manager, "get_overrides", [])
    assert_true(overrides.has("Basic Override"), "Should have basic override registered")

func test_override_enabling() -> void:
    watch_signals(_override_manager)
    
    TypeSafeMixin._call_node_method_bool(_override_manager, "register_override", [TEST_OVERRIDE_SETTINGS.ADVANCED])
    var result: bool = TypeSafeMixin._call_node_method_bool(_override_manager, "enable_override", ["Advanced Override"])
    assert_true(result, "Should enable advanced override")
    verify_signal_emitted(_override_manager, "override_state_changed")
    
    var is_enabled: bool = TypeSafeMixin._call_node_method_bool(_override_manager, "is_override_enabled", ["Advanced Override"])
    assert_true(is_enabled, "Advanced override should be enabled")

# Override Settings Tests
func test_override_settings() -> void:
    watch_signals(_override_manager)
    
    TypeSafeMixin._call_node_method_bool(_override_manager, "register_override", [TEST_OVERRIDE_SETTINGS.BASIC])
    var settings: Dictionary = TypeSafeMixin._call_node_method_dict(_override_manager, "get_override_settings", ["Basic Override"])
    
    assert_eq(settings.difficulty, GameEnums.DifficultyLevel.NORMAL, "Basic override should have normal difficulty")
    assert_true(settings.permadeath, "Basic override should have permadeath enabled")

# Override Validation Tests
func test_invalid_override_handling() -> void:
    watch_signals(_override_manager)
    
    var result: bool = TypeSafeMixin._call_node_method_bool(_override_manager, "register_override", [null])
    assert_false(result, "Should reject null override")
    verify_signal_not_emitted(_override_manager, "override_registered")
    
    result = TypeSafeMixin._call_node_method_bool(_override_manager, "enable_override", ["NonexistentOverride"])
    assert_false(result, "Should reject nonexistent override")
    verify_signal_not_emitted(_override_manager, "override_state_changed")

# Performance Tests
func test_override_performance() -> void:
    watch_signals(_override_manager)
    var start_time := Time.get_ticks_msec()
    
    for i in range(100):
        var override := TEST_OVERRIDE_SETTINGS.BASIC.duplicate()
        override.name = "Override_%d" % i
        TypeSafeMixin._call_node_method_bool(_override_manager, "register_override", [override])
    
    var duration := Time.get_ticks_msec() - start_time
    assert_true(duration < 1000, "Should register 100 overrides within 1 second")
    # Note: Using verify_signal_emitted for signal emission checks