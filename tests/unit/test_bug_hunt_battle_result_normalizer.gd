extends GdUnitTestSuite
## The Bug Hunt post-battle chokepoint: every fact the sequence reads comes out of
## BugHuntBattleResultNormalizer, and nothing it reports is invented.
##
## WHY THIS EXISTS. Measured on HEAD before Phase 4, no played Bug Hunt mission ever
## scored an objective. `objectives_completed` had exactly two producers, both of them
## launch-FAILURE fallbacks that fabricated a won mission (BugHuntMissionPanel :451,
## :496), so every real battle came back reading 0: Court Martial fired every turn,
## objective XP and Reputation never paid, and the campaign had no reachable win. The
## mirror defect sat in the casualty step, which read an empty `casualties` list as
## "no battle data" and rolled a 1-in-5 casualty per active main character — so a
## battle nobody was hurt in still produced casualties.
##
## Both are the documented consumer-reads-a-key-no-producer-writes shape, and the
## foundation 5PFH already proved is the answer: STAMP the scenario before the battle,
## then pass everything through ONE normalizer. This suite is that normalizer's pin.
##
## WHAT THE THREE GROUPS PROVE.
##   Battle facts (1-5): the stamp reaches the result, casualties are DERIVED from what
##     the battle screen recorded, and an empty battle stays empty. Case 5 is the
##     no-invention case and it is the one the deleted fallback would fail.
##   The debrief (6-11): the p.185/201 weights, the p.201 signals penalty, the p.201
##     success threshold and the p.201 Court Martial test, each scored from the
##     thresholds STAMPED with the mission rather than from a literal in the scorer.
##   The contract (12-14): add-only, idempotent, and abort-proof against the variant
##     result shapes a legacy save or another mode can hand over.
##
## ⚠ THE TWO-STAGE PROPERTY IS LOAD-BEARING (case 12). normalize() is called TWICE per
## mission: once on the battle return with an EMPTY debrief (facts only, the player has
## not debriefed yet) and again on debrief submit. If the debrief block wrote its keys
## unconditionally, the first call would stamp `objectives_completed = 0` and the
## second could never raise it — and test_bug_hunt_turn_completion's OBJECTIVES_RESULT,
## which injects a value directly, would be overwritten. Hence: skipped entirely when
## the debrief is empty, and add-only PER FIELD when it is not.
##
## gdUnit4 v6.0.3.

const Normalizer = preload("res://src/core/battle/BugHuntBattleResultNormalizer.gd")
const Shared = preload("res://src/core/battle/BattleResultNormalizer.gd")

## The scoring block as data/bug_hunt/bug_hunt_missions.json carries it, and as
## BugHuntMissionPanel stamps it onto the mission. Written out here rather than loaded
## so a case fails when the SCORER changes, not when the data file does — the data is
## pinned separately by its own citations.
const SCORING := {
	"weights": {"normal": 1, "vital": 2, "critical": 3},
	"success_threshold": 2,
	"signals_requirement": {
		"signals_at_least": 4, "must_investigate": 2, "objective_penalty": 1},
}


func _stamp(overrides: Dictionary = {}) -> Dictionary:
	## A mission as BugHuntMissionPanel._launch_mission stamps it. Three objectives
	## weighted 1 / 2 / 3, which is the p.185 spread (normal, Vital, Critical).
	var stamp := {
		"priority": 5,
		"spawn_rating": 2,
		"escalation_step": 3,
		"signals_total": 0,
		"use_signals": false,
		"participant_ids": ["mc_ada", "mc_bo"],
		"scoring": SCORING.duplicate(true),
		"objectives": [
			{"type": {"name": "Secure the site"}, "rating": "normal", "weight": 1},
			{"type": {"name": "Recover the sample"}, "rating": "vital", "weight": 2},
			{"type": {"name": "Destroy the hive"}, "rating": "critical", "weight": 3},
		],
	}
	for key in overrides:
		stamp[key] = overrides[key]
	return stamp


func _battle(overrides: Dictionary = {}) -> Dictionary:
	## TacticalBattleUI's OWN vocabulary -- crew_injuries_data / crew_casualties_data /
	## crew_participants, each a list of character dictionaries. Deliberately NOT the
	## post-battle vocabulary: the whole point of the normalizer is the translation.
	var result := {
		"victory": true,
		"rounds": 4,
		"crew_participants": [
			{"character_id": "mc_ada", "name": "Ada"},
			{"character_id": "mc_bo", "name": "Bo"},
			{"character_id": "mc_cyr", "name": "Cyr"},
		],
		"crew_injuries_data": [{"character_id": "mc_bo", "name": "Bo"}],
		"crew_casualties_data": [{"character_id": "mc_cyr", "name": "Cyr"}],
	}
	for key in overrides:
		result[key] = overrides[key]
	return result


# ---------------------------------------------------------------- battle facts
func test_the_stamp_carries_the_scenario_into_the_result() -> void:
	## The mission's own identity survives the battle. `priority` matters most: the
	## p.204 XP step pays +1 XP on Mission Priority 4+, and before the stamp existed
	## it read a default of 1 on every played mission, so that row never paid.
	var out := Normalizer.normalize(_battle(), _stamp(), {})
	assert_int(out.get("priority", -1)).override_failure_message(
		"the stamped Mission Priority must reach the result -- the p.204 XP row reads it"
	).is_equal(5)
	assert_int(out.get("spawn_rating", -1)).is_equal(2)
	assert_int(out.get("escalation_step", -1)).is_equal(3)
	assert_array(out.get("mission_objectives", [])).has_size(3)
	assert_bool(out.get("bug_hunt_normalized", false)).is_true()


func test_casualty_ids_are_derived_from_what_the_battle_screen_recorded() -> void:
	## p.202: "For each character who became a casualty during this campaign turn,
	## roll D100". That is everyone who went Out of Action -- injured AND killed -- so
	## both of the battle screen's lists feed it, and each id appears once.
	var out := Normalizer.normalize(_battle(), _stamp(), {})
	var ids: Array = out.get("casualty_ids", [])
	assert_array(ids).override_failure_message(
		"casualty_ids must be the union of the injured and the killed, by id"
	).contains_exactly_in_any_order(["mc_bo", "mc_cyr"])


func test_participant_ids_prefer_the_stamp_over_the_battle_screen() -> void:
	## The stamp was taken at deployment, before the battle could change the roster,
	## so it is authoritative for "who took the field" (p.203). The battle screen here
	## reports a THIRD name the stamp does not have, and the stamp must still win.
	var out := Normalizer.normalize(_battle(), _stamp(), {})
	assert_array(out.get("participant_ids", [])).contains_exactly(["mc_ada", "mc_bo"])


func test_participant_ids_fall_back_to_the_battle_screen_when_unstamped() -> void:
	## A mission launched before the stamp existed, or by a path that does not stamp,
	## still has to answer "who was there" -- the fallback reads crew_participants
	## through the SAME shared parser 5PFH uses, so the two modes cannot drift.
	var out := Normalizer.normalize(
		_battle(), _stamp({"participant_ids": []}), {})
	assert_array(out.get("participant_ids", [])).contains_exactly_in_any_order(
		["mc_ada", "mc_bo", "mc_cyr"])


func test_a_battle_in_which_nobody_was_hurt_reports_no_casualties() -> void:
	## THE NO-INVENTION CASE. An empty casualty list is a legitimate outcome, not
	## missing data. The deleted fallback in BugHuntPostBattlePanel treated it as the
	## latter and rolled a 1-in-5 chance per active main character, so a clean mission
	## still sent people to the Casualty table.
	var clean := _battle({"crew_injuries_data": [], "crew_casualties_data": []})
	var out := Normalizer.normalize(clean, _stamp(), {})
	assert_array(out.get("casualty_ids", [null])).override_failure_message(
		"a battle with no injuries and no casualties must report NO casualty ids"
	).is_empty()


# -------------------------------------------------------------------- debrief
func test_objectives_are_scored_by_their_book_weights() -> void:
	## Compendium pp.185, 201: a Vital Objective counts as 2 and a Critical as 3.
	## Completing the Vital and the Critical is a weighted total of 5 from two ticks,
	## and the literal count is carried alongside because p.203 Step 4 rolls 1D6 "for
	## every Objective you completed", which is the COUNT, not the weighted total.
	var out := Normalizer.normalize(
		_battle(), _stamp(), {"completed_objective_indices": [1, 2]})
	assert_int(out.get("objectives_completed", -1)).override_failure_message(
		"Vital (2) + Critical (3) must score 5, not 2"
	).is_equal(5)
	assert_int(out.get("objectives_completed_count", -1)).is_equal(2)
	assert_bool(out.get("mission_success", false)).is_true()
	assert_bool(out.get("court_martial_required", true)).is_false()


func test_four_or_more_signals_with_fewer_than_two_investigated_costs_an_objective() -> void:
	## p.201 verbatim: "if the mission had 4 or more signals initially, you must have
	## investigated at least 2 before Evac. Failure to do so means your Objective total
	## is reduced by 1."
	var stamp := _stamp({"use_signals": true, "signals_total": 4})
	var out := Normalizer.normalize(_battle(), stamp, {
		"completed_objective_indices": [0, 1], "signals_investigated": 1})
	assert_int(out.get("objectives_completed", -1)).override_failure_message(
		"1 + 2 = 3, less the p.201 penalty of 1, is 2"
	).is_equal(2)
	assert_bool(out.get("objectives_penalty_applied", false)).is_true()


func test_the_signals_penalty_does_not_apply_below_four_signals() -> void:
	## The other arm of the same rule, and the one a scorer that always subtracts
	## would fail. Three signals, none investigated, is no penalty at all.
	var stamp := _stamp({"use_signals": true, "signals_total": 3})
	var out := Normalizer.normalize(_battle(), stamp, {
		"completed_objective_indices": [0, 1], "signals_investigated": 0})
	assert_int(out.get("objectives_completed", -1)).is_equal(3)
	assert_bool(out.get("objectives_penalty_applied", true)).is_false()


func test_one_objective_is_a_failure_but_not_a_court_martial() -> void:
	## Two rules on one page that are easy to collapse into each other. p.201 sets the
	## success threshold at "Two or more ... for the purposes of awarding Experience
	## Points", and separately: "If you failed to complete any Objectives at all, you
	## may face a court martial." ANY -- so a single completed Objective is a failed
	## mission that raises NO court martial.
	var out := Normalizer.normalize(
		_battle(), _stamp(), {"completed_objective_indices": [0]})
	assert_int(out.get("objectives_completed", -1)).is_equal(1)
	assert_bool(out.get("mission_success", true)).override_failure_message(
		"one objective is below the p.201 threshold of two"
	).is_false()
	assert_bool(out.get("court_martial_required", true)).override_failure_message(
		"p.201 raises a court martial on ZERO objectives, not on falling short"
	).is_false()


func test_zero_objectives_raises_the_court_martial() -> void:
	## The arm that fired on EVERY played mission before the stamp existed.
	var out := Normalizer.normalize(
		_battle(), _stamp(), {"completed_objective_indices": []})
	assert_int(out.get("objectives_completed", -1)).is_equal(0)
	assert_bool(out.get("court_martial_required", false)).is_true()


func test_a_lost_marine_declaration_is_intersected_with_the_real_casualties() -> void:
	## p.202: "If a character exited the table via a battlefield edge, rather than
	## through Evac, use the Lost Marine column instead." Only a casualty can be a Lost
	## Marine, so a declaration naming someone who never went down is dropped rather
	## than sending an unharmed character to the Casualty table.
	var out := Normalizer.normalize(_battle(), _stamp(), {
		"lost_marine_ids": ["mc_cyr", "mc_ada"], "completed_objective_indices": [0]})
	assert_array(out.get("lost_marine_ids", [])).override_failure_message(
		"mc_ada was never a casualty, so they cannot be a Lost Marine"
	).contains_exactly(["mc_cyr"])


# ------------------------------------------------------------------- contract
func test_an_empty_debrief_writes_no_debrief_keys() -> void:
	## The two-stage property. On the battle RETURN there is no debrief yet, and the
	## normalizer must not answer questions the player has not been asked -- writing
	## `objectives_completed = 0` here would make the later debrief unable to raise it.
	var out := Normalizer.normalize(_battle(), _stamp(), {})
	assert_bool(out.has("objectives_completed")).override_failure_message(
		"an empty debrief must leave objectives_completed ABSENT, not zero"
	).is_false()
	assert_bool(out.has("mission_success")).is_false()
	assert_bool(out.has("court_martial_required")).is_false()
	assert_bool(out.has("debrief_recorded")).is_false()
	# ... and the battle facts are still there, which is what the first stage is for.
	assert_int(out.get("priority", -1)).is_equal(5)


func test_it_is_add_only_and_idempotent() -> void:
	## Add-only: a value already on the result wins, so an upstream producer is never
	## overwritten. Idempotent: the panel calls this again with the debrief after the
	## turn controller has already called it with an empty one, so a second pass must
	## not move an answer.
	var pre := _battle({"priority": 1, "casualty_ids": ["mc_ada"]})
	var once := Normalizer.normalize(pre, _stamp(), {"completed_objective_indices": [2]})
	assert_int(once.get("priority", -1)).override_failure_message(
		"an existing priority must survive -- the normalizer fills gaps, it does not correct"
	).is_equal(1)
	assert_array(once.get("casualty_ids", [])).contains_exactly(["mc_ada"])
	var twice := Normalizer.normalize(
		once.duplicate(true), _stamp(), {"completed_objective_indices": [2]})
	assert_int(twice.get("objectives_completed", -1)).is_equal(
		once.get("objectives_completed", -2))
	assert_int(twice.get("priority", -1)).is_equal(1)


func test_a_non_array_casualties_value_does_not_abort_the_normalizer() -> void:
	## `casualties` reaches this code as an int on some paths (BattleResultNormalizer
	## .casualty_count documents five shapes it has to tolerate). A typed
	## `var x: Array = results.casualties` against an int is a class-(b) runtime abort:
	## the enclosing function unwinds SILENTLY, so the whole post-battle sequence would
	## stop partway with nothing in the log. The reads are Variant-tested for that
	## reason, and this case is what proves it -- a return at all IS the assertion.
	##
	## Both readers are exercised: the malformed BATTLE values go through the shared
	## parser, and the malformed DEBRIEF field through the Bug Hunt normalizer's own.
	var odd := _battle({"casualties": 3, "units_downed": "not an array"})
	var out := Normalizer.normalize(odd, _stamp(), {
		"completed_objective_indices": [0], "lost_marine_ids": "mc_cyr"})
	assert_bool(out.get("bug_hunt_normalized", false)).override_failure_message(
		"the normalizer aborted on a non-Array result value instead of tolerating it"
	).is_true()
	assert_int(out.get("objectives_completed", -1)).is_equal(1)
	assert_array(out.get("lost_marine_ids", [null])).override_failure_message(
		"a malformed Lost Marine declaration must yield NO Lost Marines, not an abort"
	).is_empty()


func test_the_shared_parser_reads_the_battle_screen_the_same_way_for_both_modes() -> void:
	## The one structural thing 5PFH and Bug Hunt share: parsing TacticalBattleUI's
	## output. Two hand-written readers of one producer is how they drift apart, so
	## both chokepoints call BattleResultNormalizer.parse_crew_outcome -- and this case
	## pins that the Bug Hunt casualty ids ARE that parser's answer, not a second one.
	var battle := _battle()
	var parsed: Dictionary = Shared.parse_crew_outcome(battle.duplicate(true))
	var out := Normalizer.normalize(battle, _stamp(), {})
	assert_array(out.get("casualty_ids", [])).contains_exactly_in_any_order(
		parsed.get("downed_ids", []))
	assert_array(parsed.get("participant_ids", [])).contains_exactly_in_any_order(
		["mc_ada", "mc_bo", "mc_cyr"])
