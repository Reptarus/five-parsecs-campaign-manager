extends "res://addons/gut/test.gd"

var StateVerificationPanel = preload("res://src/ui/components/combat/state/state_verification_panel.tscn")
var panel: Node

func before_each() -> void:
	panel = StateVerificationPanel.instantiate()
	add_child_autofree(panel)
	await get_tree().process_frame

func test_initial_state() -> void:
	assert_false(panel.auto_verify, "Auto-verify should start disabled")
	assert_eq(panel.current_state.size(), 0, "Current state should start empty")
	assert_eq(panel.expected_state.size(), 0, "Expected state should start empty")

func test_update_current_state() -> void:
	var test_state = {
		"combat": {
			"health": 100,
			"armor": 50
		}
	}
	
	panel.update_current_state(test_state)
	assert_eq(panel.current_state, test_state, "Current state should be updated")

func test_update_expected_state() -> void:
	var test_state = {
		"combat": {
			"health": 100,
			"armor": 50
		}
	}
	
	panel.update_expected_state(test_state)
	assert_eq(panel.expected_state, test_state, "Expected state should be updated")

func test_verify_matching_states() -> void:
	watch_signals(panel)
	var test_state = {
		"combat": {
			"health": 100,
			"armor": 50
		}
	}
	
	panel.update_current_state(test_state)
	panel.update_expected_state(test_state)
	panel.verify_state()
	
	assert_signal_emitted(panel, "state_verified")
	var result = get_signal_parameters(panel, "state_verified")[0]
	assert_true(result.verified, "States should match")
	assert_eq(result.mismatches.size(), 0, "Should have no mismatches")

func test_verify_mismatched_states() -> void:
	watch_signals(panel)
	var current_state = {
		"combat": {
			"health": 80,
			"armor": 50
		}
	}
	
	var expected_state = {
		"combat": {
			"health": 100,
			"armor": 50
		}
	}
	
	panel.update_current_state(current_state)
	panel.update_expected_state(expected_state)
	panel.verify_state()
	
	assert_signal_emitted(panel, "state_mismatch_detected")
	var result = get_signal_parameters(panel, "state_verified")[0]
	assert_false(result.verified, "States should not match")
	assert_eq(result.mismatches.size(), 1, "Should have one mismatch")

func test_auto_verify() -> void:
	watch_signals(panel)
	panel._on_auto_verify_toggled(true)
	
	var test_state = {
		"combat": {
			"health": 100
		}
	}
	
	panel.update_current_state(test_state)
	assert_signal_emitted(panel, "state_verified")

func test_manual_correction_request() -> void:
	watch_signals(panel)
	var current_state = {
		"combat": {
			"health": 80
		}
	}
	
	var expected_state = {
		"combat": {
			"health": 100
		}
	}
	
	panel.update_current_state(current_state)
	panel.update_expected_state(expected_state)
	panel._update_state_display()
	
	# Simulate selecting the health item
	var health_item = panel.state_tree.get_root().get_children().get_next().get_children()
	panel.state_tree.set_selected(health_item, 0)
	
	panel._on_correction_pressed()
	
	assert_signal_emitted(panel, "manual_correction_requested")
	var params = get_signal_parameters(panel, "manual_correction_requested")
	assert_eq(params[0], "health", "Should request correction for health")
	assert_eq(params[1], 80, "Should have current value")
	assert_eq(params[2], 100, "Should have expected value")

func test_value_comparison() -> void:
	# Test simple values
	assert_true(panel._compare_values(100, 100), "Integers should match")
	assert_true(panel._compare_values("test", "test"), "Strings should match")
	assert_true(panel._compare_values(true, true), "Booleans should match")
	
	# Test complex values
	var dict1 = {"key": "value"}
	var dict2 = {"key": "value"}
	assert_true(panel._compare_values(dict1, dict2), "Dictionaries should match")
	
	var array1 = [1, 2, 3]
	var array2 = [1, 2, 3]
	assert_true(panel._compare_values(array1, array2), "Arrays should match")

func test_value_parsing() -> void:
	assert_eq(panel._parse_value("100"), 100, "Should parse integer")
	assert_eq(panel._parse_value("3.14"), 3.14, "Should parse float")
	assert_eq(panel._parse_value("true"), true, "Should parse boolean")
	assert_eq(panel._parse_value("test"), "test", "Should keep string")
	assert_eq(panel._parse_value("N/A"), null, "Should parse N/A as null")
	
	var dict_str = '{"key": "value"}'
	var parsed_dict = panel._parse_value(dict_str)
	assert_eq(parsed_dict.key, "value", "Should parse dictionary")

func test_export_verification_results() -> void:
	var current_state = {
		"combat": {
			"health": 80,
			"armor": 50
		}
	}
	
	var expected_state = {
		"combat": {
			"health": 100,
			"armor": 50
		}
	}
	
	panel.update_current_state(current_state)
	panel.update_expected_state(expected_state)
	
	var results = panel.export_verification_results()
	assert_has(results, "timestamp", "Should have timestamp")
	assert_has(results, "categories", "Should have categories")
	assert_false(results.categories.combat.verified, "Combat category should not be verified")
	assert_false(results.categories.combat.states.health.verified, "Health should not be verified")
	assert_true(results.categories.combat.states.armor.verified, "Armor should be verified")