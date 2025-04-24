@tool
# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Window
class_name SettingsDialog

const Self = preload("res://src/ui/dialogs/SettingsDialog.gd")

## Settings dialog for Five Parsecs Campaign Manager
##
## Provides a user interface for changing theme, display, and accessibility settings
## using Godot 4.4's enhanced UI capabilities.

## Dependencies
const ThemeManager = preload("res://src/ui/themes/ThemeManager.gd")

## Signal when settings are applied
signal settings_applied(settings: Dictionary)
## Signal when settings are reset to defaults
signal settings_reset()
## Signal when dialog is closed
signal dialog_closed()

## UI references
@onready var theme_option: OptionButton = $VBoxContainer/ThemeSection/ThemeOption
@onready var scale_slider: HSlider = $VBoxContainer/DisplaySection/ScaleSlider
@onready var scale_value: Label = $VBoxContainer/DisplaySection/ScaleValue
@onready var high_contrast_check: CheckBox = $VBoxContainer/AccessibilitySection/HighContrastCheck
@onready var reduced_animation_check: CheckBox = $VBoxContainer/AccessibilitySection/ReducedAnimationCheck

## Theme manager reference
var theme_manager: ThemeManager

## Initialize the dialog with the base setup
func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	if not is_properly_initialized():
		push_error("SettingsDialog: Failed to initialize - UI components not found")
		return
	
	# Set up theme options
	theme_option.clear()
	for theme_name in ThemeManager.ThemeVariant.keys():
		theme_option.add_item(theme_name.capitalize())
	
	# Set up scale slider
	scale_slider.min_value = ThemeManager.MIN_SCALE_FACTOR
	scale_slider.max_value = ThemeManager.MAX_SCALE_FACTOR
	scale_slider.step = 0.05
	scale_slider.value = ThemeManager.DEFAULT_SCALE_FACTOR
	update_scale_label(ThemeManager.DEFAULT_SCALE_FACTOR)
	
	# Connect signals
	_connect_signals()
	
	# Hide the dialog by default
	hide()

## Connect the dialog's signals
func _connect_signals() -> void:
	if scale_slider and not scale_slider.value_changed.is_connected(_on_scale_changed):
		scale_slider.value_changed.connect(_on_scale_changed)
		
	if theme_option and not theme_option.item_selected.is_connected(_on_theme_selected):
		theme_option.item_selected.connect(_on_theme_selected)
		
	if high_contrast_check and not high_contrast_check.toggled.is_connected(_on_high_contrast_toggled):
		high_contrast_check.toggled.connect(_on_high_contrast_toggled)
		
	if reduced_animation_check and not reduced_animation_check.toggled.is_connected(_on_reduced_animation_toggled):
		reduced_animation_check.toggled.connect(_on_reduced_animation_toggled)
	
	var apply_button = get_node_or_null("VBoxContainer/ButtonSection/ApplyButton")
	if apply_button and not apply_button.pressed.is_connected(_on_apply_pressed):
		apply_button.pressed.connect(_on_apply_pressed)
	
	var reset_button = get_node_or_null("VBoxContainer/ButtonSection/ResetButton")
	if reset_button and not reset_button.pressed.is_connected(_on_reset_pressed):
		reset_button.pressed.connect(_on_reset_pressed)
	
	var close_button = get_node_or_null("VBoxContainer/ButtonSection/CloseButton")
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	
	if not close_requested.is_connected(_on_close_pressed):
		close_requested.connect(_on_close_pressed)

## Initialize the dialog with theme manager
## @param manager: Reference to the theme manager
func initialize(manager: ThemeManager) -> void:
	theme_manager = manager
	
	if not is_properly_initialized():
		push_error("SettingsDialog: Cannot initialize with theme manager - UI components not found")
		return
		
	# Update controls to match current theme settings
	if theme_manager:
		theme_option.selected = theme_manager.get_theme_variant()
		scale_slider.value = theme_manager.get_scale_factor()
		update_scale_label(theme_manager.get_scale_factor())
		high_contrast_check.button_pressed = theme_manager.is_high_contrast_enabled()
		reduced_animation_check.button_pressed = theme_manager.is_reduced_animation_enabled()

## Update the scale value label
## @param value: New scale value
func update_scale_label(value: float) -> void:
	if scale_value:
		scale_value.text = "%d%%" % int(value * 100)

## Show the dialog with settings
func show_dialog() -> void:
	if not is_properly_initialized():
		push_error("SettingsDialog: Cannot show dialog - UI components not found")
		return
		
	# Update UI to current settings if manager available
	if theme_manager:
		theme_option.selected = theme_manager.get_theme_variant()
		scale_slider.value = theme_manager.get_scale_factor()
		update_scale_label(theme_manager.get_scale_factor())
		high_contrast_check.button_pressed = theme_manager.is_high_contrast_enabled()
		reduced_animation_check.button_pressed = theme_manager.is_reduced_animation_enabled()
	
	# Show the dialog
	popup_centered()
	show()

## Hide the dialog and emit closed signal
func hide_dialog() -> void:
	hide()
	dialog_closed.emit()

## Handle scale slider changes
func _on_scale_changed(value: float) -> void:
	update_scale_label(value)

## Handle theme option selection
func _on_theme_selected(index: int) -> void:
	# Apply theme preview immediately for better feedback
	if theme_manager:
		theme_manager.set_theme_variant(index)

## Handle high contrast toggle
func _on_high_contrast_toggled(enabled: bool) -> void:
	# Apply high contrast immediately for preview
	if theme_manager:
		theme_manager.set_high_contrast(enabled)

## Handle reduced animation toggle
func _on_reduced_animation_toggled(enabled: bool) -> void:
	# Apply reduced animation immediately for preview
	if theme_manager:
		theme_manager.set_reduced_animation(enabled)

## Handle apply button press
func _on_apply_pressed() -> void:
	if not theme_manager:
		push_error("SettingsDialog: Theme manager not connected")
		return
	
	if not is_properly_initialized():
		push_error("SettingsDialog: Cannot apply settings - UI components not found")
		return
	
	# Apply all settings
	theme_manager.set_theme_variant(theme_option.selected)
	theme_manager.set_scale_factor(scale_slider.value)
	theme_manager.set_high_contrast(high_contrast_check.button_pressed)
	theme_manager.set_reduced_animation(reduced_animation_check.button_pressed)
	
	# Save settings
	theme_manager.save_config()
	
	# Emit signal with current settings
	var settings = {
		"theme_variant": theme_option.selected,
		"scale_factor": scale_slider.value,
		"high_contrast": high_contrast_check.button_pressed,
		"reduced_animation": reduced_animation_check.button_pressed
	}
	settings_applied.emit(settings)
	
	# Close dialog
	hide_dialog()

## Handle reset button press
func _on_reset_pressed() -> void:
	if not is_properly_initialized():
		push_error("SettingsDialog: Cannot reset settings - UI components not found")
		return
		
	# Reset to defaults
	theme_option.selected = ThemeManager.ThemeVariant.DEFAULT
	scale_slider.value = ThemeManager.DEFAULT_SCALE_FACTOR
	update_scale_label(ThemeManager.DEFAULT_SCALE_FACTOR)
	high_contrast_check.button_pressed = false
	reduced_animation_check.button_pressed = false
	
	# Apply immediately for feedback
	if theme_manager:
		theme_manager.set_theme_variant(ThemeManager.ThemeVariant.DEFAULT)
		theme_manager.set_scale_factor(ThemeManager.DEFAULT_SCALE_FACTOR)
		theme_manager.set_high_contrast(false)
		theme_manager.set_reduced_animation(false)
	
	settings_reset.emit()

## Handle close button press
func _on_close_pressed() -> void:
	hide_dialog()

## Check if all UI components are properly initialized
## @return: True if all required components are valid
func is_properly_initialized() -> bool:
	return theme_option != null and \
		   scale_slider != null and \
		   scale_value != null and \
		   high_contrast_check != null and \
		   reduced_animation_check != null