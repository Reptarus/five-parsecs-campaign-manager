class_name FPCM_DualInputRoll
extends HBoxContainer

## Dual Input Roll - Reusable dice roll component for tabletop companion
##
## Every dice roll in the battle system supports two modes:
## 1. "Roll for me" - App generates the result using DiceSystem
## 2. "I rolled [X]" - Player inputs their physical dice result
##
## This component provides both modes in a compact, touch-friendly layout.
## Used throughout the battle companion wherever dice are needed.
##
## Reference: Five Parsecs From Home - Companion Philosophy
## "The player has physical dice on the table. Always let them use their own dice."

signal roll_completed(result: int, was_manual: bool)

## Dice configuration
@export var dice_type: String = "d6":
	set(value):
		dice_type = value
		if is_node_ready():
			_update_labels()

@export var context_label: String = "Roll":
	set(value):
		context_label = value
		if is_node_ready():
			_update_labels()

@export var show_result: bool = true

## Touch target minimum from UIColors design system
const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN

## Internal state
var _last_result: int = 0
var _last_was_manual: bool = false
var _manual_input_visible: bool = false

## UI nodes
var _context_lbl: Label
var _roll_button: Button
var _manual_button: Button
var _manual_input: SpinBox
var _confirm_button: Button
var _result_label: Label
var _manual_container: HBoxContainer

func _ready() -> void:
	_build_ui()
	_update_labels()

func _build_ui() -> void:
	add_theme_constant_override("separation", 4)

	# Context label (optional, shows what this roll is for)
	_context_lbl = Label.new()
	_context_lbl.name = "ContextLabel"
	_context_lbl.add_theme_font_size_override("font_size", 14)
	_context_lbl.add_theme_color_override("font_color", Color("#9ca3af"))
	_context_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_context_lbl)

	# "Roll for me" button
	_roll_button = Button.new()
	_roll_button.name = "RollButton"
	_roll_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	_roll_button.pressed.connect(_on_roll_pressed)
	_apply_button_style(_roll_button, Color("#3b82f6"))
	add_child(_roll_button)

	# "I rolled..." button (toggles manual input)
	_manual_button = Button.new()
	_manual_button.name = "ManualButton"
	_manual_button.text = "I rolled..."
	_manual_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	_manual_button.pressed.connect(_on_manual_toggle)
	_apply_button_style(_manual_button, Color("#1f2937"))
	add_child(_manual_button)

	# Manual input container (hidden by default)
	_manual_container = HBoxContainer.new()
	_manual_container.name = "ManualContainer"
	_manual_container.visible = false
	_manual_container.add_theme_constant_override("separation", 4)
	add_child(_manual_container)

	_manual_input = SpinBox.new()
	_manual_input.name = "ManualInput"
	_manual_input.min_value = _get_min_for_dice()
	_manual_input.max_value = _get_max_for_dice()
	_manual_input.value = 1
	_manual_input.custom_minimum_size = Vector2(70, TOUCH_TARGET_MIN)
	_manual_container.add_child(_manual_input)

	_confirm_button = Button.new()
	_confirm_button.name = "ConfirmButton"
	_confirm_button.text = "OK"
	_confirm_button.custom_minimum_size = Vector2(48, TOUCH_TARGET_MIN)
	_confirm_button.pressed.connect(_on_manual_confirm)
	_apply_button_style(_confirm_button, Color("#10b981"))
	_manual_container.add_child(_confirm_button)

	# Result display
	_result_label = Label.new()
	_result_label.name = "ResultLabel"
	_result_label.add_theme_font_size_override("font_size", 18)
	_result_label.add_theme_color_override("font_color", Color("#f3f4f6"))
	_result_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_result_label.visible = false
	add_child(_result_label)

func _apply_button_style(button: Button, bg_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate()
	hover_style.bg_color = bg_color.lightened(0.15)
	button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := style.duplicate()
	pressed_style.bg_color = bg_color.darkened(0.15)
	button.add_theme_stylebox_override("pressed", pressed_style)

	button.add_theme_color_override("font_color", Color("#f3f4f6"))
	button.add_theme_font_size_override("font_size", 14)

func _update_labels() -> void:
	if _context_lbl:
		_context_lbl.text = context_label
		_context_lbl.visible = not context_label.is_empty()

	if _roll_button:
		_roll_button.text = "Roll %s" % dice_type

	if _manual_input:
		_manual_input.min_value = _get_min_for_dice()
		_manual_input.max_value = _get_max_for_dice()

## "Roll for me" - app generates the result
func _on_roll_pressed() -> void:
	_hide_manual_input()
	var result := _generate_roll()
	_submit_result(result, false)

## Toggle manual input visibility
func _on_manual_toggle() -> void:
	_manual_input_visible = not _manual_input_visible
	_manual_container.visible = _manual_input_visible
	if _manual_input_visible:
		_manual_input.get_line_edit().select_all()

## Confirm manual input
func _on_manual_confirm() -> void:
	var result := int(_manual_input.value)
	_hide_manual_input()
	_submit_result(result, true)

func _hide_manual_input() -> void:
	_manual_input_visible = false
	if _manual_container:
		_manual_container.visible = false

func _submit_result(result: int, was_manual: bool) -> void:
	_last_result = result
	_last_was_manual = was_manual

	if show_result and _result_label:
		_result_label.text = str(result)
		_result_label.visible = true

		# Brief highlight animation
		var tween := create_tween()
		tween.tween_property(_result_label, "modulate", Color.GOLD, 0.15)
		tween.tween_property(_result_label, "modulate", Color.WHITE, 0.3)

	roll_completed.emit(result, was_manual)

## Generate a roll based on dice_type
func _generate_roll() -> int:
	match dice_type:
		"d6":
			return randi_range(1, 6)
		"2d6":
			return randi_range(1, 6) + randi_range(1, 6)
		"d10":
			return randi_range(1, 10)
		"d100":
			return randi_range(1, 100)
		"d66":
			return (randi_range(1, 6) * 10) + randi_range(1, 6)
		_:
			# Try to parse custom format like "3d6"
			if "d" in dice_type:
				var parts := dice_type.split("d")
				if parts.size() == 2:
					var count := int(parts[0]) if not parts[0].is_empty() else 1
					var sides := int(parts[1])
					if sides > 0:
						var total := 0
						for i in range(count):
							total += randi_range(1, sides)
						return total
			return randi_range(1, 6)

func _get_min_for_dice() -> int:
	match dice_type:
		"2d6":
			return 2
		"d66":
			return 11
		_:
			return 1

func _get_max_for_dice() -> int:
	match dice_type:
		"d6":
			return 6
		"2d6":
			return 12
		"d10":
			return 10
		"d100":
			return 100
		"d66":
			return 66
		_:
			if "d" in dice_type:
				var parts := dice_type.split("d")
				if parts.size() == 2:
					var count := int(parts[0]) if not parts[0].is_empty() else 1
					var sides := int(parts[1])
					return count * sides
			return 6

## Get last roll result
func get_last_result() -> int:
	return _last_result

## Get whether last roll was manual
func was_last_manual() -> bool:
	return _last_was_manual

## Reset display (clear result)
func reset() -> void:
	_last_result = 0
	_last_was_manual = false
	_hide_manual_input()
	if _result_label:
		_result_label.visible = false
