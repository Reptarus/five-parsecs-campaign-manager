extends PanelContainer
class_name CommercialPassagePanel

## Commercial Passage Panel
## Displayed when player has no ship - book passage on commercial transport
## Design: Modern UI theme with destination selection

signal passage_booked(destination: String)

# Design system constants
const SPACING_XS := 4
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24
const TOUCH_TARGET_MIN := 48
const FONT_SIZE_XS := 11
const FONT_SIZE_SM := 14
const FONT_SIZE_MD := 16
const FONT_SIZE_LG := 18
const FONT_SIZE_XL := 24

# Colors
const COLOR_SECONDARY := Color("#111827")
const COLOR_TERTIARY := Color("#1f2937")
const COLOR_BORDER := Color("#374151")
const COLOR_ACCENT := Color("#3b82f6")
const COLOR_WARNING := Color("#f59e0b")
const COLOR_TEXT_PRIMARY := Color("#f3f4f6")
const COLOR_TEXT_SECONDARY := Color("#9ca3af")

# Constants
const COST_PER_PERSON := 10

# UI References
@onready var crew_count_label: Label = $VBox/CrewCost/CrewLabel
@onready var total_cost_label: Label = $VBox/CrewCost/TotalLabel
@onready var destination_select: OptionButton = $VBox/DestinationSelect
@onready var book_button: Button = $VBox/BookButton

# State
var crew_size: int = 1
var available_destinations: Array[String] = [
	"Fringe World",
	"Industrial Hub",
	"Trading Station",
	"Frontier Colony",
	"Research Outpost"
]


func _ready() -> void:
	_setup_ui()
	_populate_destinations()
	_connect_signals()
	update_cost_display()


func _setup_ui() -> void:
	"""Setup panel styling"""
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_SECONDARY.r, COLOR_SECONDARY.g, COLOR_SECONDARY.b, 0.8)
	style.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(SPACING_LG)
	add_theme_stylebox_override("panel", style)

	# Style destination selector
	_style_option_button(destination_select)

	# Style book button
	_style_book_button()


func _style_option_button(option_btn: OptionButton) -> void:
	"""Apply styling to option button"""
	option_btn.custom_minimum_size.y = TOUCH_TARGET_MIN

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_TERTIARY
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	option_btn.add_theme_stylebox_override("normal", style)

	option_btn.add_theme_font_size_override("font_size", FONT_SIZE_MD)


func _style_book_button() -> void:
	"""Apply primary button styling"""
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ACCENT
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	book_button.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate()
	hover_style.bg_color = Color(COLOR_ACCENT.r * 1.2, COLOR_ACCENT.g * 1.2, COLOR_ACCENT.b * 1.2)
	book_button.add_theme_stylebox_override("hover", hover_style)

	book_button.add_theme_font_size_override("font_size", FONT_SIZE_MD)


func _populate_destinations() -> void:
	"""Populate destination dropdown"""
	destination_select.clear()
	for destination in available_destinations:
		destination_select.add_item(destination)


func _connect_signals() -> void:
	"""Connect signals"""
	book_button.pressed.connect(_on_book_button_pressed)


func set_crew_size(size: int) -> void:
	"""Update crew size and recalculate costs"""
	crew_size = max(1, size)
	update_cost_display()


func set_available_destinations(destinations: Array) -> void:
	"""Update available destinations"""
	available_destinations = destinations
	_populate_destinations()


func update_cost_display() -> void:
	"""Update cost labels"""
	var total_cost := crew_size * COST_PER_PERSON

	crew_count_label.text = "Cost per person: %d credits" % COST_PER_PERSON
	total_cost_label.text = "Crew: %d = %d credits total" % [crew_size, total_cost]


func get_total_cost() -> int:
	"""Get total passage cost"""
	return crew_size * COST_PER_PERSON


func _on_book_button_pressed() -> void:
	"""Handle book passage button"""
	if destination_select.selected < 0:
		return

	var destination := destination_select.get_item_text(destination_select.selected)
	passage_booked.emit(destination)
