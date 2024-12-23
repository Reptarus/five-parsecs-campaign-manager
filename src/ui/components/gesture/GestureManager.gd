class_name GestureManager
extends Node

signal swipe_detected(direction: Vector2)
signal long_press_detected(position: Vector2)
signal pinch_detected(factor: float)

const MIN_SWIPE_DISTANCE := 50.0
const MAX_SWIPE_TIME := 0.5
const LONG_PRESS_TIME := 0.75
const MIN_PINCH_DISTANCE := 10.0

var touch_points := {}
var long_press_timer: Timer
var initial_pinch_distance: float

func _ready() -> void:
    _setup_long_press_timer()

func _setup_long_press_timer() -> void:
    long_press_timer = Timer.new()
    long_press_timer.one_shot = true
    long_press_timer.wait_time = LONG_PRESS_TIME
    long_press_timer.timeout.connect(_on_long_press_timeout)
    add_child(long_press_timer)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        _handle_touch(event)
    elif event is InputEventScreenDrag:
        _handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
    if event.pressed:
        touch_points[event.index] = {
            "start_position": event.position,
            "start_time": Time.get_ticks_msec() / 1000.0,
            "current_position": event.position
        }
        
        if touch_points.size() == 1:
            long_press_timer.start()
    else:
        if touch_points.has(event.index):
            var touch = touch_points[event.index]
            var duration = Time.get_ticks_msec() / 1000.0 - touch.start_time
            var distance = touch.start_position.distance_to(event.position)
            
            if duration < MAX_SWIPE_TIME and distance > MIN_SWIPE_DISTANCE:
                var direction = (event.position - touch.start_position).normalized()
                swipe_detected.emit(direction)
            
            touch_points.erase(event.index)
            
        if touch_points.is_empty():
            long_press_timer.stop()

func _handle_drag(event: InputEventScreenDrag) -> void:
    if touch_points.has(event.index):
        touch_points[event.index].current_position = event.position
        
        if touch_points.size() == 2:
            _handle_pinch()
        else:
            long_press_timer.stop()

func _handle_pinch() -> void:
    var points = touch_points.values()
    var current_distance = points[0].current_position.distance_to(points[1].current_position)
    
    if initial_pinch_distance == 0:
        initial_pinch_distance = current_distance
    elif abs(current_distance - initial_pinch_distance) > MIN_PINCH_DISTANCE:
        var factor = current_distance / initial_pinch_distance
        pinch_detected.emit(factor)
        initial_pinch_distance = current_distance

func _on_long_press_timeout() -> void:
    if touch_points.size() == 1:
        var touch = touch_points.values()[0]
        var current_position = touch.current_position
        var start_position = touch.start_position
        
        if current_position.distance_to(start_position) < MIN_SWIPE_DISTANCE:
            long_press_detected.emit(current_position) 