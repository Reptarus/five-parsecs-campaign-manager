extends GdUnitTestSuite
## Two small verified defects from the Sep 2026 page walk.
##
## 1. SHIP DEBT FALLBACK. `ShipPanel._create_ship_from_type_id()` fell back to
##    `randi_range(0, 3)` when a ship type id did not resolve. That matches NO
##    ROW of the Core Rules p.31 Ship Table — every entry in data/ships.json
##    carries a `debt_base` of 10 or more plus 1D6 — so a crew that took the
##    fallback started essentially debt-free, which quietly removes the p.76 debt
##    interest and the p.76 seizure rules from the whole campaign. An invented
##    number is the project's oldest documented failure mode.
##
## 2. ONBOARDING FLAG. `MainMenu._on_onboard_existing_pressed()` set
##    `temp_data["onboarding_mode"]` and THEN called `_start_new_campaign()`,
##    whose first act is `GameStateManager.start_new_campaign()` →
##    `clear_all_temp_data()`. The flag was erased microseconds after it was
##    written, so the two consumers (`CampaignCreationUI:427` and
##    `CampaignEditorScreen:88`) could never see it and "Onboard Existing Game"
##    behaved exactly like "New Campaign".
##
##    Both halves existed and were correct — the WRITE was simply undone before
##    the READ. That is the same invisibility as a consumer with no producer, and
##    no census finds either.
##
## gdUnit4 v6.0.3 compatible.

const SHIP_PANEL_SRC := "res://src/ui/screens/campaign/panels/ShipPanel.gd"
const MAIN_MENU_SRC := "res://src/ui/screens/mainmenu/MainMenu.gd"
const SHIPS_DB := "res://data/ships.json"


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot read %s" % path).is_not_null()
	var text: String = f.get_as_text()
	f.close()
	return text


# ── Ship debt (Core Rules p.31) ──────────────────────────────────────────

func test_every_ship_in_the_table_carries_a_real_debt() -> void:
	# The floor the fallback must respect. If any row legitimately had a debt
	# under 4 this test would say so rather than letting the assumption stand.
	var parsed: Variant = JSON.parse_string(_read(SHIPS_DB))
	assert_bool(parsed is Dictionary).is_true()
	var types: Array = (parsed as Dictionary).get("ship_types", [])
	assert_array(types).is_not_empty()
	for entry in types:
		if not (entry is Dictionary):
			continue
		var base: int = int(entry.get("debt_base", entry.get("debt_min", 0)))
		assert_int(base).override_failure_message(
			"'%s' has a debt base of %d; the p.31 table has no row that low"
			% [str(entry.get("name", "?")), base]
		).is_greater(9)


func test_the_worn_freighter_fallback_is_not_invented() -> void:
	# p.31 Worn Freighter: debt_base 20 + 1D6. The fallback now resolves that
	# from the same file the main path reads, so it cannot drift from the table.
	var src: String = _read(SHIP_PANEL_SRC)
	assert_bool(src.contains("ship_data.debt = randi_range(0, 3)")).override_failure_message(
		"the invented 0-3 credit fallback debt is back — no p.31 row is that low"
	).is_false()
	assert_str(src).contains("func _worn_freighter_debt()")
	assert_str(src).override_failure_message(
		"the fallback must read the ships table rather than restate its numbers"
	).contains('str(entry.get("name", "")) == "Worn Freighter"')


# ── The onboarding flag (order of operations) ────────────────────────────

func test_the_onboarding_flag_is_set_after_the_temp_data_clear() -> void:
	# Order IS the fix. Written before `_start_new_campaign()`, the flag is wiped
	# by `clear_all_temp_data()` before either consumer can read it.
	var src: String = _read(MAIN_MENU_SRC)
	var start: int = src.find("func _on_onboard_existing_pressed()")
	assert_int(start).override_failure_message(
		"the Onboard Existing Game handler is gone").is_greater(-1)
	var after: int = src.find("\nfunc ", start + 10)
	var body: String = src.substr(start, after - start)

	var flag_at: int = body.find('set_temp_data("onboarding_mode"')
	var start_at: int = body.find("_start_new_campaign()")
	assert_int(flag_at).is_greater(-1)
	assert_int(start_at).is_greater(-1)
	assert_bool(start_at < flag_at).override_failure_message(
		"the onboarding flag is still written BEFORE _start_new_campaign(), whose"
		+ " first act clears all temp data — so the flag never survives to its"
		+ " readers and Onboard Existing Game silently starts a normal campaign"
	).is_true()


func test_the_clear_that_caused_it_is_still_there() -> void:
	# The bug is an ORDERING one, not a stray clear: wiping temp data at the start
	# of a new campaign is correct and deliberate (it stops Battle Simulator and
	# Bug Hunt state leaking in). This case exists so a future reader does not
	# "fix" the ordering by deleting the clear instead.
	var gsm_src: String = _read("res://src/core/managers/GameStateManager.gd")
	var start: int = gsm_src.find("func start_new_campaign()")
	assert_int(start).is_greater(-1)
	var body: String = gsm_src.substr(start, 500)
	assert_str(body).override_failure_message(
		"start_new_campaign() no longer clears temp data; that clear is"
		+ " deliberate and stops other gamemodes leaking state into creation"
	).contains("clear_all_temp_data()")


func test_both_onboarding_consumers_still_read_the_flag() -> void:
	# A flag with no reader is as dead as a reader with no flag.
	assert_str(_read("res://src/ui/screens/campaign/CampaignCreationUI.gd")) \
		.contains('get_temp_data("onboarding_mode"')
	assert_str(_read("res://src/ui/screens/campaign/CampaignEditorScreen.gd")) \
		.contains('get_temp_data("onboarding_mode"')
