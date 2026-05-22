## NarrativeChoiceButton — touch-friendly button for NarrativeScreen choices.
## Shows a main label (the choice) and an optional smaller hint (the
## consequence — "Tests Savvy", "Costs 1 credit", etc.). Disabled state
## greys the button and exposes a tooltip-friendly disabled_reason.
##
## Use:
##   var btn := NarrativeChoiceButtonClass.new()
##   btn.setup({"id": 0, "label": "Talk to the locals", "hint": "Tests Savvy"})
##   btn.choice_pressed.connect(_on_choice_pressed)
##   container.add_child(btn)
##
## Emits `choice_pressed(choice_id: int)` when activated.
##
## Path-loaded (no class_name) per docs/sop/component-patterns.md.
extends Button

const TOUCH_TARGET_MIN := 48
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_TEXT_DISABLED := Color("#404040")
const SPACING_XS := 4
const SPACING_SM := 8

signal choice_pressed(choice_id: int)

var _choice_id: int = 0
var _label_main: Label = null
var _label_hint: Label = null


func _ready() -> void:
	custom_minimum_size.y = TOUCH_TARGET_MIN
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Wrap content in margin + vbox so we can stack two labels.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", SPACING_SM)
	margin.add_theme_constant_override("margin_right", SPACING_SM)
	margin.add_theme_constant_override("margin_top", SPACING_XS)
	margin.add_theme_constant_override("margin_bottom", SPACING_XS)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 0)
	margin.add_child(vbox)

	_label_main = Label.new()
	_label_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_main.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	_label_main.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_label_main.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_label_main)

	_label_hint = Label.new()
	_label_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_hint.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_label_hint.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	_label_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label_hint.visible = false
	vbox.add_child(_label_hint)

	pressed.connect(_on_pressed)


## Populates the button from a choice dictionary.
## Required: id (int), label (String)
## Optional: hint (String), enabled (bool, default true), disabled_reason (String)
func setup(choice_data: Dictionary) -> void:
	_choice_id = int(choice_data.get("id", 0))
	var label_text: String = str(choice_data.get("label", ""))
	var hint_text: String = str(choice_data.get("hint", ""))
	var enabled: bool = bool(choice_data.get("enabled", true))
	var disabled_reason: String = str(choice_data.get("disabled_reason", ""))

	# Build labels lazily if _ready hasn't fired yet (defensive when setup
	# is called between .new() and add_child()).
	if not _label_main:
		_pending_setup_apply.call_deferred(label_text, hint_text,
			enabled, disabled_reason)
		return
	_apply_setup(label_text, hint_text, enabled, disabled_reason)


func _pending_setup_apply(label_text: String, hint_text: String,
		enabled: bool, disabled_reason: String) -> void:
	_apply_setup(label_text, hint_text, enabled, disabled_reason)


func _apply_setup(label_text: String, hint_text: String,
		enabled: bool, disabled_reason: String) -> void:
	if _label_main:
		_label_main.text = label_text
		_label_main.add_theme_color_override("font_color",
			COLOR_TEXT_DISABLED if not enabled else COLOR_TEXT_PRIMARY)
	if _label_hint:
		if hint_text.is_empty():
			_label_hint.visible = false
		else:
			_label_hint.text = hint_text
			_label_hint.visible = true
	disabled = not enabled
	tooltip_text = disabled_reason if not enabled else ""


func _on_pressed() -> void:
	choice_pressed.emit(_choice_id)
