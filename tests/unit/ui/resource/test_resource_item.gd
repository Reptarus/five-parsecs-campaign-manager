extends "res://addons/gut/test.gd"

const ResourceItem = preload("res://src/ui/resource/ResourceItem.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var resource_item: Node

func before_each() -> void:
	resource_item = ResourceItem.new()
	add_child(resource_item)
	await resource_item.ready

func after_each() -> void:
	resource_item.queue_free()

func test_initial_setup() -> void:
	assert_not_null(resource_item)
	assert_not_null(resource_item.icon_texture)
	assert_not_null(resource_item.name_label)
	assert_not_null(resource_item.amount_label)
	assert_not_null(resource_item.trend_label)
	assert_not_null(resource_item.market_label)
	
	assert_eq(resource_item.resource_type, GameEnums.ResourceType.NONE)
	assert_eq(resource_item.current_amount, 0)
	assert_eq(resource_item.market_value, 0)
	assert_eq(resource_item.trend, 0)

func test_setup() -> void:
	var type := GameEnums.ResourceType.CREDITS
	resource_item.setup(type, 100, 150, 1)
	
	assert_eq(resource_item.resource_type, type)
	assert_eq(resource_item.current_amount, 100)
	assert_eq(resource_item.market_value, 150)
	assert_eq(resource_item.trend, 1)
	
	assert_eq(resource_item.name_label.text, "Credits")
	assert_eq(resource_item.amount_label.text, "100")
	assert_eq(resource_item.market_label.text, "(150)")
	assert_eq(resource_item.trend_label.text, "↑")

func test_update_values() -> void:
	var type := GameEnums.ResourceType.CREDITS
	resource_item.setup(type, 100, 0, 0)
	
	resource_item.update_values(200, 250, -1)
	
	assert_eq(resource_item.current_amount, 200)
	assert_eq(resource_item.market_value, 250)
	assert_eq(resource_item.trend, -1)
	
	assert_eq(resource_item.amount_label.text, "200")
	assert_eq(resource_item.market_label.text, "(250)")
	assert_eq(resource_item.trend_label.text, "↓")

func test_trend_symbols() -> void:
	var type := GameEnums.ResourceType.CREDITS
	var trends = {
		-1: "↓",
		0: "→",
		1: "↑"
	}
	
	for trend in trends:
		resource_item.setup(type, 100, 100, trend)
		assert_eq(resource_item.trend_label.text, trends[trend])

func test_trend_colors() -> void:
	var type := GameEnums.ResourceType.CREDITS
	var trend_colors = {
		-1: Color(1, 0.4, 0.4),  # Red
		0: Color(1, 1, 1),      # White
		1: Color(0.4, 1, 0.4)   # Green
	}
	
	for trend in trend_colors:
		resource_item.setup(type, 100, 100, trend)
		assert_eq(resource_item.trend_label.modulate, trend_colors[trend])
		assert_eq(resource_item.market_label.modulate, trend_colors[trend])

func test_market_value_display() -> void:
	var type := GameEnums.ResourceType.CREDITS
	# Test with market value
	resource_item.setup(type, 100, 150, 0)
	assert_eq(resource_item.market_label.text, "(150)")
	
	# Test without market value
	resource_item.setup(type, 100, 0, 0)
	assert_eq(resource_item.market_label.text, "")

func test_tooltip_generation() -> void:
	var type := GameEnums.ResourceType.CREDITS
	resource_item.setup(type, 100, 150, 1)
	var tooltip = resource_item.tooltip_text
	
	assert_true(tooltip.contains("Credits"))
	assert_true(tooltip.contains("Current: 100"))
	assert_true(tooltip.contains("Market Value: 150"))
	assert_true(tooltip.contains("Difference: +50"))
	assert_true(tooltip.contains("Trend: Increasing"))
	
	# Test with no market value
	resource_item.setup(type, 100, 0, 0)
	tooltip = resource_item.tooltip_text
	
	assert_true(tooltip.contains("Credits"))
	assert_true(tooltip.contains("Current: 100"))
	assert_false(tooltip.contains("Market Value"))
	assert_true(tooltip.contains("Trend: Stable"))

func test_different_resource_types() -> void:
	var resource_types = [
		GameEnums.ResourceType.CREDITS,
		GameEnums.ResourceType.SUPPLIES,
		GameEnums.ResourceType.TECH_PARTS
	]
	
	for type in resource_types:
		resource_item.setup(type, 100, 0, 0)
		var type_name = GameEnums.ResourceType.keys()[type].capitalize()
		assert_eq(resource_item.name_label.text, type_name)
		assert_true(resource_item.tooltip_text.contains(type_name))

func test_icon_loading() -> void:
	var type := GameEnums.ResourceType.CREDITS
	resource_item.setup(type, 100, 0, 0)
	
	# Check if icon was loaded (if it exists)
	var icon_path = "res://assets/icons/resources/credits.png"
	if ResourceLoader.exists(icon_path):
		assert_not_null(resource_item.icon_texture.texture)
	else:
		assert_null(resource_item.icon_texture.texture) 