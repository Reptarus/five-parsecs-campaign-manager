extends GdUnitTestSuite
## World Phase step-viewport budget contract (tablet QA sprint, Aug 8 2026)
##
## Pins the fix for the sprint's blocker: on a 1280x800 tablet in LANDSCAPE the World
## Phase rendered "Crew Tasks" as a heading and nothing else. The crew list, the task
## list and "Resolve All Tasks" were all below the fold, so no task could be assigned,
## so Next Step did nothing and the campaign could not leave Turn 1 Step 2.
##
## Nothing was broken in the data — the crew list held all six members the whole time.
## The step area is a ScrollContainer nested inside another ScrollContainer, and a
## ScrollContainer reports ~0 minimum height, so PhaseContainer contributed 2px to the
## column minimum and silently absorbed the entire squeeze: 117px of viewport for
## 1130px of content. Nothing overflowed and nothing was logged.
##
## _apply_vertical_compaction() hands space back by letting the OUTER scroll own the
## gesture, but it only did so below SHORT_VIEWPORT_DESIGN_PX (620). A landscape tablet
## measures 689 design px and sailed past that test while having 240px of real budget.
##
## The contract locked here: the decision is made on the space actually LEFT for the
## step area, and it is measured in relaxed units so it cannot depend on its own
## previous answer.
##
## gdUnit4 v6.0.3 compatible. NOTE: run with -c, never --headless (project rule).

const WorldPhaseScene := preload("res://src/ui/screens/world/WorldPhaseController.tscn")
const CONTROLLER_PATH := "res://src/ui/screens/world/WorldPhaseController.gd"


func _make() -> Control:
	var wp: Control = auto_free(WorldPhaseScene.instantiate())
	add_child(wp)
	return wp


func _source() -> String:
	var f := FileAccess.open(CONTROLLER_PATH, FileAccess.READ)
	assert_that(f).is_not_null()
	return f.get_as_text()


func test_min_phase_viewport_constant_exists_and_is_usable() -> void:
	# A list plus the buttons that act on it. If someone lowers this below ~240 the
	# landscape tablet slips back through, since its measured budget there was 240-284.
	var scr: GDScript = load(CONTROLLER_PATH)
	assert_that(scr).is_not_null()
	var floor_px: float = scr.MIN_PHASE_VIEWPORT_DESIGN_PX
	assert_float(floor_px).is_greater(240.0)


func test_budget_is_measured_in_relaxed_units_not_live_ones() -> void:
	## The whole point of the constants. Compaction edits both separations, the bottom
	## margin and the Title's visibility; if the budget reads those live it answers
	## differently depending on whether it already ran, straddles the threshold, and
	## flip-flops the layout between resizes (measured: 240 relaxed vs 384 tight).
	var src := _source()
	assert_str(src).contains("func _phase_viewport_budget() -> float:")
	assert_str(src).contains("budget -= RELAXED_MARGIN_BOTTOM_PX")
	assert_str(src).contains("RELAXED_SEPARATION_PX")
	# margin_top is the SettingsOverlay band reservation, NOT compaction's, so it is
	# the one value that must still be read live.
	assert_str(src).contains("budget -= float(mc.get_theme_constant(\"margin_top\"))")
	# ...and margin_bottom must NOT be, or the hysteresis comes straight back.
	assert_str(src).not_contains("budget -= float(mc.get_theme_constant(\"margin_bottom\"))")


func test_title_is_normalised_out_of_the_budget_in_both_states() -> void:
	## Compaction hides the Title, which shrinks the Header's minimum. Charging for it
	## while hidden makes every tight reading permanently lower than every relaxed one,
	## so the first evaluation latches the layout for good. Adding it back while VISIBLE
	## normalises both states to the same question.
	var src := _source()
	assert_str(src).contains("if title is Control and (title as Control).visible:")
	assert_str(src).contains("budget += (title as Control).get_combined_minimum_size().y")


func test_compaction_triggers_on_either_small_screen_or_starved_step_area() -> void:
	## Two independent conditions, OR-ed. Dropping the second one restores the bug.
	var src := _source()
	assert_str(src).contains("vp.get_visible_rect().size.y < SHORT_VIEWPORT_DESIGN_PX")
	assert_str(src).contains("or _phase_viewport_budget() < MIN_PHASE_VIEWPORT_DESIGN_PX")


func test_exactly_one_scrollbar_owns_the_gesture() -> void:
	## Nested vertical scrolling is unusable on touch, so exactly ONE container may
	## scroll. This used to hand ownership back and forth (outer when tight, inner when
	## relaxed); it is now ONE model in every layout — outer AUTO, inner DISABLED.
	##
	## The handoff was removed because its relaxed half could not work (Aug 8 2026):
	##   * the chrome INSIDE PhaseScroll is STOP and deeper than it, so the inner scroll
	##     was never offered the drag it supposedly owned; and
	##   * StepNavigation lives in the OUTER scroll, so disabling that one put Next Step
	##     permanently below the fold (measured y=1609 in a 1280 viewport).
	##
	## AUTO, never DISABLED, for the outer one: AUTO already means "inert while the
	## content fits", which is all the relaxed layout ever wanted. DISABLED additionally
	## means "cannot scroll even when it overflows", which is the bug.
	var src := _source()
	assert_str(src).contains(
		"(scroll as ScrollContainer).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO")
	assert_str(src).contains("ScrollContainer.SCROLL_MODE_DISABLED")
	assert_str(src).not_contains(
		"ScrollContainer.SCROLL_MODE_AUTO if tight else ScrollContainer.SCROLL_MODE_DISABLED")
	assert_str(src).not_contains(
		"ScrollContainer.SCROLL_MODE_DISABLED if tight else ScrollContainer.SCROLL_MODE_AUTO")


## PhaseContainer does NOT stay at its scene path: _ensure_content_scroll() reparents
## everything below the Header into ContentScroll/ContentColumn. Resolving it by the
## authored path returns null and silently skips the assertions below, so search for it.
func _find_named(root: Node, want: String) -> Node:
	if str(root.name) == want:
		return root
	for c in root.get_children():
		var hit := _find_named(c, want)
		if hit != null:
			return hit
	return null


func test_budget_is_stable_across_repeated_compaction_passes() -> void:
	## The live guard against hysteresis: run compaction several times at one size and
	## the budget must not move. If it does, the layout can oscillate on resize.
	var wp := _make()
	await await_millis(120)
	wp._apply_vertical_compaction()
	await await_millis(60)
	var first: float = wp._phase_viewport_budget()
	for _i in range(3):
		wp._apply_vertical_compaction()
		await await_millis(40)
		assert_float(wp._phase_viewport_budget()).is_equal_approx(first, 1.0)


func test_step_area_is_not_starved_after_compaction() -> void:
	## The outcome that matters, asserted on live geometry rather than on source text:
	## the two scrolls must be in OPPOSITE modes, so the step is always reachable by
	## exactly one gesture.
	var wp := _make()
	await await_millis(120)
	wp._apply_vertical_compaction()
	await await_millis(60)

	var phase_scroll: Node = _find_named(wp, "PhaseScroll")
	assert_that(phase_scroll).is_not_null()
	var outer: Node = _find_named(wp, "ContentScroll")
	assert_that(outer).is_not_null()

	var inner_scrolls: bool = (phase_scroll as ScrollContainer).vertical_scroll_mode \
		!= ScrollContainer.SCROLL_MODE_DISABLED
	var outer_scrolls: bool = (outer as ScrollContainer).vertical_scroll_mode \
		!= ScrollContainer.SCROLL_MODE_DISABLED
	# Never both — that is the nested-scroll trap the design exists to avoid.
	assert_bool(inner_scrolls and outer_scrolls).is_false()
	# ...and never neither, or tall content has no way to be reached at all.
	assert_bool(inner_scrolls or outer_scrolls).is_true()


func test_gesture_reaches_whichever_scroll_owns_it() -> void:
	## The OTHER half of the handoff, and it is not implied by the scroll modes.
	##
	## Turning the inner scroll off stops it SCROLLING; it does not stop the step area
	## EATING the gesture. PhaseContainer is a PanelContainer, and PanelContainer defaults
	## to MOUSE_FILTER_STOP, which Godot 4.6 marks handled and does not propagate — so
	## while tight, a touch-drag anywhere over the step area died at PhaseContainer and
	## the outer scroll never saw it. Measured on the tablet: every swipe inside the card
	## produced a pixel-identical screenshot, while one on the strip just above it (the
	## only place outside PhaseContainer) scrolled the screen correctly.
	##
	## Drives BOTH states on purpose. Asserting the relationship at whatever size the
	## harness happens to be is worth nothing here: the relaxed answer (STOP, inner owns)
	## is also the answer with this fix reverted, so a one-state version passes either
	## way -- it would go green while the bug is present.
	##
	## Both branches are driven DIRECTLY through _apply_layout_for(), not coaxed out of
	## the screen by resizing the window. An earlier version picked two window sizes and
	## asserted they straddled the branch; it was green run alone and failed in any
	## multi-suite run, because a suite that ran first left the window in a state where
	## BOTH sizes measured relaxed. The decision belongs to _is_tight() and is tested
	## separately — what matters here is that each layout wires the gesture correctly.
	var wp := _make()
	await await_millis(120)

	for tight in [true, false]:
		wp._apply_layout_for(tight)
		await await_millis(60)

		var pc: Node = _find_named(wp, "PhaseContainer")
		var ps: Node = _find_named(wp, "PhaseScroll")
		var outer: Node = _find_named(wp, "ContentScroll")
		assert_that(pc).is_not_null()
		assert_that(ps).is_not_null()
		assert_that(outer).is_not_null()

		var outer_owns: bool = (outer as ScrollContainer).vertical_scroll_mode \
			!= ScrollContainer.SCROLL_MODE_DISABLED
		# EVERY control between the finger and the outer scroll has to let the drag past,
		# not just these two — see test_decorative_chrome_does_not_swallow_the_drag. These
		# are the two the compaction pass owns directly.
		var chain_open: bool = \
			(ps as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE \
			and (pc as Control).mouse_filter != Control.MOUSE_FILTER_STOP

		assert_bool(outer_owns) \
			.override_failure_message(
				"_apply_layout_for(%s): the outer scroll must own scrolling in EVERY "
				% str(tight) + "layout. It also holds StepNavigation, so a layout that "
				+ "disables it puts Next Step out of reach on any tall page.")\
			.is_true()
		# Open exactly when the outer scroll is the one that needs to receive the drag.
		assert_bool(chain_open) \
			.override_failure_message(
				"_apply_layout_for(%s): outer_owns=%s but chain_open=%s -- the gesture "
				% [str(tight), outer_owns, chain_open]
				+ "cannot reach the scroll that owns it")\
			.is_equal(outer_owns)


func test_decorative_chrome_does_not_swallow_the_drag() -> void:
	## The blocker that survived TWO wrong fixes, so it is asserted on live nodes.
	##
	## Clearing PhaseScroll and PhaseContainer changed nothing on the tablet, because the
	## finger never touches them — it touches whatever chrome is drawn under it. The chain
	## measured on device was @HSeparator (STOP) inside WorldBriefingCard (PanelContainer,
	## STOP): both default to STOP, both mark the drag handled, and the outer scroll never
	## saw it. It is a class of blocker, not two nodes, and the briefing rebuilds a fresh
	## crop of them on every refresh.
	##
	## Invariant: while the OUTER scroll owns scrolling, nothing non-focusable inside it
	## may still be STOP. Focusable controls are exempt on purpose — dragging over a list
	## should scroll that list.
	var wp := _make()
	await await_millis(120)

	# Forced, not coaxed out of a window size — see the note in
	# test_gesture_reaches_whichever_scroll_owns_it about order-dependence.
	wp._apply_layout_for(true)
	await await_millis(80)

	var outer: Node = _find_named(wp, "ContentScroll")
	assert_that(outer).is_not_null()

	var blockers: Array[String] = []
	_collect_blockers(outer, blockers)

	assert_array(blockers) \
		.override_failure_message(
			"these non-focusable controls are still MOUSE_FILTER_STOP inside the "
			+ "scroll that owns the gesture, so a touch-drag over any of them dies "
			+ "there: %s" % str(blockers))\
		.is_empty()

	# ...and the RELAXED layout must be just as open.
	#
	# ⚠ THIS ASSERTION USED TO BE INVERTED, and the inversion was the bug. It required
	# the relaxed layout to put STOP back, on the premise that the inner scroll would be
	# offered the drag first. That is true of PhaseContainer, which sits ABOVE PhaseScroll,
	# and false of the cards and separators INSIDE it — they are deeper, are offered the
	# event first, and STOP marks it handled. So on every tall screen (the tablet in
	# landscape included) a touch-drag over the step area reached no scroll at all, while
	# the scrollbar worked fine. A test can encode a bug as confidently as code can.
	wp._apply_layout_for(false)
	await await_millis(80)
	var still_blocked: Array[String] = []
	_collect_blockers(outer, still_blocked)
	assert_array(still_blocked) \
		.override_failure_message(
			"the relaxed layout re-closed these non-focusable controls, so a touch-drag "
			+ "over any of them dies there instead of reaching the scroll that owns the "
			+ "gesture: %s" % str(still_blocked))\
		.is_empty()


func _collect_blockers(node: Node, out: Array[String]) -> void:
	for child in node.get_children():
		if child is Control:
			var c := child as Control
			if c.focus_mode == Control.FOCUS_NONE and not (c is ScrollContainer) \
					and c.mouse_filter == Control.MOUSE_FILTER_STOP:
				out.append("%s(%s)" % [str(c.name), c.get_class()])
		_collect_blockers(child, out)


func test_relaxed_state_restores_the_scenes_own_filter() -> void:
	## Restore what the scene declared, not a hard-coded STOP: the value is captured once
	## before compaction first overwrites it. Writing STOP back would bake today's engine
	## default into the screen and silently discard any filter the .tscn later sets.
	var src := _source()
	# The two filters are now unconditional, because the outer scroll owns the gesture in
	# every layout and both of these sit between the finger and it. The old conditional
	# forms restored STOP-adjacent values on the relaxed path and are what left touch-drag
	# dead on tall screens; assert they cannot come back.
	assert_str(src).contains("phase_container.mouse_filter = Control.MOUSE_FILTER_PASS")
	assert_str(src).contains(
		"(phase_scroll as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE")
	assert_str(src).not_contains(
		"Control.MOUSE_FILTER_PASS if tight else _phase_container_mouse_filter")
	assert_str(src).not_contains(
		"Control.MOUSE_FILTER_IGNORE if tight else _phase_scroll_mouse_filter")
	# The sweep must read the CACHED decision. Re-deriving it from a rebuild hook asks the
	# question mid-teardown — the briefing has just freed its children, the budget reads
	# huge, and the "not tight" answer closes every control the sweep had just opened.
	# Measured on device: opened=33, then a re-measure closed all 33 again.
	assert_str(src).contains("_open_content_to_scroll_gesture(_is_tight_layout)")
	assert_str(src).not_contains("_open_content_to_scroll_gesture(_is_tight())")


## NOT TESTED HERE, and deliberately so: the production BUDGET NUMBER at 1280x800.
##
## It was attempted and removed rather than weakened. A WorldPhaseController with no
## campaign carries a fraction of its production minimums in the Controls block, Footer
## and Header, so the budget it measures is not the budget a real campaign produces and
## no assertion on the value survives. The only ways to make it pass were to fake the
## chrome or to assert something that holds in both states; both give a green row that
## proves nothing.
##
## Correction (measured Aug 8 2026, after this note first claimed otherwise): what the
## harness CAN reach is the tight BRANCH — this suite takes it at 1280x800, which is what
## gives test_gesture_reaches_whichever_scroll_owns_it its detection power. The same
## scene instantiated bare under a SceneTree script stays relaxed at that size (budget
## 673 against a floor of 320). So "which size is tight" depends on the harness and must
## be asserted, never assumed; the earlier blanket "reports NOT tight at 1280x800" was
## true of the bare probe only.
##
## The real-geometry evidence for this fix is the runtime probe recorded in
## docs/qa/TABLET_QA_SPRINT_2026-08.md (T4-03): with the fix, 1280x800 gives budget
## 283.7 across three consecutive passes, the outer scroll takes the gesture, and the
## step area lays out at 1151px instead of 117px, with the crew list rendering all six
## members. test_compaction_triggers_on_either_small_screen_or_starved_step_area is the
## regression guard — reverting the budget condition fails it.


# ---------------------------------------------------------------------------
# W2-05 — the page must rewind when the STEP changes, and only then.
#
# Found on the tablet: arriving at a short step from a long one left the scroll
# offset where it was, so the new step's heading was above the fold and the
# visible remainder was blank. It presented as missing DATA — "Crew Tasks shows
# 1 of 6 crew" — and burned real time in _get_eligible_crew() and
# _populate_crew_list() before scrolling the page revealed all six were present
# the whole time. That is the expensive part of this bug, and why it is pinned.
# ---------------------------------------------------------------------------

func _content_scroll(wp: Control) -> ScrollContainer:
	return wp.get_node_or_null("MarginContainer/VBoxContainer/ContentScroll") as ScrollContainer


func test_changing_step_rewinds_the_page_to_the_top() -> void:
	var wp := _make()
	var scroll: ScrollContainer = await _make_page_scrollable(wp)

	scroll.scroll_vertical = 400
	# Without this line the test is worthless: on a page that fits, the setter clamps
	# to 0 and the assertion below passes whether or not the rewind exists.
	assert_int(scroll.scroll_vertical).is_equal(400)

	wp.current_step = wp.current_step + 1
	wp._show_current_step()

	assert_int(scroll.scroll_vertical).is_equal(0)


## Make the page genuinely taller than its viewport, so a non-zero scroll offset is
## a LEGAL state. Without this the ScrollContainer clamps scroll_vertical to 0 (its
## scrollbar max is 0 when the content fits), and a test that "scrolls down" would
## silently be testing 0 == 0 — passing whether or not the guard exists.
func _make_page_scrollable(wp: Control) -> ScrollContainer:
	var scroll := _content_scroll(wp)
	assert_that(scroll).is_not_null()
	var column := scroll.get_node_or_null("ContentColumn")
	assert_that(column).is_not_null()
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4000)
	column.add_child(spacer)
	await await_idle_frame()
	return scroll


func test_re_showing_the_same_step_does_not_yank_the_player_to_the_top() -> void:
	# The guard, not the rewind. _show_current_step() has seven call sites; an
	# unconditional reset would fight the player the first time one of them becomes
	# a mid-interaction refresh. Same shape as the W2-01 turn stamp.
	var wp := _make()
	var scroll: ScrollContainer = await _make_page_scrollable(wp)

	wp._show_current_step()          # claims the current step
	scroll.scroll_vertical = 250     # player scrolls down
	# Prove the harness can actually hold an offset before asserting it survived.
	assert_int(scroll.scroll_vertical).is_equal(250)

	wp._show_current_step()          # a refresh, NOT a step change

	assert_int(scroll.scroll_vertical).is_equal(250)


# ---------------------------------------------------------------------------
# T2-06 — a checkpoint from a PREVIOUS turn must not leak completion flags.
#
# The strip rendered `1 2 3 4 ✓ 6` on a fresh Turn 9 Step 1 (confirmed twice on
# device). Position 5 is RESOLVE_RUMORS. The staleness rule already existed, inline
# in _setup_initial_state(), with a comment naming this exact symptom — but
# CampaignTurnController REUSES this controller in place on Turn 2+, firing neither
# _ready() nor _setup_initial_state(). On that path the only gate consulted was
# has_checkpoint(), which asked nothing but is_empty(), so last turn's
# step_completed survived. Producers had written `turn_number` for precisely this
# check and no consumer ever read it.
# ---------------------------------------------------------------------------

const WPC := preload("res://src/ui/screens/world/WorldPhaseController.gd")


func test_a_checkpoint_from_another_turn_is_stale() -> void:
	var cp := {"turn_number": 8, "step_completed": {0: true, 4: true}}
	assert_bool(WPC.is_checkpoint_stale(cp, 9)).is_true()


func test_a_checkpoint_from_the_same_turn_is_kept() -> void:
	# The whole point of a checkpoint: leaving to the dashboard mid-turn and coming
	# back must NOT wipe the steps already done.
	var cp := {"turn_number": 9, "step_completed": {0: true, 4: false}}
	assert_bool(WPC.is_checkpoint_stale(cp, 9)).is_false()


func test_a_fully_completed_checkpoint_is_stale_even_on_the_same_turn() -> void:
	# It describes a FINISHED world phase; restoring it drops the player into a turn
	# with nothing left to do.
	var cp := {"turn_number": 9, "step_completed": {0: true, 1: true, 2: true}}
	assert_bool(WPC.is_checkpoint_stale(cp, 9)).is_true()


func test_an_empty_checkpoint_is_not_stale() -> void:
	# "Nothing saved" and "saved something rotten" are different states, and only the
	# second should trigger a clear.
	assert_bool(WPC.is_checkpoint_stale({}, 9)).is_false()


func test_an_unstamped_checkpoint_is_not_discarded_on_turn_alone() -> void:
	# Pre-fix saves carry no turn_number. Treating -1 as a mismatch would wipe a
	# legitimate in-progress turn on the first launch after upgrading.
	var cp := {"step_completed": {0: true, 4: false}}
	assert_bool(WPC.is_checkpoint_stale(cp, 9)).is_false()


func test_has_checkpoint_rejects_a_stale_one() -> void:
	# DETECTION-CRITICAL: this is the gate initialize_world_phase() reads to decide
	# whether to skip reset_world_phase(). If it still answered on is_empty() alone,
	# every fix above would be inert on the path that actually breaks.
	var wp := _make()
	wp._checkpoint_data = {"turn_number": -99, "step_completed": {4: true}}

	assert_bool(wp.has_checkpoint()).is_false()
	assert_bool(wp._checkpoint_data.is_empty()).is_true()
