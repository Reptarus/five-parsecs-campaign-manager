extends "res://addons/gut/test.gd"

const GestureManager = preload("res://src/ui/components/gesture/GestureManager.gd")

var manager: GestureManager
var swipe_detected := false
var long_press_detected := false
var pinch_detected := false
var last_swipe_direction: Vector2
var last_long_press_position: Vector2
var last_pinch_factor: float

func before_each() -> void:
	manager = GestureManager.new()
	add_child(manager)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	manager.queue_free()

func _reset_signals() -> void:
	swipe_detected = false
	long_press_detected = false
	pinch_detected = false
	last_swipe_direction = Vector2.ZERO
	last_long_press_position = Vector2.ZERO
	last_pinch_factor = 0.0

func _connect_signals() -> void:
	manager.swipe_detected.connect(_on_swipe)
	manager.long_press_detected.connect(_on_long_press)
	manager.pinch_detected.connect(_on_pinch)

func _on_swipe(direction: Vector2) -> void:
	swipe_detected = true
	last_swipe_direction = direction

func _on_long_press(position: Vector2) -> void:
	long_press_detected = true
	last_long_press_position = position

func _on_pinch(factor: float) -> void:
	pinch_detected = true
	last_pinch_factor = factor

func test_initial_setup() -> void:
	assert_not_null(manager)
	assert_not_null(manager.long_press_timer)
	assert_eq(manager.MIN_SWIPE_DISTANCE, 50.0)
	assert_eq(manager.MAX_SWIPE_TIME, 0.5)
	assert_eq(manager.LONG_PRESS_TIME, 0.75)
	assert_eq(manager.MIN_PINCH_DISTANCE, 10.0)

func test_touch_handling() -> void:
	var touch_event = InputEventScreenTouch.new()
	touch_event.pressed = true
	touch_event.position = Vector2(100, 100)
	
	manager._handle_touch(touch_event)
	assert_true(manager.touch_points.has(touch_event.index))
	assert_eq(manager.touch_points[touch_event.index].start_position, touch_event.position)

func test_swipe_detection() -> void:
	var start_touch = InputEventScreenTouch.new()
	start_touch.pressed = true
	start_touch.position = Vector2(100, 100)
	
	var end_touch = InputEventScreenTouch.new()
	end_touch.pressed = false
	end_touch.position = Vector2(200, 100) # Horizontal swipe
	
	manager._handle_touch(start_touch)
	manager._handle_touch(end_touch)
	
	assert_true(swipe_detected)
	assert_eq(last_swipe_direction.x, 1.0) # Right swipe

func test_long_press_detection() -> void:
	var touch_event = InputEventScreenTouch.new()
	touch_event.pressed = true
	touch_event.position = Vector2(100, 100)
	
	manager._handle_touch(touch_event)
	manager._on_long_press_timeout()
	
	assert_true(long_press_detected)
	assert_eq(last_long_press_position, touch_event.position)

func test_pinch_detection() -> void:
	var touch1 = InputEventScreenTouch.new()
	touch1.pressed = true
	touch1.position = Vector2(100, 100)
	touch1.index = 0
	
	var touch2 = InputEventScreenTouch.new()
	touch2.pressed = true
	touch2.position = Vector2(200, 200)
	touch2.index = 1
	
	manager._handle_touch(touch1)
	manager._handle_touch(touch2)
	
	var drag2 = InputEventScreenDrag.new()
	drag2.position = Vector2(300, 300)
	drag2.index = 1
	
	manager._handle_drag(drag2)
	
	assert_true(pinch_detected)   