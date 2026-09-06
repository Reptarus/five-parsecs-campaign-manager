extends GdUnitTestSuite
## T11-28 / T11-36 — a row must open on a TAP, never on the press-down of a scroll.
##
## Five hand-rolled handlers acted on `event.pressed`, so on the tablet the Compendium
## list opened a detail popup the instant a finger touched a row to scroll it. During
## the device walk this cost two misdiagnoses: a "scrollbar drag" that was ~5px off
## landed on a row and opened "Punks", and the resulting large pixel diff read as a
## successful scroll.
##
## Events are driven by emitting `gui_input` directly. Godot does not deliver real
## InputEvents in headless mode, so synthesising them at the signal is the only way to
## test the discrimination without a display — and it is the same event object and the
## same local coordinate space the engine would hand the handler.

const TapGestureRef = preload("res://src/ui/components/common/TapGesture.gd")

var _fired: int = 0


func _make(size := Vector2(200, 48)) -> Control:
	_fired = 0
	var c: Control = auto_free(Control.new())
	c.size = size
	add_child(c)
	TapGestureRef.connect_tap(c, func() -> void: _fired += 1)
	return c


func _mb(pos: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = pos
	return e


func _motion(pos: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = pos
	return e


func test_a_press_and_release_at_the_same_point_fires_once() -> void:
	var c := _make()
	c.gui_input.emit(_mb(Vector2(40, 20), true))
	c.gui_input.emit(_mb(Vector2(40, 20), false))
	assert_int(_fired).is_equal(1)


## A small wobble is a tap, not a drag — a finger is not a mouse. The tolerance is the
## project's own `gui/common/default_scroll_deadzone=16`, so anything this forgives is
## movement the ScrollContainer has not acted on either.
func test_a_wobble_inside_the_slop_still_counts_as_a_tap() -> void:
	var c := _make()
	c.gui_input.emit(_mb(Vector2(40, 20), true))
	c.gui_input.emit(_motion(Vector2(46, 24)))
	c.gui_input.emit(_mb(Vector2(46, 24), false))
	assert_int(_fired).is_equal(1)


func test_a_drag_past_the_slop_does_not_fire() -> void:
	var c := _make()
	c.gui_input.emit(_mb(Vector2(40, 20), true))
	c.gui_input.emit(_motion(Vector2(40, 60)))   # 40 px — a scroll
	c.gui_input.emit(_mb(Vector2(40, 60), false))
	assert_int(_fired).override_failure_message(
		"A 40 px drag opened the row. This is the device defect: the finger was "
		+ "scrolling the list and the row treated the press-down as a click."
	).is_equal(0)


## THE T11-36 DISCRIMINATOR. HubFeatureCard listened to InputEventMouseButton AND
## InputEventScreenTouch. The project sets emulate_touch_from_mouse=true
## (project.godot:109) and leaves emulate_mouse_from_touch at its default true, so one
## physical tap arrives as BOTH — and ran the handler twice. TapGesture ignores the
## touch family precisely because the mouse family already carries every tap.
func test_a_tap_delivered_as_both_families_fires_exactly_once() -> void:
	var c := _make()
	var down := InputEventScreenTouch.new()
	down.pressed = true
	down.position = Vector2(40, 20)
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.position = Vector2(40, 20)

	c.gui_input.emit(_mb(Vector2(40, 20), true))
	c.gui_input.emit(down)
	c.gui_input.emit(up)
	c.gui_input.emit(_mb(Vector2(40, 20), false))

	assert_int(_fired).override_failure_message(
		"One tap fired the handler %d times. Listening to both the mouse and touch "
		% [_fired] + "families double-fires under this project's emulation settings."
	).is_equal(1)


## Sliding off the row before letting go cancels — the affordance Button already gives.
func test_a_release_outside_the_control_does_not_fire() -> void:
	var c := _make()
	c.gui_input.emit(_mb(Vector2(40, 20), true))
	c.gui_input.emit(_mb(Vector2(40, 400), false))
	assert_int(_fired).is_equal(0)


func test_a_right_click_does_not_fire() -> void:
	var c := _make()
	c.gui_input.emit(_mb(Vector2(40, 20), true, MOUSE_BUTTON_RIGHT))
	c.gui_input.emit(_mb(Vector2(40, 20), false, MOUSE_BUTTON_RIGHT))
	assert_int(_fired).is_equal(0)


## A release with no matching press must not fire — otherwise a drag that STARTED on
## the scrollbar and ended over a row would open that row.
func test_a_release_with_no_press_does_not_fire() -> void:
	var c := _make()
	c.gui_input.emit(_mb(Vector2(40, 20), false))
	assert_int(_fired).is_equal(0)
