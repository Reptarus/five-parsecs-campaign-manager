@tool
extends Control
class_name BarChart

## Bar Chart Component for Data Visualization
## Provides bar chart rendering for campaign analytics

signal chart_updated(data: Dictionary)
signal bar_selected(index: int, value: float)

@export var bar_color: Color = Color.CYAN
@export var bar_outline_color: Color = Color.WHITE
@export var background_color: Color = Color.TRANSPARENT
@export var grid_color: Color = Color.GRAY
@export var show_grid: bool = true
@export var bar_spacing: float = 4.0

var chart_data: Array[float] = []
var chart_labels: Array[String] = []
var _title: String = ""
var _x_label: String = ""
var _y_label: String = ""

func set_data(data: Array[float], labels: Array[String] = [], title: String = "", x_label: String = "", y_label: String = "") -> void:
	chart_data = data.duplicate()
	chart_labels = labels.duplicate()
	_title = title
	_x_label = x_label
	_y_label = y_label
	
	# Generate default labels if none provided
	if chart_labels.is_empty():
		for i in range(chart_data.size()):
			chart_labels.append(str(i + 1))
	
	queue_redraw()
	chart_updated.emit({"data": data, "labels": labels, "title": title})

func add_bar(value: float, label: String = "") -> void:
	chart_data.append(value)
	if label.is_empty():
		chart_labels.append(str(chart_data.size()))
	else:
		chart_labels.append(label)
	queue_redraw()

func clear_data() -> void:
	chart_data.clear()
	chart_labels.clear()
	queue_redraw()

func _draw() -> void:
	if chart_data.is_empty():
		return
	
	var rect = get_rect()
	
	# Draw background
	if background_color.a > 0:
		draw_rect(rect, background_color)
	
	# Calculate bounds
	var max_value = chart_data.max() if chart_data.size() > 0 else 1.0
	var min_value = chart_data.min() if chart_data.size() > 0 else 0.0
	if max_value == min_value:
		max_value = min_value + 1.0
	
	# Draw grid
	if show_grid:
		_draw_grid(rect, min_value, max_value)
	
	# Draw bars
	_draw_bars(rect, min_value, max_value)

func _draw_grid(rect: Rect2, min_value: float, max_value: float) -> void:
	var grid_lines = 5
	
	# Horizontal grid lines
	for i in range(grid_lines + 1):
		var y = rect.position.y + (rect.size.y * i / grid_lines)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x + rect.size.x, y), grid_color, 1.0)

func _draw_bars(rect: Rect2, min_value: float, max_value: float) -> void:
	var bar_count = chart_data.size()
	if bar_count == 0:
		return
	
	var total_spacing = bar_spacing * (bar_count - 1)
	var available_width = rect.size.x - total_spacing
	var bar_width = available_width / bar_count
	
	var value_range = max_value - min_value
	
	for i in range(bar_count):
		var value = chart_data[i]
		var normalized_value = (value - min_value) / value_range
		
		var bar_height = normalized_value * rect.size.y
		var x = rect.position.x + (i * (bar_width + bar_spacing))
		var y = rect.position.y + rect.size.y - bar_height
		
		var bar_rect = Rect2(x, y, bar_width, bar_height)
		
		# Draw bar
		draw_rect(bar_rect, bar_color)
		
		# Draw outline
		draw_rect(bar_rect, bar_outline_color, false, 1.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = event.position
		var bar_index = _find_bar_at_position(mouse_pos)
		if bar_index >= 0:
			bar_selected.emit(bar_index, chart_data[bar_index])

func _find_bar_at_position(mouse_pos: Vector2) -> int:
	if chart_data.is_empty():
		return -1
	
	var rect = get_rect()
	var bar_count = chart_data.size()
	var total_spacing = bar_spacing * (bar_count - 1)
	var available_width = rect.size.x - total_spacing
	var bar_width = available_width / bar_count
	
	if mouse_pos.y < rect.position.y or mouse_pos.y > rect.position.y + rect.size.y:
		return -1
	
	for i in range(bar_count):
		var x = rect.position.x + (i * (bar_width + bar_spacing))
		if mouse_pos.x >= x and mouse_pos.x <= x + bar_width:
			return i
	
	return -1

func get_chart_title() -> String:
	return _title

func get_x_label() -> String:
	return _x_label

func get_y_label() -> String:
	return _y_label

func get_labels() -> Array[String]:
	return chart_labels.duplicate()