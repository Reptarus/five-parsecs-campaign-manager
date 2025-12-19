@tool
extends Node

## Theme Manager for Five Parsecs Campaign Manager
## Handles theme switching, scaling, and accessibility features
## NOTE: This is an autoload - do not use class_name

const AccessibilityThemesClass = preload("res://src/ui/themes/AccessibilityThemes.gd")

signal theme_changed(theme_name: String)
signal scale_changed(scale_factor: float)
signal accessibility_changed(settings: Dictionary)

enum ThemeVariant {
	DEFAULT,        # Alias for DARK (for compatibility)
	DARK,           # Default deep space theme
	LIGHT,          # Light mode variant
	HIGH_CONTRAST,  # Accessibility high contrast
	COLORBLIND_DEUTERANOPIA,  # Red-green colorblind (most common)
	COLORBLIND_PROTANOPIA,    # Red colorblind (variant)
	COLORBLIND_TRITANOPIA     # Blue-yellow colorblind (rare)
}

const MIN_SCALE_FACTOR: float = 0.8
const MAX_SCALE_FACTOR: float = 2.0
const DEFAULT_SCALE_FACTOR: float = 1.0
const SETTINGS_PATH: String = "user://theme_settings.cfg"

var current_theme: ThemeVariant = ThemeVariant.DARK
var current_scale: float = DEFAULT_SCALE_FACTOR
var high_contrast_mode: bool = false
var reduced_animation: bool = false
var current_theme_resource: Theme

# Theme definitions dictionary
var theme_definitions: Dictionary = {}

# Registered controls for automatic updates
var _registered_controls: Array[Control] = []

func _ready() -> void:
	_load_theme_definitions()
	_load_saved_theme()
	apply_theme(current_theme)

func _load_theme_definitions() -> void:
	"""Load all theme color palettes from AccessibilityThemes"""
	theme_definitions = {
		ThemeVariant.DARK: _get_dark_theme(),
		ThemeVariant.LIGHT: _get_light_theme(),
		ThemeVariant.HIGH_CONTRAST: AccessibilityThemesClass.get_high_contrast(),
		ThemeVariant.COLORBLIND_DEUTERANOPIA: AccessibilityThemesClass.get_deuteranopia(),
		ThemeVariant.COLORBLIND_PROTANOPIA: AccessibilityThemesClass.get_protanopia(),
		ThemeVariant.COLORBLIND_TRITANOPIA: AccessibilityThemesClass.get_tritanopia()
	}

func apply_theme(theme: ThemeVariant) -> void:
	"""Apply a theme variant to all registered controls"""
	if current_theme != theme:
		current_theme = theme
		_apply_theme_variant()
		_save_theme_preference()
		theme_changed.emit(_get_theme_name(theme))

func set_theme_variant(variant: ThemeVariant) -> void:
	"""Alias for apply_theme for backwards compatibility"""
	apply_theme(variant)

func _get_theme_name(variant: ThemeVariant) -> String:
	"""Get human-readable theme name"""
	match variant:
		ThemeVariant.DARK:
			return "Dark (Deep Space)"
		ThemeVariant.LIGHT:
			return "Light"
		ThemeVariant.HIGH_CONTRAST:
			return "High Contrast"
		ThemeVariant.COLORBLIND_DEUTERANOPIA:
			return "Colorblind (Red-Green)"
		ThemeVariant.COLORBLIND_PROTANOPIA:
			return "Colorblind (Red)"
		ThemeVariant.COLORBLIND_TRITANOPIA:
			return "Colorblind (Blue-Yellow)"
		_:
			return "Unknown"

func _apply_theme_variant() -> void:
	"""Apply current theme to all registered controls"""
	_apply_to_all_controls()

func _apply_to_all_controls() -> void:
	"""Update all registered controls with current theme"""
	for control in _registered_controls:
		if is_instance_valid(control):
			_apply_theme_to_control(control)

func _apply_theme_to_control(control: Control) -> void:
	"""Apply theme colors to a specific control"""
	if not is_instance_valid(control):
		return
	
	var theme_colors = theme_definitions.get(current_theme, {})
	
	# Apply colors based on control type
	if control is Label:
		control.add_theme_color_override("font_color", theme_colors.get("text_primary", Color.WHITE))
	elif control is LineEdit:
		control.add_theme_color_override("font_color", theme_colors.get("text_primary", Color.WHITE))
		control.add_theme_color_override("font_placeholder_color", theme_colors.get("text_secondary", Color.GRAY))
	elif control is Button:
		control.add_theme_color_override("font_color", theme_colors.get("text_primary", Color.WHITE))
		control.add_theme_color_override("font_hover_color", theme_colors.get("accent_hover", Color.CYAN))
	elif control is PanelContainer or control is Panel:
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = theme_colors.get("elevated", Color("#252542"))
		style_box.border_color = theme_colors.get("border", Color("#3A3A5C"))
		style_box.border_width_left = 1
		style_box.border_width_top = 1
		style_box.border_width_right = 1
		style_box.border_width_bottom = 1
		control.add_theme_stylebox_override("panel", style_box)

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

# ============ THEME DEFINITIONS ============

func _get_dark_theme() -> Dictionary:
	"""Deep Space theme (default) - matches BaseCampaignPanel constants"""
	return {
		"base": Color("#0a0d14"),           # COLOR_PRIMARY
		"elevated": Color("#111827"),       # COLOR_SECONDARY
		"input": Color("#1f2937"),          # COLOR_TERTIARY
		"border": Color("#374151"),         # COLOR_BORDER
		"accent": Color("#3b82f6"),         # COLOR_BLUE
		"accent_hover": Color("#60a5fa"),   # Lighter blue
		"focus": Color("#60a5fa"),          # Focus ring
		"text_primary": Color("#f3f4f6"),   # Bright white
		"text_secondary": Color("#9ca3af"), # Gray secondary
		"text_disabled": Color("#6b7280"),  # Muted
		"success": Color("#10b981"),        # COLOR_EMERALD
		"warning": Color("#f59e0b"),        # COLOR_AMBER
		"danger": Color("#ef4444")          # COLOR_RED
	}

func _get_light_theme() -> Dictionary:
	"""Light mode variant"""
	return {
		"base": Color("#f5f5f5"),           # Light gray background
		"elevated": Color("#ffffff"),       # White cards
		"input": Color("#ffffff"),          # White inputs
		"border": Color("#e0e0e0"),         # Light border
		"accent": Color("#2563eb"),         # Darker blue for contrast
		"accent_hover": Color("#3b82f6"),   # Medium blue hover
		"focus": Color("#3b82f6"),          # Focus ring
		"text_primary": Color("#1f2937"),   # Dark text
		"text_secondary": Color("#6b7280"), # Gray text
		"text_disabled": Color("#9ca3af"),  # Light gray
		"success": Color("#059669"),        # Darker green
		"warning": Color("#d97706"),        # Darker orange
		"danger": Color("#dc2626")          # Darker red
	}

# Note: High contrast and colorblind themes now loaded from AccessibilityThemes
# Removed duplicate theme definitions - use AccessibilityThemes.get_* instead

# ============ COLOR ACCESSORS ============

func get_color(color_name: String) -> Color:
	"""Get a color from the current theme by name"""
	var theme_colors = theme_definitions.get(current_theme, {})
	return AccessibilityThemesClass.get_color_from_theme(theme_colors, color_name, Color.WHITE)

func get_health_color(health_percent: float) -> Color:
	"""Get color for health bars based on percentage (colorblind-safe)"""
	if health_percent >= 0.7:
		return get_color("health_full")
	elif health_percent >= 0.3:
		return get_color("health_mid")
	else:
		return get_color("health_low")

func get_threat_color(threat_level: String) -> Color:
	"""Get color for threat levels (colorblind-safe)"""
	match threat_level.to_lower():
		"low":
			return get_color("threat_low")
		"medium":
			return get_color("threat_medium")
		"high":
			return get_color("threat_high")
		_:
			return get_color("text_secondary")

func get_equipment_color(equipment_type: String) -> Color:
	"""Get color for equipment types (colorblind-safe)"""
	match equipment_type.to_lower():
		"weapon":
			return get_color("weapon")
		"armor":
			return get_color("armor")
		"gear":
			return get_color("gear")
		_:
			return get_color("accent")

func get_font_size(size_name: String) -> int:
	"""Get font size (scaled by current scale factor)"""
	var base_size := 16  # Default
	
	match size_name:
		"xs": base_size = 11
		"sm": base_size = 14
		"md": base_size = 16
		"lg": base_size = 18
		"xl": base_size = 24
		_: base_size = 16
	
	return int(base_size * current_scale)

# ============ CONTROL REGISTRATION ============

func register_control(control: Control) -> void:
	"""Register a control for automatic theme updates"""
	if control and not _registered_controls.has(control):
		_registered_controls.append(control)
		_apply_theme_to_control(control)

func unregister_control(control: Control) -> void:
	"""Unregister a control from theme updates"""
	_registered_controls.erase(control)

# ============ PERSISTENCE ============

func _save_theme_preference() -> void:
	"""Save current theme settings to disk"""
	var config = ConfigFile.new()
	config.set_value("theme", "variant", current_theme)
	config.set_value("theme", "scale_factor", current_scale)
	config.set_value("theme", "high_contrast", high_contrast_mode)
	config.set_value("theme", "reduced_animation", reduced_animation)
	
	var err = config.save(SETTINGS_PATH)
	if err != OK:
		push_error("ThemeManager: Failed to save theme settings: %d" % err)

func _load_saved_theme() -> void:
	"""Load saved theme settings from disk"""
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	
	if err == OK:
		current_theme = config.get_value("theme", "variant", ThemeVariant.DARK)
		current_scale = config.get_value("theme", "scale_factor", DEFAULT_SCALE_FACTOR)
		high_contrast_mode = config.get_value("theme", "high_contrast", false)
		reduced_animation = config.get_value("theme", "reduced_animation", false)
		print("ThemeManager: Loaded saved theme settings")