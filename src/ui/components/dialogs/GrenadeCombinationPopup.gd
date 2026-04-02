class_name GrenadeCombinationPopup
extends Window

## Grenade Combination Popup - lets player choose how many Frakk vs Dazzle grenades (total=3)
## Core Rules p.79: "Receive 3 grenades (Frakk or Dazzle in any combination)"

signal grenades_chosen(frakk_count: int, dazzle_count: int)

# Deep Space theme constants
const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_ACCENT_HOVER := Color("#3A7199")
const COLOR_FOCUS := Color("#4FC3F7")
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_BORDER := Color("#3A3A5C")
const TOUCH_TARGET_MIN := 48
const TOTAL_GRENADES := 3

var _frakk_count: int = 3
var _dazzle_count: int = 0
var _frakk_label: Label
var _dazzle_label: Label

func _init() -> void:
	title = "Choose Grenades"
	size = Vector2i(380, 280)
	transient = true
	exclusive = true
	unresizable = true
	close_requested.connect(func(): pass)  # Must choose

func show_grenade_picker() -> void:
	## Build and display the grenade combination picker
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BASE
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

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
	title_label.text = "Choose Grenade Combination"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	var subtitle := Label.new()
	subtitle.text = "Pick %d grenades total (Frakk and/or Dazzle)" % TOTAL_GRENADES
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	vbox.add_child(sep)

	# Frakk row
	var frakk_row := _create_counter_row("Frakk Grenades", _frakk_count)
	_frakk_label = frakk_row.get_meta("count_label")
	frakk_row.get_meta("minus_btn").pressed.connect(_adjust_frakk.bind(-1))
	frakk_row.get_meta("plus_btn").pressed.connect(_adjust_frakk.bind(1))
	vbox.add_child(frakk_row)

	# Dazzle row
	var dazzle_row := _create_counter_row("Dazzle Grenades", _dazzle_count)
	_dazzle_label = dazzle_row.get_meta("count_label")
	dazzle_row.get_meta("minus_btn").pressed.connect(_adjust_dazzle.bind(-1))
	dazzle_row.get_meta("plus_btn").pressed.connect(_adjust_dazzle.bind(1))
	vbox.add_child(dazzle_row)

	# Confirm button
	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = COLOR_ACCENT
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(8)
	confirm_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = COLOR_ACCENT_HOVER
	btn_hover.set_corner_radius_all(6)
	btn_hover.set_content_margin_all(8)
	btn_hover.border_color = COLOR_FOCUS
	btn_hover.set_border_width_all(2)
	confirm_btn.add_theme_stylebox_override("hover", btn_hover)
	confirm_btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	confirm_btn.add_theme_font_size_override("font_size", 16)
	confirm_btn.pressed.connect(_on_confirm)
	vbox.add_child(confirm_btn)

	popup_centered()

func _create_counter_row(label_text: String, initial_count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var name_label := Label.new()
	name_label.text = label_text
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var minus_btn := Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(TOUCH_TARGET_MIN, TOUCH_TARGET_MIN)
	_style_counter_button(minus_btn)
	row.add_child(minus_btn)

	var count_label := Label.new()
	count_label.text = str(initial_count)
	count_label.add_theme_font_size_override("font_size", 18)
	count_label.add_theme_color_override("font_color", COLOR_FOCUS)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.custom_minimum_size = Vector2(40, 0)
	row.add_child(count_label)

	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(TOUCH_TARGET_MIN, TOUCH_TARGET_MIN)
	_style_counter_button(plus_btn)
	row.add_child(plus_btn)

	row.set_meta("count_label", count_label)
	row.set_meta("minus_btn", minus_btn)
	row.set_meta("plus_btn", plus_btn)
	return row

func _style_counter_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_ELEVATED
	normal.set_corner_radius_all(6)
	normal.border_color = COLOR_BORDER
	normal.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = COLOR_ACCENT
	hover.set_corner_radius_all(6)
	hover.border_color = COLOR_FOCUS
	hover.set_border_width_all(1)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	btn.add_theme_font_size_override("font_size", 18)

func _adjust_frakk(delta: int) -> void:
	var new_val: int = clampi(_frakk_count + delta, 0, TOTAL_GRENADES)
	_frakk_count = new_val
	_dazzle_count = TOTAL_GRENADES - _frakk_count
	_update_labels()

func _adjust_dazzle(delta: int) -> void:
	var new_val: int = clampi(_dazzle_count + delta, 0, TOTAL_GRENADES)
	_dazzle_count = new_val
	_frakk_count = TOTAL_GRENADES - _dazzle_count
	_update_labels()

func _update_labels() -> void:
	if _frakk_label:
		_frakk_label.text = str(_frakk_count)
	if _dazzle_label:
		_dazzle_label.text = str(_dazzle_count)

func _on_confirm() -> void:
	grenades_chosen.emit(_frakk_count, _dazzle_count)
	queue_free()
