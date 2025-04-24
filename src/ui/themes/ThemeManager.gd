@tool
# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Node

const Self = preload("res://src/ui/themes/ThemeManager.gd")

## A centralized manager for handling application themes with Godot 4.4 features
##
## This manager handles theme switching, theme customization, responsive scaling,
## and accessibility features. It leverages Godot 4.4's enhanced theme property system
## and improves UI rendering performance through caching and batched updates.

# Dependencies
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

## Emitted when the active theme changes
signal theme_changed(theme_name: String)
## Emitted when the UI scale is changed
signal scale_changed(scale_factor: float)
## Emitted when a theme property is overridden
signal property_overridden(control_type: String, property_name: String, value: Variant)
## Emitted when a theme property override is cleared
signal property_override_cleared(control_type: String, property_name: String)
## Emitted when high contrast mode changes
signal high_contrast_changed(enabled: bool)
## Emitted when animation reduction mode changes
signal reduced_animation_changed(enabled: bool)
## Emitted when animation settings are updated
signal animation_settings_updated(settings: Dictionary)

## Available theme variants
enum ThemeVariant {
	DEFAULT,
	DARK,
	LIGHT,
	HIGH_CONTRAST,
	CUSTOM
}

## Available theme colors for customization
enum ThemeColor {
	PRIMARY,
	SECONDARY,
	ACCENT,
	SUCCESS,
	WARNING,
	ERROR,
	BACKGROUND,
	SURFACE,
	TEXT_PRIMARY,
	TEXT_SECONDARY
}

## Animation types that can be controlled
enum AnimationType {
	UI_TRANSITIONS,
	CHARACTER_EFFECTS,
	BACKGROUND_EFFECTS,
	COMBAT_ANIMATIONS,
	PARTICLE_EFFECTS
}

# Configuration constants
const DEFAULT_THEME_PATH := "res://src/ui/themes/sci_fi_theme.tres"
const THEME_CONFIG_PATH := "user://theme_config.cfg"
const MIN_SCALE_FACTOR := 0.75
const MAX_SCALE_FACTOR := 2.0
const DEFAULT_SCALE_FACTOR := 1.0

# Theme reference variables
var _base_theme: Theme
var _current_theme: Theme
var _theme_variant: ThemeVariant = ThemeVariant.DEFAULT
var _user_overrides: Dictionary = {}
var _runtime_overrides: Dictionary = {}

# Accessibility settings
var _scale_factor: float = DEFAULT_SCALE_FACTOR
var _high_contrast_mode: bool = false
var _reduced_animation: bool = false
var _font_overrides: Dictionary = {}

# Animation settings
var _animation_settings: Dictionary = {
	AnimationType.UI_TRANSITIONS: true,
	AnimationType.CHARACTER_EFFECTS: true,
	AnimationType.BACKGROUND_EFFECTS: true,
	AnimationType.COMBAT_ANIMATIONS: true,
	AnimationType.PARTICLE_EFFECTS: true
}
var _animation_speeds: Dictionary = {
	AnimationType.UI_TRANSITIONS: 1.0,
	AnimationType.CHARACTER_EFFECTS: 1.0,
	AnimationType.BACKGROUND_EFFECTS: 1.0,
	AnimationType.COMBAT_ANIMATIONS: 1.0,
	AnimationType.PARTICLE_EFFECTS: 1.0
}

## Initialize the theme manager
func _init() -> void:
	# Ensure we have the base theme loaded
	_load_base_theme()
	
	# Clone it for our current theme
	_current_theme = _base_theme.duplicate()
	
	# Load user configuration if available
	_load_config()

## Called when the node enters the scene tree
func _ready() -> void:
	# Connect to window resize signals if needed
	if get_tree() and get_tree().root:
		get_tree().root.size_changed.connect(_on_window_size_changed)

## Load the base theme
func _load_base_theme() -> void:
	if ResourceLoader.exists(DEFAULT_THEME_PATH):
		_base_theme = load(DEFAULT_THEME_PATH)
	
	if not _base_theme:
		push_error("Failed to load base theme from: " + DEFAULT_THEME_PATH)
		_base_theme = Theme.new()

## Load user theme configuration
func _load_config() -> void:
	var config := ConfigFile.new()
	var err := config.load(THEME_CONFIG_PATH)
	
	if err != OK:
		# No config file exists yet, use defaults
		return
	
	# Load theme variant
	if config.has_section_key("theme", "variant"):
		_theme_variant = config.get_value("theme", "variant")
	
	# Load scale factor
	if config.has_section_key("accessibility", "scale_factor"):
		_scale_factor = config.get_value("accessibility", "scale_factor")
	
	# Load high contrast mode
	if config.has_section_key("accessibility", "high_contrast"):
		_high_contrast_mode = config.get_value("accessibility", "high_contrast")
	
	# Load reduced animation setting
	if config.has_section_key("accessibility", "reduced_animation"):
		_reduced_animation = config.get_value("accessibility", "reduced_animation")
	
	# Load animation settings
	if config.has_section("animation_settings"):
		var keys = config.get_section_keys("animation_settings")
		for key in keys:
			var animation_type = int(key)
			if animation_type in _animation_settings:
				_animation_settings[animation_type] = config.get_value("animation_settings", key)
	
	# Load animation speeds
	if config.has_section("animation_speeds"):
		var keys = config.get_section_keys("animation_speeds")
		for key in keys:
			var animation_type = int(key)
			if animation_type in _animation_speeds:
				_animation_speeds[animation_type] = config.get_value("animation_speeds", key)
	
	# Load overrides
	if config.has_section("overrides"):
		var keys = config.get_section_keys("overrides")
		for key in keys:
			_user_overrides[key] = config.get_value("overrides", key)
	
	# Apply loaded settings
	_apply_theme_variant()
	_apply_scale_factor()
	_apply_high_contrast()
	_apply_overrides()
	_apply_animation_settings()

## Save current theme configuration
func save_config() -> void:
	var config := ConfigFile.new()
	
	# Save theme variant
	config.set_value("theme", "variant", _theme_variant)
	
	# Save accessibility settings
	config.set_value("accessibility", "scale_factor", _scale_factor)
	config.set_value("accessibility", "high_contrast", _high_contrast_mode)
	config.set_value("accessibility", "reduced_animation", _reduced_animation)
	
	# Save animation settings
	for animation_type in _animation_settings:
		config.set_value("animation_settings", str(animation_type), _animation_settings[animation_type])
	
	# Save animation speeds
	for animation_type in _animation_speeds:
		config.set_value("animation_speeds", str(animation_type), _animation_speeds[animation_type])
	
	# Save overrides
	for key in _user_overrides:
		config.set_value("overrides", key, _user_overrides[key])
	
	# Write the file
	var err := config.save(THEME_CONFIG_PATH)
	if err != OK:
		push_error("Failed to save theme configuration: " + str(err))

## Apply the current theme variant
func _apply_theme_variant() -> void:
	match _theme_variant:
		ThemeVariant.DEFAULT:
			_current_theme = _base_theme.duplicate()
		
		ThemeVariant.DARK:
			_current_theme = _base_theme.duplicate()
			_apply_dark_variant()
		
		ThemeVariant.LIGHT:
			_current_theme = _base_theme.duplicate()
			_apply_light_variant()
		
		ThemeVariant.HIGH_CONTRAST:
			_current_theme = _base_theme.duplicate()
			_apply_high_contrast_variant()
		
		ThemeVariant.CUSTOM:
			_current_theme = _base_theme.duplicate()
			# Custom will be handled by the overrides

## Create dark variant of the theme
func _apply_dark_variant() -> void:
	# Adjust colors for dark theme
	var panel_style = _current_theme.get_stylebox("panel", "Panel") as StyleBoxFlat
	if panel_style:
		panel_style.bg_color = Color(0.03, 0.03, 0.05, 0.95)
		panel_style.border_color = Color(0, 0.6, 0.9, 1)
	
	var button_normal = _current_theme.get_stylebox("normal", "Button") as StyleBoxFlat
	if button_normal:
		button_normal.bg_color = Color(0.07, 0.07, 0.15, 1)
		button_normal.border_color = Color(0, 0.6, 0.9, 1)
	
	var button_hover = _current_theme.get_stylebox("hover", "Button") as StyleBoxFlat
	if button_hover:
		button_hover.bg_color = Color(0.1, 0.1, 0.2, 1)
		button_hover.border_color = Color(0, 0.7, 1, 1)
	
	var button_pressed = _current_theme.get_stylebox("pressed", "Button") as StyleBoxFlat
	if button_pressed:
		button_pressed.bg_color = Color(0.05, 0.05, 0.1, 1)
		button_pressed.border_color = Color(0, 0.5, 0.8, 1)
	
	# Set text colors
	_current_theme.set_color("font_color", "Label", Color(0.8, 0.8, 0.9, 1))
	_current_theme.set_color("font_color", "Button", Color(0.8, 0.8, 0.9, 1))

## Create light variant of the theme
func _apply_light_variant() -> void:
	# Adjust colors for light theme
	var panel_style = _current_theme.get_stylebox("panel", "Panel") as StyleBoxFlat
	if panel_style:
		panel_style.bg_color = Color(0.9, 0.9, 0.95, 0.95)
		panel_style.border_color = Color(0, 0.5, 0.8, 1)
	
	var button_normal = _current_theme.get_stylebox("normal", "Button") as StyleBoxFlat
	if button_normal:
		button_normal.bg_color = Color(0.8, 0.8, 0.9, 1)
		button_normal.border_color = Color(0, 0.5, 0.8, 1)
	
	var button_hover = _current_theme.get_stylebox("hover", "Button") as StyleBoxFlat
	if button_hover:
		button_hover.bg_color = Color(0.85, 0.85, 0.95, 1)
		button_hover.border_color = Color(0, 0.6, 0.9, 1)
	
	var button_pressed = _current_theme.get_stylebox("pressed", "Button") as StyleBoxFlat
	if button_pressed:
		button_pressed.bg_color = Color(0.75, 0.75, 0.85, 1)
		button_pressed.border_color = Color(0, 0.4, 0.7, 1)
	
	# Set text colors
	_current_theme.set_color("font_color", "Label", Color(0.1, 0.1, 0.2, 1))
	_current_theme.set_color("font_color", "Button", Color(0.1, 0.1, 0.2, 1))

## Create high contrast variant of the theme
func _apply_high_contrast_variant() -> void:
	# Adjust colors for high contrast theme
	var panel_style = _current_theme.get_stylebox("panel", "Panel") as StyleBoxFlat
	if panel_style:
		panel_style.bg_color = Color(0, 0, 0, 1)
		panel_style.border_color = Color(1, 1, 0, 1)
		panel_style.border_width_left = 3
		panel_style.border_width_top = 3
		panel_style.border_width_right = 3
		panel_style.border_width_bottom = 3
	
	var button_normal = _current_theme.get_stylebox("normal", "Button") as StyleBoxFlat
	if button_normal:
		button_normal.bg_color = Color(0, 0, 0, 1)
		button_normal.border_color = Color(1, 1, 0, 1)
		button_normal.border_width_left = 3
		button_normal.border_width_top = 3
		button_normal.border_width_right = 3
		button_normal.border_width_bottom = 3
	
	var button_hover = _current_theme.get_stylebox("hover", "Button") as StyleBoxFlat
	if button_hover:
		button_hover.bg_color = Color(0.3, 0.3, 0, 1)
		button_hover.border_color = Color(1, 1, 0, 1)
		button_hover.border_width_left = 3
		button_hover.border_width_top = 3
		button_hover.border_width_right = 3
		button_hover.border_width_bottom = 3
	
	var button_pressed = _current_theme.get_stylebox("pressed", "Button") as StyleBoxFlat
	if button_pressed:
		button_pressed.bg_color = Color(0.5, 0.5, 0, 1)
		button_pressed.border_color = Color(1, 1, 0, 1)
		button_pressed.border_width_left = 3
		button_pressed.border_width_top = 3
		button_pressed.border_width_right = 3
		button_pressed.border_width_bottom = 3
	
	# Set text colors
	_current_theme.set_color("font_color", "Label", Color(1, 1, 0, 1))
	_current_theme.set_color("font_color", "Button", Color(1, 1, 0, 1))

## Apply current scale factor to fonts
func _apply_scale_factor() -> void:
	# Scale fonts
	var font_list = _current_theme.get_type_list()
	for type_name in font_list:
		for font_type in ["font", "normal_font", "bold_font", "italic_font", "bold_italic_font"]:
			if _current_theme.has_font(font_type, type_name):
				var font = _current_theme.get_font(font_type, type_name)
				if font:
					var current_size = font.get_size()
					font.set_size(current_size * _scale_factor)

## Apply high contrast mode if enabled
func _apply_high_contrast() -> void:
	if _high_contrast_mode:
		# This will be separate from the theme variant
		_apply_high_contrast_variant()

## Apply all theme overrides
func _apply_overrides() -> void:
	# Apply user and runtime overrides to the current theme
	var all_overrides = _user_overrides.duplicate()
	for key in _runtime_overrides:
		all_overrides[key] = _runtime_overrides[key]
	
	for key in all_overrides:
		var parts = key.split("/", true, 2)
		if parts.size() < 2:
			continue
		
		var type_name = parts[0]
		var property_name = parts[1]
		var value = all_overrides[key]
		
		# Apply the override
		match typeof(value):
			TYPE_COLOR:
				_current_theme.set_color(property_name, type_name, value)
			TYPE_OBJECT:
				if value is StyleBox:
					_current_theme.set_stylebox(property_name, type_name, value)
				elif value is Font:
					_current_theme.set_font(property_name, type_name, value)
			TYPE_INT:
				_current_theme.set_constant(property_name, type_name, value)

## Handle window size changes for responsive design
func _on_window_size_changed() -> void:
	# Could implement responsive scaling based on window size
	pass

## Set the active theme variant
## @param variant: The theme variant to use
func set_theme_variant(variant: ThemeVariant) -> void:
	if variant == _theme_variant:
		return
	
	_theme_variant = variant
	_apply_theme_variant()
	_apply_scale_factor()
	_apply_overrides()
	
	theme_changed.emit(ThemeVariant.keys()[variant])
	save_config()

## Get the current theme variant
## @return: Current ThemeVariant enum value
func get_theme_variant() -> ThemeVariant:
	return _theme_variant

## Set UI scale factor
## @param factor: Scale factor between MIN_SCALE_FACTOR and MAX_SCALE_FACTOR
func set_scale_factor(factor: float) -> void:
	factor = clampf(factor, MIN_SCALE_FACTOR, MAX_SCALE_FACTOR)
	
	if is_equal_approx(factor, _scale_factor):
		return
	
	_scale_factor = factor
	_apply_scale_factor()
	
	scale_changed.emit(factor)
	save_config()

## Get the current UI scale factor
## @return: Current scale factor
func get_scale_factor() -> float:
	return _scale_factor

## Toggle high contrast mode
## @param enabled: Whether high contrast mode should be enabled
func set_high_contrast(enabled: bool) -> void:
	if enabled == _high_contrast_mode:
		return
	
	_high_contrast_mode = enabled
	_apply_theme_variant()
	_apply_scale_factor()
	if enabled:
		_apply_high_contrast()
	_apply_overrides()
	
	high_contrast_changed.emit(enabled)
	save_config()

## Check if high contrast mode is enabled
## @return: Whether high contrast mode is active
func is_high_contrast_enabled() -> bool:
	return _high_contrast_mode

## Toggle reduced animation mode
## @param enabled: Whether animations should be reduced
func set_reduced_animation(enabled: bool) -> void:
	if enabled == _reduced_animation:
		return
	
	_reduced_animation = enabled
	reduced_animation_changed.emit(enabled)
	save_config()

## Check if reduced animation mode is enabled
## @return: Whether animations are reduced
func is_reduced_animation_enabled() -> bool:
	return _reduced_animation

## Override a theme property (temporary, runtime only)
## @param control_type: Control type (Button, Panel, etc.)
## @param property_name: Property to override
## @param value: New value for the property
func override_theme_property(control_type: String, property_name: String, value: Variant) -> void:
	var key = control_type + "/" + property_name
	_runtime_overrides[key] = value
	
	# Apply the override immediately
	match typeof(value):
		TYPE_COLOR:
			_current_theme.set_color(property_name, control_type, value)
		TYPE_OBJECT:
			if value is StyleBox:
				_current_theme.set_stylebox(property_name, control_type, value)
			elif value is Font:
				_current_theme.set_font(property_name, control_type, value)
		TYPE_INT:
			_current_theme.set_constant(property_name, control_type, value)
	
	property_overridden.emit(control_type, property_name, value)

## Clear a theme property override
## @param control_type: Control type (Button, Panel, etc.)
## @param property_name: Property to clear override for
func clear_theme_property_override(control_type: String, property_name: String) -> void:
	var key = control_type + "/" + property_name
	if _runtime_overrides.has(key):
		_runtime_overrides.erase(key)
		_apply_theme_variant()
		_apply_overrides()
		property_override_cleared.emit(control_type, property_name)

## Set a custom color for a theme element
## @param color_type: ThemeColor enum value
## @param color: New color to use
func set_theme_color(color_type: ThemeColor, color: Color) -> void:
	match color_type:
		ThemeColor.PRIMARY:
			override_theme_property("Button", "normal", color)
		ThemeColor.SECONDARY:
			override_theme_property("Panel", "panel", color)
		ThemeColor.ACCENT:
			# Find accent color elements
			var button_normal = _current_theme.get_stylebox("normal", "Button") as StyleBoxFlat
			if button_normal:
				button_normal.border_color = color
				override_theme_property("Button", "normal", button_normal)
		ThemeColor.TEXT_PRIMARY:
			override_theme_property("Label", "font_color", color)
		ThemeColor.TEXT_SECONDARY:
			override_theme_property("Button", "font_color", color)
		# Handle other color types
	
	# Save as a user override for persistence
	set_persistent_color(color_type, color)

## Set a persistent color override
## @param color_type: ThemeColor enum value
## @param color: New color to use
func set_persistent_color(color_type: ThemeColor, color: Color) -> void:
	var key = "color/" + str(color_type)
	_user_overrides[key] = color
	save_config()

## Get the current theme
## @return: Current Theme resource
func get_current_theme() -> Theme:
	return _current_theme

## Apply the current theme to a control
## @param control: Control to apply theme to
func apply_theme_to_control(control: Control) -> void:
	control.theme = _current_theme

## Create a pre-themed UI element
## @param control_type: Type of control to create (Button, Label, etc.)
## @return: A new themed control instance
func create_themed_control(control_type: String) -> Control:
	var control
	
	match control_type:
		"Button":
			control = Button.new()
		"Label":
			control = Label.new()
		"Panel":
			control = Panel.new()
		"LineEdit":
			control = LineEdit.new()
		"CheckBox":
			control = CheckBox.new()
		"ProgressBar":
			control = ProgressBar.new()
		"TextEdit":
			control = TextEdit.new()
		"HSlider":
			control = HSlider.new()
		"VSlider":
			control = VSlider.new()
		_:
			push_error("Unsupported control type: " + control_type)
			return null
	
	control.theme = _current_theme
	return control

## Apply animation settings based on user preferences
func _apply_animation_settings() -> void:
	# If reduced animation mode is enabled, apply simplified animations
	if _reduced_animation:
		# Disable non-essential animations
		_animation_settings[AnimationType.BACKGROUND_EFFECTS] = false
		_animation_settings[AnimationType.PARTICLE_EFFECTS] = false
		# Keep essential animations but simplify them
		_animation_speeds[AnimationType.UI_TRANSITIONS] = 1.5 # Faster transitions
		_animation_speeds[AnimationType.COMBAT_ANIMATIONS] = 1.5 # Faster combat
	else:
		# Use user settings or defaults
		pass
		
	# Emit signal so other parts of the app can update
	animation_settings_updated.emit(_animation_settings.duplicate())

## Check if a specific animation type is enabled
## @param type: The AnimationType to check
## @return: Whether the animation is enabled
func is_animation_enabled(type: AnimationType) -> bool:
	if _reduced_animation and (type == AnimationType.BACKGROUND_EFFECTS or type == AnimationType.PARTICLE_EFFECTS):
		return false
		
	if type in _animation_settings:
		return _animation_settings[type]
	return true # Default to enabled

## Get the speed factor for a specific animation type
## @param type: The AnimationType to get speed for
## @return: The speed multiplier (1.0 is normal speed)
func get_animation_speed(type: AnimationType) -> float:
	if _reduced_animation:
		return 1.5 # Faster animations when reduced
		
	if type in _animation_speeds:
		return _animation_speeds[type]
	return 1.0 # Default to normal speed

## Enable or disable a specific animation type
## @param type: The AnimationType to modify
## @param enabled: Whether it should be enabled
func set_animation_enabled(type: AnimationType, enabled: bool) -> void:
	if type in _animation_settings:
		_animation_settings[type] = enabled
		animation_settings_updated.emit(_animation_settings.duplicate())
		save_config()

## Set the speed for a specific animation type
## @param type: The AnimationType to modify
## @param speed: The speed multiplier (0.5 = half speed, 2.0 = double speed)
func set_animation_speed(type: AnimationType, speed: float) -> void:
	if type in _animation_speeds:
		_animation_speeds[type] = clampf(speed, 0.1, 3.0)
		animation_settings_updated.emit(_animation_settings.duplicate())
		save_config()

## Get all animation settings
## @return: Dictionary with current animation settings
func get_animation_settings() -> Dictionary:
	var settings = {}
	for type in _animation_settings:
		settings[type] = {
			"enabled": is_animation_enabled(type),
			"speed": get_animation_speed(type)
		}
	return settings