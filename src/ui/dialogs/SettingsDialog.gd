@tool
class_name SettingsDialog
extends Window

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

## UI references
@onready var theme_option: OptionButton = $VBoxContainer/ThemeSection/ThemeOption
@onready var scale_slider: HSlider = $VBoxContainer/DisplaySection/ScaleSlider
@onready var scale_value: Label = $VBoxContainer/DisplaySection/ScaleValue
@onready var high_contrast_check: CheckBox = $VBoxContainer/AccessibilitySection/HighContrastCheck
@onready var reduced_animation_check: CheckBox = $VBoxContainer/AccessibilitySection/ReducedAnimationCheck

## Theme manager reference
var theme_manager: ThemeManager

func _ready() -> void:
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
	scale_slider.value_changed.connect(_on_scale_changed)
	theme_option.item_selected.connect(_on_theme_selected)
	high_contrast_check.toggled.connect(_on_high_contrast_toggled)
	reduced_animation_check.toggled.connect(_on_reduced_animation_toggled)
	
	$VBoxContainer/ButtonSection/ApplyButton.pressed.connect(_on_apply_pressed)
	$VBoxContainer/ButtonSection/ResetButton.pressed.connect(_on_reset_pressed)
	$VBoxContainer/ButtonSection/CloseButton.pressed.connect(_on_close_pressed)
	
	close_requested.connect(_on_close_pressed)

## Connect the theme manager to this dialog
## @param manager: Reference to the theme manager
func connect_theme_manager(manager: ThemeManager) -> void:
	theme_manager = manager
	
	# Update controls to match current theme settings
	theme_option.selected = theme_manager.get_theme_variant()
	scale_slider.value = theme_manager.get_scale_factor()
	update_scale_label(theme_manager.get_scale_factor())
	high_contrast_check.button_pressed = theme_manager.is_high_contrast_enabled()
	reduced_animation_check.button_pressed = theme_manager.is_reduced_animation_enabled()

## Update the scale value label
## @param value: New scale value
func update_scale_label(value: float) -> void:
	scale_value.text = "%d%%" % int(value * 100)

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
		push_error("Theme manager not connected")
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
	hide()

## Handle reset button press
func _on_reset_pressed() -> void:
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
	hide()