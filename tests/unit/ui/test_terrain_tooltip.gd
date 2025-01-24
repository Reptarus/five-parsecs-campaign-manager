extends "res://addons/gut/test.gd"

const TerrainTooltip = preload("res://src/ui/components/combat/TerrainTooltip.gd")

var tooltip: TerrainTooltip

func before_each() -> void:
	tooltip = TerrainTooltip.new()
	add_child(tooltip)

func after_each() -> void:
	tooltip.queue_free()

func test_initial_setup() -> void:
	assert_not_null(tooltip)
	assert_false(tooltip.visible)

func test_show_tooltip() -> void:
	var test_terrain = {
		"type": "forest",
		"cover": 2,
		"movement_cost": 1.5,
		"description": "Dense forest providing good cover"
	}
	tooltip.show_tooltip(test_terrain)
	assert_true(tooltip.visible)
	# Add more specific assertions when tooltip content is implemented

func test_hide_tooltip() -> void:
	tooltip.hide_tooltip()
	assert_false(tooltip.visible)

func test_update_position() -> void:
	var test_pos = Vector2(100, 100)
	tooltip.update_position(test_pos)
	# Add position assertions when implemented 