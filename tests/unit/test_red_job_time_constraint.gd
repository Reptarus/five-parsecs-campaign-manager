extends GdUnitTestSuite
## Red Job Time Constraint — Core Rules p.149, verbatim:
## "All Red Jobs are fought under a time constraint. AT THE END OF ROUND 6, roll
## 1D6 on the table below."
##
## `RedZoneSystem.roll_time_constraint()` was written, correct, and had ZERO
## callers, so a Red Zone battle simply ran to its natural end: no reinforcement
## waves, no escalating Count Down clock, no 'Evac now!'.
##
## ⚠ THE TRAP THIS ROW CARRIED. There are TWO `roll_time_constraint()` functions
## on two unrelated classes. The one with a live caller is
## `compendium_missions_expanded.gd`'s, reached from JobOfferComponent for Expanded
## Missions — a completely different table. Grepping the NAME finds a live call and
## proves nothing about the Red Job rule. This suite asserts on the RED ZONE data
## specifically.
##
## Unlike the p.149 Threat Condition, this one cannot be stamped at mission
## acceptance: the book fixes it to a ROUND, so it needs a round-loop hook.
##
## gdUnit4 v6.0.3 compatible.

const RedZoneRef := preload("res://src/core/mission/RedZoneSystem.gd")
const FlowGuideRef := preload("res://src/core/battle/BattleFlowGuide.gd")
const TBUI_SRC := "res://src/ui/screens/battle/TacticalBattleUI.gd"


func _src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var t: String = f.get_as_text()
	f.close()
	return t


func _code_only(path: String) -> String:
	var out: PackedStringArray = []
	for line: String in _src(path).split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)


func _rows() -> Array:
	var f := FileAccess.open("res://data/red_zone_jobs.json", FileAccess.READ)
	assert_object(f).is_not_null()
	var json := JSON.new()
	assert_int(json.parse(f.get_as_text())).is_equal(OK)
	f.close()
	var root: Dictionary = json.data.get("red_zone_jobs", json.data)
	return root.get("time_constraints", [])


# ── 1. The p.149 table itself ──────────────────────────────────────────────

func test_the_table_is_a_d6_covering_one_to_six_exactly_once() -> void:
	var rows: Array = _rows()
	assert_int(rows.size()).override_failure_message(
		"p.149 prints six rows").is_equal(6)
	var seen: Array[int] = []
	for row: Variant in rows:
		seen.append(int((row as Dictionary).get("roll", 0)))
	seen.sort()
	assert_array(seen).is_equal([1, 2, 3, 4, 5, 6])


func test_the_row_names_and_effects_match_the_book() -> void:
	var expected := {
		1: "none",
		2: "reinforcements",
		3: "significant_reinforcements",
		4: "countdown",
		5: "evac_now",
		6: "elite_reinforcements",
	}
	for row: Variant in _rows():
		var r: int = int((row as Dictionary).get("roll", 0))
		assert_str(str((row as Dictionary).get("effect", ""))) \
			.override_failure_message("p.149 roll %d effect" % r) \
			.is_equal(str(expected[r]))


## The instruction TEXT is the product in a tabletop companion, so a dropped
## clause is a dropped rule. Three were missing.
func test_the_instructions_carry_the_clauses_the_book_prints() -> void:
	var by_roll := {}
	for row: Variant in _rows():
		by_roll[int((row as Dictionary).get("roll", 0))] = str(
			(row as Dictionary).get("description", ""))

	# p.149 rolls 2 and 3: "Pick the entry point closest to a crew figure."
	for r: int in [2, 3]:
		assert_str(str(by_roll[r]).to_lower()).override_failure_message(
			"p.149 roll %d drops 'Pick the entry point closest to a crew figure'"
			% r).contains("closest to a crew figure")

	# p.149 roll 4: "If the clock runs out before the opposing side has been
	# driven off, the battle ends and you do not Hold the Field."
	assert_str(str(by_roll[4]).to_lower()).override_failure_message(
		"p.149 roll 4 drops the Hold the Field consequence, which is the half"
		+ " with real campaign effects (it gates the p.119 Rival removal roll,"
		+ " p.120 Battlefield Finds and p.121 Loot)").contains("hold the field")

	# p.149 roll 5 already carried it; pin it so it cannot be lost.
	assert_str(str(by_roll[5]).to_lower()).contains("hold the field")


func test_the_two_field_denying_rows_are_flagged_for_code() -> void:
	for row: Variant in _rows():
		var r: int = int((row as Dictionary).get("roll", 0))
		var denies: bool = bool((row as Dictionary).get("denies_hold_field", false))
		if r == 4 or r == 5:
			assert_bool(denies).override_failure_message(
				"p.149 roll %d says 'you do not Hold the Field'" % r).is_true()
		else:
			assert_bool(denies).override_failure_message(
				"p.149 roll %d does NOT take the field away" % r).is_false()


func test_every_roll_resolves_to_a_named_row() -> void:
	# A D6 that can return {"name": "None"} for a real roll would silently skip
	# the constraint — the same silent-default shape this audit exists to remove.
	for _i in range(300):
		var tc: Dictionary = RedZoneRef.roll_time_constraint()
		assert_bool(tc.is_empty()).is_false()
		assert_int(int(tc.get("roll", 0))).is_between(1, 6)
		assert_str(str(tc.get("effect", ""))).override_failure_message(
			"roll %d fell through to the unnamed default" % int(tc.get("roll", 0))
		).is_not_equal("")


# ── 2. The round-loop hook ─────────────────────────────────────────────────

func test_the_constraint_round_is_six() -> void:
	assert_int(FlowGuideRef.RED_JOB_CONSTRAINT_ROUND).override_failure_message(
		"p.149: 'At the end of Round 6, roll 1D6'").is_equal(6)


func test_nothing_fires_outside_a_red_job() -> void:
	assert_array(FlowGuideRef.build_red_job_round_prompts(9, false, {})) \
		.override_failure_message(
			"the Time Constraint leaked into an ordinary battle").is_empty()


func test_the_clock_is_announced_before_it_lands() -> void:
	# A time constraint the player only learns about after it fires is not a
	# constraint they can play around.
	var p: Array = FlowGuideRef.build_red_job_round_prompts(4, true, {})
	assert_int(p.size()).override_failure_message(
		"no warning before Round 6").is_equal(1)
	assert_str(str((p[0] as Dictionary).get("id", ""))) \
		.is_equal("red_job_time_constraint_pending")


func test_the_rolled_result_is_restated_every_round() -> void:
	# A reinforcement wave the player is meant to place is not a one-time notice.
	var state := {
		"rolled": true, "roll": 2, "name": "Reinforcements",
		"description": "3 additional enemy arrive...", "effect": "reinforcements",
	}
	for round_num: int in [6, 7, 12]:
		var p: Array = FlowGuideRef.build_red_job_round_prompts(round_num, true, state)
		assert_int(p.size()).override_failure_message(
			"round %d dropped the standing instruction" % round_num).is_equal(1)
		assert_str(str((p[0] as Dictionary).get("text", ""))).contains("Reinforcements")


func test_only_count_down_adds_a_per_round_clock() -> void:
	var countdown := {
		"rolled": true, "roll": 4, "name": "Count Down", "description": "d",
		"effect": "countdown", "countdown_at": 1,
	}
	var ids: Array[String] = []
	for pr: Variant in FlowGuideRef.build_red_job_round_prompts(7, true, countdown):
		ids.append(str((pr as Dictionary).get("id", "")))
	assert_array(ids).contains(["red_job_countdown"])

	var evac := {
		"rolled": true, "roll": 5, "name": "Evac Now!", "description": "d",
		"effect": "evac_now",
	}
	for pr: Variant in FlowGuideRef.build_red_job_round_prompts(7, true, evac):
		assert_str(str((pr as Dictionary).get("id", ""))).override_failure_message(
			"Evac Now! grew a per-round clock it does not have").is_not_equal(
				"red_job_countdown")


func test_the_count_down_range_escalates_as_the_book_prints_it() -> void:
	# "On a 1, the Battle ends immediately. At the end of the next round the
	# Battle ends on a 1-2, then 1-3, and so forth."
	var expected := {1: "on a 1 ", 2: "on a 1-2 ", 3: "on a 1-3 "}
	for at: int in expected:
		var state := {
			"rolled": true, "roll": 4, "name": "Count Down", "description": "d",
			"effect": "countdown", "countdown_at": at,
		}
		var found := ""
		for pr: Variant in FlowGuideRef.build_red_job_round_prompts(7, true, state):
			if str((pr as Dictionary).get("id", "")) == "red_job_countdown":
				found = str((pr as Dictionary).get("text", "")).to_lower()
		assert_str(found).override_failure_message(
			"countdown_at %d should print '%s'" % [at, expected[at]]
		).contains(str(expected[at]).strip_edges())


# ── 3. Hold the Field is denied at EVERY producer ──────────────────────────

## p.149 rows 4 and 5 both say "you do not Hold the Field". Hold the Field is
## produced at three sites in TacticalBattleUI (results-form prefill, played
## resolution, map auto-resolve). A guard applied to N-1 of N sites is the single
## most common defect shape in this codebase, so this counts them.
func test_the_hold_field_denial_reaches_all_three_producers() -> void:
	var src: String = _code_only(TBUI_SRC)
	assert_bool(src.contains("func _apply_red_job_hold_denial")) \
		.override_failure_message(
			"the single denial chokepoint is gone; each producer would need its"
			+ " own guard, which is how one gets missed").is_true()
	var applications: int = src.count("_apply_red_job_hold_denial(")
	# One definition + three call sites.
	assert_int(applications).override_failure_message(
		"_apply_red_job_hold_denial appears %d times (expected 4: one definition"
		% applications + " plus the three held_field producers) — a producer is"
		+ " unguarded and Count Down / Evac Now would still Hold the Field there"
	).is_equal(4)


func test_the_resolver_is_called_from_the_round_loop() -> void:
	var src: String = _code_only(TBUI_SRC)
	assert_bool(src.contains("_resolve_red_job_time_constraint()")) \
		.override_failure_message(
			"the Time Constraint is no longer resolved in the End Phase, so"
			+ " RedZoneSystem.roll_time_constraint() goes back to zero callers"
		).is_true()
	# It must be resolved BEFORE the prompts are built, or the banner asks for a
	# roll the app already made.
	var resolve_at: int = src.find("_resolve_red_job_time_constraint()")
	var prompt_at: int = src.find("build_red_job_round_prompts(")
	assert_int(resolve_at).is_greater(-1)
	assert_int(prompt_at).is_greater(-1)
	assert_bool(resolve_at < prompt_at).override_failure_message(
		"the prompts are built before the roll is resolved, so the first Round 6"
		+ " banner reports the previous round's state").is_true()


func test_the_red_job_rule_reads_the_red_zone_table_not_the_expanded_one() -> void:
	# The trap this row carried: two same-named functions on unrelated classes.
	var src: String = _code_only(TBUI_SRC)
	assert_bool(src.contains("RedZoneSystemRef.roll_time_constraint()")) \
		.override_failure_message(
			"the battle UI is calling some OTHER roll_time_constraint() — the"
			+ " Expanded Missions one on compendium_missions_expanded.gd is a"
			+ " different table for a different rule").is_true()
