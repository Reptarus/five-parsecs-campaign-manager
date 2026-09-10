extends GdUnitTestSuite
## The battlefield map's pan and zoom must be reachable by a FINGER.
##
## THE DEFECT (measured on a Lenovo TB361FU, deploy #29, 2026-09-09). Both maps in
## this codebase armed panning on MOUSE_BUTTON_MIDDLE (HexStarMap also RIGHT) and
## zoom on the WHEEL. Android's `emulate_mouse_from_touch` synthesises LEFT and
## nothing else, so on glass neither gesture could fire:
##
##   - Galaxy Log: three finger drags in three directions left the frame
##     BYTE-IDENTICAL (9b4947d3); the control arm, a tap on a hex, changed it.
##   - Battlefield: a real two-pointer pinch (the system pointer overlay read
##     `P: 2 / 2`) moved the map 0 px. A pinch was being read as a single tap.
##
## Meanwhile `TacticalBattleUI.gd:853` told the player "pinch/scroll to zoom, drag
## to pan". One of those three worked.
##
## ⚠ WHAT THIS SUITE CAN AND CANNOT PROVE. It drives `_gui_input()` directly, so it
## pins the HANDLER: the slop discrimination, the one-way latch, and the
## multiplicative-to-additive zoom conversion. It does NOT prove ROUTING — whether
## Android actually delivers InputEventMagnifyGesture to a Control's `_gui_input`
## once `enable_pan_and_scale_gestures` is on. That is device-only, and a green run
## here is not a substitute for it. Same discipline as the sprint's headless touch
## cases: they pin the STATE a fix leaves behind, not the gesture.
##
## ⚠ The multiplicative conversion has its own case on purpose. `_zoom()` takes an
## ADDITIVE step while InputEventMagnifyGesture.factor is a MULTIPLICATIVE delta, so
## the handler converts through the current level. Passing `factor - 1.0` straight in
## also "works" — it zooms — and would pass every other case here while making the
## pinch crawl at high zoom. `test_pinch_step_scales_with_current_zoom` is the only
## thing standing between that simplification and a silent regression.

const ViewScript = preload("res://src/ui/components/battle/BattlefieldMapView.gd")
const GenScript = preload("res://src/core/battle/BattlefieldGenerator.gd")
const Grid = preload("res://src/core/battle/BattlefieldGrid.gd")

## Must exceed BattlefieldMapView.DRAG_SLOP_PX (16.0, matching
## gui/common/default_scroll_deadzone). 40 px is unambiguously past it.
const PAST_SLOP := 40.0
## Must stay inside it. 6 px is the sort of wobble a real finger makes on a tap.
const INSIDE_SLOP := 6.0

var _view: Control
var _clicks: int = 0


func before_test() -> void:
	# A populated map, built by the REAL generator rather than a hand-made sector
	# array — _handle_click() refuses to emit when `_sector_shapes` is empty, so an
	# unpopulated map would make every tap case pass for the wrong reason.
	var gen = GenScript.new()
	var result: Dictionary = gen.generate_terrain_suggestions(
		"industrial_zone", [], {}, 12345, 2.0)
	var sectors: Array = result.get("sectors", [])
	assert_int(sectors.size()).override_failure_message(
		"generator produced no sectors — the tap cases would pass vacuously"
		).is_greater(0)

	_view = ViewScript.new()
	add_child(_view)
	auto_free(_view)
	_view.size = Vector2(900, 900)
	_view.configure_grid(Grid.dims_for_table(2.0))
	_view.set_show_scatter(true)
	_view.populate_from_sectors(sectors, "industrial_zone", [])

	_clicks = 0
	_view.cell_clicked.connect(func(_label: String, _features: Array) -> void:
		_clicks += 1
	)


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

func _press(at: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = at
	_view._gui_input(e)


func _release(at: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	e.position = at
	_view._gui_input(e)


func _move(to: Vector2, rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = to
	e.relative = rel
	_view._gui_input(e)


func _pinch(factor: float, at: Vector2 = Vector2(450, 450)) -> void:
	var e := InputEventMagnifyGesture.new()
	e.factor = factor
	e.position = at
	_view._gui_input(e)


# ---------------------------------------------------------------------------
# pinch to zoom — the one gesture with no mouse-family equivalent
# ---------------------------------------------------------------------------

func test_pinch_zooms_in() -> void:
	_view.zoom_level = 1.0
	_pinch(1.5)
	assert_float(_view.zoom_level).override_failure_message(
		"a spreading pinch must zoom IN; a pinch used to be read as a single tap"
		).is_greater(1.0)


func test_pinch_zooms_out() -> void:
	_view.zoom_level = 2.0
	_pinch(0.5)
	assert_float(_view.zoom_level).is_less(2.0)


func test_pinch_step_scales_with_current_zoom() -> void:
	# THE CONVERSION CASE. `factor` is multiplicative; `_zoom()` is additive. A
	# handler that passes `factor - 1.0` straight through still zooms — and still
	# passes both cases above — but applies the same ABSOLUTE step at every level,
	# so the pinch crawls when zoomed in. Converting through the current level
	# makes a given finger spread do the same proportional thing everywhere.
	_view.zoom_level = 1.0
	_pinch(1.2)
	var step_at_1x: float = _view.zoom_level - 1.0

	_view.zoom_level = 2.0
	_pinch(1.2)
	var step_at_2x: float = _view.zoom_level - 2.0

	assert_float(step_at_2x).override_failure_message(
		"same pinch factor gave %.4f at 1x and %.4f at 2x — the multiplicative "
		% [step_at_1x, step_at_2x]
		+ "delta is being used as an additive one"
		).is_greater(step_at_1x)


func test_pinch_respects_the_zoom_clamp() -> void:
	# ZOOM_MAX is 3.0. A wild factor must not escape it.
	_view.zoom_level = 2.9
	_pinch(10.0)
	assert_float(_view.zoom_level).is_less_equal(3.0)

	_view.zoom_level = 0.6
	_pinch(0.01)
	assert_float(_view.zoom_level).is_greater_equal(0.5)


# ---------------------------------------------------------------------------
# two-finger pan
# ---------------------------------------------------------------------------

func test_two_finger_pan_moves_the_map() -> void:
	var before: Vector2 = _view.pan_offset
	var e := InputEventPanGesture.new()
	e.delta = Vector2(1.0, 0.0)
	e.position = Vector2(450, 450)
	_view._gui_input(e)
	assert_vector(_view.pan_offset).is_not_equal(before)


# ---------------------------------------------------------------------------
# single-finger drag to pan, vs the sector tap — they share one button
# ---------------------------------------------------------------------------

func test_press_alone_does_not_pan_and_does_not_tap() -> void:
	var before: Vector2 = _view.pan_offset
	_press(Vector2(450, 450))
	assert_vector(_view.pan_offset).is_equal(before)
	assert_int(_clicks).override_failure_message(
		"the popover fired on PRESS — this is the T11-28 shape and it is exactly "
		+ "what made a drag open the sector rules mid-gesture"
		).is_equal(0)


func test_drag_past_slop_pans() -> void:
	var before: Vector2 = _view.pan_offset
	_press(Vector2(450, 450))
	_move(Vector2(450 + PAST_SLOP, 450), Vector2(PAST_SLOP, 0))
	assert_vector(_view.pan_offset).override_failure_message(
		"a single-finger drag did not pan — this is the whole defect: on Android "
		+ "a finger arrives as an emulated LEFT press, never MIDDLE"
		).is_not_equal(before)


func test_drag_past_slop_does_not_fire_the_tap() -> void:
	_press(Vector2(450, 450))
	_move(Vector2(450 + PAST_SLOP, 450), Vector2(PAST_SLOP, 0))
	_release(Vector2(450 + PAST_SLOP, 450))
	assert_int(_clicks).is_equal(0)


func test_tap_fires_on_release() -> void:
	_press(Vector2(450, 450))
	_release(Vector2(450, 450))
	assert_int(_clicks).override_failure_message(
		"a genuine tap stopped opening the sector popover — the drag fix must not "
		+ "cost the interaction it was protecting"
		).is_equal(1)


func test_wobble_inside_slop_still_taps_and_does_not_pan() -> void:
	var before: Vector2 = _view.pan_offset
	_press(Vector2(450, 450))
	_move(Vector2(450 + INSIDE_SLOP, 450), Vector2(INSIDE_SLOP, 0))
	_release(Vector2(450 + INSIDE_SLOP, 450))
	assert_vector(_view.pan_offset).override_failure_message(
		"a %spx wobble panned the map; the deadzone exists so a shaky tap does not"
		% INSIDE_SLOP).is_equal(before)
	assert_int(_clicks).is_equal(1)


func test_slop_latch_is_one_way() -> void:
	# Drag well past the deadzone, then come back and release near the start. The
	# latch must hold: releasing close to the origin after a long drag is a pan
	# ending, not a tap. Without the one-way latch this opens a popover the player
	# never asked for — and it is the easy thing to get wrong, because the naive
	# check is "is the finger still far away?" at release time.
	_press(Vector2(450, 450))
	_move(Vector2(450 + PAST_SLOP * 3, 450), Vector2(PAST_SLOP * 3, 0))
	_move(Vector2(450, 450), Vector2(-PAST_SLOP * 3, 0))
	_release(Vector2(450, 450))
	assert_int(_clicks).override_failure_message(
		"returning inside the slop re-armed the tap — the latch is not one-way"
		).is_equal(0)


func test_a_second_finger_cancels_the_armed_tap() -> void:
	# FOUND ON DEVICE, not here (deploy #30). `emulate_mouse_from_touch` synthesises
	# pointer 0 only, and a second pointer CANCELS that emulated press -- the cancel
	# arriving as a LEFT release still inside the slop, which the latch then passes
	# through as a genuine tap. So a pinch zoomed the map AND opened the sector
	# popover under finger one.
	#
	# ⚠ This case only exists because the hardware found it. Every headless case
	# above passed with the defect live, because the slop latch sees one pointer
	# travel and the cause here is POINTER COUNT. Worth remembering before treating
	# a green unit run as a substitute for glass.
	_press(Vector2(450, 450))
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.pressed = true
	second.position = Vector2(650, 450)
	_view._gui_input(second)
	_release(Vector2(450, 450))
	assert_int(_clicks).override_failure_message(
		"a second finger did not cancel the tap — a pinch will open the sector popover"
		).is_equal(0)


func test_the_veto_branch_cannot_itself_fire_a_tap() -> void:
	# The veto listens to the touch family, which is exactly how T11-36's double-fire
	# happened. Guard the distinction: a touch event ALONE must never produce a tap.
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	touch.position = Vector2(450, 450)
	_view._gui_input(touch)
	touch.pressed = false
	_view._gui_input(touch)
	assert_int(_clicks).override_failure_message(
		"the touch-family veto branch fired a tap — it must only ever cancel one"
		).is_equal(0)


func test_a_second_gesture_starts_clean() -> void:
	# The release path must disarm, or the NEXT press inherits `_tap_moved` and the
	# first tap after any drag is silently swallowed.
	_press(Vector2(450, 450))
	_move(Vector2(450 + PAST_SLOP, 450), Vector2(PAST_SLOP, 0))
	_release(Vector2(450 + PAST_SLOP, 450))
	assert_int(_clicks).is_equal(0)

	_press(Vector2(450, 450))
	_release(Vector2(450, 450))
	assert_int(_clicks).override_failure_message(
		"the tap after a drag was swallowed — release did not disarm the latch"
		).is_equal(1)
