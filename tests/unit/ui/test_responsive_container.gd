extends "res://addons/gut/test.gd"

const ResponsiveContainer = preload("res://src/ui/components/base/ResponsiveContainer.gd")

var container: ResponsiveContainer
var main_container: Container
var orientation_changed_count: int = 0
var last_orientation_portrait: bool = false

func before_each() -> void:
	container = ResponsiveContainer.new()
	main_container = Container.new()
	main_container.name = "MainContainer"
	
	add_child(container)
	container.add_child(main_container)
	
	orientation_changed_count = 0
	last_orientation_portrait = false
	container.orientation_changed.connect(_on_orientation_changed)

func after_each() -> void:
	container.queue_free()

func _on_orientation_changed(is_portrait: bool) -> void:
	orientation_changed_count += 1
	last_orientation_portrait = is_portrait

func test_initial_setup() -> void:
	assert_not_null(container.main_container)
	assert_false(container.is_portrait)
	assert_eq(container.portrait_threshold, 1.0)
	assert_eq(container.min_width, 300.0)

func test_landscape_mode() -> void:
	container.size = Vector2(800, 600) # Wide layout
	container._check_orientation()
	
	assert_false(container.is_portrait)
	assert_false(container.is_in_portrait_mode())
	assert_eq(orientation_changed_count, 0) # No change from default

func test_portrait_mode_by_ratio() -> void:
	container.size = Vector2(400, 800) # Tall layout
	container._check_orientation()
	
	assert_true(container.is_portrait)
	assert_true(container.is_in_portrait_mode())
	assert_eq(orientation_changed_count, 1)
	assert_true(last_orientation_portrait)

func test_portrait_mode_by_min_width() -> void:
	container.size = Vector2(250, 400) # Narrow layout
	container._check_orientation()
	
	assert_true(container.is_portrait)
	assert_true(container.is_in_portrait_mode())
	assert_eq(orientation_changed_count, 1)
	assert_true(last_orientation_portrait)

func test_orientation_change() -> void:
	# Start in landscape
	container.size = Vector2(800, 600)
	container._check_orientation()
	assert_false(container.is_portrait)
	assert_eq(orientation_changed_count, 0)
	
	# Switch to portrait
	container.size = Vector2(400, 800)
	container._check_orientation()
	assert_true(container.is_portrait)
	assert_eq(orientation_changed_count, 1)
	assert_true(last_orientation_portrait)
	
	# Back to landscape
	container.size = Vector2(800, 600)
	container._check_orientation()
	assert_false(container.is_portrait)
	assert_eq(orientation_changed_count, 2)
	assert_false(last_orientation_portrait)

func test_custom_threshold() -> void:
	container.portrait_threshold = 0.75 # More lenient threshold
	
	# This size would be landscape with default threshold (1.0)
	# but is portrait with custom threshold (0.75)
	container.size = Vector2(600, 800)
	container._check_orientation()
	
	assert_true(container.is_portrait)
	assert_eq(orientation_changed_count, 1)
	assert_true(last_orientation_portrait)

func test_custom_min_width() -> void:
	container.min_width = 500.0 # Higher minimum width
	
	# This size would be landscape normally
	# but is portrait due to custom min_width
	container.size = Vector2(450, 400)
	container._check_orientation()
	
	assert_true(container.is_portrait)
	assert_eq(orientation_changed_count, 1)
	assert_true(last_orientation_portrait)