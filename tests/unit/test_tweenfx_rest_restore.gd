extends GdUnitTestSuite
## A TweenFX animation re-triggered mid-flight must not leave its node displaced.
##
## FOUND ON RENDERS, 2026-10-28 (Sprint U, Planetfall creation wizard): the
## "Step N of 6" label grew on every step. Every TweenFX animation begins with
## `TweenManager.stop(node, anim)` and then reads the node's CURRENT scale as its
## "original". stop() killed the running tween wherever it was, so a punch
## re-triggered at its peak captured the peak (x1.15) as the rest scale and
## settled there; the next step did it again. The wizard re-triggered it on every
## step, because `_on_step_changed()` and `_show_panel()` (after a 0.15 s fade
## await, inside the 0.3 s punch) each called `_update_step_label()`.
##
## The fix is at the chokepoint: an animation hands TweenManager the rest values it
## moves away from, and stop()/stop_all() put them back. Tween.custom_step() drives
## each tween to an exact point, so no case here depends on wall-clock timing.

const TweenManagerScript = preload("res://addons/TweenFX/TweenManager.gd")


func _node() -> Control:
	var n: Control = auto_free(Control.new())
	n.size = Vector2(100, 40)
	add_child(n)
	return n


func test_punch_retriggered_at_its_peak_settles_at_rest() -> void:
	var n := _node()
	var first: Tween = TweenFX.punch_in(n, 0.15, 0.15)
	first.custom_step(0.15)
	# Premise: the first punch really is at its peak when it is interrupted.
	assert_float(n.scale.x).is_greater(1.1)
	var second: Tween = TweenFX.punch_in(n, 0.15, 0.15)
	assert_vector(n.scale).is_equal(Vector2.ONE)
	second.custom_step(1.0)
	assert_vector(n.scale).is_equal(Vector2.ONE)


func test_repeated_interrupted_punches_do_not_compound() -> void:
	var n := _node()
	var t: Tween = null
	for _i in range(6):
		t = TweenFX.punch_in(n, 0.15, 0.15)
		t.custom_step(0.15)
	t.custom_step(1.0)
	assert_vector(n.scale).is_equal(Vector2.ONE)


func test_interrupted_press_settles_at_rest() -> void:
	var n := _node()
	var first: Tween = TweenFX.press(n, 0.2)
	first.custom_step(0.12)
	assert_bool(n.scale.is_equal_approx(Vector2.ONE)).is_false()
	var second: Tween = TweenFX.press(n, 0.2)
	second.custom_step(1.0)
	assert_vector(n.scale).is_equal(Vector2.ONE)


func test_interrupted_pop_in_restores_scale_and_alpha() -> void:
	var n := _node()
	var first: Tween = TweenFX.pop_in(n, 0.3)
	first.custom_step(0.1)
	assert_float(n.modulate.a).is_less(1.0)
	var second: Tween = TweenFX.pop_in(n, 0.3)
	second.custom_step(2.0)
	assert_vector(n.scale).is_equal(Vector2.ONE)
	assert_float(n.modulate.a).is_equal(1.0)


func test_stop_all_mid_breathe_returns_to_rest() -> void:
	var n := _node()
	var t: Tween = TweenFX.breathe(n, 3.0, 0.1)
	t.custom_step(1.5)
	assert_float(n.scale.x).is_greater(1.05)
	TweenFX.stop_all(n)
	assert_vector(n.scale).is_equal(Vector2.ONE)


## A finished animation must leave no rest record behind, or a later stop() would
## snap back a scale the caller set on purpose.
func test_a_finished_animation_leaves_no_rest_record() -> void:
	var n := _node()
	var t: Tween = TweenFX.punch_in(n, 0.15, 0.15)
	t.custom_step(1.0)
	n.scale = Vector2(2, 2)
	TweenFX.stop(n, TweenFX.Animations.PUNCH_IN)
	assert_vector(n.scale).is_equal(Vector2(2, 2))
	assert_bool(TweenManagerScript._rest.has(n)).is_false()


## The wizard itself: a player tapping Next through every step, faster than the
## punch lasts, must end on a label at its rest scale, anchored on the left.
func test_planetfall_wizard_step_label_ends_at_rest() -> void:
	var ps: PackedScene = load("res://src/ui/screens/planetfall/PlanetfallCreationUI.tscn")
	var ui: Node = auto_free(ps.instantiate())
	add_child(ui)
	await get_tree().process_frame
	for step in range(1, 6):
		ui.coordinator.go_to_step(step)
		await get_tree().process_frame
	await await_millis(900)
	var label: Label = ui._step_label
	assert_str(label.text).starts_with("Step 6 of 6")
	assert_vector(label.scale).is_equal(Vector2.ONE)
	assert_float(label.pivot_offset.x).is_equal(0.0)
