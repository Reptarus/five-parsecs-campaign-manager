@tool
extends "res://tests/fixtures/base_test.gd"

const OverrideController := preload("res://src/ui/components/combat/overrides/override_controller.tscn")
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

var controller: Node
var mock_resolver: Node
var mock_manager: Node

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	controller = OverrideController.instantiate()
	
	mock_resolver = Node.new()
	mock_resolver.name = "OverrideResolver"
	mock_resolver.add_user_signal("override_requested")
	mock_resolver.add_user_signal("dice_roll_completed")
	mock_resolver.apply_override = func(context: String, value: int): pass
	
	mock_manager = Node.new()
	mock_manager.name = "CombatManager"
	mock_manager.add_user_signal("combat_state_changed")
	mock_manager.add_user_signal("override_validation_requested")
	mock_manager.get_current_state = func() -> Dictionary: return {}
	
	add_child(mock_resolver)
	add_child(mock_manager)
	add_child(controller)
	
	controller.setup_combat_system(mock_resolver, mock_manager)
	watch_signals(controller)
	watch_signals(mock_resolver)
	watch_signals(mock_manager)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	controller = null
	mock_resolver = null
	mock_manager = null

# Helper Methods
func create_combat_state(type: int = GameEnums.VerificationType.COMBAT) -> Dictionary:
	return {
		"type": type,
		"attack_bonus": 2,
		"defense_value": 2,
		"weapon_damage": 3
	}

# Basic State Tests
func test_initial_state() -> void:
	assert_eq(controller.active_context, "", "Active context should start empty")
	assert_false(controller.override_panel.visible, "Override panel should start hidden")
	assert_eq(controller.get_verification_type(), GameEnums.VerificationType.NONE, "Should start with no verification type")

# Override Request Tests
func test_request_override() -> void:
	controller.request_override("attack_roll", 3, GameEnums.VerificationType.COMBAT)
	
	assert_eq(controller.active_context, "attack_roll", "Active context should be set")
	assert_true(controller.override_panel.visible, "Override panel should be visible")
	assert_eq(controller.get_verification_type(), GameEnums.VerificationType.COMBAT, "Should set correct verification type")

func test_multiple_override_requests() -> void:
	var override_contexts = [
		{"context": "attack_roll", "value": 3, "type": GameEnums.VerificationType.COMBAT},
		{"context": "movement", "value": 2, "type": GameEnums.VerificationType.MOVEMENT},
		{"context": "reaction", "value": 1, "type": GameEnums.VerificationType.STATE}
	]
	
	for override in override_contexts:
		controller.request_override(override.context, override.value, override.type)
		assert_eq(controller.active_context, override.context, "Should set correct context")
		assert_eq(controller.get_verification_type(), override.type, "Should set correct type")
		controller.override_panel._on_cancel_pressed()

# Override Application Tests
func test_override_applied() -> void:
	controller.request_override("attack_roll", 3, GameEnums.VerificationType.COMBAT)
	
	controller.override_panel.override_value_spinbox.value = 4
	controller.override_panel._on_apply_pressed()
	
	assert_signal_emitted(controller, "override_applied")
	assert_eq(controller.active_context, "attack_roll", "Context should remain set until override is complete")
	assert_eq(controller.override_panel.override_value_spinbox.value, 4, "Override value should be updated")

func test_override_cancelled() -> void:
	controller.request_override("attack_roll", 3, GameEnums.VerificationType.COMBAT)
	
	controller.override_panel._on_cancel_pressed()
	
	assert_signal_emitted(controller, "override_cancelled")
	assert_eq(controller.active_context, "", "Active context should be cleared")
	assert_false(controller.override_panel.visible, "Override panel should be hidden")
	assert_eq(controller.get_verification_type(), GameEnums.VerificationType.NONE, "Should reset verification type")

# Combat System Integration Tests
func test_combat_override_requested() -> void:
	mock_resolver.emit_signal("override_requested", "attack_roll", 3, GameEnums.VerificationType.COMBAT)
	
	assert_eq(controller.active_context, "attack_roll", "Should handle combat override request")
	assert_true(controller.override_panel.visible, "Should show override panel")
	assert_eq(controller.get_verification_type(), GameEnums.VerificationType.COMBAT, "Should set combat verification type")

func test_dice_roll_completed() -> void:
	controller.request_override("attack_roll", 3, GameEnums.VerificationType.COMBAT)
	mock_resolver.emit_signal("dice_roll_completed", "attack_roll", 4)
	
	assert_false(controller.override_panel.visible, "Should hide panel when roll completes")
	assert_eq(controller.get_verification_type(), GameEnums.VerificationType.NONE, "Should reset verification type")

# Validation Tests
func test_validate_combat_overrides() -> void:
	mock_manager.get_current_state = func() -> Dictionary: return create_combat_state()
	
	var test_cases = [
		{"context": "attack_roll", "value": 8, "expected": true, "message": "Should allow valid attack roll"},
		{"context": "attack_roll", "value": 9, "expected": false, "message": "Should reject invalid attack roll"},
		{"context": "damage_roll", "value": 6, "expected": true, "message": "Should allow valid damage roll"},
		{"context": "damage_roll", "value": 7, "expected": false, "message": "Should reject invalid damage roll"},
		{"context": "defense_roll", "value": 8, "expected": true, "message": "Should allow valid defense roll"},
		{"context": "defense_roll", "value": 9, "expected": false, "message": "Should reject invalid defense roll"}
	]
	
	for test in test_cases:
		assert_eq(
			controller.validate_override(test.context, test.value),
			test.expected,
			test.message
		)

func test_validate_movement_overrides() -> void:
	mock_manager.get_current_state = func() -> Dictionary: return create_combat_state(GameEnums.VerificationType.MOVEMENT)
	
	var test_cases = [
		{"value": 2, "expected": true, "message": "Should allow movement within range"},
		{"value": 5, "expected": false, "message": "Should reject movement beyond range"}
	]
	
	for test in test_cases:
		assert_eq(
			controller.validate_override("movement", test.value),
			test.expected,
			test.message
		)

# State Change Tests
func test_combat_state_changed() -> void:
	mock_manager.get_current_state = func() -> Dictionary: return create_combat_state()
	controller.request_override("attack_roll", 3, GameEnums.VerificationType.COMBAT)
	controller.override_panel.override_value_spinbox.value = 8
	
	mock_manager.emit_signal("combat_state_changed", create_combat_state())
	
	assert_false(controller.override_panel.visible, "Should hide panel when value becomes invalid")
	assert_eq(controller.get_verification_type(), GameEnums.VerificationType.NONE, "Should reset verification type")

# Error Handling Tests
func test_invalid_operations() -> void:
	# Test invalid override request
	controller.request_override("invalid_context", 3, -1)
	assert_eq(controller.active_context, "", "Should not set context for invalid request")
	assert_false(controller.override_panel.visible, "Should not show panel for invalid request")
	
	# Test invalid validation request
	var result = controller._on_override_validation_requested("invalid_context", 8)
	assert_false(result, "Should reject invalid validation request")
	
	# Test invalid state change
	mock_manager.emit_signal("combat_state_changed", {"invalid": true})
	assert_eq(controller.get_verification_type(), GameEnums.VerificationType.NONE, "Should handle invalid state gracefully")

# Performance Tests
func test_rapid_override_requests() -> void:
	var contexts = ["attack_roll", "defense_roll", "damage_roll"]
	var start_time = Time.get_unix_time_from_system()
	
	for i in range(100):
		var context = contexts[i % contexts.size()]
		controller.request_override(context, i, GameEnums.VerificationType.COMBAT)
		controller.override_panel._on_cancel_pressed()
	
	var end_time = Time.get_unix_time_from_system()
	var time_taken = end_time - start_time
	
	assert_true(time_taken < 1.0, "Should handle rapid override requests efficiently")