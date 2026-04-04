extends PanelContainer
class_name AccessibilitySettingsPanel

## Accessibility Settings Panel for Five Parsecs Campaign Manager
## Allows users to select visual accessibility themes:
## - High Contrast (for low vision)
## - Deuteranopia (red-green colorblind - most common)
## - Protanopia (red colorblind)
## - Tritanopia (blue-yellow colorblind - rare)

signal theme_selected(theme_variant: ThemeManager.ThemeVariant)

# UI References
var _theme_option_button: OptionButton
var _preview_container: VBoxContainer
var _description_label: Label
var _apply_button: Button

# Theme manager reference
var _theme_manager: ThemeManager

func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base

func _ready() -> void:
	_find_theme_manager()
	_setup_ui()
	_populate_theme_options()
	_create_preview_badges()

func _find_theme_manager() -> void:
	## Find ThemeManager in scene tree
	if get_node_or_null("/root/ThemeManager"):
		_theme_manager = get_node("/root/ThemeManager")
	else:
		push_warning("AccessibilitySettingsPanel: ThemeManager not found")

func _setup_ui() -> void:
	## Create accessibility settings UI
	custom_minimum_size = Vector2(600, 400)

	# Main container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Accessibility Settings"
	title.add_theme_font_size_override("font_size", _scaled_font(24))
	vbox.add_child(title)

	# Theme selection
	var theme_label = Label.new()
	theme_label.text = "Visual Theme:"
	vbox.add_child(theme_label)

	_theme_option_button = OptionButton.new()
	_theme_option_button.custom_minimum_size = Vector2(400, 48)
	_theme_option_button.item_selected.connect(_on_theme_selected)
	vbox.add_child(_theme_option_button)

	# Description
	_description_label = Label.new()
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.custom_minimum_size.y = 60
	vbox.add_child(_description_label)

	# Preview section
	var preview_title = Label.new()
	preview_title.text = "Color Preview:"
	preview_title.add_theme_font_size_override("font_size", _scaled_font(18))
	vbox.add_child(preview_title)

	_preview_container = VBoxContainer.new()
	_preview_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_preview_container)

	# Apply button
	_apply_button = Button.new()
	_apply_button.text = "Apply Theme"
	_apply_button.custom_minimum_size = Vector2(200, 56)
	_apply_button.pressed.connect(_on_apply_pressed)
	vbox.add_child(_apply_button)

func _populate_theme_options() -> void:
	## Add all available themes to dropdown
	_theme_option_button.add_item("Dark (Default)", ThemeManager.ThemeVariant.DARK)
	_theme_option_button.add_item("Light", ThemeManager.ThemeVariant.LIGHT)
	_theme_option_button.add_item("High Contrast", ThemeManager.ThemeVariant.HIGH_CONTRAST)
	_theme_option_button.add_item("Colorblind: Red-Green (Deuteranopia)", ThemeManager.ThemeVariant.COLORBLIND_DEUTERANOPIA)
	_theme_option_button.add_item("Colorblind: Red (Protanopia)", ThemeManager.ThemeVariant.COLORBLIND_PROTANOPIA)
	_theme_option_button.add_item("Colorblind: Blue-Yellow (Tritanopia)", ThemeManager.ThemeVariant.COLORBLIND_TRITANOPIA)

	# Set current theme if ThemeManager available
	if _theme_manager:
		var current: int = int(_theme_manager.get_theme_variant())
		_theme_option_button.select(current)
		_update_preview(current)

func _create_preview_badges() -> void:
	## Create preview badges showing theme colors
	# This will be populated when theme is selected
	pass

func _on_theme_selected(index: int) -> void:
	## Handle theme selection from dropdown
	var theme_variant = _theme_option_button.get_item_id(index)
	_update_preview(theme_variant)

func _update_preview(theme_variant: ThemeManager.ThemeVariant) -> void:
	## Update preview with selected theme colors
	# Clear existing preview
	for child in _preview_container.get_children():
		child.queue_free()

	# Get theme description via static AccessibilityThemes helper
	var theme_name: String = _get_theme_name_from_variant(theme_variant)
	_description_label.text = AccessibilityThemes.get_theme_description(theme_name)

	# Get theme colors
	var colors: Dictionary
	match theme_variant:
		ThemeManager.ThemeVariant.HIGH_CONTRAST:
			colors = AccessibilityThemes.get_high_contrast()
		ThemeManager.ThemeVariant.COLORBLIND_DEUTERANOPIA:
			colors = AccessibilityThemes.get_deuteranopia()
		ThemeManager.ThemeVariant.COLORBLIND_PROTANOPIA:
			colors = AccessibilityThemes.get_protanopia()
		ThemeManager.ThemeVariant.COLORBLIND_TRITANOPIA:
			colors = AccessibilityThemes.get_tritanopia()
		_:
			# Default/Light themes use standard colors
			_create_standard_preview()
			return

	# Create preview grid
	_create_color_preview_grid(colors)

func _create_color_preview_grid(colors: Dictionary) -> void:
	## Create grid of color swatches with labels
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	_preview_container.add_child(grid)

	# Show key colors
	var preview_colors = [
		"success", "warning", "danger",
		"health_full", "health_mid", "health_low"
	]

	for color_key in preview_colors:
		if colors.has(color_key):
			var swatch = _create_color_swatch(color_key, colors[color_key])
			grid.add_child(swatch)

func _create_color_swatch(name: String, color: Color) -> PanelContainer:
	## Create a color swatch with label
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 60)

	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(2)
	style.border_color = Color.WHITE
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = name.capitalize()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Use contrasting text color
	var luminance = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	label.add_theme_color_override("font_color", Color.BLACK if luminance > 0.5 else Color.WHITE)

	panel.add_child(label)
	return panel

func _create_standard_preview() -> void:
	## Create preview for standard (non-accessibility) themes
	var info = Label.new()
	info.text = "Standard theme - no accessibility adjustments"
	info.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	_preview_container.add_child(info)

func _get_theme_name_from_variant(variant: ThemeManager.ThemeVariant) -> String:
	## Convert theme variant to accessibility theme name
	match variant:
		ThemeManager.ThemeVariant.HIGH_CONTRAST:
			return "high_contrast"
		ThemeManager.ThemeVariant.COLORBLIND_DEUTERANOPIA:
			return "deuteranopia"
		ThemeManager.ThemeVariant.COLORBLIND_PROTANOPIA:
			return "protanopia"
		ThemeManager.ThemeVariant.COLORBLIND_TRITANOPIA:
			return "tritanopia"
		_:
			return "dark"

func _on_apply_pressed() -> void:
	## Apply selected theme
	var selected_index = _theme_option_button.selected
	var theme_variant = _theme_option_button.get_item_id(selected_index)

	if _theme_manager and _theme_manager.has_method("set_theme_variant"):
		_theme_manager.set_theme_variant(theme_variant)

	theme_selected.emit(theme_variant)
