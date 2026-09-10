extends GdUnitTestSuite

## Crew paging on CharacterDetailsScreen — a gesture that could not arrive, and the
## affordance that was rendering in the wrong place.
##
## ── THE DEFECT, three independent halves ─────────────────────────────────────
##
## **(a) The gesture was consumed before the handler.** Detection lived in
## `_unhandled_input()`, which by definition only receives events NO Control claimed.
## This screen's sheet sits in a `ScrollContainer`, and `ScrollContainer::gui_input`
## takes `InputEventScreenTouch` / `InputEventScreenDrag` for its own touch-drag
## scrolling and `accept_event()`s them. So on any touchscreen the swipe was eaten one
## layer above the handler, every time — and no mouse-filter change can help, because
## the ScrollContainer is exactly the control that wants the event. `_input()` runs
## before GUI delivery and is the only place the whole gesture is visible.
##
## ⚠ The KEYBOARD branch deliberately stays in `_unhandled_input()`. This screen edits
## the character name in a `LineEdit`, which consumes Left/Right for its caret; moving
## that branch to `_input()` would page the roster mid-word.
##
## **(b) The list was empty anyway.** `_crew_list` comes from the temp-data keys
## `crew_list_for_swipe` / `crew_index_for_swipe`, whose only producer is
## `CrewManagementScreen._store_crew_list_for_swipe()` — and CrewManagementScreen did
## not COMPILE until 2026-09-10 (a five-argument call to a four-argument
## `_create_character_card()`, a parse error, so the whole screen was dead in
## product). The feature was dead at both ends.
##
## **(c) The one affordance it had rendered on top of the header.**
## `_build_page_dots()` called `add_child()` on the screen ROOT — a bare `Control`,
## which does not lay out its children — so the dot row sat at (0,0) instead of under
## the sheet.
##
## ── DETECTION PROOF, one arm at a time ───────────────────────────────────────
##   * rename `_input` back to `_unhandled_input` (merging the branches)
##     -> `test_a_horizontal_fling_pages_the_roster` FAILS
##   * put the touch branch back into `_unhandled_input`
##     -> `test_unhandled_input_no_longer_claims_the_touch_branch` FAILS
##   * restore `add_child(_page_dots_container)` on the root
##     -> `test_the_pager_is_parented_into_the_page_column` FAILS
##   * delete the two `_build_page_arrow()` children
##     -> `test_the_arrows_page_the_roster` FAILS
##
## ⚠ gdUnit4 is FAIL-FAST — run one case alone (rename the others `func off_*`) when
## proving any of these, or the later cases never execute and their silence is not
## evidence.

const ScreenScene := preload(
	"res://src/ui/screens/character/CharacterDetailsScreen.tscn")

var _gsm: Node = null


func before_test() -> void:
	_gsm = Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager")


func after_test() -> void:
	if _gsm == null:
		return
	for key: String in ["selected_character", "source_crew_dict",
			"crew_list_for_swipe", "crew_index_for_swipe"]:
		_gsm.clear_temp_data(key)


func _crew(count: int) -> Array:
	var out: Array = []
	for i in count:
		var c := Character.new()
		c.character_name = "Crew %d" % (i + 1)
		out.append(c.to_dictionary())
	return out


## Build the screen the way its real navigator does.
## ⚠ `selected_character` must be a `Character`, NOT the raw crew Dictionary — both
## production producers normalise before navigating, and a Dictionary here makes the
## screen abort on `current_character.has_method(...)` (Dictionary has no
## `has_method`, so that is an invalid call which unwinds the function silently).
func _build_screen(crew_count: int) -> Control:
	var crew: Array = _crew(crew_count)
	var member := Character.new()
	member.from_dictionary(crew[0])
	_gsm.set_temp_data("selected_character", member)
	_gsm.set_temp_data("source_crew_dict", crew[0])
	_gsm.set_temp_data("crew_list_for_swipe", crew)
	_gsm.set_temp_data("crew_index_for_swipe", 0)

	var screen: Control = ScreenScene.instantiate()
	add_child(screen)
	auto_free(screen)
	await await_idle_frame()
	await await_idle_frame()
	return screen


func _touch(pressed: bool, at: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = at
	return e


# ═══════════════════════════════ (a) the gesture reaches a handler

func test_a_horizontal_fling_pages_the_roster() -> void:
	## ⭐ Delivered to `_input`, which is the ONLY entry point Godot offers before the
	## ScrollContainer claims the event. If this method is not defined, the call
	## errors — so the case pins the method's existence and its behaviour together.
	if _gsm == null:
		return
	var screen: Control = await _build_screen(3)
	assert_int(screen._current_index).is_equal(0)

	screen._input(_touch(true, Vector2(400, 500)))
	screen._input(_touch(false, Vector2(200, 508)))
	await await_idle_frame()

	assert_int(screen._current_index).override_failure_message(
		"A 200 px leftward fling did not advance the roster. In _unhandled_input this "
		+ "could never fire at all: ScrollContainer accept_event()s ScreenTouch for "
		+ "its own touch-drag scrolling, one layer above the handler."
	).is_equal(1)


func test_a_rightward_fling_pages_back_and_wraps() -> void:
	if _gsm == null:
		return
	var screen: Control = await _build_screen(3)

	screen._input(_touch(true, Vector2(200, 500)))
	screen._input(_touch(false, Vector2(400, 505)))
	await await_idle_frame()

	assert_int(screen._current_index).override_failure_message(
		"A rightward fling from index 0 should wrap to the last member."
	).is_equal(2)


func test_a_tap_does_not_page() -> void:
	## ⚠ THE DISCRIMINATING CASE. Nothing is consumed here — `emulate_mouse_from_touch`
	## pushes a SEPARATE mouse event for the same finger, so consuming the touch would
	## not suppress the click and would only leave the ScrollContainer holding a press
	## whose release it never saw. The thresholds ARE the discrimination, so they have
	## to be asserted from both sides.
	if _gsm == null:
		return
	var screen: Control = await _build_screen(3)

	screen._input(_touch(true, Vector2(400, 500)))
	screen._input(_touch(false, Vector2(396, 503)))
	await await_idle_frame()

	assert_int(screen._current_index).override_failure_message(
		"A 4 px tap paged the roster. Every button on this screen would be unusable."
	).is_equal(0)


func test_a_vertical_scroll_does_not_page() -> void:
	if _gsm == null:
		return
	var screen: Control = await _build_screen(3)

	# 120 px sideways is over the distance floor, but it is a diagonal drag whose
	# vertical travel dominates — that is a scroll, not a page turn.
	screen._input(_touch(true, Vector2(400, 900)))
	screen._input(_touch(false, Vector2(280, 300)))
	await await_idle_frame()

	assert_int(screen._current_index).override_failure_message(
		"A mostly-vertical drag paged the roster. Scrolling the sheet would flip crew."
	).is_equal(0)


func test_a_second_finger_cancels_the_gesture() -> void:
	## `emulate_mouse_from_touch` synthesises pointer 0 only, and a second pointer
	## means a pinch or a two-finger scroll — neither should page the roster.
	if _gsm == null:
		return
	var screen: Control = await _build_screen(3)

	screen._input(_touch(true, Vector2(400, 500)))
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.pressed = true
	second.position = Vector2(600, 500)
	screen._input(second)
	screen._input(_touch(false, Vector2(200, 505)))
	await await_idle_frame()

	assert_int(screen._current_index).override_failure_message(
		"A two-finger gesture paged the roster."
	).is_equal(0)


func test_unhandled_input_no_longer_claims_the_touch_branch() -> void:
	## ⚠ Pins the SPLIT, not just the new handler. Leaving a touch branch in
	## `_unhandled_input` as well would double-page on any screen where the event does
	## fall through — the T11-36 double-fire shape.
	if _gsm == null:
		return
	var screen: Control = await _build_screen(3)

	screen._unhandled_input(_touch(true, Vector2(400, 500)))
	screen._unhandled_input(_touch(false, Vector2(200, 505)))
	await await_idle_frame()

	assert_int(screen._current_index).override_failure_message(
		"_unhandled_input still acts on touch. One physical fling would then page "
		+ "twice wherever the event reaches both handlers."
	).is_equal(0)


func test_the_keyboard_branch_stays_in_unhandled_input() -> void:
	## A focused LineEdit must keep its arrow keys; `_unhandled_input` is what gives it
	## first refusal.
	if _gsm == null:
		return
	var screen: Control = await _build_screen(3)

	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	screen._unhandled_input(key)
	await await_idle_frame()

	assert_int(screen._current_index).is_equal(1)


# ═══════════════════════════════ (c) the affordance

func test_the_pager_is_parented_into_the_page_column() -> void:
	## The screen root is a bare `Control`; it does not lay out children, so the old
	## `add_child(self)` rendered the dot row at (0,0), over the header.
	if _gsm == null:
		return
	var screen: Control = await _build_screen(3)

	var column := screen.get_node_or_null("MarginContainer/PageColumn")
	assert_object(column).is_not_null()
	assert_object(screen._page_dots_row).override_failure_message(
		"No pager was built for a 3-member roster."
	).is_not_null()
	assert_object(screen._page_dots_row.get_parent()).override_failure_message(
		"The pager is not a child of PageColumn, so nothing positions it and it "
		+ "renders at the top-left corner on top of the header."
	).is_same(column)


func test_the_arrows_page_the_roster() -> void:
	## ⚠ The arrows are not decoration. A gesture nobody can see is indistinguishable
	## from one that does not work — which is how this sat broken without a report.
	if _gsm == null:
		return
	var screen: Control = await _build_screen(3)

	var buttons: Array = []
	for child in screen._page_dots_row.get_children():
		if child is Button:
			buttons.append(child)
	assert_int(buttons.size()).override_failure_message(
		"Expected a ‹ and a › button flanking the dots."
	).is_equal(2)

	(buttons[1] as Button).pressed.emit()
	await await_idle_frame()
	assert_int(screen._current_index).is_equal(1)

	(buttons[0] as Button).pressed.emit()
	await await_idle_frame()
	assert_int(screen._current_index).is_equal(0)


func test_a_single_member_roster_gets_no_pager() -> void:
	if _gsm == null:
		return
	var screen: Control = await _build_screen(1)
	assert_object(screen._page_dots_row).override_failure_message(
		"A one-member roster should have nothing to page between."
	).is_null()


## ---------------------------------------------------------------------------
## The hero-card button leak. FOUND ON DEPLOY #35, on glass: after one page turn
## the card carried TWO "Change Portrait" buttons, one clipped at its top edge.
##
## `populate_ui()` guarded with `hero_card.get_node_or_null("__ChangePortraitBtn")`,
## but `_setup_portrait_upload()` adds the button to `__HeroOverlay` — a CHILD of
## hero_card. `get_node_or_null(name)` is a DIRECT-CHILD lookup, not a search, so the
## guard asked for a grandchild by its bare name, got null every time, and was
## permanently false.
##
## ⚠ It cost nothing while `populate_ui()` ran once per screen entry. The crew pager
## made it re-entrant, and that is what turned a dormant defect into a visible one —
## the same "moved the writer, left the reader" shape that killed TacticsCampaignUnit.
##
## ⚠ COUNT THE OVERLAY'S BUTTON CHILDREN, NOT ANY NAME. When an explicit `name`
## collides with a sibling, Godot DISCARDS the requested name and falls back to its
## default `@<ClassName>@<id>` form -- the leaked copies are called `@Button@128`,
## `@Button@129`, and so on. Measured directly: with the guard reverted, four page
## turns give ["__ChangePortraitBtn", "__PrintSheetBtn", "@Button@128", "@Button@129",
## "@Button@210", ...]. A substring count for "ChangePortrait" therefore reports
## exactly ONE however many leak, and the first version of this test was green against
## a live leak for exactly that reason. Assert where the damage lands.
##
## DETECTION PROOF: restore the guards to `hero_card.get_node_or_null(...)`
##   -> test_paging_does_not_leak_hero_card_buttons FAILS (4 buttons, not 1).
## ---------------------------------------------------------------------------

## Every Button parented into the hero overlay, whatever it ended up being called.
## Returns -1 when the card or overlay is missing, so an absent subtree fails loudly
## rather than reading as "zero leaked".
func _count_overlay_buttons(screen: Control) -> int:
	if screen.hero_card == null:
		return -1
	var overlay: Node = screen.hero_card.get_node_or_null("__HeroOverlay")
	if overlay == null:
		return -1
	var found: int = 0
	for child: Node in overlay.get_children():
		if child is Button:
			found += 1
	return found


func test_paging_does_not_leak_hero_card_buttons() -> void:
	if _gsm == null:
		return
	var screen: Control = await _build_screen(4)

	## Change Portrait + Print Sheet, and nothing else.
	assert_int(_count_overlay_buttons(screen)).override_failure_message(
		"A freshly built screen should carry exactly two hero-card buttons."
	).is_equal(2)

	## Three page turns = three more populate_ui() calls. With the guard looking at
	## the wrong parent this reaches EIGHT -- measured.
	screen._navigate_crew(1)
	screen._navigate_crew(1)
	screen._navigate_crew(1)
	await await_idle_frame()

	assert_int(_count_overlay_buttons(screen)).override_failure_message(
		"Hero-card buttons leaked across page turns: populate_ui() re-created them "
		+ "because the existence guard looked on hero_card for a child of "
		+ "hero_card/__HeroOverlay, and a direct-child lookup for a grandchild is "
		+ "always null."
	).is_equal(2)


func test_the_overlay_itself_is_not_rebuilt_per_page() -> void:
	## _get_or_create_hero_overlay() is "get or create". If it ever started returning a
	## fresh Control the leak test above would pass vacuously - one button per new
	## overlay - while the card accumulated overlays instead of buttons.
	if _gsm == null:
		return
	var screen: Control = await _build_screen(4)
	var first: Node = screen.hero_card.get_node_or_null("__HeroOverlay")
	assert_object(first).is_not_null()
	screen._navigate_crew(1)
	await await_idle_frame()
	assert_object(screen.hero_card.get_node_or_null("__HeroOverlay")) 		.override_failure_message(
			"The hero overlay was replaced on a page turn, so counting its children "
			+ "is no longer evidence about leaked buttons.") 		.is_same(first)

