@tool
extends PanelContainer
class_name EventResolutionPanel

## Battle Event Resolution Panel
## Displays battle events for interactive resolution with target selection

signal event_displayed(event: Dictionary)
signal target_selected(target_id: String)
signal event_resolved(event: Dictionary, outcome: Dictionary)
signal resolution_cancelled()
signal escalation_resolved(instruction: String)

# Design system constants (from BaseCampaignPanel)
const SPACING_SM: int = 8
const SPACING_MD: int = 16
const SPACING_LG: int = 24
const TOUCH_TARGET_MIN: int = 48
const FONT_SIZE_SM: int = 14
const FONT_SIZE_MD: int = 16
const FONT_SIZE_LG: int = 18

const COLOR_ELEVATED: Color = UIColors.COLOR_ELEVATED
const COLOR_BORDER: Color = UIColors.COLOR_BORDER
const COLOR_ACCENT: Color = UIColors.COLOR_ACCENT
const COLOR_ACCENT_HOVER: Color = UIColors.COLOR_ACCENT_HOVER
const COLOR_FOCUS: Color = UIColors.COLOR_FOCUS
const COLOR_TEXT_PRIMARY: Color = UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY: Color = UIColors.COLOR_TEXT_SECONDARY
const COLOR_WARNING: Color = UIColors.COLOR_WARNING
const COLOR_SUCCESS: Color = UIColors.COLOR_SUCCESS

# Current event being resolved
var _current_event: Dictionary = {}
var _selected_target: String = ""
var _available_targets: Array = []
var _is_escalation_mode: bool = false

# UI references
var title_label: Label
var description_label: RichTextLabel
var target_container: VBoxContainer
var target_label: Label
var target_list: ItemList
var effect_preview_label: Label
var confirm_button: Button
var cancel_button: Button
var resolve_button: Button  # "Mark as Resolved" for escalation events

func _ready() -> void:
	_setup_ui()
	hide()  # Hidden by default

func _setup_ui() -> void:
	# Style the panel container
	custom_minimum_size = Vector2(400, 300)
	
	# Create panel background
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_ELEVATED
	panel_style.border_color = COLOR_BORDER
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(SPACING_LG)
	add_theme_stylebox_override("panel", panel_style)
	
	# Main container
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", SPACING_MD)
	add_child(main_vbox)
	
	# Header row
	var header_row := HBoxContainer.new()
	main_vbox.add_child(header_row)
	
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title_label)
	
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(TOUCH_TARGET_MIN, TOUCH_TARGET_MIN)
	close_button.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	close_button.flat = true
	close_button.pressed.connect(_on_cancel_pressed)
	header_row.add_child(close_button)
	
	# Description label
	description_label = RichTextLabel.new()
	description_label.custom_minimum_size = Vector2(0, 80)
	description_label.add_theme_font_size_override("normal_font_size", FONT_SIZE_MD)
	description_label.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	description_label.bbcode_enabled = true
	description_label.fit_content = true
	description_label.scroll_active = false
	main_vbox.add_child(description_label)
	
	# Target selection container (hidden when no targets)
	target_container = VBoxContainer.new()
	target_container.add_theme_constant_override("separation", SPACING_SM)
	main_vbox.add_child(target_container)
	
	target_label = Label.new()
	target_label.text = "Select Target:"
	target_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	target_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	target_container.add_child(target_label)
	
	target_list = ItemList.new()
	target_list.custom_minimum_size = Vector2(0, 100)
	target_list.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	target_list.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	target_list.add_theme_color_override("font_selected_color", COLOR_ACCENT)
	target_list.item_selected.connect(_on_target_selected)
	target_container.add_child(target_list)
	
	# Effect preview label
	effect_preview_label = Label.new()
	effect_preview_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	effect_preview_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	effect_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(effect_preview_label)
	
	# Spacer to push buttons to bottom
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer)
	
	# Button row
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", SPACING_SM)
	button_row.alignment = BoxContainer.ALIGNMENT_END
	main_vbox.add_child(button_row)
	
	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(100, TOUCH_TARGET_MIN)
	cancel_button.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_row.add_child(cancel_button)
	
	confirm_button = Button.new()
	confirm_button.text = "Confirm"
	confirm_button.custom_minimum_size = Vector2(100, TOUCH_TARGET_MIN)
	confirm_button.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_confirm_pressed)
	_style_accent_button(confirm_button)
	button_row.add_child(confirm_button)

	resolve_button = Button.new()
	resolve_button.text = "Mark as Resolved"
	resolve_button.custom_minimum_size = Vector2(140, TOUCH_TARGET_MIN)
	resolve_button.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	resolve_button.pressed.connect(_on_resolve_pressed)
	resolve_button.visible = false  # Only shown in escalation mode
	_style_resolve_button(resolve_button)
	button_row.add_child(resolve_button)

func _style_accent_button(button: Button) -> void:
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = COLOR_ACCENT
	normal_style.set_corner_radius_all(4)
	normal_style.set_content_margin_all(SPACING_SM)
	
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = COLOR_ACCENT_HOVER
	
	var disabled_style := normal_style.duplicate()
	disabled_style.bg_color = COLOR_TEXT_SECONDARY
	
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", hover_style)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

func display_event(event: Dictionary, targets: Array = []) -> void:
	## Display an event with optional target selection.
	_current_event = event
	_available_targets = targets
	_selected_target = ""
	
	# Update title and description
	title_label.text = event.get("title", "Event")
	description_label.text = event.get("description", "")
	
	# Setup target selection
	if targets.is_empty():
		target_container.hide()
		confirm_button.disabled = false
		effect_preview_label.text = ""
	else:
		target_container.show()
		target_list.clear()
		for target in targets:
			var target_name: String = target.get("name", "Unknown")
			var target_info: String = target.get("info", "")
			var display_text: String = target_name
			if not target_info.is_empty():
				display_text += " - " + target_info
			target_list.add_item(display_text)
		confirm_button.disabled = true
		effect_preview_label.text = "Select a target to continue..."
	
	event_displayed.emit(event)
	show()

func _on_target_selected(index: int) -> void:
	if index >= 0 and index < _available_targets.size():
		_selected_target = _available_targets[index].get("id", "")
		target_selected.emit(_selected_target)
		confirm_button.disabled = false
		_update_effect_preview()

func _on_confirm_pressed() -> void:
	var outcome := {
		"event": _current_event,
		"target_id": _selected_target,
		"resolved": true,
		"timestamp": Time.get_ticks_msec(),
		"description": _generate_outcome_description()
	}
	event_resolved.emit(_current_event, outcome)
	_clear_and_hide()

func _on_cancel_pressed() -> void:
	resolution_cancelled.emit()
	_clear_and_hide()

func _update_effect_preview() -> void:
	## Show what will happen based on current selection.
	if _selected_target.is_empty():
		effect_preview_label.text = ""
		return
	
	# Find the selected target data
	var target_data: Dictionary = {}
	for target in _available_targets:
		if target.get("id", "") == _selected_target:
			target_data = target
			break
	
	# Generate preview text based on event type and target
	var event_type: String = _current_event.get("type", "")
	var target_name: String = target_data.get("name", "Unknown")
	var preview: String = ""
	
	match event_type:
		"damage":
			var damage_amount: int = _current_event.get("damage", 1)
			preview = "%s will take %d damage" % [target_name, damage_amount]
		"status":
			var status: String = _current_event.get("status", "affected")
			preview = "%s will be %s" % [target_name, status]
		"movement":
			var distance: int = _current_event.get("distance", 1)
			preview = "%s will move %d spaces" % [target_name, distance]
		_:
			preview = "Affects %s" % target_name
	
	effect_preview_label.text = preview

func _generate_outcome_description() -> String:
	## Generate description of event outcome.
	var base_description: String = _current_event.get("outcome_description", "Event resolved")
	
	if not _selected_target.is_empty():
		# Find target name for description
		for target in _available_targets:
			if target.get("id", "") == _selected_target:
				var target_name: String = target.get("name", "Unknown")
				return base_description.replace("{target}", target_name)
	
	return base_description

func _on_resolve_pressed() -> void:
	## Handle Mark as Resolved button press (escalation/event mode).
	var instruction: String = _current_event.get("instruction", "")
	escalation_resolved.emit(instruction)
	_clear_and_hide()

func _style_resolve_button(button: Button) -> void:
	## Style the resolve button with success color.
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = COLOR_SUCCESS
	normal_style.set_corner_radius_all(4)
	normal_style.set_content_margin_all(SPACING_SM)

	var hover_style := normal_style.duplicate()
	hover_style.bg_color = COLOR_SUCCESS.lightened(0.2)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", hover_style)
	button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

## Display an escalation event or battle event as instruction text.
## The player reads the instruction and applies it on the physical table,
## then presses "Mark as Resolved".
func display_escalation(instruction: String, is_escalation: bool = true) -> void:
	_is_escalation_mode = true
	_current_event = {"instruction": instruction, "is_escalation": is_escalation}
	_selected_target = ""
	_available_targets = []

	if is_escalation:
		title_label.text = "ESCALATION EVENT"
		title_label.add_theme_color_override("font_color", COLOR_WARNING)
	else:
		title_label.text = "Battle Event"
		title_label.add_theme_color_override("font_color", COLOR_ACCENT)

	description_label.text = instruction
	target_container.hide()
	effect_preview_label.text = "Apply this on the physical table, then mark as resolved."

	# Show resolve button, hide confirm/cancel
	resolve_button.visible = true
	confirm_button.visible = false
	cancel_button.visible = false

	show()

func _clear_and_hide() -> void:
	## Reset panel state and hide.
	_current_event = {}
	_selected_target = ""
	_available_targets = []
	_is_escalation_mode = false
	target_list.clear()
	effect_preview_label.text = ""
	confirm_button.disabled = true

	# Reset button visibility
	confirm_button.visible = true
	cancel_button.visible = true
	resolve_button.visible = false

	# Reset title color
	title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

	hide()
