extends Window
class_name StoryPointSpendingDialog

## Story Point Spending Dialog - Deep Space Design System
## Allows players to spend story points during campaign turns
## Follows Core Rules p.66-67
##
## Features:
## - Displays current story point balance
## - Shows 5 spending options with availability indicators
## - Disables options based on per-turn limits and point balance
## - Matches campaign wizard panel styling

const StoryPointSystem = preload("res://src/core/systems/StoryPointSystem.gd")

signal option_selected(spend_type: int, details: Dictionary)
signal dialog_cancelled()

# Design System Constants (matching BaseCampaignPanel)
const SPACING_XS := 4
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24
const SPACING_XL := 32

const TOUCH_TARGET_MIN := 48
const TOUCH_TARGET_COMFORT := 56

const FONT_SIZE_XS := 11
const FONT_SIZE_SM := 14
const FONT_SIZE_MD := 16
const FONT_SIZE_LG := 18
const FONT_SIZE_XL := 24

const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_INPUT := Color("#1E1E36")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_ACCENT_HOVER := Color("#3A7199")
const COLOR_FOCUS := Color("#4FC3F7")

const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_TEXT_DISABLED := Color("#404040")

const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER := Color("#DC2626")

# UI References
var balance_label: Label
var option_buttons: Array[Button] = []

# Dialog state
var _current_points: int = 0
var _spending_status: Dictionary = {}

func _ready() -> void:
	title = "Spend Story Point"
	size = Vector2i(550, 700)
	unresizable = false
	transient = true
	exclusive = true

	# Apply Deep Space background
	var window_panel := PanelContainer.new()
	window_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var window_style := StyleBoxFlat.new()
	window_style.bg_color = COLOR_BASE
	window_panel.add_theme_stylebox_override("panel", window_style)
	add_child(window_panel)

	_create_ui()

	close_requested.connect(_on_cancel_pressed)

func _create_ui() -> void:
	# Main margin container with SPACING_XL padding
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", SPACING_XL)
	margin.add_theme_constant_override("margin_right", SPACING_XL)
	margin.add_theme_constant_override("margin_top", SPACING_XL)
	margin.add_theme_constant_override("margin_bottom", SPACING_XL)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_LG)
	margin.add_child(vbox)

	# === HEADER ===
	var header := _create_header()
	vbox.add_child(header)

	# === BALANCE CARD ===
	var balance_card := _create_balance_card()
	vbox.add_child(balance_card)

	# === SPENDING OPTIONS ===
	var options_container := _create_spending_options()
	vbox.add_child(options_container)

	# === CANCEL BUTTON ===
	var cancel_container := _create_cancel_button()
	vbox.add_child(cancel_container)

func _create_header() -> VBoxContainer:
	"""Create dialog header with title and description."""
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", SPACING_SM)

	# Title
	var title_label := Label.new()
	title_label.text = "Spend Story Point"
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	container.add_child(title_label)

	# Description
	var desc := Label.new()
	desc.text = "Story points represent narrative control. Spend them wisely to influence the campaign."
	desc.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(desc)

	return container

func _create_balance_card() -> PanelContainer:
	"""Create styled card showing current story point balance."""
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Card styling with accent border
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_SM)

	# Icon
	var icon := Label.new()
	icon.text = "⭐"
	icon.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	hbox.add_child(icon)

	# Balance text
	balance_label = Label.new()
	balance_label.text = "Current Balance: 0"
	balance_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	balance_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	balance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(balance_label)

	card.add_child(hbox)
	return card

func _create_spending_options() -> VBoxContainer:
	"""Create all 5 spending option buttons."""
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", SPACING_SM)
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Section label
	var label := Label.new()
	label.text = "SPENDING OPTIONS"
	label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	container.add_child(label)

	# Option 1: Roll Twice, Pick One
	var opt1 := _create_option_button(
		StoryPointSystem.SpendType.ROLL_TWICE_PICK_ONE,
		"Roll Twice, Pick One",
		"Roll on any table twice and choose your preferred result",
		"Unlimited uses"
	)
	container.add_child(opt1)
	option_buttons.append(opt1)

	# Option 2: Reroll Result
	var opt2 := _create_option_button(
		StoryPointSystem.SpendType.REROLL_RESULT,
		"Reroll Any Result",
		"Reroll any result (must accept new result)",
		"Unlimited uses"
	)
	container.add_child(opt2)
	option_buttons.append(opt2)

	# Option 3: Get Credits
	var opt3 := _create_option_button(
		StoryPointSystem.SpendType.GET_CREDITS,
		"Get 3 Credits",
		"Instantly gain 3 credits",
		"Once per turn"
	)
	container.add_child(opt3)
	option_buttons.append(opt3)

	# Option 4: Get XP
	var opt4 := _create_option_button(
		StoryPointSystem.SpendType.GET_XP,
		"Get +3 XP",
		"Grant +3 XP to one character",
		"Once per turn"
	)
	container.add_child(opt4)
	option_buttons.append(opt4)

	# Option 5: Extra Action
	var opt5 := _create_option_button(
		StoryPointSystem.SpendType.EXTRA_ACTION,
		"Extra Campaign Action",
		"Take an additional campaign action this turn",
		"Once per turn"
	)
	container.add_child(opt5)
	option_buttons.append(opt5)

	return container

func _create_option_button(spend_type: int, title: String, description: String, limit_text: String) -> PanelContainer:
	"""Create a styled spending option button card."""
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = TOUCH_TARGET_COMFORT + 24

	# Card styling
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_XS)

	# Title row with limit badge
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", SPACING_SM)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)

	# Limit badge
	var limit_badge := _create_limit_badge(limit_text)
	title_row.add_child(limit_badge)

	vbox.add_child(title_row)

	# Description
	var desc := Label.new()
	desc.text = description
	desc.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# Action button
	var button := Button.new()
	button.text = "Spend 1 Story Point"
	button.custom_minimum_size.y = TOUCH_TARGET_MIN
	button.set_meta("spend_type", spend_type)
	button.pressed.connect(_on_option_selected.bind(spend_type))
	_style_action_button(button)
	vbox.add_child(button)

	card.add_child(vbox)
	return card

func _create_limit_badge(limit_text: String) -> PanelContainer:
	"""Create a small badge showing usage limit."""
	var badge := PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BORDER
	style.set_corner_radius_all(4)
	style.set_content_margin_all(SPACING_XS)
	badge.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = limit_text
	label.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	badge.add_child(label)

	return badge

func _style_action_button(button: Button) -> void:
	"""Apply design system styling to action button."""
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ACCENT
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	button.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate()
	hover_style.bg_color = COLOR_ACCENT_HOVER
	button.add_theme_stylebox_override("hover", hover_style)

	var disabled_style := style.duplicate()
	disabled_style.bg_color = COLOR_BORDER
	button.add_theme_stylebox_override("disabled", disabled_style)

	button.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	button.add_theme_color_override("font_disabled_color", COLOR_TEXT_DISABLED)

func _create_cancel_button() -> HBoxContainer:
	"""Create cancel button at bottom of dialog."""
	var container := HBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_END

	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(120, TOUCH_TARGET_MIN)

	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = COLOR_BORDER
	cancel_style.set_corner_radius_all(6)
	cancel_style.set_content_margin_all(SPACING_SM)
	cancel_button.add_theme_stylebox_override("normal", cancel_style)
	cancel_button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	cancel_button.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	cancel_button.pressed.connect(_on_cancel_pressed)
	container.add_child(cancel_button)

	return container

## PUBLIC API

## Show the dialog with current story point balance and spending status
## current_points: Number of story points available
## spending_status: Dictionary with "credits_available", "xp_available", "action_available" keys
func show_dialog(current_points: int, spending_status: Dictionary) -> void:
	_current_points = current_points
	_spending_status = spending_status

	# Update balance display
	balance_label.text = "Current Balance: %d" % current_points

	# Update button availability
	_update_button_states()

	popup_centered()

func _update_button_states() -> void:
	"""Update button enabled/disabled states based on balance and per-turn limits."""
	if option_buttons.is_empty():
		return

	# Unlimited options (indices 0 and 1)
	var has_points := _current_points >= 1
	option_buttons[0].disabled = not has_points  # ROLL_TWICE_PICK_ONE
	option_buttons[1].disabled = not has_points  # REROLL_RESULT

	# Once-per-turn options (indices 2, 3, 4)
	var credits_available: bool = _spending_status.get("credits_available", true)
	var xp_available: bool = _spending_status.get("xp_available", true)
	var action_available: bool = _spending_status.get("action_available", true)

	option_buttons[2].disabled = not (has_points and credits_available)  # GET_CREDITS
	option_buttons[3].disabled = not (has_points and xp_available)       # GET_XP
	option_buttons[4].disabled = not (has_points and action_available)   # EXTRA_ACTION

## SIGNAL HANDLERS

func _on_option_selected(spend_type: int) -> void:
	"""Handle spending option button pressed."""
	var details := {}

	# For GET_XP, we might want to show a character picker
	# For now, emit with empty details - caller can handle character selection
	if spend_type == StoryPointSystem.SpendType.GET_XP:
		details = {"needs_character_selection": true}

	option_selected.emit(spend_type, details)
	hide()

func _on_cancel_pressed() -> void:
	dialog_cancelled.emit()
	hide()
