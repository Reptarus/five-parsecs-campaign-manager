@tool
extends "res://tests/fixtures/base/game_test.gd"

# Base class for UI testing
# Use direct inheritance from game_test.gd to avoid circular dependencies

# Constants
const UI_STABILIZE_TIME: float = 0.2
const THEME_OVERRIDE_TIMEOUT: float = 0.1
const MIN_TOUCH_TARGET_SIZE: float = 44.0

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
	_setup_test_environment()

func after_each() -> void:
	_restore_test_environment()
	await super.after_each()

func _setup_test_environment() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_viewport().gui_embed_subwindows = false
	await get_tree().process_frame

func _restore_test_environment() -> void:
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
	await stabilize_engine(UI_STABILIZE_TIME)

func simulate_click(control: Control, position: Vector2 = Vector2.ZERO) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = position
	await simulate_ui_input(control, click)
	
	click.pressed = false
	await simulate_ui_input(control, click)

# Responsive Testing
func test_responsive_layout(control: Control) -> void:
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
				assert_true(child.size.x >= MIN_TOUCH_TARGET_SIZE and child.size.y >= MIN_TOUCH_TARGET_SIZE,
					"Touch target size should be at least %sx%s pixels" % [MIN_TOUCH_TARGET_SIZE, MIN_TOUCH_TARGET_SIZE])

# Performance Testing
func start_performance_monitoring() -> void:
	_performance_metrics = {
		"layout_updates": 0,
		"draw_calls": 0,
		"theme_lookups": 0
	}

func stop_performance_monitoring() -> Dictionary:
	return _performance_metrics

func assert_performance_metrics(metrics: Dictionary, thresholds: Dictionary) -> void:
	for key in thresholds:
		assert_true(metrics[key] <= thresholds[key],
			"Performance metric %s exceeded threshold: %s > %s" % [key, metrics[key], thresholds[key]])

# Accessibility Testing
func test_accessibility(control: Control) -> void:
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
func test_animations(control: Control) -> void:
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