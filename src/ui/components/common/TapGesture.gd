extends RefCounted
## Fire an action on a deliberate TAP, never on the press-down of a scroll drag.
##
## THE PROBLEM, measured on a Lenovo TB361FU (T11-28, deploy #19). Five hand-rolled
## row handlers across four files acted on `event.pressed` — the press DOWN — with no
## tap-vs-drag discrimination:
##
##   CompendiumCategoryView.gd  (rich rows, compact rows)
##   CompendiumScreen.gd        (search results)
##   CrewManagementScreen.gd    (crew rows)
##   HubFeatureCard.gd          (52 references across 6 screens)
##
## So the instant a finger touched a row to scroll the list, the row opened its
## detail popup. Relaxing mouse_filter (TouchScrollOpener) fixes the SWALLOWED drag
## and leaves this half live — the two defects are independent and both must be fixed
## or the list is still unusable.
##
## WHY THE MOUSE FAMILY ONLY. `emulate_mouse_from_touch` defaults to true and, per the
## Godot 4.6 docs, makes the engine "send mouse input events when a user taps or
## swipes on a touchscreen" — so a touch ALREADY arrives here as
## InputEventMouseButton. This project additionally sets
## `pointing/emulate_touch_from_mouse=true` (project.godot:109), so listening to BOTH
## families means one physical tap runs the handler TWICE. That is exactly what
## HubFeatureCard.gd:137/:140 did (T11-36), and it is why this helper deliberately
## ignores InputEventScreenTouch rather than handling it "for completeness".
##
## COORDINATES. Verified against the Godot 4.6 InputEventMouse docs: when received in
## Control._gui_input() the position is "the mouse's position within the Control using
## its local coordinate system" — the same transform the `gui_input` SIGNAL delivers.
## So the slop compare and the in-bounds check are both in local space, and neither
## needs a manual transform.

## Per-control state. A static helper has no instance to hold it, and metadata keeps
## the state with the control that owns the gesture, so freeing the row frees it too.
const _META_ARMED := &"__tap_armed"
const _META_POS := &"__tap_press_pos"

## Matches `gui/common/default_scroll_deadzone=16` (project.godot:104), so a movement
## this helper forgives is exactly one the ScrollContainer has not yet acted on.
const DEFAULT_SLOP_PX := 16.0


## Call `on_tap` when `control` receives a press and release at (near) the same point.
##
## `on_tap` takes no arguments — bind whatever the row needs at the call site.
## A movement beyond `slop_px`, or a release outside the control, cancels silently.
static func connect_tap(
	control: Control, on_tap: Callable, slop_px: float = DEFAULT_SLOP_PX
) -> void:
	if control == null or not on_tap.is_valid():
		return
	control.gui_input.connect(
		func(event: InputEvent) -> void:
			_handle(control, on_tap, slop_px, event)
	)


static func _handle(
	control: Control, on_tap: Callable, slop_px: float, event: InputEvent
) -> void:
	if not is_instance_valid(control):
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			control.set_meta(_META_ARMED, true)
			control.set_meta(_META_POS, mb.position)
			return
		# Release. Disarm FIRST so no path can leave a stale arm behind.
		var armed: bool = bool(control.get_meta(_META_ARMED, false))
		control.set_meta(_META_ARMED, false)
		if not armed:
			return
		var start: Vector2 = control.get_meta(_META_POS, mb.position)
		if start.distance_to(mb.position) > slop_px:
			return
		# A release that has left the control is a cancelled press, not a tap —
		# the same affordance Button gives when you slide off it before letting go.
		if not Rect2(Vector2.ZERO, control.size).has_point(mb.position):
			return
		on_tap.call()

	elif event is InputEventMouseMotion:
		if not bool(control.get_meta(_META_ARMED, false)):
			return
		var origin: Vector2 = control.get_meta(_META_POS, Vector2.ZERO)
		if origin.distance_to((event as InputEventMouseMotion).position) > slop_px:
			# This is a scroll, not a tap. Let it go to the ScrollContainer.
			control.set_meta(_META_ARMED, false)
