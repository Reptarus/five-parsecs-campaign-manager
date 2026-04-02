class_name ItemChoicePopup
extends Window

## Item Choice Popup - Crew Task Reward Picker
## Shows when a task result gives the player a choice between items (e.g., "Handgun OR Blade")
## Follows Deep Space theme and AssignEquipmentComponent popup pattern

signal item_chosen(item_name: String)

# Deep Space theme constants (matching BaseCampaignPanel)
const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_ACCENT_HOVER := Color("#3A7199")
const COLOR_FOCUS := Color("#4FC3F7")
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_BORDER := Color("#3A3A5C")
const TOUCH_TARGET_MIN := 48

func _init() -> void:
	title = "Choose Reward"
	size = Vector2i(380, 100)  # Width fixed, height adjusted in show_choices()
	transient = true
	exclusive = true
	unresizable = true
	close_requested.connect(_on_close_requested)

func show_choices(result_name: String, options: Array) -> void:
	## Build the popup UI and display it
	# Calculate height: header(~60) + description(~30) + separator(~10) + buttons(56 each) + padding(32)
	var estimated_height: int = 130 + (options.size() * 64)
	size = Vector2i(380, estimated_height)

	# Background panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_BASE
	panel_style.border_color = COLOR_BORDER
	panel_style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	# Margin
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Title
	var title_label := Label.new()
	title_label.text = "Choose Your Reward"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	# Subtitle (result name)
	if not result_name.is_empty():
		var subtitle := Label.new()
		subtitle.text = result_name
		subtitle.add_theme_font_size_override("font_size", 14)
		subtitle.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(subtitle)

	# Separator
	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	vbox.add_child(sep)

	# Choice buttons
	var button_container := VBoxContainer.new()
	button_container.add_theme_constant_override("separation", 8)
	vbox.add_child(button_container)

	for option_name in options:
		var btn := Button.new()
		btn.text = str(option_name)
		btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Normal style
		var btn_normal := StyleBoxFlat.new()
		btn_normal.bg_color = COLOR_ACCENT
		btn_normal.set_corner_radius_all(6)
		btn_normal.set_content_margin_all(8)
		btn.add_theme_stylebox_override("normal", btn_normal)

		# Hover style
		var btn_hover := StyleBoxFlat.new()
		btn_hover.bg_color = COLOR_ACCENT_HOVER
		btn_hover.set_corner_radius_all(6)
		btn_hover.set_content_margin_all(8)
		btn_hover.border_color = COLOR_FOCUS
		btn_hover.set_border_width_all(2)
		btn.add_theme_stylebox_override("hover", btn_hover)

		# Pressed style
		var btn_pressed := StyleBoxFlat.new()
		btn_pressed.bg_color = COLOR_ELEVATED
		btn_pressed.set_corner_radius_all(6)
		btn_pressed.set_content_margin_all(8)
		btn_pressed.border_color = COLOR_FOCUS
		btn_pressed.set_border_width_all(2)
		btn.add_theme_stylebox_override("pressed", btn_pressed)

		# Text color
		btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_font_size_override("font_size", 16)

		btn.pressed.connect(_on_option_selected.bind(str(option_name)))
		button_container.add_child(btn)

	popup_centered()

func _on_option_selected(option_name: String) -> void:
	item_chosen.emit(option_name)
	queue_free()

func _on_close_requested() -> void:
	# Player must choose — don't allow closing without a selection
	pass
