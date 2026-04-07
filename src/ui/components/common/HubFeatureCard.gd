class_name HubFeatureCard
extends PanelContainer

## Dark card with cyan left border, icon, title, description, and arrow.
## Used as a dashboard hub navigation element — replaces plain button lists.
## Inspired by Fallout Wasteland Warfare hub screen feature cards.

signal card_pressed

var _icon_label: Label
var _title_label: Label
var _desc_label: Label

func _ready() -> void:
	_build_ui()
	# Touch/click handling
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _build_ui() -> void:
	custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_COMFORT)

	# Card style — dark bg with cyan left border
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_SECONDARY
	style.border_color = UIColors.COLOR_CYAN
	style.border_width_left = 3
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.set_corner_radius_all(4)
	style.content_margin_left = UIColors.SPACING_MD
	style.content_margin_right = UIColors.SPACING_MD
	style.content_margin_top = UIColors.SPACING_SM
	style.content_margin_bottom = UIColors.SPACING_SM
	add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UIColors.SPACING_MD)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbox)

	# Icon
	_icon_label = Label.new()
	_icon_label.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_XL + 4
	)
	_icon_label.add_theme_color_override(
		"font_color", UIColors.COLOR_CYAN
	)
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_icon_label)

	# Text column
	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 2)
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(text_vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_LG
	)
	_title_label.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_child(_title_label)

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_SM
	)
	_desc_label.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_SECONDARY
	)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_child(_desc_label)

	# Arrow indicator
	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_LG
	)
	arrow.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_MUTED
	)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(arrow)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		TweenFX.press(self, 0.15)
		card_pressed.emit()
	elif event is InputEventScreenTouch and event.pressed:
		TweenFX.press(self, 0.15)
		card_pressed.emit()

func _on_hover_enter() -> void:
	var style: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	style.border_color = UIColors.COLOR_ACCENT_HOVER
	style.bg_color = UIColors.COLOR_TERTIARY
	add_theme_stylebox_override("panel", style)

func _on_hover_exit() -> void:
	var style: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	style.border_color = UIColors.COLOR_CYAN
	style.bg_color = UIColors.COLOR_SECONDARY
	add_theme_stylebox_override("panel", style)

## Configure the card. Returns self for chaining.
func setup(
	icon: String,
	title_text: String,
	description: String
) -> HubFeatureCard:
	if _icon_label:
		_icon_label.text = icon
	if _title_label:
		_title_label.text = title_text
	if _desc_label:
		_desc_label.text = description
	return self
