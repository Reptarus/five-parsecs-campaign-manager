@tool
extends "res://tests/fixtures/base_test.gd"

const UIManager := preload("res://src/ui/screens/UIManager.gd")
const OptionsMenu := preload("res://src/ui/screens/gameplay_options_menu.gd")

var ui_manager: Node
var options_menu: Node

func before_each() -> void:
	await super.before_each()
	
	# Set up mobile environment
	simulate_mobile_environment("phone_portrait")
	
	ui_manager = Node.new()
	ui_manager.set_script(UIManager)
	options_menu = Node.new()
	options_menu.set_script(OptionsMenu)
	add_child(ui_manager)
	add_child(options_menu)
	
	# Ensure UI is ready
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	ui_manager = null
	options_menu = null

func test_initial_state() -> void:
	assert_false(options_menu.visible, "Options menu should start hidden")
	assert_true(ui_manager.has_method("show_options"), "UI Manager should have show_options method")
	assert_fits_mobile_screen(options_menu)

func test_show_options() -> void:
	ui_manager.show_options()
	assert_true(options_menu.visible, "Options menu should be visible")
	assert_fits_mobile_screen(options_menu)

func test_hide_options() -> void:
	ui_manager.show_options()
	ui_manager.hide_options()
	assert_false(options_menu.visible, "Options menu should be hidden")

func test_touch_interaction() -> void:
	# Test basic touch interaction
	var button_pos = options_menu.get_node("OptionsButton").global_position
	simulate_touch_event(button_pos, true)
	await get_tree().process_frame
	simulate_touch_event(button_pos, false)
	await get_tree().process_frame
	
	assert_true(options_menu.visible, "Options menu should open on touch")
	
	# Test touch target sizes
	for child in options_menu.get_children():
		if child is BaseButton:
			assert_touch_target_size(child)

func test_responsive_layout() -> void:
	# Test portrait mode
	simulate_mobile_environment("phone_portrait")
	await get_tree().process_frame
	assert_fits_mobile_screen(options_menu, "phone_portrait")
	
	# Test landscape mode
	simulate_mobile_environment("phone_landscape")
	await get_tree().process_frame
	assert_fits_mobile_screen(options_menu, "phone_landscape")
	
	# Test tablet mode
	simulate_mobile_environment("tablet_portrait")
	await get_tree().process_frame
	assert_fits_mobile_screen(options_menu, "tablet_portrait")

func test_scroll_behavior() -> void:
	var scroll_container = options_menu.get_node("ScrollContainer")
	if not scroll_container:
		return
	
	var start_pos = Vector2(100, 100)
	var end_pos = Vector2(100, 300)
	
	# Test scroll gesture
	await simulate_touch_drag(start_pos, end_pos)
	assert_ne(scroll_container.scroll_vertical, 0,
		"ScrollContainer should respond to touch drag")

func test_mobile_performance() -> void:
	var results = await measure_mobile_performance(func():
		ui_manager.show_options()
		await get_tree().process_frame
		ui_manager.hide_options()
		await get_tree().process_frame
	)
	
	# Performance assertions
	assert_true(results.average_fps >= 30.0,
		"Average FPS should be at least 30")
	assert_true(results.minimum_fps >= 20.0,
		"Minimum FPS should be at least 20")
	assert_true(results.memory_delta_kb < 1024,
		"Memory usage increase should be less than 1MB")
	
	gut.p("Mobile UI Performance Results:")
	gut.p("- Average FPS: %.2f" % results.average_fps)
	gut.p("- 95th percentile FPS: %.2f" % results["95th_percentile_fps"])
	gut.p("- Minimum FPS: %.2f" % results.minimum_fps)
	gut.p("- Memory Delta: %.2f KB" % results.memory_delta_kb)
	gut.p("- Draw Calls Delta: %d" % results.draw_calls_delta)
	gut.p("- Objects Delta: %d" % results.objects_delta)

func simulate_touch_event(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)
	await get_tree().process_frame

func simulate_touch_drag(start_pos: Vector2, end_pos: Vector2, duration: float = 0.1) -> void:
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
