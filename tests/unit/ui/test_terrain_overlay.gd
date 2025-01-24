extends "res://addons/gut/test.gd"

const TerrainOverlay = preload("res://src/ui/components/combat/TerrainOverlay.gd")

var overlay: TerrainOverlay

func before_each() -> void:
	overlay = TerrainOverlay.new()
	add_child(overlay)

func after_each() -> void:
	overlay.queue_free()

func test_initial_setup() -> void:
	assert_not_null(overlay)
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_PASS)

func test_terrain_update() -> void:
	var test_terrain = {
		"type": "forest",
		"cover": 2,
		"movement_cost": 1.5
	}
	overlay.update_terrain(test_terrain)
	# Add assertions for terrain updates when implemented

func test_highlight_cell() -> void:
	var test_pos = Vector2i(2, 3)
	overlay.highlight_cell(test_pos)
	# Add assertions for cell highlighting when implemented

func test_clear_highlight() -> void:
	overlay.clear_highlight()
	# Add assertions for highlight clearing when implemented 