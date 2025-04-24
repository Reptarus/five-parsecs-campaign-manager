# This file should be referenced via preload
# Use explicit preloads instead of global class names
@tool
extends Node
class_name GestureManager

## Gesture manager for handling complex touch inputs
##
## Detects swipes, long presses, pinches, and other multi-touch gestures
## and emits signals that can be connected to by UI components

const Self = preload("res://src/ui/components/gesture/GestureManager.gd")

## Emitted when a swipe gesture is detected
signal swipe_detected(direction: Vector2)
## Emitted when a long press is detected
signal long_press_detected(position: Vector2)
## Emitted when a pinch gesture is detected
signal pinch_detected(factor: float)
## Emitted when a tap is detected
signal tap(target: Control, position: Vector2)
## Emitted when a swipe is detected (with target and direction info)
signal swipe(target: Control, start_position: Vector2, end_position: Vector2, direction: int)
## Emitted when a pinch is detected (with target info)
signal pinch(target: Control, factor: float)

## Swipe direction enum for easier direction identification
enum SwipeDirection {
    LEFT,
    RIGHT,
    UP,
    DOWN
}

# Configurable gesture thresholds
var tap_timeout: float = 0.3
var swipe_threshold: float = 50.0
var pinch_threshold: float = 0.1

# Default gesture detection parameters
const MIN_SWIPE_DISTANCE := 50.0
const MAX_SWIPE_TIME := 0.5
const LONG_PRESS_TIME := 0.75
const MIN_PINCH_DISTANCE := 10.0

# Touch tracking
var touch_points := {}
var active_touches := {}
var long_press_timer: Timer
var initial_pinch_distance: float = 0.0

# Target tracking
var _registered_targets: Array[Control] = []

## Set up the gesture manager with timers and input handling
func _ready() -> void:
    if Engine.is_editor_hint():
        return
        
    _setup_long_press_timer()
    set_process_input(true)

## Set up the long press timer
func _setup_long_press_timer() -> void:
    long_press_timer = Timer.new()
    long_press_timer.one_shot = true
    long_press_timer.wait_time = LONG_PRESS_TIME
    long_press_timer.timeout.connect(_on_long_press_timeout)
    add_child(long_press_timer)

## Register a control to receive gesture events
## @param target: The control to register for gesture events
func register_target(target: Control) -> void:
    if not target or not is_instance_valid(target):
        push_warning("GestureManager: Cannot register null or invalid target")
        return
        
    if not _registered_targets.has(target):
        _registered_targets.append(target)

## Unregister a control from receiving gesture events
## @param target: The control to unregister
func unregister_target(target: Control) -> void:
    if not target or not is_instance_valid(target):
        return
        
    var index = _registered_targets.find(target)
    if index >= 0:
        _registered_targets.remove_at(index)

## Check if a target is registered for gesture events
## @param target: The control to check
## @return: True if the target is registered, false otherwise
func is_target_registered(target: Control) -> bool:
    return _registered_targets.has(target)

## Process input events for gesture detection
## This provides compatibility with both _input and _unhandled_input
func _input(event: InputEvent) -> void:
    if Engine.is_editor_hint():
        return
        
    if event is InputEventScreenTouch:
        _handle_touch(event)
    elif event is InputEventScreenDrag:
        _handle_drag(event)

## Also handle unhandled input for better gesture capture
func _unhandled_input(event: InputEvent) -> void:
    # Delegate to _input for consistent handling
    _input(event)

## Handle touch events (press and release)
func _handle_touch(event: InputEventScreenTouch) -> void:
    if event.pressed:
        # Start touch tracking
        touch_points[event.index] = {
            "start_position": event.position,
            "start_time": Time.get_ticks_msec() / 1000.0,
            "current_position": event.position
        }
        
        # Store in active touches
        active_touches[event.index] = touch_points[event.index]
        
        # Start long press detection for single touches
        if touch_points.size() == 1:
            long_press_timer.start()
    else:
        # Handle touch release
        if touch_points.has(event.index):
            var touch = touch_points[event.index]
            var duration = Time.get_ticks_msec() / 1000.0 - touch.start_time
            var distance = touch.start_position.distance_to(event.position)
            
            # Find target under touch point
            var target = _find_target_at_position(event.position)
            
            if duration < tap_timeout and distance < swipe_threshold:
                # Tap detected
                if target:
                    tap.emit(target, event.position)
            elif duration < MAX_SWIPE_TIME and distance > MIN_SWIPE_DISTANCE:
                # Swipe detected
                var direction = _determine_swipe_direction(touch.start_position, event.position)
                var dir_vector = (event.position - touch.start_position).normalized()
                
                # Emit general swipe signal
                swipe_detected.emit(dir_vector)
                
                # Emit targeted swipe signal if we have a target
                if target:
                    swipe.emit(target, touch.start_position, event.position, direction)
            
            # Remove from tracking
            touch_points.erase(event.index)
            active_touches.erase(event.index)
            
        # Stop long press timer if no touches remain
        if touch_points.is_empty():
            long_press_timer.stop()
            initial_pinch_distance = 0.0

## Handle drag events (movement during touch)
func _handle_drag(event: InputEventScreenDrag) -> void:
    if touch_points.has(event.index):
        touch_points[event.index].current_position = event.position
        
        # Handle pinch gesture with two touches
        if touch_points.size() == 2:
            _handle_pinch()
        else:
            # Stop long press timer if significant movement occurs
            var touch = touch_points[event.index]
            if touch.start_position.distance_to(event.position) > MIN_SWIPE_DISTANCE:
                long_press_timer.stop()

## Handle pinch gesture detection
func _handle_pinch() -> void:
    var points = touch_points.values()
    var current_distance = points[0].current_position.distance_to(points[1].current_position)
    
    if initial_pinch_distance == 0:
        initial_pinch_distance = current_distance
    elif abs(current_distance - initial_pinch_distance) > MIN_PINCH_DISTANCE:
        var factor = current_distance / initial_pinch_distance
        
        # Find a suitable target (center point between touches)
        var center = (points[0].current_position + points[1].current_position) / 2
        var target = _find_target_at_position(center)
        
        # Emit general pinch signal
        pinch_detected.emit(factor)
        
        # Emit targeted pinch signal if we have a target
        if target:
            pinch.emit(target, factor)
        
        # Update initial distance for continuous pinch detection
        initial_pinch_distance = current_distance

## Handle long press timeout
func _on_long_press_timeout() -> void:
    if touch_points.size() == 1:
        var touch = touch_points.values()[0]
        var current_position = touch.current_position
        var start_position = touch.start_position
        
        if current_position.distance_to(start_position) < MIN_SWIPE_DISTANCE:
            # Find target at long press position
            var target = _find_target_at_position(current_position)
            
            # Emit long press signal
            long_press_detected.emit(current_position)
            
            # If we have a target, emit specific long press signal
            if target and target.has_signal("long_press"):
                target.emit_signal("long_press", current_position)

## Find a registered target at the given position
## @param position: The screen position to check
## @return: The first registered target at the position, or null if none found
func _find_target_at_position(position: Vector2) -> Control:
    for target in _registered_targets:
        if is_instance_valid(target) and target.visible:
            var local_pos = target.get_global_transform().affine_inverse() * position
            if target.get_rect().has_point(local_pos):
                return target
    return null

## Determine the swipe direction based on start and end positions
## @param start: The start position of the swipe
## @param end: The end position of the swipe
## @return: The SwipeDirection enum value for the swipe
func _determine_swipe_direction(start: Vector2, end: Vector2) -> int:
    var delta = end - start
    
    # Determine primary direction based on dominant axis
    if abs(delta.x) > abs(delta.y):
        return SwipeDirection.RIGHT if delta.x > 0 else SwipeDirection.LEFT
    else:
        return SwipeDirection.DOWN if delta.y > 0 else SwipeDirection.UP

## Set the maximum time for a tap gesture to be recognized
## @param timeout: The timeout in seconds
func set_tap_timeout(timeout: float) -> void:
    tap_timeout = timeout

## Set the minimum distance for a swipe to be recognized
## @param threshold: The threshold in pixels
func set_swipe_threshold(threshold: float) -> void:
    swipe_threshold = threshold

## Set the minimum distance change for a pinch to be recognized
## @param threshold: The threshold as a factor (0-1)
func set_pinch_threshold(threshold: float) -> void:
    pinch_threshold = threshold

## Clean up all gesture tracking
func cleanup() -> void:
    # Clear all tracking data
    touch_points.clear()
    active_touches.clear()
    _registered_targets.clear()
    
    # Stop timers
    if long_press_timer:
        long_press_timer.stop()
    
    # Reset state
    initial_pinch_distance = 0.0