extends GdUnitTestSuite
## T11-40 — the tight/relaxed decision must not depend on the layout it produces.
##
## THE DEFECT THIS PINS. `_phase_viewport_budget()` subtracted the minimum of every
## visible non-Phase child of `ContentColumn`, and `_apply_nav_pinning()` MOVES
## Controls / HSeparator2 / Footer out of that column whenever the layout is relaxed.
## So the same screen at the same size measured two different budgets depending on
## where the nav currently lived. Measured on a 689.7 design-px viewport:
##
##     nav inside ContentColumn   ->  244.7  ->  tight   (keeps it inside)
##     nav pinned outside         ->  502.7  ->  relaxed (keeps it outside)
##
## against MIN_PHASE_VIEWPORT_DESIGN_PX = 320. Both are stable fixed points, so the
## layout latched to whichever it reached first, and the delta was exactly the nav's
## own minimum plus its separations. On the tablet that stranded the World Phase
## footer below the fold (T11-40).
##
## The budget's own docblock takes care to keep the UNITS monotonic — it measures in
## fixed RELAXED units precisely so compaction cannot feed back into the decision.
## Node LOCATION was a second input, and it moved with the answer.
##
## ⚠ These cases are deliberately SIZE-INDEPENDENT. Headless gives a dummy
## DisplayServer, so `window_set_size()` does nothing and every rect measures at the
## default — a case that tried to force 1280x800 here would assert against whatever
## the harness happened to provide. The invariant does not need a particular size:
## at ANY size the two pinning states must agree.

const SCENE := "res://src/ui/screens/world/WorldPhaseController.tscn"
const NAV_NAMES: Array[String] = ["Controls", "HSeparator2", "Footer"]

func _screen() -> Node:
	var inst: Node = (load(SCENE) as PackedScene).instantiate()
	add_child(inst)
	auto_free(inst)
	return inst

func _nav_node(inst: Node, nav_name: String) -> Control:
	var vbox: Node = inst.get_node_or_null("MarginContainer/VBoxContainer")
	if vbox == null:
		return null
	var scroll: Node = vbox.get_node_or_null("ContentScroll")
	var column: Node = scroll.get_node_or_null("ContentColumn") if scroll else null
	var found: Node = column.get_node_or_null(nav_name) if column else null
	if found == null:
		found = vbox.get_node_or_null(nav_name)
	return found as Control


func test_the_budget_does_not_depend_on_where_the_nav_is_parented() -> void:
	var inst: Node = _screen()
	await get_tree().process_frame

	inst._apply_nav_pinning(true)          # nav INSIDE ContentColumn
	await get_tree().process_frame
	var tight_side: float = inst._phase_viewport_budget()

	inst._apply_nav_pinning(false)         # nav PINNED outside
	await get_tree().process_frame
	var relaxed_side: float = inst._phase_viewport_budget()

	# The whole latch, in one assertion. Pre-fix these differed by the nav's own
	# minimum plus separations (measured 258.0 px at 689.7, 265.0 at 1379.3).
	assert_float(relaxed_side).is_equal_approx(tight_side, 0.01)

func test_the_decision_is_stable_under_repeated_evaluation() -> void:
	# A latched budget also means _is_tight() can flip on a re-ask that changed
	# nothing. Asking it three times across both arrangements must give one answer.
	var inst: Node = _screen()
	await get_tree().process_frame
	var first: bool = inst._is_tight()
	inst._apply_nav_pinning(true)
	await get_tree().process_frame
	var after_tight: bool = inst._is_tight()
	inst._apply_nav_pinning(false)
	await get_tree().process_frame
	var after_relaxed: bool = inst._is_tight()
	assert_bool(after_tight).is_equal(first)
	assert_bool(after_relaxed).is_equal(first)

func test_the_nav_is_actually_subtracted_from_the_budget() -> void:
	# The invariant above would also hold if the nav were subtracted NOWHERE, which
	# would over-report the space available to the step area. Hiding it must give its
	# height back, and by its own minimum — proving it is counted exactly once.
	var inst: Node = _screen()
	await get_tree().process_frame
	inst._apply_nav_pinning(true)
	await get_tree().process_frame
	var with_nav: float = inst._phase_viewport_budget()

	var reclaimed: float = 0.0
	for nav_name in NAV_NAMES:
		var nav: Control = _nav_node(inst, nav_name)
		if nav != null and nav.visible:
			reclaimed += nav.get_combined_minimum_size().y + 24.0  # RELAXED_SEPARATION_PX
			nav.visible = false
	assert_float(reclaimed).is_greater(0.0)
	await get_tree().process_frame
	var without_nav: float = inst._phase_viewport_budget()
	assert_float(without_nav - with_nav).is_equal_approx(reclaimed, 0.01)

func test_the_arrangement_matches_the_decision_after_compaction() -> void:
	# The player-visible half of T11-40: a screen that DECIDES relaxed must actually
	# pin the nav outside the scroll, and one that decides tight must leave it inside
	# (scrolling to it is strictly better on a 733x338 phone, which is why the tight
	# branch exists at all).
	var inst: Node = _screen()
	await get_tree().process_frame
	inst._apply_vertical_compaction()
	await get_tree().process_frame
	await get_tree().process_frame

	var vbox: Node = inst.get_node_or_null("MarginContainer/VBoxContainer")
	assert_object(vbox).is_not_null()
	var tight: bool = inst._is_tight_layout
	for nav_name in NAV_NAMES:
		var pinned_here: bool = vbox.get_node_or_null(nav_name) != null
		# tight  -> the nav lives in ContentColumn, so it is NOT a direct vbox child
		# relaxed -> it is pinned as a direct vbox child
		assert_bool(pinned_here).is_equal(not tight)
