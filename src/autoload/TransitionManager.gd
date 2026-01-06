extends CanvasLayer
class_name TransitionManagerClass

## TransitionManager - Smooth scene transitions with fade effects
## Sprint B1: Provides polished scene change animations for modern UX
##
## Usage:
##   TransitionManager.fade_to_scene("res://path/to/scene.tscn")
##   TransitionManager.fade_to_scene_name("main_menu")  # Uses SceneRouter paths
##   await TransitionManager.fade_out()
##   # do manual scene work
##   await TransitionManager.fade_in()

signal transition_started
signal transition_mid_point  # Emits when fade-out complete, before scene change
signal transition_completed
signal transition_cancelled

## Configuration
const DEFAULT_DURATION := 0.2  # 200ms default fade (fast, polished)
const SLOW_DURATION := 0.4     # 400ms for dramatic transitions
const FAST_DURATION := 0.1     # 100ms for quick cuts

## State
var _is_transitioning: bool = false
var _overlay: ColorRect
var _tween: Tween

## Colors for different transition types
const COLOR_FADE_BLACK := Color(0, 0, 0, 1)
const COLOR_FADE_WHITE := Color(1, 1, 1, 1)
const COLOR_FADE_DARK_BLUE := Color(0.1, 0.1, 0.18, 1)  # Matches Deep Space theme

func _ready() -> void:
	# Set layer to be above all other UI
	layer = 100

	# Create the fade overlay
	_setup_overlay()

	print("TransitionManager: Initialized with %0.1fs default transition" % DEFAULT_DURATION)

func _setup_overlay() -> void:
	"""Create the ColorRect overlay for fade effects"""
	_overlay = ColorRect.new()
	_overlay.name = "TransitionOverlay"
	_overlay.color = Color(0, 0, 0, 0)  # Start fully transparent
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input when transparent

	# Make it cover the full screen
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.size = Vector2(4096, 4096)  # Large enough for any resolution
	_overlay.position = Vector2(-2048, -2048)  # Center it

	add_child(_overlay)

## Main transition method - fade to scene by file path
func fade_to_scene(scene_path: String, duration: float = DEFAULT_DURATION, fade_color: Color = COLOR_FADE_BLACK) -> void:
	"""Fade out, change scene, fade in"""
	if _is_transitioning:
		push_warning("TransitionManager: Already transitioning, ignoring request")
		return

	if not FileAccess.file_exists(scene_path):
		push_error("TransitionManager: Scene file not found: " + scene_path)
		return

	_is_transitioning = true
	transition_started.emit()

	# Fade out
	await _fade_out(duration, fade_color)
	transition_mid_point.emit()

	# Change scene
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("TransitionManager: Failed to change scene: " + scene_path)
		_is_transitioning = false
		transition_cancelled.emit()
		# Still fade in to recover gracefully
		await _fade_in(duration)
		return

	# Wait a frame for scene to initialize
	await get_tree().process_frame

	# Fade in
	await _fade_in(duration)

	_is_transitioning = false
	transition_completed.emit()

## Transition using SceneRouter scene names
func fade_to_scene_name(scene_name: String, duration: float = DEFAULT_DURATION, fade_color: Color = COLOR_FADE_BLACK) -> void:
	"""Fade to a scene using SceneRouter's scene name registry"""
	if not SceneRouter:
		push_error("TransitionManager: SceneRouter not available")
		return

	var scene_path = SceneRouter.get_scene_path(scene_name)
	if scene_path.is_empty():
		push_error("TransitionManager: Unknown scene name: " + scene_name)
		return

	await fade_to_scene(scene_path, duration, fade_color)

	# Update SceneRouter's current scene tracking
	if SceneRouter:
		SceneRouter.current_scene = scene_name

## Fade out only (for manual scene management)
func fade_out(duration: float = DEFAULT_DURATION, fade_color: Color = COLOR_FADE_BLACK) -> void:
	"""Fade to black (or specified color). Use for manual scene transitions."""
	if _is_transitioning:
		push_warning("TransitionManager: Already transitioning")
		return

	_is_transitioning = true
	transition_started.emit()
	await _fade_out(duration, fade_color)
	transition_mid_point.emit()

## Fade in only (for manual scene management)
func fade_in(duration: float = DEFAULT_DURATION) -> void:
	"""Fade back in from overlay. Call after manual scene change."""
	await _fade_in(duration)
	_is_transitioning = false
	transition_completed.emit()

## Quick flash effect (useful for impacts, errors)
func flash(flash_color: Color = COLOR_FADE_WHITE, duration: float = 0.1) -> void:
	"""Quick flash effect - useful for battle hits, errors, etc."""
	if _is_transitioning:
		return

	_is_transitioning = true
	_overlay.color = flash_color
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	await get_tree().create_timer(duration * 0.3).timeout

	await _fade_in(duration * 0.7)
	_is_transitioning = false

## Cancel current transition (emergency use only)
func cancel_transition() -> void:
	"""Cancel current transition - use only for emergencies"""
	if _tween and _tween.is_valid():
		_tween.kill()

	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	transition_cancelled.emit()

## Check if currently transitioning
func is_transitioning() -> bool:
	return _is_transitioning

## Private implementation

func _fade_out(duration: float, fade_color: Color) -> void:
	"""Internal fade out implementation"""
	# Kill any existing tween
	if _tween and _tween.is_valid():
		_tween.kill()

	# Block input during transition
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# Set target color (fully opaque)
	var target_color = fade_color
	target_color.a = 1.0

	# Start from transparent
	_overlay.color = Color(fade_color.r, fade_color.g, fade_color.b, 0.0)

	# Animate to opaque
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN)
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_overlay, "color", target_color, duration)

	await _tween.finished

func _fade_in(duration: float) -> void:
	"""Internal fade in implementation"""
	# Kill any existing tween
	if _tween and _tween.is_valid():
		_tween.kill()

	# Store current color for fade from
	var start_color = _overlay.color
	var end_color = Color(start_color.r, start_color.g, start_color.b, 0.0)

	# Animate to transparent
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_overlay, "color", end_color, duration)

	await _tween.finished

	# Allow input again
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Convenience methods for common transitions

func fade_to_main_menu(duration: float = DEFAULT_DURATION) -> void:
	"""Convenience: Fade to main menu"""
	await fade_to_scene_name("main_menu", duration, COLOR_FADE_DARK_BLUE)

func fade_to_campaign_dashboard(duration: float = DEFAULT_DURATION) -> void:
	"""Convenience: Fade to campaign dashboard"""
	await fade_to_scene_name("campaign_dashboard", duration, COLOR_FADE_BLACK)

func fade_to_battle(duration: float = SLOW_DURATION) -> void:
	"""Convenience: Dramatic fade to battle (slower)"""
	await fade_to_scene_name("tactical_battle", duration, COLOR_FADE_BLACK)

func fade_to_post_battle(duration: float = SLOW_DURATION) -> void:
	"""Convenience: Fade to post-battle sequence"""
	await fade_to_scene_name("post_battle_sequence", duration, COLOR_FADE_BLACK)

## Debug methods

func _test_transitions() -> void:
	"""Test method for verifying transitions work"""
	print("TransitionManager: Testing fade out...")
	await fade_out(0.5)
	print("TransitionManager: Fade out complete")
	await get_tree().create_timer(1.0).timeout
	print("TransitionManager: Testing fade in...")
	await fade_in(0.5)
	print("TransitionManager: Test complete")
