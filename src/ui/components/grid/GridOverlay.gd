@tool
extends Control

signal cell_selected(cell_pos: Vector2i)
signal cell_hovered(cell_pos: Vector2i)

var grid_size: Vector2i
var cell_size: Vector2
var selected_cell := Vector2i(-1, -1)
var hover_cell := Vector2i(-1, -1)

const GRID_COLOR := Color(0.3, 0.3, 0.3, 0.5)
const SELECTED_COLOR := Color(1.0, 1.0, 0.0, 0.3)
const HOVER_COLOR := Color(1.0, 1.0, 1.0, 0.2)

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_PASS
    set_process_input(true)

func draw_grid(size: Vector2i, cell: Vector2) -> void:
    grid_size = size
    cell_size = cell
    custom_minimum_size = Vector2(grid_size) * cell_size
    queue_redraw()

func update_overlay(selected: Vector2i, hover: Vector2i) -> void:
    selected_cell = selected
    hover_cell = hover
    queue_redraw()

func _draw() -> void:
    # Draw vertical grid lines
    for x in range(grid_size.x + 1):
        var start := Vector2(x * cell_size.x, 0)
        var end := Vector2(x * cell_size.x, grid_size.y * cell_size.y)
        draw_line(start, end, GRID_COLOR)

    # Draw horizontal grid lines
    for y in range(grid_size.y + 1):
        var start := Vector2(0, y * cell_size.y)
        var end := Vector2(grid_size.x * cell_size.x, y * cell_size.y)
        draw_line(start, end, GRID_COLOR)

    # Draw selected cell highlight
    if selected_cell != Vector2i(-1, -1):
        var rect := Rect2(Vector2(selected_cell) * cell_size, cell_size)
        draw_rect(rect, SELECTED_COLOR)

    # Draw hover cell highlight
    if hover_cell != Vector2i(-1, -1) and hover_cell != selected_cell:
        var rect := Rect2(Vector2(hover_cell) * cell_size, cell_size)
        draw_rect(rect, HOVER_COLOR)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        var new_hover := Vector2i(event.position / cell_size)
        if new_hover != hover_cell and _is_valid_cell(new_hover):
            hover_cell = new_hover
            emit_signal("cell_hovered", hover_cell)
            queue_redraw()
    
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var new_selected := Vector2i(event.position / cell_size)
        if _is_valid_cell(new_selected):
            selected_cell = new_selected
            emit_signal("cell_selected", selected_cell)
            queue_redraw()

func _is_valid_cell(pos: Vector2i) -> bool:
    return pos.x >= 0 and pos.x < grid_size.x and pos.y >= 0 and pos.y < grid_size.y

func get_cell_position(grid_pos: Vector2i) -> Vector2:
    return Vector2(grid_pos) * cell_size

func get_grid_position(world_pos: Vector2) -> Vector2i:
    return Vector2i(world_pos / cell_size) 