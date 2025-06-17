@tool
extends "res://addons/gut/test.gd"

# Type-safe script references
const SettingsDialogScript := preload("res://src/ui/dialogs/SettingsDialog.gd")
const SettingsDialogScene := preload("res://src/ui/dialogs/SettingsDialog.tscn")
const ThemeManagerScript := preload("res://src/ui/themes/ThemeManager.gd")
const ThemeManagerScene := preload("res://src/ui/themes/ThemeManager.tscn")

# Test constants
const TEST_THEMES := ["base", "dark", "light"]
const TEST_TEXT_SIZES := ["small", "normal", "large"]

# Instance variables
var settings_dialog: SettingsDialogScript
var theme_manager: ThemeManagerScript

# Signal tracking
var settings_changed_emitted := false
var dialog_closed_emitted := false

func before_each():
	# Create and add the theme manager first
	theme_manager = ThemeManagerScene.instantiate()
	add_child(theme_manager)
	
	# Create and add the settings dialog
	settings_dialog = SettingsDialogScene.instantiate()
	add_child(settings_dialog)
	
	# Initialize the settings dialog with the theme manager
	if settings_dialog.has_method("initialize"):
		settings_dialog.initialize(theme_manager)
	
	# Reset signal tracking
	_reset_signal_states()
	_connect_signals()

func after_each():
	_cleanup_signals()
	
	if is_instance_valid(settings_dialog):
		settings_dialog.queue_free()
	
	if is_instance_valid(theme_manager):
		theme_manager.queue_free()

func _reset_signal_states() -> void:
	settings_changed_emitted = false
	dialog_closed_emitted = false

func _connect_signals() -> void:
	if settings_dialog != null:
		if settings_dialog.has_signal("settings_changed"):
			settings_dialog.settings_changed.connect(_on_settings_changed)
		
		if settings_dialog.has_signal("dialog_closed"):
			settings_dialog.dialog_closed.connect(_on_dialog_closed)

func _cleanup_signals() -> void:
	if settings_dialog != null:
		if settings_dialog.has_signal("settings_changed") and settings_dialog.settings_changed.is_connected(_on_settings_changed):
			settings_dialog.settings_changed.disconnect(_on_settings_changed)
		
		if settings_dialog.has_signal("dialog_closed") and settings_dialog.dialog_closed.is_connected(_on_dialog_closed):
			settings_dialog.dialog_closed.disconnect(_on_dialog_closed)

# Signal handlers
func _on_settings_changed(_settings: Dictionary) -> void:
	settings_changed_emitted = true

func _on_dialog_closed() -> void:
	dialog_closed_emitted = true

# Tests
func test_initial_state() -> void:
	assert_not_null(settings_dialog, "SettingsDialog should be instantiated")
	assert_not_null(theme_manager, "ThemeManager should be instantiated")
	assert_false(settings_dialog.visible, "Dialog should not be visible initially")

func test_show_dialog() -> void:
	settings_dialog.show_dialog()
	assert_true(settings_dialog.visible, "Dialog should be visible after show_dialog()")

func test_hide_dialog() -> void:
	settings_dialog.show_dialog()
	settings_dialog.hide_dialog()
	assert_false(settings_dialog.visible, "Dialog should not be visible after hide_dialog()")
	assert_true(dialog_closed_emitted, "dialog_closed signal should be emitted")

func test_theme_selection() -> void:
	settings_dialog.show_dialog()
	
	# Test selecting each available theme
	for theme in TEST_THEMES:
		# Find and simulate theme option button selection
		var option_button = _find_theme_option_button()
		assert_not_null(option_button, "Theme option button should exist")
		
		# Find the index for the theme
		var theme_index := -1
		for i in range(option_button.item_count):
			if option_button.get_item_text(i) == theme:
				theme_index = i
				break
		
		assert_gt(theme_index, -1, "Theme '" + theme + "' should be in the option list")
		
		# Select the theme and check if it's applied
		_reset_signal_states()
		option_button.select(theme_index)
		option_button.emit_signal("item_selected", theme_index)
		
		assert_true(settings_changed_emitted, "settings_changed signal should be emitted")
		assert_eq(theme_manager.current_theme_name, theme.to_lower(), "Theme should be changed to '" + theme + "'")

func test_text_size_selection() -> void:
	settings_dialog.show_dialog()
	
	# Test selecting each available text size
	for size in TEST_TEXT_SIZES:
		# Find and simulate text size option button selection
		var option_button = _find_text_size_option_button()
		assert_not_null(option_button, "Text size option button should exist")
		
		# Find the index for the text size
		var size_index := -1
		for i in range(option_button.item_count):
			if option_button.get_item_text(i).to_lower() == size:
				size_index = i
				break
		
		assert_gt(size_index, -1, "Text size '" + size + "' should be in the option list")
		
		# Select the text size and check if it's applied
		_reset_signal_states()
		option_button.select(size_index)
		option_button.emit_signal("item_selected", size_index)
		
		assert_true(settings_changed_emitted, "settings_changed signal should be emitted")

func test_high_contrast_toggle() -> void:
	settings_dialog.show_dialog()
	
	# Find high contrast check button
	var check_button = _find_high_contrast_check_button()
	assert_not_null(check_button, "High contrast check button should exist")
	
	# Test toggling high contrast on
	_reset_signal_states()
	var initial_state = check_button.button_pressed
	check_button.button_pressed = !initial_state
	check_button.emit_signal("toggled", !initial_state)
	
	assert_true(settings_changed_emitted, "settings_changed signal should be emitted")
	assert_eq(theme_manager.high_contrast_enabled, !initial_state, "High contrast setting should be toggled")

func test_animations_toggle() -> void:
	settings_dialog.show_dialog()
	
	# Find animations check button
	var check_button = _find_animations_check_button()
	assert_not_null(check_button, "Animations check button should exist")
	
	# Test toggling animations on/off
	_reset_signal_states()
	var initial_state = check_button.button_pressed
	check_button.button_pressed = !initial_state
	check_button.emit_signal("toggled", !initial_state)
	
	assert_true(settings_changed_emitted, "settings_changed signal should be emitted")
	assert_eq(theme_manager.animations_enabled, !initial_state, "Animations setting should be toggled")

func test_dialog_apply_button() -> void:
	settings_dialog.show_dialog()
	
	# Find apply button
	var apply_button = _find_apply_button()
	assert_not_null(apply_button, "Apply button should exist")
	
	# Simulate clicking apply button
	_reset_signal_states()
	apply_button.emit_signal("pressed")
	
	assert_true(dialog_closed_emitted, "dialog_closed signal should be emitted")
	assert_false(settings_dialog.visible, "Dialog should be hidden after apply")

func test_dialog_cancel_button() -> void:
	settings_dialog.show_dialog()
	
	# Find cancel button
	var cancel_button = _find_cancel_button()
	assert_not_null(cancel_button, "Cancel button should exist")
	
	# Simulate clicking cancel button
	_reset_signal_states()
	cancel_button.emit_signal("pressed")
	
	assert_true(dialog_closed_emitted, "dialog_closed signal should be emitted")
	assert_false(settings_dialog.visible, "Dialog should be hidden after cancel")

# Helper methods to find UI elements
func _find_theme_option_button() -> OptionButton:
	return _find_control_by_type_and_property(settings_dialog, "OptionButton", "name", "*theme*")

func _find_text_size_option_button() -> OptionButton:
	return _find_control_by_type_and_property(settings_dialog, "OptionButton", "name", "*text*size*")

func _find_high_contrast_check_button() -> CheckButton:
	return _find_control_by_type_and_property(settings_dialog, "CheckButton", "name", "*contrast*")

func _find_animations_check_button() -> CheckButton:
	return _find_control_by_type_and_property(settings_dialog, "CheckButton", "name", "*animation*")

func _find_apply_button() -> Button:
	return _find_control_by_type_and_property(settings_dialog, "Button", "text", "*Apply*")

func _find_cancel_button() -> Button:
	return _find_control_by_type_and_property(settings_dialog, "Button", "text", "*Cancel*")

func _find_control_by_type_and_property(parent: Node, control_class_name: String, property: String, value_pattern: String) -> Control:
	if not parent or not is_instance_valid(parent):
		return null
		
	# Check if the current node matches
	if parent.get_class() == control_class_name or control_class_name in parent.get_class_list():
		var property_value = str(parent.get(property)).to_lower() if parent.has_method("get") and parent.get(property) != null else ""
		var pattern = value_pattern.to_lower()
		
		if "*" in pattern:
			# Handle wildcard pattern
			var parts = pattern.split("*")
			var matches = true
			
			for part in parts:
				if part and part not in property_value:
					matches = false
					break
					
			if matches:
				return parent
		elif property_value == pattern:
			return parent
	
	# Recursively search children
	for child in parent.get_children():
		var result = _find_control_by_type_and_property(child, control_class_name, property, value_pattern)
		if result:
			return result
			
	return null