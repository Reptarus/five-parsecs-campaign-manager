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
var _test_control: Control = null
var _viewport_size: Vector2i = Vector2i.ZERO
var _performance_metrics: Dictionary = {}

func before_each() -> void:
	await super.before_each()
	_viewport_size = get_viewport().size if get_viewport() else Vector2i.ZERO
	_setup_test_environment()

func after_each() -> void:
	_restore_test_environment()
	await super.after_each()

func _setup_test_environment() -> void:
	if not DisplayServer:
		push_warning("DisplayServer is not available")
		return
		
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	var tree = get_tree()
	if not tree or not tree.root:
		push_warning("Scene tree or root node is not available")
		return
		
	tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	tree.root.gui_embed_subwindows = false
	await get_tree().process_frame

func _restore_test_environment() -> void:
	var tree = get_tree()
	if not tree or not tree.root:
		push_warning("Scene tree or root node is not available")
		return
		
	tree.root.size = _viewport_size
	await get_tree().process_frame

# UI Visibility Testing
func assert_control_visible(control: Control, message: String = "") -> void:
	if not is_instance_valid(control):
		assert_fail("Cannot check visibility of invalid control")
		return
		
	assert_true(control.visible and control.get_combined_minimum_size() != Vector2.ZERO,
		message if message else "Control should be visible and have size")

func assert_control_hidden(control: Control, message: String = "") -> void:
	if not is_instance_valid(control):
		assert_fail("Cannot check visibility of invalid control")
		return
		
	assert_true(not control.visible or control.modulate.a == 0.0,
		message if message else "Control should be hidden")

# Theme Testing
func assert_theme_override(control: Control, property: String, value: Variant) -> void:
	if not is_instance_valid(control):
		assert_fail("Cannot check theme override of invalid control")
		return
		
	if property.is_empty():
		assert_fail("Property name cannot be empty")
		return
		
	assert_true(control.has_theme_override(property),
		"Control should have theme override for %s" % property)
	assert_eq(control.get_theme_override(property), value,
		"Theme override value should match expected")

# Input Testing
func simulate_ui_input(control: Control, event: InputEvent) -> void:
	if not is_instance_valid(control):
		assert_fail("Cannot simulate input on invalid control")
		return
		
	if not event:
		assert_fail("Cannot simulate with null event")
		return
		
	control.gui_input.emit(event)
	await stabilize_engine(UI_STABILIZE_TIME)

func simulate_click(control: Control, position: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(control):
		assert_fail("Cannot simulate click on invalid control")
		return
		
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = position
	await simulate_ui_input(control, click)
	
	click.pressed = false
	await simulate_ui_input(control, click)

# Responsive Testing
func test_responsive_layout(control: Control = null) -> void:
	if not is_instance_valid(control):
		assert_fail("No valid control provided for responsive layout testing")
		return
		
	# Store original viewport size
	var viewport = get_viewport()
	if not viewport:
		assert_fail("Viewport is null, cannot test responsive layout")
		return
		
	var original_size = viewport.size
	
	# Test different screen sizes
	var test_sizes = [
		Vector2i(640, 480), # Small
		Vector2i(1280, 720), # Medium
		Vector2i(1920, 1080) # Large
	]
	
	for size in test_sizes:
		viewport.size = size
		await get_tree().process_frame
		await get_tree().process_frame
		
		# Verify control fits in viewport
		assert_true(control.size.x <= size.x,
			"Control width should fit current viewport width (%s <= %s)" % [control.size.x, size.x])
		assert_true(control.size.y <= size.y,
			"Control height should fit current viewport height (%s <= %s)" % [control.size.y, size.y])
	
	# Restore original size
	viewport.size = original_size
	await get_tree().process_frame

# Performance Testing
func start_performance_monitoring() -> void:
	_performance_metrics = {
		"layout_updates": 0,
		"draw_calls": 0,
		"theme_lookups": 0
	}

func stop_performance_monitoring() -> Dictionary:
	return _performance_metrics.duplicate()

func assert_performance_metrics(metrics: Dictionary, thresholds: Dictionary) -> void:
	if not metrics or metrics.is_empty():
		assert_fail("Performance metrics dictionary is empty")
		return
		
	if not thresholds or thresholds.is_empty():
		assert_fail("Performance thresholds dictionary is empty")
		return
		
	for key in thresholds:
		if not metrics.has(key):
			assert_fail("Performance metric '%s' not found in metrics" % key)
			continue
			
		assert_true(metrics[key] <= thresholds[key],
			"Performance metric %s exceeded threshold: %s > %s" % [key, metrics[key], thresholds[key]])

# Accessibility Testing
func test_accessibility(control: Control = null) -> void:
	# Create a default control if none is provided
	var test_control = control
	if not is_instance_valid(test_control):
		test_control = Control.new()
		test_control.name = "DefaultAccessibilityTestControl"
		add_child_autofree(test_control)
		
		# Add a simple button for focus testing
		var button = Button.new()
		button.name = "DefaultTestButton"
		button.text = "Default Button"
		button.focus_mode = Control.FOCUS_ALL
		test_control.add_child(button)
		
		track_test_node(test_control)
	
	if not is_instance_valid(test_control):
		push_warning("Cannot test accessibility of invalid control")
		return
		
	# Test focus navigation
	var focusable := test_control.find_children("*", "Control", true, false)
	if focusable.is_empty():
		# No focusable controls found, this may be intentional
		push_warning("No focusable controls found in %s" % test_control.name)
		return
		
	# Filter to only include controls with focus mode
	focusable = focusable.filter(func(c):
		return c is Control and c.focus_mode != Control.FOCUS_NONE
	)
	
	if focusable.is_empty():
		push_warning("No controls with non-NONE focus mode found in %s" % test_control.name)
		return
	
	for i in range(focusable.size()):
		var current := focusable[i] as Control
		if not is_instance_valid(current):
			continue
			
		current.grab_focus()
		assert_true(current.has_focus(),
			"Control %s should be able to receive focus" % current.name)
		
		var next := current.find_next_valid_focus()
		if i < focusable.size() - 1:
			assert_not_null(next,
				"Control %s should have valid next focus target" % current.name)

# Animation Testing
func test_animations(control: Control = null) -> void:
	# Create a default control if none is provided
	var test_control = control
	if not is_instance_valid(test_control):
		test_control = Control.new()
		test_control.name = "DefaultAnimationTestControl"
		
		# Add a basic AnimationPlayer
		var animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		test_control.add_child(animation_player)
		
		# Add a simple animation
		var animation = Animation.new()
		animation.length = 0.5
		
		# Use the proper animation library API for Godot 4
		if not animation_player.has_animation_library(""):
			animation_player.add_animation_library("", AnimationLibrary.new())
		animation_player.get_animation_library("").add_animation("test_animation", animation)
		
		add_child_autofree(test_control)
		track_test_node(test_control)
	
	if not is_instance_valid(test_control):
		push_warning("Cannot test animations of invalid control")
		return
		
	var animation_player := _find_animation_player(test_control)
	if not animation_player:
		push_warning("No AnimationPlayer found in %s" % test_control.name)
		return
	
	var animation_list = _get_animation_list(animation_player)
	if animation_list.is_empty():
		push_warning("No animations found in AnimationPlayer in %s" % test_control.name)
		return
	
	for anim_name in animation_list:
		animation_player.play(anim_name)
		await animation_player.animation_finished
		
		assert_eq(animation_player.current_animation, "",
			"Animation %s should complete" % anim_name)

# Helper function to find an AnimationPlayer in a control hierarchy
func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
		
	var direct_player = node.get_node_or_null("AnimationPlayer")
	if direct_player and direct_player is AnimationPlayer:
		return direct_player
		
	for child in node.get_children():
		var found = _find_animation_player(child)
		if found:
			return found
			
	return null

# Helper function to get all animations from an AnimationPlayer
func _get_animation_list(animation_player: AnimationPlayer) -> Array:
	var animations = []
	
	# Get animations from all libraries
	for lib_name in animation_player.get_animation_library_list():
		var library = animation_player.get_animation_library(lib_name)
		if library:
			for anim_name in library.get_animation_list():
				animations.append(anim_name if lib_name.is_empty() else lib_name + "/" + anim_name)
	
	return animations

# Utility Functions
func find_child_by_type(parent: Node, type: String) -> Node:
	if not is_instance_valid(parent):
		assert_fail("Cannot find child in invalid parent node")
		return null
		
	if type.is_empty():
		assert_fail("Type string cannot be empty")
		return null
		
	for child in parent.get_children():
		if child.get_class() == type:
			return child
	return null

func find_children_by_type(parent: Node, type: String) -> Array[Node]:
	var result: Array[Node] = []
	
	if not is_instance_valid(parent):
		assert_fail("Cannot find children in invalid parent node")
		return result
		
	if type.is_empty():
		assert_fail("Type string cannot be empty")
		return result
		
	for child in parent.get_children():
		if child.get_class() == type:
			result.append(child)
	return result

func wait_for_animation(animation_player: AnimationPlayer, animation_name: String) -> void:
	if not is_instance_valid(animation_player):
		assert_fail("Cannot wait for animation on invalid AnimationPlayer")
		return
		
	if animation_name.is_empty():
		assert_fail("Animation name cannot be empty")
		return
		
	animation_player.play(animation_name)
	await animation_player.animation_finished

# Additional helper methods
func assert_fail(message: String) -> void:
	assert_true(false, message)