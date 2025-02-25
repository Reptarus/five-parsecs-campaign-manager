@tool
extends ComponentTestBase

const GridOverlay := preload("res://src/ui/components/grid/GridOverlay.gd")

# Type-safe instance variables
var _last_selected_cell: Vector2i
var _last_hovered_cell: Vector2i

# Override _create_component_instance to provide the specific component
func _create_component_instance() -> Control:
	return GridOverlay.new()

func before_each() -> void:
	await super.before_each()
	_reset_state()
	_connect_signals()

func after_each() -> void:
	_reset_state()
	await super.after_each()

func _reset_state() -> void:
	_last_selected_cell = Vector2i(-1, -1)
	_last_hovered_cell = Vector2i(-1, -1)

func _connect_signals() -> void:
	_component.cell_selected.connect(_on_cell_selected)
	_component.cell_hovered.connect(_on_cell_hovered)

func _on_cell_selected(cell_pos: Vector2i) -> void:
	_last_selected_cell = cell_pos

func _on_cell_hovered(cell_pos: Vector2i) -> void:
	_last_hovered_cell = cell_pos

func test_initial_setup() -> void:
	await test_component_structure()
	
	# Additional component-specific checks
	assert_eq(_component.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(_component.selected_cell, Vector2i(-1, -1))
	assert_eq(_component.hover_cell, Vector2i(-1, -1))

func test_draw_grid() -> void:
	var grid_size := Vector2i(10, 10)
	var cell_size := Vector2(32, 32)
	_component.draw_grid(grid_size, cell_size)
	
	assert_eq(_component.grid_size, grid_size)
	assert_eq(_component.cell_size, cell_size)
	assert_eq(_component.custom_minimum_size, Vector2(grid_size) * cell_size)

func test_update_overlay() -> void:
	var selected := Vector2i(2, 3)
	var hover := Vector2i(4, 5)
	_component.update_overlay(selected, hover)
	
	assert_eq(_component.selected_cell, selected)
	assert_eq(_component.hover_cell, hover)

func test_cell_selection() -> void:
	_component.draw_grid(Vector2i(10, 10), Vector2(32, 32))
	
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(50, 50) # Should select cell (1, 1)
	
	await simulate_component_input(event)
	
	assert_component_signal_emitted("cell_selected", [Vector2i(1, 1)])
	assert_eq(_last_selected_cell, Vector2i(1, 1))

func test_cell_hover() -> void:
	_component.draw_grid(Vector2i(10, 10), Vector2(32, 32))
	
	var event := InputEventMouseMotion.new()
	event.position = Vector2(50, 50) # Should hover over cell (1, 1)
	
	await simulate_component_input(event)
	
	assert_component_signal_emitted("cell_hovered", [Vector2i(1, 1)])
	assert_eq(_last_hovered_cell, Vector2i(1, 1))

func test_cell_position_conversion() -> void:
	_component.draw_grid(Vector2i(10, 10), Vector2(32, 32))
	
	var grid_pos := Vector2i(2, 3)
	var world_pos: Vector2 = _component.get_cell_position(grid_pos)
	assert_eq(world_pos, Vector2(grid_pos) * _component.cell_size)
	
	var converted_grid_pos: Vector2i = _component.get_grid_position(world_pos)
	assert_eq(converted_grid_pos, grid_pos)

func test_valid_cell_check() -> void:
	_component.draw_grid(Vector2i(10, 10), Vector2(32, 32))
	
	assert_true(_component._is_valid_cell(Vector2i(0, 0)))
	assert_true(_component._is_valid_cell(Vector2i(9, 9)))
	assert_false(_component._is_valid_cell(Vector2i(-1, 0)))
	assert_false(_component._is_valid_cell(Vector2i(10, 10)))

# Additional tests using base class functionality
func test_component_theme() -> void:
	await super.test_component_theme()
	
	# Additional theme checks for grid overlay
	assert_component_theme_color("grid_color")
	assert_component_theme_color("hover_color")
	assert_component_theme_color("selected_color")

func test_component_layout() -> void:
	await super.test_component_layout()
	
	# Additional layout checks for grid overlay
	_component.draw_grid(Vector2i(10, 10), Vector2(32, 32))
	assert_eq(_component.size, Vector2(320, 320))

func test_component_performance() -> void:
	start_performance_monitoring()
	
	# Perform grid overlay specific operations
	_component.draw_grid(Vector2i(10, 10), Vector2(32, 32))
	
	for i in range(5):
		var pos := Vector2i(i, i)
		_component.update_overlay(pos, pos + Vector2i(1, 1))
		await get_tree().process_frame
	
	var metrics := stop_performance_monitoring()
	assert_performance_metrics(metrics, {
		"layout_updates": 10,
		"draw_calls": 5,
		"theme_lookups": 20
	})

func test_grid_interaction() -> void:
	_component.draw_grid(Vector2i(10, 10), Vector2(32, 32))
	
	# Test click sequence
	await simulate_component_click(Vector2(50, 50))
	assert_component_signal_emitted("cell_selected", [Vector2i(1, 1)])
	
	# Test hover sequence
	await simulate_component_hover(Vector2(100, 100))
	assert_component_signal_emitted("cell_hovered", [Vector2i(3, 3)])
	
	# Test out of bounds
	await simulate_component_click(Vector2(-10, -10))
	assert_component_signal_not_emitted("cell_selected")
	
	await simulate_component_hover(Vector2(400, 400))
	assert_component_signal_not_emitted("cell_hovered")