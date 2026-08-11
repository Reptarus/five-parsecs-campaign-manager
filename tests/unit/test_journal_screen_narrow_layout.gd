extends GdUnitTestSuite
## CampaignJournalScreen must fit a small phone (tablet QA sprint, Aug 8 2026)
##
## The two long-standing verify_layout failures — "@MarginContainer@NNNN off-screen by
## 12.2 px" at 393x851 and "48.7 px" at 360x640 — were HORIZONTAL, not vertical, and the
## cause was three buttons in a plain HBoxContainer at the bottom of the detail pane.
##
## Why a button row 5 levels down sets the width of the whole screen: the detail pane's
## ScrollContainer has horizontal_scroll_mode = SCROLL_MODE_DISABLED, and a disabled axis
## propagates its child's minimum straight up instead of absorbing it. So 243px of
## un-wrappable buttons became 259 (margin) -> 267 (scroll) -> 299 (panel) -> 331 (split)
## -> 359 at the root MarginContainer, against 310.3 design px of phone. 359 - 310.3 =
## 48.7, exactly what the harness reported.
##
## The fix is the one this screen's own _build_header() already uses: an HFlowContainer,
## whose minimum is its WIDEST ITEM rather than the SUM. Measured after: 155, and the
## sweep went from 166/2 to 168/0.
##
## gdUnit4 v6.0.3 compatible. NOTE: run with -c, never --headless (project rule).

const JournalScene := preload("res://src/ui/screens/campaign/CampaignJournalScreen.tscn")

## Window sizes, matching verify_layout. Its labels quote the resulting DESIGN rect
## ("360x640" -> "310x551"); setting the design numbers as the window measures a
## different screen and the failing case comes back clean.
const SMALL_PHONE := Vector2i(360, 640)
const PHONE_PORTRAIT := Vector2i(393, 851)


func _root_margin(inst: Node) -> MarginContainer:
	for c in inst.get_children():
		if c is MarginContainer:
			return c as MarginContainer
	return null


func test_screen_minimum_width_fits_a_small_phone() -> void:
	var inst: Control = auto_free(JournalScene.instantiate())
	add_child(inst)
	await await_millis(150)

	var win := get_tree().root
	var original: Vector2i = win.size
	var failures: Array[String] = []

	for size in [SMALL_PHONE, PHONE_PORTRAIT]:
		DisplayServer.window_set_size(size)
		await await_millis(150)

		var margin := _root_margin(inst)
		assert_that(margin).is_not_null()
		var design: Vector2 = get_viewport().get_visible_rect().size
		var need: float = margin.get_combined_minimum_size().x
		# 1px of slack for rounding in the design-space divide; the real regression is
		# tens of px (48.7 when this last broke), so this cannot mask one.
		if need > design.x + 1.0:
			failures.append("%dx%d: needs %.1f design px of width but has %.1f (over by %.1f)"
				% [size.x, size.y, need, design.x, need - design.x])

	DisplayServer.window_set_size(original)
	await await_millis(100)

	assert_array(failures) \
		.override_failure_message(
			"CampaignJournalScreen cannot fit a phone: %s. Something in the detail pane "
			% str(failures)
			+ "has an un-shrinkable horizontal minimum — check for a non-wrapping row "
			+ "under the ScrollContainer, whose disabled horizontal axis propagates it.")\
		.is_empty()


func test_detail_actions_wrap_instead_of_setting_a_width_floor() -> void:
	## Guards the mechanism, not just the number: an HBoxContainer's minimum is the SUM of
	## its children's, so restoring one here would silently reinstate the floor even if
	## the buttons were individually narrowed.
	var inst: Control = auto_free(JournalScene.instantiate())
	add_child(inst)
	await await_millis(150)

	var row := _find_actions_row(inst)
	assert_that(row) \
		.override_failure_message(
			"could not find the detail-actions row (Edit Notes / Attach Photo / "
			+ "View Photos) — if it was renamed, update this test rather than deleting it")\
		.is_not_null()
	assert_bool(row is HFlowContainer) \
		.override_failure_message(
			"the detail-actions row is a %s. It must wrap: as a non-wrapping box its "
			% row.get_class()
			+ "minimum is the SUM of three buttons, which propagates up through the "
			+ "horizontally-disabled ScrollContainer and sets the whole screen's width.")\
		.is_true()


## Found by its buttons rather than by node name: the row is code-built and unnamed, so
## a name lookup would silently return null and pass a hollow test.
func _find_actions_row(node: Node) -> Control:
	var wanted := ["Edit Notes", "Attach Photo", "View Photos"]
	if node is Container:
		var found := 0
		for c in node.get_children():
			if c is Button and wanted.has((c as Button).text):
				found += 1
		if found >= 2:
			return node as Control
	for c in node.get_children():
		var hit := _find_actions_row(c)
		if hit != null:
			return hit
	return null
