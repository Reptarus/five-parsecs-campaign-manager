extends GdUnitTestSuite
## QA scenario fixtures (Aug 8 2026, tablet sprint).
##
## These tests exist so the fixtures in `data/qa_scenarios/` and the app agree.
## The whole point of committing scenarios as data was that device QA and CI load
## the BYTE-IDENTICAL files; if that guarantee is not tested, they drift and the
## fixture silently becomes a no-op on device where nobody is watching a log.
##
## The important assertions are the two that catch the project's most common
## defect shape — a key with no consumer:
##   * every counter key a fixture writes must map to a real GameStateManager
##     setter (test_every_counter_key_has_a_live_setter)
##   * every DLC id a fixture names must exist in DLCManager.DLC_IDS
## Both fail on a typo, which would otherwise present as "the scenario did
## nothing" on a tablet, hours later.

const QAScenarioLoader := preload("res://src/core/qa/QAScenarioLoader.gd")
const FiveParsecsCampaignCore := preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const GameStateManagerScript := preload("res://src/core/managers/GameStateManager.gd")
const DLCManagerScript := preload("res://src/core/systems/DLCManager.gd")


func _make_campaign(crew_count: int = 6) -> Resource:
	var c = FiveParsecsCampaignCore.new()
	var members: Array = []
	for i in range(crew_count):
		members.append({
			"character_id": "qa_char_%d" % i,
			"id": "qa_char_%d" % i,
			"character_name": "QA Crew %d" % i,
			"name": "QA Crew %d" % i,
			"is_captain": i == 0,
			"in_sick_bay": false,
			"recovery_turns": 0,
			"experience": 0,
			"status_effects": [],
			"equipment": [],
		})
	c.crew_data = {"members": members}
	return c


# ============================================================================
# Fixture integrity
# ============================================================================

func test_fixtures_exist() -> void:
	var ids: Array = QAScenarioLoader.list_ids()
	assert_int(ids.size()).is_greater(0)


func test_every_fixture_parses_and_is_self_describing() -> void:
	## A fixture with no `unlocks` is a trap: a tester applies it, cannot tell what
	## it was supposed to reach, and reports against the wrong book pages.
	for id in QAScenarioLoader.list_ids():
		var s: Dictionary = QAScenarioLoader.load_scenario(id)
		assert_bool(s.is_empty()).override_failure_message(
			"Fixture '%s' failed to parse as a JSON object." % id).is_false()
		assert_str(str(s.get("name", ""))).override_failure_message(
			"Fixture '%s' has no name." % id).is_not_empty()
		assert_str(str(s.get("summary", ""))).override_failure_message(
			"Fixture '%s' has no summary." % id).is_not_empty()
		assert_array(s.get("unlocks", [])).override_failure_message(
			"Fixture '%s' lists no unlocks — say which book rules it reaches." % id
			).is_not_empty()


func test_unknown_scenario_id_returns_empty_not_a_silent_noop() -> void:
	assert_bool(QAScenarioLoader.load_scenario("no_such_scenario").is_empty()).is_true()


# ============================================================================
# Key/consumer agreement — the guards that catch a typo before the tablet does
# ============================================================================

func test_every_counter_key_has_a_live_setter() -> void:
	var gsm = GameStateManagerScript.new()
	add_child(gsm)
	for id in QAScenarioLoader.list_ids():
		var block: Dictionary = QAScenarioLoader.load_scenario(id).get("campaign", {})
		for key in block:
			assert_bool(QAScenarioLoader.COUNTER_SETTERS.has(key)).override_failure_message(
				"Fixture '%s' sets counter '%s', which QAScenarioLoader cannot route."
				% [id, key]).is_true()
			var method: String = QAScenarioLoader.COUNTER_SETTERS[key]
			assert_bool(gsm.has_method(method)).override_failure_message(
				"Fixture '%s' key '%s' routes to GameStateManager.%s(), which does not exist."
				% [id, key, method]).is_true()
	gsm.queue_free()


func test_every_dlc_id_named_by_a_fixture_exists() -> void:
	for id in QAScenarioLoader.list_ids():
		var block: Dictionary = QAScenarioLoader.load_scenario(id).get("dlc", {})
		for dlc_id in block.get("own", []):
			assert_bool(DLCManagerScript.DLC_IDS.has(str(dlc_id))).override_failure_message(
				"Fixture '%s' owns DLC '%s', which is not in DLCManager.DLC_IDS."
				% [id, dlc_id]).is_true()


func test_every_crew_field_a_fixture_writes_is_allowed() -> void:
	## The allow-list is deliberate: an open merge would let a fixture write
	## `origin` as an int or drop `character_id`, both documented ways to destroy a
	## crew member silently.
	for id in QAScenarioLoader.list_ids():
		for patch in QAScenarioLoader.load_scenario(id).get("crew", []):
			if not (patch is Dictionary):
				continue
			for field in patch:
				if field == "index":
					continue
				assert_bool(QAScenarioLoader.CREW_FIELDS.has(field)
					).override_failure_message(
					"Fixture '%s' patches crew field '%s', which is not allow-listed."
					% [id, field]).is_true()


# ============================================================================
# apply() actually mutates the campaign — assert where the damage lands
# ============================================================================

func test_apply_writes_crew_state_onto_the_campaign() -> void:
	var campaign = _make_campaign()
	var scenario: Dictionary = {
		"crew": [
			{"index": 1, "in_sick_bay": true, "recovery_turns": 2},
			{"index": 4, "experience": 11},
		]
	}
	var receipt: Dictionary = QAScenarioLoader.apply(scenario, campaign)

	var members: Array = campaign.get_crew_members()
	assert_bool(bool(members[1].get("in_sick_bay", false))).is_true()
	assert_int(int(members[1].get("recovery_turns", 0))).is_equal(2)
	assert_int(int(members[4].get("experience", 0))).is_equal(11)
	assert_array(receipt.get("warnings", [])).is_empty()
	assert_int(receipt.get("applied", []).size()).is_equal(2)


func test_apply_reports_an_out_of_range_crew_index_instead_of_skipping_silently() -> void:
	var campaign = _make_campaign(3)
	var receipt: Dictionary = QAScenarioLoader.apply(
		{"crew": [{"index": 9, "experience": 5}]}, campaign)
	assert_array(receipt.get("applied", [])).is_empty()
	assert_int(receipt.get("warnings", []).size()).is_equal(1)


func test_apply_without_a_campaign_warns_and_does_not_crash() -> void:
	var receipt: Dictionary = QAScenarioLoader.apply({"campaign": {"credits": 10}}, null)
	assert_array(receipt.get("applied", [])).is_empty()
	assert_int(receipt.get("warnings", []).size()).is_greater(0)


func test_apply_of_an_empty_scenario_is_reported_not_silently_successful() -> void:
	var campaign = _make_campaign()
	var receipt: Dictionary = QAScenarioLoader.apply({}, campaign)
	assert_int(receipt.get("warnings", []).size()).is_greater(0)


func test_salvage_units_go_through_the_ledger_as_an_absolute() -> void:
	## The fixture states an ABSOLUTE; SalvageLedger's API takes a DELTA. Applying
	## the same scenario twice must therefore be idempotent, not additive.
	var campaign = _make_campaign()
	var scenario: Dictionary = {"compendium_progress": {"salvage_units": 30}}
	QAScenarioLoader.apply(scenario, campaign)
	QAScenarioLoader.apply(scenario, campaign)
	var ledger = load("res://src/core/campaign/SalvageLedger.gd")
	assert_int(ledger.get_units(campaign)).is_equal(30)


func test_red_zone_progress_lands_on_the_campaign_fields() -> void:
	var campaign = _make_campaign()
	QAScenarioLoader.apply({"compendium_progress": {
		"red_zone_licensed": true, "red_zone_turns_completed": 10}}, campaign)
	assert_bool(bool(campaign.red_zone_licensed)).is_true()
	assert_int(int(campaign.red_zone_turns_completed)).is_equal(10)


# ============================================================================
# Load-time integrity — the trap that blanked the dashboard on device
# ============================================================================

func test_dialog_script_and_its_static_factory_actually_load() -> void:
	## Aug 8 2026: `var dlg := new()` inside QAScenarioDialog's static open() is the
	## Godot 4.6 "Identifier not found" trap. It fails at SCRIPT-LOAD time, so every
	## file that preloads the dialog dies with it — CampaignDashboard did, and the
	## device showed a blank screen with the process alive and logcat clean.
	##
	## `--headless --import` cannot see this (the script is never loaded) and neither
	## can a fixture test, so it needs its own case: load the script AND actually run
	## the static factory.
	var script = load("res://src/ui/screens/dev/QAScenarioDialog.gd")
	assert_object(script).override_failure_message(
		"QAScenarioDialog.gd failed to load — anything preloading it dies too.").is_not_null()

	var host := Node.new()
	add_child(host)
	var campaign = _make_campaign()
	var dlg = script.open(host, campaign)
	assert_object(dlg).override_failure_message(
		"QAScenarioDialog.open() returned null — the static factory is broken."
		).is_not_null()
	assert_bool(dlg is Window).is_true()
	dlg.free()
	host.free()


func test_dashboard_script_loads_with_the_dialog_preloaded() -> void:
	## CampaignDashboard preloads QAScenarioDialog, so a load failure in the dialog
	## takes the whole dashboard down.
	##
	## ⚠ THIS GUARD IS WEAK AND THE COMMENT SAYS SO ON PURPOSE. Measured Aug 8 2026
	## by re-introducing the dialog's TEXT_MUTED parse error: BOTH `is_not_null()`
	## and `can_instantiate()` on the dashboard script still returned true. Godot
	## does not propagate a failed const preload into either signal, so neither
	## assertion can observe the damage.
	##
	## It is kept only as a coarse smoke check. The assertion that actually catches
	## a broken preload is the one above, which RUNS the dialog's static factory —
	## see [[reference_a_green_test_can_detect_nothing]]: assert where the damage
	## lands, and do not trust a guard you have not tried to break.
	var dash = load("res://src/ui/screens/campaign/CampaignDashboard.gd")
	assert_object(dash).is_not_null()
	assert_bool(dash.can_instantiate()).is_true()


func test_endgame_fixture_reaches_the_black_job_gate() -> void:
	## Core Rules p.150: a Black Job needs a licence AND 10 completed Red Zone
	## turns. This asserts the shipped fixture really clears that bar rather than
	## just claiming to in its `unlocks` list.
	var campaign = _make_campaign()
	var s: Dictionary = QAScenarioLoader.load_scenario("endgame_and_failure")
	assert_bool(s.is_empty()).is_false()
	QAScenarioLoader.apply(s, campaign)
	assert_bool(bool(campaign.red_zone_licensed)).is_true()
	assert_int(int(campaign.red_zone_turns_completed)).is_greater_equal(10)


func test_the_forced_roll_section_is_actually_built() -> void:
	## The factory case above proves the dialog OPENS. It cannot prove the UI got
	## built: a runtime error inside _build_forced_roll_section() aborts _build_ui()
	## and open() still hands back a non-null Window, so is_not_null() stays green
	## over a dialog missing half its controls. Assert on the control itself.
	##
	## The section is what makes T9-47 / T9-48 / T9-51 reachable on device at all
	## (docs/qa/PICKUP_2026-08-14.md section 3) - if it silently vanishes, the next
	## device run quietly loses the only tool that reaches those rows.
	var script = load("res://src/ui/screens/dev/QAScenarioDialog.gd")
	assert_object(script).is_not_null()

	var host := Node.new()
	add_child(host)
	var dlg = script.open(host, _make_campaign())
	assert_object(dlg).is_not_null()

	var picker: OptionButton = _first_option_button(dlg)
	assert_object(picker).override_failure_message(
		"forced-roll picker missing - _build_ui() aborted before building it"
		).is_not_null()
	assert_int(picker.item_count).override_failure_message(
		"picker built but empty - FORCEABLE_ROLLS did not populate it"
		).is_equal(dlg.FORCEABLE_ROLLS.size())

	# Every entry must name a die the seam can actually satisfy, and a target value
	# inside it. A typo here would hand QA a value that is discarded at roll time,
	# and the tester would see a random roll and think the seam is broken.
	for entry: Dictionary in dlg.FORCEABLE_ROLLS:
		var sides: int = int(entry["sides"])
		var target: int = int(entry["target"])
		assert_bool(sides == 6 or sides == 10 or sides == 100).override_failure_message(
			"%s declares D%d, which DiceManager has no hook for" % [
				str(entry["key"]), sides]).is_true()
		assert_int(target).override_failure_message(
			"%s target %d is outside its own D%d" % [
				str(entry["key"]), target, sides]).is_between(1, sides)

	dlg.free()
	host.free()


## First OptionButton anywhere under `node`, or null.
func _first_option_button(node: Node) -> OptionButton:
	for child in node.get_children():
		if child is OptionButton:
			return child
		var found: OptionButton = _first_option_button(child)
		if found != null:
			return found
	return null
