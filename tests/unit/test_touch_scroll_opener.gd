extends GdUnitTestSuite
## T9-45 (tablet, Aug 13 2026) — two more screens could only be scrolled by
## grabbing the thin scrollbar at the screen edge. Same class as T4-01.
##
## Measured on a Lenovo TB361FU: swipes at x=2280 and x=2080 changed nothing;
## a drag on the scrollbar at x=2538 scrolled normally.
##
##   - Record Battle Result drawer — wall-to-wall CheckBox / SpinBox /
##     OptionButton, with "Submit Battle Results" below the fold.
##   - World Phase page — drags over the Travel/Upkeep panels did nothing.
##
## WHY THE EXISTING FIX DID NOT COVER THEM. `WorldPhaseController._open_subtree`
## already swept STOP -> PASS, but guarded on `focus_mode == FOCUS_NONE` to avoid
## competing with widgets that scroll themselves. CheckBox, SpinBox and
## OptionButton are ALL focusable, so the sweep walked straight past the exact
## controls under the player's finger.
##
## Relaxing them is safe: PASS still delivers the event to the control FIRST, so
## a widget that genuinely handles a drag keeps handling it and only unhandled
## events propagate. Verified against the Godot 4.6 docs that no other lever
## exists — `scroll_deadzone` (already 16 project-wide) only governs a drag the
## container RECEIVES, and `mouse_force_pass_scroll_events` is scroll-wheel only.
##
## gdUnit4 v6.0.3. NOTE: run with -c, never --headless (project rule).

const TouchScrollOpener = preload(
	"res://src/ui/components/common/TouchScrollOpener.gd")


func _tree_with(children: Array) -> Control:
	var root := Control.new()
	add_child(auto_free(root))
	for c in children:
		root.add_child(c)
	return root


# ── the three widgets that actually broke on device ──────────────────────────

## THE DEFECT. Each of these defaults to MOUSE_FILTER_STOP and is FOCUSABLE, so
## the old focus_mode guard skipped every one.
func test_the_focusable_widgets_that_broke_the_drawer_are_opened() -> void:
	var check := CheckBox.new()
	var spin := SpinBox.new()
	var option := OptionButton.new()
	var button := Button.new()
	var root := _tree_with([check, spin, option, button])

	# Precondition: if Godot ever stops defaulting these to STOP, this test is
	# asserting nothing and should be revisited rather than silently passing.
	assert_int(check.mouse_filter).override_failure_message(
		"CheckBox no longer defaults to STOP — re-derive this test").is_equal(
		Control.MOUSE_FILTER_STOP)
	assert_bool(check.focus_mode == Control.FOCUS_NONE).override_failure_message(
		"CheckBox is expected to be FOCUSABLE — that is precisely why the old "
		+ "focus_mode == FOCUS_NONE sweep skipped it").is_false()

	TouchScrollOpener.open_subtree(root)

	for c: Control in [check, spin, option, button]:
		assert_int(c.mouse_filter).override_failure_message(
			"%s still STOPs, so a touch-drag starting on it dies there and the "
			% c.get_class()
			+ "owning ScrollContainer never sees the gesture").is_equal(
			Control.MOUSE_FILTER_PASS)


## The chrome from T4-01, still covered.
func test_decorative_chrome_is_still_opened() -> void:
	var panel := PanelContainer.new()
	var sep := HSeparator.new()
	var root := _tree_with([panel, sep])
	TouchScrollOpener.open_subtree(root)
	assert_int(panel.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	assert_int(sep.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)


# ── what must KEEP claiming its own gesture ──────────────────────────────────

## A drag inside a list should scroll THAT list, not the page behind it. These
## own an inner scroll, so they are skipped outright rather than merely given
## first refusal.
func test_containers_that_scroll_themselves_are_left_alone() -> void:
	var inner_scroll := ScrollContainer.new()
	var tree := Tree.new()
	var list := ItemList.new()
	var text := TextEdit.new()
	var root := _tree_with([inner_scroll, tree, list, text])
	for c: Control in [inner_scroll, tree, list, text]:
		c.mouse_filter = Control.MOUSE_FILTER_STOP

	TouchScrollOpener.open_subtree(root)

	for c: Control in [inner_scroll, tree, list, text]:
		assert_int(c.mouse_filter).override_failure_message(
			"%s scrolls or selects on its own drag and must keep STOPping"
			% c.get_class()).is_equal(Control.MOUSE_FILTER_STOP)


# ── behaviour of the sweep itself ────────────────────────────────────────────

## Nested chrome is the normal case — the World Phase chain measured on the
## tablet was HSeparator inside PanelContainer inside VBox, four levels down.
func test_the_sweep_reaches_nested_children() -> void:
	var outer := PanelContainer.new()
	var mid := VBoxContainer.new()
	var deep := CheckBox.new()
	outer.add_child(mid)
	mid.add_child(deep)
	var root := _tree_with([outer])

	TouchScrollOpener.open_subtree(root)
	assert_int(deep.mouse_filter).override_failure_message(
		"the finger lands on the DEEPEST control, so a one-level sweep fixes "
		+ "nothing").is_equal(Control.MOUSE_FILTER_PASS)


## IGNORE must survive: PhaseScroll is deliberately set to IGNORE by its caller
## so it cannot CLAIM a drag it no longer acts on, and the sweep must not
## "upgrade" that to PASS.
func test_ignore_is_not_touched() -> void:
	var ignored := PanelContainer.new()
	ignored.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var root := _tree_with([ignored])
	TouchScrollOpener.open_subtree(root)
	assert_int(ignored.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


## Panels get rebuilt on every step change, so the sweep runs repeatedly.
func test_the_sweep_is_idempotent_and_reports_what_it_did() -> void:
	var check := CheckBox.new()
	var root := _tree_with([check])
	assert_int(TouchScrollOpener.open_subtree(root)).is_equal(1)
	assert_int(TouchScrollOpener.open_subtree(root)).override_failure_message(
		"a second pass should find nothing left to open").is_equal(0)


## The count is the difference between "nothing needed opening" and "the sweep
## never ran" — the failure mode that made the first World Phase fix look
## applied when it had walked an empty tree.
func test_a_sweep_over_nothing_reports_zero_rather_than_erroring() -> void:
	assert_int(TouchScrollOpener.open_subtree(null)).is_equal(0)
	assert_int(TouchScrollOpener.open_subtree(_tree_with([]))).is_equal(0)
