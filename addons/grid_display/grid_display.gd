@tool
class_name GridDisplay
extends Node2D

signal grid_updated(grid_size: Vector2, cell_size: Vector2)

##The Number of cells, horizontally and vertically, using x/y values respectively
@export var grid_size := Vector2i(2, 5):
	set(value):
		grid_size = value
		emit_signal("grid_updated", grid_size, cell_size)
		queue_redraw()

##The line size of the grid, horizontally and vertically, using x/y values respectively
@export var line_size := Vector2(5.0, 5.0):
	set(value):
		line_size = value
		queue_redraw()

@export var border_width := 5.0:
	set(value):
		border_width = value
		queue_redraw()

@export var cell_size := Vector2(64.0, 64.0):
	set(value):
		cell_size = value
		emit_signal("grid_updated", grid_size, cell_size)
		queue_redraw()

@export_category("Colors")
##Border Line Color
@export var border_color := Color.WHITE:
	set(value):
		border_color = value
		queue_redraw()

##Vertical Line Color
@export var vline_color := Color.WHITE:
	set(value):
		vline_color = value
		queue_redraw()

##Horizontal Line Color
@export var hline_color := Color.WHITE:
	set(value):
		hline_color = value
		queue_redraw()

@export_category("Display Options")
@export var draw_border := true:
	set(value):
		draw_border = value
		queue_redraw()

@export var draw_grid := true:
	set(value):
		draw_grid = value
		queue_redraw()

func _ready() -> void:
	if not Engine.is_editor_hint():
		emit_signal("grid_updated", grid_size, cell_size)

func _draw() -> void:
	if draw_border: 
		_draw_rect()
	if draw_grid: 
		_draw_grid()

func _draw_rect() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(grid_size) * cell_size)
	draw_rect(rect, border_color, false, border_width)

func _draw_grid() -> void:
	# Draw vertical lines
	for i in range(1, grid_size.x):
		var start := Vector2(i * cell_size.x, 0)
		var end := Vector2(i * cell_size.x, grid_size.y * cell_size.y)
		draw_line(start, end, vline_color, line_size.x)
	
	# Draw horizontal lines
	for i in range(1, grid_size.y):
		var start := Vector2(0, i * cell_size.y)
		var end := Vector2(grid_size.x * cell_size.x, i * cell_size.y)
		draw_line(start, end, hline_color, line_size.y)

func get_cell_position(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos) * cell_size

func get_grid_position(world_pos: Vector2) -> Vector2i:
	return Vector2i(world_pos / cell_size)
