extends GdUnitTestSuite
## Fringe World Strife — Compendium pp.148-151.
##
## THE DEFECT THIS PINS. The 10-row D100 strife table has been complete and
## byte-correct in data/compendium/world_options.json since it was written, and
## the chapter still never ran once, for FOUR independent reasons at the one live
## call site (WorldPhaseController._check_compendium_world_strife):
##
##   1. it gated on `world_phase_data["is_fringe_world"]` — a key no producer
##      anywhere in the repository writes, so the guard was permanently false;
##   2. `should_check_strife()` re-rolled the p.148 ARRIVAL die every campaign
##      turn, and the book rolls it once, on arrival;
##   3. it fired the D100 immediately, and the book fires it only when the
##      Instability score reaches or exceeds 10;
##   4. it read `strife_event["instability_mod"]`, and every row carries
##      `instability_reduction` — into a local that was never used anyway.
##
## Fixing 1-4 would still not have produced the chapter, because its ENGINE — a
## per-world Instability score that accumulates across turns — did not exist in
## any form. The one function that looked like it (`roll_instability_delta`) had
## a single caller, in phases/WorldPhase.gd, a file with zero instantiations,
## and that copy then did `clampi(instability, 0, 10)`: pinning the score AT the
## threshold it was supposed to cross.
##
## gdUnit4 v6.0.3 compatible.

const Strife = preload("res://src/core/world/FringeWorldStrife.gd")
const WorldOptions = preload("res://src/data/compendium_world_options.gd")

const PLANET := "test_world_01"
const PAYMENT_SRC := "res://src/core/campaign/phases/post_battle/PaymentProcessor.gd"
const WORLD_OPTIONS_SRC := "res://src/data/compendium_world_options.gd"
const CONTROLLER_SRC := "res://src/ui/screens/world/WorldPhaseController.gd"

var _saved_flag: bool = false
var _saved_owned: bool = false


func _dlc() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


func before_test() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	_saved_owned = dlc.has_dlc("freelancers_handbook")
	_saved_flag = dlc.is_feature_enabled(dlc.ContentFlag.get("FRINGE_WORLD_STRIFE"))


func after_test() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(dlc.ContentFlag.get("FRINGE_WORLD_STRIFE"), _saved_flag)
	dlc.set_dlc_owned("freelancers_handbook", _saved_owned)


func _enable() -> bool:
	var dlc := _dlc()
	if dlc == null:
		return false
	dlc.set_dlc_owned("freelancers_handbook", true)
	dlc.set_feature_enabled(dlc.ContentFlag.get("FRINGE_WORLD_STRIFE"), true)
	return true


func _campaign() -> Dictionary:
	return {"progress_data": {}, "rivals": []}


## Seed one world's state directly. progress_data["fringe_strife"] IS the
## documented storage location (see the FringeWorldStrife docblock), so a test
## that writes there breaks loudly if the key ever moves — which is correct.
func _seed(campaign: Dictionary, instability: int, tracking: bool = true) -> void:
	campaign["progress_data"]["fringe_strife"] = {
		PLANET: {
			"planet_id": PLANET,
			"arrival_roll": 6,
			"arrival_threshold": 4,
			"unstable": true,
			"instability": instability,
			"tracking": tracking,
			"active_effects": [],
			"history": [],
		}
	}


func _src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var text: String = f.get_as_text()
	f.close()
	return text


## Source with whole-line comments removed.
##
## The anti-regression greps below assert about CODE, and these files carry long
## docblocks that quote the exact dead identifiers they replaced — so grepping
## raw source makes the explanation of a fix look like the fix being reverted.
## (This test suite caught its own docblock that way on the first run.)
## Trailing comments on code lines are NOT stripped; keep the named identifiers
## in full-line comments.
func _code_only(path: String) -> String:
	var out: PackedStringArray = []
	for line in _src(path).split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)


# --- The data --------------------------------------------------------------

func test_strife_table_spans_1_to_100_with_no_gap_or_overlap() -> void:
	var spans: Array = []
	for event in WorldOptions.STRIFE_EVENTS:
		spans.append([int(event.get("roll_min", -1)), int(event.get("roll_max", -1))])
	spans.sort_custom(func(a, b): return a[0] < b[0])
	var previous: int = 0
	for span in spans:
		assert_int(span[0]).override_failure_message(
			"strife table: gap or overlap at %d (previous row ended %d)"
			% [span[0], previous]).is_equal(previous + 1)
		previous = span[1]
	assert_int(previous).override_failure_message(
		"strife table stops at %d, not 100" % previous).is_equal(100)


func test_every_row_carries_instability_reduction_not_instability_mod() -> void:
	# The exact key the two old consumers got wrong. `instability_mod` appears on
	# no row and never did.
	for event in WorldOptions.STRIFE_EVENTS:
		var label: String = str(event.get("name", "?"))
		assert_bool(event.has("instability_reduction")).override_failure_message(
			"%s has no instability_reduction" % label).is_true()
		assert_bool(event.has("instability_mod")).override_failure_message(
			"%s carries instability_mod — the key the broken consumers read; "
			% label + "it must not exist").is_false()


func test_the_two_na_rows_are_the_only_zero_reduction_rows() -> void:
	# p.151: "Any result of 'NA' means Instability is no longer tracked."
	# Only Invasion Imminent (87-94) and Civil War (95-100) print NA.
	var zero_rows: Array = []
	for event in WorldOptions.STRIFE_EVENTS:
		if int(event.get("instability_reduction", -1)) == 0:
			zero_rows.append(str(event.get("id", "")))
	assert_array(zero_rows).contains_exactly_in_any_order(
		["invasion_imminent", "civil_war"])


# --- p.148 arrival ---------------------------------------------------------

func test_arrival_uses_four_plus_and_the_calmer_option_uses_five_plus() -> void:
	if not _enable():
		return
	var standard_unstable: int = 0
	var calmer_unstable: int = 0
	for i in range(400):
		var a := _campaign()
		if bool(Strife.roll_arrival(a, "w%d" % i, false).get("unstable", false)):
			standard_unstable += 1
		var b := _campaign()
		if bool(Strife.roll_arrival(b, "w%d" % i, true).get("unstable", false)):
			calmer_unstable += 1
	# 4+ on 1D6 is 50%, 5+ is 33%. Wide bounds — this asserts the thresholds are
	# different and in the right direction, not the RNG.
	assert_int(standard_unstable).override_failure_message(
		"p.148 says 4+; got %d/400" % standard_unstable).is_between(160, 240)
	assert_int(calmer_unstable).override_failure_message(
		"p.148 calmer option says 5+; got %d/400" % calmer_unstable).is_between(93, 173)
	assert_int(calmer_unstable).override_failure_message(
		"the calmer option must produce FEWER unstable worlds").is_less(standard_unstable)


func test_an_unstable_world_begins_at_plus_one_instability() -> void:
	# "When you arrive on the world, it begins at +1 Instability."
	if not _enable():
		return
	for i in range(60):
		var campaign := _campaign()
		var state: Dictionary = Strife.roll_arrival(campaign, "w%d" % i, false)
		if bool(state.get("unstable", false)):
			assert_int(int(state.get("instability", -1))).is_equal(1)
		else:
			assert_int(int(state.get("instability", -1))).is_equal(0)


func test_the_arrival_roll_is_idempotent_per_world() -> void:
	# Re-entering the World Phase, or reloading a save, must not re-roll a quiet
	# world into an unstable one. This is fault #2 of the old code, inverted.
	if not _enable():
		return
	var campaign := _campaign()
	var first: Dictionary = Strife.roll_arrival(campaign, PLANET, false)
	for _i in range(30):
		var again: Dictionary = Strife.roll_arrival(campaign, PLANET, false)
		assert_bool(bool(again.get("unstable"))).override_failure_message(
			"the arrival verdict changed on a re-entry").is_equal(
				bool(first.get("unstable")))
		assert_int(int(again.get("arrival_roll"))).is_equal(int(first.get("arrival_roll")))


func test_a_stable_world_is_never_tracked() -> void:
	if not _enable():
		return
	var campaign := _campaign()
	campaign["progress_data"]["fringe_strife"] = {
		PLANET: {"unstable": false, "instability": 0, "tracking": false},
	}
	assert_bool(Strife.is_tracking(campaign, PLANET)).is_false()
	assert_bool(Strife.accumulate(campaign, PLANET).get("ran", true)).override_failure_message(
		"a stable world must not accumulate Instability").is_false()


# --- p.148 accumulator -----------------------------------------------------

func test_the_accumulator_applies_all_four_book_modifiers() -> void:
	# "add 1D6 to the total. Adjust the total by an additional +1 for every
	#  active Rival on this world. Subtract -1 if you completed a Patron job this
	#  campaign turn. Subtract -1 if you Held the Field against a Roving Threat."
	if not _enable():
		return
	for _i in range(200):
		var campaign := _campaign()
		_seed(campaign, 0)
		var report: Dictionary = Strife.accumulate(campaign, PLANET, 3, true, true)
		var mods: Dictionary = report.get("modifiers", {})
		var die: int = int(mods.get("die", 0))
		assert_int(die).is_between(1, 6)
		assert_int(int(mods.get("rivals", 0))).is_equal(3)
		assert_int(int(mods.get("patron_job", 0))).is_equal(-1)
		assert_int(int(mods.get("held_field_roving", 0))).is_equal(-1)
		assert_int(int(report.get("delta", 0))).override_failure_message(
			"delta must be 1D6 +3 rivals -1 patron -1 roving").is_equal(die + 1)


func test_a_quiet_turn_can_reduce_instability() -> void:
	# The minimum delta is 1D6(1) - 1 - 1 = -1, so the score can fall. Floored at
	# 0 (documented at the implementation — the book states no lower bound, and
	# its own arithmetic treats 0 as the resting floor).
	if not _enable():
		return
	var saw_negative_delta: bool = false
	for _i in range(300):
		var campaign := _campaign()
		_seed(campaign, 0)
		var report: Dictionary = Strife.accumulate(campaign, PLANET, 0, true, true)
		if int(report.get("delta", 0)) < 0:
			saw_negative_delta = true
			assert_int(int(report.get("instability", -1))).override_failure_message(
				"instability must not go negative").is_greater_equal(0)
	assert_bool(saw_negative_delta).override_failure_message(
		"a Patron job plus a Roving Threat hold on a 1D6 of 1 is -1; never saw it"
	).is_true()


func test_the_d100_fires_only_at_ten_or_above() -> void:
	# "If this causes Instability to reach or exceed 10, make a D100 roll."
	# Seeded at 3: even a 6 lands on 9 and must NOT fire.
	if not _enable():
		return
	for _i in range(200):
		var campaign := _campaign()
		_seed(campaign, 3)
		var report: Dictionary = Strife.accumulate(campaign, PLANET, 0, false, false)
		if int(report.get("instability", 0)) < 10 and not report.get("fired", false):
			continue
		assert_bool(report.get("fired", false)).override_failure_message(
			"fired at instability %d — the threshold is 10"
			% int(report.get("instability", 0))).is_true()


func test_below_the_threshold_nothing_fires() -> void:
	if not _enable():
		return
	for _i in range(200):
		var campaign := _campaign()
		# 0 + at most 6 = 6. Can never reach 10.
		_seed(campaign, 0)
		var report: Dictionary = Strife.accumulate(campaign, PLANET, 0, false, false)
		assert_bool(report.get("fired", true)).override_failure_message(
			"fired below the threshold at instability %d"
			% int(report.get("instability", 0))).is_false()


func test_firing_reduces_the_score_by_the_row_amount() -> void:
	# "reduce the Instability score by the amount listed"
	if not _enable():
		return
	var saw_reduction: bool = false
	for _i in range(300):
		var campaign := _campaign()
		_seed(campaign, 20)
		var before: int = 20
		var report: Dictionary = Strife.accumulate(campaign, PLANET, 0, false, false)
		assert_bool(report.get("fired", false)).override_failure_message(
			"seeded at 20 — must always fire").is_true()
		var reduction: int = int(report.get("reduction", 0))
		if reduction <= 0:
			continue  # an NA row
		saw_reduction = true
		var expected: int = before + int(report.get("delta", 0)) - reduction
		assert_int(int(report.get("instability", -1))).override_failure_message(
			"score not reduced by the row's listed amount (%d)" % reduction
		).is_equal(maxi(expected, 0))
	assert_bool(saw_reduction).is_true()


func test_an_na_row_stops_tracking_for_good() -> void:
	# p.151: "Any result of 'NA' means Instability is no longer tracked: The
	# world has bigger problems to worry about!"
	if not _enable():
		return
	var saw_na: bool = false
	for _i in range(400):
		var campaign := _campaign()
		_seed(campaign, 20)
		var report: Dictionary = Strife.accumulate(campaign, PLANET, 0, false, false)
		if int(report.get("reduction", -1)) != 0:
			continue
		saw_na = true
		assert_bool(report.get("tracking", true)).is_false()
		assert_bool(Strife.is_tracking(campaign, PLANET)).override_failure_message(
			"an NA row must stop tracking permanently").is_false()
		# And a later Invasion step must do nothing at all.
		assert_bool(Strife.accumulate(campaign, PLANET).get("ran", true)).is_false()
	assert_bool(saw_na).override_failure_message(
		"never rolled 87-100 in 400 tries — check the table").is_true()


func test_the_option_is_silent_when_switched_off() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(dlc.ContentFlag.get("FRINGE_WORLD_STRIFE"), false)
	var campaign := _campaign()
	assert_dict(Strife.roll_arrival(campaign, PLANET)).is_empty()
	_seed(campaign, 50)
	assert_bool(Strife.accumulate(campaign, PLANET).get("ran", true)).is_false()


# --- pp.149-150 persistent effects -----------------------------------------

func test_criminal_gang_and_economic_collapse_each_cost_one_credit() -> void:
	if not _enable():
		return
	for effect_id in ["criminal_gang", "economic_collapse"]:
		var campaign := _campaign()
		_seed(campaign, 1)
		assert_int(Strife.payout_modifier(campaign, PLANET)).is_equal(0)
		Strife.add_active_effect(campaign, PLANET, effect_id)
		assert_int(Strife.payout_modifier(campaign, PLANET)).override_failure_message(
			"%s must reduce this world's payouts by 1 Credit" % effect_id).is_equal(-1)


func test_the_two_payout_penalties_do_not_stack() -> void:
	# Each row says "-1 Credit" and the book gives no stacking rule, so inventing
	# -2 would be our arithmetic rather than the book's.
	if not _enable():
		return
	var campaign := _campaign()
	_seed(campaign, 1)
	Strife.add_active_effect(campaign, PLANET, "criminal_gang")
	Strife.add_active_effect(campaign, PLANET, "economic_collapse")
	assert_int(Strife.payout_modifier(campaign, PLANET)).is_equal(-1)


func test_hooligans_closes_explore_and_trade_economic_collapse_closes_trade() -> void:
	if not _enable():
		return
	var campaign := _campaign()
	_seed(campaign, 1)
	assert_array(Strife.blocked_crew_tasks(campaign, PLANET)).is_empty()

	Strife.add_active_effect(campaign, PLANET, "hooligans", {"expires_after_turn": 5})
	assert_array(Strife.blocked_crew_tasks(campaign, PLANET)) \
		.contains_exactly_in_any_order(["explore", "trade"])

	var other := _campaign()
	_seed(other, 1)
	Strife.add_active_effect(other, PLANET, "economic_collapse")
	assert_array(Strife.blocked_crew_tasks(other, PLANET)).contains_exactly(["trade"])


func test_hooligans_expires_after_its_single_turn_but_others_persist() -> void:
	# p.149 Hooligans is the only row with a stated duration ("during the next
	# campaign turn"). Everything else stands until the player clears it.
	if not _enable():
		return
	var campaign := _campaign()
	_seed(campaign, 1)
	Strife.add_active_effect(campaign, PLANET, "hooligans", {"expires_after_turn": 5})
	Strife.add_active_effect(campaign, PLANET, "economic_collapse")

	assert_array(Strife.expire_effects(campaign, PLANET, 5)).override_failure_message(
		"must not expire on the turn it is still in force").is_empty()
	assert_array(Strife.expire_effects(campaign, PLANET, 6)).contains_exactly(["hooligans"])
	assert_bool(Strife.has_active_effect(campaign, PLANET, "hooligans")).is_false()
	assert_bool(Strife.has_active_effect(campaign, PLANET, "economic_collapse")) \
		.override_failure_message("Economic Collapse has no duration — it must persist") \
		.is_true()


func test_an_effect_is_never_recorded_twice() -> void:
	if not _enable():
		return
	var campaign := _campaign()
	_seed(campaign, 1)
	for _i in range(5):
		Strife.add_active_effect(campaign, PLANET, "criminal_gang")
	assert_int(Strife.active_effects(campaign, PLANET).size()).is_equal(1)


func test_heating_up_draws_a_real_criminal_elements_row() -> void:
	# p.149: "Add a Rival randomly selected from the Criminal Elements subtable
	# (core rules, p.94)" — the actual D100 table, not a hand-written shortlist.
	if not _enable():
		return
	var seen := {}
	for _i in range(150):
		var name: String = Strife.roll_criminal_elements_name()
		assert_str(name).override_failure_message(
			"the Criminal Elements subtable produced nothing").is_not_empty()
		seen[name] = true
	assert_int(seen.size()).override_failure_message(
		"only ever drew %s — the D100 roll is not reaching the table" % str(seen.keys())
	).is_greater(3)


# --- The wiring ------------------------------------------------------------

func test_the_accumulator_runs_in_the_invasion_step() -> void:
	# p.148: "During the Invasion step of every campaign turn, add 1D6 to the
	# total." Must be its OWN call, not nested inside process_invasion_check —
	# that function returns early unless the enemy was an Invasion Threat, so
	# nesting would advance the score only on those rare turns.
	var src: String = _src(PAYMENT_SRC)
	assert_str(src).contains("func process_fringe_world_strife")
	assert_str(src).override_failure_message(
		"the accumulator no longer reaches FringeWorldStrife"
	).contains("FringeWorldStrifeRef.accumulate(")
	assert_str(src).override_failure_message(
		"the Criminal Gang / Economic Collapse payout penalty is not applied"
	).contains("FringeWorldStrifeRef.payout_modifier(")


func test_the_broken_boolean_gate_is_gone() -> void:
	# `should_check_strife(is_fringe_world)` was the whole live entry point and
	# its argument had no producer anywhere. Do not reinstate it: the book's gate
	# is the arrival 1D6, whose result is per-world STATE, not a world property.
	assert_str(_code_only(WORLD_OPTIONS_SRC)).override_failure_message(
		"should_check_strife is back — see the deletion note in that file"
	).not_contains("func should_check_strife")
	assert_str(_code_only(CONTROLLER_SRC)).override_failure_message(
		"WorldPhaseController is gating on is_fringe_world again, a key nothing writes"
	).not_contains("is_fringe_world")


func test_the_controller_does_the_arrival_roll_and_nothing_else() -> void:
	var src: String = _code_only(CONTROLLER_SRC)
	assert_str(src).contains("FringeWorldStrifeRef.roll_arrival(")
	assert_str(src).override_failure_message(
		"the controller is firing the D100 directly again — that belongs to the "
		+ "accumulator, at the threshold of 10"
	).not_contains("CompendiumWorldOptionsRef.roll_strife_event()")
