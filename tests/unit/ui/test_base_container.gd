@tool
extends "res://tests/fixtures/base/game_test.gd"

## Test suite for BaseContainer UI component
## Tests layout behavior, spacing, and orientation functionality

# Enums for container orientation
enum ContainerOrientation {
	HORIZONTAL,
	VERTICAL
}

# Test variables with explicit types
var _component: Container
var child1: Control
var child2: Control

func _call_node_method_float(obj: Object, method: String, args: Array = [], default: float = 0.0) -> float:
	if not obj or not obj.has_method(method):
		return default
	return obj.callv(method, args)

func _call_node_method_int(obj: Object, method: String, args: Array = [], default: int = 0) -> int:
	if not obj or not obj.has_method(method):
		return default
	return obj.callv(method, args)

func before_each() -> void:
	await super.before_each()
	
	# Create component
	_component = Container.new()
	_component.set_script(load("res://src/ui/components/base/BaseContainer.gd"))
	add_child_autofree(_component)
	
	# Create test controls
	child1 = Control.new()
	if not child1:
		push_error("Failed to create first Control")
		return
		
	child2 = Control.new()
	if not child2:
		push_error("Failed to create second Control")
		return
	
	# Set up test controls with minimum sizes
	child1.custom_minimum_size = Vector2(100, 50)
	child2.custom_minimum_size = Vector2(150, 75)
	
	_component.add_child(child1)
	_component.add_child(child2)
	_component.size = Vector2(400, 300)
	
	await stabilize_engine()

func after_each() -> void:
	_component = null
	child1 = null
	child2 = null
	await super.after_each()

func test_horizontal_layout() -> void:
	assert_not_null(_component, "Container should be initialized")
	_call_node_method_bool(_component, "set_orientation", [ContainerOrientation.HORIZONTAL])
	_call_node_method_bool(_component, "set_spacing", [10.0])
	_component._on_sort_children()
	
	# First child should be at (0,0) with its minimum width and container height
	assert_eq(child1.position, Vector2.ZERO)
	assert_eq(child1.size, Vector2(100, 300))
	
	# Second child should be positioned after first child + spacing
	assert_eq(child2.position.x, 110) # 100 + 10 spacing
	assert_eq(child2.position.y, 0)
	assert_eq(child2.size, Vector2(150, 300))

func test_vertical_layout() -> void:
	assert_not_null(_component, "Container should be initialized")
	_call_node_method_bool(_component, "set_orientation", [ContainerOrientation.VERTICAL])
	_call_node_method_bool(_component, "set_spacing", [10.0])
	_component._on_sort_children()
	
	# First child should be at (0,0) with container width and its minimum height
	assert_eq(child1.position, Vector2.ZERO)
	assert_eq(child1.size, Vector2(400, 50))
	
	# Second child should be positioned below first child + spacing
	assert_eq(child2.position.x, 0)
	assert_eq(child2.position.y, 60) # 50 + 10 spacing
	assert_eq(child2.size, Vector2(400, 75))

func test_spacing_property() -> void:
	var test_spacing := 20.0
	_call_node_method_bool(_component, "set_spacing", [test_spacing])
	var actual_spacing: float = _call_node_method_float(_component, "get_spacing", [], 0.0)
	assert_eq(actual_spacing, test_spacing, "Spacing should be updated")

func test_orientation_property() -> void:
	_call_node_method_bool(_component, "set_orientation", [ContainerOrientation.HORIZONTAL])
	var orientation: int = _call_node_method_int(_component, "get_orientation", [], -1)
	assert_eq(orientation, ContainerOrientation.HORIZONTAL, "Orientation should be horizontal")
	
	_call_node_method_bool(_component, "set_orientation", [ContainerOrientation.VERTICAL])
	orientation = _call_node_method_int(_component, "get_orientation", [], -1)
	assert_eq(orientation, ContainerOrientation.VERTICAL, "Orientation should be vertical")

func test_minimum_size() -> void:
	_call_node_method_bool(_component, "set_orientation", [ContainerOrientation.HORIZONTAL])
	var min_size: Vector2 = _component.get_minimum_size()
	assert_eq(min_size.x, 260) # 100 + 150 + 10 spacing
	assert_eq(min_size.y, 75) # max(50, 75)
	
	_call_node_method_bool(_component, "set_orientation", [ContainerOrientation.VERTICAL])
	min_size = _component.get_minimum_size()
	assert_eq(min_size.x, 150) # max(100, 150)
	assert_eq(min_size.y, 135) # 50 + 75 + 10 spacing

func test_component_structure() -> void:
	# Test basic structure
	assert_not_null(_component, "Component should be initialized")
	assert_true(_component.is_inside_tree(), "Component should be in scene tree")
	
	# Test orientation and spacing
	var orientation: int = _call_node_method_int(_component, "get_orientation", [], -1)
	assert_true(orientation in [ContainerOrientation.HORIZONTAL, ContainerOrientation.VERTICAL],
		"Should have valid orientation")
	
	var spacing: float = _call_node_method_float(_component, "get_spacing", [], -1.0)
	assert_ge(spacing, 0.0, "Should have non-negative spacing")

func test_component_theme() -> void:
	# Test theme properties
	assert_true(_component.has_theme_constant("spacing"), "Should have spacing theme constant")
	assert_true(_component.has_theme_stylebox("normal"), "Should have normal stylebox")

func test_component_accessibility() -> void:
	# Test accessibility features
	assert_true(_component.clip_contents, "Should clip contents for better visual clarity")
	assert_true(_component.mouse_filter == Control.MOUSE_FILTER_PASS,
		"Should pass mouse events to children")