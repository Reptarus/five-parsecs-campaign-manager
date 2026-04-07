class_name InlineRenameWidget
extends VBoxContainer

## Two-mode inline rename widget: display (name + "tap to rename" hint)
## and edit (LineEdit + confirm/cancel). Self-documenting affordance.
## Inspired by Fallout Wasteland Warfare "(Tap here to rename)" pattern.

signal name_confirmed(new_name: String)

var current_name: String = "":
	set(v):
		current_name = v
		if _name_label:
			_name_label.text = v

var placeholder: String = "Enter name..."
var max_length: int = 40

var _name_label: Label
var _hint_label: Label
var _display_container: VBoxContainer
var _edit_container: HBoxContainer
var _line_edit: LineEdit
var _is_editing: bool = false

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	add_theme_constant_override("separation", 0)

	# ── Display mode ──────────────────────────────────────
	_display_container = VBoxContainer.new()
	_display_container.add_theme_constant_override("separation", 0)
	_display_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_display_container.gui_input.connect(_on_display_input)
	add_child(_display_container)

	_name_label = Label.new()
	_name_label.text = current_name
	_name_label.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_XL
	)
	_name_label.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display_container.add_child(_name_label)

	_hint_label = Label.new()
	_hint_label.text = "(tap to rename)"
	_hint_label.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_XS
	)
	_hint_label.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_MUTED
	)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display_container.add_child(_hint_label)

	# ── Edit mode (hidden initially) ─────────────────────
	_edit_container = HBoxContainer.new()
	_edit_container.add_theme_constant_override(
		"separation", UIColors.SPACING_XS
	)
	_edit_container.visible = false
	add_child(_edit_container)

	_line_edit = LineEdit.new()
	_line_edit.placeholder_text = placeholder
	_line_edit.max_length = max_length
	_line_edit.custom_minimum_size = Vector2(
		200, UIColors.TOUCH_TARGET_MIN
	)
	_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line_edit.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_LG
	)
	_line_edit.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)
	var le_style := StyleBoxFlat.new()
	le_style.bg_color = UIColors.COLOR_INPUT
	le_style.border_color = UIColors.COLOR_CYAN
	le_style.set_border_width_all(1)
	le_style.set_corner_radius_all(4)
	le_style.content_margin_left = UIColors.SPACING_SM
	le_style.content_margin_right = UIColors.SPACING_SM
	_line_edit.add_theme_stylebox_override("normal", le_style)
	_line_edit.text_submitted.connect(_on_text_submitted)
	_edit_container.add_child(_line_edit)

	# Confirm button
	var confirm_btn := Button.new()
	confirm_btn.text = "✓"
	confirm_btn.custom_minimum_size = Vector2(
		UIColors.TOUCH_TARGET_MIN, UIColors.TOUCH_TARGET_MIN
	)
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = UIColors.COLOR_EMERALD.darkened(0.4)
	confirm_style.border_color = UIColors.COLOR_EMERALD
	confirm_style.set_border_width_all(1)
	confirm_style.set_corner_radius_all(4)
	confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	confirm_btn.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)
	confirm_btn.pressed.connect(_confirm_rename)
	_edit_container.add_child(confirm_btn)

	# Cancel button
	var cancel_btn := Button.new()
	cancel_btn.text = "✕"
	cancel_btn.custom_minimum_size = Vector2(
		UIColors.TOUCH_TARGET_MIN, UIColors.TOUCH_TARGET_MIN
	)
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = UIColors.COLOR_RED.darkened(0.6)
	cancel_style.border_color = UIColors.COLOR_RED
	cancel_style.set_border_width_all(1)
	cancel_style.set_corner_radius_all(4)
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	cancel_btn.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)
	cancel_btn.pressed.connect(_cancel_rename)
	_edit_container.add_child(cancel_btn)

func _on_display_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_enter_edit_mode()
	elif event is InputEventScreenTouch and event.pressed:
		_enter_edit_mode()

func _enter_edit_mode() -> void:
	if _is_editing:
		return
	_is_editing = true
	_display_container.visible = false
	_edit_container.visible = true
	_line_edit.text = current_name
	_line_edit.grab_focus()
	_line_edit.select_all()
	TweenFX.fold_in(_edit_container, 0.2)

func _on_text_submitted(_text: String) -> void:
	_confirm_rename()

func _confirm_rename() -> void:
	var new_text: String = _line_edit.text.strip_edges()
	if new_text.is_empty():
		# Reject empty — shake the input
		TweenFX.headshake(_line_edit, 0.4, 6.0, 3)
		return
	current_name = new_text
	name_confirmed.emit(new_text)
	_exit_edit_mode()

func _cancel_rename() -> void:
	_exit_edit_mode()

func _exit_edit_mode() -> void:
	_is_editing = false
	_edit_container.visible = false
	_display_container.visible = true

func _unhandled_key_input(event: InputEvent) -> void:
	if _is_editing and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_cancel_rename()
			get_viewport().set_input_as_handled()

## Configure the widget. Returns self for chaining.
func setup(name_text: String, hint: String = "(tap to rename)") -> InlineRenameWidget:
	current_name = name_text
	if _hint_label:
		_hint_label.text = hint
	return self
