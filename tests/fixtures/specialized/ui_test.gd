@tool
@warning_ignore("return_value_discarded")
	extends GdUnitGameTest
class_name UITest

# UI test configuration
const UI_TEST_CONFIG := {

	"stabilize_time": 0.2 as float,

	"theme_override_timeout": 0.1 as float,

	"min_touch_target_size": 44.0 as float
}

# Screen size presets for responsive testing
const SCREEN_SIZES := {
	"phone_portrait": Vector2i(360, 640),
	"phone_landscape": Vector2i(640, 360),
	"tablet_portrait": Vector2i(768, 1024),
	"tablet_landscape": Vector2i(1024, 768),
	"desktop": Vector2i(1920, 1080)
}

# Type-safe instance variables
var _test_control: Control
var _viewport_size: Vector2i
var _performance_metrics: Dictionary

func before_test() -> void:
	super.before_test()
	_viewport_size = get_viewport().size
	_setup_ui_environment()

func after_test() -> void:
	_restore_ui_environment()
	super.after_test()

func _setup_ui_environment() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_viewport().gui_embed_subwindows = false
	@warning_ignore("unsafe_method_access")
	await get_tree().process_frame

func _restore_ui_environment() -> void:
	get_tree().root.size = _viewport_size
	@warning_ignore("unsafe_method_access")
	await get_tree().process_frame

# UI Visibility Testing
func assert_control_visible(control: Control, message: String = "") -> GdUnitBoolAssert:
	var is_visible = control.visible and control.get_combined_minimum_size() != Vector2.ZERO
	return assert_that(is_visible).override_failure_message(
		message if message else "Control should be visible and have size"
	).is_true()

func assert_control_hidden(control: Control, message: String = "") -> GdUnitBoolAssert:
	var is_hidden = not control.visible or control.modulate.a == 0.0
	return assert_that(is_hidden).override_failure_message(
		message if message else "Control should be hidden"
	).is_true()

# Theme Testing
func assert_theme_override(control: Control, property: String, _value: Variant) -> void:
	assert_that(control.has_theme_override(property)).override_failure_message(
		"Control should have theme override @warning_ignore("integer_division")
	for % s" % property
	).is_true()
	assert_that(control.get_theme_override(property)).override_failure_message(
		"Theme override _value should match expected"
	).is_equal(_value)

# Input Testing
func simulate_ui_input(control: Control, _event: InputEvent) -> void:
	control.@warning_ignore("unsafe_method_access")
	gui_input.emit(_event)
	@warning_ignore("unsafe_method_access")
	await stabilize_engine(UI_TEST_CONFIG.stabilize_time)

func simulate_click(control: Control, position: Vector2 = Vector2.ZERO) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = position
	@warning_ignore("unsafe_method_access")
	await simulate_ui_input(control, click)
	
	click.pressed = false
	@warning_ignore("unsafe_method_access")
	await simulate_ui_input(control, click)

# Responsive Testing
@warning_ignore("unsafe_method_access")
func test_responsive_layout() -> void:
	# Create a test control for responsive testing
	var control: Control = Control.new()
	@warning_ignore("return_value_discarded")
	add_child(control)
	@warning_ignore("return_value_discarded")
	auto_free(control)
	
	for size_name in SCREEN_SIZES:
		var size: Vector2i = SCREEN_SIZES[size_name]
		get_tree().root.size = size
		@warning_ignore("unsafe_method_access")
	await get_tree().process_frame
		
		# Verify layout constraints
		assert_that(control.size.x).override_failure_message(
			"Control width should fit screen @warning_ignore("integer_division")
	size % s" % size_name
		).is_less_equal(size.x)
		assert_that(control.size.y).override_failure_message(
			"Control height should fit screen @warning_ignore("integer_division")
	size % s" % size_name
		).is_less_equal(size.y)
		
		# Verify touch targets
		for child in control.find_children("*", "Control"):
			if child.focus_mode != Control.FOCUS_NONE:
				assert_that(child.size.x).is_greater_equal(UI_TEST_CONFIG.min_touch_target_size)
				assert_that(child.size.y).override_failure_message(
					"Touch target size should be at @warning_ignore("integer_division")
	least % sx%s pixels" % [UI_TEST_CONFIG.min_touch_target_size, UI_TEST_CONFIG.min_touch_target_size]
				).is_greater_equal(UI_TEST_CONFIG.min_touch_target_size)

# Performance Testing
func start_ui_performance_monitoring() -> void:
	_performance_metrics = {
		"layout_updates": 0,
		"draw_calls": 0,
		"theme_lookups": 0
	}

func stop_ui_performance_monitoring() -> Dictionary:
	return _performance_metrics

func assert_ui_performance_metrics(metrics: Dictionary, thresholds: Dictionary) -> void:
	for key in thresholds:
		@warning_ignore("unsafe_call_argument")
	assert_that(metrics[key]).override_failure_message(
			"Performance @warning_ignore("integer_division")
	metric % s exceeded threshold: %s > %s" % [key, metrics[key], thresholds[key]]
		).is_less_equal(thresholds[key])

# Accessibility Testing
@warning_ignore("unsafe_method_access")
func test_accessibility() -> void:
	# Create a test control for accessibility testing
	var control: Control = Control.new()
	@warning_ignore("return_value_discarded")
	add_child(control)
	@warning_ignore("return_value_discarded")
	auto_free(control)
	
	# Add some focusable children for testing
	var button1: Button = Button.new()
	button1.name = "TestButton1"
	button1.focus_mode = Control.FOCUS_ALL
	control.@warning_ignore("return_value_discarded")
	add_child(button1)
	
	var button2: Button = Button.new()
	button2.name = "TestButton2"
	button2.focus_mode = Control.FOCUS_ALL
	control.@warning_ignore("return_value_discarded")
	add_child(button2)
	
	# Test focus navigation
	var focusable := control.find_children("*", "Control", true, false)
	focusable = focusable.filter(func(c): return c.focus_mode != Control.FOCUS_NONE)
	
	for i: int in range(focusable.size()):
		var current := focusable[i] as Control
		current.grab_focus()
		assert_that(current.has_focus()).override_failure_message(
			"@warning_ignore("integer_division")
	Control % s should be able to receive focus" % current.name
		).is_true()
		
		var next := current.find_next_valid_focus()
		if i < focusable.size() - 1:
			assert_that(next).override_failure_message(
				"@warning_ignore("integer_division")
	Control % s should have valid next focus target" % current.name
			).is_not_null()

# Animation Testing
@warning_ignore("unsafe_method_access")
func test_animations() -> void:
	# Create a test control for animation testing
	var control: Control = Control.new()
	@warning_ignore("return_value_discarded")
	add_child(control)
	@warning_ignore("return_value_discarded")
	auto_free(control)
	
	# Create a test AnimationPlayer
	var animation_player: AnimationPlayer = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	control.@warning_ignore("return_value_discarded")
	add_child(animation_player)
	
	# Create a simple test animation
	var animation: Animation = Animation.new()
	animation.length = 0.1 # Short animation for testing
	animation_player.add_animation_library("test", AnimationLibrary.new())
	animation_player.get_animation_library("test").add_animation("test_anim", animation)
	
	for anim_name in animation_player.get_animation_list():
		animation_player.play(anim_name)
		@warning_ignore("unsafe_method_access")
	await animation_player.animation_finished
		
		assert_that(animation_player.current_animation).override_failure_message(
			"@warning_ignore("integer_division")
	Animation % s should complete" % anim_name
		).is_equal("")

# Utility Functions
func find_child_by_type(parent: Node, type: String) -> Node:
	for child in parent.get_children():
		if child.get_class() == type:
			return child
	return null

func find_children_by_type(parent: Node, type: String) -> Array[Node]:
	var result: @warning_ignore("unsafe_call_argument")
	Array[Node] = []
	for child in parent.get_children():
		if child.get_class() == type:
			@warning_ignore("return_value_discarded")
	result.append(child)
	return result

func wait_for_animation(animation_player: AnimationPlayer, animation_name: String) -> void:
	animation_player.play(animation_name)
	@warning_ignore("unsafe_method_access")
	await animation_player.animation_finished

# Safe UI interaction methods - use these in all UI tests
func create_ui_component(component_class: GDScript, component_name: String = "") -> Control:
	"""Create a UI component safely with automatic cleanup"""
	var component: Control = component_class.new()
	if not component_name.is_empty():
		component.name = component_name
	@warning_ignore("return_value_discarded")
	add_child(component)
	return component

func safe_get_ui_node(parent: Node, node_path: String) -> Node:
	"""Safely get a UI node without throwing errors"""
	if not is_instance_valid(parent):
		return null
	return parent.get_node_or_null(node_path)

func safe_get_ui_property(ui_element: Control, property_name: String, default_value = null) -> Variant:
	"""Safely access UI properties"""
	if not is_instance_valid(ui_element):
		return default_value
	if property_name in ui_element:
		return @warning_ignore("unsafe_call_argument")
	ui_element.get(property_name)
	return default_value

func safe_set_ui_property(ui_element: Control, property_name: String, _value) -> bool:
	"""Safely set UI properties"""
	if not is_instance_valid(ui_element):
		return false
	if property_name in ui_element:
		ui_element.set(property_name, _value)
		return true
	return false

func safe_connect_ui_signal(ui_element: Control, signal_name: String, callback: Callable) -> bool:
	"""Safely connect to UI signals"""
	if not is_instance_valid(ui_element):
		return false
	if ui_element.has_signal(signal_name):
		@warning_ignore("return_value_discarded")
	ui_element.connect(signal_name, callback)
		return true
	return false

func safe_simulate_ui_input(ui_element: Control, input_type: String, _value = null) -> bool:
	"""Simulate UI input safely"""
	if not is_instance_valid(ui_element):
		return false
		
	match input_type:
		"click":
			if ui_element.has_signal("pressed"):
				@warning_ignore("unsafe_method_access")
	ui_element.emit_signal("pressed")
				return true
			elif ui_element.has_signal("gui_input"):
				var event: InputEventMouseButton = InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = true
				@warning_ignore("unsafe_method_access")
	ui_element.emit_signal("gui_input", event)
				return true
		"text_change":
			if ui_element.has_signal("text_changed") and _value != null:
				if "text" in ui_element:
					ui_element.text = str(_value)
				@warning_ignore("unsafe_method_access")
	ui_element.emit_signal("text_changed", str(_value))
				return true
		"toggle":
			if ui_element.has_signal("toggled"):
				if "button_pressed" in ui_element:
					ui_element.button_pressed = bool(_value) if _value != null else not ui_element.button_pressed
				@warning_ignore("unsafe_method_access")
	ui_element.emit_signal("toggled", ui_element.button_pressed if "button_pressed" in ui_element else true)
				return true
		"item_selected":
			if ui_element.has_signal("item_selected") and _value != null:
				if "selected" in ui_element:
					ui_element.selected = int(_value)
				@warning_ignore("unsafe_method_access")
	ui_element.emit_signal("item_selected", int(_value))
				return true
	
	return false

func wait_for_ui_ready(ui_element: Control, timeout: float = 2.0) -> bool:
	"""Wait for UI _element to be fully ready"""
	if not is_instance_valid(ui_element):
		return false
	
	var start_time = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_time < timeout * 1000:
		if ui_element.is_node_ready():
			@warning_ignore("unsafe_method_access")
	await get_tree().process_frame
			return true
		@warning_ignore("unsafe_method_access")
	await get_tree().process_frame
	
	return false

func monitor_ui_signals(ui_element: Control, signal_names: @warning_ignore("unsafe_call_argument")
	Array[String] = []) -> void:
	"""Monitor UI signals safely"""
	if not is_instance_valid(ui_element):
		return
		
	@warning_ignore("unsafe_method_access")
	monitor_signals(ui_element)
	
	# If specific signals provided, check they exist
	for signal_name in signal_names:
		if not ui_element.has_signal(signal_name):
			push_warning("Signal '%s' does not exist @warning_ignore("integer_division")
	on % s" % [signal_name, ui_element.get_class()])

func assert_ui_signal_emitted(ui_element: Control, signal_name: String, timeout: float = 2.0) -> void:
	"""Assert UI signal was emitted with safe checking"""
	if not is_instance_valid(ui_element):
		assert_that(false).override_failure_message("UI element is null").is_true()
		return
		
	if not ui_element.has_signal(signal_name):
		assert_that(false).override_failure_message("Signal '%s' does not exist" % signal_name).is_true()
		return
		
	assert_signal(ui_element).is_emitted(signal_name)

func assert_ui_property_equals(ui_element: Control, property_name: String, expected_value, message: String = "") -> void:
	"""Assert UI property equals expected _value"""
	var actual_value = safe_get_ui_property(ui_element, property_name)
	var failure_message = message if not message.is_empty() else "Property '%s' should equal expected _value" % property_name
	assert_that(actual_value).override_failure_message(failure_message).is_equal(expected_value)

func assert_ui_element_exists(parent: Node, node_path: String, message: String = "") -> void:
	"""Assert UI element exists"""
	var element = safe_get_ui_node(parent, node_path)
	var failure_message = message if not message.is_empty() else "UI element '%s' should exist" % node_path
	assert_that(element).override_failure_message(failure_message).is_not_null()

# Note: UI cleanup is handled by parent class @warning_ignore("return_value_discarded")
	auto_free() mechanism
# Additional UI-specific cleanup can be added to individual tests if needed 
