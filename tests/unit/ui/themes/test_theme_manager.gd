@tool
extends "res://addons/gut/test.gd"

# Type-safe script references
const ThemeManagerScript := preload("res://src/ui/themes/ThemeManager.gd")
const ThemeManagerScene := preload("res://src/ui/themes/ThemeManager.tscn")

# Theme resources
const BaseTheme := preload("res://src/ui/themes/base_theme.tres")
const DarkTheme := preload("res://src/ui/themes/dark_theme.tres")
const LightTheme := preload("res://src/ui/themes/light_theme.tres")
const HighContrastTheme := preload("res://src/ui/themes/high_contrast_theme.tres")

# Test constants
const TEST_SCALE := 1.2
const SMALL_TEXT_SCALE := 0.9
const LARGE_TEXT_SCALE := 1.4

# Instance variables
var theme_manager: ThemeManagerScript
var test_control: Control

# Signal tracking
var theme_changed_emitted := false
var scale_changed_emitted := false
var accessibility_changed_emitted := false

func before_each():
	theme_manager = ThemeManagerScene.instantiate()
	add_child(theme_manager)
	
	# Create a test control to verify theme application
	test_control = Control.new()
	add_child(test_control)
	
	# Reset signal tracking
	_reset_signal_states()
	_connect_signals()

func after_each():
	_cleanup_signals()
	
	if is_instance_valid(test_control):
		test_control.queue_free()
	
	if is_instance_valid(theme_manager):
		theme_manager.queue_free()

func _reset_signal_states() -> void:
	theme_changed_emitted = false
	scale_changed_emitted = false
	accessibility_changed_emitted = false

func _connect_signals() -> void:
	if theme_manager != null and theme_manager.has_signal("theme_changed"):
		theme_manager.theme_changed.connect(_on_theme_changed)
	
	if theme_manager != null and theme_manager.has_signal("scale_changed"):
		theme_manager.scale_changed.connect(_on_scale_changed)
		
	if theme_manager != null and theme_manager.has_signal("accessibility_changed"):
		theme_manager.accessibility_changed.connect(_on_accessibility_changed)

func _cleanup_signals() -> void:
	if theme_manager != null:
		if theme_manager.has_signal("theme_changed") and theme_manager.theme_changed.is_connected(_on_theme_changed):
			theme_manager.theme_changed.disconnect(_on_theme_changed)
		
		if theme_manager.has_signal("scale_changed") and theme_manager.scale_changed.is_connected(_on_scale_changed):
			theme_manager.scale_changed.disconnect(_on_scale_changed)
			
		if theme_manager.has_signal("accessibility_changed") and theme_manager.accessibility_changed.is_connected(_on_accessibility_changed):
			theme_manager.accessibility_changed.disconnect(_on_accessibility_changed)

# Signal handlers
func _on_theme_changed(_theme_name: String) -> void:
	theme_changed_emitted = true

func _on_scale_changed(_scale: float) -> void:
	scale_changed_emitted = true

func _on_accessibility_changed(_options: Dictionary) -> void:
	accessibility_changed_emitted = true

# Tests
func test_initial_state() -> void:
	assert_not_null(theme_manager, "ThemeManager should be instantiated")
	assert_eq(theme_manager.current_theme_name, "base", "Default theme should be 'base'")
	assert_eq(theme_manager.ui_scale, 1.0, "Default UI scale should be 1.0")
	assert_not_null(theme_manager.current_theme, "Current theme resource should not be null")

func test_set_theme() -> void:
	theme_manager.set_theme("dark")
	assert_eq(theme_manager.current_theme_name, "dark", "Theme should be changed to 'dark'")
	assert_true(theme_changed_emitted, "theme_changed signal should be emitted")

func test_set_invalid_theme() -> void:
	var original_theme = theme_manager.current_theme_name
	theme_manager.set_theme("nonexistent_theme")
	assert_eq(theme_manager.current_theme_name, original_theme, "Theme should remain unchanged with invalid theme name")
	assert_false(theme_changed_emitted, "theme_changed signal should not be emitted for invalid themes")

func test_set_ui_scale() -> void:
	theme_manager.set_ui_scale(TEST_SCALE)
	assert_eq(theme_manager.ui_scale, TEST_SCALE, "UI scale should be updated")
	assert_true(scale_changed_emitted, "scale_changed signal should be emitted")

func test_set_text_size() -> void:
	# Test small text
	theme_manager.set_text_size("small")
	assert_eq(theme_manager.get_text_scale(), SMALL_TEXT_SCALE, "Text scale should be set to small")
	
	# Test large text
	theme_manager.set_text_size("large")
	assert_eq(theme_manager.get_text_scale(), LARGE_TEXT_SCALE, "Text scale should be set to large")
	
	# Test normal text
	theme_manager.set_text_size("normal")
	assert_eq(theme_manager.get_text_scale(), 1.0, "Text scale should be set to normal")

func test_toggle_high_contrast() -> void:
	# Enable high contrast
	theme_manager.toggle_high_contrast(true)
	assert_true(theme_manager.high_contrast_enabled, "High contrast should be enabled")
	assert_true(accessibility_changed_emitted, "accessibility_changed signal should be emitted")
	
	# Reset signal tracking and disable high contrast
	_reset_signal_states()
	theme_manager.toggle_high_contrast(false)
	assert_false(theme_manager.high_contrast_enabled, "High contrast should be disabled")
	assert_true(accessibility_changed_emitted, "accessibility_changed signal should be emitted")

func test_toggle_animations() -> void:
	# Disable animations
	theme_manager.toggle_animations(false)
	assert_false(theme_manager.animations_enabled, "Animations should be disabled")
	assert_true(accessibility_changed_emitted, "accessibility_changed signal should be emitted")
	
	# Reset signal tracking and enable animations
	_reset_signal_states()
	theme_manager.toggle_animations(true)
	assert_true(theme_manager.animations_enabled, "Animations should be enabled")
	assert_true(accessibility_changed_emitted, "accessibility_changed signal should be emitted")

func test_apply_theme_to_control() -> void:
	# Apply theme to test control
	theme_manager.apply_theme_to_control(test_control)
	assert_not_null(test_control.theme, "Theme should be applied to control")
	
	# Change theme and verify control theme updates
	var original_theme = test_control.theme
	theme_manager.set_theme("dark")
	theme_manager.apply_theme_to_control(test_control)
	assert_ne(test_control.theme, original_theme, "Control theme should be updated after theme change")

func test_theme_resource_switching() -> void:
	# Test base theme
	theme_manager.set_theme("base")
	assert_eq(theme_manager.current_theme_name, "base", "Theme should be set to base")
	assert_eq(theme_manager.current_theme, BaseTheme, "Base theme resource should be applied")
	
	# Test dark theme
	theme_manager.set_theme("dark")
	assert_eq(theme_manager.current_theme_name, "dark", "Theme should be set to dark")
	assert_eq(theme_manager.current_theme, DarkTheme, "Dark theme resource should be applied")
	
	# Test light theme
	theme_manager.set_theme("light")
	assert_eq(theme_manager.current_theme_name, "light", "Theme should be set to light")
	assert_eq(theme_manager.current_theme, LightTheme, "Light theme resource should be applied")
	
	# Test high contrast theme
	theme_manager.toggle_high_contrast(true)
	assert_eq(theme_manager.current_theme, HighContrastTheme, "High contrast theme resource should be applied")