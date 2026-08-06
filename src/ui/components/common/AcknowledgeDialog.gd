class_name AcknowledgeDialog
extends Window

## Titleless acknowledgement modal.
## The message IS the body — no title bar text, single "OK" button.
## Sized for short blockers ("Not enough credits", "Cannot do that") but it now
## GROWS to fit longer copy: the fixed 200px height silently clipped anything
## past ~4 lines and pushed the OK button off the window, leaving the X as the
## only way out. Found when the Story Track's outcome prose landed here.
## Inspired by Fallout Wasteland Warfare companion app error modals.

signal acknowledged

## Baseline for a one-or-two-line blocker.
const MIN_HEIGHT := 200
## Never grow past this share of the screen; beyond it the body scrolls.
const MAX_HEIGHT_RATIO := 0.7

var _message_label: Label
var _scroll: ScrollContainer
var _pending_text: String = ""

func _init() -> void:
	title = ""
	size = Vector2i(380, MIN_HEIGHT)
	transient = true
	exclusive = true
	unresizable = true
	close_requested.connect(_on_ok_pressed)

func _ready() -> void:
	_build_ui()
	if not _pending_text.is_empty():
		_message_label.text = _pending_text
	# Deferred: the label reports no useful minimum size until it has been laid
	# out once at the window's width, which autowrap depends on.
	_fit_to_content.call_deferred()

func _fit_to_content() -> void:
	if _message_label == null or not is_instance_valid(_message_label):
		return
	await get_tree().process_frame
	if not is_instance_valid(self) or not is_instance_valid(_message_label):
		return

	var text_h: int = int(ceil(_message_label.get_minimum_size().y))
	# Body + OK button + separation + top/bottom margins.
	var chrome_h: int = UIColors.TOUCH_TARGET_COMFORT + UIColors.SPACING_MD \
		+ UIColors.SPACING_LG + UIColors.SPACING_MD
	var desired: int = text_h + chrome_h

	var screen_h: int = DisplayServer.screen_get_size().y
	var max_h: int = int(screen_h * MAX_HEIGHT_RATIO)
	var final_h: int = clampi(desired, MIN_HEIGHT, max_h)
	if final_h != size.y:
		size = Vector2i(size.x, final_h)
		move_to_center()

func _build_ui() -> void:
	# Background
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_BASE
	style.border_color = UIColors.COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	# Margin
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UIColors.SPACING_LG)
	margin.add_theme_constant_override("margin_right", UIColors.SPACING_LG)
	margin.add_theme_constant_override("margin_top", UIColors.SPACING_LG)
	margin.add_theme_constant_override("margin_bottom", UIColors.SPACING_MD)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", UIColors.SPACING_MD)
	margin.add_child(vbox)

	# Message label — this IS the content, no title.
	# Inside a ScrollContainer so copy longer than MAX_HEIGHT_RATIO of the screen
	# stays reachable instead of being clipped away with no way to read it.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll)

	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_message_label.add_theme_font_size_override(
		"font_size", ScreenChrome.font_size(UIColors.FONT_SIZE_LG))
	_message_label.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)
	_scroll.add_child(_message_label)

	# OK button
	var ok_btn := Button.new()
	ok_btn.text = "OK"
	ok_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_COMFORT)
	ok_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = UIColors.COLOR_ACCENT
	btn_style.set_corner_radius_all(4)
	ok_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = UIColors.COLOR_ACCENT_HOVER
	btn_hover.set_corner_radius_all(4)
	ok_btn.add_theme_stylebox_override("hover", btn_hover)
	# Derive pressed/disabled/focus from the box above so this button keeps
	# its shape when it is clicked. See DialogStyles.complete_button_states.
	DialogStyles.complete_button_states(ok_btn)

	ok_btn.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)
	ok_btn.add_theme_font_size_override("font_size", ScreenChrome.font_size(UIColors.FONT_SIZE_MD))
	ok_btn.pressed.connect(_on_ok_pressed)
	vbox.add_child(ok_btn)

func _on_ok_pressed() -> void:
	acknowledged.emit()
	queue_free()

## Show a simple message. Adds self to parent, centers, and displays.
static func show_message(
	parent: Node, text: String
) -> AcknowledgeDialog:
	var _Self = load("res://src/ui/components/common/AcknowledgeDialog.gd")
	var dialog = _Self.new()
	dialog._pending_text = text
	parent.add_child(dialog)
	dialog.popup_centered()
	return dialog
