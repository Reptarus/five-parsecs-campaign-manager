extends "res://addons/gut/test.gd"

const GridOverlay = preload("res://src/ui/components/grid/GridOverlay.gd")

var overlay: GridOverlay
var cell_selected_signal_emitted := false
var cell_hovered_signal_emitted := false
var last_selected_cell: Vector2i
var last_hovered_cell: Vector2i

func before_each() -> void:
	overlay = GridOverlay.new()
	add_child(overlay)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	overlay.queue_free()

func _reset_signals() -> void:
	cell_selected_signal_emitted = false
	cell_hovered_signal_emitted = false
	last_selected_cell = Vector2i(-1, -1)
	last_hovered_cell = Vector2i(-1, -1)

func _connect_signals() -> void:
	overlay.cell_selected.connect(_on_cell_selected)
	overlay.cell_hovered.connect(_on_cell_hovered)

func _on_cell_selected(cell_pos: Vector2i) -> void:
	cell_selected_signal_emitted = true
	last_selected_cell = cell_pos

func _on_cell_hovered(cell_pos: Vector2i) -> void:
	cell_hovered_signal_emitted = true
	last_hovered_cell = cell_pos

func test_initial_setup() -> void:
	assert_not_null(overlay)
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(overlay.selected_cell, Vector2i(-1, -1))
	assert_eq(overlay.hover_cell, Vector2i(-1, -1))

func test_draw_grid() -> void:
	var grid_size = Vector2i(10, 10)
	var cell_size = Vector2(32, 32)
	overlay.draw_grid(grid_size, cell_size)
	
	assert_eq(overlay.grid_size, grid_size)
	assert_eq(overlay.cell_size, cell_size)
	assert_eq(overlay.custom_minimum_size, Vector2(grid_size) * cell_size)

func test_update_overlay() -> void:
	var selected = Vector2i(2, 3)
	var hover = Vector2i(4, 5)
	overlay.update_overlay(selected, hover)
	
	assert_eq(overlay.selected_cell, selected)
	assert_eq(overlay.hover_cell, hover)

func test_cell_selection() -> void:
	overlay.draw_grid(Vector2i(10, 10), Vector2(32, 32))
	
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(50, 50) # Should select cell (1, 1)
	
	overlay._gui_input(event)
	
	assert_true(cell_selected_signal_emitted)
	assert_eq(last_selected_cell, Vector2i(1, 1))

func test_cell_hover() -> void:
	overlay.draw_grid(Vector2i(10, 10), Vector2(32, 32))
	
	var event = InputEventMouseMotion.new()
	event.position = Vector2(50, 50) # Should hover over cell (1, 1)
	
	overlay._gui_input(event)
	
	assert_true(cell_hovered_signal_emitted)
	assert_eq(last_hovered_cell, Vector2i(1, 1))

func test_cell_position_conversion() -> void:
	overlay.draw_grid(Vector2i(10, 10), Vector2(32, 32))
	
	var grid_pos = Vector2i(2, 3)
	var world_pos = overlay.get_cell_position(grid_pos)
	assert_eq(world_pos, Vector2(grid_pos) * overlay.cell_size)
	
	var converted_grid_pos = overlay.get_grid_position(world_pos)
	assert_eq(converted_grid_pos, grid_pos)

func test_valid_cell_check() -> void:
	overlay.draw_grid(Vector2i(10, 10), Vector2(32, 32))
	
	assert_true(overlay._is_valid_cell(Vector2i(0, 0)))
	assert_true(overlay._is_valid_cell(Vector2i(9, 9)))
	assert_false(overlay._is_valid_cell(Vector2i(-1, 0)))
	assert_false(overlay._is_valid_cell(Vector2i(10, 10)))