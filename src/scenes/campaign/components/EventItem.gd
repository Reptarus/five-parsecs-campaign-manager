@tool
extends Control
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/scenes/campaign/components/EventItem.gd")

# Signals
signal event_selected(event_id: String)

# Node references
@onready var title_label: Label = $MarginContainer/VBoxContainer/Header/Title
@onready var timestamp_label: Label = $MarginContainer/VBoxContainer/Header/Timestamp
@onready var description_label: Label = $MarginContainer/VBoxContainer/Description
@onready var category_indicator: ColorRect = $CategoryIndicator
@onready var background: Panel = $Background

# Properties
var event_id: String = ""
var event_color: Color = Color.WHITE:
	set(value):
		event_color = value
		if category_indicator:
			category_indicator.color = value

func _ready() -> void:
	_setup_ui()
	_connect_signals()

func _setup_ui() -> void:
	custom_minimum_size = Vector2(0, 80)
	
	if background:
		background.mouse_filter = Control.MOUSE_FILTER_PASS
	
	if category_indicator:
		category_indicator.color = event_color
		
	if title_label:
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
	if timestamp_label:
		timestamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		timestamp_label.modulate = Color(1, 1, 1, 0.6)
		
	if description_label:
		description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _connect_signals() -> void:
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			emit_signal("event_selected", event_id)

# Public methods
func setup(id: String, title: String, description: String, timestamp: int, color: Color) -> void:
	event_id = id
	event_color = color
	
	if title_label:
		title_label.text = title
		
	if description_label:
		description_label.text = description
		
	if timestamp_label:
		timestamp_label.text = _format_timestamp(timestamp)

func _format_timestamp(timestamp: int) -> String:
	var datetime = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%02d:%02d" % [datetime.hour, datetime.minute]

# Animation methods
func highlight(duration: float = 0.3) -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.5, duration * 0.5)
	tween.tween_property(self, "modulate:a", 1.0, duration * 0.5)

func fade_in(delay: float = 0.0) -> void:
	modulate.a = 0.0
	var tween = create_tween()
	if delay > 0:
		tween.tween_interval(delay)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)