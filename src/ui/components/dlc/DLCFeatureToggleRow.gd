extends HBoxContainer

## Atomic reusable row for a single DLC feature toggle.
## Two states: owned (checkbox) or locked (lock icon + upsell).

signal feature_toggled(flag: int, enabled: bool)
signal upsell_requested(dlc_id: String)

const FONT_SIZE_SM := UIColors.FONT_SIZE_SM
const FONT_SIZE_MD := UIColors.FONT_SIZE_MD
const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_TEXT_MUTED := UIColors.COLOR_TEXT_MUTED
const COLOR_CYAN := UIColors.COLOR_CYAN
const SPACING_SM := UIColors.SPACING_SM

var _flag_value: int = -1
var _dlc_id: String = ""
var _checkbox: CheckBox = null

func setup(
	flag_value: int,
	display_name: String,
	description: String,
	is_available: bool,
	is_enabled: bool,
	pack_name: String,
	dlc_id: String,
) -> void:
	_flag_value = flag_value
	_dlc_id = dlc_id
	custom_minimum_size.y = TOUCH_TARGET_MIN
	add_theme_constant_override("separation", SPACING_SM)

	if is_available:
		_build_owned_row(display_name, description, is_enabled)
	else:
		_build_locked_row(display_name, pack_name)

func set_enabled(enabled: bool) -> void:
	if _checkbox:
		_checkbox.set_pressed_no_signal(enabled)

func _build_owned_row(
	display_name: String,
	description: String,
	is_enabled: bool,
) -> void:
	_checkbox = CheckBox.new()
	_checkbox.text = display_name
	_checkbox.button_pressed = is_enabled
	_checkbox.custom_minimum_size.y = TOUCH_TARGET_MIN
	_checkbox.add_theme_font_size_override(
		"font_size", FONT_SIZE_MD)
	_checkbox.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	_checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_checkbox.toggled.connect(_on_toggled)
	add_child(_checkbox)

	if not description.is_empty():
		var desc_lbl := Label.new()
		desc_lbl.text = description
		desc_lbl.add_theme_font_size_override(
			"font_size", FONT_SIZE_SM)
		desc_lbl.add_theme_color_override(
			"font_color", COLOR_TEXT_SECONDARY)
		add_child(desc_lbl)

func _build_locked_row(
	display_name: String,
	pack_name: String,
) -> void:
	var lock_icon := Label.new()
	lock_icon.text = "🔒"
	lock_icon.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	add_child(lock_icon)

	var name_lbl := Label.new()
	name_lbl.text = display_name
	name_lbl.add_theme_font_size_override(
		"font_size", FONT_SIZE_MD)
	name_lbl.add_theme_color_override(
		"font_color", COLOR_TEXT_MUTED)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(name_lbl)

	var upsell_btn := Button.new()
	upsell_btn.text = "Get %s" % pack_name
	upsell_btn.flat = true
	upsell_btn.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	upsell_btn.add_theme_color_override(
		"font_color", COLOR_CYAN)
	upsell_btn.custom_minimum_size.y = TOUCH_TARGET_MIN
	upsell_btn.pressed.connect(
		func(): upsell_requested.emit(_dlc_id))
	add_child(upsell_btn)

func _on_toggled(enabled: bool) -> void:
	feature_toggled.emit(_flag_value, enabled)
