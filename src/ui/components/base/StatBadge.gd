class_name StatBadge
extends PanelContainer

## Reusable Stat Badge Component for Five Parsecs Campaign Manager
## Displays a stat name + value in a compact, touch-friendly badge format.
## Used across 10+ screens: crew roster, battle HUD, ship upgrades, all campaign panels.
##
## ACCESSIBILITY FEATURES:
## - Uses ThemeManager for colorblind-safe colors
## - Automatically adapts to high contrast mode
## - Color-independent stat display (text + icons)
##
## Visual Design:
## - 80x64px minimum size (comfortable readability)
## - Rounded panel (8px corners), semi-transparent background
## - Vertical stack: stat name (uppercase) above value
## - Optional '+' sign for positive values (combat bonuses, etc.)
##
## Usage Example:
##     var badge = StatBadge.new()
##     badge.stat_name = "Combat"
##     badge.stat_value = 5
##     badge.show_plus = true  # Shows "+5"
##     badge.use_theme_color("success")  # Colorblind-safe green
##     add_child(badge)

# ============ DESIGN SYSTEM CONSTANTS ============
# Spacing and typography from BaseCampaignPanel

const SPACING_XS := 4
const SPACING_SM := 8
const FONT_SIZE_XS := 11
const FONT_SIZE_SM := 14

# Default colors (fallback if ThemeManager not available)
const COLOR_INPUT := Color("#1E1E36")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_TEXT_SECONDARY := Color("#808080")

# ============ PUBLIC PROPERTIES ============

## Stat name (displayed uppercase above value)
var stat_name: String = "STAT":
	set(value):
		stat_name = value
		_update_display()

## Stat value (numeric or string)
var stat_value: Variant = 0:
	set(value):
		stat_value = value
		_update_display()

## Show '+' sign for positive values (e.g., "+5" instead of "5")
var show_plus: bool = false:
	set(value):
		show_plus = value
		_update_display()

## Optional accent color override for stat value (defaults to COLOR_ACCENT)
var accent_color: Color = COLOR_ACCENT:
	set(value):
		accent_color = value
		_use_custom_color = true
		_update_display()

## Use theme color name instead of custom color (colorblind-safe)
var theme_color_name: String = "":
	set(value):
		theme_color_name = value
		_use_custom_color = false
		_update_display()

# ============ PRIVATE VARIABLES ============

var _name_label: Label
var _value_label: Label
var _is_ready: bool = false
var _use_custom_color: bool = false
var _theme_manager: ThemeManager = null

# ============ LIFECYCLE METHODS ============

func _ready() -> void:
	_find_theme_manager()
	_setup_ui()
	_is_ready = true
	_update_display()
	print("StatBadge: Initialized with stat '%s' = %s (theme-aware: %s)" % [stat_name, stat_value, _theme_manager != null])

func _find_theme_manager() -> void:
	## Find ThemeManager in scene tree if available
	# Try to find ThemeManager autoload
	if Engine.has_singleton("ThemeManager"):
		_theme_manager = Engine.get_singleton("ThemeManager")
	elif get_node_or_null("/root/ThemeManager"):
		_theme_manager = get_node("/root/ThemeManager")
	else:
		push_warning("StatBadge: ThemeManager not found, using fallback colors")

# ============ UI SETUP ============

func _setup_ui() -> void:
	## Create panel styling and label hierarchy
	# === PANEL STYLING ===
	custom_minimum_size = Vector2(80, 64)  # Touch-friendly minimum
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_INPUT, 0.5)  # Semi-transparent background
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)  # Rounded corners
	style.set_content_margin_all(SPACING_SM)  # 8px padding
	add_theme_stylebox_override("panel", style)
	
	# === VERTICAL LAYOUT ===
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", SPACING_XS)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)
	
	# === STAT NAME LABEL (TOP) ===
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	_name_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(_name_label)
	
	# === STAT VALUE LABEL (BOTTOM) ===
	_value_label = Label.new()
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_value_label.add_theme_color_override("font_color", COLOR_ACCENT)
	vbox.add_child(_value_label)

# ============ UPDATE METHODS ============

func _update_display() -> void:
	## Refresh label text when properties change
	if not _is_ready:
		return
	
	# Update stat name (uppercase)
	if _name_label:
		_name_label.text = stat_name.to_upper()
	
	# Update stat value with optional '+' sign
	if _value_label:
		var value_text := _format_value(stat_value)
		_value_label.text = value_text
		
		# Use theme color if specified, otherwise use custom accent_color
		var display_color: Color
		if not _use_custom_color and theme_color_name != "" and _theme_manager:
			display_color = _theme_manager.get_color(theme_color_name)
		else:
			display_color = accent_color
		
		_value_label.add_theme_color_override("font_color", display_color)

func _format_value(value: Variant) -> String:
	## Format value with optional '+' sign for positive numbers
	var value_str := str(value)
	
	# If show_plus enabled and value is a positive number
	if show_plus:
		if value is int or value is float:
			if value > 0:
				return "+" + value_str
			else:
				return value_str
		# String values: check if first char is digit
		elif value_str.length() > 0 and value_str[0].is_valid_int():
			var num_val := value_str.to_int()
			if num_val > 0:
				return "+" + value_str
	
	return value_str

# ============ PUBLIC UTILITY METHODS ============

## Convenience method to set all properties at once
func configure(stat: String, value: Variant, plus: bool = false, color: Color = COLOR_ACCENT) -> void:
	stat_name = stat
	stat_value = value
	show_plus = plus
	accent_color = color
	print("StatBadge: Configured - %s: %s (show_plus: %s)" % [stat, value, plus])

## Set badge to use theme color (colorblind-safe)
func use_theme_color(color_name: String) -> void:
	## Use a theme color name instead of custom color (e.g., 'success', 'danger', 'warning')
	theme_color_name = color_name
	_use_custom_color = false
	_update_display()

## Convenience method for health display (colorblind-safe)
func configure_health(current_health: int, max_health: int) -> void:
	## Configure badge for health display with colorblind-safe colors
	stat_name = "Health"
	stat_value = "%d/%d" % [current_health, max_health]
	
	# Calculate health percentage and use appropriate theme color
	var health_percent := float(current_health) / float(max_health) if max_health > 0 else 0.0
	if health_percent >= 0.7:
		use_theme_color("health_full")
	elif health_percent >= 0.3:
		use_theme_color("health_mid")
	else:
		use_theme_color("health_low")

## Convenience method for status display (success/warning/danger)
func configure_status(stat: String, value: Variant, status: String) -> void:
	## Configure badge with semantic status color (success/warning/danger)
	stat_name = stat
	stat_value = value
	use_theme_color(status)  # "success", "warning", or "danger"
