extends GdUnitTestSuite
## The Compendium p.202 post-battle sequence, resolved once and applied once.
##
## WHY THIS EXISTS. On HEAD the post-battle sequence was spread across the panel and
## the phase manager, and it disagreed with the book in ways no test could see:
##   * `_process_casualties` read an EMPTY casualty list as "no battle data" and rolled
##     a 1-in-5 casualty per active marine, so a battle nobody was hurt in still
##     produced casualties.
##   * The tally was written +1 in the panel's Step 2, +1 again for every character who
##     received XP (which is everyone who took the field), and a third time by the
##     muster lookup -- so a character who played every mission was checked at 2, 4 ...
##     14, 16, never reached the p.203 rows for 13 or 15, and fell through the empty
##     16+ lookup FOREVER. They could not leave the army.
##   * Muster out was rolled for every main character including the ones in Sick Bay.
##   * A muster-out DELETED the veteran; no transfer file was ever written.
## Case 5 is the one that names the cost: fifteen missions in a row, checked at every
## row from 8 to 14 in order, leaving automatically at 15.
##
## WHAT THE THREE KINDS OF CASE PROVE.
##   Behavioural (0-9): a forced roll reaches the book's row and comes back out as the
##     effect the book describes, through the real resolver and the real data files.
##   Contract (10-12): the resolver's emitted op vocabulary matches the mutator's match
##     arms exactly; no roll context contains a second forceable key; the panel applies
##     no rule of its own. These are the three ways this slice can rot silently.
##   Integration (13): a muster_out op reaches CharacterTransferService and a file lands
##     in user://transfers/, which is the whole point of the p.203 rule.
##
## WHY THE VOCABULARY CASE IS NOT PEDANTRY. `_apply_post_battle_effect` is a `match` on
## a string. An op the resolver emits with no arm does NOTHING and reports NOTHING --
## the documented consumer-reads-a-key-no-producer-writes defect with the two halves
## swapped. Its own docblock names this suite as the guard.
##
## THE PRODUCER REACHES THE AUTOLOAD, NOT A FRESH INSTANCE, so `after_test()` clearing
## the forced queue is MANDATORY: an unconsumed value rides /root/DiceManager into every
## later suite in the same process and surfaces as an unrelated flake.
##
## gdUnit4 v6.0.3.

const Resolver = preload("res://src/core/campaign/BugHuntPostBattleResolver.gd")
const PhaseManager = preload("res://src/core/campaign/BugHuntPhaseManager.gd")
const BugHuntCore = preload("res://src/game/campaign/BugHuntCampaignCore.gd")
const QADialog = preload("res://src/ui/screens/dev/QAScenarioDialog.gd")

const RESOLVER_PATH := "res://src/core/campaign/BugHuntPostBattleResolver.gd"
const MUTATOR_PATH := "res://src/core/campaign/BugHuntPhaseManager.gd"
const PANEL_PATH := "res://src/ui/screens/bug_hunt/panels/BugHuntPostBattlePanel.gd"

## The ONE write the panel is allowed to make. It stamps the battle result onto
## `current_mission` so a force-stop between the battle and the debrief does not lose
## it; it applies no rule and decides nothing. Named here rather than excluded by a
## loose pattern, so a SECOND write cannot hide behind it.
const PANEL_ALLOWED_WRITE := "_campaign.current_mission = stamp"

## Core mutators that would mean the panel is applying a rule. The panel may READ the
## campaign freely -- it renders it.
const PANEL_BANNED_CALLS: Array[String] = [
	"add_main_character", "remove_main_character", "add_reputation", "spend_reputation",
	"add_to_sick_bay", "tick_sick_bay", "apply_assignments", "advance_turn",
]

const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
## The phase manager's persist() goes through GameState.save_campaign(), which also
## rewrites last_campaign: unguarded, the next process auto-loads this Bug Hunt core
## and a 5PFH suite reads its String difficulty (measured 2026-10-27, Sprint 3 gate).

var _dm: Node = null
var _user_state: Dictionary


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")
	# INSTRUMENT THE PREMISE. Without the autoload every queue_forced_result() below is
	# a no-op and every behavioural case passes on whatever the RNG happened to give --
	# the "does not reproduce" shape from a probe that never delivered its stimulus.
	assert_object(_dm).override_failure_message(
		"/root/DiceManager did not resolve under the runner, so nothing below can force "
		+ "anything and every behavioural case would pass vacuously").is_not_null()
	_dm.clear_forced_results()


func after_test() -> void:
	if _dm != null:
		_dm.clear_forced_results()
	SaveDirGuard.restore(_user_state)


# ──────────────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────────────

func _marine(id: String, cname: String, extra: Dictionary = {}) -> Dictionary:
	var m: Dictionary = {
		"id": id, "name": cname,
		"combat_skill": 1, "toughness": 3, "xp": 0,
		"completed_missions_count": 0,
	}
	for k in extra:
		m[k] = extra[k]
	return m


func _snapshot(chars: Array, battle: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var snap: Dictionary = {
		"characters": chars,
		"reputation": 0,
		"operational_progress_modifier": 0,
		"missions_in_current_operation": 0,
		"pending_military_life_rolls": 0,
		"sick_bay": {},
		"battle_result": battle,
	}
	for k in extra:
		snap[k] = extra[k]
	return snap


## Pin every roll this case does not care about, so a red case has exactly one cause.
## Operational Progress 50 is the p.205 41-55 "Stalemate" row (modifier 0) and Military
## Life 33 is the p.206 31-35 "Time flies" row (no effect keys) -- both chosen because
## they change nothing, and both asserted as such by case 12's data premise.
func _quiet() -> void:
	_dm.queue_forced_result("Bug Hunt Operational Progress", 50)
	_dm.queue_forced_result("Bug Hunt Military Life", 33)
	_dm.queue_forced_result("Bug Hunt Military Life", 33)
	_dm.queue_forced_result("Bug Hunt Muster Out", 2)
	for i in range(4):
		_dm.queue_forced_result("Bug Hunt Reputation", 1)


func _ops(receipt: Dictionary, op: String) -> Array:
	var out: Array = []
	for e in receipt.get("effects", []):
		if e is Dictionary and str(e.get("op", "")) == op:
			out.append(e)
	return out


func _step(receipt: Dictionary, index: int) -> Dictionary:
	for s in receipt.get("steps", []):
		if s is Dictionary and int(s.get("step", -1)) == index:
			return s
	return {}


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("could not open %s" % path).is_not_null()
	var text: String = f.get_as_text()
	f.close()
	return text


# ──────────────────────────────────────────────────────────────────────────────
# 0 — premise
# ──────────────────────────────────────────────────────────────────────────────

func test_the_forcing_seam_is_armed() -> void:
	assert_bool(OS.is_debug_build()).override_failure_message(
		"queue_forced_result() is gated on OS.is_debug_build(); in a release build "
		+ "every behavioural case below would silently roll at random").is_true()
	_dm.queue_forced_result("Bug Hunt Court Martial", 1)
	assert_int(_dm.roll_d6("Bug Hunt Court Martial: probe")).is_equal(1)


# ──────────────────────────────────────────────────────────────────────────────
# 1-2 — Court Martial (p.201)
# ──────────────────────────────────────────────────────────────────────────────

func test_court_martial_is_skipped_when_an_objective_was_completed() -> void:
	_quiet()
	_dm.queue_forced_result("Bug Hunt Court Martial", 1)
	var receipt: Dictionary = Resolver.new().resolve(_snapshot(
		[_marine("a", "Alpha")],
		{"participant_ids": ["a"], "objectives_completed": 1}))
	# The forced 1 is still sitting in the queue, unconsumed, which is the proof the
	# roll never happened -- a 1 that WAS rolled would have removed the leader.
	assert_array(_ops(receipt, "remove_character")).override_failure_message(
		"p.201 Court Martial is rolled only when NO objective was completed; one "
		+ "objective was, and the leader was removed anyway").is_empty()


func test_court_martial_removes_the_mission_leader_on_a_forced_one() -> void:
	_quiet()
	_dm.queue_forced_result("Bug Hunt Court Martial", 1)
	var receipt: Dictionary = Resolver.new().resolve(_snapshot(
		[_marine("a", "Alpha"), _marine("b", "Bravo")],
		{"participant_ids": ["a", "b"], "objectives_completed": 0,
			"mission_leader_id": "b"}))
	var removed: Array = _ops(receipt, "remove_character")
	assert_int(removed.size()).is_equal(1)
	assert_str(str(removed[0].get("target", ""))).is_equal("b")
	# The buyout is a CHOICE that cancels the removal, never a write that undoes one.
	assert_str(str(removed[0].get("cancel_choice", ""))).is_equal("court_martial_buyout")


## p.202/p.203: a character who leaves "for any other reason" is replaced. A Court
## Martial removal used to be the one exit with no replacement, so the squad shrank
## permanently. The buyout must cancel the replacement too, or saving the leader
## would ALSO roll up a new character.
func test_a_court_martial_removal_is_replaced_unless_bought_out() -> void:
	_quiet()
	_dm.queue_forced_result("Bug Hunt Court Martial", 1)
	var receipt: Dictionary = Resolver.new().resolve(_snapshot(
		[_marine("a", "Alpha"), _marine("b", "Bravo")],
		{"participant_ids": ["a", "b"], "objectives_completed": 0,
			"mission_leader_id": "b"}))
	var replaced: Array = _ops(receipt, "replace_character")
	assert_int(replaced.size()).override_failure_message(
		"p.202: a Court Martial removal must roll up a replacement").is_equal(1)
	assert_str(str(replaced[0].get("cancel_choice", ""))).is_equal("court_martial_buyout")


## p.203: "You may opt to retire an injured trooper if you like. If so, they are
## removed from your roster. Dead, removed, and retired troopers are replaced at this
## stage." p.213: a retiree may carry over into 5PFH, so a retirement is the muster-out
## op (which writes the transfer file) plus the replacement. A trooper ALREADY in Sick
## Bay is offered it too, and declining changes nothing.
func test_an_injured_trooper_may_retire_and_is_replaced() -> void:
	_quiet()
	var receipt: Dictionary = Resolver.new().resolve(_snapshot(
		[_marine("a", "Alpha", {"completed_missions_count": 4}), _marine("b", "Bravo")],
		{"participant_ids": ["b"], "objectives_completed": 1},
		{"sick_bay": {"a": 2}}))
	var offered: Array = []
	for c in receipt.get("choices_needed", []):
		if c is Dictionary and str(c.get("kind", "")) == "retire_injured":
			offered.append(c)
	assert_int(offered.size()).override_failure_message(
		"p.203: the trooper in Sick Bay must be offered retirement").is_equal(1)
	assert_str(str(offered[0].target)).is_equal("a")
	var declined: Dictionary = Resolver.apply_choices(receipt, {str(offered[0].id): false})
	assert_array(declined.effects).is_empty()
	var retired: Dictionary = Resolver.apply_choices(receipt, {str(offered[0].id): true})
	var ops: Array = []
	for e in retired.effects:
		ops.append(str(e.op))
	assert_array(ops).contains_exactly(["muster_out", "replace_character"])
	assert_int(int(retired.effects[0].amount)) \
		.override_failure_message("p.213 mustering credits read the Completed Missions") \
		.is_equal(4)


# ──────────────────────────────────────────────────────────────────────────────
# 3-4 — Casualties (p.202)
# ──────────────────────────────────────────────────────────────────────────────

func test_a_forced_gruesome_fate_kills_and_replaces() -> void:
	_quiet()
	_dm.queue_forced_result("Bug Hunt Casualty", 1) # p.202 01-05, is_dead
	var receipt: Dictionary = Resolver.new().resolve(_snapshot(
		[_marine("a", "Alpha")],
		{"participant_ids": ["a"], "casualty_ids": ["a"], "objectives_completed": 1}))
	assert_int(_ops(receipt, "kill").size()).is_equal(1)
	assert_str(str(_ops(receipt, "kill")[0].get("target", ""))).is_equal("a")
	# p.203: "If a main character leaves for any reason, a new character is rolled up."
	assert_int(_ops(receipt, "replace_character").size()).is_equal(1)
	# A dead marine is not also put in Sick Bay or paid XP.
	assert_array(_ops(receipt, "set_sick_bay")).is_empty()
	assert_array(_ops(receipt, "add_xp")).is_empty()


func test_a_survivable_casualty_row_sets_sick_bay_from_the_rolled_formula() -> void:
	_quiet()
	_dm.queue_forced_result("Bug Hunt Casualty", 16)     # p.202 16-24 Leg wound, 1D3
	_dm.queue_forced_result("Bug Hunt Recovery Time", 6) # 1D3 is ceil(1D6/2) -> 3
	var receipt: Dictionary = Resolver.new().resolve(_snapshot(
		[_marine("a", "Alpha")],
		{"participant_ids": ["a"], "casualty_ids": ["a"], "objectives_completed": 1}))
	var sick: Array = _ops(receipt, "set_sick_bay")
	assert_int(sick.size()).is_equal(1)
	assert_int(int(sick[0].get("amount", 0))).override_failure_message(
		"1D3 is rolled as ceil(1D6/2), so a forced 6 must be 3 Sick Bay turns"
		).is_equal(3)
	assert_array(_ops(receipt, "kill")).is_empty()


# ──────────────────────────────────────────────────────────────────────────────
# 5-6 — Tally and muster out (p.203)
# ──────────────────────────────────────────────────────────────────────────────

func test_the_tally_skips_a_character_who_started_the_turn_in_sick_bay() -> void:
	_quiet()
	var receipt: Dictionary = Resolver.new().resolve(_snapshot(
		[_marine("a", "Alpha"), _marine("b", "Bravo")],
		{"participant_ids": ["a", "b"], "objectives_completed": 1},
		{"sick_bay": {"b": 2}}))
	var tallies: Array = _ops(receipt, "tally")
	assert_int(tallies.size()).override_failure_message(
		"p.203: +1 for each character that took the field; characters in Sick Bay do "
		+ "not update. Two tallies means the Sick Bay marine was counted").is_equal(1)
	assert_str(str(tallies[0].get("target", ""))).is_equal("a")
	# One mission played, whoever took the field -- the counter R&R (p.206) reads.
	assert_int(_ops(receipt, "total_missions_played").size()).is_equal(1)


func test_a_fifteen_mission_career_is_checked_at_every_row_and_leaves_automatically() -> void:
	## p.203 rows: 1-4 no check, 5-7 only after a casualty, 8-9 vs 9, 10-11 vs 8,
	## 12 vs 7, 13 vs 6, 14 vs 5, 15+ automatic. So a clean career is checked seven
	## times, at falling targets, and then leaves.
	##
	## On HEAD the same career was checked at 2, 4, 6 ... (the tally ran three times
	## per mission) and fell through the 16+ lookup forever.
	var targets: Array[int] = []
	var completed: int = 0
	var in_operation: int = 0
	var left_at: int = -1
	var leave_reason: String = ""

	for mission in range(1, 16):
		_dm.clear_forced_results()
		_quiet()
		var snap: Dictionary = _snapshot(
			[_marine("vet", "Vet", {"completed_missions_count": completed})],
			{"participant_ids": ["vet"], "objectives_completed": 1},
			{"missions_in_current_operation": in_operation})
		var receipt: Dictionary = Resolver.new().resolve(snap)

		for r in _step(receipt, 3).get("rolls", []):
			targets.append(int(r.get("target", 0)))

		var outs: Array = _ops(receipt, "muster_out")
		if not outs.is_empty():
			left_at = mission
			leave_reason = str(outs[0].get("reason", ""))
			break

		completed += _ops(receipt, "tally").size()
		in_operation += 1
		if not _ops(receipt, "rest_and_recuperation").is_empty():
			in_operation = 0

	assert_array(targets).override_failure_message(
		"p.203 must check a career marine at 9, 9, 8, 8, 7, 6, 5 as their completed "
		+ "missions run 8..14; got %s" % str(targets)).is_equal([9, 9, 8, 8, 7, 6, 5])
	assert_int(left_at).override_failure_message(
		"p.203: 15 completed missions is an automatic muster out").is_equal(15)
	assert_str(leave_reason).is_equal("automatic")


# ──────────────────────────────────────────────────────────────────────────────
# 7-9 — Reputation, Operational Progress, Military Life, R&R (pp.203-206)
# ──────────────────────────────────────────────────────────────────────────────

func test_reputation_pays_the_auto_award_and_the_per_objective_dice() -> void:
	_dm.queue_forced_result("Bug Hunt Operational Progress", 50)
	_dm.queue_forced_result("Bug Hunt Military Life", 33)
	_dm.queue_forced_result("Bug Hunt Military Life", 33)
	_dm.queue_forced_result("Bug Hunt Muster Out", 2)
	_dm.queue_forced_result("Bug Hunt Reputation", 5) # objective 1: 5-6 pays
	_dm.queue_forced_result("Bug Hunt Reputation", 1) # objective 2: nothing
	var receipt: Dictionary = Resolver.new().resolve(_snapshot(
		[_marine("a", "Alpha")],
		{"participant_ids": ["a"], "objectives_completed": 2}))
	var rep: Array = _ops(receipt, "reputation")
	assert_int(rep.size()).is_equal(1)
	assert_int(int(rep[0].get("amount", 0))).override_failure_message(
		"p.203: 2+ objectives pays +1, then 1D6 per objective with 5-6 paying +1 "
		+ "each. A forced 5 then a forced 1 is +1 +1 = 2").is_equal(2)


func test_operational_progress_rolls_over_one_hundred_into_the_campaign_victory() -> void:
	_dm.queue_forced_result("Bug Hunt Military Life", 33)
	_dm.queue_forced_result("Bug Hunt Military Life", 33)
	_dm.queue_forced_result("Bug Hunt Muster Out", 2)
	_dm.queue_forced_result("Bug Hunt Reputation", 1)
	_dm.queue_forced_result("Bug Hunt Operational Progress", 100)
	var receipt: Dictionary = Resolver.new().resolve(_snapshot(
		[_marine("a", "Alpha")],
		{"participant_ids": ["a"], "objectives_completed": 1},
		{"operational_progress_modifier": 5}))
	assert_int(_ops(receipt, "campaign_victory").size()).override_failure_message(
		"p.205 above_100 is the Parade row -- the ONLY way a Bug Hunt campaign is won. "
		+ "A forced 100 with a +5 modifier totals 105 and must reach it").is_equal(1)


func test_military_life_time_in_the_brig_reaches_its_two_effects() -> void:
	_dm.queue_forced_result("Bug Hunt Operational Progress", 50)
	_dm.queue_forced_result("Bug Hunt Muster Out", 2)
	_dm.queue_forced_result("Bug Hunt Reputation", 1)
	_dm.queue_forced_result("Bug Hunt Military Life", 16) # p.206 16-20
	var receipt: Dictionary = Resolver.new().resolve(_snapshot(
		[_marine("a", "Alpha")],
		{"participant_ids": ["a"], "objectives_completed": 1}))
	var rep: Array = _ops(receipt, "reputation")
	assert_int(rep.size()).is_equal(1)
	assert_int(int(rep[0].get("amount", 0))).is_equal(-1)
	var flags: Array = _ops(receipt, "military_life_flag")
	assert_int(flags.size()).is_equal(1)
	assert_str(str(flags[0].get("flag", ""))).override_failure_message(
		"p.206 Time in the Brig is -1 Reputation AND miss the next mission; the "
		+ "second half is a persisted flag, not prose").is_equal("miss_next_mission")


func test_rest_and_recuperation_lands_on_the_fourth_mission_of_the_operation() -> void:
	_quiet()
	var third: Dictionary = Resolver.new().resolve(_snapshot(
		[_marine("a", "Alpha")],
		{"participant_ids": ["a"], "objectives_completed": 1},
		{"missions_in_current_operation": 2, "reputation": 3}))
	assert_array(_ops(third, "rest_and_recuperation")).override_failure_message(
		"p.206 R&R is earned after four missions; this is the third").is_empty()
	# With Reputation in hand the book offers it early for 1 Reputation -- a CHOICE.
	var early: bool = false
	for c in third.get("choices_needed", []):
		if c is Dictionary and str(c.get("kind", "")) == "early_rr":
			early = true
	assert_bool(early).is_true()

	_dm.clear_forced_results()
	_quiet()
	var fourth: Dictionary = Resolver.new().resolve(_snapshot(
		[_marine("a", "Alpha")],
		{"participant_ids": ["a"], "objectives_completed": 1},
		{"missions_in_current_operation": 3, "reputation": 3}))
	assert_int(_ops(fourth, "rest_and_recuperation").size()).override_failure_message(
		"p.206: entitled to R&R after every 4 missions in the current operation"
		).is_equal(1)
	# ONE compound op. The extra Sick Bay tick and the operation reset are both the
	# mutator's, so they cannot drift apart or be applied from two emission sites.
	assert_int(_ops(fourth, "missions_in_operation").size()).is_equal(1)


# ──────────────────────────────────────────────────────────────────────────────
# 10-12 — contract
# ──────────────────────────────────────────────────────────────────────────────

func test_every_emitted_op_has_a_mutator_arm() -> void:
	var emitted: Array[String] = []
	var re := RegEx.create_from_string('"op"\\s*:\\s*"([a-z_]+)"')
	for m in re.search_all(_read(RESOLVER_PATH)):
		var op: String = m.get_string(1)
		if not (op in emitted):
			emitted.append(op)
	emitted.sort()

	# The arms of `match op:` inside _apply_post_battle_effect, which are the only
	# consumers of that vocabulary.
	var mutator: String = _read(MUTATOR_PATH)
	var start: int = mutator.find("match op:")
	assert_int(start).override_failure_message(
		"_apply_post_battle_effect no longer contains `match op:`; this case is "
		+ "measuring nothing").is_greater(-1)
	var body: String = mutator.substr(start)
	var next_func: int = body.find("\nfunc ")
	if next_func > 0:
		body = body.substr(0, next_func)
	# GDScript allows ONE arm to answer several ops -- `"kill", "remove_character":`
	# is a single arm covering two. A pattern anchored on `":` therefore skips that
	# whole line and reports both ops as unhandled, which is exactly what the first
	# run of this case did: a FALSE finding against correct code. Match the arm LINE,
	# then take every name on it.
	var handled: Array[String] = []
	var arm := RegEx.create_from_string('(?m)^\\t\\t("[a-z_]+"(?:\\s*,\\s*"[a-z_]+")*)\\s*:')
	var name_re := RegEx.create_from_string('"([a-z_]+)"')
	for m in arm.search_all(body):
		for n in name_re.search_all(m.get_string(1)):
			handled.append(n.get_string(1))
	assert_int(handled.size()).override_failure_message(
		"the match-arm regex found no arms, so every emitted op would read as "
		+ "unhandled and this case would fail for its own reason").is_greater(10)

	assert_int(emitted.size()).override_failure_message(
		"the op regex matched nothing, so this case cannot fail").is_greater(10)
	var missing: Array[String] = []
	for op in emitted:
		if not (op in handled):
			missing.append(op)
	assert_array(missing).override_failure_message(
		"BugHuntPostBattleResolver emits %s with no arm in "
		% str(missing) + "_apply_post_battle_effect, so the effect is computed, "
		+ "carried through the receipt and then silently dropped").is_empty()

	var orphan: Array[String] = []
	for op in handled:
		if not (op in emitted):
			orphan.append(op)
	assert_array(orphan).override_failure_message(
		"_apply_post_battle_effect handles %s, which nothing emits -- either a "
		% str(orphan) + "producer was removed or the arm is misspelt").is_empty()


func test_no_roll_context_contains_a_second_forceable_key() -> void:
	## A forced value is taken by the FIRST queued key CONTAINED in the roll's context
	## (DiceManager.gd:104, case-insensitive substring). So a sub-roll whose context
	## carries a parent table's key STEALS the value queued for the table, and the row
	## the tester asked for never comes up -- the seam looks broken while behaving
	## exactly as documented. That is a real defect found in this resolver's first
	## draft; the four sub-rolls were renamed for it.
	var keys: Array[String] = []
	for row in QADialog.FORCEABLE_ROLLS:
		if row is Dictionary:
			var k: String = str(row.get("key", ""))
			if k.begins_with("Bug Hunt"):
				keys.append(k.to_lower())
	assert_int(keys.size()).override_failure_message(
		"no Bug Hunt rows in FORCEABLE_ROLLS; this case is measuring nothing"
		).is_greater(10)

	var contexts: Array[String] = []
	var re := RegEx.create_from_string('_roll_(?:d6|d100|2d6)\\(\\s*"([^"]+)"')
	for m in re.search_all(_read(RESOLVER_PATH)):
		# A format string's stem is what a key can match; everything from the first
		# specifier on is runtime text.
		var stem: String = m.get_string(1)
		var pct: int = stem.find("%")
		if pct >= 0:
			stem = stem.substr(0, pct)
		if not (stem in contexts):
			contexts.append(stem)
	assert_int(contexts.size()).override_failure_message(
		"the roll-context regex matched nothing").is_greater(5)

	var collisions: Array[String] = []
	for ctx in contexts:
		var hits: Array[String] = []
		for k in keys:
			if ctx.to_lower().contains(k):
				hits.append(k)
		if hits.size() > 1:
			collisions.append("%s -> %s" % [ctx, str(hits)])
	assert_array(collisions).override_failure_message(
		"these roll contexts match more than one forceable key, so the first queued "
		+ "one wins and the other is never consumed: %s" % str(collisions)).is_empty()


func test_the_panel_applies_no_rules_of_its_own() -> void:
	## Phase 5 moved every p.202 decision into the resolver and every write into
	## BugHuntPhaseManager. The panel renders the receipt and collects choices.
	var source: String = _read(PANEL_PATH)
	var lines: PackedStringArray = source.split("\n")
	var writes := RegEx.create_from_string('_campaign\\.[A-Za-z_]+\\s*(=[^=]|\\+=|-=)')
	var offences: Array[String] = []

	for i in range(lines.size()):
		var line: String = lines[i]
		var m := writes.search(line)
		if m != null:
			var hash_at: int = line.find("#")
			# A `#` before the match means the match is inside a comment. (A `#`
			# inside a STRING before the match would make this miss a real write --
			# a false negative, never a false alarm.)
			var commented: bool = hash_at >= 0 and hash_at < m.get_start()
			if not commented and not line.contains(PANEL_ALLOWED_WRITE):
				offences.append("%d: %s" % [i + 1, line.strip_edges()])
		for banned in PANEL_BANNED_CALLS:
			if line.contains("_campaign.%s(" % banned):
				offences.append("%d: calls %s" % [i + 1, banned])

	assert_array(offences).override_failure_message(
		"BugHuntPostBattlePanel must be presentation-only; these lines write to the "
		+ "campaign or call a core mutator: %s" % str(offences)).is_empty()
	# The allowed write must still BE there -- if the resume stamp is deleted, this
	# case would pass for the wrong reason and a force-stop would lose the battle.
	assert_bool(source.contains(PANEL_ALLOWED_WRITE)).override_failure_message(
		"the one allowed panel write (the current_mission resume stamp) is gone, so "
		+ "the allowance above is now excusing nothing and should be removed").is_true()
	# A text scan proves the right words are present, never that the file COMPILES.
	assert_bool(load(PANEL_PATH).can_instantiate()).is_true()


# ──────────────────────────────────────────────────────────────────────────────
# 13 — integration: the veteran leaves, they are not deleted
# ──────────────────────────────────────────────────────────────────────────────

func test_a_muster_out_effect_writes_a_transfer_file() -> void:
	# PREMISE, and the reason it is asserted rather than assumed: this case deletes
	# the DIFFERENCE between two listings of user://transfers/. An unreadable listing
	# here is not a nuisance -- it makes every veteran ALREADY waiting for pickup look
	# like a file this test wrote. That is the 2026-09-21 save-directory deletion, one
	# directory over. Refuse rather than guess.
	var before = _transfer_files()
	assert_bool(before is Array).override_failure_message(
		"premise: user://transfers/ exists and could not be listed, so nothing below "
		+ "can tell a file this test wrote from a mustered-out veteran waiting to be "
		+ "picked up. Refusing to compute a difference against an unknown before-set."
		).is_true()
	if not (before is Array):
		return

	var core = BugHuntCore.new()
	core.add_main_character(_marine("vet", "Vet", {"completed_missions_count": 15}))
	var pm = PhaseManager.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)

	pm._apply_post_battle_effect({
		"op": "muster_out", "target": "vet", "amount": 15, "reason": "automatic",
	})

	var after = _transfer_files()
	assert_bool(after is Array).override_failure_message(
		"user://transfers/ could not be listed after the muster out, so the cleanup "
		+ "below would have to guess which file this test wrote"
		).is_true()
	if not (after is Array):
		return
	var added: Array = []
	for f in after:
		if not (f in before):
			added.append(f)

	assert_int(added.size()).override_failure_message(
		"p.203: a marine whose term is up LEAVES THE ARMY. On HEAD remove_main_character() "
		+ "was called alone and the veteran was deleted with nothing written anywhere"
		).is_equal(1)
	assert_int(core.main_characters.size()).override_failure_message(
		"the marine must also leave the squad once the destination file is written"
		).is_equal(0)

	for f in added:
		DirAccess.remove_absolute("user://transfers/".path_join(f))


## Names in user://transfers/, or NULL when the directory exists and could not be
## read. The null is the whole point. Returning [] there is indistinguishable from
## an empty directory, and the one caller SUBTRACTS this listing from a later one
## and deletes the remainder -- so an empty-because-unreadable before-set nominates
## every pending transfer on disk. A pending transfer is a mustered-out veteran who
## exists in no campaign until a dashboard picks them up: the file IS the character.
##
## Mirrors tests/fixtures/helpers/save_dir_guard.gd::_list_saves(), which was given
## the same distinction on 2026-09-21 after the ambiguity it had cost 238 real saves.
func _transfer_files() -> Variant:
	if not DirAccess.dir_exists_absolute("user://transfers"):
		return []  # nothing there yet is a real, knowable empty
	var dir := DirAccess.open("user://transfers")
	if dir == null:
		return null
	var out: Array = []
	for f in dir.get_files():
		out.append(f)
	return out
