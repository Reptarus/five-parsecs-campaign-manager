@tool
extends GameTest
class_name MobileTestBase

# Mobile test helpers
func create_test_game_state() -> Node:
	var state := Node.new()
	add_child_autofree(state)
	return state

# Screen resolution helpers
func set_test_resolution(width: int, height: int) -> void:
	var window := get_window()
	if window:
		window.size = Vector2i(width, height)
		await get_tree().process_frame

func restore_resolution() -> void:
	var window := get_window()
	if window:
		window.size = Vector2i(1920, 1080) # Default test resolution
		await get_tree().process_frame

# Device simulation helpers
func simulate_device_dpi(dpi: int) -> void:
	# Store original DPI
	var original_dpi := DisplayServer.screen_get_dpi()
	
	# Set test DPI
	# Note: This is a mock implementation since we can't actually change DPI
	push_warning("DPI simulation not fully implemented")
	
	await get_tree().process_frame

func restore_device_dpi() -> void:
	# Restore original DPI
	# Note: This is a mock implementation
	push_warning("DPI restoration not fully implemented")
	
	await get_tree().process_frame

# Touch input simulation
func simulate_touch_press(position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.pressed = true
	Input.parse_input_event(event)

func simulate_touch_release(position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.pressed = false
	Input.parse_input_event(event)

func simulate_touch_drag(from: Vector2, to: Vector2, steps: int = 10) -> void:
	var step_size := (to - from) / steps
	var current := from
	
	simulate_touch_press(from)
	
	for i in range(steps):
		current += step_size
		var event := InputEventScreenDrag.new()
		event.position = current
		event.relative = step_size
		Input.parse_input_event(event)
		await get_tree().process_frame
	
	simulate_touch_release(to)

# Orientation helpers
func simulate_portrait_orientation() -> void:
	# Mock implementation
	push_warning("Orientation simulation not fully implemented")
	await get_tree().process_frame

func simulate_landscape_orientation() -> void:
	# Mock implementation
	push_warning("Orientation simulation not fully implemented")
	await get_tree().process_frame

# Mobile-specific assertions
func assert_fits_screen(control: Control, message: String = "") -> void:
	var screen_size := DisplayServer.window_get_size()
	var control_size := control.get_rect().size
	
	assert_true(control_size.x <= screen_size.x and control_size.y <= screen_size.y,
		message if message else "Control should fit within screen bounds")

func assert_touch_target_size(control: Control, message: String = "") -> void:
	var min_touch_size := Vector2(44, 44) # Standard minimum touch target size
	var control_size := control.get_rect().size
	
	assert_true(control_size.x >= min_touch_size.x and control_size.y >= min_touch_size.y,
		message if message else "Control should meet minimum touch target size requirements")

# Mobile-specific test utilities
func add_child_autofree(node: Node) -> Node:
	add_child(node)
	node.queue_free_on_exit = true
	return node