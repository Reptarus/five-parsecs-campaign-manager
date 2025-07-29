@tool
extends Control
class_name LineChart

## Line Chart Component for Data Visualization
## Provides line chart rendering for campaign analytics

signal chart_updated(data: Dictionary)
signal point_selected(index: int, value: float)

@export var line_color: Color = Color.WHITE
@export var background_color: Color = Color.TRANSPARENT
@export var grid_color: Color = Color.GRAY
@export var show_grid: bool = true
@export var line_thickness: float = 2.0

var chart_data: Array[Vector2] = []
var _title: String = ""
var _x_label: String = ""
var _y_label: String = ""

func set_data(data: Array[Vector2], title: String = "", x_label: String = "", y_label: String = "") -> void:
	chart_data = data.duplicate()
	_title = title
	_x_label = x_label
	_y_label = y_label
	queue_redraw()
	chart_updated.emit({"data": data, "title": title})

func add_point(point: Vector2) -> void:
	chart_data.append(point)
	queue_redraw()

func clear_data() -> void:
	chart_data.clear()
	queue_redraw()

func _draw() -> void:
	if chart_data.is_empty():
		return
	
	var rect = get_rect()
	
	# Draw background
	if background_color.a > 0:
		draw_rect(rect, background_color)
	
	# Calculate bounds
	var min_x = chart_data[0].x
	var max_x = chart_data[0].x
	var min_y = chart_data[0].y
	var max_y = chart_data[0].y
	
	for point in chart_data:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)
	
	# Avoid division by zero
	var x_range = max(max_x - min_x, 1.0)
	var y_range = max(max_y - min_y, 1.0)
	
	# Draw grid
	if show_grid:
		_draw_grid(rect, min_x, max_x, min_y, max_y)
	
	# Draw line
	_draw_line_chart(rect, min_x, max_x, min_y, max_y, x_range, y_range)

func _draw_grid(rect: Rect2, min_x: float, max_x: float, min_y: float, max_y: float) -> void:
	var grid_lines = 5
	
	# Vertical grid lines
	for i in range(grid_lines + 1):
		var x = rect.position.x + (rect.size.x * i / grid_lines)
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.position.y + rect.size.y), grid_color, 1.0)
	
	# Horizontal grid lines
	for i in range(grid_lines + 1):
		var y = rect.position.y + (rect.size.y * i / grid_lines)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x + rect.size.x, y), grid_color, 1.0)

func _draw_line_chart(rect: Rect2, min_x: float, max_x: float, min_y: float, max_y: float, x_range: float, y_range: float) -> void:
	if chart_data.size() < 2:
		return
	
	var points: PackedVector2Array = []
	
	for point in chart_data:
		var x = rect.position.x + ((point.x - min_x) / x_range) * rect.size.x
		var y = rect.position.y + rect.size.y - ((point.y - min_y) / y_range) * rect.size.y
		points.append(Vector2(x, y))
	
	# Draw line segments
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], line_color, line_thickness)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = event.position
		var closest_index = _find_closest_point(mouse_pos)
		if closest_index >= 0:
			point_selected.emit(closest_index, chart_data[closest_index].y)

func _find_closest_point(mouse_pos: Vector2) -> int:
	if chart_data.is_empty():
		return -1
	
	var closest_index = -1
	var closest_distance = INF
	
	var rect = get_rect()
	var min_x = chart_data[0].x
	var max_x = chart_data[0].x
	var min_y = chart_data[0].y
	var max_y = chart_data[0].y
	
	for point in chart_data:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)
	
	var x_range = max(max_x - min_x, 1.0)
	var y_range = max(max_y - min_y, 1.0)
	
	for i in range(chart_data.size()):
		var point = chart_data[i]
		var x = rect.position.x + ((point.x - min_x) / x_range) * rect.size.x
		var y = rect.position.y + rect.size.y - ((point.y - min_y) / y_range) * rect.size.y
		var distance = mouse_pos.distance_to(Vector2(x, y))
		
		if distance < closest_distance:
			closest_distance = distance
			closest_index = i
	
	return closest_index if closest_distance < 20.0 else -1

func get_chart_title() -> String:
	return _title

func get_x_label() -> String:
	return _x_label

func get_y_label() -> String:
	return _y_label