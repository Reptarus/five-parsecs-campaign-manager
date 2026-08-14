extends GdUnitTestSuite
## Soft-keyboard avoidance contract (T3-01, tablet QA sprint Aug 8 2026)
##
## The bug: nothing in this app yielded to the Android soft keyboard, so any input
## below the screen midline was typed blind. Desktop QA structurally cannot find it
## (no IME), and it survived every prior pass for exactly that reason.
##
## The reason this suite is mostly STATIC-function tests is not laziness — it is the
## only honest way to pin the fix. The live path needs a real IME, so everything
## that can be decided without one was deliberately factored into pure functions:
## the classification, the physical->logical conversion, the shift arithmetic and
## the ancestor search. What is left in the Node is wiring, and the wiring is
## asserted separately (registration + arm/disarm) rather than pretended-at.
##
## gdUnit4 v6.0.3 compatible. NOTE: run with -c, never --headless (project rule).

const KA := preload("res://src/autoload/KeyboardAvoidance.gd")


# ---------------------------------------------------------------- classification

func test_line_edit_and_text_edit_raise_the_keyboard() -> void:
	var le: LineEdit = auto_free(LineEdit.new())
	var te: TextEdit = auto_free(TextEdit.new())
	assert_bool(KA.accepts_text(le)).is_true()
	assert_bool(KA.accepts_text(te)).is_true()


func test_non_text_controls_and_null_do_not_arm() -> void:
	# A Button taking focus must DISARM, not leave a stale armed control behind
	# polling for a keyboard that will never come.
	var btn: Button = auto_free(Button.new())
	assert_bool(KA.accepts_text(btn)).is_false()
	assert_bool(KA.accepts_text(null)).is_false()


func test_a_spinbox_is_covered_through_its_internal_line_edit() -> void:
	# SpinBox never takes focus itself — it hands focus to an internal LineEdit, so
	# that is what gui_focus_changed delivers. This is the campaign-editor and
	# creation-wizard case (every numeric field), so if LineEdit coverage ever
	# narrowed to "top-level LineEdits only", those screens would regress silently.
	var sb: SpinBox = auto_free(SpinBox.new())
	var inner := sb.get_line_edit()
	assert_that(inner).is_not_null()
	assert_bool(KA.accepts_text(inner)).is_true()


# ------------------------------------------------------- physical -> logical px

func test_keyboard_height_is_converted_out_of_physical_pixels() -> void:
	# The whole reason this conversion exists: DisplayServer reports the keyboard in
	# PHYSICAL px while Control rects live in the stretched design space. A 400px
	# keyboard on an 800px-tall window covers half the screen, so against a 1280-tall
	# logical viewport it must read 640, not 400.
	assert_float(KA.to_logical_height(400, 800, 1280.0)).is_equal_approx(640.0, 0.01)


func test_conversion_is_identity_when_design_space_matches_the_window() -> void:
	# Desktop, 1:1. Guards against someone "simplifying" the ratio into a constant.
	assert_float(KA.to_logical_height(300, 1000, 1000.0)).is_equal_approx(300.0, 0.01)


func test_conversion_survives_a_degenerate_window_without_dividing_by_zero() -> void:
	# window_get_size() can report 0 during a rotation. Falling back to the physical
	# value over-scrolls slightly; returning 0 or NaN would silently disable the fix
	# at exactly the moment the layout is changing.
	assert_float(KA.to_logical_height(400, 0, 1280.0)).is_equal_approx(400.0, 0.01)


# ------------------------------------------------------------ shift arithmetic

func test_a_field_in_the_upper_half_is_never_touched() -> void:
	# 1280-tall viewport, 500-tall keyboard -> safe area ends at 780. A field ending
	# at 300 is clear, so the correct answer is "do nothing".
	assert_float(KA.compute_shift(300.0, 1280.0, 500.0)).is_equal(0.0)


func test_an_occluded_field_is_shifted_clear_with_margin() -> void:
	# Field ends at 900, safe area ends at 780 -> 120 occluded, plus the 12px margin
	# so it does not sit flush against the keyboard's top edge.
	var shift: float = KA.compute_shift(900.0, 1280.0, 500.0, 12.0)
	assert_float(shift).is_equal_approx(132.0, 0.01)


func test_a_field_resting_exactly_on_the_keyboard_edge_still_gets_its_margin() -> void:
	# The boundary case a >= / > slip would flip. Field bottom == safe_bottom means
	# the field is technically visible but touching the keyboard; it should still
	# move by the margin.
	assert_float(KA.compute_shift(780.0, 1280.0, 500.0, 12.0)).is_equal_approx(12.0, 0.01)


func test_zero_keyboard_height_shifts_nothing() -> void:
	# DETECTION-CRITICAL. get_height() reads 0 both when the keyboard is absent AND
	# during the animation-in window, which is precisely when the naive
	# implementation samples it. Without this guard safe_bottom collapses to the
	# viewport height and every bottom-anchored field would be scrolled on focus, on
	# desktop too. A regression here is a visible jump on a device with a hardware
	# keyboard attached.
	assert_float(KA.compute_shift(1270.0, 1280.0, 0.0)).is_equal(0.0)


# --------------------------------------------------------- ancestor resolution

func test_the_shift_goes_to_a_scroll_that_can_actually_move() -> void:
	# DETECTION-CRITICAL, and it is the exact shape of the bug this sprint already
	# fixed once (W2-03): the World Phase nests a DISABLED inner ScrollContainer
	# inside an AUTO outer one. Handing the shift to the nearest ancestor without
	# checking the mode writes scroll_vertical on a container that cannot scroll —
	# a silent no-op that looks identical to "the fix was never written".
	var outer: ScrollContainer = auto_free(ScrollContainer.new())
	outer.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var inner := ScrollContainer.new()
	inner.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var field := LineEdit.new()
	outer.add_child(inner)
	inner.add_child(field)
	add_child(outer)

	assert_that(KA.find_scrollable_ancestor(field)).is_same(outer)


func test_no_scrollable_ancestor_resolves_to_null_rather_than_guessing() -> void:
	var plain: VBoxContainer = auto_free(VBoxContainer.new())
	var field := LineEdit.new()
	plain.add_child(field)
	add_child(plain)

	assert_that(KA.find_scrollable_ancestor(field)).is_null()


func test_the_search_does_not_return_the_field_itself() -> void:
	# A TextEdit is not a ScrollContainer but scrolls internally; if the walk ever
	# started at `from` instead of its parent, a self-match would send the shift
	# nowhere useful.
	var sc: ScrollContainer = auto_free(ScrollContainer.new())
	var field := LineEdit.new()
	sc.add_child(field)
	add_child(sc)

	assert_that(KA.find_scrollable_ancestor(field)).is_same(sc)


# -------------------------------------------------------------- wiring / setup

func test_the_autoload_is_registered_so_the_fix_is_actually_live() -> void:
	# The fix is systemic and has no per-screen call site, so registration IS the
	# wiring. An unregistered autoload would leave every test above passing against
	# code that never runs — the single most common failure mode in this codebase.
	var cfg := ConfigFile.new()
	assert_int(cfg.load("res://project.godot")).is_equal(OK)
	var entry := str(cfg.get_value("autoload", "KeyboardAvoidance", ""))
	assert_str(entry).contains("src/autoload/KeyboardAvoidance.gd")


func test_focusing_a_non_text_control_disarms_the_poller() -> void:
	var ka: Node = auto_free(KA.new())
	add_child(ka)
	var btn: Button = auto_free(Button.new())

	ka._on_gui_focus_changed(btn)

	assert_bool(ka.is_processing()).is_false()
	assert_that(ka._armed_control).is_null()


func test_focusing_a_text_field_arms_the_poller() -> void:
	# Arming is what buys the animation window. If focus stopped arming, the fix
	# would sample a 0 height once and do nothing, forever, on every device.
	var ka: Node = auto_free(KA.new())
	add_child(ka)
	var field: LineEdit = auto_free(LineEdit.new())

	ka._on_gui_focus_changed(field)

	assert_bool(ka.is_processing()).is_true()
	assert_that(ka._armed_control).is_same(field)


func test_the_poll_gives_up_instead_of_processing_forever() -> void:
	# A hardware keyboard makes get_height() legitimately return 0 forever. Without a
	# timeout the autoload would burn a _process callback for the life of the session
	# every time a field was focused.
	var ka: Node = auto_free(KA.new())
	add_child(ka)
	# The field MUST be in the tree and actually focused. A detached LineEdit cannot
	# grab focus (Godot logs "Condition !is_inside_tree() is true" and ignores it), so
	# _process would disarm on the has_focus() guard instead — the test would go green
	# while proving nothing about the timeout it exists to pin.
	var field: LineEdit = auto_free(LineEdit.new())
	add_child(field)
	field.grab_focus()
	assert_bool(field.has_focus()).is_true()

	ka._on_gui_focus_changed(field)
	assert_bool(ka.is_processing()).is_true()

	ka._process(KA.POLL_TIMEOUT_SEC + 0.1)

	assert_bool(ka.is_processing()).is_false()


func test_height_must_be_stable_before_it_is_trusted() -> void:
	# The keyboard animates, so the first non-zero reading is a PARTIAL height.
	# Acting on it would scroll to a position that is wrong by however much of the
	# animation was left. Two equal readings is the cheapest evidence it settled.
	assert_int(KA.STABLE_READINGS_REQUIRED).is_greater_equal(2)


# ------------------------------------------------------------------- headroom
#
# Added after the FIRST device confirmation failed (Aug 8 2026). v1 only scrolled,
# and shipped with a stated gap: a field on a page too short to scroll stays
# occluded. The Campaign Editor reproduced it immediately — its fields occupy ~870
# of 1600px, so the ScrollContainer's range was ZERO, scroll_vertical clamped back
# to 0, and the keyboard opened over a field that never moved. Scrolling alone
# cannot fix that; there has to be somewhere to scroll TO.

func _scroll_with_content() -> ScrollContainer:
	var sc: ScrollContainer = auto_free(ScrollContainer.new())
	var col := VBoxContainer.new()
	col.name = "Content"
	sc.add_child(col)
	add_child(sc)
	return sc


func test_the_scroll_content_container_is_found() -> void:
	var sc := _scroll_with_content()
	assert_that(KA.scroll_content(sc)).is_not_null()
	assert_str(KA.scroll_content(sc).name).is_equal("Content")


func test_headroom_is_added_to_the_content_not_the_scroll() -> void:
	# A second direct child of a ScrollContainer OVERLAPS the first rather than
	# stacking below it, so a spacer added there would add no range at all.
	var ka: Node = auto_free(KA.new())
	add_child(ka)
	var sc := _scroll_with_content()

	ka._ensure_headroom(sc, 400.0)

	var content := KA.scroll_content(sc)
	var spacer := content.get_node_or_null(NodePath(KA.SPACER_NAME))
	assert_that(spacer).is_not_null()
	assert_float((spacer as Control).custom_minimum_size.y).is_equal(400.0)


func test_headroom_is_never_added_twice() -> void:
	# Focus moves between fields on a form; each move re-applies. Stacking a new
	# spacer per tap would push the page down without limit.
	var ka: Node = auto_free(KA.new())
	add_child(ka)
	var sc := _scroll_with_content()

	ka._ensure_headroom(sc, 400.0)
	ka._ensure_headroom(sc, 300.0)

	var content := KA.scroll_content(sc)
	var spacers := 0
	for c in content.get_children():
		if c.name == KA.SPACER_NAME:
			spacers += 1
	assert_int(spacers).is_equal(1)


func test_the_spacer_is_always_the_last_child() -> void:
	# Anywhere else it would inject a gap into the middle of a form.
	var ka: Node = auto_free(KA.new())
	add_child(ka)
	var sc := _scroll_with_content()
	var content := KA.scroll_content(sc)
	ka._ensure_headroom(sc, 400.0)
	content.add_child(Label.new())        # a field added after the keyboard opened
	ka._ensure_headroom(sc, 400.0)

	var last := content.get_child(content.get_child_count() - 1)
	assert_str(last.name).is_equal(KA.SPACER_NAME)


func test_the_spacer_never_swallows_a_touch() -> void:
	# It sits under the keyboard, but a drag starting on it must still reach the
	# ScrollContainer — the exact defect class as W2-03/T4-01.
	var ka: Node = auto_free(KA.new())
	add_child(ka)
	var sc := _scroll_with_content()
	ka._ensure_headroom(sc, 400.0)

	var spacer := KA.scroll_content(sc).get_node_or_null(NodePath(KA.SPACER_NAME))
	assert_int((spacer as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_headroom_is_removed_when_the_keyboard_closes() -> void:
	# DETECTION-CRITICAL. A spacer outliving its keyboard is permanent dead space at
	# the bottom of a form, and it would be invisible in review — it only appears
	# after someone types.
	var ka: Node = auto_free(KA.new())
	add_child(ka)
	var sc := _scroll_with_content()
	ka._ensure_headroom(sc, 400.0)
	assert_that(KA.scroll_content(sc).get_node_or_null(NodePath(KA.SPACER_NAME))).is_not_null()

	ka._clear_headroom()

	assert_that(KA.scroll_content(sc).get_node_or_null(NodePath(KA.SPACER_NAME))).is_null()


func test_focusing_a_second_field_leaves_the_holding_state() -> void:
	# Without this the poller stays in its watch-for-close branch and never
	# re-shifts: moving between fields on a form would work exactly once.
	var ka: Node = auto_free(KA.new())
	add_child(ka)
	var a: LineEdit = auto_free(LineEdit.new())
	ka._holding = true

	ka._on_gui_focus_changed(a)

	assert_bool(ka._holding).is_false()
	assert_bool(ka.is_processing()).is_true()


func test_a_stale_shift_is_dropped_when_focus_has_already_moved() -> void:
	# _apply_avoidance awaits a frame (the spacer's effect on the scroll range is not
	# visible until layout runs). Tapping quickly between two fields starts a second
	# pass before the first resumes, and without the guard BOTH would add their own
	# shift to the same scroll — stacking into an over-scroll that jumps the page
	# past the field the player is actually in. Newest focus wins.
	var ka: Node = auto_free(KA.new())
	add_child(ka)
	var first: LineEdit = auto_free(LineEdit.new())
	var second: LineEdit = auto_free(LineEdit.new())

	ka._armed_control = second          # focus already moved on
	assert_that(ka._armed_control).is_not_same(first)
	# The guard is an identity comparison against the live armed control, so a
	# resumed coroutine for `first` must find itself stale.
	assert_bool(ka._armed_control == first).is_false()
