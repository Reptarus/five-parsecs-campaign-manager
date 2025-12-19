extends PopupPanel
class_name ShipPurchaseDialog

## Ship Purchase Dialog
## Modal for purchasing new ships with loan options
## Design: Modern UI theme with ship type selection

signal ship_purchased(ship_data: Dictionary)
signal dialog_cancelled()

# Design system constants
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24
const TOUCH_TARGET_MIN := 48
const FONT_SIZE_SM := 14
const FONT_SIZE_MD := 16
const FONT_SIZE_LG := 18
const FONT_SIZE_XL := 24

# Colors
const COLOR_PRIMARY := Color("#0a0d14")
const COLOR_SECONDARY := Color("#111827")
const COLOR_TERTIARY := Color("#1f2937")
const COLOR_BORDER := Color("#374151")
const COLOR_ACCENT := Color("#3b82f6")
const COLOR_SUCCESS := Color("#10b981")
const COLOR_WARNING := Color("#f59e0b")
const COLOR_DANGER := Color("#ef4444")
const COLOR_TEXT_PRIMARY := Color("#f3f4f6")
const COLOR_TEXT_SECONDARY := Color("#9ca3af")

# UI References
@onready var credits_label: Label = $Panel/VBox/CreditsLabel
@onready var ship_list: VBoxContainer = $Panel/VBox/ShipScroll/ShipList
@onready var loan_checkbox: CheckBox = $Panel/VBox/LoanCheck
@onready var cancel_button: Button = $Panel/VBox/Buttons/CancelButton
@onready var purchase_button: Button = $Panel/VBox/Buttons/PurchaseButton

# Ship types from Five Parsecs
const SHIP_TYPES := [
	{
		"name": "Worn Freighter",
		"cost": 200,
		"hull": 80,
		"description": "Basic transport vessel, seen better days"
	},
	{
		"name": "Standard Transport",
		"cost": 400,
		"hull": 100,
		"description": "Reliable balanced ship for small crews"
	},
	{
		"name": "Armed Trader",
		"cost": 600,
		"hull": 100,
		"description": "Equipped with defensive weapons"
	},
	{
		"name": "Fast Courier",
		"cost": 500,
		"hull": 80,
		"description": "High speed, lower armor"
	}
]

# State
var player_credits: int = 0
var selected_ship: Dictionary = {}
var selected_ship_card: PanelContainer = null


func _ready() -> void:
	_setup_ui()
	_populate_ship_list()
	_connect_signals()
	purchase_button.disabled = true


func _setup_ui() -> void:
	"""Setup dialog styling"""
	size = Vector2(600, 500)

	# Panel background
	var panel = $Panel
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SECONDARY
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(SPACING_LG)
	panel.add_theme_stylebox_override("panel", style)


func _populate_ship_list() -> void:
	"""Create ship option cards"""
	for child in ship_list.get_children():
		child.queue_free()

	for ship_type in SHIP_TYPES:
		var card := _create_ship_card(ship_type)
		ship_list.add_child(card)


func _create_ship_card(ship_data: Dictionary) -> PanelContainer:
	"""Create a selectable ship option card"""
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)

	# Style
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_TERTIARY
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)

	# Header row: name + cost
	var header := HBoxContainer.new()

	var name_label := Label.new()
	name_label.text = ship_data.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	header.add_child(name_label)

	var cost_label := Label.new()
	cost_label.text = "%d CR" % ship_data.cost
	cost_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	cost_label.add_theme_color_override("font_color", COLOR_WARNING)
	header.add_child(cost_label)

	vbox.add_child(header)

	# Stats row
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", SPACING_MD)

	var hull_badge := _create_stat_badge("Hull", ship_data.hull)
	stats.add_child(hull_badge)

	vbox.add_child(stats)

	# Description
	var desc_label := Label.new()
	desc_label.text = ship_data.description
	desc_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	desc_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	panel.add_child(vbox)

	# Make clickable
	panel.gui_input.connect(_on_ship_card_clicked.bind(panel, ship_data))
	panel.mouse_entered.connect(_on_ship_card_hover.bind(panel, true))
	panel.mouse_exited.connect(_on_ship_card_hover.bind(panel, false))

	return panel


func _create_stat_badge(stat_name: String, value: Variant) -> PanelContainer:
	"""Create compact stat badge"""
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(80, 32)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_PRIMARY, 0.6)
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var name_label := Label.new()
	name_label.text = stat_name.to_upper()
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	hbox.add_child(name_label)

	var value_label := Label.new()
	value_label.text = str(value)
	value_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	value_label.add_theme_color_override("font_color", COLOR_ACCENT)
	hbox.add_child(value_label)

	panel.add_child(hbox)
	return panel


func _on_ship_card_clicked(event: InputEvent, card: PanelContainer, ship_data: Dictionary) -> void:
	"""Handle ship card selection"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_ship(card, ship_data)


func _on_ship_card_hover(card: PanelContainer, is_hovering: bool) -> void:
	"""Visual feedback on hover"""
	if card == selected_ship_card:
		return

	var style := card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if is_hovering:
		style.border_color = COLOR_ACCENT
		style.set_border_width_all(2)
	else:
		style.border_color = COLOR_BORDER
		style.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", style)


func _select_ship(card: PanelContainer, ship_data: Dictionary) -> void:
	"""Select a ship for purchase"""
	# Deselect previous
	if selected_ship_card:
		var old_style := selected_ship_card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		old_style.border_color = COLOR_BORDER
		old_style.set_border_width_all(1)
		selected_ship_card.add_theme_stylebox_override("panel", old_style)

	# Select new
	selected_ship = ship_data
	selected_ship_card = card

	var style := card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = COLOR_SUCCESS
	style.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", style)

	# Enable purchase button if affordable (or loan is checked)
	var can_afford: bool = player_credits >= ship_data.cost
	purchase_button.disabled = not (can_afford or loan_checkbox.button_pressed)


func _connect_signals() -> void:
	"""Connect button signals"""
	cancel_button.pressed.connect(_on_cancel_pressed)
	purchase_button.pressed.connect(_on_purchase_pressed)
	loan_checkbox.toggled.connect(_on_loan_toggled)


func _on_cancel_pressed() -> void:
	"""Handle cancel"""
	dialog_cancelled.emit()
	hide()


func _on_purchase_pressed() -> void:
	"""Handle purchase"""
	if selected_ship.is_empty():
		return

	var purchase_data := selected_ship.duplicate()
	purchase_data["used_loan"] = loan_checkbox.button_pressed

	ship_purchased.emit(purchase_data)
	hide()


func _on_loan_toggled(pressed: bool) -> void:
	"""Handle loan checkbox toggle"""
	if selected_ship.is_empty():
		return

	var can_afford: bool = player_credits >= selected_ship.cost
	purchase_button.disabled = not (can_afford or pressed)


func show_dialog(credits: int) -> void:
	"""Show dialog with player's current credits"""
	player_credits = credits
	credits_label.text = "Credits: %d" % credits

	# Reset selection
	selected_ship = {}
	selected_ship_card = null
	purchase_button.disabled = true
	loan_checkbox.button_pressed = false

	popup_centered()
