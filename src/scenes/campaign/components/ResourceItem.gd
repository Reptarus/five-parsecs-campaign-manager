@tool
extends Control
class_name ResourceItem

# Signals
signal resource_clicked(resource_name: String, current_value: int)

# Node references
@onready var name_label: Label = $HBoxContainer/NameLabel
@onready var value_label: Label = $HBoxContainer/ValueLabel
@onready var trend_indicator: TextureRect = $HBoxContainer/TrendIndicator
@onready var progress_bar: ProgressBar = $ProgressBar

# Properties
var resource_name: String = ""
var current_value: int = 0
var max_value: int = 100
var trend: int = 0
var resource_color: Color = Color.WHITE

func _ready() -> void:
	_setup_ui()
	_update_display()

func _setup_ui() -> void:
	custom_minimum_size = Vector2(0, 40)
	
	# Set up progress bar
	if progress_bar:
		progress_bar.min_value = 0
		progress_bar.max_value = max_value
		progress_bar.value = current_value
		progress_bar.modulate = resource_color
		
	# Set up trend indicator
	if trend_indicator:
		trend_indicator.modulate = resource_color

func _update_display() -> void:
	if not is_inside_tree():
		return
		
	if name_label:
		name_label.text = resource_name.capitalize()
		
	if value_label:
		value_label.text = str(current_value)
		if max_value != 9999:  # Don't show max for credits
			value_label.text += "/" + str(max_value)
			
	if progress_bar:
		progress_bar.max_value = max_value
		progress_bar.value = current_value
		
	if trend_indicator:
		_update_trend_indicator()

func _update_trend_indicator() -> void:
	if not trend_indicator:
		return
		
	match trend:
		1:  # Increasing
			trend_indicator.rotation_degrees = 0
			trend_indicator.modulate.a = 1.0
		-1:  # Decreasing
			trend_indicator.rotation_degrees = 180
			trend_indicator.modulate.a = 1.0
		_:  # Stable
			trend_indicator.modulate.a = 0.0

# Public methods
func setup(name: String, current: int, max_val: int, trend_val: int, color: Color) -> void:
	resource_name = name
	current_value = current
	max_value = max_val
	trend = trend_val
	resource_color = color
	
	if is_inside_tree():
		_setup_ui()
		_update_display()

# Input handling
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			emit_signal("resource_clicked", resource_name, current_value)

# Animation methods
func highlight(duration: float = 0.3) -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.5, duration * 0.5)
	tween.tween_property(self, "modulate:a", 1.0, duration * 0.5)

func animate_value_change(new_value: int, duration: float = 0.5) -> void:
	var tween = create_tween()
	tween.tween_method(
		func(val: int): 
			current_value = val
			_update_display(),
		current_value,
		new_value,
		duration
	) 
