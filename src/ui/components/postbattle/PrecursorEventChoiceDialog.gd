extends PanelContainer
class_name PrecursorEventChoiceDialog

## Precursor Event Choice Dialog for Post-Battle Phase
## Allows Precursor crew to choose between two rolled campaign events
## Reference: Core Rules - Precursor Crew Benefit (roll twice, pick one)

# Signals
signal event_selected(choice: int)  # 1 for event1, 2 for event2
signal dialog_closed()

# Design System Constants (from BaseCampaignPanel)
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

# State
var event1: Dictionary = {}
var event2: Dictionary = {}
var selected_choice: int = 0

# UI nodes - created dynamically
var title_label: Label
var description_label: RichTextLabel
var event1_panel: PanelContainer
var event2_panel: PanelContainer
var event1_button: Button
var event2_button: Button
var confirm_button: Button

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	## Create and style the dialog UI programmatically
	# Panel background
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_BASE
	panel_style.border_color = COLOR_FOCUS  # Cyan border for precursor theme
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(SPACING_XL)
	add_theme_stylebox_override("panel", panel_style)

	custom_minimum_size = Vector2(500, 400)

	# Main vertical layout
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_LG)
	add_child(vbox)

	# Title
	title_label = Label.new()
	title_label.text = "PRECURSOR VISION"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	title_label.add_theme_color_override("font_color", COLOR_FOCUS)
	vbox.add_child(title_label)

	# Description
	description_label = RichTextLabel.new()
	description_label.bbcode_enabled = true
	description_label.fit_content = true
	description_label.text = "[center]Your Precursor heritage grants you a glimpse into possible futures.\nChoose which path to walk.[/center]"
	description_label.add_theme_font_size_override("normal_font_size", FONT_SIZE_MD)
	description_label.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(description_label)

	# Event cards container (horizontal)
	var events_hbox := HBoxContainer.new()
	events_hbox.add_theme_constant_override("separation", SPACING_LG)
	events_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(events_hbox)

	# Event 1 card
	event1_panel = _create_event_card(1)
	events_hbox.add_child(event1_panel)

	# Event 2 card
	event2_panel = _create_event_card(2)
	events_hbox.add_child(event2_panel)

	# Confirm button
	confirm_button = Button.new()
	confirm_button.text = "Confirm Choice"
	confirm_button.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	confirm_button.disabled = true
	_style_button(confirm_button, COLOR_ACCENT)
	confirm_button.pressed.connect(_on_confirm_pressed)
	vbox.add_child(confirm_button)

func _create_event_card(event_num: int) -> PanelContainer:
	## Create a styled event card panel
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(200, 200)

	# Card style
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = COLOR_ELEVATED
	card_style.border_color = COLOR_BORDER
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(SPACING_MD)
	card.add_theme_stylebox_override("panel", card_style)

	# Card content
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	card.add_child(vbox)

	# Event number header
	var header := Label.new()
	header.text = "Event %d" % event_num
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	header.add_theme_color_override("font_color", COLOR_ACCENT_HOVER)
	vbox.add_child(header)

	# Event name (will be updated)
	var name_label := Label.new()
	name_label.name = "EventName"
	name_label.text = "---"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)

	# Event description (will be updated)
	var desc_label := RichTextLabel.new()
	desc_label.name = "EventDesc"
	desc_label.bbcode_enabled = true
	desc_label.fit_content = true
	desc_label.text = "[center]No event data[/center]"
	desc_label.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	desc_label.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_label)

	# Select button
	var button := Button.new()
	button.name = "SelectButton"
	button.text = "Select This Event"
	button.custom_minimum_size.y = TOUCH_TARGET_MIN
	button.toggle_mode = true
	_style_toggle_button(button)
	button.toggled.connect(func(toggled_on: bool): _on_event_selected(event_num, toggled_on))
	vbox.add_child(button)

	# Store reference
	if event_num == 1:
		event1_button = button
	else:
		event2_button = button

	return card

func _style_button(button: Button, bg_color: Color) -> void:
	## Apply consistent button styling
	button.custom_minimum_size.y = TOUCH_TARGET_MIN

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = bg_color
	normal_style.set_corner_radius_all(4)
	normal_style.set_content_margin_all(SPACING_MD)
	button.add_theme_stylebox_override("normal", normal_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = COLOR_ACCENT_HOVER
	hover_style.set_corner_radius_all(4)
	hover_style.set_content_margin_all(SPACING_MD)
	button.add_theme_stylebox_override("hover", hover_style)

	var disabled_style := StyleBoxFlat.new()
	disabled_style.bg_color = COLOR_TEXT_DISABLED
	disabled_style.set_corner_radius_all(4)
	disabled_style.set_content_margin_all(SPACING_MD)
	button.add_theme_stylebox_override("disabled", disabled_style)

func _style_toggle_button(button: Button) -> void:
	## Apply toggle button styling for event selection
	button.custom_minimum_size.y = TOUCH_TARGET_MIN

	# Normal (unselected)
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = COLOR_ELEVATED
	normal_style.border_color = COLOR_BORDER
	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.set_corner_radius_all(4)
	normal_style.set_content_margin_all(SPACING_SM)
	button.add_theme_stylebox_override("normal", normal_style)

	# Hover
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = COLOR_INPUT
	hover_style.border_color = COLOR_ACCENT
	hover_style.border_width_left = 1
	hover_style.border_width_top = 1
	hover_style.border_width_right = 1
	hover_style.border_width_bottom = 1
	hover_style.set_corner_radius_all(4)
	hover_style.set_content_margin_all(SPACING_SM)
	button.add_theme_stylebox_override("hover", hover_style)

	# Pressed (selected)
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = COLOR_ACCENT
	pressed_style.border_color = COLOR_FOCUS
	pressed_style.border_width_left = 2
	pressed_style.border_width_top = 2
	pressed_style.border_width_right = 2
	pressed_style.border_width_bottom = 2
	pressed_style.set_corner_radius_all(4)
	pressed_style.set_content_margin_all(SPACING_SM)
	button.add_theme_stylebox_override("pressed", pressed_style)

func setup(event_data_1: Dictionary, event_data_2: Dictionary) -> void:
	## Initialize dialog with two event options
	event1 = event_data_1
	event2 = event_data_2

	_update_event_display(event1_panel, event1)
	_update_event_display(event2_panel, event2)

	# Reset selection state
	selected_choice = 0
	if event1_button:
		event1_button.button_pressed = false
	if event2_button:
		event2_button.button_pressed = false
	if confirm_button:
		confirm_button.disabled = true

func _update_event_display(panel: PanelContainer, event_data: Dictionary) -> void:
	## Update an event card with event data
	var name_label := panel.find_child("EventName", true, false) as Label
	var desc_label := panel.find_child("EventDesc", true, false) as RichTextLabel

	if name_label:
		var event_name: String = event_data.get("name", "Unknown Event")
		name_label.text = event_name

	if desc_label:
		var description: String = event_data.get("description", "No description available.")
		var effect: String = event_data.get("effect", "")

		var display_text := "[center]%s[/center]" % description
		if not effect.is_empty():
			display_text += "\n\n[color=#4FC3F7]Effect:[/color] %s" % effect

		desc_label.text = display_text

func _on_event_selected(event_num: int, toggled_on: bool) -> void:
	## Handle event selection toggle
	if toggled_on:
		selected_choice = event_num

		# Deselect the other button
		if event_num == 1 and event2_button:
			event2_button.button_pressed = false
		elif event_num == 2 and event1_button:
			event1_button.button_pressed = false

		# Enable confirm button
		if confirm_button:
			confirm_button.disabled = false
	else:
		# If toggling off the currently selected option
		if selected_choice == event_num:
			selected_choice = 0
			if confirm_button:
				confirm_button.disabled = true

func _on_confirm_pressed() -> void:
	## Handle confirm button press
	if selected_choice > 0:
		event_selected.emit(selected_choice)
		dialog_closed.emit()
		queue_free()

## Public method to show the dialog
func show_choice(event_data_1: Dictionary, event_data_2: Dictionary) -> void:
	## Show the dialog with two event options (convenience method)
	setup(event_data_1, event_data_2)
	show()
