@tool
extends "res://tests/fixtures/game_test.gd"

const ManualOverridePanel := preload("res://src/ui/components/combat/overrides/manual_override_panel.gd")

# Test variables
var panel: Node # Using Node type to avoid casting issues

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	panel = ManualOverridePanel.new()
	add_child(panel)
	track_test_node(panel)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	panel = null

# Test Methods
func test_initial_state() -> void:
	assert_false(panel.visible, "Panel should start hidden")
	assert_eq(panel.override_value, 0, "Should start with zero override value")

func test_set_override_value() -> void:
	watch_signals(panel)
	
	panel.set_override_value(5)
	assert_eq(panel.override_value, 5, "Should set override value")
	assert_signal_emitted(panel, "override_value_changed")

func test_reset_override() -> void:
	watch_signals(panel)
	
	panel.set_override_value(5)
	panel.reset_override()
	
	assert_eq(panel.override_value, 0, "Should reset override value")
	assert_signal_emitted(panel, "override_reset")

func test_toggle_visibility() -> void:
	watch_signals(panel)
	
	panel.show()
	assert_true(panel.visible, "Panel should be visible")
	assert_signal_emitted(panel, "visibility_changed")
	
	panel.hide()
	assert_false(panel.visible, "Panel should be hidden")
	assert_signal_emitted(panel, "visibility_changed")