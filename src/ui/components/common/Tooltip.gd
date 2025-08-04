class_name Tooltip
extends Control

## Universal Tooltip System for Five Parsecs Campaign Manager
## Provides contextual help and information throughout the UI

signal tooltip_shown(text: String)
signal tooltip_hidden()

@onready var background: NinePatchRect = $Background
@onready var label: RichTextLabel = $Background/Label
@onready var arrow: Polygon2D = $Arrow

var target_control: Control = null
var tooltip_content: String = ""
var show_delay: float = 0.5
var hide_delay: float = 0.1
var show_timer: Timer
var hide_timer: Timer
var fade_tween: Tween

# Tooltip positioning
enum Position {
	AUTO,
	TOP,
	BOTTOM,
	LEFT,
	RIGHT,
	TOP_LEFT,
	TOP_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_RIGHT
}

var preferred_position: Position = Position.AUTO
var margin: float = 10.0
var max_width: float = 300.0

func _ready() -> void:
	_setup_ui()
	_setup_timers()
	visible = false
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _setup_ui() -> void:
	"""Setup the tooltip visual appearance"""
	# Background setup
	if not background:
		background = NinePatchRect.new()
		add_child(background)

	background.patch_margin_left = 8
	background.patch_margin_right = 8
	background.patch_margin_top = 8
	background.patch_margin_bottom = 8

	# Label setup
	if not label:
		label = RichTextLabel.new()
		background.add_child(label)

	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.selection_enabled = false
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_constant_override("margin_left", 8)
	label.add_theme_constant_override("margin_right", 8)
	label.add_theme_constant_override("margin_top", 6)
	label.add_theme_constant_override("margin_bottom", 6)

	# Arrow setup for directional pointing
	if not arrow:
		arrow = Polygon2D.new()
		add_child(arrow)

	_update_arrow_shape()

func _setup_timers() -> void:
	"""Setup show/hide timers"""
	show_timer = Timer.new()
	show_timer.wait_time = show_delay
	show_timer.one_shot = true
	show_timer.timeout.connect(_show_tooltip)
	add_child(show_timer)

	hide_timer = Timer.new()
	hide_timer.wait_time = hide_delay
	hide_timer.one_shot = true
	hide_timer.timeout.connect(_hide_tooltip)
	add_child(hide_timer)

func _update_arrow_shape() -> void:
	"""Update arrow shape based on position"""
	var arrow_points = PackedVector2Array()
	var arrow_size: int = 8

	# Default downward arrow (tooltip above target)

	arrow_points.append(Vector2(0, 0))

	arrow_points.append(Vector2(arrow_size, -arrow_size))

	arrow_points.append(Vector2(-arrow_size, -arrow_size))

	arrow.polygon = arrow_points
	arrow.color = Color(0.2, 0.2, 0.2, 0.9) # Dark semi-transparent

## ===== PUBLIC API =====

func show_tooltip(text: String, target: Control, position: Position = Position.AUTO) -> void:
	"""Show tooltip with specified text at target control"""
	tooltip_content = text
	target_control = target
	preferred_position = position

	if (safe_call_method(text, "is_empty") == true):
		hide_tooltip()
		return

	# Cancel any pending hide
	hide_timer.stop()

	# Start show timer if not already visible
	if not visible:
		show_timer.start()
	else:
		_update_tooltip_content()
		_position_tooltip()

func hide_tooltip() -> void:
	"""Hide the tooltip"""
	show_timer.stop()
	hide_timer.start()

func show_immediately(text: String, target: Control, position: Position = Position.AUTO) -> void:
	"""Show tooltip immediately without delay"""
	tooltip_content = text
	target_control = target
	preferred_position = position

	show_timer.stop()
	hide_timer.stop()
	_show_tooltip()

func set_delays(show_delay_time: float, hide_delay_time: float) -> void:
	"""Set custom show/hide delays"""
	show_delay = show_delay_time
	hide_delay = hide_delay_time
	show_timer.wait_time = show_delay
	hide_timer.wait_time = hide_delay

## ===== INTERNAL METHODS =====

func _show_tooltip() -> void:
	"""Internal method to show the tooltip"""
	if (safe_call_method(tooltip_content, "is_empty") == true) or not target_control:
		return

	_update_tooltip_content()
	_position_tooltip()

	visible = true

	# Animate fade in
	if fade_tween:
		fade_tween.kill()

	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, 0.2)

	tooltip_shown.emit(tooltip_content) # warning: return value discarded (intentional)

func _hide_tooltip() -> void:
	"""Internal method to hide the tooltip"""
	if fade_tween:
		fade_tween.kill()

	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.15)
	fade_tween.tween_callback(func(): visible = false)

	tooltip_hidden.emit() # warning: return value discarded (intentional)

func _update_tooltip_content() -> void:
	"""Update the tooltip content and size"""
	if not label:
		return

	label.text = tooltip_content

	# Calculate size needed
	var content_size = label.get_content_height()
	var label_width = min(max_width, _estimate_text_width(tooltip_content))

	background.size = Vector2(label_width + 16, content_size + 12)
	size = background.size

func _estimate_text_width(text: String) -> float:
	"""Estimate width needed for text"""
	# Simple estimation - could be improved with actual text measurement
	var char_width: int = 8 # Average character width
	var lines = text.split("\n")
	var max_line_length: int = 0

	for line in lines:
		# Remove BBCode tags for length calculation
		var clean_line = line.strip_edges()
		clean_line = clean_line.replace("[/b]", "").replace("[b]", "")
		clean_line = clean_line.replace("[/i]", "").replace("[i]", "")
		max_line_length = max(max_line_length, clean_line.length())

	return min(max_width, max_line_length * char_width + 20)

func _position_tooltip() -> void:
	"""Position the tooltip relative to target"""
	if not target_control:
		return

	var target_rect = target_control.get_global_rect()
	var tooltip_size = background.size
	var screen_size = get_viewport().get_visible_rect().size

	var pos = Vector2()
	var final_position = preferred_position

	# Auto-position if requested
	if final_position == Position.AUTO:
		final_position = _calculate_best_position(target_rect, tooltip_size, screen_size)

	# Calculate position based on determined position
	match final_position:
		Position.TOP:
			pos = Vector2(
				target_rect.position.x + target_rect.size.x / 2.0 - tooltip_size.x / 2.0,
				target_rect.position.y - tooltip_size.y - margin
			)
		Position.BOTTOM:
			pos = Vector2(
				target_rect.position.x + target_rect.size.x / 2.0 - tooltip_size.x / 2.0,
				target_rect.position.y + target_rect.size.y + margin
			)
		Position.LEFT:
			pos = Vector2(
				target_rect.position.x - tooltip_size.x - margin,
				target_rect.position.y + target_rect.size.y / 2.0 - tooltip_size.y / 2.0
			)
		Position.RIGHT:
			pos = Vector2(
				target_rect.position.x + target_rect.size.x + margin,
				target_rect.position.y + target_rect.size.y / 2.0 - tooltip_size.y / 2.0
			)
		Position.TOP_RIGHT:
			pos = Vector2(
				target_rect.position.x + target_rect.size.x + margin,
				target_rect.position.y - tooltip_size.y - margin
			)
		_: # Default to bottom
			pos = Vector2(
				target_rect.position.x + target_rect.size.x / 2.0 - tooltip_size.x / 2.0,
				target_rect.position.y + target_rect.size.y + margin
			)

	# Clamp to screen bounds
	pos.x = clamp(pos.x, margin, screen_size.x - tooltip_size.x - margin)
	pos.y = clamp(pos.y, margin, screen_size.y - tooltip_size.y - margin)

	global_position = pos
	_update_arrow_position(final_position, target_rect)

func _calculate_best_position(target_rect: Rect2, tooltip_size: Vector2, screen_size: Vector2) -> Position:
	"""Calculate the best position based on available space"""
	var space_above = target_rect.position.y
	var space_below = screen_size.y - (target_rect.position.y + target_rect.size.y)
	var space_left = target_rect.position.x
	var space_right = screen_size.x - (target_rect.position.x + target_rect.size.x)

	# Prefer bottom if there's space, otherwise top
	if space_below >= tooltip_size.y + margin:
		return Position.BOTTOM
	elif space_above >= tooltip_size.y + margin:
		return Position.TOP
	elif space_right >= tooltip_size.x + margin:
		return Position.RIGHT
	elif space_left >= tooltip_size.x + margin:
		return Position.LEFT
	else:
		return Position.BOTTOM # Fallback

func _update_arrow_position(pos: Position, target_rect: Rect2) -> void:
	"""Update arrow position and rotation based on tooltip position"""
	if not arrow:
		return

	var arrow_offset = Vector2()
	var rotation_deg: int = 0

	match pos:
		Position.TOP:
			arrow_offset = Vector2(background.size.x / 2.0, background.size.y)
			rotation_deg = 180
		Position.BOTTOM:
			arrow_offset = Vector2(background.size.x / 2.0, 0)
			rotation_deg = 0
		Position.LEFT:
			arrow_offset = Vector2(background.size.x, background.size.y / 2.0)
			rotation_deg = 90
		Position.RIGHT:
			arrow_offset = Vector2(0, background.size.y / 2.0)
			rotation_deg = -90
		_:
			arrow_offset = Vector2(background.size.x / 2.0, 0)
			rotation_deg = 0

	arrow.position = arrow_offset
	arrow.rotation_degrees = rotation_deg

## ===== STATIC HELPER METHODS =====

static func create_tooltip_for_control(control: Control, text: String, position: Position = Position.AUTO) -> Tooltip:
	"""Create and attach a tooltip to a control"""
	var tooltip := Tooltip.new()
	control.get_tree().current_scene.add_child(tooltip)

	# Connect mouse events
	control.mouse_entered.connect(func(): tooltip.show_tooltip(text, control, position))
	control.mouse_exited.connect(func(): tooltip.hide_tooltip())

	return tooltip

static func add_tooltip_to_control(control: Control, text: String, position: Position = Position.AUTO):
	"""Add tooltip functionality to an existing control"""
	var tooltip = create_tooltip_for_control(control, text, position)
	control.set_meta("tooltip", tooltip)
	return tooltip

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null