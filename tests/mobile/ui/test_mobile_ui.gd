@tool
extends "res://tests/fixtures/base/mobile_test_base.gd"

# Type-safe script references
const UIManagerScript := preload("res://src/ui/screens/UIManager.gd")
const OptionsMenuScript := preload("res://src/ui/screens/gameplay_options_menu.gd")

# Type-safe instance variables
var _ui_manager: Node = null
var _options_menu: Node = null

# Performance thresholds
const MIN_FPS: float = 30.0
const MIN_MEMORY_MB: float = 1.0
const TOUCH_DURATION: float = 0.1

# Performance testing methods
func measure_performance(callable: Callable, iterations: int = 100) -> Dictionary:
	var results := {
		"fps_samples": [],
		"memory_samples": [],
		"draw_calls": []
	}
	
	for i in range(iterations):
		await callable.call()
		results.fps_samples.append(Engine.get_frames_per_second())
		results.memory_samples.append(Performance.get_monitor(Performance.MEMORY_STATIC))
		results.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		await stabilize_engine(STABILIZE_TIME)
	
	return {
		"average_fps": _calculate_average(results.fps_samples),
		"minimum_fps": _calculate_minimum(results.fps_samples),
		"memory_delta_kb": (_calculate_maximum(results.memory_samples) - _calculate_minimum(results.memory_samples)) / 1024,
		"draw_calls_delta": _calculate_maximum(results.draw_calls) - _calculate_minimum(results.draw_calls)
	}

func _calculate_average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for value in values:
		sum += value
	return sum / values.size()

func _calculate_minimum(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var min_value: float = values[0]
	for value in values:
		min_value = min(min_value, value)
	return min_value

func _calculate_maximum(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var max_value: float = values[0]
	for value in values:
		max_value = max(max_value, value)
	return max_value

func before_each() -> void:
	await super.before_each()
	
	# Set up mobile environment
	await simulate_mobile_environment("phone_portrait")
	
	# Initialize UI components
	_ui_manager = TypeSafeMixin._safe_cast_to_node(Node.new(), "UIManager")
	if not _ui_manager:
		push_error("Failed to create UI manager")
		return
	_ui_manager.set_script(UIManagerScript)
	add_child_autofree(_ui_manager)
	track_test_node(_ui_manager)
	
	_options_menu = TypeSafeMixin._safe_cast_to_node(Node.new(), "OptionsMenu")
	if not _options_menu:
		push_error("Failed to create options menu")
		return
	_options_menu.set_script(OptionsMenuScript)
	add_child_autofree(_options_menu)
	track_test_node(_options_menu)
	
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	await super.after_each()
	_ui_manager = null
	_options_menu = null

func test_initial_state() -> void:
	assert_false(_options_menu.visible, "Options menu should start hidden")
	assert_true(TypeSafeMixin._safe_method_call_bool(_ui_manager, "has_method", ["show_options"]),
		"UI Manager should have show_options method")
	assert_fits_mobile_screen(_options_menu)

func test_show_options() -> void:
	TypeSafeMixin._safe_method_call_bool(_ui_manager, "show_options", [])
	assert_true(_options_menu.visible, "Options menu should be visible")
	assert_fits_mobile_screen(_options_menu)

func test_hide_options() -> void:
	TypeSafeMixin._safe_method_call_bool(_ui_manager, "show_options", [])
	TypeSafeMixin._safe_method_call_bool(_ui_manager, "hide_options", [])
	assert_false(_options_menu.visible, "Options menu should be hidden")

func test_touch_interaction() -> void:
	# Test basic touch interaction
	var button: Control = TypeSafeMixin._safe_cast_to_control(_options_menu.get_node("OptionsButton"), "OptionsButton")
	if not button:
		push_error("Failed to get options button")
		return
		
	var button_pos: Vector2 = button.global_position
	await simulate_touch_event(button_pos, true)
	await get_tree().process_frame
	await simulate_touch_event(button_pos, false)
	await get_tree().process_frame
	
	assert_true(_options_menu.visible, "Options menu should open on touch")
	
	# Test touch target sizes
	for child in _options_menu.get_children():
		if child is BaseButton:
			assert_touch_target_size(child)

func test_responsive_layout() -> void:
	# Test portrait mode
	await simulate_mobile_environment("phone_portrait")
	await stabilize_engine(STABILIZE_TIME)
	assert_fits_mobile_screen(_options_menu)
	
	# Test landscape mode
	await simulate_mobile_environment("phone_landscape")
	await stabilize_engine(STABILIZE_TIME)
	assert_fits_mobile_screen(_options_menu)
	
	# Test tablet mode
	await simulate_mobile_environment("tablet_portrait")
	await stabilize_engine(STABILIZE_TIME)
	assert_fits_mobile_screen(_options_menu)

func test_scroll_behavior() -> void:
	var scroll_container: ScrollContainer = TypeSafeMixin._safe_cast_to_node(_options_menu.get_node("ScrollContainer"), "ScrollContainer")
	if not scroll_container:
		push_error("Failed to get scroll container")
		return
	
	var start_pos := Vector2(100, 100)
	var end_pos := Vector2(100, 300)
	
	# Test scroll gesture
	await simulate_touch_drag(start_pos, end_pos)
	assert_ne(scroll_container.scroll_vertical, 0,
		"ScrollContainer should respond to touch drag")

func test_mobile_performance() -> void:
	var metrics: Dictionary = await measure_performance(
		func() -> void:
			TypeSafeMixin._safe_method_call_bool(_ui_manager, "show_options", [])
			await get_tree().process_frame
			TypeSafeMixin._safe_method_call_bool(_ui_manager, "hide_options", [])
			await get_tree().process_frame
	)
	
	verify_performance_metrics(metrics, {
		"average_fps": MIN_FPS,
		"minimum_fps": MIN_FPS * 0.67,
		"memory_delta_kb": MIN_MEMORY_MB * 1024,
		"draw_calls_delta": 25
	})
	
	print_debug("Mobile UI Performance Results:")
	print_debug("- Average FPS: %.2f" % metrics.get("average_fps", 0.0))
	print_debug("- Minimum FPS: %.2f" % metrics.get("minimum_fps", 0.0))
	print_debug("- Memory Delta: %.2f KB" % metrics.get("memory_delta_kb", 0.0))
	print_debug("- Draw Calls Delta: %d" % metrics.get("draw_calls_delta", 0))

# Helper Methods
func simulate_touch_event(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)
	await get_tree().process_frame

func simulate_touch_drag(start_pos: Vector2, end_pos: Vector2, duration: float = TOUCH_DURATION) -> void:
	await simulate_touch_event(start_pos, true)
	
	var steps := int(duration / 0.016) # ~60fps
	for i in range(steps):
		var t := float(i) / float(steps)
		var current_pos := start_pos.lerp(end_pos, t)
		var event := InputEventScreenDrag.new()
		event.position = current_pos
		event.relative = (end_pos - start_pos) / steps
		Input.parse_input_event(event)
		await get_tree().process_frame
	
	await simulate_touch_event(end_pos, false)
