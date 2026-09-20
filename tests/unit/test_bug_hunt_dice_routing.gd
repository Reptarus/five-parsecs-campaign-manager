extends GdUnitTestSuite
## Every Bug Hunt table roll goes through DiceManager, and every key the QA dialog
## offers reaches a live roll.
##
## WHY THIS EXISTS. Before Phase 3 of the Bug Hunt sprint, `DiceManager` had ZERO
## references anywhere under the Bug Hunt tree and 40 raw `randi_range` calls stood in
## for it. Nothing a Bug Hunt tester saw could be forced, so every rare row — an
## enlistment refusal, a commendation, a Service History that is a combat operation —
## was reachable only by grinding. That is the same wall that left T9-47, T9-48 and
## T9-51 stuck desk-verified for three weeks until `queue_forced_result()` landed
## (docs/qa/PICKUP_2026-08-14.md section 3).
##
## WHAT THE TWO HALVES PROVE.
##   Behavioural (cases 1-6): a value queued on the /root/DiceManager AUTOLOAD comes
##     back out of the real producer, end to end, through the same call the app makes.
##     This is the half a static scan cannot do: it proves the context string the
##     producer BUILDS at runtime matches the key the dialog OFFERS, including where
##     the context is assembled with a format specifier.
##   Census (cases 7-9): every Bug Hunt key in FORCEABLE_ROLLS has a live roll site,
##     no key is a substring of another, and no Bug Hunt key can be eaten by a 5PFH
##     roll or the reverse.
##
## ⚠ THE PRODUCERS REACH THE AUTOLOAD, NOT A FRESH INSTANCE. `test_dice_forced_results`
## builds its own DiceManager precisely so queued values cannot leak between cases; it
## can, because it calls that instance directly. These cases cannot — a RefCounted
## producer resolves `/root/DiceManager` itself. So `after_test()` clearing the queue is
## MANDATORY, not hygiene: an unconsumed value would ride the autoload into every later
## suite in the same process and surface as an unrelated flake.
##
## gdUnit4 v6.0.3.

const QADialog = preload("res://src/ui/screens/dev/QAScenarioDialog.gd")
const BHCharGen = preload("res://src/core/character/BugHuntCharacterGeneration.gd")
const BHBattleSetup = preload("res://src/core/battle/BugHuntBattleSetup.gd")
const TransferService = preload("res://src/core/character/CharacterTransferService.gd")
const FiveParsecsCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const BugHuntCore = preload("res://src/game/campaign/BugHuntCampaignCore.gd")

## Helpers that take a roll context and hand it ONWARD rather than rolling it
## themselves. The census walk below looks for a `roll_` call on the same line as a
## key's literal; these break that, because the literal sits at the call site and the
## roll happens one or two frames deeper with no literal in sight:
##
##   :649  _random_main_character(ctx, "Bug Hunt Subject Pick: Military Life")
##   :976      -> _pick()  ->  _roll_d100(context)
##
## The list is a relaxation, so it carries its own proof: test_every_declared_context
## _forwarder_actually_reaches_a_roll resolves each body and fails if the chain stops
## rolling. Without that, adding a name here would make its keys look live forever.
const CONTEXT_FORWARDERS: Array[String] = [
	"_random_participant",
	"_random_main_character",
	"_pick",
]

## Keys whose producer builds its context with a format specifier, so the literal on
## the roll line is a STEM and not the key. Asserted to be exactly this set in case 7 —
## if a third key starts needing the relaxed arm, that is a new runtime-assembled
## context and someone should look at it, not have it quietly accepted.
const EXPECTED_FORMATTED_KEYS: Array[String] = [
	"Bug Hunt Commendation: die 1",
	"Bug Hunt Commendation: die 2",
]

var _dm: Node = null


func before_test() -> void:
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")
	# INSTRUMENT THE PREMISE. If the autoload is absent every `queue_forced_result`
	# below is a no-op and every behavioural case would pass on whatever the RNG
	# happened to give — the "does not reproduce" shape from a probe that never
	# delivered its own stimulus.
	assert_object(_dm).override_failure_message(
		"/root/DiceManager did not resolve under the runner, so nothing below can "
		+ "force anything and every case would pass vacuously").is_not_null()
	_dm.clear_forced_results()


func after_test() -> void:
	# See the header: the queue lives on a shared autoload for the whole process.
	if _dm != null:
		_dm.clear_forced_results()


# ─────────────────────────────────────────────────────────── 0. the seam itself
func test_the_seam_is_armed_under_the_runner() -> void:
	## The other cases are only meaningful if forcing actually works here. Debug-build
	## gating means `queue_forced_result` returns false in a release export, and the
	## runner is a debug build — stated rather than assumed.
	assert_bool(OS.is_debug_build()).override_failure_message(
		"the runner is not a debug build, so the forced-roll seam is disabled and "
		+ "every behavioural case below is measuring the RNG").is_true()

	assert_bool(_dm.queue_forced_result("Bug Hunt Origin", 42)).is_true()
	var queued: Dictionary = _dm.get_forced_results()
	# The key is stored lowercased — matching is case-insensitive, so QA can type it
	# however they like and the dialog's own capitalisation is not load-bearing.
	assert_bool(queued.has("bug hunt origin")).override_failure_message(
		"expected the key stored lowercased, got %s" % str(queued.keys())).is_true()

	_dm.clear_forced_results()
	assert_dict(_dm.get_forced_results()).is_empty()


# ───────────────────────────────────────────── 1-2. character creation, pp.171-172
func test_character_creation_rolls_are_forceable_end_to_end() -> void:
	## All five creation rolls forced at once, then ONE call to the real producer.
	##
	## ⭐ This is the case the static census structurally cannot do. The commendation
	## context is built as `"Bug Hunt Commendation: die %d" % (i + 1)`, so no scan of
	## the source can prove the string that reaches DiceManager is the string the
	## dialog offers. Running it does.
	##
	## Expected values read out of data/bug_hunt/bug_hunt_character_creation.json,
	## not out of the dialog's `note` strings — a note is documentation, and pinning
	## a test to documentation pins the wrong thing.
	_dm.queue_forced_result("Bug Hunt Origin", 1)            # 1-9   Core systems world
	_dm.queue_forced_result("Bug Hunt Basic Training", 1)    # 1-15  Ground forces
	_dm.queue_forced_result("Bug Hunt Service History", 26)  # 26-40 Patrol in fringe-space
	_dm.queue_forced_result("Bug Hunt Commendation: die 1", 6)
	_dm.queue_forced_result("Bug Hunt Commendation: die 2", 1)

	var gen = BHCharGen.new()
	# A name is passed so _generate_random_name()'s own unrouted rolls stay out of it.
	var mc: Dictionary = gen.generate_main_character("Probe")

	assert_int(mc.get("origin_roll", -1)).is_equal(1)
	assert_str(str(mc.get("origin", ""))).is_equal("Core systems world")
	assert_int(mc.get("training_roll", -1)).is_equal(1)
	assert_str(str(mc.get("basic_training", ""))).is_equal("Ground forces (Infantry)")
	assert_int(mc.get("service_roll", -1)).is_equal(26)
	assert_str(str(mc.get("service_history", ""))).is_equal("Patrol in fringe-space")

	# Ground forces grants combat_skill +1 and toughness +1 over the 0/3 base.
	assert_int(mc.get("combat_skill", -99)).is_equal(1)
	assert_int(mc.get("toughness", -99)).is_equal(4)

	# Patrol in fringe-space is a combat operation, so the 2D6 commendation runs.
	# One 6 and one 1 is exactly one commendation: +1 XP and +1 Reputation.
	assert_int(mc.get("commendation_xp", -1)).is_equal(1)
	assert_int(mc.get("commendation_rep", -1)).is_equal(1)
	# 1 XP from the service advantage + 1 from the commendation.
	assert_int(mc.get("xp", -1)).is_equal(2)
	# 1 Reputation from Core systems world + 1 from the commendation.
	assert_int(mc.get("reputation_contribution", -1)).is_equal(2)

	# Every queued value was consumed by the roll it was meant for.
	assert_dict(_dm.get_forced_results()).override_failure_message(
		"a queued value was never consumed, so at least one context does not match "
		+ "its key: %s" % str(_dm.get_forced_results())).is_empty()


func test_an_unforced_generation_does_not_return_the_forced_rows() -> void:
	## Discrimination control. Without it, case 1 would still pass if
	## `generate_main_character` hardcoded those rows and never rolled at all.
	var gen = BHCharGen.new()
	var seen: Dictionary = {}
	for i: int in range(30):
		seen[gen.generate_main_character("Probe").get("origin_roll", 0)] = true
	assert_int(seen.size()).override_failure_message(
		"30 unforced generations produced a single origin_roll (%s) — the roll is "
		% str(seen.keys()) + "stuck, so case 1 proves nothing").is_greater(1)


# ─────────────────────────── 2b. a defect this suite MEASURED, pinned here
func test_generated_stats_are_ints_not_json_floats() -> void:
	## Godot's JSON parser returns EVERY number as a float, so `base_stats` handed
	## back 3.0 for Toughness and `_apply_stat_bonuses`'s `+=` kept it one. Measured
	## by case 1 against HEAD, before the coercion landed:
	##     line 119: Expecting: '1'  but was '1.000000'   (combat_skill)
	##     line 120: Expecting: '4'  but was '4.000000'   (toughness)
	##
	## Why it matters past the assertion: the float reaches to_dictionary() and the
	## save, and any surface that prints it with str() renders "3.0". That is
	## T11-33/T11-34, found on a real device walk against the 5PFH ship readout and
	## recorded verbatim at DisplayText.gd:12-17.
	##
	## Why a TYPE case sits in the DICE suite: it needs the forced-roll harness above
	## to make a generated character deterministic, and the seam is what measured it.
	## Case 1's two stat lines would also go red on a revert -- but with a bare
	## "unexpected type <float>" and no cause, so this case is the one that explains.
	var gen = BHCharGen.new()

	# Same three rows as case 1. Ground forces is the row that grants stat bonuses,
	# so forcing it is what puts _apply_stat_bonuses on the path at all.
	_dm.queue_forced_result("Bug Hunt Origin", 1)
	_dm.queue_forced_result("Bug Hunt Basic Training", 1)
	_dm.queue_forced_result("Bug Hunt Service History", 26)
	_dm.queue_forced_result("Bug Hunt Commendation: die 1", 6)
	_dm.queue_forced_result("Bug Hunt Commendation: die 2", 1)
	var mc: Dictionary = gen.generate_main_character("Probe")
	var grunt: Dictionary = gen.generate_grunt("Probe Grunt")

	# Premise. Without the bonus actually applying, the += site is never reached and
	# the types below would pass while that half of the fix was reverted.
	assert_int(int(mc.get("combat_skill", -99))).override_failure_message(
		"Ground forces did not grant its combat_skill +1, so _apply_stat_bonuses "
		+ "never ran and the type assertions below do not cover it").is_equal(1)

	for stat: String in ["reactions", "speed", "combat_skill", "toughness", "savvy"]:
		assert_int(typeof(mc.get(stat))).override_failure_message(
			# The whole sentence is parenthesised before the `%`: in GDScript `%` binds
			# tighter than `+`, so the unparenthesised form would format only the first
			# fragment. The first draft of this message did exactly that and ended
			# "is 1.0 ... so it serializes as 3.0", contradicting itself in one line --
			# a fixed illustration where the real value belongs.
			("main character stat '%s' is %s, a %s and not an int: a JSON float reached "
			+ "the character dict, so the save stores %s and str() prints '%s'")
			% [stat, str(mc.get(stat)), type_string(typeof(mc.get(stat))),
				str(mc.get(stat)), str(mc.get(stat))]
		).is_equal(TYPE_INT)
		assert_int(typeof(grunt.get(stat))).override_failure_message(
			"grunt stat '%s' is %s, a %s and not an int"
			% [stat, str(grunt.get(stat)), type_string(typeof(grunt.get(stat)))]
		).is_equal(TYPE_INT)


# ─────────────────────────────────────────────────── 3-4. battle setup, pp.191, 208
func test_signals_count_is_forceable_and_the_tactical_locations_follow_it() -> void:
	## p.208: roll 1D6 Signals; p.192: the six markers are shared, so tactical
	## locations are 6 minus the signals. Two arms, because a single arm could pass
	## against a hardcoded 6.
	var setup = BHBattleSetup.new()

	_dm.queue_forced_result("Bug Hunt Signals: count", 6)
	var all_signals: Dictionary = setup.generate_battle_context({"use_signals": true})
	assert_int((all_signals.get("signals", []) as Array).size()).is_equal(6)
	assert_int((all_signals.get("tactical_locations", []) as Array).size()).is_equal(0)

	_dm.clear_forced_results()
	_dm.queue_forced_result("Bug Hunt Signals: count", 2)
	var mixed: Dictionary = setup.generate_battle_context({"use_signals": true})
	assert_int((mixed.get("signals", []) as Array).size()).is_equal(2)
	assert_int((mixed.get("tactical_locations", []) as Array).size()).is_equal(4)


func test_tactical_location_type_is_forceable() -> void:
	## p.191: 1 Distract, 2-3 Block, 4-5 Neutralize, 6 Delay.
	##
	## ⚠ Only the FIRST location is forced. The type is rolled once per location in a
	## loop and a queued value is consumed exactly once, so this asserts the first and
	## says nothing about the rest — which is the honest scope, not a limitation to
	## paper over by queueing six values.
	var setup = BHBattleSetup.new()
	_dm.queue_forced_result("Bug Hunt Tactical Location: type", 6)

	var ctx: Dictionary = setup.generate_battle_context({})
	var locs: Array = ctx.get("tactical_locations", [])
	assert_int(locs.size()).is_equal(6)

	var first: Dictionary = locs[0]
	assert_int(first.get("d6_roll", -1)).is_equal(6)
	assert_str(str(first.get("name", ""))).is_equal("Delay")


# ─────────────────────────────────────────────────────── 5-6. enlistment, pp.212-214
func test_enlistment_dice_are_forceable_and_the_pass_boundary_is_exact() -> void:
	## p.212: 2D6 + Combat Skill, 7+ enlists. 6 and 1 with no Combat Skill is exactly
	## 7 — the boundary, where an off-by-one in the comparison shows up and a
	## comfortable pass would not.
	_dm.queue_forced_result("Bug Hunt Enlistment: die 1", 6)
	_dm.queue_forced_result("Bug Hunt Enlistment: die 2", 1)

	var svc = TransferService.new()
	var result: Dictionary = svc.attempt_enlistment({
		"id": "probe_enlist",
		"character_id": "probe_enlist",
		"name": "Probe",
		"character_name": "Probe",
		"game_mode": "standard",
		"status": "active",
		"combat_skill": 0,
	})

	assert_array(result.get("dice", [])).is_equal([6, 1])
	assert_int(result.get("roll", -1)).is_greater_equal(7)
	assert_bool(result.get("success", false)).is_true()


func test_a_forced_enlistment_refusal_reports_both_dice() -> void:
	## The failure branch is the one the QA dialog's `die 2 -> 1` row exists to reach,
	## and the only branch that surfaces `patron_bonus` and the Story Point rescue.
	##
	## ⚠ `patron_bonus` is NOT asserted to be 0. It is read off
	## GameState.current_campaign, and GameState._try_auto_load_last_campaign()
	## (GameState.gd:150) loads a campaign at every launch — so its value depends on
	## which suite ran before this one in the same process. Asserting the ARITHMETIC
	## identity instead is deterministic under either ambient state and still proves
	## the dice were forced. Snake eyes with combat 0 fails at 2 or 3 either way.
	_dm.queue_forced_result("Bug Hunt Enlistment: die 1", 1)
	_dm.queue_forced_result("Bug Hunt Enlistment: die 2", 1)

	var svc = TransferService.new()
	var result: Dictionary = svc.attempt_enlistment({
		"id": "probe_refuse",
		"character_id": "probe_refuse",
		"name": "Probe",
		"character_name": "Probe",
		"game_mode": "standard",
		"status": "active",
		"combat_skill": 0,
	})

	assert_array(result.get("dice", [])).is_equal([1, 1])
	var dice: Array = result.get("dice", [])
	assert_int(result.get("roll", -1)).is_equal(
		int(dice[0]) + int(dice[1])
		+ int(result.get("combat_bonus", 0)) + int(result.get("patron_bonus", 0)))
	assert_bool(result.get("success", true)).is_false()
	assert_bool(result.get("story_point_rescue_available", false)).is_true()


# ────────────────────────────────────────────────────────────── 7-9. the census
func test_every_bug_hunt_forceable_key_has_a_live_roll_context() -> void:
	## Copied in shape from test_final_partial_rows.gd's world-trait accessor census:
	## a key the dialog offers whose producer has been renamed or deleted is a dead
	## control, and a dead control in a QA tool is worse than a missing one — a tester
	## queues it, nothing happens, and they report the FEATURE as broken.
	##
	## Scoped to the Bug Hunt keys. The ten 5PFH keys are already pinned behaviourally
	## by test_dice_forced_results.gd and were walked on hardware (T9-47/48/51), and
	## two of them reach the autoload through MissionTableManager rather than calling
	## roll_d10/roll_d100 on a line of their own, so this rule would report them as
	## missing for a tooling reason.
	var keys: Array[String] = _bug_hunt_keys()
	assert_int(keys.size()).override_failure_message(
		"no Bug Hunt keys found in FORCEABLE_ROLLS — this case would pass vacuously"
	).is_greater(10)

	var sites: Array[String] = _roll_call_lines()
	assert_int(sites.size()).override_failure_message(
		"the source walk found %d roll-call lines — it is not reaching src/, so "
		% sites.size() + "every key below would report as missing").is_greater(100)

	var missing: Array[String] = []
	var needed_relaxation: Array[String] = []
	for key: String in keys:
		var lower := key.to_lower()
		var direct := false
		for line: String in sites:
			if line.contains(lower):
				direct = true
				break
		if direct:
			continue
		# Relaxed arm: the producer formats the context, e.g.
		#   "Bug Hunt Commendation: die %d" % (i + 1)
		# so the literal on the line is a stem. Only keys ending in a digit qualify,
		# which is exactly the enumerated-die shape.
		var stem := _digit_stem(lower)
		if stem != "" and _any_line_contains(sites, stem + "%"):
			needed_relaxation.append(key)
			continue
		missing.append(key)

	assert_array(missing).override_failure_message(
		"FORCEABLE_ROLLS offers keys that reach no roll in src/: %s\n"
		% str(missing) + "Either the producer was renamed and the dialog row is now "
		+ "a dead control, or the row was added ahead of its producer.").is_empty()

	# Assert the premise of the relaxed arm rather than letting it absorb anything.
	needed_relaxation.sort()
	var expected := EXPECTED_FORMATTED_KEYS.duplicate()
	expected.sort()
	assert_array(needed_relaxation).override_failure_message(
		"the set of keys whose context is assembled with a format specifier changed: "
		+ "expected %s, measured %s. A new one means a producer started building its "
		% [str(expected), str(needed_relaxation)]
		+ "context at runtime — read it before widening this list.").is_equal(expected)


func test_every_declared_context_forwarder_actually_reaches_a_roll() -> void:
	## CONTEXT_FORWARDERS relaxes the census above: a line that merely calls one of
	## these is accepted as reaching a roll. That is only honest while the chain really
	## terminates in one, so each body is resolved and checked here. A forwarder that
	## stopped rolling -- or was renamed out from under a stale entry -- fails here
	## instead of quietly certifying every key that flows through it.
	assert_int(CONTEXT_FORWARDERS.size()).override_failure_message(
		"no forwarders declared -- this case would pass vacuously").is_greater(0)

	var files: Array[String] = []
	_collect("res://src", files)
	var sources: Array[String] = []
	for path: String in files:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		sources.append(f.get_as_text())
		f.close()
	assert_int(sources.size()).override_failure_message(
		"the source walk read %d files -- it is not reaching src/" % sources.size()
		).is_greater(100)

	var broken: Array[String] = []
	for name: String in CONTEXT_FORWARDERS:
		var body := ""
		for text: String in sources:
			body = _function_body(text, name)
			if body != "":
				break
		if body == "":
			broken.append("%s is declared a forwarder but is defined nowhere in src/" % name)
			continue
		var reaches := body.contains("roll_")
		if not reaches:
			for other: String in CONTEXT_FORWARDERS:
				if other != name and body.contains(other + "("):
					reaches = true
					break
		if not reaches:
			broken.append(
				"%s forwards a roll context but its body neither rolls nor calls " % name
				+ "another declared forwarder, so the census is trusting a dead chain")
	assert_array(broken).override_failure_message(str(broken)).is_empty()


func test_no_forceable_key_is_a_substring_of_another() -> void:
	## DiceManager._take_forced (DiceManager.gd:102-121) returns on the FIRST queued
	## key whose lowercased form is contained in the roll context, in Dictionary
	## insertion order. If key A were a substring of key B, a value queued under A
	## would be eaten by a B roll — silently, and only when both happen to be armed.
	##
	## This is not hypothetical: "Bug Hunt Regiment: title part 1 reroll" was renamed
	## to "... title reroll" for exactly this reason
	## (BugHuntCharacterGeneration.gd:231-235).
	var keys: Array[String] = _all_keys()
	var collisions: Array[String] = []
	for a: String in keys:
		for b: String in keys:
			if a != b and b.to_lower().contains(a.to_lower()):
				collisions.append("%s -> eaten by -> %s" % [a, b])
	assert_array(collisions).override_failure_message(
		"forceable keys are not prefix-free: %s" % str(collisions)).is_empty()


func test_no_five_parsecs_key_matches_a_bug_hunt_roll_or_the_reverse() -> void:
	## Cross-mode safety. Every Bug Hunt context is prefixed "Bug Hunt", which is what
	## keeps a queued "Character Event" from being consumed by a Bug Hunt roll while a
	## tester walks one mode with the other armed. Asserted rather than trusted,
	## because the prefix is a convention and nothing enforces it.
	var bug_hunt: Array[String] = _bug_hunt_keys()
	var five_parsecs: Array[String] = []
	for key: String in _all_keys():
		if not key.to_lower().begins_with("bug hunt"):
			five_parsecs.append(key)
	assert_int(five_parsecs.size()).is_greater(5)

	var crossings: Array[String] = []
	for fp: String in five_parsecs:
		for bh: String in bug_hunt:
			if bh.to_lower().contains(fp.to_lower()):
				crossings.append("5PFH '%s' would be eaten by Bug Hunt '%s'" % [fp, bh])
			if fp.to_lower().contains(bh.to_lower()):
				crossings.append("Bug Hunt '%s' would be eaten by 5PFH '%s'" % [bh, fp])
	assert_array(crossings).override_failure_message(str(crossings)).is_empty()


# ─────────────────────────────────────────────── 10-11. the dialog's owner guard
func test_campaign_supports_scenarios_discriminates_the_four_cores() -> void:
	## The QA fixtures in data/qa_scenarios/ are deltas against a `crew_data` campaign
	## and are applied through GameStateManager setters, which write to
	## GameState.current_campaign — NOT to whatever campaign is on screen. Guarding on
	## the OWNER (does this campaign have crew_data?) rather than on a mode flag is
	## what stops a Bug Hunt session writing credits and story points into the
	## player's 5PFH save. Measured: FiveParsecsCampaignCore.gd mentions crew_data 24
	## times, BugHuntCampaignCore.gd zero.
	assert_bool(QADialog.campaign_supports_scenarios({"crew_data": {}})).is_true()
	assert_bool(QADialog.campaign_supports_scenarios({"main_characters": []})).is_false()

	var fp = FiveParsecsCore.new()
	assert_bool(QADialog.campaign_supports_scenarios(fp)).override_failure_message(
		"a real FiveParsecsCampaignCore must be supported, or the guard has disabled "
		+ "the fixtures for the mode they exist for").is_true()

	var bh = BugHuntCore.new()
	assert_bool(QADialog.campaign_supports_scenarios(bh)).override_failure_message(
		"a real BugHuntCampaignCore must NOT be supported").is_false()

	# Neither shape errors — the guard is reached from a dashboard that may hand it
	# anything, and an abort there would take the whole dialog with it.
	assert_bool(QADialog.campaign_supports_scenarios(null)).is_false()
	assert_bool(QADialog.campaign_supports_scenarios(7)).is_false()


func test_unsupported_campaign_text_names_the_mode_problem() -> void:
	## A disabled control with no explanation is indistinguishable from a broken one,
	## which is the blank-state lesson from deploy #35. The refusal must say which
	## half is disabled and why.
	var text: String = QADialog.unsupported_campaign_text()
	assert_str(text).contains("crew_data")
	assert_str(text.to_lower()).contains("5pfh-only")
	# ... and it must not read as "the whole dialog is useless here".
	assert_str(text.to_lower()).contains("forcing a roll")


# ──────────────────────────────────────────────────────────────────── helpers
func _all_keys() -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in QADialog.FORCEABLE_ROLLS:
		out.append(str(row.get("key", "")))
	return out


func _bug_hunt_keys() -> Array[String]:
	var out: Array[String] = []
	for key: String in _all_keys():
		if key.to_lower().begins_with("bug hunt"):
			out.append(key)
	return out


func _digit_stem(lower_key: String) -> String:
	## "bug hunt commendation: die 1" -> "bug hunt commendation: die ".
	## Empty when the key does not end in a digit, so the relaxed arm cannot apply.
	var end := lower_key.length()
	while end > 0 and lower_key[end - 1] >= "0" and lower_key[end - 1] <= "9":
		end -= 1
	if end == lower_key.length():
		return ""
	return lower_key.substr(0, end)


func _any_line_contains(lines: Array[String], needle: String) -> bool:
	for line: String in lines:
		if line.contains(needle):
			return true
	return false


func _roll_call_lines() -> Array[String]:
	## Every lowercased, comment-stripped line under src/ that calls something named
	## roll_*. QAScenarioDialog.gd is excluded: it holds the table, so every key would
	## match itself and the census would be a tautology.
	var files: Array[String] = []
	_collect("res://src", files)
	var out: Array[String] = []
	for path: String in files:
		if path.ends_with("QAScenarioDialog.gd"):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var text := f.get_as_text()
		f.close()
		for raw: String in text.split("\n"):
			var line := _strip_comment(raw)
			if line.contains("roll_") or _calls_a_forwarder(line):
				out.append(line.to_lower())
	return out


func _calls_a_forwarder(line: String) -> bool:
	## A CALL to a declared forwarder, not its definition. Without the `func` test the
	## definition line would be collected too -- harmless today (it carries no literal)
	## but it would make the walk report a forwarder as its own roll site.
	if line.strip_edges().begins_with("func "):
		return false
	for name: String in CONTEXT_FORWARDERS:
		if line.contains(name + "("):
			return true
	return false


func _function_body(text: String, fn_name: String) -> String:
	## The lines of `func fn_name(` up to the next top-level declaration. Returns ""
	## when the function is absent, which the caller treats as a failure rather than
	## as "nothing to check".
	var lines: PackedStringArray = text.split("\n")
	var i := 0
	while i < lines.size():
		if lines[i].begins_with("func " + fn_name + "("):
			break
		i += 1
	if i >= lines.size():
		return ""
	var body: Array[String] = []
	i += 1
	while i < lines.size():
		var line: String = lines[i]
		if line.length() > 0 and not (line[0] == "\t" or line[0] == " ") \
				and not line.strip_edges().is_empty():
			break
		body.append(_strip_comment(line))
		i += 1
	return "\n".join(body)


func _strip_comment(line: String) -> String:
	## Cut at the first '#' that is not inside a double-quoted string. Done by hand
	## rather than with a RegEx because the escaping needed for the string-or-comment
	## pattern is exactly where the equivalent Python probe broke twice.
	var in_string := false
	var i := 0
	while i < line.length():
		var c := line[i]
		if c == "\\" and in_string:
			i += 2
			continue
		if c == "\"":
			in_string = not in_string
		elif c == "#" and not in_string:
			return line.substr(0, i)
		i += 1
	return line


func _collect(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = d.get_next()
			continue
		var full := dir_path.path_join(entry)
		if d.current_is_dir():
			_collect(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()
