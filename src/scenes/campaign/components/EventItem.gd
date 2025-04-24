@tool
extends Control
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/scenes/campaign/components/EventItem.gd")

# Signals
signal event_selected(event_id: String)
signal value_changed(new_value: String)
signal action_triggered(action: String)

# Node references
@onready var title_label: Label = $MarginContainer/VBoxContainer/Header/Title if has_node("MarginContainer/VBoxContainer/Header/Title") else null
@onready var timestamp_label: Label = $MarginContainer/VBoxContainer/Header/Timestamp if has_node("MarginContainer/VBoxContainer/Header/Timestamp") else null
@onready var description_label: Label = $MarginContainer/VBoxContainer/Description if has_node("MarginContainer/VBoxContainer/Description") else null
@onready var category_indicator: ColorRect = $CategoryIndicator if has_node("CategoryIndicator") else null
@onready var background: Panel = $Background if has_node("Background") else null
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

# Properties
var event_id: String = ""
var event_color: Color = Color.WHITE:
	set(value):
		event_color = value
		if is_instance_valid(category_indicator):
			category_indicator.color = value

func _ready() -> void:
	if not is_inside_tree():
		return
		
	_setup_ui()
	_connect_signals()

func _setup_ui() -> void:
	custom_minimum_size = Vector2(0, 80)
	
	if is_instance_valid(background):
		background.mouse_filter = Control.MOUSE_FILTER_PASS
	
	if is_instance_valid(category_indicator):
		category_indicator.color = event_color
		
	if is_instance_valid(title_label):
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
	if is_instance_valid(timestamp_label):
		timestamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		timestamp_label.modulate = Color(1, 1, 1, 0.6)
		
	if is_instance_valid(description_label):
		description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		if description_label.has_method("set_autowrap_mode"):
			description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if description_label.has_method("set_text_overrun_behavior"):
			description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _connect_signals() -> void:
	if has_signal("gui_input") and gui_input.is_connected(_on_gui_input):
		gui_input.disconnect(_on_gui_input)
	
	if has_signal("gui_input"):
		gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if not is_inside_tree() or event_id.is_empty():
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if has_signal("event_selected") and not event_id.is_empty():
				event_selected.emit(event_id)

# Public methods
func setup(id: String, title: String, description: String, timestamp: int, color: Color) -> void:
	event_id = id
	event_color = color
	
	if is_instance_valid(title_label):
		title_label.text = title
		
	if is_instance_valid(description_label):
		description_label.text = description
		
	if is_instance_valid(timestamp_label):
		timestamp_label.text = _format_timestamp(timestamp)
		
	if is_instance_valid(category_indicator):
		category_indicator.color = color

func _format_timestamp(timestamp: int) -> String:
	if timestamp <= 0:
		return ""
		
	var datetime = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%02d:%02d" % [datetime.hour, datetime.minute]

# Animation methods
func highlight(duration: float = 0.3) -> void:
	if not is_inside_tree():
		return
		
	if is_instance_valid(animation_player) and animation_player.has_animation("highlight"):
		animation_player.play("highlight")
		return
		
	var tween = create_tween()
	if tween:
		tween.tween_property(self, "modulate:a", 0.5, duration * 0.5)
		tween.tween_property(self, "modulate:a", 1.0, duration * 0.5)

func fade_in(delay: float = 0.0) -> void:
	if not is_inside_tree():
		return
		
	if is_instance_valid(animation_player) and animation_player.has_animation("fade_in"):
		if delay > 0:
			await get_tree().create_timer(delay).timeout
		animation_player.play("fade_in")
		return
		
	modulate.a = 0.0
	var tween = create_tween()
	if tween:
		if delay > 0:
			tween.tween_interval(delay)
		tween.tween_property(self, "modulate:a", 1.0, 0.3)

func play_highlight_animation() -> void:
	highlight()

# Getter/setter methods
func set_value(title_text: String) -> void:
	if is_instance_valid(title_label):
		title_label.text = title_text
	
	if has_signal("value_changed"):
		value_changed.emit(title_text)

func get_current_value() -> String:
	if is_instance_valid(title_label):
		return title_label.text
	return ""

func set_timestamp(timestamp_text: String) -> void:
	if is_instance_valid(timestamp_label):
		timestamp_label.text = timestamp_text

func set_text_color(color: Color) -> void:
	if is_instance_valid(title_label):
		title_label.add_theme_color_override("font_color", color)
		
	if is_instance_valid(timestamp_label):
		timestamp_label.add_theme_color_override("font_color", color)

func add_action(action_text: String) -> void:
	# This method would be called to add clickable actions to the event item
	# Implementation depends on UI design for actions
	pass

func trigger_action(action: String) -> void:
	if has_signal("action_triggered"):
		action_triggered.emit(action)