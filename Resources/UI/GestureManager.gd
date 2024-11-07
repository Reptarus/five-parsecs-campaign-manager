class_name GestureManager
extends Node

signal swipe_detected(direction: Vector2)
signal pinch_detected(scale: float)
signal long_press_detected(position: Vector2)
signal double_tap_detected(position: Vector2)

const MIN_SWIPE_DISTANCE = 50.0
const MIN_PINCH_DISTANCE = 10.0
const DOUBLE_TAP_TIME = 0.3
const LONG_PRESS_TIME = 0.5

var touch_points := {}
var first_tap_time := 0.0
var long_press_timer: Timer

func _ready() -> void:
    long_press_timer = Timer.new()
    long_press_timer.one_shot = true
    long_press_timer.timeout.connect(_on_long_press_timeout)
    add_child(long_press_timer)

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        _handle_touch(event)
    elif event is InputEventScreenDrag:
        _handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
    if event.pressed:
        touch_points[event.index] = event.position
        if event.index == 0:  # Primary touch
            _check_double_tap(event.position)
            long_press_timer.start(LONG_PRESS_TIME)
    else:
        touch_points.erase(event.index)
        long_press_timer.stop()

func _handle_drag(event: InputEventScreenDrag) -> void:
    if touch_points.size() == 1:  # Single finger drag
        var start_pos = touch_points[event.index]
        var drag_vector = event.position - start_pos
        if drag_vector.length() > MIN_SWIPE_DISTANCE:
            swipe_detected.emit(drag_vector.normalized())
            touch_points[event.index] = event.position
    elif touch_points.size() == 2:  # Pinch gesture
        _handle_pinch(event)

func _handle_pinch(event: InputEventScreenDrag) -> void:
    var points = touch_points.values()
    var initial_distance = points[0].distance_to(points[1])
    var current_distance = event.position.distance_to(points[1] if event.index == 0 else points[0])
    var scale = current_distance / initial_distance
    pinch_detected.emit(scale)

func _check_double_tap(position: Vector2) -> void:
    var current_time = Time.get_ticks_msec() / 1000.0
    if current_time - first_tap_time < DOUBLE_TAP_TIME:
        double_tap_detected.emit(position)
        first_tap_time = 0.0
    else:
        first_tap_time = current_time

func _on_long_press_timeout() -> void:
    if not touch_points.is_empty():
        long_press_detected.emit(touch_points[0])
