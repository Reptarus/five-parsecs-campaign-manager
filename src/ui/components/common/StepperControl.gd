class_name StepperControl
extends HBoxContainer

## Reusable quantity stepper widget: [−] value [+]
## Auto-disables at min/max bounds. Animates value changes.
## Inspired by Fallout Wasteland Warfare companion app stepper controls.

signal value_changed(new_value: int)

var value: int = 0:
	set(v):
		var clamped: int = clampi(v, min_value, max_value)
		if clamped == value:
			return
		value = clamped
		_update_display()
		value_changed.emit(value)

var min_value: int = 0
var max_value: int = 99
var step: int = 1

var _minus_btn: Button
var _plus_btn: Button
var _value_label: Label

func _ready() -> void:
	_build_ui()
	_update_display()

func _build_ui() -> void:
	add_theme_constant_override("separation", UIColors.SPACING_XS)
	alignment = BoxContainer.ALIGNMENT_CENTER

	# Minus button
	_minus_btn = Button.new()
	_minus_btn.text = "−"
	_minus_btn.custom_minimum_size = Vector2(
		UIColors.TOUCH_TARGET_MIN, UIColors.TOUCH_TARGET_MIN
	)
	_style_stepper_btn(_minus_btn, UIColors.COLOR_RED)
	_minus_btn.pressed.connect(_on_minus)
	add_child(_minus_btn)

	# Value display
	_value_label = Label.new()
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.custom_minimum_size = Vector2(48, 0)
	_value_label.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_LG
	)
	_value_label.add_theme_color_override(
		"font_color", UIColors.COLOR_CYAN
	)
	add_child(_value_label)

	# Plus button
	_plus_btn = Button.new()
	_plus_btn.text = "+"
	_plus_btn.custom_minimum_size = Vector2(
		UIColors.TOUCH_TARGET_MIN, UIColors.TOUCH_TARGET_MIN
	)
	_style_stepper_btn(_plus_btn, UIColors.COLOR_EMERALD)
	_plus_btn.pressed.connect(_on_plus)
	add_child(_plus_btn)

func _style_stepper_btn(btn: Button, color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = color.darkened(0.6)
	normal.border_color = color
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = color.darkened(0.4)
	hover.border_color = color
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = color.darkened(0.2)
	pressed.border_color = color
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = UIColors.COLOR_SECONDARY
	disabled.border_color = UIColors.COLOR_BORDER
	disabled.set_border_width_all(1)
	disabled.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)
	btn.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_LG)

func _on_minus() -> void:
	value -= step

func _on_plus() -> void:
	value += step

func _update_display() -> void:
	if _value_label:
		_value_label.text = str(value)
		# Punch animation on change
		_value_label.pivot_offset = _value_label.size / 2
		TweenFX.punch_in(_value_label, 0.15, 0.2)

	if _minus_btn:
		_minus_btn.disabled = (value <= min_value)
	if _plus_btn:
		_plus_btn.disabled = (value >= max_value)

## Configure the stepper. Call after instantiation, before adding to tree.
func setup(
	initial: int = 0,
	min_val: int = 0,
	max_val: int = 99,
	step_val: int = 1
) -> StepperControl:
	min_value = min_val
	max_value = max_val
	step = step_val
	value = clampi(initial, min_val, max_val)
	return self
