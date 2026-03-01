extends PanelContainer
class_name ShipDamageStatusPanel

## Ship Damage Status Panel
## Displays ship hull integrity, damage state, and repair cost
## Design: Modern UI theme with glass morphism styling

signal repair_requested()

# Design system constants (from BaseCampaignPanel)
const SPACING_XS := 4
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24
const FONT_SIZE_XS := 11
const FONT_SIZE_SM := 14
const FONT_SIZE_MD := 16
const FONT_SIZE_LG := 18

# Colors
const COLOR_SECONDARY := Color("#111827")
const COLOR_TERTIARY := Color("#1f2937")
const COLOR_BORDER := Color("#374151")
const COLOR_SUCCESS := Color("#10b981")
const COLOR_WARNING := Color("#f59e0b")
const COLOR_DANGER := Color("#ef4444")
const COLOR_TEXT_PRIMARY := Color("#f3f4f6")
const COLOR_TEXT_SECONDARY := Color("#9ca3af")

# UI References
@onready var damage_state_label: Label = $VBox/Header/StateLabel
@onready var hull_bar: ProgressBar = $VBox/HullBar
@onready var hull_text_label: Label = $VBox/Stats/HullLabel
@onready var repair_cost_label: Label = $VBox/Stats/RepairLabel
@onready var critical_warning: PanelContainer = $VBox/CriticalWarning

# Ship data
var current_hull: int = 100
var max_hull: int = 100
var repair_cost_per_point: int = 5


func _ready() -> void:
	_setup_ui()
	update_display(current_hull, max_hull)


func _setup_ui() -> void:
	## Setup panel styling
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_SECONDARY.r, COLOR_SECONDARY.g, COLOR_SECONDARY.b, 0.8)
	style.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(SPACING_LG)
	add_theme_stylebox_override("panel", style)


func update_display(hull: int, max_hull_value: int) -> void:
	## Update UI to reflect current ship status
	current_hull = hull
	max_hull = max_hull_value

	var hull_percent := (float(current_hull) / float(max_hull)) * 100.0

	# Update hull bar
	hull_bar.value = hull_percent
	_update_hull_bar_color(hull_percent)

	# Update damage state text
	var state_text := _get_damage_state_text(hull_percent)
	damage_state_label.text = state_text
	_update_state_label_color(hull_percent)

	# Update stats
	hull_text_label.text = "Hull: %d/%d" % [current_hull, max_hull]

	var hull_damage := max_hull - current_hull
	var total_repair_cost := hull_damage * repair_cost_per_point
	repair_cost_label.text = "Repair Cost: %d credits" % total_repair_cost

	# Show/hide critical warning
	if critical_warning:
		critical_warning.visible = hull_percent <= 25.0


func _get_damage_state_text(hull_percent: float) -> String:
	## Get damage state description based on hull percentage
	if hull_percent <= 0.0:
		return "DESTROYED"
	elif hull_percent <= 25.0:
		return "CRITICAL"
	elif hull_percent <= 50.0:
		return "DAMAGED"
	elif hull_percent <= 75.0:
		return "MINOR DAMAGE"
	else:
		return "OPERATIONAL"


func _update_hull_bar_color(hull_percent: float) -> void:
	## Update progress bar color based on damage level
	var fill_style := StyleBoxFlat.new()

	if hull_percent <= 25.0:
		fill_style.bg_color = COLOR_DANGER
	elif hull_percent <= 50.0:
		fill_style.bg_color = COLOR_WARNING
	else:
		fill_style.bg_color = COLOR_SUCCESS

	fill_style.set_corner_radius_all(4)
	hull_bar.add_theme_stylebox_override("fill", fill_style)


func _update_state_label_color(hull_percent: float) -> void:
	## Update state label color based on damage level
	var color: Color

	if hull_percent <= 25.0:
		color = COLOR_DANGER
	elif hull_percent <= 50.0:
		color = COLOR_WARNING
	else:
		color = COLOR_SUCCESS

	damage_state_label.add_theme_color_override("font_color", color)


func set_repair_cost_per_point(cost: int) -> void:
	## Set the repair cost per hull point
	repair_cost_per_point = cost
	update_display(current_hull, max_hull)


func _on_repair_button_pressed() -> void:
	## Handle repair button click
	repair_requested.emit()
