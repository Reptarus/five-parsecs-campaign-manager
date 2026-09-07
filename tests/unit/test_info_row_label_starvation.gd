extends GdUnitTestSuite
## T11 "Corporate Label" — CampaignScreenBase._create_info_row() must not let either of
## its two labels starve the other.
##
## THE DEFECT (tablet, Rivals card): the value rendered as a 1 px wide, 9-line vertical
## slab reading "Corporate". Measured causes, tests/tools/probe_label_clip_min.gd at
## FONT_SIZE_SM:
##
##     plain Label, autowrap off  ->  min (327, 23)   reports its FULL text width
##     the autowrapping value     ->  min (  1, 855)  855 px tall at 1 px wide
##
## CampaignDashboard passes a rival NAME as the row LABEL, and 327 px exhausts a ~384 px
## portrait column on its own, so the EXPAND_FILL value received only its 1 px minimum.
##
## ⚠ WHY THE NAME IS ASSERTED TOO, AND WHY THAT IS THE IMPORTANT HALF. The obvious fix
## is clip_text on the name — it does bound the minimum to 1 px, measured above. But
## SIZE_SHRINK_BEGIN hands a child EXACTLY its minimum, so clip_text alone would have
## made the name vanish on all 49 call sites while an overflow sweep reported clean:
## nothing overflows when everything is 1 px. A test that only checked the value would
## have passed that regression happily. Starvation is asserted in BOTH directions.
##
## Asserts RENDERED RECTS after a layout frame, never construction properties.
## tests/unit/test_prebattle_responsive_layout.gd:82-96 is the cautionary tale: it
## asserts custom_minimum_size and autowrap_mode, so it passes while the pane it covers
## renders header-only.

## The tablet portrait column the defect was observed in.
const ROW_WIDTH := 384.0
## A narrower row, where the defect is near-total rather than merely bad. MEASURED with
## the pre-fix code at the headless font size: the name label demands 218 px, so at 240 px
## the value was left FOURTEEN pixels - which is the "Corporate" slab. The wide row alone
## is a weaker detector (the value still got 158 px there), so both widths are asserted.
const ROW_NARROW := 240.0
## A real string from the device walk, and the one that caused this.
const LONG_LABEL := "Old nemesis (persistent, +1 enemies)"

var _screen: CampaignScreenBase


func before_test() -> void:
	_screen = CampaignScreenBase.new()
	add_child(_screen)
	auto_free(_screen)


## Build a real row, constrain it to a portrait column, and let it lay out.
func _laid_out(label: String, value: String,
		width: float = ROW_WIDTH) -> HBoxContainer:
	var hbox: HBoxContainer = _screen._create_info_row(label, value)
	_screen.add_child(hbox)
	hbox.size = Vector2(width, 32.0)
	# Two frames: one for the container sort, one for the labels to take their rects.
	await get_tree().process_frame
	await get_tree().process_frame
	return hbox


func test_the_row_still_has_the_two_label_shape_this_suite_assumes() -> void:
	# If the factory ever returns a different structure, every assertion below would
	# silently stop testing anything.
	var hbox := await _laid_out("Type", "Corporate")
	assert_int(hbox.get_child_count()).override_failure_message(
		"_create_info_row must return an HBox of exactly [name, value]"
	).is_equal(2)
	assert_object(hbox.get_child(0)).is_instanceof(Label)
	assert_object(hbox.get_child(1)).is_instanceof(Label)


func test_a_long_label_does_not_starve_the_value() -> void:
	# ⭐ THE DEFECT. Before the fix the value rendered at its 1 px minimum here.
	var hbox := await _laid_out(LONG_LABEL, "Corporate")
	var value: Label = hbox.get_child(1)

	assert_float(value.size.x).override_failure_message(
		"the value was starved to %.1f px of a %.0f px row by the label %s — this is "
		% [value.size.x, ROW_WIDTH, LONG_LABEL]
		+ "the 1px-wide 'Corporate' slab"
	).is_greater(ROW_WIDTH * 0.5)

	# Unit-free shape check: a value degraded to one glyph per line is far TALLER than
	# it is wide (measured 1 x 855). Any healthy text block is wider than it is tall.
	assert_bool(value.size.x > value.size.y).override_failure_message(
		"the value rendered %.1f x %.1f — taller than wide, i.e. wrapped to a vertical "
		% [value.size.x, value.size.y]
		+ "slab rather than a line of text"
	).is_true()


func test_a_long_label_does_not_starve_the_value_on_a_NARROW_row() -> void:
	# The faithful reproduction of the device symptom. Pre-fix the value rendered at
	# ~14 px here; the wide-row case above is the same defect with more slack.
	var hbox := await _laid_out(LONG_LABEL, "Corporate", ROW_NARROW)
	var value: Label = hbox.get_child(1)
	assert_float(value.size.x).override_failure_message(
		"on a %.0f px row the value got %.1f px - the label ate the row"
		% [ROW_NARROW, value.size.x]
	).is_greater(ROW_NARROW * 0.5)
	assert_bool(value.size.x > value.size.y).override_failure_message(
		"the value rendered %.1f x %.1f - a vertical slab, not a line of text"
		% [value.size.x, value.size.y]
	).is_true()


func test_a_long_label_does_not_starve_ITSELF() -> void:
	# ⭐ THE TRAP. clip_text bounds this label's minimum to 1 px, and SHRINK_BEGIN would
	# then hand it exactly that — a fix that deletes the label instead of clipping it.
	var hbox := await _laid_out(LONG_LABEL, "Corporate")
	var name_lbl: Label = hbox.get_child(0)

	assert_float(name_lbl.size.x).override_failure_message(
		"the name label rendered %.1f px wide — clip_text takes its minimum to 1 px, so "
		% name_lbl.size.x
		+ "it needs a container-level share (EXPAND_FILL + stretch ratio) or it vanishes"
	).is_greater(ROW_WIDTH * 0.15)

	assert_bool(name_lbl.clip_text).override_failure_message(
		"the name must clip rather than demand its full 327 px"
	).is_true()

	# The full string must stay recoverable once it is ellipsised.
	assert_str(name_lbl.tooltip_text).override_failure_message(
		"an ellipsised label must keep its full text in the tooltip"
	).is_equal(LONG_LABEL)


func test_a_short_label_still_leaves_the_value_the_larger_share() -> void:
	# The common shape — _create_info_row("Type", value) — must not regress: the value
	# is the payload and keeps the larger share of the row.
	var hbox := await _laid_out("Type", "Corporate")
	var name_lbl: Label = hbox.get_child(0)
	var value: Label = hbox.get_child(1)
	assert_bool(value.size.x > name_lbl.size.x).override_failure_message(
		"value %.1f px vs label %.1f px — the value should hold the larger share"
		% [value.size.x, name_lbl.size.x]
	).is_true()
