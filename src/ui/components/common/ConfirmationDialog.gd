extends Window
class_name FPCMConfirmationDialog

## Confirmation Dialog - Deep Space Design System
## Reusable confirmation component for destructive actions
## Sprint D: Safety & Validation

signal confirmed
signal cancelled

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
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_ACCENT_HOVER := Color("#3A7199")

const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")

const COLOR_SUCCESS := Color("#10B981")
const COLOR_DANGER := Color("#DC2626")
const COLOR_DANGER_HOVER := Color("#EF4444")

# UI References
var message_label: Label
var confirm_button: Button
var cancel_button: Button

# State
var _is_destructive: bool = false
var _pending_confirmation: bool = false

func _ready() -> void:
	size = Vector2i(400, 250)
	unresizable = true
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

	close_requested.connect(_on_cancel_pressed)

func _create_ui() -> void:
	# Main margin container
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

	# === MESSAGE AREA ===
	var message_container := _create_message_container()
	vbox.add_child(message_container)

	# Spacer to push buttons to bottom
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# === ACTION BUTTONS ===
	var buttons := _create_action_buttons()
	vbox.add_child(buttons)

func _create_message_container() -> VBoxContainer:
	## Create the message display area.
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", SPACING_MD)
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Message label
	message_label = Label.new()
	message_label.text = "Are you sure you want to proceed?"
	message_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	message_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(message_label)

	return container

func _create_action_buttons() -> HBoxContainer:
	## Create styled action buttons matching design system.
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", SPACING_SM)
	container.alignment = BoxContainer.ALIGNMENT_END

	# Cancel button
	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(100, TOUCH_TARGET_MIN)

	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = COLOR_BORDER
	cancel_style.set_corner_radius_all(6)
	cancel_style.set_content_margin_all(SPACING_SM)
	cancel_button.add_theme_stylebox_override("normal", cancel_style)
	cancel_button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	cancel_button.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	cancel_button.pressed.connect(_on_cancel_pressed)
	container.add_child(cancel_button)

	# Confirm button (styled based on destructive flag)
	confirm_button = Button.new()
	confirm_button.text = "Confirm"
	confirm_button.custom_minimum_size = Vector2(140, TOUCH_TARGET_COMFORT)
	confirm_button.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	confirm_button.pressed.connect(_on_confirm_pressed)
	container.add_child(confirm_button)

	_update_confirm_button_style()

	return container

func _update_confirm_button_style() -> void:
	## Update confirm button styling based on destructive flag.
	if not confirm_button:
		return

	var bg_color: Color
	var hover_color: Color

	if _is_destructive:
		bg_color = COLOR_DANGER
		hover_color = COLOR_DANGER_HOVER
	else:
		bg_color = COLOR_SUCCESS
		hover_color = COLOR_ACCENT_HOVER

	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = bg_color
	confirm_style.set_corner_radius_all(6)
	confirm_style.set_content_margin_all(SPACING_SM)
	confirm_button.add_theme_stylebox_override("normal", confirm_style)

	var confirm_hover := confirm_style.duplicate()
	confirm_hover.bg_color = hover_color
	confirm_button.add_theme_stylebox_override("hover", confirm_hover)

	confirm_button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

## Show confirmation dialog with custom message
## @param dialog_title: Window title
## @param message: Message to display
## @param confirm_text: Text for confirm button (default: "Confirm")
## @param destructive: If true, confirm button shows in red (default: false)
func show_confirmation(dialog_title: String, message: String, confirm_text: String = "Confirm", destructive: bool = false) -> void:
	title = dialog_title
	_is_destructive = destructive
	_pending_confirmation = true

	if message_label:
		message_label.text = message

	if confirm_button:
		confirm_button.text = confirm_text

	_update_confirm_button_style()
	popup_centered()

## Async method to wait for user response
## Returns true if confirmed, false if cancelled
func await_confirmation(dialog_title: String, message: String, confirm_text: String = "Confirm", destructive: bool = false) -> bool:
	show_confirmation(dialog_title, message, confirm_text, destructive)

	# Wait for either signal
	var result = await _wait_for_response()
	return result

func _wait_for_response() -> bool:
	# Create a signal to wait on
	while _pending_confirmation:
		await get_tree().create_timer(0.05).timeout
		if not is_visible():
			return false
	return _last_result

var _last_result: bool = false

func _on_confirm_pressed() -> void:
	_pending_confirmation = false
	_last_result = true
	confirmed.emit()
	hide()

func _on_cancel_pressed() -> void:
	_pending_confirmation = false
	_last_result = false
	cancelled.emit()
	hide()
