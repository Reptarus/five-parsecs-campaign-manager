extends GdUnitTestSuite
## Compendium pp.112-115 — the Faction subsystem downstream of generation.
##
## The whole engine existed and almost none of it ran. Eleven public entry points
## had ZERO callers; the ones that DID have callers were fed keys no producer
## wrote. The root was a single omission: `WorldPhaseController`'s mission_dict
## copies ~20 named keys off the accepted job and `faction_id` was not one of
## them, so the faction's identity died at the hand-off. RivalPatronResolver reads
## `battle_result["faction_id"]` to run the p.112 Loyalty gain, found "" every
## time, and Loyalty stayed 0 in every campaign that has ever been played — which
## silently disabled every rule that reads it:
##   p.112 Faction Favors      D6 <= Loyalty, so never
##   p.113 Office party        "Credits equal to their Loyalty rating", so 0
##   p.115 Befriending          "+1 Story Point" to your highest-loyalty faction
##   p.115 We thought we would  gated on 3+ Loyalty
##   p.115 Faction Destruction  vengeance Rival gated on 4+ Loyalty to the winner
##
## gdUnit4 v6.0.3 compatible.

const FactionSystemScript = preload("res://src/core/systems/FactionSystem.gd")

const WORLD_CONTROLLER_SRC := "res://src/ui/screens/world/WorldPhaseController.gd"
const NORMALIZER_SRC := "res://src/core/battle/BattleResultNormalizer.gd"
const JOB_OFFER_SRC := "res://src/ui/screens/world/components/JobOfferComponent.gd"
const PAYMENT_SRC := "res://src/core/campaign/phases/post_battle/PaymentProcessor.gd"
const UPKEEP_SRC := "res://src/ui/screens/world/components/UpkeepPhaseComponent.gd"
const FACTION_SRC := "res://src/core/systems/FactionSystem.gd"
const FACTIONS_JSON := "res://data/RulesReference/Factions.json"

var _sys: Node
var _saved_flag: bool = false


func _dlc() -> Node:
	return get_node_or_null("/root/DLCManager")


func before_test() -> void:
	# The whole chapter is paid Compendium content, and the gate is TWO-level
	# (owned AND toggled) with `_enabled_flags` defaulting false. A test that does
	# not enable it measures the gate rather than the rule — which is exactly what
	# the first run of this suite did: roll_loyalty_gain returned false 240/240
	# times and it looked like a rules failure.
	var dlc: Node = _dlc()
	if dlc:
		_saved_flag = dlc.is_feature_enabled(dlc.ContentFlag.EXPANDED_FACTIONS)
		dlc.set_feature_enabled(dlc.ContentFlag.EXPANDED_FACTIONS, true)
	_sys = auto_free(FactionSystemScript.new())
	add_child(_sys)
	_sys._load_faction_data()


func after_test() -> void:
	var dlc: Node = _dlc()
	if dlc:
		dlc.set_feature_enabled(dlc.ContentFlag.EXPANDED_FACTIONS, _saved_flag)


## The gate itself, asserted rather than assumed.
func test_the_whole_subsystem_is_gated_on_expanded_factions() -> void:
	var dlc: Node = _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(dlc.ContentFlag.EXPANDED_FACTIONS, false)
	_seed_faction("syndicate", 4, 4, 0)
	assert_bool(_sys.roll_loyalty_gain("syndicate", false)).override_failure_message(
		"Loyalty was gained with Expanded Factions OFF").is_false()
	assert_int((_sys.process_faction_activities("syndicate") as Array).size()) \
		.override_failure_message(
			"faction activities ran with Expanded Factions OFF").is_equal(0)


func _src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var t: String = f.get_as_text()
	f.close()
	return t


## Comment-stripped source. A scan that forbids a string must ignore comments, or
## the comment explaining the fix trips the test for the bug.
func _code_only(path: String) -> String:
	var out: PackedStringArray = []
	for line: String in _src(path).split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)


func _seed_faction(fid: String, power: int, influence: int, loyalty: int = 0) -> void:
	_sys.active_factions[fid] = {
		"name": fid.capitalize(), "power": power,
		"influence": influence, "loyalty": loyalty,
	}


# ── THE ROOT: the mission must carry the faction's identity ────────────────

func test_the_mission_dict_carries_the_faction_id() -> void:
	var src: String = _code_only(WORLD_CONTROLLER_SRC)
	assert_bool(src.contains("\"faction_id\": str(job_results.get(\"faction_id\", \"\"))")) \
		.override_failure_message(
			"WorldPhaseController's mission_dict no longer copies `faction_id` off"
			+ " the accepted job. Without it battle_result[\"faction_id\"] is \"\","
			+ " roll_loyalty_gain is never called, and Loyalty is permanently 0 —"
			+ " which disables Favors, Office party, Befriending and the 3+/4+ gates."
		).is_true()


## p.113: "If you did a job DIRECTLY for a Faction, always perform the Faction
## Struggle event. This does not occur for affiliated jobs." So faction_job_id is
## deliberately NOT a copy of faction_id — an affiliated Patron job carries the
## latter and must leave the former empty.
func test_faction_job_id_is_set_only_for_a_direct_faction_job() -> void:
	var src: String = _code_only(WORLD_CONTROLLER_SRC)
	assert_bool(src.contains("\"faction_job_id\"")).override_failure_message(
		"faction_job_id has no producer again — PostBattlePhase:554 reads it to"
		+ " fire the mandatory Faction Struggle").is_true()
	assert_bool(src.contains("if mission_source == \"faction\" else \"\"")) \
		.override_failure_message(
			"faction_job_id is no longer conditioned on a DIRECT faction job;"
			+ " p.113 excludes affiliated jobs from the mandatory Struggle").is_true()


func test_the_normalizer_carries_the_affiliation_flag() -> void:
	var src: String = _code_only(NORMALIZER_SRC)
	for key: String in ["faction_id", "faction_job_id", "is_affiliated_patron_job"]:
		assert_bool(src.contains("\"%s\"" % key)).override_failure_message(
			"BattleResultNormalizer no longer passes '%s' through; it dies at the" % key
			+ " chokepoint every path crosses").is_true()


func test_the_affiliation_roll_is_wired_and_remembered() -> void:
	var src: String = _code_only(JOB_OFFER_SRC)
	assert_bool(src.contains("check_affiliated_patron")).override_failure_message(
		"FactionSystem.check_affiliated_patron() is back to zero callers — no"
		+ " Patron job is flagged affiliated and the p.112 'a roll of a 6' branch"
		+ " is unreachable").is_true()
	assert_bool(src.contains("patron_faction_affiliation")).override_failure_message(
		"the affiliation is no longer remembered per patron. p.112 rolls it when"
		+ " the Patron is NEW; re-rolling every offer lets a contact drift in and"
		+ " out of a Faction and turns a flat 1/3 into 1-(2/3)^n").is_true()


# ── p.112 Gaining Loyalty ──────────────────────────────────────────────────

func test_loyalty_rises_on_a_direct_job_and_the_roll_matches_the_book() -> void:
	_seed_faction("syndicate", 3, 3, 0)
	# "If the roll is equal to or higher than your current Loyalty score, it is
	# raised by +1." At Loyalty 0 every D6 result qualifies.
	var gained := 0
	for _i in 30:
		_sys.set_faction_loyalty("syndicate", 0)
		if _sys.roll_loyalty_gain("syndicate", false):
			gained += 1
	assert_int(gained).override_failure_message(
		"at Loyalty 0 every D6 is >= 0, so a direct-job win must always gain"
	).is_equal(30)


func test_an_affiliated_job_only_gains_on_a_six() -> void:
	_seed_faction("syndicate", 3, 3, 0)
	var gained := 0
	for _i in 240:
		_sys.set_faction_loyalty("syndicate", 0)
		if _sys.roll_loyalty_gain("syndicate", true):
			gained += 1
	# p.112: "If this was an Affiliated Patron job, a roll of a 6 earns +1
	# Loyalty" — 1 in 6, versus the always-succeeds direct case above.
	assert_bool(gained > 15 and gained < 65).override_failure_message(
		"affiliated jobs gained %d/240; a 6-only rule is ~40. If it is ~240 the"
		% gained + " is_affiliated branch is being skipped and affiliated jobs are"
		+ " using the easier direct-job odds the book withholds from them").is_true()


# ── p.113 Faction Activities ───────────────────────────────────────────────

func test_the_mandatory_struggle_has_no_power_requirement() -> void:
	var src: String = _code_only(FACTION_SRC)
	var start: int = src.find("func process_faction_activities")
	var body: String = src.substr(start, src.find("\nfunc ", start + 10) - start)
	assert_bool(body.contains("_faction_struggle(job_faction, true)")) \
		.override_failure_message(
			"the mandatory p.113 Struggle is gated on Power again. 'If you did a"
			+ " job directly for a Faction, ALWAYS perform the Faction Struggle"
			+ " event' — the Power 3+ requirement belongs to the D100 row 61-75"
			+ " ACTIVITY, not to this").is_true()


func test_office_party_pays_credits_equal_to_loyalty() -> void:
	var src: String = _code_only(FACTION_SRC)
	var start: int = src.find("func _office_party")
	var body: String = src.substr(start, src.find("\nfunc ", start + 10) - start)
	assert_bool(body.contains("character.has_method(\"get_faction_loyalty\")")) \
		.override_failure_message(
			"Office party asks each crew CHARACTER for get_faction_loyalty(), a"
			+ " method Character does not have — the only definition repo-wide is"
			+ " on FactionSystem — so has_method is permanently false and the"
			+ " party pays 0 credits").is_false()
	assert_bool(body.contains("get_faction_loyalty(fid)")).override_failure_message(
		"Office party no longer reads the crew-vs-faction Loyalty score").is_true()


func test_the_two_mission_activities_do_not_call_a_method_that_does_not_exist() -> void:
	var src: String = _code_only(FACTION_SRC)
	assert_bool(src.contains("add_mission_opportunity")).override_failure_message(
		"`add_mission_opportunity` has ZERO definitions repo-wide, so every"
		+ " has_method() guard on it is permanently false. Plans within plans and"
		+ " Day to day operations both hung off one").is_false()


func test_day_to_day_operations_promises_a_job_next_turn() -> void:
	_seed_faction("guild", 3, 3)
	_sys._day_to_day_operations(_sys.active_factions["guild"])
	assert_bool(_sys.active_factions["guild"].get("offers_job_next_turn", false)) \
		.override_failure_message(
			"p.113 row 91-00 is 'Crew offered a job NEXT turn'").is_true()


## The flag has to survive the turn it was set on. process_faction_activities used
## to clear it in the same call, consuming the promise before anything could keep it.
func test_the_promised_job_is_not_cleared_by_the_activity_reset() -> void:
	var src: String = _code_only(FACTION_SRC)
	var start: int = src.find("func process_faction_activities")
	var body: String = src.substr(start, src.find("\nfunc ", start + 10) - start)
	assert_bool(body.contains("[\"offers_job_next_turn\"] = false")) \
		.override_failure_message(
			"process_faction_activities clears offers_job_next_turn in the same"
			+ " call that sets it, so 'next turn' never arrives. It is cleared"
			+ " where it is CONSUMED instead").is_false()


# ── p.115 Faction Destruction ──────────────────────────────────────────────

func test_a_stat_can_actually_reach_zero() -> void:
	_seed_faction("doomed", 1, 1)
	var f: Dictionary = _sys.active_factions["doomed"]
	_sys._decrease_highest_stat(f)
	# p.115: "If either Power or Influence is reduced to 0, the Faction ceases to
	# exist." A max(1, ...) clamp made that unreachable — the faction sat at 1/1
	# forever and kept acting.
	assert_bool(_sys.active_factions.has("doomed")).override_failure_message(
		"a faction at Power 1 / Influence 1 survived a further decrease — either"
		+ " the stat is clamped at 1 again or the destruction check is unwired."
		+ " Both were true before Aug 2026, and fixing only one changes nothing"
	).is_false()


func test_a_healthy_faction_is_not_destroyed() -> void:
	_seed_faction("strong", 4, 4)
	_sys._decrease_highest_stat(_sys.active_factions["strong"])
	assert_bool(_sys.active_factions.has("strong")).override_failure_message(
		"destruction now fires on a faction that is merely damaged").is_true()
	assert_int(int(_sys.active_factions["strong"]["power"])).is_equal(3)


## "Every time a Faction is destroyed, every remaining Faction rolls 1D6+Power.
## The highest score gains +1 Influence."
func test_survivors_scramble_for_influence_when_a_faction_dies() -> void:
	_seed_faction("doomed", 1, 1)
	_seed_faction("a", 3, 2)
	_seed_faction("b", 3, 2)
	var before: int = int(_sys.active_factions["a"]["influence"]) \
		+ int(_sys.active_factions["b"]["influence"])
	_sys._decrease_highest_stat(_sys.active_factions["doomed"])
	var after: int = int(_sys.active_factions["a"]["influence"]) \
		+ int(_sys.active_factions["b"]["influence"])
	assert_int(after).override_failure_message(
		"p.115: the survivors' 1D6+Power scramble grants at least +1 Influence"
	).is_greater(before)


# ── p.115 Faction Events ───────────────────────────────────────────────────

## Every row in the book's table needs a handler. Seven had none or set a flag
## that no consumer read, which is 49 of 100 rolls producing only journal text.
func test_every_event_row_the_book_prints_has_a_handler() -> void:
	var f := FileAccess.open(FACTIONS_JSON, FileAccess.READ)
	assert_object(f).is_not_null()
	var json := JSON.new()
	var ok: int = json.parse(f.get_as_text())
	f.close()
	assert_int(ok).is_equal(OK)
	var rows: Array = (json.data as Dictionary).get("factions", {}) \
		.get("faction_events", {}).get("table", [])
	assert_int(rows.size()).override_failure_message(
		"the p.115 Faction Event table should have 15 rows").is_equal(15)

	var handler_src: String = _code_only(FACTION_SRC)
	var start: int = handler_src.find("func _apply_faction_event")
	var body: String = handler_src.substr(
		start, handler_src.find("\nfunc ", start + 10) - start)
	var missing: PackedStringArray = []
	for row: Variant in rows:
		var name: String = str((row as Dictionary).get("event", ""))
		if not body.contains("\"%s\"" % name):
			missing.append("%s (%s)" % [name, str((row as Dictionary).get("roll", ""))])
	assert_int(missing.size()).override_failure_message(
		"p.115 rows with no handler at all: %s" % ", ".join(missing)).is_equal(0)


func test_truce_stops_the_whole_activity_step() -> void:
	_seed_faction("a", 4, 4)
	_seed_faction("b", 4, 4)
	_sys._apply_faction_event({"event": "Truce"})
	# "Calm reigns. Next turn, no Faction activities occur."
	var results: Array = _sys.process_faction_activities("")
	assert_int(results.size()).override_failure_message(
		"a Truce did not stop the activity step").is_equal(0)
	# ...and only for one turn.
	assert_int((_sys.process_faction_activities("") as Array).size()) \
		.override_failure_message("the Truce never expired").is_greater(0)


func test_tensions_rising_adds_one_danger_pay_and_is_spent_once() -> void:
	_sys._apply_faction_event({"event": "Tensions rising"})
	var mission := {"danger_pay": 0, "skip_danger_pay": true}
	_sys._apply_tensions_rising(mission, true)
	assert_int(int(mission["danger_pay"])).override_failure_message(
		"p.115 15-19: 'Faction jobs next turn increase Danger Pay by +1 Credit'"
	).is_equal(1)
	assert_bool(bool(mission["skip_danger_pay"])).override_failure_message(
		"the +1 must survive PaymentProcessor's non-patron Danger Pay zeroing"
	).is_false()


func test_the_favour_event_needs_three_loyalty() -> void:
	_seed_faction("friends", 3, 3, 2)
	var ev := {"event": "We thought we would do you a favor"}
	_sys._apply_faction_event(ev)
	assert_bool(ev.has("rival_eliminated")).override_failure_message(
		"p.115 88-93 is gated on 'Do you have 3+ Loyalty?' — 2 is not 3"
	).is_false()


# ── p.114 cross-references, both previously zero-caller ────────────────────

func test_the_strife_cross_reference_is_wired() -> void:
	var src: String = _code_only(PAYMENT_SRC)
	assert_bool(src.contains("process_strife_by_name")).override_failure_message(
		"FactionSystem.process_strife_by_name() is back to zero callers, so the"
		+ " p.114 Crackdown / Economic Collapse / Civil War effects on factions"
		+ " never fire").is_true()


func test_a_crackdown_stops_every_activity_not_just_one_faction() -> void:
	_seed_faction("a", 4, 4)
	_seed_faction("b", 4, 4)
	_sys.process_strife_by_name("crackdown")
	assert_int((_sys.process_faction_activities("a") as Array).size()) \
		.override_failure_message(
			"p.114: 'A Crackdown prevents ALL Faction activities this turn' — the"
			+ " old per-faction flag left the mandatory Struggle running through it"
		).is_equal(0)


func test_the_invasion_response_is_wired() -> void:
	var src: String = _code_only(UPKEEP_SRC)
	assert_bool(src.contains("process_invasion")).override_failure_message(
		"FactionSystem.process_invasion() is back to zero callers: an invaded"
		+ " world's factions neither flee nor dissolve, and the Power 5+ defenders"
		+ " contribute nothing to the p.126 Galactic War roll").is_true()
	assert_bool(src.contains("war_modifier")).override_failure_message(
		"the +1-per-defender bonus is not reaching the tracked planet's"
		+ " war_modifier, the field GalacticWarProcessor actually reads").is_true()
