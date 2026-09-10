extends GdUnitTestSuite

## T11-36 — one physical tap must fire a card's action EXACTLY ONCE.
##
## ── WHY THIS SUITE EXISTS ────────────────────────────────────────────────────
## `emulate_mouse_from_touch` defaults to true, and this project ALSO sets
## `pointing/emulate_touch_from_mouse=true` (project.godot:109). So a single physical
## tap on a touchscreen arrives at a Control as BOTH an `InputEventScreenTouch` AND an
## `InputEventMouseButton`. A handler that acts on both families runs twice.
##
## Two controls carried that shape after the T11-36 sweep migrated the other 52
## references to `TapGesture`:
##   • `UnitActivationCard._on_gui_input`  (LIVE — and it TOGGLES, so a double-fire
##     presented as "tapping the card does nothing", the least reportable symptom)
##   • `CharacterCard._gui_input`          (LATENT — only built for `Character`
##     resources; a loaded save yields Dictionaries which already used TapGesture)
##
## ⚠ THE DISCRIMINATING PART IS EMITTING BOTH FAMILIES. A test that pushes only mouse
## events passes against the OLD code too, because the old handler also accepted mouse
## events — it would simply never reveal the second fire. Each case below therefore
## delivers the touch event as well, exactly as a device does, and asserts a COUNT
## rather than "was it emitted". Detection-proven: restore the `InputEventScreenTouch`
## branch in either card and the matching case reports 2.

const CharacterCardScene := preload(
	"res://src/ui/components/character/CharacterCard.tscn")
const UnitActivationCardScene := preload(
	"res://src/ui/components/battle/UnitActivationCard.tscn")
const TapGestureRef := preload("res://src/ui/components/common/TapGesture.gd")


## One physical tap, modelled the way the engine actually delivers it.
func _deliver_one_tap(control: Control) -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2.ZERO

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2.ZERO

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2.ZERO

	# Order matches a real device: the touch lands, then its synthesised mouse pair.
	control.gui_input.emit(touch)
	control.gui_input.emit(press)
	control.gui_input.emit(release)


func test_character_card_emits_card_tapped_exactly_once() -> void:
	var card: PanelContainer = auto_free(CharacterCardScene.instantiate())
	add_child(card)
	await get_tree().process_frame

	var fired: Array[int] = [0]
	card.card_tapped.connect(func() -> void: fired[0] += 1)

	_deliver_one_tap(card)
	await get_tree().process_frame

	assert_int(fired[0]).override_failure_message(
		"CharacterCard emitted card_tapped %d times for ONE tap. 2 means the "
		% fired[0]
		+ "InputEventScreenTouch branch is back (T11-36); 0 means TapGesture is "
		+ "no longer wired in _ready()."
	).is_equal(1)


func test_unit_activation_card_toggles_exactly_once() -> void:
	var card: Control = auto_free(UnitActivationCardScene.instantiate())
	add_child(card)
	card.initialize({
		"id": "u1", "name": "Tester", "is_crew": true,
		"current_health": 4, "max_health": 4, "combat": 1, "toughness": 4,
	})
	await get_tree().process_frame

	var fired: Array[int] = [0]
	card.activation_toggled.connect(func(_id: String) -> void: fired[0] += 1)

	_deliver_one_tap(card)
	await get_tree().process_frame

	assert_int(fired[0]).override_failure_message(
		"UnitActivationCard emitted activation_toggled %d times for ONE tap."
		% fired[0]
	).is_equal(1)

	# ⚠ The COUNT alone would not catch the real-world symptom. `_handle_tap()`
	# toggles, so two fires return the card to where it started — the signal count
	# moves but the STATE does not, which is why the device symptom was "nothing
	# happens" rather than a visible double action. Assert the state landed too.
	assert_bool(card.is_activated).override_failure_message(
		"is_activated is false after one tap — the toggle ran an even number of times."
	).is_true()


func test_a_drag_across_the_card_does_not_activate_it() -> void:
	## T11-28's half of the same fix: press, move beyond the 16 px slop, release.
	## Dragging a unit list to SCROLL it must not activate whatever is under the
	## finger. Fixing the double-fire alone would leave this live.
	var card: Control = auto_free(UnitActivationCardScene.instantiate())
	add_child(card)
	card.initialize({
		"id": "u2", "name": "Dragged", "is_crew": true,
		"current_health": 4, "max_health": 4, "combat": 1, "toughness": 4,
	})
	await get_tree().process_frame

	var fired: Array[int] = [0]
	card.activation_toggled.connect(func(_id: String) -> void: fired[0] += 1)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2.ZERO

	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(0, 60)  # well beyond DEFAULT_SLOP_PX (16)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(0, 60)

	card.gui_input.emit(press)
	card.gui_input.emit(motion)
	card.gui_input.emit(release)
	await get_tree().process_frame

	assert_int(fired[0]).override_failure_message(
		"A 60 px drag activated the card (%d fires) — TapGesture's slop is not "
		% fired[0] + "cancelling the tap."
	).is_equal(0)
	assert_bool(card.is_activated).is_false()


## A SECOND `connect_tap()` on the same Control is silently INERT, not a double-fire.
##
## ⚠ Recorded because the walk of 2026-09-08 wrote the opposite into the QA log — that
## `TapGesture.connect_tap()` "has no guard against being called twice, so a second
## call would silently double every tap". That is WRONG, and the direction matters:
## the danger is a dead handler, not a duplicated one.
##
## The gesture's state lives on the CONTROL (`_META_ARMED` / `_META_POS`, chosen so
## freeing the row frees the state), and the release path disarms BEFORE it fires. So
## with two lambdas connected to the same `gui_input`, the first release consumes the
## arm and the second reads `armed == false` and returns. Measured: 1 and 0.
##
## Keying the state on the control therefore makes double-connection FAIL SAFE for the
## defect this whole suite is about. It is still a trap — a second tap action wired to
## an already-tapped control never runs, with no error — so the fix for a control that
## needs two effects is ONE callback that does both, never two `connect_tap()` calls.
func test_a_second_connect_tap_on_one_control_is_inert_not_doubled() -> void:
	var control := Control.new()
	control.size = Vector2(100, 100)
	add_child(control)
	auto_free(control)

	var first := [0]
	var second := [0]
	TapGestureRef.connect_tap(control, func() -> void: first[0] += 1)
	TapGestureRef.connect_tap(control, func() -> void: second[0] += 1)

	_deliver_one_tap(control)
	await get_tree().process_frame

	assert_int(first[0]).override_failure_message(
		"The first tap callback fired %d times; one tap must fire it exactly once."
		% first[0]
	).is_equal(1)
	assert_int(second[0]).override_failure_message(
		"The second connect_tap() callback fired %d times. It is expected to be INERT "
		% second[0] + "because the shared per-control arm is consumed by the first "
		+ "release — if this is now firing, double-connection has become a real "
		+ "double-fire and every connect_tap() call site needs auditing."
	).is_equal(0)
