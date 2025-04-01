@tool
extends "res://tests/fixtures/base/game_test.gd"

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

func before_each() -> void:
	await super.before_each()
	_viewport_size = get_viewport().size
	_setup_ui_environment()

func after_each() -> void:
	_restore_ui_environment()
	await super.after_each()

func _setup_ui_environment() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_viewport().gui_embed_subwindows = false
	await get_tree().process_frame

func _restore_ui_environment() -> void:
	get_tree().root.size = _viewport_size
	await get_tree().process_frame

# UI Visibility Testing
func assert_control_visible(control: Control, message: String = "") -> void:
	assert_true(control.visible and control.get_combined_minimum_size() != Vector2.ZERO,
		message if message else "Control should be visible and have size")

func assert_control_hidden(control: Control, message: String = "") -> void:
	assert_true(not control.visible or control.modulate.a == 0.0,
		message if message else "Control should be hidden")

# Theme Testing
func assert_theme_override(control: Control, property: String, value: Variant) -> void:
	assert_true(control.has_theme_override(property),
		"Control should have theme override for %s" % property)
	assert_eq(control.get_theme_override(property), value,
		"Theme override value should match expected")

# Input Testing
func simulate_ui_input(control: Control, event: InputEvent) -> void:
	control.gui_input.emit(event)
	await stabilize_engine(UI_TEST_CONFIG.stabilize_time)

func simulate_click(control: Control, position: Vector2 = Vector2.ZERO) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = position
	await simulate_ui_input(control, click)
	
	click.pressed = false
	await simulate_ui_input(control, click)

# Responsive Testing
func test_responsive_layout(control: Control = null) -> void:
	if control == null:
		push_warning("No control provided for test_responsive_layout")
		return
		
	for size_name in SCREEN_SIZES:
		var size: Vector2i = SCREEN_SIZES[size_name]
		get_tree().root.size = size
		await get_tree().process_frame
		
		# Verify layout constraints
		assert_true(control.size.x <= size.x,
			"Control width should fit screen size %s" % size_name)
		assert_true(control.size.y <= size.y,
			"Control height should fit screen size %s" % size_name)
		
		# Verify touch targets
		for child in control.find_children("*", "Control"):
			if child.focus_mode != Control.FOCUS_NONE:
				assert_true(child.size.x >= UI_TEST_CONFIG.min_touch_target_size and child.size.y >= UI_TEST_CONFIG.min_touch_target_size,
					"Touch target size should be at least %sx%s pixels" % [UI_TEST_CONFIG.min_touch_target_size, UI_TEST_CONFIG.min_touch_target_size])

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
		assert_true(metrics[key] <= thresholds[key],
			"Performance metric %s exceeded threshold: %s > %s" % [key, metrics[key], thresholds[key]])

# Accessibility Testing
func test_accessibility(control: Control = null) -> void:
	if control == null:
		push_warning("No control provided for test_accessibility")
		return
		
	# Test focus navigation
	var focusable := control.find_children("*", "Control", true, false)
	focusable = focusable.filter(func(c): return c.focus_mode != Control.FOCUS_NONE)
	
	for i in range(focusable.size()):
		var current := focusable[i] as Control
		current.grab_focus()
		assert_true(current.has_focus(),
			"Control %s should be able to receive focus" % current.name)
		
		var next := current.find_next_valid_focus()
		if i < focusable.size() - 1:
			assert_not_null(next,
				"Control %s should have valid next focus target" % current.name)

# Animation Testing
func test_animations(control: Control = null) -> void:
	if control == null:
		push_warning("No control provided for test_animations")
		return
		
	var animation_player := control.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if not animation_player:
		return
	
	for anim_name in animation_player.get_animation_list():
		animation_player.play(anim_name)
		await animation_player.animation_finished
		
		assert_eq(animation_player.current_animation, "",
			"Animation %s should complete" % anim_name)

# Utility Functions
func find_child_by_type(parent: Node, type: String) -> Node:
	for child in parent.get_children():
		if child.get_class() == type:
			return child
	return null

func find_children_by_type(parent: Node, type: String) -> Array[Node]:
	var result: Array[Node] = []
	for child in parent.get_children():
		if child.get_class() == type:
			result.append(child)
	return result

func wait_for_animation(animation_player: AnimationPlayer, animation_name: String) -> void:
	animation_player.play(animation_name)
	await animation_player.animation_finished