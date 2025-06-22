@tool
extends Node
class_name ThemeManager

## Theme Manager for Five Parsecs Campaign Manager
## Handles theme switching, scaling, and accessibility features

signal theme_changed(theme_name: String)
signal scale_changed(scale_factor: float)
signal accessibility_changed(settings: Dictionary)

enum ThemeVariant {
	DEFAULT,
	DARK,
	HIGH_CONTRAST,
	COLORBLIND_FRIENDLY
}

const MIN_SCALE_FACTOR: float = 0.8
const MAX_SCALE_FACTOR: float = 2.0
const DEFAULT_SCALE_FACTOR: float = 1.0

var current_theme: ThemeVariant = ThemeVariant.DEFAULT
var current_scale: float = DEFAULT_SCALE_FACTOR
var high_contrast_mode: bool = false
var reduced_animation: bool = false
var current_theme_resource: Theme

func _init() -> void:
	_initialize_default_theme()

func _initialize_default_theme() -> void:
	current_theme_resource = Theme.new()
	_setup_default_theme()

func _setup_default_theme() -> void:
	# Set up basic theme properties
	# This would normally load from theme files
	pass

func set_theme_variant(variant: ThemeVariant) -> void:
	if current_theme != variant:
		current_theme = variant
		_apply_theme_variant()
		theme_changed.emit(_get_theme_name(variant))

func _get_theme_name(variant: ThemeVariant) -> String:
	match variant:
		ThemeVariant.DEFAULT:
			return "Default"
		ThemeVariant.DARK:
			return "Dark"
		ThemeVariant.HIGH_CONTRAST:
			return "High Contrast"
		ThemeVariant.COLORBLIND_FRIENDLY:
			return "Colorblind Friendly"
		_:
			return "Unknown"

func _apply_theme_variant() -> void:
	match current_theme:
		ThemeVariant.DEFAULT:
			_apply_default_theme()
		ThemeVariant.DARK:
			_apply_dark_theme()
		ThemeVariant.HIGH_CONTRAST:
			_apply_high_contrast_theme()
		ThemeVariant.COLORBLIND_FRIENDLY:
			_apply_colorblind_friendly_theme()

func _apply_default_theme() -> void:
	# Apply default theme colors and styles
	pass

func _apply_dark_theme() -> void:
	# Apply dark theme colors and styles
	pass

func _apply_high_contrast_theme() -> void:
	# Apply high contrast theme colors and styles
	high_contrast_mode = true

func _apply_colorblind_friendly_theme() -> void:
	# Apply colorblind friendly theme colors and styles
	pass

func set_scale_factor(scale: float) -> void:
	var clamped_scale = clamp(scale, MIN_SCALE_FACTOR, MAX_SCALE_FACTOR)
	if current_scale != clamped_scale:
		current_scale = clamped_scale
		_apply_scale_factor()
		scale_changed.emit(current_scale)

func _apply_scale_factor() -> void:
	# Apply scaling to UI elements
	if current_theme_resource:
		# This would normally scale font sizes, margins, etc.
		pass

func set_high_contrast(enabled: bool) -> void:
	if high_contrast_mode != enabled:
		high_contrast_mode = enabled
		_apply_accessibility_settings()

func set_reduced_animation(enabled: bool) -> void:
	if reduced_animation != enabled:
		reduced_animation = enabled
		_apply_accessibility_settings()

func _apply_accessibility_settings() -> void:
	var settings = {
		"high_contrast": high_contrast_mode,
		"reduced_animation": reduced_animation
	}
	accessibility_changed.emit(settings)

func get_current_theme() -> ThemeVariant:
	return current_theme

func get_current_scale() -> float:
	return current_scale

func is_high_contrast_enabled() -> bool:
	return high_contrast_mode

func is_reduced_animation_enabled() -> bool:
	return reduced_animation

func get_theme_resource() -> Theme:
	return current_theme_resource

func apply_theme_to_control(control: Control) -> void:
	if control and current_theme_resource:
		control.theme = current_theme_resource

func save_settings() -> Dictionary:
	return {
		"theme_variant": current_theme,
		"scale_factor": current_scale,
		"high_contrast": high_contrast_mode,
		"reduced_animation": reduced_animation
	}

func load_settings(settings: Dictionary) -> void:
	if settings.has("theme_variant"):
		set_theme_variant(settings.theme_variant)
	
	if settings.has("scale_factor"):
		set_scale_factor(settings.scale_factor)
	
	if settings.has("high_contrast"):
		set_high_contrast(settings.high_contrast)
	
	if settings.has("reduced_animation"):
		set_reduced_animation(settings.reduced_animation)
