extends Window
class_name CustomVictoryDialog

## Custom Victory Condition Dialog - Deep Space Design System
## Allows players to create custom victory conditions with adjusted targets
## Matches campaign wizard panel styling for visual consistency

const FPCM_VictoryDescriptions = preload("res://src/game/victory/VictoryDescriptions.gd")

signal custom_condition_created(condition_type: int, target_value: int)
signal dialog_cancelled

# Design System Constants (matching BaseCampaignPanel)
const SPACING_XS := 4
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24
const SPACING_XL := 32

const TOUCH_TARGET_MIN := 48
const TOUCH_TARGET_COMFORT := 56

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

# UI References
var condition_type_option: OptionButton
var target_value_input: LineEdit
var preview_container: VBoxContainer
var preview_card: PanelContainer
var confirm_button: Button
var cancel_button: Button

# Mapping from OptionButton index to victory type enum
var _type_index_map: Array[int] = []

func _ready() -> void:
	title = "Create Custom Victory Condition"
	size = Vector2i(550, 600)
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
	_populate_condition_types()
	_update_preview()

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

	# === VICTORY TYPE CARD ===
	var type_card := _create_victory_type_card()
	vbox.add_child(type_card)

	# === TARGET VALUE CARD ===
	var target_card := _create_target_value_card()
	vbox.add_child(target_card)

	# === PREVIEW CARD ===
	preview_container = VBoxContainer.new()
	preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(preview_container)

	# === ACTION BUTTONS ===
	var buttons := _create_action_buttons()
	vbox.add_child(buttons)

func _create_header() -> VBoxContainer:
	## Create dialog header with title and description.
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", SPACING_SM)

	# Title
	var title_label := Label.new()
	title_label.text = "Create Custom Victory Condition"
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	container.add_child(title_label)

	# Description
	var desc := Label.new()
	desc.text = "Adjust the target value for any victory condition to suit your campaign style."
	desc.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(desc)

	return container

func _create_victory_type_card() -> PanelContainer:
	## Create styled card for victory type selection.
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Card styling
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)

	# Label
	var label := Label.new()
	label.text = "VICTORY TYPE"
	label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(label)

	# OptionButton
	condition_type_option = OptionButton.new()
	condition_type_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	_style_option_button(condition_type_option)
	condition_type_option.item_selected.connect(_on_condition_type_changed)
	vbox.add_child(condition_type_option)

	card.add_child(vbox)
	return card

func _create_target_value_card() -> PanelContainer:
	## Create styled card for target value input.
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Card styling
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)

	# Label
	var label := Label.new()
	label.text = "TARGET VALUE"
	label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(label)

	# LineEdit (replacing SpinBox for better mobile UX)
	target_value_input = LineEdit.new()
	target_value_input.placeholder_text = "Enter target value..."
	target_value_input.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	_style_line_edit(target_value_input)
	target_value_input.text_changed.connect(_on_target_value_changed)
	vbox.add_child(target_value_input)

	card.add_child(vbox)
	return card

func _create_action_buttons() -> HBoxContainer:
	## Create styled action buttons matching design system.
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", SPACING_SM)
	container.alignment = BoxContainer.ALIGNMENT_END

	# Cancel button
	cancel_button = Button.new()
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

	# Confirm button (primary action)
	confirm_button = Button.new()
	confirm_button.text = "Create Custom Condition"
	confirm_button.custom_minimum_size = Vector2(220, TOUCH_TARGET_COMFORT)

	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = COLOR_ACCENT
	confirm_style.set_corner_radius_all(6)
	confirm_style.set_content_margin_all(SPACING_SM)
	confirm_button.add_theme_stylebox_override("normal", confirm_style)

	# Hover state
	var confirm_hover := confirm_style.duplicate()
	confirm_hover.bg_color = COLOR_ACCENT_HOVER
	confirm_button.add_theme_stylebox_override("hover", confirm_hover)

	confirm_button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	confirm_button.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	confirm_button.pressed.connect(_on_confirm_pressed)
	container.add_child(confirm_button)

	return container

func _style_line_edit(line_edit: LineEdit) -> void:
	## Apply design system styling to LineEdit.
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_INPUT
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	line_edit.add_theme_stylebox_override("normal", style)

	var focus_style := style.duplicate()
	focus_style.border_color = COLOR_FOCUS
	focus_style.set_border_width_all(2)
	line_edit.add_theme_stylebox_override("focus", focus_style)

	line_edit.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	line_edit.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

func _style_option_button(option_btn: OptionButton) -> void:
	## Apply design system styling to OptionButton.
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_INPUT
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	option_btn.add_theme_stylebox_override("normal", style)

	var focus_style := style.duplicate()
	focus_style.border_color = COLOR_FOCUS
	focus_style.set_border_width_all(2)
	option_btn.add_theme_stylebox_override("focus", focus_style)

	option_btn.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	option_btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

func _populate_condition_types() -> void:
	condition_type_option.clear()
	_type_index_map.clear()

	# Group by category for better organization
	var categories = {
		FPCM_VictoryDescriptions.VictoryCategory.DURATION: "Duration",
		FPCM_VictoryDescriptions.VictoryCategory.COMBAT: "Combat",
		FPCM_VictoryDescriptions.VictoryCategory.STORY: "Story",
		FPCM_VictoryDescriptions.VictoryCategory.WEALTH: "Wealth",
		FPCM_VictoryDescriptions.VictoryCategory.CHALLENGE: "Challenge"
	}

	var idx = 0
	for category_id in categories:
		var category_name = categories[category_id]
		var types = FPCM_VictoryDescriptions.get_victory_types_by_category(category_id)

		if types.is_empty():
			continue

		# Add separator for categories after first
		if idx > 0:
			condition_type_option.add_separator()

		for victory_type in types:
			var name = FPCM_VictoryDescriptions.get_victory_name(victory_type)
			condition_type_option.add_item("%s - %s" % [category_name, name])
			_type_index_map.append(victory_type)
			idx += 1

	if condition_type_option.item_count > 0:
		condition_type_option.select(0)
		_on_condition_type_changed(0)

func _on_condition_type_changed(index: int) -> void:
	if index < 0 or index >= _type_index_map.size():
		return

	var victory_type = _type_index_map[index]
	var default_value = _get_default_value_for_type(victory_type)

	# Update LineEdit with default value
	target_value_input.text = str(default_value)

	_update_preview()

func _get_default_value_for_type(victory_type: int) -> int:
	# Return standard target values based on type
	match victory_type:
		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20:
			return 20
		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50:
			return 50
		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100:
			return 100
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20:
			return 20
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_50:
			return 50
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_100:
			return 100
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3:
			return 3
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5:
			return 5
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10:
			return 10
		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_10:
			return 10
		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_20:
			return 20
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_50K:
			return 50000
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_100K:
			return 100000
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_10:
			return 10
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_20:
			return 20
		_:
			return 10

func _on_target_value_changed(_new_text: String) -> void:
	_update_preview()

func _update_preview() -> void:
	if not preview_container or _type_index_map.is_empty():
		return

	var index = condition_type_option.selected
	if index < 0 or index >= _type_index_map.size():
		return

	# Remove old preview if exists
	if preview_card:
		preview_card.queue_free()
		preview_card = null

	var victory_type = _type_index_map[index]
	var target_text = target_value_input.text if target_value_input else "0"
	var target = int(target_text) if target_text.is_valid_int() else 0

	# Create new preview card
	preview_card = _create_preview_card(victory_type, target)
	preview_container.add_child(preview_card)

func _create_preview_card(victory_type: int, target_value: int) -> PanelContainer:
	## Create styled preview card matching ExpandedConfigPanel design.
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 120

	# Card styling with cyan focus border
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_FOCUS # Cyan to show "preview" state
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)

	# Get victory data
	var data = FPCM_VictoryDescriptions.get_victory_data(victory_type)
	var name = data.get("name", "Custom Victory")
	var short_desc = data.get("short_desc", "Custom victory condition")
	var difficulty = data.get("difficulty", "Medium")
	var est_time = data.get("estimated_hours", "5-10")
	var strategy = data.get("strategy", "")

	# Calculate adjusted time
	var adjusted_time = _estimate_adjusted_time(victory_type, target_value, est_time)

	# === PREVIEW LABEL ===
	var preview_label := Label.new()
	preview_label.text = "PREVIEW"
	preview_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	preview_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(preview_label)

	# === TITLE ===
	var title := Label.new()
	title.text = "%s (Custom: %d)" % [name, target_value]
	title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	vbox.add_child(title)

	# === DESCRIPTION ===
	var description := Label.new()
	description.text = short_desc
	description.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	description.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(description)

	# === BADGES ROW ===
	var badges_row := HBoxContainer.new()
	badges_row.add_theme_constant_override("separation", SPACING_SM)

	# Target badge (blue accent)
	var target_badge := _create_badge("Target: %d" % target_value, COLOR_ACCENT)
	badges_row.add_child(target_badge)

	# Difficulty badge (color coded)
	var difficulty_color := _get_difficulty_color(difficulty)
	var difficulty_badge := _create_badge("Difficulty: %s" % difficulty, difficulty_color)
	badges_row.add_child(difficulty_badge)

	# Time estimate badge
	var time_badge := _create_badge("Time: %s hrs" % adjusted_time, COLOR_BORDER)
	badges_row.add_child(time_badge)

	vbox.add_child(badges_row)

	# === STRATEGY TIP (if available) ===
	if not strategy.is_empty():
		var tip := Label.new()
		tip.text = "Strategy: %s" % strategy
		tip.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		tip.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(tip)

	card.add_child(vbox)
	return card

func _create_badge(text: String, bg_color: Color) -> PanelContainer:
	## Create a colored badge for displaying metadata.
	var badge := PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(4)
	style.set_content_margin_all(SPACING_XS)
	badge.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	badge.add_child(label)

	return badge

func _get_difficulty_color(difficulty: String) -> Color:
	## Return color based on difficulty level.
	match difficulty:
		"Easy":
			return COLOR_SUCCESS
		"Medium":
			return COLOR_WARNING
		"Hard", "Very Hard":
			return Color("#DC2626") # COLOR_DANGER
		_:
			return COLOR_BORDER

func _estimate_adjusted_time(victory_type: int, target: int, base_time: String) -> String:
	# Parse base time range
	var parts = base_time.split("-")
	if parts.size() != 2:
		return base_time

	var min_hours = parts[0].to_float()
	var max_hours = parts[1].to_float()
	var default_value = float(_get_default_value_for_type(victory_type))

	if default_value <= 0:
		return base_time

	# Scale time proportionally
	var ratio = float(target) / default_value
	var adjusted_min = min_hours * ratio
	var adjusted_max = max_hours * ratio

	return "%.0f-%.0f" % [adjusted_min, adjusted_max]

func _on_confirm_pressed() -> void:
	if _type_index_map.is_empty():
		return

	var index = condition_type_option.selected
	if index < 0 or index >= _type_index_map.size():
		return

	var victory_type = _type_index_map[index]
	var target_text = target_value_input.text

	# Validate input is a valid integer
	if not target_text.is_valid_int():
		push_warning("Invalid target value: %s" % target_text)
		return

	var target = int(target_text)

	# Validate against range (optional safety check)
	var range_data = FPCM_VictoryDescriptions.get_value_range(victory_type)
	if target < range_data.min or target > range_data.max:
		push_warning("Target %d out of range [%d, %d]" % [target, range_data.min, range_data.max])
		# Could show error message to user here
		return

	custom_condition_created.emit(victory_type, target)
	hide()

func _on_cancel_pressed() -> void:
	dialog_cancelled.emit()
	hide()

## Show the dialog centered on screen
func show_dialog() -> void:
	popup_centered()
