extends "res://addons/gut/test.gd"

const BaseContainer = preload("res://src/ui/components/base/BaseContainer.gd")

var container: BaseContainer

func before_each() -> void:
	container = BaseContainer.new()
	add_child(container)

func after_each() -> void:
	container.queue_free()

func test_initial_setup() -> void:
	assert_not_null(container)
	assert_true(container is Control)
	assert_true(container.size.x > 0)
	assert_true(container.size.y > 0)

func test_minimum_size() -> void:
	var min_size = Vector2(100, 100)
	container.custom_minimum_size = min_size
	
	assert_eq(container.custom_minimum_size, min_size)
	assert_true(container.size.x >= min_size.x)
	assert_true(container.size.y >= min_size.y)

func test_layout_update() -> void:
	var new_size = Vector2(200, 200)
	container.size = new_size
	
	assert_eq(container.size, new_size)

func test_child_addition() -> void:
	var child = Control.new()
	container.add_child(child)
	
	assert_true(child in container.get_children())
	assert_true(child.size.x <= container.size.x)
	assert_true(child.size.y <= container.size.y)

func test_visibility() -> void:
	container.visible = false
	assert_false(container.visible)
	
	container.visible = true
	assert_true(container.visible)

func test_anchors() -> void:
	container.anchor_left = 0
	container.anchor_top = 0
	container.anchor_right = 1
	container.anchor_bottom = 1
	
	assert_eq(container.anchor_left, 0)
	assert_eq(container.anchor_top, 0)
	assert_eq(container.anchor_right, 1)
	assert_eq(container.anchor_bottom, 1)

func test_margins() -> void:
	var margin = 10
	container.add_theme_constant_override("margin_left", margin)
	container.add_theme_constant_override("margin_top", margin)
	container.add_theme_constant_override("margin_right", margin)
	container.add_theme_constant_override("margin_bottom", margin)
	
	assert_eq(container.get_theme_constant("margin_left"), margin)
	assert_eq(container.get_theme_constant("margin_top"), margin)
	assert_eq(container.get_theme_constant("margin_right"), margin)
	assert_eq(container.get_theme_constant("margin_bottom"), margin)