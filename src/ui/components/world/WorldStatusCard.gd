extends PanelContainer
class_name WorldStatusCard

## World Status Card Component
## Displays current planet info, threat level, and available patrons
## Part of Campaign Dashboard UI modernization (Phase 3b)

# Design constants from BaseCampaignPanel
const SPACING_XS := 4
const SPACING_SM := 8
const SPACING_MD := 16
const FONT_SIZE_XS := 11
const FONT_SIZE_SM := 14
const FONT_SIZE_MD := 16
const FONT_SIZE_LG := 18

# Color palette - Deep Space Theme
const COLOR_SECONDARY := Color("#111827")
const COLOR_TERTIARY := Color("#1f2937")
const COLOR_BORDER := Color("#374151")
const COLOR_EMERALD := Color("#10b981")
const COLOR_AMBER := Color("#f59e0b")
const COLOR_RED := Color("#ef4444")
const COLOR_TEXT_PRIMARY := Color("#f3f4f6")
const COLOR_TEXT_SECONDARY := Color("#9ca3af")

# Signals
signal world_details_requested()

# UI References
var main_vbox: VBoxContainer
var header_hbox: HBoxContainer
var planet_icon: Label
var planet_name_label: Label
var location_type_label: Label
var threat_container: HBoxContainer
var threat_label: Label
var threat_bars_container: HBoxContainer
var patrons_label: Label

# World data
var planet_name: String = "Unknown World"
var location_type: String = ""
var threat_level: int = 1
var patrons_available: int = 0


func _ready() -> void:
	_setup_ui()
	_apply_glass_style()


func _setup_ui() -> void:
	## Build the card UI structure
	# Main container
	main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", SPACING_SM)
	add_child(main_vbox)

	# Header: Planet Icon + Name
	header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", SPACING_SM)
	main_vbox.add_child(header_hbox)

	planet_icon = Label.new()
	planet_icon.text = "🌍"
	planet_icon.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	planet_icon.add_theme_color_override("font_color", COLOR_EMERALD)
	header_hbox.add_child(planet_icon)

	planet_name_label = Label.new()
	planet_name_label.text = planet_name
	planet_name_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	planet_name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	planet_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(planet_name_label)

	# Location Type
	location_type_label = Label.new()
	location_type_label.text = location_type
	location_type_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	location_type_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	main_vbox.add_child(location_type_label)

	# Threat Level Indicator
	threat_container = HBoxContainer.new()
	threat_container.add_theme_constant_override("separation", SPACING_SM)
	main_vbox.add_child(threat_container)

	threat_label = Label.new()
	threat_label.text = "THREAT"
	threat_label.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	threat_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	threat_container.add_child(threat_label)

	threat_bars_container = HBoxContainer.new()
	threat_bars_container.add_theme_constant_override("separation", 2)
	_create_threat_bars()
	threat_container.add_child(threat_bars_container)

	# Patrons Available
	patrons_label = Label.new()
	patrons_label.text = "0 patrons available"
	patrons_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	patrons_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	main_vbox.add_child(patrons_label)

	# Make card clickable
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


func _apply_glass_style() -> void:
	## Apply glass morphism styling to the card
	var style := StyleBoxFlat.new()

	# Semi-transparent background
	style.bg_color = Color(COLOR_SECONDARY.r, COLOR_SECONDARY.g, COLOR_SECONDARY.b, 0.8)

	# Subtle border with transparency
	style.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.5)
	style.set_border_width_all(1)

	# Rounded corners
	style.set_corner_radius_all(16)

	# Padding
	style.set_content_margin_all(SPACING_MD)

	add_theme_stylebox_override("panel", style)


func _create_threat_bars() -> void:
	## Create 5 threat level bars
	# Clear existing bars
	for child in threat_bars_container.get_children():
		child.queue_free()

	# Create 5 bars
	for i in range(5):
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(16, 20)

		# Color based on threat level
		if i < threat_level:
			# Filled bar - color based on intensity
			if threat_level <= 2:
				bar.color = COLOR_EMERALD  # Low threat = green
			elif threat_level <= 3:
				bar.color = COLOR_AMBER    # Medium threat = amber
			else:
				bar.color = COLOR_RED      # High threat = red
		else:
			# Empty bar
			bar.color = Color(COLOR_BORDER, 0.3)

		threat_bars_container.add_child(bar)


func _on_gui_input(event: InputEvent) -> void:
	## Handle click on card to show world details
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			world_details_requested.emit()


## Public API for setting world data

func set_world_data(data: Dictionary) -> void:
	## Update card with world data from WorldPhase/GameState
	planet_name = data.get("name", "Unknown World")
	location_type = data.get("type", "")
	threat_level = data.get("danger_level", 1)
	patrons_available = data.get("patrons_count", 0)

	_update_display()


func _update_display() -> void:
	## Refresh UI with current data
	if not is_inside_tree():
		return

	planet_name_label.text = planet_name
	location_type_label.text = location_type

	# Update threat bars
	_create_threat_bars()

	# Update patrons count
	var patron_text := "%d patron%s available" % [patrons_available, "s" if patrons_available != 1 else ""]
	patrons_label.text = patron_text


func set_threat_level(level: int) -> void:
	## Update threat level (1-5)
	threat_level = clampi(level, 1, 5)
	_create_threat_bars()


func set_patrons_count(count: int) -> void:
	## Update available patrons count
	patrons_available = maxi(count, 0)
	var patron_text := "%d patron%s available" % [patrons_available, "s" if patrons_available != 1 else ""]
	patrons_label.text = patron_text
