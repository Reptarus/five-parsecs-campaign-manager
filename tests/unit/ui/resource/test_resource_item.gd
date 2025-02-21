extends "res://addons/gut/test.gd"

# Type safety helper functions
func _safe_cast_object(value: Variant, error_message: String = "") -> Object:
	if not value is Object:
		push_error("Cannot cast to Object: %s" % error_message)
		return null
	return value

func _safe_cast_array(value: Variant, error_message: String = "") -> Array:
	if not value is Array:
		push_error("Cannot cast to Array: %s" % error_message)
		return []
	return value

func _safe_cast_dictionary(value: Variant, error_message: String = "") -> Dictionary:
	if not value is Dictionary:
		push_error("Cannot cast to Dictionary: %s" % error_message)
		return {}
	return value

func _safe_cast_bool(value: Variant, error_message: String = "") -> bool:
	if not value is bool:
		push_error("Cannot cast to bool: %s" % error_message)
		return false
	return value

func _safe_cast_int(value: Variant, error_message: String = "") -> int:
	if not value is int:
		push_error("Cannot cast to int: %s" % error_message)
		return 0
	return value

func _safe_cast_color(value: Variant, error_message: String = "") -> Color:
	if not value is Color:
		push_error("Cannot cast to Color: %s" % error_message)
		return Color.WHITE
	return value

func _get_property_safe(obj: Object, property: String, default_value: Variant = null) -> Variant:
	if not property in obj:
		return default_value
	return obj.get(property)

# Type definitions
const ResourceItemScript: GDScript = preload("res://src/ui/resource/ResourceItem.gd")
const GameEnumsScript: GDScript = preload("res://src/core/systems/GlobalEnums.gd")

# Test tracking
var _tracked_nodes: Array[Node] = []
var resource_item: Node

func before_each() -> void:
	var item_instance: Node = Node.new()
	if not item_instance:
		push_error("Failed to create resource item instance")
		return
		
	item_instance.set_script(ResourceItemScript)
	if not item_instance.get_script() == ResourceItemScript:
		push_error("Failed to set ResourceItem script")
		return
		
	resource_item = item_instance
	track_test_node(item_instance)
	add_child(resource_item)
	await resource_item.ready

func after_each() -> void:
	cleanup_tracked_nodes()
	resource_item = null

func track_test_node(node: Node) -> void:
	if not node in _tracked_nodes:
		_tracked_nodes.append(node)

func cleanup_tracked_nodes() -> void:
	for node in _tracked_nodes:
		if is_instance_valid(node) and node.is_inside_tree():
			node.queue_free()
	_tracked_nodes.clear()

func test_initial_setup() -> void:
	assert_not_null(resource_item, "Resource item should be created")
	
	var icon_texture: Node = _safe_cast_object(_get_property_safe(resource_item, "icon_texture"), "Icon texture should be a Node")
	var name_label: Node = _safe_cast_object(_get_property_safe(resource_item, "name_label"), "Name label should be a Node")
	var amount_label: Node = _safe_cast_object(_get_property_safe(resource_item, "amount_label"), "Amount label should be a Node")
	var trend_label: Node = _safe_cast_object(_get_property_safe(resource_item, "trend_label"), "Trend label should be a Node")
	var market_label: Node = _safe_cast_object(_get_property_safe(resource_item, "market_label"), "Market label should be a Node")
	
	assert_not_null(icon_texture, "Should have icon texture")
	assert_not_null(name_label, "Should have name label")
	assert_not_null(amount_label, "Should have amount label")
	assert_not_null(trend_label, "Should have trend label")
	assert_not_null(market_label, "Should have market label")
	
	var resource_type: int = _safe_cast_int(_get_property_safe(resource_item, "resource_type", 0), "Resource type should be an integer")
	var current_amount: int = _safe_cast_int(_get_property_safe(resource_item, "current_amount", 0), "Current amount should be an integer")
	var market_value: int = _safe_cast_int(_get_property_safe(resource_item, "market_value", 0), "Market value should be an integer")
	var trend: int = _safe_cast_int(_get_property_safe(resource_item, "trend", 0), "Trend should be an integer")
	
	assert_eq(resource_type, GameEnumsScript.ResourceType.NONE, "Should initialize with NONE resource type")
	assert_eq(current_amount, 0, "Should initialize with zero amount")
	assert_eq(market_value, 0, "Should initialize with zero market value")
	assert_eq(trend, 0, "Should initialize with zero trend")

func test_setup() -> void:
	var type: int = GameEnumsScript.ResourceType.CREDITS
	var setup_result: bool = _safe_cast_bool(_get_property_safe(resource_item, "setup", [type, 100, 150, 1]), "Setup should return bool")
	assert_true(setup_result, "Should successfully setup resource item")
	
	var resource_type: int = _safe_cast_int(_get_property_safe(resource_item, "resource_type", 0), "Resource type should be an integer")
	var current_amount: int = _safe_cast_int(_get_property_safe(resource_item, "current_amount", 0), "Current amount should be an integer")
	var market_value: int = _safe_cast_int(_get_property_safe(resource_item, "market_value", 0), "Market value should be an integer")
	var trend: int = _safe_cast_int(_get_property_safe(resource_item, "trend", 0), "Trend should be an integer")
	
	assert_eq(resource_type, type, "Should set resource type")
	assert_eq(current_amount, 100, "Should set current amount")
	assert_eq(market_value, 150, "Should set market value")
	assert_eq(trend, 1, "Should set trend")
	
	var name_label: Node = _safe_cast_object(_get_property_safe(resource_item, "name_label"), "Name label should be a Node")
	var amount_label: Node = _safe_cast_object(_get_property_safe(resource_item, "amount_label"), "Amount label should be a Node")
	var market_label: Node = _safe_cast_object(_get_property_safe(resource_item, "market_label"), "Market label should be a Node")
	var trend_label: Node = _safe_cast_object(_get_property_safe(resource_item, "trend_label"), "Trend label should be a Node")
	
	assert_eq(_get_property_safe(name_label, "text", ""), "Credits", "Should set name label")
	assert_eq(_get_property_safe(amount_label, "text", ""), "100", "Should set amount label")
	assert_eq(_get_property_safe(market_label, "text", ""), "(150)", "Should set market label")
	assert_eq(_get_property_safe(trend_label, "text", ""), "↑", "Should set trend label")

func test_update_values() -> void:
	var type: int = GameEnumsScript.ResourceType.CREDITS
	var setup_result: bool = _safe_cast_bool(_get_property_safe(resource_item, "setup", [type, 100, 0, 0]), "Setup should return bool")
	assert_true(setup_result, "Should successfully setup resource item")
	
	var update_result: bool = _safe_cast_bool(_get_property_safe(resource_item, "update_values", [200, 250, -1]), "Update values should return bool")
	assert_true(update_result, "Should successfully update values")
	
	var current_amount: int = _safe_cast_int(_get_property_safe(resource_item, "current_amount", 0), "Current amount should be an integer")
	var market_value: int = _safe_cast_int(_get_property_safe(resource_item, "market_value", 0), "Market value should be an integer")
	var trend: int = _safe_cast_int(_get_property_safe(resource_item, "trend", 0), "Trend should be an integer")
	
	assert_eq(current_amount, 200, "Should update current amount")
	assert_eq(market_value, 250, "Should update market value")
	assert_eq(trend, -1, "Should update trend")
	
	var amount_label: Node = _safe_cast_object(_get_property_safe(resource_item, "amount_label"), "Amount label should be a Node")
	var market_label: Node = _safe_cast_object(_get_property_safe(resource_item, "market_label"), "Market label should be a Node")
	var trend_label: Node = _safe_cast_object(_get_property_safe(resource_item, "trend_label"), "Trend label should be a Node")
	
	assert_eq(_get_property_safe(amount_label, "text", ""), "200", "Should update amount label")
	assert_eq(_get_property_safe(market_label, "text", ""), "(250)", "Should update market label")
	assert_eq(_get_property_safe(trend_label, "text", ""), "↓", "Should update trend label")

func test_trend_symbols() -> void:
	var type: int = GameEnumsScript.ResourceType.CREDITS
	var trends: Dictionary = {
		-1: "↓",
		0: "→",
		1: "↑"
	}
	
	for trend in trends:
		var setup_result: bool = _safe_cast_bool(_get_property_safe(resource_item, "setup", [type, 100, 100, trend]), "Setup should return bool")
		assert_true(setup_result, "Should successfully setup resource item")
		
		var trend_label: Node = _safe_cast_object(_get_property_safe(resource_item, "trend_label"), "Trend label should be a Node")
		assert_eq(_get_property_safe(trend_label, "text", ""), trends[trend], "Should set correct trend symbol")

func test_trend_colors() -> void:
	var type: int = GameEnumsScript.ResourceType.CREDITS
	var trend_colors: Dictionary = {
		-1: Color(1, 0.4, 0.4),  # Red
		0: Color(1, 1, 1),      # White
		1: Color(0.4, 1, 0.4)   # Green
	}
	
	for trend in trend_colors:
		var setup_result: bool = _safe_cast_bool(_get_property_safe(resource_item, "setup", [type, 100, 100, trend]), "Setup should return bool")
		assert_true(setup_result, "Should successfully setup resource item")
		
		var trend_label: Node = _safe_cast_object(_get_property_safe(resource_item, "trend_label"), "Trend label should be a Node")
		var market_label: Node = _safe_cast_object(_get_property_safe(resource_item, "market_label"), "Market label should be a Node")
		
		var trend_color: Color = _safe_cast_color(_get_property_safe(trend_label, "modulate", Color.WHITE), "Trend label color should be a Color")
		var market_color: Color = _safe_cast_color(_get_property_safe(market_label, "modulate", Color.WHITE), "Market label color should be a Color")
		
		assert_eq(trend_color, trend_colors[trend], "Should set correct trend label color")
		assert_eq(market_color, trend_colors[trend], "Should set correct market label color")

func test_market_value_display() -> void:
	var type: int = GameEnumsScript.ResourceType.CREDITS
	
	# Test with market value
	var setup_result1: bool = _safe_cast_bool(_get_property_safe(resource_item, "setup", [type, 100, 150, 0]), "Setup should return bool")
	assert_true(setup_result1, "Should successfully setup resource item with market value")
	
	var market_label: Node = _safe_cast_object(_get_property_safe(resource_item, "market_label"), "Market label should be a Node")
	assert_eq(_get_property_safe(market_label, "text", ""), "(150)", "Should display market value")
	
	# Test without market value
	var setup_result2: bool = _safe_cast_bool(_get_property_safe(resource_item, "setup", [type, 100, 0, 0]), "Setup should return bool")
	assert_true(setup_result2, "Should successfully setup resource item without market value")
	
	assert_eq(_get_property_safe(market_label, "text", ""), "", "Should not display market value")

func test_tooltip_generation() -> void:
	var type: int = GameEnumsScript.ResourceType.CREDITS
	var setup_result: bool = _safe_cast_bool(_get_property_safe(resource_item, "setup", [type, 100, 150, 1]), "Setup should return bool")
	assert_true(setup_result, "Should successfully setup resource item")
	
	var tooltip: String = _get_property_safe(resource_item, "tooltip_text", "")
	
	assert_true(tooltip.contains("Credits"), "Tooltip should contain resource name")
	assert_true(tooltip.contains("Current: 100"), "Tooltip should contain current amount")
	assert_true(tooltip.contains("Market Value: 150"), "Tooltip should contain market value")
	assert_true(tooltip.contains("Difference: +50"), "Tooltip should contain difference")
	assert_true(tooltip.contains("Trend: Increasing"), "Tooltip should contain trend")
	
	# Test with no market value
	setup_result = _safe_cast_bool(_get_property_safe(resource_item, "setup", [type, 100, 0, 0]), "Setup should return bool")
	assert_true(setup_result, "Should successfully setup resource item without market value")
	
	tooltip = _get_property_safe(resource_item, "tooltip_text", "")
	
	assert_true(tooltip.contains("Credits"), "Tooltip should contain resource name")
	assert_true(tooltip.contains("Current: 100"), "Tooltip should contain current amount")
	assert_false(tooltip.contains("Market Value"), "Tooltip should not contain market value")
	assert_true(tooltip.contains("Trend: Stable"), "Tooltip should contain trend")

func test_different_resource_types() -> void:
	var resource_types: Array = [
		GameEnumsScript.ResourceType.CREDITS,
		GameEnumsScript.ResourceType.SUPPLIES,
		GameEnumsScript.ResourceType.TECH_PARTS
	]
	
	for type in resource_types:
		var setup_result: bool = _safe_cast_bool(_get_property_safe(resource_item, "setup", [type, 100, 0, 0]), "Setup should return bool")
		assert_true(setup_result, "Should successfully setup resource item")
		
		var type_name: String = GameEnumsScript.ResourceType.keys()[type].capitalize()
		var name_label: Node = _safe_cast_object(_get_property_safe(resource_item, "name_label"), "Name label should be a Node")
		
		assert_eq(_get_property_safe(name_label, "text", ""), type_name, "Should set correct resource name")
		assert_true(_get_property_safe(resource_item, "tooltip_text", "").contains(type_name), "Tooltip should contain resource name")

func test_icon_loading() -> void:
	var type: int = GameEnumsScript.ResourceType.CREDITS
	var setup_result: bool = _safe_cast_bool(_get_property_safe(resource_item, "setup", [type, 100, 0, 0]), "Setup should return bool")
	assert_true(setup_result, "Should successfully setup resource item")
	
	var icon_texture: Node = _safe_cast_object(_get_property_safe(resource_item, "icon_texture"), "Icon texture should be a Node")
	var icon_path: String = "res://assets/icons/resources/credits.png"
	
	if ResourceLoader.exists(icon_path):
		assert_not_null(_get_property_safe(icon_texture, "texture"), "Should load icon texture")
	else:
		assert_null(_get_property_safe(icon_texture, "texture"), "Should not have icon texture") 