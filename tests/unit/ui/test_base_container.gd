extends "res://addons/gut/test.gd"

const BaseContainer = preload("res://src/ui/components/base/BaseContainer.gd")

var container: BaseContainer
var child1: Control
var child2: Control

func before_each() -> void:
	container = BaseContainer.new()
	child1 = Control.new()
	child2 = Control.new()
	
	# Set up test controls with minimum sizes
	child1.custom_minimum_size = Vector2(100, 50)
	child2.custom_minimum_size = Vector2(150, 75)
	
	add_child(container)
	container.add_child(child1)
	container.add_child(child2)
	container.size = Vector2(400, 300)

func after_each() -> void:
	container.queue_free()

func test_horizontal_layout() -> void:
	container.orientation = BaseContainer.ContainerOrientation.HORIZONTAL
	container.spacing = 10.0
	container._on_sort_children()
	
	# First child should be at (0,0) with its minimum width and container height
	assert_eq(child1.position, Vector2.ZERO)
	assert_eq(child1.size, Vector2(100, 300))
	
	# Second child should be positioned after first child + spacing
	assert_eq(child2.position.x, 110) # 100 + 10 spacing
	assert_eq(child2.position.y, 0)
	assert_eq(child2.size, Vector2(150, 300))

func test_vertical_layout() -> void:
	container.orientation = BaseContainer.ContainerOrientation.VERTICAL
	container.spacing = 10.0
	container._on_sort_children()
	
	# First child should be at (0,0) with container width and its minimum height
	assert_eq(child1.position, Vector2.ZERO)
	assert_eq(child1.size, Vector2(400, 50))
	
	# Second child should be positioned below first child + spacing
	assert_eq(child2.position.x, 0)
	assert_eq(child2.position.y, 60) # 50 + 10 spacing
	assert_eq(child2.size, Vector2(400, 75))

func test_horizontal_wrapping() -> void:
	container.orientation = BaseContainer.ContainerOrientation.HORIZONTAL
	container.spacing = 10.0
	container.size = Vector2(200, 300) # Narrow container to force wrapping
	container._on_sort_children()
	
	# First child should fit on first row
	assert_eq(child1.position, Vector2.ZERO)
	assert_eq(child1.size, Vector2(100, 300))
	
	# Second child should wrap to next row due to insufficient width
	assert_eq(child2.position.x, 0)
	assert_true(child2.position.y > 0)

func test_vertical_wrapping() -> void:
	container.orientation = BaseContainer.ContainerOrientation.VERTICAL
	container.spacing = 10.0
	container.size = Vector2(400, 100) # Short container to force wrapping
	container._on_sort_children()
	
	# First child should fit in first column
	assert_eq(child1.position, Vector2.ZERO)
	assert_eq(child1.size, Vector2(400, 50))
	
	# Second child should wrap to next column due to insufficient height
	assert_true(child2.position.x > 0)
	assert_eq(child2.position.y, 0)

func test_invisible_child_skipping() -> void:
	child1.visible = false
	container.orientation = BaseContainer.ContainerOrientation.HORIZONTAL
	container.spacing = 10.0
	container._on_sort_children()
	
	# Second child should be positioned at start since first child is invisible
	assert_eq(child2.position, Vector2.ZERO) 