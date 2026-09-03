extends GdUnitTestSuite
## Four rules that shared one root cause: a value produced and never consumed.
##
## 1. ADVANCED TRAINING WAS A DEAD MECHANISM (Core Rules p.125).
##    `AdvancementSystem._apply_training_benefits()` recorded each course as
##    `character.set("has_<x>_training", true)` — a property Character does NOT
##    declare, so a silent no-op (Character.gd:1067 says so outright) — and it was
##    reachable only from `purchase_training()`, which has ZERO callers. The live
##    grant path is `Character.add_training()`, whose SSOT is `acquired_training`.
##    So `RedZoneSystem` read `has_broker_training` and never found it: a crew
##    member who BOUGHT Broker training got no Red Zone licence discount.
##
## 2. MERCHANT SCHOOL bought nothing at all (p.125).
##
## 3. REWARDS SUBTABLE ship-component discount (p.134) was rolled at "establish
##    value now" time and thrown away — 20% of Rewards results, a line of text and
##    no benefit.
##
## 4. EXPANDED MISSIONS two-objective rolls (Compendium pp.74-76) promised two
##    objectives with separate time constraints and listed one of each.
##
## gdUnit4 v6.0.3 compatible.

const AdvancementRef := preload("res://src/core/character/advancement/AdvancementSystem.gd")
const LOOT_PROC_SRC := "res://src/core/campaign/phases/post_battle/LootProcessor.gd"
const SHIPMAN_SRC := "res://src/ui/screens/ships/ShipManager.gd"
const REDZONE_SRC := "res://src/core/mission/RedZoneSystem.gd"
const CREWTASK_SRC := "res://src/ui/screens/world/components/CrewTaskComponent.gd"
const JOB_SRC := "res://src/ui/screens/world/components/JobOfferComponent.gd"


const NL := "\n"

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


# ── 1. The training reader ─────────────────────────────────────────────────

func test_training_is_read_from_acquired_training_on_both_shapes() -> void:
	# Crew are Dictionaries on a loaded save and Character RESOURCES on a fresh
	# campaign; a reader that handles only one shape silently answers "no".
	assert_bool(AdvancementRef.member_has_training(
		{"acquired_training": ["merchant"]}, "merchant")).is_true()
	assert_bool(AdvancementRef.member_has_training(
		{"acquired_training": ["broker"]}, "merchant")).is_false()
	assert_bool(AdvancementRef.member_has_training({}, "merchant")).is_false()
	assert_bool(AdvancementRef.member_has_training(null, "merchant")).is_false()

	var ch := Character.new()
	assert_bool(AdvancementRef.member_has_training(ch, "merchant")).is_false()
	ch.add_training("merchant")
	assert_bool(AdvancementRef.member_has_training(ch, "merchant")) \
		.override_failure_message(
			"add_training() is the LIVE grant path and the reader must see it"
		).is_true()


func test_the_dead_has_x_training_booleans_are_not_read_anywhere() -> void:
	# Character.gd:1069 — "never read them, and never reintroduce that mechanism".
	var offenders: PackedStringArray = []
	for path: String in [REDZONE_SRC, CREWTASK_SRC]:
		var line_no := 0
		for line: String in _code_only(path).split("\n"):
			line_no += 1
			if "has_broker_training" in line or "has_merchant_training" in line:
				offenders.append("%s:%d" % [path.get_file(), line_no])
	assert_int(offenders.size()).override_failure_message(
		"a `has_*_training` boolean is being read again. Nothing writes those —"
		+ " `purchase_training()` has zero callers and its Object.set() calls are"
		+ " no-ops — so the branch is permanently false:\n  "
		+ "\n  ".join(offenders)).is_equal(0)


func test_the_red_zone_licence_discount_sees_purchased_broker_training() -> void:
	assert_bool(_code_only(REDZONE_SRC).contains(
		"AdvancementSystemRef.member_has_training(member, \"broker\")")) \
		.override_failure_message(
			"the Red Zone licence discount no longer recognises PURCHASED Broker"
			+ " training (p.125), only a lucky creation trait").is_true()


func test_crew_wide_lookup_finds_a_single_trained_member() -> void:
	var crew: Array = [
		{"acquired_training": []},
		{"acquired_training": ["broker"]},
		{},
	]
	assert_bool(AdvancementRef.crew_has_training(crew, "broker")).is_true()
	assert_bool(AdvancementRef.crew_has_training(crew, "merchant")).is_false()
	assert_bool(AdvancementRef.crew_has_training([], "broker")).is_false()


# ── 2. Merchant school reroll ──────────────────────────────────────────────

func test_the_merchant_reroll_exists_and_is_offered_before_payout() -> void:
	var src: String = _code_only(CREWTASK_SRC)
	assert_bool(src.contains("_offer_merchant_reroll")).override_failure_message(
		"Merchant school (p.125) buys nothing again").is_true()
	# "You may roll up ALL eligible Trade rolls BEFORE choosing what to reroll" —
	# so it must sit after the free-trade rolls and before the event queue applies
	# anything.
	var offer_at: int = src.find("await _offer_merchant_reroll(")
	var queue_at: int = src.find("_build_event_queue()")
	assert_int(offer_at).override_failure_message(
		"the reroll offer is not awaited in the resolve-all flow").is_greater(-1)
	assert_int(queue_at).is_greater(-1)
	assert_bool(offer_at < queue_at).override_failure_message(
		"the reroll is offered AFTER the event queue has begun paying results"
		+ " out, so the player would be rerolling a result already applied"
	).is_true()


func test_the_reroll_is_once_per_campaign_turn() -> void:
	var src: String = _code_only(CREWTASK_SRC)
	assert_bool(src.contains("MERCHANT_REROLL_KEY")).override_failure_message(
		"p.125 says 'one Trade roll EACH CAMPAIGN TURN' — the per-turn budget is"
		+ " gone, so the reroll could be taken repeatedly").is_true()
	assert_bool(src.contains("_mark_merchant_reroll_used")).is_true()


func test_the_new_roll_replaces_the_old_one() -> void:
	# p.125: "The new roll must be accepted" — not best-of-two.
	var src: String = _code_only(CREWTASK_SRC)
	var body_at: int = src.find("func _offer_merchant_reroll")
	assert_int(body_at).is_greater(-1)
	# ⚠ BOUND THE WINDOW. `substr(body_at)` alone scans to END OF FILE, so
	# this failed the moment ANY later function in the ~4,100-line component
	# used maxi() — which the Sep 3 errata recruit work did, at :4029 and
	# :4060, nowhere near the merchant reroll. The rule was never broken;
	# the test was reading the wrong code. Same shape as the knock-out test
	# that scanned its own docblock.
	var rest: String = src.substr(body_at)
	var next_func: int = rest.find(NL + "func ", 1)
	var body: String = rest.substr(0, next_func) if next_func > 0 else rest
	assert_bool(body.contains("maxi(")).override_failure_message(
		"the merchant reroll is picking the better of two rolls; p.125 says the"
		+ " new roll MUST be accepted").is_false()


# ── 3. p.134 ship-component discount ───────────────────────────────────────

func test_the_discount_is_banked_when_the_reward_lands() -> void:
	assert_bool(_code_only(LOOT_PROC_SRC).contains("ship_component_discount")) \
		.override_failure_message(
			"LootProcessor throws the p.134 'establish value now' roll away again"
		).is_true()
	assert_bool(_code_only(LOOT_PROC_SRC).contains("ship_component_discounts")) \
		.override_failure_message("the voucher queue is not written").is_true()


func test_the_discount_is_shown_in_the_price_and_spent_on_purchase() -> void:
	var src: String = _code_only(SHIPMAN_SRC)
	assert_bool(src.contains("_pending_component_discount()")) \
		.override_failure_message(
			"the banked discount is not reflected in the component price, so the"
			+ " player cannot see the voucher they hold").is_true()
	assert_bool(src.contains("_consume_component_discount()")) \
		.override_failure_message(
			"the voucher is never spent, so it discounts every purchase forever"
			+ " instead of 'your NEXT ship component purchase'").is_true()


## The voucher must be burned only once the purchase actually goes through.
func test_the_voucher_is_consumed_after_the_affordability_check() -> void:
	var src: String = _code_only(SHIPMAN_SRC)
	var fn_at: int = src.find("func _on_upgrade_purchased")
	assert_int(fn_at).is_greater(-1)
	var body: String = src.substr(fn_at)
	# ⚠ The anchor was "if current_credits < cost:". The Aug 6 SalvageLedger
	# work renamed that local to `credit_cost` (salvage is applied first,
	# so the credit half is what must be affordable), and the test was never
	# updated - it searched for a string that no longer existed, got -1, and
	# failed on `-1 > -1`. Matched on the stable prefix now, so a further
	# rename of the amount cannot break it again.
	var afford_at: int = body.find("if current_credits < ")
	var consume_at: int = body.find("_consume_component_discount()")
	assert_int(afford_at).is_greater(-1)
	assert_int(consume_at).is_greater(-1)
	assert_bool(consume_at > afford_at).override_failure_message(
		"the p.134 voucher is consumed BEFORE the affordability check, so a click"
		+ " the crew cannot pay for still burns it").is_true()


func test_the_rewards_table_ranges_match_the_book() -> void:
	# p.134: 71-85 Ship Parts (1D6), 86-90 Military Ship Part (1D6+2).
	var f := FileAccess.open("res://data/loot_tables.json", FileAccess.READ)
	assert_object(f).is_not_null()
	var json := JSON.new()
	assert_int(json.parse(f.get_as_text())).is_equal(OK)
	f.close()
	var rows: Array = json.data.get("tables", {}).get("rewards_subtable", [])
	assert_int(rows.size()).is_equal(10)
	var by_item := {}
	for row: Variant in rows:
		by_item[str((row as Dictionary).get("item", ""))] = row
	# Godot's JSON parser returns EVERY number as a float, so [71.0, 85.0] does
	# not equal [71, 85]. Normalise rather than comparing floats.
	var ints := func(a: Variant) -> Array[int]:
		var out: Array[int] = []
		for v: Variant in (a as Array):
			out.append(int(v))
		return out
	assert_array(ints.call((by_item["Ship Parts"] as Dictionary).get("roll_range", []))) \
		.is_equal([71, 85])
	assert_str(str((by_item["Ship Parts"] as Dictionary).get("discount_dice", ""))) \
		.is_equal("1d6")
	assert_array(ints.call(
		(by_item["Military Ship Part"] as Dictionary).get("roll_range", []))) \
		.is_equal([86, 90])
	assert_str(str((by_item["Military Ship Part"] as Dictionary).get(
		"discount_dice", ""))).is_equal("1d6+2")


# ── 4. Expanded Missions two-objective rolls ───────────────────────────────

func test_the_objective_count_is_read_from_the_overview_row() -> void:
	var src: String = _code_only(JOB_SRC)
	assert_bool(src.contains("objective_count")).override_failure_message(
		"the overview row's `count` has no consumer again, so 40%% of Expanded"
		+ " Missions rolls promise two objectives and list one").is_true()
	assert_bool(src.contains("for i in range(objective_count):")) \
		.override_failure_message(
			"objectives are not generated per the count — Compendium p.75 rolls"
			+ " the specific-objective table 'once for each objective'").is_true()


func test_each_objective_gets_its_own_time_constraint() -> void:
	# p.76: "If you have two objectives, a constraint is determined SEPARATELY
	# for each objective."
	var src: String = _code_only(JOB_SRC)
	var loop_at: int = src.find("for i in range(objective_count):")
	assert_int(loop_at).is_greater(-1)
	var loop_body: String = src.substr(loop_at, 900)
	assert_bool(loop_body.contains("roll_specific_objective()")).is_true()
	assert_bool(loop_body.contains("roll_time_constraint()")).override_failure_message(
		"the time constraint is rolled outside the per-objective loop, so both"
		+ " objectives share one limit").is_true()


func test_the_overview_rows_still_carry_the_book_counts() -> void:
	var f := FileAccess.open("res://data/compendium/missions_expanded.json",
		FileAccess.READ)
	assert_object(f).is_not_null()
	var json := JSON.new()
	assert_int(json.parse(f.get_as_text())).is_equal(OK)
	f.close()
	var root: Dictionary = json.data.get("expanded_missions", json.data)
	var rows: Array = root.get("objective_overview", [])
	assert_int(rows.size()).is_equal(3)
	var expected := {"single": 1, "dual_both": 2, "dual_choice": 2}
	for row: Variant in rows:
		var id: String = str((row as Dictionary).get("id", ""))
		assert_int(int((row as Dictionary).get("count", 0))) \
			.override_failure_message("p.74 row '%s' count" % id) \
			.is_equal(int(expected[id]))


func test_the_briefing_numbers_both_objectives() -> void:
	var src: String = _code_only(JOB_SRC)
	assert_bool(src.contains("dlc_objectives")).override_failure_message(
		"the briefing renders only the singular keys, so the second objective is"
		+ " generated and never shown").is_true()
	assert_bool(src.contains("[%d] ")).override_failure_message(
		"a two-objective briefing does not number its objectives, so the two"
		+ " time constraints cannot be told apart").is_true()
