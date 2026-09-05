extends Node

## Soft-keyboard avoidance — scrolls a focused text field out from under the
## Android/iOS on-screen keyboard.
##
## T3-01, found on the Aug 8 2026 tablet pass: NOTHING in this app yields to the
## soft keyboard. Any input below the screen midline is typed blind. Desktop QA
## structurally cannot see it — desktop has no IME — which is why it survived
## every prior pass.
##
## ## Why a poller and not a signal
##
## Godot 4.6 has NO keyboard show/hide signal or notification. The full API is
## three calls on DisplayServer (`virtual_keyboard_show/hide/get_height`), and
## `virtual_keyboard_get_height()` returns 0 while hidden. Verified against the
## 4.6 class reference, not assumed.
##
## So the trigger has to be `Viewport.gui_focus_changed`, which fires the instant
## a Control takes focus — and at that instant the keyboard is still ANIMATING IN,
## so its height still reads 0. A handler that sampled the height once on focus
## would measure zero every time and do nothing, on every device, silently. Hence:
## arm on focus, then poll until the height STABILISES (two equal non-zero
## readings), apply once, disarm.
##
## ## Why the height needs converting
##
## `virtual_keyboard_get_height()` is in PHYSICAL screen pixels. Control rects are
## in the stretched design space (this project runs canvas_items+expand off a
## square 1080 base, so the two differ on every device and differ by a DIFFERENT
## factor in portrait than in landscape). Comparing them directly would under- or
## over-scroll by the stretch ratio. `to_logical_height()` does the conversion.
##
## ## Scope of v1
##
## Covers the root viewport, which is every screen. Focus inside a separate
## `Window` (a popup dialog) emits on THAT window's viewport, not root, so
## in-dialog fields are not covered yet — no dialog with a text field has been
## reported failing, and speculatively hooking every sub-window is how you get a
## leak. Revisit when a dialog actually reproduces it.
##
## ## Headroom (added after the first device confirmation, Aug 8 2026)
##
## v1 only scrolled, and shipped with a stated gap: "a field on a page too short to
## scroll stays occluded". The Campaign Editor reproduced it on the tablet
## immediately — its fields occupy ~870 of 1600px, so the ScrollContainer had a
## scroll range of ZERO and `scroll_vertical += shift` clamped straight back to 0.
## The keyboard opened (`mInputShown=true`) and the tapped field stayed buried.
##
## Scrolling alone can never fix that: there has to be somewhere to scroll TO. So a
## spacer is appended to the scroll's content while the keyboard is up, which is
## what makes the range exist. It is deliberately minimal — a bare `Control` with no
## script, `MOUSE_FILTER_IGNORE`, always the LAST child, under a reserved name — and
## it is removed the moment the keyboard closes, so nothing iterating that container
## sees it outside a live text-entry moment.

## Breathing room left below the focused field, in logical px, so the field does
## not sit flush against the keyboard's top edge.
const FOCUS_MARGIN := 12.0

## How long to wait for the keyboard to finish animating before giving up. Android
## keyboard animations are ~250ms; 1.5s is slack for a cold IME start without
## leaving _process running if the keyboard never appears (e.g. a hardware keyboard
## is attached, where get_height() legitimately stays 0 forever).
const POLL_TIMEOUT_SEC := 1.5

## Consecutive equal non-zero readings required before the height is trusted.
const STABLE_READINGS_REQUIRED := 2

## Emitted after a successful adjustment. Exists so QA and tests can observe that
## avoidance actually ran, rather than inferring it from a screenshot.
signal avoidance_applied(control: Control, shifted_by: float)

## Reserved name for the headroom spacer. Distinctive so a container walk can
## recognise and skip it, and so a leak is greppable.
const SPACER_NAME := "__keyboard_avoidance_spacer"

var _armed_control: Control = null
var _poll_elapsed: float = 0.0
var _last_height: int = 0
var _stable_readings: int = 0
## The scroll currently holding a spacer, so it can be cleaned up from anywhere.
var _spacer_host: ScrollContainer = null
## The Window currently displaced by _shift_window_up(), and the Y to put it back to.
var _shifted_window: Window = null
var _window_original_y: int = 0
## True while the keyboard is up and we are watching for it to close.
var _holding: bool = false


## The container the ScrollContainer scrolls. ScrollContainer expects one content
## child; the spacer is appended INSIDE that child, never as a second child of the
## scroll itself (which would overlap rather than stack).
static func scroll_content(scroll: ScrollContainer) -> Container:
	if scroll == null:
		return null
	for child in scroll.get_children():
		var c := child as Container
		if c != null and c.name != SPACER_NAME:
			return c
	return null


## Grow the scrollable range by `needed` px so there is somewhere to scroll TO.
##
## Without this the whole feature silently no-ops on any page whose content already
## fits — which is most single-screen forms, and is exactly how the Campaign Editor
## failed its first device test.
func _ensure_headroom(scroll: ScrollContainer, needed: float) -> void:
	var content := scroll_content(scroll)
	if content == null:
		return
	var spacer := content.get_node_or_null(NodePath(SPACER_NAME)) as Control
	if spacer == null:
		spacer = Control.new()
		spacer.name = SPACER_NAME
		# Never intercept a touch: this sits under the keyboard, but a drag that
		# starts on it must still reach the ScrollContainer.
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(spacer)
	spacer.custom_minimum_size = Vector2(0, needed)
	# Always last, so it only ever adds trailing space.
	content.move_child(spacer, content.get_child_count() - 1)
	_spacer_host = scroll


## Move a Window up so the focused field clears the keyboard.
##
## The fallback for a dialog with no ScrollContainer. Only ever applied to a CHILD
## window: shifting the root would move the whole application.
##
## The original Y is captured ONCE, on the first shift, and every later shift is
## computed from that captured value rather than from the current position — moving
## between two fields in the same dialog would otherwise stack shift onto shift and
## walk the dialog off the top of the screen.
func _shift_window_up(control: Control, shift: float) -> void:
	var w := control.get_window()
	if w == null or w == get_tree().root:
		return
	if _shifted_window != w:
		_restore_window()
		_shifted_window = w
		_window_original_y = w.position.y
	w.position.y = maxi(0, _window_original_y - int(ceil(shift)))
	avoidance_applied.emit(control, shift)


## Put a shifted Window back. Called from exactly the same places as
## _clear_headroom(): a dialog left displaced after the keyboard closes is the same
## class of leak as a spacer outliving its keyboard, and more visible.
func _restore_window() -> void:
	if _shifted_window != null and is_instance_valid(_shifted_window):
		_shifted_window.position.y = _window_original_y
	_shifted_window = null


## Remove the spacer. Called when the keyboard closes, and defensively on disarm —
## a spacer outliving its keyboard is dead space at the bottom of a form.
func _clear_headroom() -> void:
	_restore_window()
	if _spacer_host == null or not is_instance_valid(_spacer_host):
		_spacer_host = null
		return
	var content := scroll_content(_spacer_host)
	if content != null:
		var spacer := content.get_node_or_null(NodePath(SPACER_NAME))
		if spacer != null:
			content.remove_child(spacer)
			spacer.queue_free()
	_spacer_host = null


func _ready() -> void:
	set_process(false)
	# No virtual keyboard, no work — and no signal connection at all, so desktop
	# and editor runs pay literally nothing.
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	_hook_viewport(get_tree().root)
	# T11-11: EVERY Window is its own Viewport, so a control focused inside a dialog
	# emits gui_focus_changed on THAT Window and never on the root. Connecting only
	# to the root made this autoload structurally blind to all 15 `extends Window`
	# subclasses in src/ — three of which take text input: BugReportDialog and
	# CustomVictoryDialog (both player-facing) and QAScenarioDialog, which is where
	# it was found. It presented as one debug screen's problem and was systemic.
	#
	# Hooked on node_added so it is ORDER-INDEPENDENT. Registering each dialog by
	# hand is the shape that has already failed twice here: a fix ordered against
	# SOME callers is not a fix, and the caller that gets forgotten is always the
	# one added next.
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	var w := node as Window
	if w != null:
		_hook_viewport(w)


func _hook_viewport(vp: Viewport) -> void:
	if vp == null:
		return
	if not vp.gui_focus_changed.is_connected(_on_gui_focus_changed):
		vp.gui_focus_changed.connect(_on_gui_focus_changed)


## True when focusing `node` will raise the soft keyboard.
##
## LineEdit covers SpinBox too: a SpinBox does not take focus itself, it hands
## focus to its internal LineEdit (`SpinBox.get_line_edit()`), so the signal
## delivers the LineEdit. Static + pure so the classification is testable without
## a device.
static func accepts_text(node: Control) -> bool:
	if node == null:
		return false
	return node is LineEdit or node is TextEdit


## Convert a keyboard height from PHYSICAL screen px to LOGICAL (design-space) px.
##
## Under canvas_items+expand the viewport's visible rect is the design space while
## the window is physical, and their ratio is the live stretch factor — which
## changes with orientation, so it must be recomputed per call, never cached.
## Falls back to the physical value when the window height is unusable, which is
## the conservative direction (over-scroll rather than under-scroll).
static func to_logical_height(physical_height: int, window_height: int, logical_viewport_height: float) -> float:
	if window_height <= 0 or logical_viewport_height <= 0.0:
		return float(physical_height)
	return float(physical_height) * (logical_viewport_height / float(window_height))


## How far content must scroll UP so a field ending at `control_bottom` clears the
## keyboard. All arguments in LOGICAL px. Returns 0.0 when nothing is occluded, so
## a field in the upper half is never touched.
##
## Pure and static: this is the whole decision, and it is the part worth pinning.
static func compute_shift(control_bottom: float, viewport_height: float, keyboard_logical_height: float, margin: float = FOCUS_MARGIN) -> float:
	if keyboard_logical_height <= 0.0:
		return 0.0
	var safe_bottom := viewport_height - keyboard_logical_height
	return maxf(0.0, (control_bottom + margin) - safe_bottom)


## Nearest ancestor ScrollContainer that can actually absorb a vertical shift.
## Skips ones whose vertical axis is DISABLED — handing the shift to a scroll that
## cannot scroll is the same silent no-op this whole fix exists to remove.
static func find_scrollable_ancestor(from: Control) -> ScrollContainer:
	var node: Node = from
	while node != null:
		node = node.get_parent()
		var sc := node as ScrollContainer
		if sc != null and sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			return sc
	return null


func _on_gui_focus_changed(node: Control) -> void:
	if not accepts_text(node):
		_disarm()
		return
	_armed_control = node
	_poll_elapsed = 0.0
	_last_height = 0
	_stable_readings = 0
	# Leave HOLDING when focus moves to a DIFFERENT field: the keyboard is already
	# up, so without this the poller would stay in its watch-for-close branch and
	# never re-shift for the newly focused control — moving between fields on a form
	# would work once and then silently stop. The spacer is kept (it is reused).
	_holding = false
	set_process(true)


func _process(delta: float) -> void:
	if _armed_control == null or not is_instance_valid(_armed_control) or not _armed_control.has_focus():
		_disarm()
		return

	_poll_elapsed += delta
	var height := DisplayServer.virtual_keyboard_get_height()

	# HOLDING: the shift is applied and the spacer is in place. Stay alive only to
	# notice the keyboard closing, so the spacer never outlives it.
	if _holding:
		if height <= 0:
			_clear_headroom()
			_holding = false
			_disarm()
		return

	if height > 0 and height == _last_height:
		_stable_readings += 1
		if _stable_readings >= STABLE_READINGS_REQUIRED:
			_apply_avoidance(_armed_control, height)
			# Do NOT disarm: _process must keep running to see the keyboard close.
			_holding = true
			return
	else:
		_stable_readings = 0
	_last_height = height

	if _poll_elapsed >= POLL_TIMEOUT_SEC:
		_disarm()


func _disarm() -> void:
	_armed_control = null
	_stable_readings = 0
	_last_height = 0
	_holding = false
	_clear_headroom()
	set_process(false)


func _apply_avoidance(control: Control, keyboard_physical_height: int) -> void:
	# The CONTROL's viewport, not this autoload's. They are the same thing only while
	# the field lives in the main scene; for a field inside a Window they are two
	# different viewports with two different visible rects, and measuring the wrong
	# one silently produces a shift computed against the wrong height (T11-11).
	var viewport := control.get_viewport()
	if viewport == null:
		return
	var visible_rect := viewport.get_visible_rect()
	var scroll := find_scrollable_ancestor(control)

	# Get the field into the scroll's own viewport FIRST, so the geometry the shift
	# is computed from is final. Done explicitly rather than by setting
	# `follow_focus = true`, which would be a persistent mutation of a scene node
	# for a transient need.
	if scroll != null:
		scroll.ensure_control_visible(control)

	var keyboard_logical := to_logical_height(
		keyboard_physical_height,
		DisplayServer.window_get_size().y,
		visible_rect.size.y
	)
	var control_bottom := control.global_position.y + control.size.y
	var shift := compute_shift(control_bottom, visible_rect.size.y, keyboard_logical)

	# The height is PHYSICAL (raw device) px — VERIFIED in the engine source, since
	# the class reference says only "in pixels". DisplayServerAndroid::
	# virtual_keyboard_get_height() passes godot_io_java->get_vk_height() straight
	# through with no scaling, and the Java side derives it from
	# WindowInsetsCompat.Type.ime(); Android window insets are always raw device px.
	# So to_logical_height()'s stretch conversion above is correct.
	#
	# This print is NOT for that question — it is for the navigation bar. godot#86663
	# / #41388: on Android 11+ with a permanently visible nav bar, its height used to
	# be ADDED to the keyboard's, making the reported height too LARGE (over-scroll).
	# Fixed at milestone 4.5, so 4.6 has it — but it reportedly never reproduced on
	# every device, so confirm rather than assume on any new test hardware: compare
	# `raw` against the keyboard's measured height in a screencap (~762 of 1600 px on
	# the Lenovo TB361FU). Debug builds only.
	if OS.is_debug_build():
		print("[KeyboardAvoidance] raw=%d window_h=%d logical_vp_h=%.1f -> kb_logical=%.1f | field_bottom=%.1f shift=%.1f" % [
			keyboard_physical_height, DisplayServer.window_get_size().y,
			visible_rect.size.y, keyboard_logical, control_bottom, shift])

	if shift <= 0.0:
		return

	# NO SCROLL TO WORK WITH. Two of the three text-taking dialogs (CustomVictoryDialog,
	# QAScenarioDialog) build a plain VBox with no ScrollContainer anywhere, so the
	# scroll strategy has nothing to move and the old code returned here having done
	# nothing. A Window can be moved directly instead, which needs no scene surgery and
	# no spacer — and unlike scrolling it cannot silently no-op, because a Window's
	# position has no clamp to fight.
	if scroll == null:
		_shift_window_up(control, shift)
		return

	# Make the room BEFORE asking for it. On a page whose content already fits, the
	# scroll range is zero and the assignment below clamps straight back to 0 —
	# which is precisely how this silently did nothing on its first device test.
	_ensure_headroom(scroll, keyboard_logical)
	# The spacer changes the content's minimum size, and container layout is
	# deferred, so the new range is not visible to scroll_vertical this frame.
	await get_tree().process_frame
	if not is_instance_valid(scroll) or not is_instance_valid(control):
		return
	# Bail if focus moved while awaiting. Tapping quickly between two fields starts a
	# second _apply_avoidance before this one resumes, and both would then add their
	# own shift to the same scroll — stacking into an over-scroll that jumps the page
	# past the field the player is actually in. The newest focus always wins.
	if _armed_control != control:
		return

	scroll.scroll_vertical += int(ceil(shift))
	avoidance_applied.emit(control, shift)
