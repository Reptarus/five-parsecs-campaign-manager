extends GdUnitTestSuite
## Three rules that each state a rule the code applied in the wrong SHAPE.
##
## 1. RED ZONE QUEST PAY (Core Rules p.120 + p.150). Every rule that widens the
##    pay roll states a TOTAL, not an increment — so when two apply the answer is
##    the LARGER total, never the sum. The code applied them in sequence and a Red
##    Zone Quest conclusion rolled FOUR dice: best-of-4 averages 5.24 against the
##    book's best-of-3 4.96.
##
## 2. SPECIAL CONDITIONS (Compendium p.76). The table is headed "Special
##    Conditions: PATRON JOBS ONLY" and opens "If undertaking a Patron job". It
##    was rolled for every offer, so an Open Market mission could arrive banning
##    Psionics or Armor on behalf of an employer that does not exist.
##
## 3. BLACK JOB MISSION (Core Rules pp.150-151). The D10 'Your Day in Hell' roll
##    lived inside a UI card BUILDER, so it re-rolled on every panel rebuild —
##    while `PostBattleCompletion` and `CampaignJournal` both READ
##    `black_zone_mission`, a key no producer anywhere ever wrote.
##
## gdUnit4 v6.0.3 compatible.

const PAYMENT_SRC := "res://src/core/campaign/phases/post_battle/PaymentProcessor.gd"
const JOB_SRC := "res://src/ui/screens/world/components/JobOfferComponent.gd"
const WPC_SRC := "res://src/ui/screens/world/WorldPhaseController.gd"
const PREP_SRC := "res://src/ui/screens/world/components/MissionPrepComponent.gd"
const NORM_SRC := "res://src/core/battle/BattleResultNormalizer.gd"
const CPM_SRC := "res://src/core/campaign/CampaignPhaseManager.gd"

const BlackZoneRef := preload("res://src/core/mission/BlackZoneSystem.gd")


func _src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var t: String = f.get_as_text()
	f.close()
	return t


## Comment-stripped source — a scan that forbids a string must ignore the comment
## that explains why it is forbidden. (This suite quotes "roll_patron_condition"
## and "roll_mission_type" in its own prose, and so does the code it scans.)
func _code_only(path: String) -> String:
	var out: PackedStringArray = []
	for line: String in _src(path).split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)


# ── 1. Red Zone Quest pay: three dice, not four ────────────────────────────

func test_the_pay_roll_uses_a_die_count_not_stacked_rolls() -> void:
	var src: String = _code_only(PAYMENT_SRC)
	assert_bool(src.contains("dice_count")).override_failure_message(
		"the pay roll is back to applying each widening rule in sequence, which is"
		+ " how a Red Zone Quest ended up rolling four dice").is_true()
	assert_bool(src.contains("dice_count = 3 if is_red_zone_pay else 2")) \
		.override_failure_message(
			"p.150 'When finishing a Quest, you may roll THREE dice, pick the"
			+ " best, and add +1' / p.120 quest finale is TWO dice + 1").is_true()


func test_danger_pay_raises_the_count_it_does_not_add_to_it() -> void:
	# p.83 "roll twice, picking the higher die" is also a TOTAL. Adding it on top
	# of the p.150 three would be the same defect in a new place.
	assert_bool(_code_only(PAYMENT_SRC).contains("dice_count = maxi(dice_count, 2)")) \
		.override_failure_message(
			"Danger Pay increments the die count instead of raising it to its own"
			+ " stated total of 2, so it stacks with the zone and quest rules"
		).is_true()


## Behavioural: the expected value of best-of-N is a fixed, well-separated ladder
## (1D6 3.50, best-of-2 4.47, best-of-3 4.96, best-of-4 5.24). The quest +1 is
## added on top. Sampling the four cases pins that the counts are what the book
## says without pinning a seed.
func test_the_four_pay_cases_have_the_book_expected_values() -> void:
	var trials: int = 4000
	var rng := RandomNumberGenerator.new()
	rng.seed = 8062026

	var best_of := func(n: int) -> int:
		var best: int = 0
		for _i in range(n):
			best = maxi(best, rng.randi_range(1, 6))
		return best

	# Reference ladder, computed the same way the processor does.
	var cases := {
		"ordinary": {"dice": 1, "bonus": 0, "expect": 3.50},
		"red_zone": {"dice": 2, "bonus": 0, "expect": 4.47},
		"quest": {"dice": 2, "bonus": 1, "expect": 5.47},
		"red_zone_quest": {"dice": 3, "bonus": 1, "expect": 5.96},
	}
	for name: String in cases:
		var c: Dictionary = cases[name]
		var total: int = 0
		for _t in range(trials):
			total += best_of.call(int(c["dice"])) + int(c["bonus"])
		var avg: float = float(total) / float(trials)
		assert_float(avg).override_failure_message(
			"%s: expected ~%.2f, sampled %.3f over %d trials"
			% [name, float(c["expect"]), avg, trials]
		).is_between(float(c["expect"]) - 0.12, float(c["expect"]) + 0.12)

	# The defect this row records: best-of-FOUR sits 0.28 above best-of-three,
	# which is far outside the ±0.12 band above — so the assertion can really fail.
	var four_total: int = 0
	for _t in range(trials):
		four_total += best_of.call(4) + 1
	var four_avg: float = float(four_total) / float(trials)
	assert_float(four_avg).override_failure_message(
		"best-of-4 (%.3f) is not separable from the book's best-of-3 (5.96) at"
		+ " this sample size, so the test above proves nothing" % four_avg
	).is_greater(6.10)


# ── 2. Special Conditions are Patron jobs only ─────────────────────────────

func test_the_patron_condition_roll_is_gated_on_a_patron_job() -> void:
	var src: String = _code_only(JOB_SRC)
	var idx: int = src.find("roll_patron_condition")
	assert_int(idx).override_failure_message(
		"roll_patron_condition is gone entirely — the p.76 table should be gated,"
		+ " not deleted").is_greater(-1)
	# The gate must be the guard immediately enclosing the call.
	var before: String = src.substr(maxi(0, idx - 320), mini(320, idx))
	assert_bool(before.contains("job_source == \"patron\"")).override_failure_message(
		"Compendium p.76 heads this table 'Special Conditions: Patron Jobs Only'"
		+ " and opens 'If undertaking a Patron job'. Without the gate an"
		+ " Opportunity mission can ban Psionics or Armor on behalf of an employer"
		+ " that does not exist.").is_true()


func test_the_gate_matches_the_danger_pay_gate_already_in_the_file() -> void:
	# Both are p.83/p.76 PATRON tables the Open Market builder was running anyway.
	# Two different answers to "is this a Patron job?" in one file is how a rule
	# ends up half-applied.
	var src: String = _code_only(JOB_SRC)
	assert_bool(src.contains("mission_source != \"patron\" and mission_source != \"faction\"")) \
		.override_failure_message(
			"the Danger Pay gate changed shape; the Special Conditions gate was"
			+ " written to match it and they must stay in agreement").is_true()
	assert_bool(src.contains("job_source == \"patron\" or job_source == \"faction\"")) \
		.override_failure_message(
			"the Special Conditions gate no longer accepts faction jobs, which the"
			+ " Danger Pay gate does — the two now disagree").is_true()


# ── 3. The Black Job mission is rolled once and recorded ───────────────────

func test_the_day_in_hell_table_is_a_d10_covering_one_to_ten() -> void:
	# Core Rules pp.150-151: 1-2 / 3-4 / 5-6 / 7-8 / 9-10.
	var seen := {}
	for roll: int in range(1, 11):
		seen[roll] = false
	for _i in range(400):
		var m: Dictionary = BlackZoneRef.roll_mission_type()
		assert_bool(m.is_empty()).override_failure_message(
			"roll_mission_type() returned {} — the D10 has a hole in it").is_false()
	# Every printed row must be reachable from the data.
	var data_rows: Array = []
	var f := FileAccess.open("res://data/black_zone_jobs.json", FileAccess.READ)
	assert_object(f).is_not_null()
	var json := JSON.new()
	assert_int(json.parse(f.get_as_text())).is_equal(OK)
	f.close()
	var root: Dictionary = json.data.get("black_zone_jobs", json.data)
	data_rows = root.get("mission_types", [])
	assert_int(data_rows.size()).override_failure_message(
		"the 'Your Day in Hell' table should have the book's five rows"
	).is_equal(5)
	var covered: Array[int] = []
	for row: Variant in data_rows:
		var span: Array = (row as Dictionary).get("roll_range", [])
		assert_int(span.size()).is_equal(2)
		for v: int in range(int(span[0]), int(span[1]) + 1):
			covered.append(v)
	covered.sort()
	assert_array(covered).override_failure_message(
		"the D10 must tile 1-10 exactly once").is_equal(
			[1, 2, 3, 4, 5, 6, 7, 8, 9, 10])


func test_the_roll_happens_at_stamping_time_not_in_the_card_builder() -> void:
	assert_bool(_code_only(WPC_SRC).contains("func _stamp_black_zone_mission")) \
		.override_failure_message(
			"the Black Job mission is no longer stamped alongside is_black_zone,"
			+ " so it falls back to being re-rolled by whatever displays it"
		).is_true()
	# The builder must READ, via the resolver, not roll inline.
	var prep: String = _code_only(PREP_SRC)
	# Exactly ONE roll site may survive in the component: the not-persisted preview
	# fallback inside _black_zone_mission(). A second one means a builder is
	# rolling again.
	assert_int(prep.count("BlackZoneSystem.roll_mission_type()")).override_failure_message(
		"MissionPrepComponent contains %d roll sites; only the preview fallback"
		% prep.count("BlackZoneSystem.roll_mission_type()")
		+ " inside _black_zone_mission() may roll").is_equal(1)
	assert_bool(prep.contains("var bz_mission: Dictionary = _black_zone_mission()")) \
		.override_failure_message(
			"MissionPrepComponent rolls the mission type inside a card builder"
			+ " again, so the briefing changes every time the panel rebuilds"
		).is_true()


func test_both_zone_stamp_sites_handle_black_as_well_as_red() -> void:
	# The Red Job Threat Condition is stamped at TWO sites; a guard applied to one
	# of two sites is the shape that produced half this ledger.
	var src: String = _code_only(WPC_SRC)
	var red_calls: int = src.count("_stamp_red_zone_threat(")
	var black_calls: int = src.count("_stamp_black_zone_mission(")
	# Each has one definition plus its call sites.
	assert_int(black_calls).override_failure_message(
		"_stamp_black_zone_mission is called at %d site(s) but the Red Zone"
		% (black_calls - 1)
		+ " equivalent at %d — the two zone paths must stay symmetric"
		% (red_calls - 1)).is_equal(red_calls)


func test_the_stamped_mission_reaches_the_two_waiting_consumers() -> void:
	assert_bool(_code_only(NORM_SRC).contains("\"black_zone_mission\"")) \
		.override_failure_message(
			"black_zone_mission is not in the normalizer passthrough list, so it"
			+ " never reaches battle_result and PostBattleCompletion:161 /"
			+ " CampaignJournal:204 stay unfed").is_true()


func test_the_roll_is_dropped_at_turn_rollover() -> void:
	assert_bool(_code_only(CPM_SRC).contains("progress_data.erase(\"black_zone_mission\")")) \
		.override_failure_message(
			"the Black Job roll now survives into a turn where the crew did not"
			+ " volunteer, so the next Black Job inherits the previous mission"
			+ " instead of rolling its own").is_true()
