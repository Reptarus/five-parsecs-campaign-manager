extends GdUnitTestSuite

## The Trade/Explore reward-string predicates, and the popup flow they outlived.
##
## HISTORY: commit 83dd62493 (Apr 2 2026) replaced a serial "choice popup" queue
## with CrewTaskEventDialog's CHOICE_ITEM / GRENADE_COMBO event types. It removed
## the queue's producer (`_pending_choice_results.append`) and left EVERY consumer
## behind — `_show_next_choice_popup()`, `_on_choice_made()`, `_on_grenades_chosen()`,
## `_needs_player_input()` and two member vars — dead for five months.
##
## ⚠ It also did NOT reuse the predicates: `_classify_result()` re-inlined both as
## literals (`"Grenades" in s and ("Frakk" in s or "Dazzle" in s)`, `" OR " in s`).
## That duplication is WHY the helpers went dead. The 2026-09-10 cleanup therefore
## pointed the live classifier at them rather than deleting a second copy of each
## test — one test, one site.
##
## ⚠ The dead block held the ONLY reference to GrenadeCombinationPopup.gd, and
## that `preload` edge is what kept the file counted as "reachable from product"
## by lint_orphan_assets.py for five months. Reachability proves a file is LOADED,
## never that its API is USED.

const CrewTaskComponentClass = preload(
	"res://src/ui/screens/world/components/CrewTaskComponent.gd")

func _comp():
	var c = auto_free(CrewTaskComponentClass.new())
	add_child(c)
	return c

func _base() -> Dictionary:
	return {
		"crew_id": "c1", "crew_name": "Ila", "crew_member": {},
		"task_type": "Trade", "event_name": "Test", "effect_text": "",
		"table_result": {}, "result_ref": {"task_id": "trade"},
	}


# ── The predicates, which are now the single definition of each test ────────

func test_a_frakk_dazzle_string_is_a_grenade_combination() -> void:
	var c = _comp()
	assert_bool(c._is_grenade_combination("3 Frakk Grenades")).is_true()
	assert_bool(c._is_grenade_combination("2 Dazzle Grenades")).is_true()

func test_an_ordinary_item_is_not_a_grenade_combination() -> void:
	var c = _comp()
	assert_bool(c._is_grenade_combination("Combat Armor")).is_false()
	## "Grenades" alone is not enough — the picker exists for the Frakk/Dazzle
	## split specifically, so a generic grenade entry must not open one.
	assert_bool(c._is_grenade_combination("Grenades")).is_false()

func test_an_or_string_is_a_choice_item() -> void:
	var c = _comp()
	assert_bool(c._is_choice_item("Blade OR Hand Gun")).is_true()
	assert_bool(c._is_choice_item("Combat Armor")).is_false()

func test_choice_options_split_on_or_and_strip() -> void:
	var c = _comp()
	var opts: Array = c._parse_choice_options("Blade OR Hand Gun OR Shotgun")
	assert_int(opts.size()).is_equal(3)
	assert_str(str(opts[0])).is_equal("Blade")
	assert_str(str(opts[2])).is_equal("Shotgun")


# ── The live classifier must ROUTE through them, not re-inline them ─────────

func test_the_classifier_routes_a_grenade_string_to_the_picker() -> void:
	var c = _comp()
	var events: Array = c._classify_result(
		_base(), {"name": "Grenade haul", "items": ["3 Frakk Grenades"]}, {})
	assert_int(events.size()).is_equal(1)
	assert_int(int(events[0].get("type", -1))).is_equal(
		CrewTaskEventDialog.EventType.GRENADE_COMBO)

func test_the_classifier_routes_an_or_string_to_the_chooser() -> void:
	var c = _comp()
	var events: Array = c._classify_result(
		_base(), {"name": "Pick one", "items": ["Blade OR Hand Gun"]}, {})
	assert_int(events.size()).is_equal(1)
	assert_int(int(events[0].get("type", -1))).is_equal(
		CrewTaskEventDialog.EventType.CHOICE_ITEM)
	assert_array(events[0].get("choice_options", [])).contains(["Blade", "Hand Gun"])

func test_a_plain_item_takes_neither_branch() -> void:
	## The discriminating control: without it both cases above would still pass
	## with the classifier hardcoding one of the two event types.
	var c = _comp()
	var events: Array = c._classify_result(
		_base(), {"name": "Loot", "items": ["Combat Armor"]}, {})
	for e in events:
		var t: int = int(e.get("type", -1))
		assert_int(t).is_not_equal(CrewTaskEventDialog.EventType.GRENADE_COMBO)
		assert_int(t).is_not_equal(CrewTaskEventDialog.EventType.CHOICE_ITEM)


# ── The removed block must stay removed ────────────────────────────────────

func test_the_superseded_popup_flow_is_gone() -> void:
	## Regression guard. These were dead for five months behind a live-looking
	## preload; if any comes back, so has the duplicate flow.
	var c = _comp()
	for name in ["_show_next_choice_popup", "_on_choice_made", "_on_grenades_chosen",
			"_needs_player_input"]:
		assert_bool(c.has_method(name)).override_failure_message(
			"%s is back — the CrewTaskEventDialog event types supersede it" % name).is_false()

func test_the_grenade_popup_file_is_gone() -> void:
	## It was orphaned the moment the dead block went, by BOTH reference forms —
	## no `res://` path and no `uid://` (uid://dymgpwi2hfd1p), which the repo's
	## deletion protocol does not grep for by default.
	assert_bool(ResourceLoader.exists(
		"res://src/ui/components/dialogs/GrenadeCombinationPopup.gd")).is_false()

func test_the_predicates_the_classifier_needs_are_still_here() -> void:
	## The other half of the guard: the cleanup deleted a wrapper and kept the two
	## predicates plus the parser. Deleting those instead would break live
	## classification, so pin their survival explicitly.
	var c = _comp()
	for name in ["_is_grenade_combination", "_is_choice_item", "_parse_choice_options"]:
		assert_bool(c.has_method(name)).override_failure_message(
			"%s is LIVE — _classify_result() calls it" % name).is_true()
