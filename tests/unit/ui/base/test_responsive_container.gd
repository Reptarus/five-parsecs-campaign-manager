extends "res://addons/gut/test.gd"

const ResponsiveContainer = preload("res://src/ui/components/base/ResponsiveContainer.gd")

var container: ResponsiveContainer
var layout_changed_signal_emitted := false
var last_layout: String

func before_each() -> void:
	container = ResponsiveContainer.new()
	add_child(container)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	container.queue_free()

func _reset_signals() -> void:
	layout_changed_signal_emitted = false
	last_layout = ""

func _connect_signals() -> void:
	container.layout_changed.connect(_on_layout_changed)

func _on_layout_changed(new_layout: String) -> void:
	layout_changed_signal_emitted = true
	last_layout = new_layout

func test_initial_setup() -> void:
	assert_not_null(container)
	assert_true(container is Control)
	assert_true(container.size.x > 0)
	assert_true(container.size.y > 0)

func test_layout_change() -> void:
	# Test desktop layout
	container.size = Vector2(1920, 1080)
	container._update_layout()
	
	assert_true(layout_changed_signal_emitted)
	assert_eq(last_layout, "desktop")
	
	# Reset signals
	_reset_signals()
	
	# Test tablet layout
	container.size = Vector2(1024, 768)
	container._update_layout()
	
	assert_true(layout_changed_signal_emitted)
	assert_eq(last_layout, "tablet")
	
	# Reset signals
	_reset_signals()
	
	# Test mobile layout
	container.size = Vector2(480, 800)
	container._update_layout()
	
	assert_true(layout_changed_signal_emitted)
	assert_eq(last_layout, "mobile")

func test_minimum_size() -> void:
	var min_size = Vector2(320, 480) # Typical minimum mobile size
	container.custom_minimum_size = min_size
	
	assert_eq(container.custom_minimum_size, min_size)
	assert_true(container.size.x >= min_size.x)
	assert_true(container.size.y >= min_size.y)

func test_layout_persistence() -> void:
	# Set desktop layout
	container.size = Vector2(1920, 1080)
	container._update_layout()
	var initial_layout = last_layout
	
	# Resize slightly but stay in desktop range
	container.size = Vector2(1800, 1000)
	container._update_layout()
	
	assert_eq(last_layout, initial_layout)

func test_layout_thresholds() -> void:
	# Test desktop threshold
	container.size = Vector2(1366, 768)
	container._update_layout()
	assert_eq(last_layout, "desktop")
	
	# Test tablet threshold
	container.size = Vector2(768, 1024)
	container._update_layout()
	assert_eq(last_layout, "tablet")
	
	# Test mobile threshold
	container.size = Vector2(320, 480)
	container._update_layout()
	assert_eq(last_layout, "mobile")

func test_orientation_change() -> void:
	# Test landscape
	container.size = Vector2(1024, 768)
	container._update_layout()
	var landscape_layout = last_layout
	
	# Test portrait
	container.size = Vector2(768, 1024)
	container._update_layout()
	var portrait_layout = last_layout
	
	assert_ne(landscape_layout, portrait_layout)

func test_child_layout() -> void:
	var child = Control.new()
	container.add_child(child)
	
	# Test desktop layout
	container.size = Vector2(1920, 1080)
	container._update_layout()
	
	assert_true(child.size.x <= container.size.x)
	assert_true(child.size.y <= container.size.y)
	
	# Test mobile layout
	container.size = Vector2(320, 480)
	container._update_layout()
	
	assert_true(child.size.x <= container.size.x)
	assert_true(child.size.y <= container.size.y)