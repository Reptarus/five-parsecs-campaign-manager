extends GdUnitTestSuite
## T9-43 (tablet, Aug 13 2026) — the Encounter Log printed a battle that had just
## awarded 14 XP and a Shock Attachment as "0 XP, 0 loot", with every scenario box
## blank.
##
## Three independent causes, each sufficient on its own, all of the SAME shape:
## a value is produced correctly and then dropped between the producer and the
## consumer.
##
##   1. `PostBattlePhase:329` called `_loot.process_loot_gathering(_ctx)`, emitted
##      the return and never assigned `loot_earned`. The field was declared,
##      synced into the context and read twice — and written nowhere.
##   2. `PostBattleCompletion:136` reads `battle_result["xp_earned"]`. The only
##      writer of that key repo-wide is `BattleResults.gd:190`, which is not on
##      this path; `ExperienceTrainingProcessor` returns per-crew {crew_id, xp}
##      awards which the orchestrator emitted and discarded.
##   3. `create_battle_journal_entry` built its `entry_data` as a fixed key
##      literal that named none of the five scenario keys, so the Aug 9 fix to
##      `auto_create_battle_entry` — which records them into `stats` for the
##      printable Encounter Log (Core Rules Appendix X, p.180) — could never fire
##      on the campaign path.
##
## WHY THE EXISTING SUITE COULD NOT SEE ANY OF IT: every prior test called
## `auto_create_battle_entry(dict)` and PASSED THE KEYS IN, so it exercised the
## consumer while all three defects sat in the producer. This suite drives
## `create_battle_journal_entry()` — the function the campaign actually calls —
## into a REAL CampaignJournal, and reads the stored entry back.
##
## gdUnit4 v6.0.3. NOTE: run with -c, never --headless (project rule).

const PostBattlePhaseScript = preload(
	"res://src/core/campaign/phases/PostBattlePhase.gd")
const PostBattleCompletionScript = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleCompletion.gd")
const PostBattleContextScript = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const CampaignJournalScript = preload("res://src/core/campaign/CampaignJournal.gd")


## A battle result carrying every scenario fact the funnel stamps before the
## battle, in the shapes CampaignTurnController actually produces:
## `deployment_condition` is the {condition_id, title} Dictionary and
## `notable_sight` is {type, effect, roll}.
func _battle_result() -> Dictionary:
	return {
		"turn": 3,
		"success": true,
		"enemy_type": "Gangers",
		"mission_type": "Secure",
		"enemy_category": "criminal_elements",
		"enemy_count": 7,
		"deployment_condition": {"condition_id": "poor_visibility",
			"title": "Poor Visibility"},
		"notable_sight": {"type": "SHINY_BITS", "effect": "Gain 1 loot roll",
			"roll": 4},
		"objective_id": "move_through",
		"objective_met": true,
	}


func _journal() -> Node:
	var j: Node = auto_free(CampaignJournalScript.new())
	add_child(j)
	return j


func _run_completion(battle_result: Dictionary, loot: Array,
		journal: Node) -> Dictionary:
	var ctx = PostBattleContextScript.new()
	ctx.battle_result = battle_result
	ctx.campaign_journal = journal
	ctx.loot_earned = loot
	ctx.mission_successful = true
	ctx.crew_participants = []
	ctx.injuries_sustained = []
	var completion = PostBattleCompletionScript.new()
	completion.create_battle_journal_entry(ctx)
	assert_int(journal.entries.size()).override_failure_message(
		"create_battle_journal_entry wrote no entry at all").is_equal(1)
	return journal.entries[0]


# ── cause 3: the scenario keys reach `stats` ─────────────────────────────────

## The Encounter Log's boxes. Each of these printed BLANK on device because the
## entry_data literal did not name them, so `auto_create_battle_entry` — which has
## read them since Aug 9 — was handed a dict that never had them.
func test_the_scenario_keys_survive_the_handoff_into_stats() -> void:
	var entry: Dictionary = _run_completion(_battle_result(), [], _journal())
	var stats: Dictionary = entry.get("stats", {})
	var missing: Array[String] = []
	for key: String in ["mission_type", "enemy_category", "enemy_count",
			"deployment_condition", "notable_sight"]:
		if not stats.has(key):
			missing.append(key)
	assert_array(missing).override_failure_message(
		"the battle knew these and the Encounter Log will print them blank, "
		+ "because create_battle_journal_entry's key literal dropped them:\n  "
		+ "\n  ".join(missing)).is_empty()


## Shapes, not just presence: the sheet prints these, so a Dictionary landing in
## a text box would read as "{ condition_id: ... }".
func test_the_dictionary_shaped_facts_are_reduced_to_their_printable_text() -> void:
	var entry: Dictionary = _run_completion(_battle_result(), [], _journal())
	var stats: Dictionary = entry.get("stats", {})
	assert_str(str(stats.get("deployment_condition", ""))).is_equal(
		"Poor Visibility")
	assert_str(str(stats.get("notable_sight", ""))).is_equal("SHINY_BITS")
	assert_int(int(stats.get("enemy_count", 0))).is_equal(7)


# ── cause 1: loot ────────────────────────────────────────────────────────────

func test_gathered_loot_is_counted_in_the_entry() -> void:
	var loot: Array = [{"name": "Shock Attachment"}, {"name": "Blade"}]
	var entry: Dictionary = _run_completion(_battle_result(), loot, _journal())
	assert_int(int(entry.get("stats", {}).get("loot_earned", -1))
		).override_failure_message(
		"the crew picked up 2 items and the Crew Log recorded a different number"
		).is_equal(2)


## THE ORCHESTRATOR HALF, which is where cause 1 actually lived. The test above
## hands `ctx.loot_earned` in, so it is blind to PostBattlePhase never filling it
## — the same callee-not-caller blindness that hid all three defects.
##
## `_sync_context()` runs ONCE and binds `_ctx.loot_earned` to the orchestrator's
## array OBJECT, so the fix has to MUTATE that array. Rebinding it
## (`loot_earned = gathered_loot`) would leave the context pointing at the old
## empty one and this assertion is what catches that.
func test_the_orchestrator_records_the_loot_it_gathered() -> void:
	var phase: Node = auto_free(PostBattlePhaseScript.new())
	add_child(phase)
	var bound_before: Array = phase.loot_earned

	# The REAL pipeline. Step 7 rolls off data/loot_tables.json; banking the items
	# needs a campaign, which this has not got, but the GATHER is what is under
	# test and it runs regardless.
	phase.start_post_battle_phase({
		"success": true,
		"turn": 3,
		"enemies_defeated_count": 4,
		"crew_participants": [],
		"injuries_sustained": [],
	})

	assert_bool(phase.loot_earned.is_empty()).override_failure_message(
		"Step 7 gathered loot and the orchestrator dropped it: "
		+ "process_loot_gathering()'s return was emitted and never assigned to "
		+ "loot_earned, so the Encounter Log's loot box and "
		+ "get_results()['loot_earned'] were empty on every battle ever played"
		).is_false()
	assert_bool(bound_before == phase.loot_earned).override_failure_message(
		"loot_earned was REBOUND to a new array. _sync_context() already handed "
		+ "the context the original object, so the context still sees an empty "
		+ "list — mutate the array, never reassign the field").is_true()


# ── cause 2: XP ──────────────────────────────────────────────────────────────

func test_the_battle_xp_total_reaches_the_entry() -> void:
	var br: Dictionary = _battle_result()
	br["xp_earned"] = 14
	var entry: Dictionary = _run_completion(br, [], _journal())
	assert_int(int(entry.get("stats", {}).get("xp_gained", -1))
		).override_failure_message(
		"14 XP was awarded and the Crew Log recorded something else"
		).is_equal(14)


## THE PRODUCER SIDE of cause 2, and the third time in this session that my first
## attempt could not see the defect it was written for.
##
## The test above sets `xp_earned` on the battle result and hands it in, so it
## exercises the journal while the defect sits in the orchestrator — reverting
## the fix produced 0 failures. Recorded rather than quietly replaced, because
## "the test passes keys in that the real producer never writes" is the single
## mistake that hid every one of T9-43, T9-44 and the Aug 9 sheet defects.
##
## This runs the REAL pipeline and asserts the CONTRACT: after Step 9 the
## orchestrator must have recorded a battle XP total on `battle_result`, because
## that is the key the journal entry reads. The awards are per-crew
## ({crew_id, xp}); somebody has to total them, and nobody did.
##
## The figure is 0 in this harness — no campaign means no crew to award — so the
## assertion is on PRESENCE, which is exactly what was missing: the key was
## absent, so `.get("xp_earned", 0)` silently defaulted and no error was ever
## raised.
func test_the_orchestrator_records_a_battle_xp_total() -> void:
	var phase: Node = auto_free(PostBattlePhaseScript.new())
	add_child(phase)
	phase.start_post_battle_phase({
		"success": true,
		"turn": 3,
		"enemies_defeated_count": 4,
		"crew_participants": [],
		"injuries_sustained": [],
	})
	assert_bool(phase.battle_result.has("xp_earned")).override_failure_message(
		"Step 9 awarded XP and no one wrote the battle total anywhere the "
		+ "journal can read it. PostBattleCompletion:136 reads "
		+ "battle_result['xp_earned']; the only writer of that key repo-wide is "
		+ "BattleResults.gd:190, which is not on this path — so the Crew Log "
		+ "recorded 0 XP for a battle that had just awarded 14.").is_true()


## The summation itself, kept small and separate: per-crew awards make a battle
## total, and a malformed entry must not abort the tally.
func test_per_crew_awards_total_into_a_battle_xp_figure() -> void:
	var awards: Array = [
		{"crew_id": "a", "xp": 3}, {"crew_id": "b", "xp": 3},
		{"crew_id": "c", "xp": 4}, "not a dictionary", {"crew_id": "d", "xp": 4},
	]
	var total: int = 0
	for award in awards:
		if award is Dictionary:
			total += int((award as Dictionary).get("xp", 0))
	assert_int(total).is_equal(14)


# ── the guard that keeps the two ends from drifting again ────────────────────

## `auto_create_battle_entry` reads its scenario facts off the dict it is handed.
## Every key it reads must be one that `create_battle_journal_entry` can forward,
## or the Aug 9 class of defect returns: a consumer taught to read a key whose
## producer never names it. Scans the consumer's source and checks the producer's.
func test_no_scenario_key_is_read_that_the_producer_cannot_forward() -> void:
	var consumer := FileAccess.open(
		"res://src/core/campaign/CampaignJournal.gd", FileAccess.READ)
	var producer := FileAccess.open(
		"res://src/core/campaign/phases/post_battle/PostBattleCompletion.gd",
		FileAccess.READ)
	assert_object(consumer).is_not_null()
	assert_object(producer).is_not_null()
	var consumer_text: String = consumer.get_as_text()
	var producer_text: String = producer.get_as_text()
	consumer.close()
	producer.close()

	# Isolate auto_create_battle_entry(), then collect battle_result.get("key").
	var start: int = consumer_text.find("func auto_create_battle_entry")
	assert_int(start).override_failure_message(
		"auto_create_battle_entry not found — the scan broke").is_greater(-1)
	var end: int = consumer_text.find("\nfunc ", start + 10)
	var body: String = consumer_text.substr(start, end - start)

	var re := RegEx.create_from_string(
		"battle_result\\.(?:get|has)\\(\\s*\"([a-z_0-9]+)\"")
	var read_keys: Array[String] = []
	for m in re.search_all(body):
		if not read_keys.has(m.get_string(1)):
			read_keys.append(m.get_string(1))
	assert_int(read_keys.size()).override_failure_message(
		"found only %d keys — the scan broke and this test checks nothing"
		% read_keys.size()).is_greater(10)

	var unforwarded: Array[String] = []
	for key: String in read_keys:
		if not producer_text.contains("\"%s\"" % key):
			unforwarded.append(key)
	assert_array(unforwarded).override_failure_message(
		"auto_create_battle_entry reads these off the dict it is handed, and "
		+ "create_battle_journal_entry — the only campaign-path caller — never "
		+ "names them, so they can only ever arrive empty:\n  "
		+ "\n  ".join(unforwarded)).is_empty()


# ── T9-49: "There is no Win condition against Rivals" (Core Rules p.91) ───────
#
# p.91 verbatim: "There is no Win condition against Rivals, but if you Hold the
# Field, you have an increased chance of permanently chasing them off." p.92 says
# the same of an Invasion.
#
# `ctx.mission_successful` is CORRECTLY false for these battles — TacticalBattleUI
# forces it (`_has_no_win_condition()`, :5997) and PaymentProcessor depends on it
# for the p.120 payment gate. The defect was the `else` branch: a bare
# `"victory" if mission_successful else "defeat"` stamped DEFEAT on every Rival and
# Invasion battle however well it went.
#
# ⚠ MEASURED ON THE TABLET, Aug 13 2026. A Rival ambush recorded with the objective
# achieved, "Won" selected and Held the Field produced this entry:
#     "description": "Battle vs Unknown - Defeat\n | Objective: Access (achieved)"
#     "mood": "defeat",  "stats": { "battle_result": "defeat", ... }
# — a single entry contradicting itself. The dashboard simultaneously moved 4W->5W,
# because the W/L counter reads `victory`/`won` while the journal reads `success`:
# TWO KEYS ANSWERING "DID YOU WIN", and p.91's gate had only been applied to one.

func _run_completion_with(battle_result: Dictionary,
		mission_successful: bool, journal: Node) -> Dictionary:
	var ctx = PostBattleContextScript.new()
	ctx.battle_result = battle_result
	ctx.campaign_journal = journal
	ctx.loot_earned = []
	ctx.mission_successful = mission_successful
	ctx.crew_participants = []
	ctx.injuries_sustained = []
	var completion = PostBattleCompletionScript.new()
	completion.create_battle_journal_entry(ctx)
	assert_int(journal.entries.size()).override_failure_message(
		"create_battle_journal_entry wrote no entry at all").is_equal(1)
	return journal.entries[0]


## The real shape: TacticalBattleUI reads no_win_condition out of
## mission_data["setup_rules"], and CampaignTurnController stamps that same bundle
## onto the battle result (:1289), so it survives BattleResultNormalizer (:89).
func _no_win_result(held_field: bool) -> Dictionary:
	var r: Dictionary = _battle_result()
	r["success"] = false          # correctly forced false by p.91
	r["setup_rules"] = {"no_win_condition": true}
	r["held_field"] = held_field
	return r


func test_a_rival_battle_is_never_recorded_as_a_defeat() -> void:
	var entry: Dictionary = _run_completion_with(
		_no_win_result(true), false, _journal())
	var word: String = str(entry.get("stats", {}).get("battle_result", ""))
	assert_str(word).override_failure_message(
		"p.91 says there is no Win condition against Rivals — it does NOT say you "
		+ "lost. Recording 'defeat' puts a loss in the permanent record and prints "
		+ "it into the Encounter Log's result box.").is_not_equal("defeat")
	assert_str(word).is_equal("held the field")


func test_holding_the_field_is_the_books_own_word_for_the_good_outcome() -> void:
	var entry: Dictionary = _run_completion_with(
		_no_win_result(true), false, _journal())
	# p.91 offers exactly one thing to achieve in these battles, and the entry
	# should say which way it went.
	assert_str(str(entry.get("description", ""))).contains("Held The Field")
	# _determine_battle_mood matches only victory/defeat, so anything else falls
	# through to neutral — correct here, and asserted so a future edit to that
	# match statement cannot quietly re-introduce a "defeat" mood.
	assert_str(str(entry.get("mood", ""))).override_failure_message(
		"a battle that cannot be lost must not carry a defeat mood").is_not_equal(
		"defeat")


func test_leaving_a_no_win_battle_early_records_withdrawal_not_defeat() -> void:
	var entry: Dictionary = _run_completion_with(
		_no_win_result(false), false, _journal())
	var word: String = str(entry.get("stats", {}).get("battle_result", ""))
	assert_str(word).is_equal("withdrew")
	assert_str(word).is_not_equal("defeat")


## The ordinary path must be untouched — this is the regression guard on the fix.
func test_an_ordinary_mission_still_records_victory_and_defeat() -> void:
	var won: Dictionary = _run_completion_with(_battle_result(), true, _journal())
	assert_str(str(won.get("stats", {}).get("battle_result", ""))).is_equal(
		"victory")

	var lost_result: Dictionary = _battle_result()
	lost_result["success"] = false
	var lost: Dictionary = _run_completion_with(lost_result, false, _journal())
	assert_str(str(lost.get("stats", {}).get("battle_result", ""))).override_failure_message(
		"a normal mission that failed its objective IS a defeat — the p.91 carve-out "
		+ "must not swallow the ordinary case").is_equal("defeat")


## A mission whose setup_rules exist but do NOT set the flag is an ordinary
## mission. Guarding on the bundle's presence rather than the flag would silently
## reclassify every battle that carries setup rules at all.
func test_setup_rules_without_the_flag_is_an_ordinary_mission() -> void:
	var r: Dictionary = _battle_result()
	r["setup_rules"] = {"flee_before_round": 4, "crew_cap_delta": -1}
	var entry: Dictionary = _run_completion_with(r, true, _journal())
	assert_str(str(entry.get("stats", {}).get("battle_result", ""))).is_equal(
		"victory")


## The OTHER half of T9-49, and the one that reaches a rules-bearing counter:
## VictoryChecker reads `battles_won` for the p.64 conditions "Win 20 / 50 / 100
## tabletop battles". A battle that cannot be won must move neither counter.
## The increment is inline in a Node method with autoload dependencies, so this
## anchors on the gate itself rather than the mere presence of the call.
func test_the_win_loss_counter_skips_a_battle_that_cannot_be_won() -> void:
	var src: String = FileAccess.get_file_as_string(
		"res://src/ui/screens/campaign/CampaignTurnController.gd")
	assert_bool(src.contains("no_win_condition")).override_failure_message(
		"CampaignTurnController must read the p.91/p.92 flag before touching the "
		+ "W/L tally").is_true()
	var gate_at: int = src.find("if no_win_condition:")
	assert_int(gate_at).override_failure_message(
		"the increment block must be GATED on no_win_condition, not merely aware "
		+ "of it").is_greater(-1)
	var won_at: int = src.find("increment_battles_won")
	assert_int(gate_at).override_failure_message(
		"the gate has to come BEFORE the win increment or it changes nothing"
		).is_less(won_at)
