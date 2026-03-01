extends PanelContainer
class_name NarrativeInjuryDialog

## Narrative Injury Selection Dialog for Post-Battle Phase
## Implements narrative_injuries house rule - player chooses injury type
## Reference: House Rules - Five Parsecs Campaign Manager
##
## When narrative_injuries house rule is enabled, players can choose which injury
## type to apply instead of rolling on the injury table. Fatal injuries are excluded.

# Signals
signal injury_selected(injury_data: Dictionary)
signal dialog_closed()

# Dependencies
const InjurySystemService = preload("res://src/core/services/InjurySystemService.gd")

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

# Severity colors
const COLOR_MIRACULOUS := Color("#10B981")  # Green - best outcome
const COLOR_MINOR := Color("#D97706")  # Orange - minor issues
const COLOR_SERIOUS := Color("#DC2626")  # Red - serious
const COLOR_CRIPPLING := Color("#991B1B")  # Dark red - severe

# State
var character_name: String = "Unknown"
var selected_injury_type: int = -1
var available_injuries: Array[Dictionary] = []

# Node references (created dynamically)
var title_label: Label
var description_label: Label
var injury_list: VBoxContainer
var confirm_button: Button
var cancel_button: Button
var injury_details_label: RichTextLabel
var _injury_button_group: ButtonGroup = null

func _ready() -> void:
	_setup_panel_style()
	_build_layout()
	_load_injury_options()
	_update_ui_state()

func _setup_panel_style() -> void:
	## Apply panel styling using design system
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_BASE
	panel_style.border_color = COLOR_BORDER
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(SPACING_XL)
	add_theme_stylebox_override("panel", panel_style)

	custom_minimum_size = Vector2(450, 500)

func _build_layout() -> void:
	## Build the dialog layout programmatically
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", SPACING_LG)
	add_child(main_vbox)

	# Title
	title_label = Label.new()
	title_label.text = "Narrative Injury Selection"
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title_label)

	# Character name subtitle
	description_label = Label.new()
	description_label.text = "Choose an injury for %s" % character_name
	description_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	description_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(description_label)

	# House rule explanation
	var house_rule_label := Label.new()
	house_rule_label.text = "House Rule: Narrative Injuries - You decide the outcome!"
	house_rule_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	house_rule_label.add_theme_color_override("font_color", COLOR_FOCUS)
	house_rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(house_rule_label)

	# Separator
	var separator := HSeparator.new()
	main_vbox.add_child(separator)

	# Scroll container for injury options
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	# Injury list
	injury_list = VBoxContainer.new()
	injury_list.add_theme_constant_override("separation", SPACING_SM)
	scroll.add_child(injury_list)

	# Selected injury details panel
	var details_panel := PanelContainer.new()
	var details_style := StyleBoxFlat.new()
	details_style.bg_color = COLOR_ELEVATED
	details_style.border_color = COLOR_BORDER
	details_style.set_border_width_all(1)
	details_style.set_corner_radius_all(4)
	details_style.set_content_margin_all(SPACING_MD)
	details_panel.add_theme_stylebox_override("panel", details_style)
	main_vbox.add_child(details_panel)

	injury_details_label = RichTextLabel.new()
	injury_details_label.bbcode_enabled = true
	injury_details_label.custom_minimum_size.y = 80
	injury_details_label.fit_content = true
	injury_details_label.text = "[i]Select an injury to see details...[/i]"
	details_panel.add_child(injury_details_label)

	# Button row
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", SPACING_MD)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(button_row)

	# Cancel button
	cancel_button = Button.new()
	cancel_button.text = "Cancel (Roll Instead)"
	cancel_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	_style_button(cancel_button, COLOR_ELEVATED)
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_row.add_child(cancel_button)

	# Confirm button
	confirm_button = Button.new()
	confirm_button.text = "Apply Injury"
	confirm_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	_style_button(confirm_button, COLOR_ACCENT)
	confirm_button.pressed.connect(_on_confirm_pressed)
	confirm_button.disabled = true
	button_row.add_child(confirm_button)

func _style_button(button: Button, bg_color: Color) -> void:
	## Apply consistent button styling
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

func _load_injury_options() -> void:
	## Load available injury options from InjurySystemService
	available_injuries = InjurySystemService.get_narrative_injury_options()
	_populate_injury_list()

func _populate_injury_list() -> void:
	## Create injury option buttons
	# Clear existing children
	for child in injury_list.get_children():
		child.queue_free()

	# Create button for each injury type
	for injury_option in available_injuries:
		var button := _create_injury_button(injury_option)
		injury_list.add_child(button)

func _get_or_create_button_group() -> ButtonGroup:
	## Get or create button group for injury selection
	if not _injury_button_group:
		_injury_button_group = ButtonGroup.new()
	return _injury_button_group

func _create_injury_button(injury_data: Dictionary) -> Button:
	## Create a styled injury selection button
	var button := Button.new()
	button.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	button.toggle_mode = true
	button.button_group = _get_or_create_button_group()

	# Button text with recovery time
	var injury_name: String = injury_data.get("name", "Unknown")
	var recovery_turns: int = injury_data.get("recovery_turns", 0)
	var button_text := injury_name
	if recovery_turns > 0:
		var turns_text := "turn" if recovery_turns == 1 else "turns"
		button_text += " (%d %s recovery)" % [recovery_turns, turns_text]
	elif injury_name == "Miraculous Escape":
		button_text += " (No injury!)"

	button.text = button_text
	button.tooltip_text = injury_data.get("description", "")

	# Get color based on injury type
	var injury_color := _get_injury_color(injury_data)

	# Button styling
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = COLOR_ELEVATED
	normal_style.border_color = injury_color
	normal_style.border_width_left = 4
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.set_corner_radius_all(4)
	normal_style.set_content_margin_all(SPACING_MD)
	button.add_theme_stylebox_override("normal", normal_style)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = injury_color
	pressed_style.border_color = injury_color
	pressed_style.set_border_width_all(2)
	pressed_style.set_corner_radius_all(4)
	pressed_style.set_content_margin_all(SPACING_MD)
	button.add_theme_stylebox_override("pressed", pressed_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(injury_color.r, injury_color.g, injury_color.b, 0.3)
	hover_style.border_color = injury_color
	hover_style.set_border_width_all(1)
	hover_style.set_corner_radius_all(4)
	hover_style.set_content_margin_all(SPACING_MD)
	button.add_theme_stylebox_override("hover", hover_style)

	# Connect signal
	var injury_type: int = injury_data.get("injury_type", -1)
	button.toggled.connect(func(toggled_on: bool): _on_injury_selected(injury_type, injury_data, toggled_on))

	return button

func _get_injury_color(injury_data: Dictionary) -> Color:
	## Get color based on injury severity
	var injury_name: String = injury_data.get("name", "").to_lower()
	var recovery_turns: int = injury_data.get("recovery_turns", 0)

	if "miraculous" in injury_name:
		return COLOR_MIRACULOUS
	elif "crippling" in injury_name:
		return COLOR_CRIPPLING
	elif "serious" in injury_name:
		return COLOR_DANGER
	elif recovery_turns == 0 or recovery_turns == 1:
		return COLOR_SUCCESS
	elif recovery_turns <= 3:
		return COLOR_WARNING
	else:
		return COLOR_DANGER

func _on_injury_selected(injury_type: int, injury_data: Dictionary, toggled_on: bool) -> void:
	## Handle injury type selection
	if toggled_on:
		selected_injury_type = injury_type
		_update_injury_details(injury_data)
		_update_ui_state()

func _update_injury_details(injury_data: Dictionary) -> void:
	## Update the details panel with selected injury info
	var name: String = injury_data.get("name", "Unknown")
	var description: String = injury_data.get("description", "")
	var recovery_turns: int = injury_data.get("recovery_turns", 0)
	var requires_surgery: bool = injury_data.get("requires_surgery", false)
	var special_effect: String = injury_data.get("special_effect", "")

	var color := _get_injury_color(injury_data)
	var color_hex := "#%02x%02x%02x" % [int(color.r * 255), int(color.g * 255), int(color.b * 255)]

	var details_text := "[b][color=%s]%s[/color][/b]\n" % [color_hex, name]
	details_text += "%s\n\n" % description

	if recovery_turns > 0:
		var turns_text := "turn" if recovery_turns == 1 else "turns"
		details_text += "[color=#808080]Recovery:[/color] %d %s\n" % [recovery_turns, turns_text]
	else:
		details_text += "[color=#10B981]No recovery time needed![/color]\n"

	if requires_surgery:
		details_text += "[color=#D97706]⚕ Requires surgery[/color]\n"

	if not special_effect.is_empty():
		details_text += "[color=#4FC3F7]Special: %s[/color]" % special_effect

	injury_details_label.text = details_text

func _update_ui_state() -> void:
	## Update button states based on selection
	confirm_button.disabled = (selected_injury_type < 0)

func _on_confirm_pressed() -> void:
	## Handle confirm button press
	if selected_injury_type < 0:
		return

	# Create injury result using service
	var injury_result = InjurySystemService.create_narrative_injury(selected_injury_type)

	print("NarrativeInjuryDialog: Selected injury - %s" % injury_result.get("type_name", "Unknown"))

	# Emit signal with injury data
	injury_selected.emit(injury_result)
	queue_free()

func _on_cancel_pressed() -> void:
	## Handle cancel button press - will fall back to rolling
	dialog_closed.emit()
	queue_free()

## Public API

func setup(crew_name: String) -> void:
	## Initialize dialog with character name
	character_name = crew_name
	if description_label:
		description_label.text = "Choose an injury for %s" % character_name
