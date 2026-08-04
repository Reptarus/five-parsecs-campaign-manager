extends GdUnitTestSuite
## Expanded Quest Progression — Compendium pp.78-80.
##
## THE DEFECT THIS PINS. Nothing here was broken; the wire was simply absent.
## `data/compendium/missions_expanded.json` has always carried all nine D100 rows
## spanning 01-100 contiguously plus the Conclusion, and
## `src/data/compendium_missions_expanded.gd` has always exposed
## `roll_quest_progression()` / `get_quest_conclusion()` behind a correct
## EXPANDED_QUESTS gate. Both had ZERO callers, in a chapter whose own first line
## says it "is used IN PLACE OF the core rulebook system" at Post-Battle Step 3.
##
## The reason it was never wired is the reason a table alone could not express
## it: a Quest step is not an event, it is a standing obligation — "until this
## has been paid / done / completed, you cannot progress the Quest" — and a roll
## with nowhere to persist its result cannot say that.
##
## gdUnit4 v6.0.3 compatible.

const Quest = preload("res://src/core/campaign/ExpandedQuestProgression.gd")
const MissionsExpanded = preload("res://src/data/compendium_missions_expanded.gd")

const RESOLVER_SRC := "res://src/core/campaign/phases/post_battle/RivalPatronResolver.gd"
const ENEMY_GEN_SRC := "res://src/core/systems/EnemyGenerator.gd"
const SETUP_RULES_SRC := "res://src/core/battle/BattleSetupRules.gd"
const NORMALIZER_SRC := "res://src/core/battle/BattleResultNormalizer.gd"
const CTC_SRC := "res://src/ui/screens/campaign/CampaignTurnController.gd"

var _saved_flag: bool = false
var _saved_owned: bool = false


func _dlc() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


func before_test() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	_saved_owned = dlc.has_dlc("freelancers_handbook")
	_saved_flag = dlc.is_feature_enabled(dlc.ContentFlag.get("EXPANDED_QUESTS"))


func after_test() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(dlc.ContentFlag.get("EXPANDED_QUESTS"), _saved_flag)
	dlc.set_dlc_owned("freelancers_handbook", _saved_owned)


func _enable() -> bool:
	var dlc := _dlc()
	if dlc == null:
		return false
	dlc.set_dlc_owned("freelancers_handbook", true)
	dlc.set_feature_enabled(dlc.ContentFlag.get("EXPANDED_QUESTS"), true)
	return true


func _campaign() -> Dictionary:
	return {"progress_data": {}, "crew_data": {"members": []}}


func _src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var text: String = f.get_as_text()
	f.close()
	return text


## Source with whole-line comments removed. The anti-regression greps below
## assert about CODE, and these files carry docblocks quoting the very
## identifiers they replaced — grepping raw source would make the explanation of
## a fix read as the fix being reverted.
func _code_only(path: String) -> String:
	var out: PackedStringArray = []
	for line in _src(path).split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)


## =========================================================================
## The table itself (p.79)
## =========================================================================

func test_progression_table_covers_1_to_100_contiguously() -> void:
	var rows: Array = MissionsExpanded.QUEST_PROGRESSION
	assert_int(rows.size()).is_equal(9)
	var expected: int = 1
	for row: Variant in rows:
		assert_int(int(row["roll_min"])).override_failure_message(
			"gap or overlap before row %s" % row.get("id", "?")).is_equal(expected)
		expected = int(row["roll_max"]) + 1
	assert_int(expected).override_failure_message(
		"the table must end at 100").is_equal(101)


func test_every_row_resolves_at_both_of_its_boundaries() -> void:
	for row: Variant in MissionsExpanded.QUEST_PROGRESSION:
		var id: String = str(row["id"])
		assert_str(str(Quest.step_for_roll(int(row["roll_min"])).get("id", ""))).is_equal(id)
		assert_str(str(Quest.step_for_roll(int(row["roll_max"])).get("id", ""))).is_equal(id)


func test_seven_rows_block_and_two_resolve_immediately() -> void:
	## p.79: seven rows end "you cannot progress the Quest"; 81-92 and 93-100 pay
	## a Rumor on the spot and set a modifier instead.
	var blocking: int = 0
	var immediate: int = 0
	for row: Variant in MissionsExpanded.QUEST_PROGRESSION:
		if bool(row.get("blocks_progress", false)):
			blocking += 1
		if bool(row.get("immediate_rumor", false)):
			immediate += 1
	assert_int(blocking).is_equal(7)
	assert_int(immediate).is_equal(2)


func test_conclusion_numbers_match_the_book() -> void:
	## p.80: "+1 to the number of enemies encountered... always accompanied by a
	## Unique Individual. They will not test Morale... roll twice, pick the
	## highest score, and add +1... roll three times on the Loot table... add +1
	## Story Point."
	var c: Dictionary = Quest.conclusion_rules()
	assert_int(int(c.get("enemy_count_bonus", 0))).is_equal(1)
	assert_bool(bool(c.get("force_unique_individual", false))).is_true()
	assert_bool(bool(c.get("enemies_fearless", false))).is_true()
	assert_int(int(c.get("credit_rolls", 0))).is_equal(2)
	assert_int(int(c.get("credit_bonus", 0))).is_equal(1)
	assert_int(int(c.get("loot_rolls", 0))).is_equal(3)
	assert_int(int(c.get("story_points", 0))).is_equal(1)


## =========================================================================
## The p.78 gate
## =========================================================================

func test_flag_off_produces_no_roll_at_all() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(dlc.ContentFlag.get("EXPANDED_QUESTS"), false)
	var campaign := _campaign()
	var out: Dictionary = Quest.roll_progress(campaign, 0, 0, 1, 0, 3, 50)
	assert_bool(bool(out["ran"])).is_false()
	assert_bool(campaign["progress_data"].has("expanded_quest")).is_false()


func test_modified_seven_or_higher_reaches_the_conclusion() -> void:
	## "On a modified score of 7 or higher, you have reached the Quest Conclusion."
	if not _enable():
		return
	var campaign := _campaign()
	var out: Dictionary = Quest.roll_progress(campaign, 4, 0, 1, 0, 3, 50)
	assert_int(int(out["total"])).is_equal(7)
	assert_bool(bool(out["conclusion"])).is_true()
	assert_bool((out["step"] as Dictionary).is_empty()).is_true()


func test_modified_six_or_lower_rolls_on_the_progression_table() -> void:
	## "On a modified score of 6 or lower, roll on the Quest Progression table."
	if not _enable():
		return
	var campaign := _campaign()
	var out: Dictionary = Quest.roll_progress(campaign, 2, 0, 1, 0, 3, 25)
	assert_int(int(out["total"])).is_equal(5)
	assert_bool(bool(out["conclusion"])).is_false()
	assert_str(str((out["step"] as Dictionary).get("id", ""))).is_equal("tough_fight")


func test_the_rumor_count_is_added_to_the_die() -> void:
	## The whole formula: "Roll 1D6, adding the number of Quest Rumors you have
	## acquired so far." Six rumors alone clear the threshold on any die.
	if not _enable():
		return
	var out: Dictionary = Quest.roll_progress(_campaign(), 6, 0, 1, 0, 1, 50)
	assert_int(int(out["total"])).is_equal(7)
	assert_bool(bool(out["conclusion"])).is_true()


func test_the_step_persists_on_the_campaign() -> void:
	if not _enable():
		return
	var campaign := _campaign()
	Quest.roll_progress(campaign, 0, 0, 3, 0, 1, 25)
	var stored: Dictionary = campaign["progress_data"]["expanded_quest"]
	assert_str(str((stored["step"] as Dictionary).get("id", ""))).is_equal("tough_fight")
	assert_int(int((stored["step"] as Dictionary).get("assigned_turn", -1))).is_equal(3)


## =========================================================================
## The standing obligation
## =========================================================================

func test_a_pending_blocking_step_suppresses_the_next_roll() -> void:
	## "Until this has been done, you cannot progress the Quest" — and progressing
	## the Quest is exactly what Step 3 does, so there is no second roll.
	if not _enable():
		return
	var campaign := _campaign()
	Quest.roll_progress(campaign, 0, 0, 1, 0, 1, 25)
	assert_bool(Quest.blocks_progress(campaign)).is_true()
	var second: Dictionary = Quest.roll_progress(campaign, 6, 0, 2, 0, 6, 90)
	assert_bool(bool(second["ran"])).override_failure_message(
		"a pending obligation must suppress the roll entirely").is_false()
	assert_bool(bool(second["blocked"])).is_true()
	assert_bool(bool(second["conclusion"])).is_false()


func test_the_two_immediate_rows_leave_nothing_pending() -> void:
	if not _enable():
		return
	for roll: int in [85, 95]:
		var campaign := _campaign()
		var out: Dictionary = Quest.roll_progress(campaign, 0, 0, 1, 0, 1, roll)
		assert_bool(bool(out["rumor_awarded"])).override_failure_message(
			"roll %d pays a Rumor on the spot" % roll).is_true()
		assert_bool(Quest.blocks_progress(campaign)).override_failure_message(
			"roll %d must not become an obligation" % roll).is_false()
		assert_bool(Quest.get_pending_step(campaign).is_empty()).is_true()


func test_enemy_massing_is_permanent_for_the_rest_of_the_quest() -> void:
	## 81-92: "All future battles that are part of the Quest must add +1 to the
	## number of enemies encountered."
	if not _enable():
		return
	var campaign := _campaign()
	Quest.roll_progress(campaign, 0, 0, 1, 0, 1, 85)
	assert_int(Quest.enemy_count_bonus(campaign)).is_equal(1)
	# Still there after the next step lands.
	Quest.roll_progress(campaign, 0, 0, 2, 0, 1, 5)
	assert_int(Quest.enemy_count_bonus(campaign)).is_equal(1)


func test_the_dangerous_data_cache_is_exempt_from_the_massing_bonus() -> void:
	## 81-92, verbatim: "(entry 54-65 above is unaffected)".
	if not _enable():
		return
	var campaign := _campaign()
	Quest.roll_progress(campaign, 0, 0, 1, 0, 1, 85)
	assert_int(Quest.enemy_count_bonus(campaign, "data_cache_dangerous")).is_equal(0)
	assert_int(Quest.enemy_count_bonus(campaign, "tough_fight")).is_equal(1)


func test_enemy_determined_reduces_panic_permanently() -> void:
	if not _enable():
		return
	var campaign := _campaign()
	Quest.roll_progress(campaign, 0, 0, 1, 0, 1, 95)
	assert_int(Quest.panic_reduction(campaign)).is_equal(1)


func test_tough_fight_adds_two_enemies_and_one_panic_while_it_is_pending() -> void:
	## 21-28: "add +2 to the number encountered, and reduce their Panic range
	## by -1."
	if not _enable():
		return
	var campaign := _campaign()
	Quest.roll_progress(campaign, 0, 0, 1, 0, 1, 25)
	assert_int(Quest.enemy_count_bonus(campaign)).is_equal(2)
	assert_int(Quest.panic_reduction(campaign)).is_equal(1)
	# And it is scoped to THAT battle, not to any Quest fight.
	assert_int(Quest.enemy_count_bonus(campaign, "business_contact")).is_equal(0)


func test_clear_wipes_the_permanent_modifiers() -> void:
	## The modifiers are scoped to "the Quest"; a new one starts clean.
	if not _enable():
		return
	var campaign := _campaign()
	Quest.roll_progress(campaign, 0, 0, 1, 0, 1, 85)
	Quest.clear(campaign)
	assert_int(Quest.enemy_count_bonus(campaign)).is_equal(0)
	assert_bool(campaign["progress_data"].has("expanded_quest")).is_false()


## =========================================================================
## Discharging each obligation
## =========================================================================

func test_paying_for_the_information_needs_the_credits() -> void:
	## 01-10: "It costs 1D6 Credits. Until this has been paid, you cannot progress
	## the Quest. Once it is paid, receive 1 Quest Rumor."
	if not _enable():
		return
	var campaign := _campaign()
	Quest.roll_progress(campaign, 0, 0, 1, 0, 1, 5, 4)
	assert_int(int(Quest.get_pending_step(campaign).get("cost", 0))).is_equal(4)

	var poor: Dictionary = Quest.pay_step_cost(campaign, 3)
	assert_bool(bool(poor["completed"])).is_false()
	assert_bool(Quest.blocks_progress(campaign)).is_true()

	var paid: Dictionary = Quest.pay_step_cost(campaign, 4)
	assert_bool(bool(paid["completed"])).is_true()
	assert_bool(bool(paid["rumor_awarded"])).is_true()
	assert_int(int(paid["paid"])).is_equal(4)
	assert_bool(Quest.blocks_progress(campaign)).is_false()


func test_research_accumulates_across_turns_to_twenty() -> void:
	## 11-20: "research points equal to the combined Savvy scores of your crew
	## members, +1D6... If the total equals or exceeds 20... you may continue
	## accumulating research points every campaign turn."
	if not _enable():
		return
	var campaign := _campaign()
	# Crew Savvy 5, die 1 → 6 on assignment. Not solved.
	Quest.roll_progress(campaign, 0, 5, 1, 0, 1, 15, -1, 1)
	assert_int(int(Quest.get_pending_step(campaign).get("progress", 0))).is_equal(6)
	assert_bool(Quest.blocks_progress(campaign)).is_true()

	Quest.add_research_points(campaign, 5, 1)   # 12
	Quest.add_research_points(campaign, 5, 1)   # 18
	assert_bool(Quest.blocks_progress(campaign)).is_true()
	var done: Dictionary = Quest.add_research_points(campaign, 5, 1)  # 24
	assert_bool(bool(done["completed"])).is_true()
	assert_bool(bool(done["rumor_awarded"])).is_true()
	assert_bool(Quest.blocks_progress(campaign)).is_false()


func test_research_solved_on_assignment_never_becomes_an_obligation() -> void:
	## A big-Savvy crew can clear 20 on the first tranche; the book's "if not"
	## branch is the only one that creates the obligation.
	if not _enable():
		return
	var campaign := _campaign()
	var out: Dictionary = Quest.roll_progress(campaign, 0, 25, 1, 0, 1, 15, -1, 1)
	assert_bool(bool(out["rumor_awarded"])).is_true()
	assert_bool(Quest.blocks_progress(campaign)).is_false()


func test_six_crew_tasks_complete_the_hard_work_step() -> void:
	## 29-38: "Once a total of 6 such tasks have been performed by your crew,
	## receive 1 Quest Rumor."
	if not _enable():
		return
	var campaign := _campaign()
	Quest.roll_progress(campaign, 0, 0, 1, 0, 1, 33)
	assert_bool(Quest.quest_task_available(campaign)).is_true()
	for i in range(5):
		var partial: Dictionary = Quest.record_quest_task(campaign)
		assert_bool(bool(partial["completed"])).override_failure_message(
			"task %d of 6 must not complete the step" % (i + 1)).is_false()
	var done: Dictionary = Quest.record_quest_task(campaign)
	assert_bool(bool(done["completed"])).is_true()
	assert_bool(bool(done["rumor_awarded"])).is_true()
	assert_bool(Quest.quest_task_available(campaign)).override_failure_message(
		"the task is not a standing option — it disappears with the step").is_false()


func test_the_quest_work_task_does_not_exist_without_that_step() -> void:
	if not _enable():
		return
	var campaign := _campaign()
	assert_bool(Quest.quest_task_available(campaign)).is_false()
	Quest.roll_progress(campaign, 0, 0, 1, 0, 1, 25)  # tough_fight
	assert_bool(Quest.quest_task_available(campaign)).is_false()


func test_holding_the_field_discharges_the_tough_fight() -> void:
	if not _enable():
		return
	var campaign := _campaign()
	Quest.roll_progress(campaign, 0, 0, 1, 0, 1, 25)
	var lost: Dictionary = Quest.record_battle(campaign, {
		"quest_step_id": "tough_fight", "held_field": false})
	assert_bool(bool(lost["completed"])).is_false()
	assert_bool(Quest.blocks_progress(campaign)).is_true()

	var won: Dictionary = Quest.record_battle(campaign, {
		"quest_step_id": "tough_fight", "held_field": true})
	assert_bool(bool(won["completed"])).is_true()
	assert_bool(bool(won["rumor_awarded"])).is_true()


func test_a_battle_fought_for_something_else_does_not_discharge_the_step() -> void:
	## Without the step id on the result, ANY battle fought while the obligation
	## stood would clear it — a Patron job included.
	if not _enable():
		return
	var campaign := _campaign()
	Quest.roll_progress(campaign, 0, 0, 1, 0, 1, 25)
	var out: Dictionary = Quest.record_battle(campaign, {"held_field": true})
	assert_bool(bool(out["completed"])).is_false()
	assert_bool(Quest.blocks_progress(campaign)).is_true()


func test_the_access_data_cache_needs_the_mission_completed() -> void:
	## 39-53: "When the mission is completed, receive 1 Quest Rumor."
	if not _enable():
		return
	var campaign := _campaign()
	Quest.roll_progress(campaign, 0, 0, 1, 0, 1, 45)
	assert_str(str(Quest.get_pending_step(campaign).get(
		"mission_objective", ""))).is_equal("access")
	assert_bool(bool(Quest.record_battle(campaign, {
		"quest_step_id": "data_cache_access", "success": false})["completed"])).is_false()
	assert_bool(bool(Quest.record_battle(campaign, {
		"quest_step_id": "data_cache_access", "success": true})["completed"])).is_true()


func test_the_dangerous_data_cache_needs_the_survival_score_not_a_win() -> void:
	## 54-65 has NO objective — "Once the score reaches 28, you can end the
	## mission." A mission flagged successful is not the same thing.
	if not _enable():
		return
	var campaign := _campaign()
	Quest.roll_progress(campaign, 0, 0, 1, 0, 1, 60)
	assert_int(int(Quest.get_pending_step(campaign).get("survival_target", 0))).is_equal(28)
	assert_bool(bool(Quest.record_battle(campaign, {
		"quest_step_id": "data_cache_dangerous", "success": true})["completed"])).is_false()
	assert_bool(bool(Quest.record_battle(campaign, {
		"quest_step_id": "data_cache_dangerous",
		"quest_survival_reached": true})["completed"])).is_true()


func test_the_business_contact_forces_aggressive_ai() -> void:
	## 66-80: "Set up a Protect mission. The enemy AI is changed to Aggressive."
	if not _enable():
		return
	var campaign := _campaign()
	Quest.roll_progress(campaign, 0, 0, 1, 0, 1, 70)
	var stamp: Dictionary = Quest.mission_stamp(campaign)
	assert_str(str(stamp.get("quest_step_objective", ""))).is_equal("protect")
	assert_str(str(stamp.get("quest_force_enemy_ai", ""))).is_equal("aggressive")


## =========================================================================
## The mission stamp — the mission carries its own identity
## =========================================================================

func test_mission_stamp_carries_the_step_id_and_the_modifiers() -> void:
	if not _enable():
		return
	var campaign := _campaign()
	Quest.roll_progress(campaign, 0, 0, 1, 0, 1, 25)
	var stamp: Dictionary = Quest.mission_stamp(campaign)
	assert_str(str(stamp.get("quest_step_id", ""))).is_equal("tough_fight")
	assert_int(int(stamp.get("quest_enemy_bonus", 0))).is_equal(2)
	assert_int(int(stamp.get("quest_panic_reduction", 0))).is_equal(1)
	assert_str(str(stamp.get("quest_step_instruction", ""))).is_not_empty()


func test_mission_stamp_is_empty_when_the_chapter_is_off() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(dlc.ContentFlag.get("EXPANDED_QUESTS"), false)
	assert_bool(Quest.mission_stamp(_campaign()).is_empty()).is_true()


## =========================================================================
## Anti-regression: the wires themselves
## =========================================================================

func test_the_resolver_branches_before_the_core_die_is_rolled() -> void:
	## A die rolled and then discarded still reaches the dice feed and the
	## journal, and the expanded system does not always roll.
	var code: String = _code_only(RESOLVER_SRC)
	var branch: int = code.find("_process_expanded_quest_progress(ctx, quest_rumors)")
	var core_roll: int = code.find("ctx.roll_d6(\"Quest progress roll\")")
	assert_int(branch).override_failure_message(
		"the expanded branch is gone from process_quest_progress").is_greater(-1)
	assert_int(core_roll).override_failure_message(
		"the core roll site vanished — check this test, not just the code"
	).is_greater(-1)
	assert_int(branch).override_failure_message(
		"the expanded branch must come BEFORE the core D6 is rolled"
	).is_less(core_roll)


func test_the_expanded_path_drops_the_core_penalty_and_travel_roll() -> void:
	## p.78 replaces Step 3 wholesale: the formula is 1D6 + Quest Rumors, and the
	## p.119 travel roll belongs to the system being replaced.
	var code: String = _code_only(RESOLVER_SRC)
	var start: int = code.find("func _process_expanded_quest_progress")
	assert_int(start).is_greater(-1)
	var body: String = code.substr(start)
	assert_str(body).override_failure_message(
		"the core -2-on-failure must not reach the expanded path").not_contains("total_roll -= 2")
	assert_str(body).override_failure_message(
		"the p.119 travel roll belongs to the replaced system"
	).not_contains("set_quest_requires_travel")


func test_the_enemy_generator_reads_the_quest_bonus() -> void:
	var code: String = _code_only(ENEMY_GEN_SRC)
	assert_str(code).contains("mission_data.get(\"quest_enemy_bonus\"")
	assert_str(code).override_failure_message(
		"the bonus must join the modifier sum, not sit in an unused local"
	).contains("+ quest_enemy_mod")


func test_the_setup_rules_read_the_quest_panic_reduction() -> void:
	var code: String = _code_only(SETUP_RULES_SRC)
	assert_str(code).contains("quest_panic_reduction")
	assert_str(code).contains("_apply_expanded_quest_step(b, mission_data)")


func test_the_normalizer_carries_the_step_id_to_the_post_battle_side() -> void:
	## Every battle path crosses the normalizer; a consumer without this
	## passthrough reads a key no producer wrote on three of the four paths.
	assert_str(_code_only(NORMALIZER_SRC)).contains("\"quest_step_id\"")


func test_the_turn_controller_stamps_quest_missions() -> void:
	var code: String = _code_only(CTC_SRC)
	assert_str(code).contains("ExpandedQuestRef.mission_stamp(")
	assert_str(code).override_failure_message(
		"p.80: the Conclusion's enemy is always accompanied by a Unique Individual"
	).contains("force_unique_individual")


func test_the_conclusion_forces_a_unique_individual_in_the_generator() -> void:
	var code: String = _code_only(ENEMY_GEN_SRC)
	assert_str(code).contains("mission_data.get(\"force_unique_individual\"")
