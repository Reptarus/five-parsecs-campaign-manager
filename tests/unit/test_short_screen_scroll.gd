extends GdUnitTestSuite
## ShortScreenScroll — the T11-01 contract (fixed 2026-09-04).
##
## Two independent defects shipped together in PreBattleUI, either fatal alone:
##
##  1. THE GATE ASKED THE WRONG QUESTION. `viewport.height < short_px` (620) can
##     never fire on a tablet in landscape, whose DESIGN height is 689 — so the
##     ScrollContainer stayed DISABLED, and a DISABLED ScrollContainer propagates
##     its child's minimum. The populated screen pushed its root MarginContainer
##     196.7 px past the viewport, and since that node is anchored full-rect with
##     grow_vertical = BOTH it grew in both directions: header off the top, footer
##     off the bottom. Swiping did nothing because the scroll was disabled, not
##     because it was exhausted.
##
##  2. EVERY CHILD WENT INTO THE SCROLL, footer included. PreBattleUI's own
##     docblock said the footer "stays put — always visible below the group",
##     which was true until the scroll helper was added below it.
##
## The layout sweep (tests/tools/verify_layout.gd) proves defect 1 end-to-end once
## its screens are populated. It CANNOT prove defect 2: a footer that scrolls away
## is inside the scroll, and content inside a scroll is allowed to exceed the
## viewport — that is what scrolling means. So the pinning contract is asserted
## structurally here instead.

const SSS := preload("res://src/ui/components/base/ShortScreenScroll.gd")

## Big enough that the scroll gets a real budget after the pins take their share.
const ROOT_SIZE := Vector2(800.0, 600.0)

var _root: Control
var _column: VBoxContainer
var _header: Control
var _body: Control
var _footer: Control


func before_test() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.custom_minimum_size = ROOT_SIZE
	_root.size = ROOT_SIZE
	add_child(_root)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_column)

	_header = _block("Header", 40.0)
	_body = _block("Body", 100.0)
	_footer = _block("Footer", 60.0)
	_column.add_child(_header)
	_column.add_child(_body)
	_column.add_child(_footer)


func after_test() -> void:
	if is_instance_valid(_root):
		_root.queue_free()


func _block(n: String, h: float) -> Control:
	var c := Control.new()
	c.name = n
	c.custom_minimum_size = Vector2(10.0, h)
	return c


func _install(pinned: int, short_px: float, trailing: int) -> void:
	var sss = SSS.new()
	_root.add_child(sss)
	sss.setup(_column, pinned, short_px, trailing)


## _apply_deferred() polls up to 8 frames for a non-zero budget before deciding.
func _settle() -> void:
	for _i in range(16):
		await get_tree().process_frame


func _scroll() -> ScrollContainer:
	return _column.get_node_or_null("ContentScroll") as ScrollContainer


# ── the pinning contract ────────────────────────────────────────────────────

func test_a_trailing_pin_keeps_the_footer_out_of_the_scroll() -> void:
	_install(1, 620.0, 1)
	var scroll := _scroll()
	assert_object(scroll).is_not_null()
	assert_object(_footer.get_parent()).override_failure_message(
		"a pinned footer must stay a child of the column; if it moves into the "
		+ "scroll it scrolls away with the content, which is what T11-01 did"
	).is_same(_column)
	assert_object(_header.get_parent()).override_failure_message(
		"a leading pin stays outside the scroll too"
	).is_same(_column)
	assert_object(_body.get_parent()).is_same(scroll.get_node("ScrollColumn"))


func test_the_scroll_is_seated_between_the_two_pins() -> void:
	## add_child() APPENDS, so without the explicit move_child the scroll would be
	## created below the footer and the footer would render above the content.
	_install(1, 620.0, 1)
	assert_int(_header.get_index()).is_equal(0)
	assert_int(_scroll().get_index()).override_failure_message(
		"the scroll must sit directly after the leading pins, not at the end"
	).is_equal(1)
	assert_int(_footer.get_index()).override_failure_message(
		"the trailing pin must remain the LAST child, i.e. the bottom of the column"
	).is_equal(2)


func test_zero_trailing_pins_is_exactly_the_old_behaviour() -> void:
	## Six of the seven live call sites pass no trailing count, so the 3-argument
	## form must keep moving everything after the leading pins, as it always did.
	_install(0, 620.0, 0)
	var inner := _scroll().get_node("ScrollColumn")
	assert_object(_header.get_parent()).is_same(inner)
	assert_object(_body.get_parent()).is_same(inner)
	assert_object(_footer.get_parent()).is_same(inner)


# ── the gate ────────────────────────────────────────────────────────────────

func test_content_taller_than_the_budget_enables_scrolling() -> void:
	## THE T11-01 CASE. short_px 1.0 removes the viewport clause entirely, so only
	## the fit test can turn scrolling on. Before the fix this returned DISABLED
	## for any viewport at least 620 design px tall, no matter how tall the content.
	_body.custom_minimum_size = Vector2(10.0, 20000.0)
	_install(1, 1.0, 1)
	await _settle()
	assert_int(_scroll().vertical_scroll_mode).override_failure_message(
		"20000px of content in a 600px column must scroll regardless of how tall "
		+ "the viewport is"
	).is_equal(ScrollContainer.SCROLL_MODE_AUTO)


func test_content_that_fits_leaves_the_scroll_disabled() -> void:
	## The other half of the promise, and the one the SOP makes to nine screens: a
	## screen whose content fits lays out exactly as it did before this component
	## learned to measure. A DISABLED scroll propagates its child's minimum, which
	## is what makes it equivalent to the plain container it replaced.
	_install(1, 1.0, 1)
	await _settle()
	var scroll := _scroll()
	# DISCRIMINATING-FIXTURE GUARD: if the harness never gave the scroll a real
	# budget, "it fits" would be true for the wrong reason and this case would pass
	# while proving nothing.
	assert_float(scroll.size.y).override_failure_message(
		"the fixture gave the scroll no height, so this case cannot distinguish "
		+ "fits-comfortably from never-laid-out"
	).is_greater(200.0)
	assert_int(scroll.vertical_scroll_mode).override_failure_message(
		"40+100+60 px of content in a 600px column does not need a scroll"
	).is_equal(ScrollContainer.SCROLL_MODE_DISABLED)


func test_a_short_viewport_still_forces_scrolling_when_content_fits() -> void:
	## The kept floor. The viewport clause was NOT removed: it is what all seven
	## existing callers have been getting, it can only ever turn scrolling ON, and
	## on a fitting screen AUTO renders identically to DISABLED anyway. A short_px
	## above any real viewport height makes it fire.
	_install(1, 100000.0, 1)
	await _settle()
	assert_int(_scroll().vertical_scroll_mode).override_failure_message(
		"the viewport-height floor must still force AUTO, so no existing caller "
		+ "loses behaviour it already had"
	).is_equal(ScrollContainer.SCROLL_MODE_AUTO)


func test_setup_is_idempotent_and_does_not_build_a_second_scroll() -> void:
	## Several screens are SHOWN rather than re-instantiated between turns
	## (CampaignTurnController does this), so setup() can run twice on one column.
	_install(1, 620.0, 1)
	_install(1, 620.0, 1)
	var scrolls := 0
	for c in _column.get_children():
		if c is ScrollContainer:
			scrolls += 1
	assert_int(scrolls).override_failure_message(
		"a second setup() must reuse the existing scroll, not nest another one"
	).is_equal(1)
	assert_object(_footer.get_parent()).is_same(_column)
