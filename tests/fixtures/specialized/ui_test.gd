@tool
extends "res://tests/fixtures/base/game_test.gd"

# Base class for UI tests providing common UI test functionality

# Use explicit preloads instead of global class names
const TestEnums = preload("res://tests/fixtures/base/test_helper.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Signal watcher for UI interaction tests - use a different name to avoid conflict
var _ui_signal_watcher = null

# UI elements being tested
var _ui_root: Control = null
var _tracked_ui_nodes: Array = []

func _init() -> void:
	# Initialize signal watcher
	if has_method("watch_signals"):
		_ui_signal_watcher = self
	
func before_each() -> void:
	await super.before_each()
	_tracked_ui_nodes.clear()

func after_each() -> void:
	_cleanup_ui_nodes()
	await super.after_each()

func _cleanup_ui_nodes() -> void:
	for node in _tracked_ui_nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()
	_tracked_ui_nodes.clear()

# Track a UI node for automatic cleanup
func track_ui_node(node: Control) -> void:
	if node and not _tracked_ui_nodes.has(node):
		_tracked_ui_nodes.append(node)

# Helper method to ensure safe method calls on UI nodes
func _call_ui_method(ui_element: Control, method: String, args: Array = []):
	if not is_instance_valid(ui_element):
		push_error("Cannot call method '%s' on invalid UI element" % method)
		return null
	
	if not ui_element.has_method(method):
		push_error("UI element does not have method: %s" % method)
		return null
	
	return ui_element.callv(method, args)

# Helper for simulating UI events
func simulate_click(ui_element: Control, position: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(ui_element):
		push_error("Cannot simulate click on invalid UI element")
		return
	
	if position == Vector2.ZERO:
		position = ui_element.size / 2 # Center of the control
	
	# Create and feed the event
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	ui_element._gui_input(event)
	
	# Release
	event.pressed = false
	ui_element._gui_input(event)

# Helper for testing focus behavior
func verify_focus_chain(controls: Array, direction: String = "next") -> bool:
	if controls.size() < 2:
		push_warning("Need at least 2 controls to test focus chain")
		return false
	
	var all_focused = true
	for i in range(controls.size() - 1):
		var current = controls[i]
		var next = controls[i + 1]
		
		if not current or not next:
			push_error("Invalid control in focus chain")
			return false
		
		# Set focus on current
		current.grab_focus()
		
		# Verify current has focus
		all_focused = all_focused and current.has_focus()
		
		# Simulate tab navigation
		var event = InputEventKey.new()
		event.keycode = KEY_TAB
		if direction == "prev":
			event.shift_pressed = true
		event.pressed = true
		Input.parse_input_event(event)
		
		# Verify next gets focus
		all_focused = all_focused and next.has_focus()
	
	return all_focused