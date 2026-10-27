extends GdUnitTestSuite
## Phase 6 step 3, half B: no JSON number reaches a rendered label as a float.
##
## WHY THIS EXISTS. Godot's JSON parser returns EVERY number as a float, so a value read
## out of data/bug_hunt/*.json -- or out of a mission stamp that has been through a save
## round-trip -- is a float by the time code touches it. `%d` and `int()` both coerce;
## only `str()` and `%s` print it verbatim, and Godot prints a whole float as "8.0". The
## Sep 10 parity audit measured exactly that on this screen: the p.204 advancement table
## rendered "8.0" and "4.0", and an XP award rendered "1.0".
##
## Those three renders are gone -- but they went away as a SIDE EFFECT of Phase 5's
## presentation-only rewrite of BugHuntPostBattlePanel, which happens to use int() and %d
## throughout. No rule anywhere says it has to. That is precisely the state a regression
## guard exists for: correct today, pinned by nothing.
##
## WHY IT WALKS LABELS RATHER THAN ASSERTING THE PRODUCER.
## test_bug_hunt_dice_routing.gd::test_generated_stats_are_ints_not_json_floats already
## asserts the PRODUCER. The audit's finding was a LABEL. A producer assertion cannot
## catch a renderer that drops an int(), which is the entire failure mode here -- assert
## where the damage lands.
##
## WHY IT FEEDS FLOATS IN DELIBERATELY. A fixture built from int literals would pass
## against a renderer that prints its input verbatim, because there would be no float to
## print -- a detection proof is only as discriminating as its fixture. The stamp and the
## character dicts below carry 2.0 / 4.0 / 8.0 in three places a reloaded save genuinely
## carries them: both are UNTYPED containers, so nothing coerces them on the way in. The
## case asserts they are really floats before it asserts the labels are clean.
##
## PREMISE INSTRUMENTATION. A walk over an unpopulated panel finds no floats for the same
## reason it finds nothing at all -- the T11-01 shape, where a layout sweep stayed green
## for a month because it measured four EMPTY panes. So the advancement card, an XP cost
## line, the weighted-objective suffix and a step heading must all be present BEFORE any
## float assertion runs.
##
## HYGIENE. _process_post_battle() persists the scored result, and
## BugHuntCampaignCore.persist() under the runner reaches /root/GameState, writing
## user://saves/<id>.save AND rewriting user://settings.cfg's last_campaign -- the
## documented cross-suite bleed that leaks a BugHuntCampaignCore into every later test
## process.
##
## That restore used to be hand-rolled here and it was HALF a restore: it put the file
## back and left GameState.game_settings, the live dict on the autoload, holding the
## probe id -- so the next suite in the same process that called save_settings() wrote
## the probe id straight back out. Measured: after a 17-suite batch the save directory
## was byte-identical while settings.cfg read last_campaign="zz_bug_hunt_rendered_numbers_probe".
## SaveDirGuard restores the dict FIRST and the file second, for that reason.
##
## gdUnit4 v6.0.3.

const PostBattlePanel := preload("res://src/ui/screens/bug_hunt/panels/BugHuntPostBattlePanel.gd")
const CoreScript := preload("res://src/game/campaign/BugHuntCampaignCore.gd")
const CharGenScript := preload("res://src/core/character/BugHuntCharacterGeneration.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

const PROBE_ID := "zz_bug_hunt_rendered_numbers_probe"
const PROBE_SAVE := "user://saves/zz_bug_hunt_rendered_numbers_probe.save"

## Godot renders a whole float as "N.0". The negative lookahead keeps a genuine decimal
## out of the match, and anchoring the left side on a DIGIT keeps page cites out of it --
## "p.201" and "pp.185" both have a letter before the dot, not a digit.
## Written with [.] rather than a backslash escape on purpose: GDScript rejects unknown
## string escapes, and that is a PARSE ERROR, which gdUnit4 reports as "No test cases
## found" with exit 0 -- a suite that silently stops existing.
const FLOAT_PATTERN := "[0-9][.]0(?![0-9])"

var _dm: Node = null
var _gs: Node = null
var _saved_campaign: Variant = null
var _user_state: Dictionary = {}


func before_test() -> void:
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")
	# Without the autoload every queue_forced_result() below is a no-op, the post-battle
	# rolls land wherever the RNG puts them, and an unlucky Court Martial or casualty row
	# changes which cards render -- so the premise assertions would fail for a reason that
	# has nothing to do with floats.
	assert_object(_dm).override_failure_message(
		"/root/DiceManager did not resolve under the runner, so no roll below can be "
		+ "pinned and this case would measure a different screen on every run").is_not_null()
	_dm.clear_forced_results()

	_gs = get_tree().root.get_node_or_null("/root/GameState")
	if _gs != null:
		_saved_campaign = _gs.current_campaign

	# Covers settings.cfg, GameState.game_settings and any save file that appears --
	# see the HYGIENE paragraph above for why the file alone was not enough.
	_user_state = SaveDirGuard.snapshot()
	# A run aborted mid-case can leave a probe save behind, and load_from_file() falls
	# back to its .bak, so clear them before a case can read one.
	_remove_probe_saves()


func after_test() -> void:
	if _dm != null:
		# The queue lives on the AUTOLOAD, not on this suite: an unconsumed forced value
		# rides /root/DiceManager into the next suite in the same process.
		_dm.clear_forced_results()
	if _gs != null:
		_gs.current_campaign = _saved_campaign
	_remove_probe_saves()
	SaveDirGuard.restore(_user_state)
	_user_state = {}


func _remove_probe_saves() -> void:
	# SaveFileWriter.write_text_atomic() writes path + ".tmp" and keeps path + ".bak".
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = PROBE_SAVE + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


# ──────────────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────────────

func _make_core() -> Resource:
	var core: Resource = CoreScript.new()
	core.campaign_name = "Rendered numbers probe"
	# Fixed, so the save persist() writes has a name this suite can remove.
	# get_campaign_id() otherwise mints one from the clock.
	core.campaign_id = PROBE_ID
	var squad: Dictionary = CharGenScript.new().generate_squad(["Alpha", "Bravo", "Charlie"])
	core.initialize_squad(squad.get("main_characters", []), squad.get("grunts", []))
	core.start_campaign()
	return core


func _participant_ids(core: Resource) -> Array:
	var ids: Array = []
	for mc in core.main_characters:
		if mc is Dictionary:
			ids.append(str((mc as Dictionary).get("id", "")))
	return ids


## Pin every roll this case does not care about, so a red case has exactly one cause.
## Matching is a case-insensitive SUBSTRING, so the bare table name reaches
## "Bug Hunt Muster Out: Alpha" and its siblings.
func _quiet() -> void:
	_dm.queue_forced_result("Bug Hunt Operational Progress", 50)
	for _i in range(4):
		_dm.queue_forced_result("Bug Hunt Military Life", 33)
		_dm.queue_forced_result("Bug Hunt Muster Out", 2)
		_dm.queue_forced_result("Bug Hunt Reputation", 1)


# ──────────────────────────────────────────────────────────────────────────────
# The guard
# ──────────────────────────────────────────────────────────────────────────────

func test_no_rendered_label_shows_a_json_float() -> void:
	var core: Resource = _make_core()
	if _gs != null:
		_gs.current_campaign = core

	# XP high enough that the cheapest p.204 advancement (speed / savvy, 6 XP) is
	# affordable, so the numeric card renders at all. Written as a FLOAT because that is
	# what a reloaded save carries: main_characters is an untyped Array of untyped
	# Dictionaries, so nothing on the way in coerces it.
	for mc in core.main_characters:
		if mc is Dictionary:
			(mc as Dictionary)["xp"] = 8.0

	var ids: Array = _participant_ids(core)
	assert_int(ids.size()).override_failure_message(
		"the generator must produce three main characters for the debrief to have "
		+ "participants; with none, no XP is awarded and no advancement card renders"
		).is_equal(3)

	# The mission as BugHuntMissionPanel stamps it, after a save round-trip. `weight` and
	# `signals_total` are the two stamp numbers that reach a label, and `priority` is read
	# by the XP step -- all three float here for the same reason `xp` is.
	core.current_mission = {
		"name": "Rendered numbers probe mission",
		"priority": 4.0,
		"use_signals": true,
		"signals_total": 4.0,
		"participant_ids": ids.duplicate(),
		"objectives": [
			{"type": {"name": "Secure the beacon"}, "rating": "vital", "weight": 2.0},
			{"type": {"name": "Sweep the nest"}, "rating": "normal", "weight": 1.0},
		],
	}
	# Instrument the fixture's own premise: if these coerced to int on the way in, the
	# case would be asserting that a renderer handed only ints prints no floats, which is
	# true of every renderer including a broken one.
	var stamped_objectives: Array = core.current_mission["objectives"]
	assert_int(typeof((stamped_objectives[0] as Dictionary)["weight"])).override_failure_message(
		"the stamped objective weight must still be a FLOAT here, or this case cannot "
		+ "discriminate between a renderer that coerces and one that does not"
		).is_equal(TYPE_FLOAT)
	assert_int(typeof(core.current_mission["signals_total"])).override_failure_message(
		"signals_total must still be a FLOAT here for the same reason").is_equal(TYPE_FLOAT)

	_quiet()

	var panel: Control = auto_free(PostBattlePanel.new())
	add_child(panel)
	panel.set_campaign(core)
	panel.set_battle_results({
		"victory": true,
		"participant_ids": ids.duplicate(),
		"casualty_ids": [],
	})
	panel.refresh()

	# Complete the Vital objective. This is what a player does, and it matters twice: a
	# weighted objective is what renders the "counts as 2" suffix the premise checks, and
	# a non-zero objective count is what skips the p.201 Court Martial roll, so the case
	# does not depend on a D6 it has not pinned.
	var checks: Array = panel._debrief_objective_checks
	assert_int(checks.size()).override_failure_message(
		"the debrief must offer one checkbox per stamped objective").is_equal(2)
	(checks[0] as CheckBox).button_pressed = true

	panel._process_post_battle()

	var texts: Array = _all_text(panel)

	# ── premise: the numeric surfaces this case exists to police actually rendered ──
	assert_bool(_any_contains(texts, "XP available")).override_failure_message(
		"the p.204 advancement card did not render, so the float assertion below would "
		+ "pass over a screen that shows no advancement costs at all. Rendered text was:\n"
		+ str(texts)).is_true()
	assert_bool(_any_contains(texts, " XP)")).override_failure_message(
		"no advancement OPTION rendered, so the xp_cost / max_value numbers the audit "
		+ "measured as \"8.0\" and \"4.0\" were never printed. Rendered text was:\n"
		+ str(texts)).is_true()
	assert_bool(_any_contains(texts, "counts as 2")).override_failure_message(
		"the weighted-objective suffix did not render, so the FLOAT weight fed in above "
		+ "never reached a label. Rendered text was:\n" + str(texts)).is_true()
	assert_bool(_any_contains(texts, "Signals investigated (of 4)")).override_failure_message(
		"the signals row did not render, so the FLOAT signals_total never reached a "
		+ "label. Rendered text was:\n" + str(texts)).is_true()
	assert_bool(_any_contains(texts, "Step ")).override_failure_message(
		"no resolver step rendered, so the receipt is empty and every roll value, award "
		+ "line and effect line is missing. Rendered text was:\n" + str(texts)).is_true()

	# ── the guard ──
	var rx := RegEx.new()
	assert_int(rx.compile(FLOAT_PATTERN)).override_failure_message(
		"the float pattern did not compile, so the scan below matches nothing and passes "
		+ "vacuously").is_equal(OK)
	var offenders: Array = []
	for t in texts:
		var s: String = str(t)
		if rx.search(s) != null:
			offenders.append(s)

	assert_array(offenders).override_failure_message(
		"A JSON number reached a rendered label as a float. Godot's JSON parser returns "
		+ "every number as a float, so a data or stamp value printed with str() or %s "
		+ "shows as \"8.0\" instead of \"8\" -- measured on this exact screen by the "
		+ "Sep 10 parity audit (advancement xp_cost and max_value, and an XP award). Use "
		+ "int() and %d, or DisplayText.number(). Offending labels:\n"
		+ "\n".join(PackedStringArray(offenders))).is_empty()


# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

## Every string a player can read on this screen. LineEdit is included because a SpinBox
## renders its value through one, and a SpinBox is a float control by construction.
func _all_text(node: Node, out: Array = []) -> Array:
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	elif node is LineEdit:
		out.append((node as LineEdit).text)
	for c in node.get_children():
		_all_text(c, out)
	return out


func _any_contains(texts: Array, needle: String) -> bool:
	for t in texts:
		if str(t).contains(needle):
			return true
	return false
