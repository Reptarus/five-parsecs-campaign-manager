extends GdUnitTestSuite
## The safety property the base-class touch sweep now depends on, measured.
##
## `BaseCampaignPanel` / `BasePhasePanel` used to refuse to touch Button, CheckBox,
## OptionButton, SpinBox and LinkButton — `return  # Interactive controls must keep
## MOUSE_FILTER_STOP`. Routing them onto `TouchScrollOpener` overrides that decision
## across every screen inheriting either base, so the question it was guarding against
## has to be answered rather than assumed:
##
##   **does a touch-drag that starts on a Button press the Button?**
##
## ⚠ **The Godot 4.6 class reference does NOT answer it.** It confirms the propagation
## rule — MOUSE_FILTER_PASS: *"If the control does not handle an event, it propagates up
## the node hierarchy"*; MOUSE_FILTER_STOP: *"These events are automatically marked as
## handled"* — and it documents that `Control.NOTIFICATION_SCROLL_BEGIN` is *"sent when a
## Control node inside a ScrollContainer starts being scrolled by a touch event"*. But
## whether `BaseButton` ACTS on that notification to cancel its own press is engine
## internals, and the class docs are silent. So this suite measures it.
##
## ⭐ **Both halves are asserted, always.** "It scrolls now" is worthless if it bought
## scrolling by making the list unselectable — that trade is invisible to a geometry
## sweep and to the STOP-count sweep in `test_touch_scroll_sweep.gd`, because both
## measure filters rather than outcomes.

const OpenerCls = preload("res://src/ui/components/common/TouchScrollOpener.gd")

const VIEW := Vector2(400, 300)
const ROW_H := 60
const ROWS := 20


class Rig:
	var sv: SubViewport
	var scroll: ScrollContainer
	var button: Button
	var check: CheckBox
	var rtl: RichTextLabel
	var metas: int = 0
	var presses: int = 0
	var toggles: int = 0
	var scroll_starts: int = 0

	func _on_pressed() -> void:
		presses += 1

	func _on_toggled(_on: bool) -> void:
		toggles += 1

	func _on_scroll_started() -> void:
		scroll_starts += 1

	func _on_meta(_meta: Variant) -> void:
		metas += 1


## A ScrollContainer with more content than it can show, whose 3rd row is a Button and
## whose 4th is a CheckBox — the two widgets the old rule protected and this one opens.
##
## ⚠ Both MUST sit inside the visible 300px band. Placed at row 8 (y=480) they are
## BELOW the viewport, so a drag aimed at them never enters the ScrollContainer at all —
## and the STOP arm then passes for the wrong reason, reporting "swallowed" for a
## gesture that was simply never delivered.
func _build(open_filters: bool) -> Rig:
	var r := Rig.new()
	r.sv = SubViewport.new()
	r.sv.size = Vector2i(int(VIEW.x), int(VIEW.y))
	add_child(r.sv)
	auto_free(r.sv)

	r.scroll = ScrollContainer.new()
	r.scroll.size = VIEW
	r.scroll.custom_minimum_size = VIEW
	r.sv.add_child(r.scroll)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	r.scroll.add_child(col)

	for i in range(ROWS):
		var row: Control
		if i == 1:
			# A result line the way the variant-mode panels print them: bbcode, fitted
			# to its text, NOT scrolling itself. One [url] so a tap has something to hit.
			r.rtl = RichTextLabel.new()
			r.rtl.bbcode_enabled = true
			r.rtl.fit_content = true
			r.rtl.scroll_active = false
			r.rtl.text = "[url=x]link[/url] result line %d" % i
			row = r.rtl
		elif i == 2:
			r.button = Button.new()
			r.button.text = "row %d" % i
			row = r.button
		elif i == 3:
			r.check = CheckBox.new()
			r.check.text = "row %d" % i
			row = r.check
		else:
			var p := PanelContainer.new()
			var l := Label.new()
			l.text = "row %d" % i
			p.add_child(l)
			row = p
		row.custom_minimum_size = Vector2(VIEW.x, ROW_H)
		col.add_child(row)

	r.button.pressed.connect(r._on_pressed)
	r.check.toggled.connect(r._on_toggled)
	r.rtl.meta_clicked.connect(r._on_meta)
	r.scroll.scroll_started.connect(r._on_scroll_started)

	if open_filters:
		OpenerCls.open_subtree(r.scroll)
	return r


func _settle(r: Rig) -> void:
	for _i in range(8):
		await get_tree().process_frame


## A synthetic touch-drag, same shape as `test_prebattle_responsive_layout._drag()`.
## `in_local_coords = true` because the points are already SubViewport-local.
func _drag(r: Rig, from: Vector2, dy: float) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	press.global_position = from
	r.sv.push_input(press, true)
	await get_tree().process_frame
	var pos := from
	var step := Vector2(0.0, dy / 8.0)
	for _i in range(8):
		pos += step
		var mm := InputEventMouseMotion.new()
		mm.position = pos
		mm.global_position = pos
		mm.relative = step
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		r.sv.push_input(mm, true)
		await get_tree().process_frame
	# Hold still so the drag speed decays. Releasing while it is non-zero starts
	# INERTIA and the scroll keeps travelling past whatever the assertion reads.
	for _j in range(14):
		await get_tree().process_frame
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	rel.position = pos
	rel.global_position = pos
	r.sv.push_input(rel, true)
	await get_tree().process_frame
	await get_tree().process_frame


## A tap: press and release in place, no motion between them.
func _tap(r: Rig, at: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	press.global_position = at
	r.sv.push_input(press, true)
	await get_tree().process_frame
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	rel.position = at
	rel.global_position = at
	r.sv.push_input(rel, true)
	await get_tree().process_frame
	await get_tree().process_frame


# ── The premise, instrumented first ─────────────────────────────────────────
# If touch emulation were off, EVERY drag below would read as blocked — which is
# indistinguishable from the defect. Assert the stimulus is deliverable before
# trusting a single row.

func test_the_touch_path_this_suite_drives_is_actually_armed() -> void:
	assert_bool(bool(ProjectSettings.get_setting(
		"input_devices/pointing/emulate_touch_from_mouse", false))).override_failure_message(
		"emulate_touch_from_mouse is OFF, so push_input() would not take the touch path "
		+ "and every drag in this suite would read as blocked whether or not it is"
	).is_true()
	assert_bool(DisplayServer.is_touchscreen_available()).override_failure_message(
		"DisplayServer reports no touchscreen, so ScrollContainer will not arm its touch "
		+ "drag and scroll_started can never fire"
	).is_true()


# ── The detection arm: prove the harness can see the defect ─────────────────

func test_a_stop_filtered_button_swallows_the_drag() -> void:
	# The pre-fix state, built deliberately. Without this the green rows below could
	# mean "the fix works" or "this harness cannot measure anything".
	var r := _build(false)
	await _settle(r)
	assert_int(r.button.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)

	await _drag(r, r.button.get_global_rect().get_center(), -100.0)
	assert_int(r.scroll.scroll_vertical).override_failure_message(
		"a STOP-filtered Button did NOT swallow the drag, so this suite's later "
		+ "assertions prove nothing about the fix"
	).is_equal(0)
	assert_int(r.scroll_starts).is_equal(0)


## A RichTextLabel that does not scroll owns no gesture, yet the opener skipped every
## RichTextLabel, so a result line kept STOP and a finger dragged over it moved nothing.
## Planetfall's turn steps are mostly result lines.
func test_a_non_scrolling_rich_text_line_swallows_the_drag_until_opened() -> void:
	var closed := _build(false)
	await _settle(closed)
	assert_int(closed.rtl.mouse_filter).override_failure_message(
		"premise: a RichTextLabel defaults to STOP").is_equal(Control.MOUSE_FILTER_STOP)
	await _drag(closed, closed.rtl.get_global_rect().get_center(), -100.0)
	assert_int(closed.scroll.scroll_vertical).override_failure_message(
		"premise: a STOP result line did not swallow the drag").is_equal(0)

	var opened := _build(true)
	await _settle(opened)
	assert_int(opened.rtl.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	await _drag(opened, opened.rtl.get_global_rect().get_center(), -100.0)
	assert_int(opened.scroll.scroll_vertical).override_failure_message(
		"a drag over an opened result line still did not scroll the page").is_greater(0)


## Opening a result line keeps its link: PASS delivers the tap to the label first.
func test_a_tap_on_an_opened_rich_text_link_still_fires() -> void:
	# The premise: this tap reaches the link on an untouched label. A first version aimed
	# at the 60 px row's middle, below the text line, and missed on BOTH arms.
	var closed := _build(false)
	await _settle(closed)
	await _tap(closed, _link_point(closed))
	assert_int(closed.metas).override_failure_message(
		"premise: the tap does not reach the link even on a STOP label").is_equal(1)
	var r := _build(true)
	await _settle(r)
	assert_int(r.rtl.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	await _tap(r, _link_point(r))
	assert_int(r.metas).override_failure_message(
		"a tap on the [url] of an opened result line no longer fires meta_clicked") \
		.is_equal(1)


## keep_open() opens what arrives AFTER the sweep: the result lines a step adds when its
## button is pressed. A one-shot sweep never saw them.
func test_keep_open_opens_controls_added_later() -> void:
	var root := Control.new()
	add_child(root)
	auto_free(root)
	OpenerCls.keep_open(root)
	OpenerCls.keep_open(root)
	assert_int(root.get_children().filter(func(n: Node) -> bool:
		return n.name.begins_with("__TouchScrollKeeper")).size()).override_failure_message(
		"keep_open is not idempotent").is_equal(1)
	var card := PanelContainer.new()
	var line := RichTextLabel.new()
	line.scroll_active = false
	var log := RichTextLabel.new()
	log.scroll_active = true
	card.add_child(line)
	root.add_child(card)
	root.add_child(log)
	assert_int(card.mouse_filter).override_failure_message("premise: arrives STOP") \
		.is_equal(Control.MOUSE_FILTER_STOP)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(card.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	assert_int(line.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	assert_int(log.mouse_filter).override_failure_message(
		"a scrolling label lost its own gesture").is_equal(Control.MOUSE_FILTER_STOP)


## A point inside the label's first word, which is the [url].
func _link_point(r: Rig) -> Vector2:
	var font: Font = r.rtl.get_theme_font("normal_font")
	var fs: int = r.rtl.get_theme_font_size("normal_font_size")
	# The row is 60 px tall and the text sits on its first line, so aim at that line.
	return r.rtl.get_global_rect().position + Vector2(
		font.get_string_size("li", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x,
		font.get_height(fs) / 2.0)


## A RichTextLabel that scrolls its own text keeps claiming its gesture.
func test_a_scrolling_rich_text_label_keeps_its_gesture() -> void:
	var rtl := RichTextLabel.new()
	rtl.scroll_active = true
	var holder := Control.new()
	holder.add_child(rtl)
	add_child(holder)
	auto_free(holder)
	OpenerCls.open_subtree(holder)
	assert_int(rtl.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)


# ── Half one: the drag reaches the scroll ───────────────────────────────────

func test_a_drag_started_on_a_button_scrolls_the_page() -> void:
	var r := _build(true)
	await _settle(r)
	assert_int(r.button.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)

	await _drag(r, r.button.get_global_rect().get_center(), -100.0)
	assert_int(r.scroll.scroll_vertical).override_failure_message(
		"opening the Button to PASS did not let the drag reach the ScrollContainer"
	).is_greater(0)
	assert_int(r.scroll_starts).override_failure_message(
		"scroll_started never fired, so the ScrollContainer did not treat this as a "
		+ "TOUCH drag — the signal is emitted only for a touch-drag of the content"
	).is_greater(0)


# ── Half two: and it does not press the button on the way ───────────────────
# This is the question the old `return  # Interactive controls must keep STOP` rule
# was protecting against, and the reason it is safe to override it.

func test_that_same_drag_does_not_press_the_button() -> void:
	var r := _build(true)
	await _settle(r)
	await _drag(r, r.button.get_global_rect().get_center(), -100.0)
	assert_int(r.presses).override_failure_message(
		"a touch-drag over a PASS-filtered Button PRESSED it (%d time(s)). Opening the "
		% r.presses
		+ "chrome would then have bought scrolling at the cost of firing whatever the "
		+ "button does — a far worse defect than the one it fixes"
	).is_equal(0)


func test_that_same_drag_does_not_toggle_a_checkbox() -> void:
	var r := _build(true)
	await _settle(r)
	await _drag(r, r.check.get_global_rect().get_center(), -100.0)
	assert_int(r.toggles).override_failure_message(
		"a touch-drag over a PASS-filtered CheckBox toggled it %d time(s)" % r.toggles
	).is_equal(0)
	assert_bool(r.check.button_pressed).is_false()


# ── Half three: a TAP still works ───────────────────────────────────────────
# Without these, "it scrolls now" could be hiding a list nobody can select from.

func test_a_tap_on_an_opened_button_still_presses_it() -> void:
	var r := _build(true)
	await _settle(r)
	await _tap(r, r.button.get_global_rect().get_center())
	assert_int(r.presses).override_failure_message(
		"the Button stopped responding to a tap after STOP -> PASS. PASS still delivers "
		+ "the event to the control FIRST; only what it does not handle propagates"
	).is_equal(1)


func test_a_tap_on_an_opened_checkbox_still_toggles_it() -> void:
	var r := _build(true)
	await _settle(r)
	await _tap(r, r.check.get_global_rect().get_center())
	assert_bool(r.check.button_pressed).override_failure_message(
		"the CheckBox stopped responding to a tap after STOP -> PASS"
	).is_true()
	assert_int(r.toggles).is_equal(1)


# ── The opener's own contract on these classes ──────────────────────────────

func test_the_opener_opens_the_widgets_the_old_base_rule_refused_to() -> void:
	# The old `_apply_pass_filter_recursive` returned on Button/CheckBox/OptionButton/
	# SpinBox/LinkButton — and, being a `return` rather than a skip, it also stopped
	# descending at the first ScrollContainer, so it never reached any of them anyway.
	var r := _build(true)
	await _settle(r)
	assert_int(r.button.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	assert_int(r.check.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	# ...and a second pass finds nothing left, so re-running after a rebuild is free.
	assert_int(OpenerCls.open_subtree(r.scroll)).is_equal(0)
