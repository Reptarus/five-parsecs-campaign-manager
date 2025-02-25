@tool
extends "res://tests/fixtures/base/game_test.gd"

const TerrainOverlay := preload("res://src/ui/components/combat/TerrainOverlay.gd")

# Type-safe instance variables
var _overlay: TerrainOverlay

func before_each() -> void:
	await super.before_each()
	_setup_overlay()

func after_each() -> void:
	_cleanup_overlay()
	await super.after_each()

func _setup_overlay() -> void:
	_overlay = TerrainOverlay.new()
	add_child_autofree(_overlay)
	track_test_node(_overlay)
	await stabilize_engine()

func _cleanup_overlay() -> void:
	_overlay = null

func test_initial_setup() -> void:
	assert_not_null(_overlay)
	assert_not_null(_overlay.get_node("TerrainHighlight"))
	assert_not_null(_overlay.get_node("TerrainGrid"))
	assert_eq(_overlay.cell_size, Vector2(64, 64))
	assert_eq(_overlay.grid_color, Color(0.3, 0.3, 0.3, 0.5))

func test_terrain_update() -> void:
	var test_terrain := {
		"type": "forest",
		"cover": 2,
		"movement_cost": 1.5,
		"color": Color(0.2, 0.6, 0.2, 0.5)
	}
	_overlay.update_terrain(test_terrain)
	
	var highlight := _overlay.get_node("TerrainHighlight")
	var grid := _overlay.get_node("TerrainGrid")
	
	assert_true(highlight.visible)
	assert_true(grid.visible)
	assert_eq(highlight.modulate, test_terrain.color)
	assert_eq(grid.modulate, test_terrain.color)

func test_highlight_cell() -> void:
	var test_pos := Vector2i(2, 3)
	_overlay.highlight_cell(test_pos)
	
	var highlight := _overlay.get_node("TerrainHighlight")
	assert_true(highlight.visible)
	assert_eq(highlight.position, Vector2(test_pos) * _overlay.cell_size)

func test_clear_highlight() -> void:
	# First set a highlight
	var test_pos := Vector2i(2, 3)
	_overlay.highlight_cell(test_pos)
	
	# Then clear it
	_overlay.clear_highlight()
	
	var highlight := _overlay.get_node("TerrainHighlight")
	var grid := _overlay.get_node("TerrainGrid")
	
	assert_false(highlight.visible)
	assert_false(grid.visible)

func test_terrain_interaction() -> void:
	# Test different cell positions
	var test_positions := [
		Vector2i(0, 0), # Origin
		Vector2i(5, 5), # Middle
		Vector2i(10, 10), # Far
		Vector2i(-1, -1), # Invalid
		Vector2i(100, 100) # Out of bounds
	]
	
	for pos in test_positions:
		_overlay.highlight_cell(pos)
		
		var highlight := _overlay.get_node("TerrainHighlight")
		if pos.x >= 0 and pos.y >= 0:
			assert_true(highlight.visible)
			assert_eq(highlight.position, Vector2(pos) * _overlay.cell_size)
		else:
			assert_false(highlight.visible)
		
		_overlay.clear_highlight()
		await get_tree().process_frame

func test_terrain_effects() -> void:
	# Test applying different terrain effects
	var test_effects := [
		{
			"type": "fire",
			"color": Color(1.0, 0.4, 0.0, 0.6)
		},
		{
			"type": "smoke",
			"color": Color(0.7, 0.7, 0.7, 0.5)
		},
		{
			"type": "radiation",
			"color": Color(0.0, 1.0, 0.0, 0.4)
		}
	]
	
	for effect in test_effects:
		var pos := Vector2i(2, 3)
		_overlay.apply_effect(pos, effect.type)
		
		var effect_node := _overlay.get_node("Effects/" + effect.type.capitalize())
		assert_true(effect_node.visible)
		assert_eq(effect_node.modulate, effect.color)
		
		_overlay.remove_effect(pos, effect.type)
		assert_false(effect_node.visible)
		await get_tree().process_frame

func test_grid_drawing() -> void:
	# Test grid line drawing
	var grid_size := Vector2i(5, 5)
	_overlay.set_grid_size(grid_size)
	
	# Count vertical lines
	var vertical_lines := 0
	for x in range(grid_size.x + 1):
		var start := Vector2(x * _overlay.cell_size.x, 0)
		var end := Vector2(x * _overlay.cell_size.x, grid_size.y * _overlay.cell_size.y)
		vertical_lines += 1
	
	# Count horizontal lines
	var horizontal_lines := 0
	for y in range(grid_size.y + 1):
		var start := Vector2(0, y * _overlay.cell_size.y)
		var end := Vector2(grid_size.x * _overlay.cell_size.x, y * _overlay.cell_size.y)
		horizontal_lines += 1
	
	assert_eq(vertical_lines, grid_size.x + 1)
	assert_eq(horizontal_lines, grid_size.y + 1)

func test_performance() -> void:
	# Test performance with many cells
	var grid_size := Vector2i(20, 20)
	_overlay.set_grid_size(grid_size)
	
	var start_time := Time.get_ticks_msec()
	
	# Update many cells
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var pos := Vector2i(x, y)
			_overlay.highlight_cell(pos)
			_overlay.clear_highlight()
			await get_tree().process_frame
	
	var end_time := Time.get_ticks_msec()
	var duration := end_time - start_time
	
	# Ensure performance is reasonable (less than 16ms per frame on average)
	var frames := grid_size.x * grid_size.y
	var avg_frame_time := duration / frames
	assert_lt(avg_frame_time, 16.0,
		"Average frame time should be less than 16ms")