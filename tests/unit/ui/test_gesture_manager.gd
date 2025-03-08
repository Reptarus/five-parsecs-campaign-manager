@tool
extends "res://tests/fixtures/specialized/ui_test.gd"

const GestureManager := preload("res://src/ui/components/gesture/GestureManager.gd")

# Type-safe instance variables
var _manager: GestureManager
var _last_swipe_direction: Vector2
var _last_long_press_position: Vector2
var _last_pinch_factor: float

func before_each() -> void:
	await super.before_each()
	_setup_manager()
	_reset_state()
	_connect_signals()

func after_each() -> void:
	_cleanup_manager()
	_reset_state()
	await super.after_each()

func _setup_manager() -> void:
	_manager = GestureManager.new()
	add_child_autofree(_manager)
	track_test_node(_manager)
	await stabilize_engine()

func _cleanup_manager() -> void:
	_manager = null

func _reset_state() -> void:
	_last_swipe_direction = Vector2.ZERO
	_last_long_press_position = Vector2.ZERO
	_last_pinch_factor = 0.0

func _connect_signals() -> void:
	if not _manager:
		return
	_manager.swipe_detected.connect(_on_swipe)
	_manager.long_press_detected.connect(_on_long_press)
	_manager.pinch_detected.connect(_on_pinch)

func _on_swipe(direction: Vector2) -> void:
	_last_swipe_direction = direction

func _on_long_press(position: Vector2) -> void:
	_last_long_press_position = position

func _on_pinch(factor: float) -> void:
	_last_pinch_factor = factor

func test_initial_setup() -> void:
	assert_not_null(_manager)
	assert_not_null(_manager.long_press_timer)
	assert_eq(_manager.MIN_SWIPE_DISTANCE, 50.0)
	assert_eq(_manager.MAX_SWIPE_TIME, 0.5)
	assert_eq(_manager.LONG_PRESS_TIME, 0.75)
	assert_eq(_manager.MIN_PINCH_DISTANCE, 10.0)

func test_touch_handling() -> void:
	var touch_event := InputEventScreenTouch.new()
	touch_event.pressed = true
	touch_event.position = Vector2(100, 100)
	
	_manager._handle_touch(touch_event)
	assert_true(_manager.touch_points.has(touch_event.index))
	assert_eq(_manager.touch_points[touch_event.index].start_position, touch_event.position)

func test_swipe_detection() -> void:
	var start_touch := InputEventScreenTouch.new()
	start_touch.pressed = true
	start_touch.position = Vector2(100, 100)
	
	var end_touch := InputEventScreenTouch.new()
	end_touch.pressed = false
	end_touch.position = Vector2(200, 100) # Horizontal swipe
	
	_manager._handle_touch(start_touch)
	_manager._handle_touch(end_touch)
	
	assert_signal_emitted(_manager, "swipe_detected")
	assert_eq(_last_swipe_direction.x, 1.0) # Right swipe

func test_long_press_detection() -> void:
	var touch_event := InputEventScreenTouch.new()
	touch_event.pressed = true
	touch_event.position = Vector2(100, 100)
	
	_manager._handle_touch(touch_event)
	_manager._on_long_press_timeout()
	
	assert_signal_emitted(_manager, "long_press_detected")
	assert_eq(_last_long_press_position, touch_event.position)

func test_pinch_detection() -> void:
	var touch1 := InputEventScreenTouch.new()
	touch1.pressed = true
	touch1.position = Vector2(100, 100)
	touch1.index = 0
	
	var touch2 := InputEventScreenTouch.new()
	touch2.pressed = true
	touch2.position = Vector2(200, 200)
	touch2.index = 1
	
	_manager._handle_touch(touch1)
	_manager._handle_touch(touch2)
	
	var drag2 := InputEventScreenDrag.new()
	drag2.position = Vector2(300, 300)
	drag2.index = 1
	
	_manager._handle_drag(drag2)
	
	assert_signal_emitted(_manager, "pinch_detected")
	assert_gt(_last_pinch_factor, 1.0) # Pinch out

func test_gesture_interaction() -> void:
	# Test swipe in different directions
	var directions := [
		Vector2(1, 0), # Right
		Vector2(-1, 0), # Left
		Vector2(0, 1), # Down
		Vector2(0, -1) # Up
	]
	
	for direction in directions:
		var start_touch := InputEventScreenTouch.new()
		start_touch.pressed = true
		start_touch.position = Vector2(100, 100)
		
		var end_touch := InputEventScreenTouch.new()
		end_touch.pressed = false
		end_touch.position = start_touch.position + direction * 100
		
		_manager._handle_touch(start_touch)
		_manager._handle_touch(end_touch)
		
		assert_signal_emitted(_manager, "swipe_detected")
		assert_eq(_last_swipe_direction.normalized(), direction)
		await get_tree().process_frame

func test_multi_touch_handling() -> void:
	# Test handling multiple touches simultaneously
	var touches: Array[InputEventScreenTouch] = []
	for i in range(3):
		var touch := InputEventScreenTouch.new()
		touch.pressed = true
		touch.position = Vector2(100 + i * 50, 100)
		touch.index = i
		touches.append(touch)
		_manager._handle_touch(touch)
	
	for touch in touches:
		assert_true(_manager.touch_points.has(touch.index))
		assert_eq(_manager.touch_points[touch.index].start_position, touch.position)
	
	# Release touches in reverse order
	for i in range(touches.size() - 1, -1, -1):
		var touch := touches[i]
		touch.pressed = false
		_manager._handle_touch(touch)
		assert_false(_manager.touch_points.has(touch.index))

func test_gesture_cancellation() -> void:
	# Test cancelling gestures
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(100, 100)
	
	_manager._handle_touch(touch)
	_manager.touch_points.clear()
	_manager.long_press_timer.stop()
	
	assert_eq(_manager.touch_points.size(), 0)
	assert_false(_manager.long_press_timer.is_paused()) # If stopped, it won't be paused

func test_input_handling() -> void:
	# Test unhandled input handling
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(100, 100)
	
	_manager._unhandled_input(touch)
	assert_true(_manager.touch_points.has(touch.index))
	
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(150, 150)
	drag.index = touch.index
	
	_manager._unhandled_input(drag)
	assert_eq(_manager.touch_points[touch.index].current_position, drag.position)