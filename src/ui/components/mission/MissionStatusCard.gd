extends PanelContainer
class_name MissionStatusCard

## Mission Status Card Component
## Displays current mission info with progress tracking and glass morphism styling
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
const COLOR_BLUE := Color("#3b82f6")
const COLOR_TEXT_PRIMARY := Color("#f3f4f6")
const COLOR_TEXT_SECONDARY := Color("#9ca3af")
const COLOR_AMBER := Color("#f59e0b")

# Signals
signal mission_details_requested()

# UI References
var main_vbox: VBoxContainer
var header_hbox: HBoxContainer
var icon_label: Label
var name_label: Label
var type_label: Label
var progress_bar: ProgressBar
var progress_label: Label
var difficulty_badge: PanelContainer

# Mission data
var mission_name: String = "No Active Mission"
var mission_type: String = ""
var objectives_completed: int = 0
var objectives_total: int = 0
var difficulty_level: int = 1


func _ready() -> void:
	_setup_ui()
	_apply_glass_style()


func _setup_ui() -> void:
	## Build the card UI structure
	# Main container
	main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", SPACING_SM)
	add_child(main_vbox)

	# Header: Icon + Mission Name
	header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", SPACING_SM)
	main_vbox.add_child(header_hbox)

	icon_label = Label.new()
	icon_label.text = "🎯"
	icon_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	icon_label.add_theme_color_override("font_color", COLOR_BLUE)
	header_hbox.add_child(icon_label)

	name_label = Label.new()
	name_label.text = mission_name
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(name_label)

	# Mission Type
	type_label = Label.new()
	type_label.text = mission_type
	type_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	type_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	main_vbox.add_child(type_label)

	# Progress Bar
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 8)
	progress_bar.show_percentage = false
	progress_bar.value = 0
	_style_progress_bar()
	main_vbox.add_child(progress_bar)

	# Progress Label
	progress_label = Label.new()
	progress_label.text = "0 of 0 objectives"
	progress_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	progress_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	main_vbox.add_child(progress_label)

	# Difficulty Badge
	difficulty_badge = _create_difficulty_badge()
	main_vbox.add_child(difficulty_badge)

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


func _style_progress_bar() -> void:
	## Apply styling to progress bar
	# Background
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = COLOR_BORDER
	bg_style.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("background", bg_style)

	# Fill (amber for mission progress)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = COLOR_AMBER
	fill_style.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("fill", fill_style)


func _create_difficulty_badge() -> PanelContainer:
	## Create difficulty indicator with star rating or numeric display
	var badge := PanelContainer.new()

	# Badge styling
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_TERTIARY, 0.6)
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_XS)
	badge.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_XS)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# Difficulty label
	var diff_label := Label.new()
	diff_label.text = "DIFFICULTY"
	diff_label.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	diff_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	hbox.add_child(diff_label)

	# Stars display (visual rating)
	var stars_label := Label.new()
	stars_label.text = _get_difficulty_stars(difficulty_level)
	stars_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	stars_label.add_theme_color_override("font_color", COLOR_AMBER)
	hbox.add_child(stars_label)

	badge.add_child(hbox)
	return badge


func _get_difficulty_stars(level: int) -> String:
	## Convert difficulty level to star representation
	var stars := ""
	for i in range(mini(level, 5)):
		stars += "★"
	return stars if stars else "☆"


func _on_gui_input(event: InputEvent) -> void:
	## Handle click on card to show details
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			mission_details_requested.emit()


## Public API for setting mission data

func set_mission_data(data: Dictionary) -> void:
	## Update card with mission data from MissionIntegrator
	mission_name = data.get("name", "Unknown Mission")
	mission_type = data.get("type_name", "")
	objectives_completed = data.get("objectives_completed", 0)
	objectives_total = data.get("objectives_total", 0)
	difficulty_level = data.get("difficulty", 1)

	_update_display()


func _update_display() -> void:
	## Refresh UI with current data
	if not is_inside_tree():
		return

	name_label.text = mission_name
	type_label.text = mission_type

	# Update progress
	var progress_pct := 0.0
	if objectives_total > 0:
		progress_pct = (float(objectives_completed) / float(objectives_total)) * 100.0
	progress_bar.value = progress_pct

	progress_label.text = "%d of %d objectives" % [objectives_completed, objectives_total]

	# Update difficulty badge
	if difficulty_badge:
		difficulty_badge.queue_free()
	difficulty_badge = _create_difficulty_badge()
	main_vbox.add_child(difficulty_badge)


func clear_mission() -> void:
	## Clear mission data and show empty state
	mission_name = "No Active Mission"
	mission_type = ""
	objectives_completed = 0
	objectives_total = 0
	difficulty_level = 1
	_update_display()
