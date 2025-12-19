extends Node
## GestureManager - Mobile gesture handling
## Note: This scene is orphaned (not referenced by other scenes)
## Consider removing if not needed, or integrating into mobile UI

signal swipe_detected(direction: Vector2)
signal pinch_detected(scale: float)
signal tap_detected(position: Vector2)

var touch_start_position: Vector2 = Vector2.ZERO
var is_tracking: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		touch_start_position = event.position
		is_tracking = true
	else:
		if is_tracking:
			var delta := event.position - touch_start_position
			if delta.length() < 10.0:
				tap_detected.emit(event.position)
			else:
				swipe_detected.emit(delta.normalized())
		is_tracking = false

func _handle_drag(_event: InputEventScreenDrag) -> void:
	# Placeholder for drag handling
	pass
