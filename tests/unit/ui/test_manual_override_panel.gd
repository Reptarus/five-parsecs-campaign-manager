@tool
extends "res://tests/test_base.gd"

const ManualOverridePanel := preload("res://src/ui/components/combat/overrides/manual_override_panel.tscn")

var panel: Node

func before_each() -> void:
    super.before_each()
    panel = ManualOverridePanel.instantiate()
    add_child(panel)

func after_each() -> void:
    super.after_each()
    panel = null

func test_panel_starts_hidden() -> void:
    assert_false(panel.visible, "Panel should start hidden")

func test_show_override_displays_panel() -> void:
    panel.show_override("test_context", 3)
    assert_true(panel.visible, "Panel should be visible after show_override")
    assert_eq(panel.current_context, "test_context", "Context should be set")
    assert_eq(panel.current_value, 3, "Current value should be set")

func test_apply_button_emits_signal() -> void:
    watch_signals(panel)
    panel.show_override("test_context", 3)
    panel.override_value_spinbox.value = 4
    panel.apply_button.emit_signal("pressed")
    
    assert_signal_emitted(panel, "override_applied")
    assert_eq(panel.override_value_spinbox.value, 4, "Override value should be correct")
    assert_false(panel.visible, "Panel should hide after apply")

func test_cancel_button_emits_signal() -> void:
    watch_signals(panel)
    panel.show_override("test_context", 3)
    panel.cancel_button.emit_signal("pressed")
    
    assert_signal_emitted(panel, "override_cancelled")
    assert_false(panel.visible, "Panel should hide after cancel")

func test_value_change_enables_apply_button() -> void:
    panel.show_override("test_context", 3)
    assert_true(panel.apply_button.disabled, "Apply button should start disabled")
    
    panel.override_value_spinbox.value = 4
    assert_false(panel.apply_button.disabled, "Apply button should be enabled after value change")
    
    panel.override_value_spinbox.value = 3
    assert_true(panel.apply_button.disabled, "Apply button should be disabled when value matches current")

func test_context_label_formatting() -> void:
    panel.show_override("ranged_attack_roll", 3)
    assert_eq(panel.override_type_label.text, "Ranged Attack Roll", "Context should be properly formatted")

func test_value_limits() -> void:
    panel.show_override("test_context", 3, 1, 10)
    assert_eq(panel.override_value_spinbox.min_value, 1, "Min value should be set")
    assert_eq(panel.override_value_spinbox.max_value, 10, "Max value should be set")