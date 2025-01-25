@tool
class_name GutInputSender
extends Node
const GutUtils = preload("res://addons/gut/utils.gd")

## The InputSender class.  It sends input to places.
##
## This is the full description that has not yet been filled in.

# Implemented InputEvent* convenience methods
# 	InputEventAction
# 	InputEventKey
# 	InputEventMouseButton
#	InputEventMouseMotion

# Yet to implement InputEvents
# 	InputEventJoypadButton
# 	InputEventJoypadMotion
# 	InputEventMagnifyGesture
# 	InputEventMIDI
# 	InputEventPanGesture
# 	InputEventScreenDrag
# 	InputEventScreenTouch


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
class InputQueueItem:
	extends Node

	var events = []
	var time_delay = null
	var frame_delay = null
	var _waited_frames = 0
	var _is_ready = false
	var _delay_started = false

	signal event_ready

	# TODO should this be done in _physics_process instead or should it be
	# configurable?
	func _physics_process(delta):
		if (frame_delay > 0 and _delay_started):
			_waited_frames += 1
			if (_waited_frames >= frame_delay):
				event_ready.emit()

	func _init(t_delay, f_delay):
		time_delay = t_delay
		frame_delay = f_delay
		_is_ready = time_delay == 0 and frame_delay == 0

	func _on_time_timeout():
		_is_ready = true
		event_ready.emit()

	func _delay_timer(t):
		return Engine.get_main_loop().root.get_tree().create_timer(t)

	func is_ready():
		return _is_ready

	func start():
		_delay_started = true
		if (time_delay > 0):
			var t = _delay_timer(time_delay)
			t.connect("timeout", Callable(self, "_on_time_timeout"))

