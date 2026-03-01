class_name ValidationPanel
extends PanelContainer

## Reusable validation feedback component for forms across the campaign manager
##
## Usage:
##   var validation_panel = ValidationPanel.new()
##   add_child(validation_panel)
##   validation_panel.show_feedback(ValidationPanel.FeedbackType.ERROR, ["Message 1", "Message 2"])
##
## Design:
##   - Success: Green border, dark green background, ✅ icon
##   - Error: Red border, dark red background, ❌ icon
##   - Warning: Orange border, dark orange background, ⚠️ icon
##   - Responsive: Messages autowrap for long text

# ENUMS
enum FeedbackType {
	SUCCESS,  ## Green styling, checkmark icon
	ERROR,    ## Red styling, X icon
	WARNING   ## Orange styling, warning icon
}

# DESIGN SYSTEM CONSTANTS
const SPACING_XS := 4
const SPACING_SM := 8
const SPACING_MD := 16
const FONT_SIZE_SM := 14
const FONT_SIZE_LG := 18
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER := Color("#DC2626")

# STATE
var feedback_type: FeedbackType = FeedbackType.SUCCESS
var messages: PackedStringArray = []

# UI REFERENCES
@onready var _main_container: VBoxContainer
@onready var _header_container: HBoxContainer
@onready var _icon_label: Label
@onready var _title_label: Label
@onready var _message_container: VBoxContainer

# LIFECYCLE
func _ready() -> void:
	_setup_ui()
	_update_display()

# PUBLIC INTERFACE
## Main entry point - updates panel with new feedback type and messages
func show_feedback(type: FeedbackType, msgs: PackedStringArray) -> void:
	feedback_type = type
	messages = msgs
	# Only update display if we're in the scene tree and UI is ready
	if is_inside_tree():
		_update_display()

# UI CONSTRUCTION
func _setup_ui() -> void:
	# Main container
	_main_container = VBoxContainer.new()
	_main_container.add_theme_constant_override("separation", SPACING_SM)
	add_child(_main_container)

	# Header (icon + title)
	_header_container = HBoxContainer.new()
	_header_container.add_theme_constant_override("separation", SPACING_SM)
	_main_container.add_child(_header_container)

	# Icon label
	_icon_label = Label.new()
	_icon_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_header_container.add_child(_icon_label)

	# Title label
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_container.add_child(_title_label)

	# Message container
	_message_container = VBoxContainer.new()
	_message_container.add_theme_constant_override("separation", SPACING_XS)
	_main_container.add_child(_message_container)

# UI UPDATES
## Refreshes all UI elements based on current feedback_type and messages
func _update_display() -> void:
	# Ensure UI is set up before updating (can be called before _ready)
	if not is_instance_valid(_icon_label) or not is_instance_valid(_title_label) or not is_instance_valid(_message_container):
		return

	# Update panel styling
	add_theme_stylebox_override("panel", _get_style_for_type(feedback_type))

	# Update icon and title
	match feedback_type:
		FeedbackType.SUCCESS:
			_icon_label.text = "✅"
			_title_label.text = "Campaign Ready to Launch"
		FeedbackType.ERROR:
			_icon_label.text = "❌"
			_title_label.text = "Campaign Incomplete"
		FeedbackType.WARNING:
			_icon_label.text = "⚠️"
			_title_label.text = "Review Required"

	# Clear existing messages
	for child in _message_container.get_children():
		child.queue_free()

	# Add new messages or default message
	if messages.is_empty():
		if feedback_type == FeedbackType.SUCCESS:
			_add_message_label("All required sections complete")
	else:
		for msg in messages:
			_add_message_label("• " + msg)

## Creates and configures a message label
func _add_message_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_container.add_child(label)

# STYLING
## Returns a configured StyleBoxFlat for the given feedback type
func _get_style_for_type(type: FeedbackType) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	# Corner radius
	style.set_corner_radius_all(8)

	# Content margins
	style.content_margin_left = SPACING_MD
	style.content_margin_right = SPACING_MD
	style.content_margin_top = SPACING_MD
	style.content_margin_bottom = SPACING_MD

	# Type-specific colors
	var border_color: Color
	var bg_color: Color

	match type:
		FeedbackType.SUCCESS:
			border_color = COLOR_SUCCESS
			bg_color = COLOR_SUCCESS.darkened(0.7)
		FeedbackType.ERROR:
			border_color = COLOR_DANGER
			bg_color = COLOR_DANGER.darkened(0.7)
		FeedbackType.WARNING:
			border_color = COLOR_WARNING
			bg_color = COLOR_WARNING.darkened(0.7)

	# Apply colors
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2

	return style
