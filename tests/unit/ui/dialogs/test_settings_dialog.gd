@tool
extends "res://tests/unit/ui/base/component_test_base.gd"

## Test suite for the SettingsDialog component
## Tests dialog visibility, theme selection, and settings changes

const SettingsDialogClass = preload("res://src/ui/dialogs/SettingsDialog.gd")
const SettingsDialogScene = preload("res://src/ui/dialogs/SettingsDialog.tscn")
const ThemeManagerClass = preload("res://src/ui/themes/ThemeManager.gd")
const ThemeManagerScene = preload("res://src/ui/themes/ThemeManager.tscn")

# Test constants
const TEST_THEMES := ["base", "dark", "light"]
const TEST_TEXT_SIZES := ["small", "normal", "large"]

# Type-safe instance variables
var settings_dialog: Control
var theme_manager_instance: Control

# Signal tracking
var settings_changed_emitted: bool = false
var dialog_closed_emitted: bool = false

## Override _create_component_instance to provide the specific component
func _create_component_instance() -> Control:
	# We need the scene instance not just a new SettingsDialog
	return SettingsDialogScene.instantiate()

## Setup before each test
func before_each() -> void:
	# Create and add the theme manager first
	theme_manager_instance = ThemeManagerScene.instantiate()
	add_child_autofree(theme_manager_instance)
	track_test_node(theme_manager_instance)
	
	# Use the base setup which adds the component
	await super.before_each()
	
	# Keep a reference to the component
	settings_dialog = _component
	
	# Initialize the settings dialog with the theme manager
	if settings_dialog and settings_dialog.has_method("initialize"):
		settings_dialog.initialize(theme_manager_instance)
	
	# Reset signal tracking
	_reset_signal_states()
	_connect_signals()

## Cleanup after each test
func after_each() -> void:
	_reset_signal_states()
	_disconnect_signals()
	await super.after_each()
	
	if is_instance_valid(theme_manager_instance) and not theme_manager_instance.is_queued_for_deletion():
		theme_manager_instance.queue_free()
	theme_manager_instance = null

## Reset signal tracking states
func _reset_signal_states() -> void:
	settings_changed_emitted = false
	dialog_closed_emitted = false

## Connect to component signals
func _connect_signals() -> void:
	if settings_dialog:
		if settings_dialog.has_signal("settings_applied") and not settings_dialog.settings_applied.is_connected(_on_settings_changed):
			settings_dialog.settings_applied.connect(_on_settings_changed)
		
		if settings_dialog.has_signal("dialog_closed") and not settings_dialog.dialog_closed.is_connected(_on_dialog_closed):
			settings_dialog.dialog_closed.connect(_on_dialog_closed)

## Disconnect from component signals
func _disconnect_signals() -> void:
	if settings_dialog:
		if settings_dialog.has_signal("settings_applied") and settings_dialog.settings_applied.is_connected(_on_settings_changed):
			settings_dialog.settings_applied.disconnect(_on_settings_changed)
		
		if settings_dialog.has_signal("dialog_closed") and settings_dialog.dialog_closed.is_connected(_on_dialog_closed):
			settings_dialog.dialog_closed.disconnect(_on_dialog_closed)

## Signal handlers
func _on_settings_changed(_settings: Dictionary) -> void:
	settings_changed_emitted = true

func _on_dialog_closed() -> void:
	dialog_closed_emitted = true

## Test initial component state
func test_initial_state() -> void:
	await test_component_structure()
	
	# Additional component-specific checks
	assert_not_null(settings_dialog, "SettingsDialog should be instantiated")
	assert_not_null(theme_manager_instance, "ThemeManager should be instantiated")
	assert_false(settings_dialog.visible, "Dialog should not be visible initially")

## Test showing the dialog
func test_show_dialog() -> void:
	settings_dialog.show_dialog()
	assert_true(settings_dialog.visible, "Dialog should be visible after show_dialog()")

## Test hiding the dialog
func test_hide_dialog() -> void:
	settings_dialog.show_dialog()
	settings_dialog.hide_dialog()
	assert_false(settings_dialog.visible, "Dialog should not be visible after hide_dialog()")
	assert_true(dialog_closed_emitted, "dialog_closed signal should be emitted")

## Test theme selection
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
			if option_button.get_item_text(i).to_lower() == theme:
				theme_index = i
				break
		
		if theme_index == -1:
			pending("Theme '" + theme + "' not found in options")
			continue
		
		assert_gt(theme_index, -1, "Theme '" + theme + "' should be in the option list")
		
		# Select the theme and check if it's applied
		_reset_signal_states()
		option_button.select(theme_index)
		option_button.item_selected.emit(theme_index)
		
		# Verify theme manager update
		assert_eq(theme_manager_instance.current_theme_name, theme.to_lower(),
			"Theme should be changed to '" + theme + "'")

## Test text size selection
func test_text_size_selection() -> void:
	settings_dialog.show_dialog()
	
	# Find text size option button
	var option_button = _find_text_size_option_button()
	if not option_button:
		pending("Text size option button not found")
		return
	
	# Test selecting each available text size
	for size in TEST_TEXT_SIZES:
		# Find the index for the text size
		var size_index := -1
		for i in range(option_button.item_count):
			if option_button.get_item_text(i).to_lower() == size:
				size_index = i
				break
		
		if size_index == -1:
			pending("Text size '" + size + "' not found in options")
			continue
			
		# Select the text size and check if it's applied
		_reset_signal_states()
		option_button.select(size_index)
		option_button.item_selected.emit(size_index)
		
		# Wait for the theme manager to update
		await get_tree().process_frame

## Test high contrast toggle
func test_high_contrast_toggle() -> void:
	settings_dialog.show_dialog()
	
	# Find high contrast check button
	var check_button = _find_high_contrast_check_button()
	if not check_button:
		pending("High contrast check button not found")
		return
	
	# Test toggling high contrast on/off
	_reset_signal_states()
	var initial_state = check_button.button_pressed
	check_button.button_pressed = !initial_state
	check_button.toggled.emit(!initial_state)
	
	# Verify theme manager update
	assert_eq(theme_manager_instance.high_contrast_enabled, !initial_state,
		"High contrast setting should be toggled")

## Test animations toggle
func test_animations_toggle() -> void:
	settings_dialog.show_dialog()
	
	# Find animations check button
	var check_button = _find_animations_check_button()
	if not check_button:
		pending("Animations check button not found")
		return
	
	# Test toggling animations on/off
	_reset_signal_states()
	var initial_state = check_button.button_pressed
	check_button.button_pressed = !initial_state
	check_button.toggled.emit(!initial_state)
	
	# Verify theme manager update
	assert_eq(theme_manager_instance.animations_enabled, !initial_state,
		"Animations setting should be toggled")

## Test dialog apply button
func test_dialog_apply_button() -> void:
	settings_dialog.show_dialog()
	
	# Find apply button
	var apply_button = _find_apply_button()
	if not apply_button:
		pending("Apply button not found")
		return
	
	# Simulate clicking apply button
	_reset_signal_states()
	apply_button.pressed.emit()
	
	assert_true(dialog_closed_emitted, "dialog_closed signal should be emitted")
	assert_false(settings_dialog.visible, "Dialog should be hidden after apply")

## Test dialog cancel button
func test_dialog_cancel_button() -> void:
	settings_dialog.show_dialog()
	
	# Find cancel button
	var cancel_button = _find_cancel_button()
	if not cancel_button:
		pending("Cancel button not found")
		return
	
	# Simulate clicking cancel button
	_reset_signal_states()
	cancel_button.pressed.emit()
	
	assert_true(dialog_closed_emitted, "dialog_closed signal should be emitted")
	assert_false(settings_dialog.visible, "Dialog should be hidden after cancel")

## Test initialization with null theme manager
func test_initialize_null_theme_manager() -> void:
	# Create a new dialog to test with
	var test_dialog = SettingsDialogScene.instantiate()
	add_child_autofree(test_dialog)
	track_test_node(test_dialog)
	
	# Initialize with null and verify it doesn't crash
	test_dialog.initialize(null)
	
	# Should not affect proper initialization check
	assert_true(test_dialog.is_properly_initialized(),
		"Dialog should still be properly initialized without theme manager")
	
	test_dialog.queue_free()

## Test proper initialization check
func test_proper_initialization() -> void:
	assert_true(settings_dialog.is_properly_initialized(),
		"Dialog should be properly initialized with all components")
	
	# Test with missing components by temporarily nulling references
	var theme_option = settings_dialog.get("theme_option")
	settings_dialog.set("theme_option", null)
	
	assert_false(settings_dialog.is_properly_initialized(),
		"Dialog should report improper initialization with missing components")
	
	# Restore reference
	settings_dialog.set("theme_option", theme_option)

# Helper methods to find UI elements
func _find_theme_option_button() -> OptionButton:
	return settings_dialog.get("theme_option") if settings_dialog else null

func _find_text_size_option_button() -> OptionButton:
	return _find_control_by_type_and_property(settings_dialog, "OptionButton", "name", "*text*size*")

func _find_high_contrast_check_button() -> Control:
	return settings_dialog.get("high_contrast_check") if settings_dialog else null

func _find_animations_check_button() -> Control:
	return settings_dialog.get("reduced_animation_check") if settings_dialog else null

func _find_apply_button() -> Button:
	return _find_control_by_type_and_property(settings_dialog, "Button", "text", "*Apply*")

func _find_cancel_button() -> Button:
	return _find_control_by_type_and_property(settings_dialog, "Button", "text", "*Close*")

## Helper method to find a control by type and property
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
