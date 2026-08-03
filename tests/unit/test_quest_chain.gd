extends GdUnitTestSuite
## The Quest arc, end to end (Core Rules pp.85, 89, 120, 123, and p.64 victory).
##
## WHAT WAS UNREACHABLE BEFORE THESE FIXES — the whole arc, in both directions:
##   p.85  Resolve Rumors ......... granted a Quest and never SPENT the Rumors,
##                                  so the D6 re-triggered every turn forever
##   p.85  "Continue a Quest" ..... the job option did not exist, so no mission
##                                  was ever built with mission_source "quest"
##                                  and the p.89 Quest objective column, though
##                                  present and byte-correct in JSON, could not
##                                  be reached by any path
##   p.89  Finale = Fight Off ..... nothing forced it; the finale rolled the D10
##   p.120 Step 3 progress roll ... ran after EVERY battle a Quest was open for,
##                                  not only Quest battles
##   p.120 finale (+1 enemy, pay
##         twice-pick-better +1,
##         p.121 triple Loot,
##         p.123 +1 XP) ........... four consumers read `is_quest_finale` off
##                                  battle_result and NO producer anywhere wrote
##                                  it. `GameState.is_quest_finale_available()`,
##                                  which the post-battle roll sets, had zero
##                                  readers. The two halves never met.
##   p.64  Complete 3/5/10 Quests . measured missions_completed, so it resolved
##                                  after any three battles
##
## Each case asserts a JOIN or a rules invariant, never a die result.

const Normalizer = preload("res://src/core/battle/BattleResultNormalizer.gd")
const MissionTables = preload("res://src/core/mission/MissionTableManager.gd")
const VictoryCheckerClass = preload("res://src/core/victory/VictoryChecker.gd")
const RivalPatronResolverClass = preload(
	"res://src/core/campaign/phases/post_battle/RivalPatronResolver.gd")
const ContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const GlobalEnumsScript = preload("res://src/core/systems/GlobalEnums.gd")
const BattleSetupRulesClass = preload("res://src/core/battle/BattleSetupRules.gd")


# ── p.90: the Defend objective modifies the setup ───────────────────────────

## "Defend — If the opposing AI is normally Cautious, Defensive, or Tactical,
## change it to Aggressive. Add +1 when determining the enemy numbers." (p.90)
## Defend is D10 5-6 on the Quest table, so a fifth of Quest missions; neither
## clause was implemented.
func test_defend_objective_adds_an_enemy_and_forces_aggressive_ai() -> void:
	var bundle: Dictionary = BattleSetupRulesClass.compute(
		{"objective_details": {"type": "DEFEND"}}, 5, 5)
	assert_int(bundle["enemy_delta"]).is_equal(1)
	var override: Dictionary = bundle["force_enemy_ai"]
	assert_array(override["from"]).contains(["C", "D", "T"])
	assert_str(str(override["to"])).is_equal("A")

## The rule raises reluctant AI; it never lowers anything. Rampaging and Beast
## are not on the book's list and must be left alone.
func test_defend_does_not_touch_ai_outside_the_books_list() -> void:
	var bundle: Dictionary = BattleSetupRulesClass.compute(
		{"objective_details": {"type": "DEFEND"}}, 5, 5)
	var from_list: Array = bundle["force_enemy_ai"]["from"]
	assert_bool(from_list.has("R")).is_false()
	assert_bool(from_list.has("B")).is_false()
	assert_bool(from_list.has("A")).is_false()

## Any other objective leaves the setup alone — otherwise the two cases above
## would pass against a function that modified every battle.
func test_other_objectives_do_not_modify_the_setup() -> void:
	for obj in ["FIGHT_OFF", "MOVE_THROUGH", "ACQUIRE", "SEARCH"]:
		var bundle: Dictionary = BattleSetupRulesClass.compute(
			{"objective_details": {"type": obj}}, 5, 5)
		assert_int(bundle["enemy_delta"]).is_equal(0)
		assert_bool((bundle["force_enemy_ai"] as Dictionary).is_empty()).is_true()


# ── p.89: the Quest objective column ────────────────────────────────────────

## "Quest Mission Objectives — 1-2 Move Through / 3-4 Search / 5-6 Defend /
## 7-8 Acquire / 9-10 Fight Off" (p.89). The Opportunity and Patron columns are
## DIFFERENT tables; rolling a Quest on the wrong one is the bug this guards.
func test_quest_objective_table_is_the_p89_quest_column() -> void:
	var mtm := MissionTables.new()
	var allowed := ["MOVE_THROUGH", "SEARCH", "DEFEND", "ACQUIRE", "FIGHT_OFF"]
	var seen := {}
	for _i in range(200):
		var obj: Dictionary = mtm.roll_mission_objective("quest")
		assert_array(allowed).contains([obj["type"]])
		seen[obj["type"]] = true
	# Over 200 rolls of a five-entry D10 table, every entry should appear. If the
	# lookup silently fell back to the Opportunity column this would still pass
	# the containment check above on MOVE_THROUGH/FIGHT_OFF alone — the coverage
	# assertion is what distinguishes the two tables.
	assert_int(seen.size()).is_equal(5)

## The Quest mission type must resolve to the quest column, not the default.
func test_quest_mission_source_selects_the_quest_table() -> void:
	var mtm := MissionTables.new()
	assert_str(mtm.get_objective_table_for_type("quest")).is_equal("quest")
	# And the option only appears when a Quest is active (p.85 availability).
	var without: Array = mtm.get_available_mission_types(false, false, false)
	var with_quest: Array = mtm.get_available_mission_types(false, true, false)
	var types_without: Array = []
	for o in without:
		types_without.append(o["type"])
	var types_with: Array = []
	for o in with_quest:
		types_with.append(o["type"])
	assert_bool(types_without.has("QUEST")).is_false()
	assert_bool(types_with.has("QUEST")).is_true()


# ── p.120: the finale flag must survive the normalizer ──────────────────────

## `is_quest_finale` gates FOUR separate book rules downstream. It reaches the
## post-battle side only if it crosses the one chokepoint every battle path
## uses, so a passthrough here is the difference between all four firing and
## none of them firing.
func test_normalizer_carries_the_finale_flag_and_quest_id() -> void:
	var mission := {
		"mission_source": "quest",
		"is_quest_finale": true,
		"quest_id": "quest_42",
	}
	var out: Dictionary = Normalizer.normalize({}, mission, 7)
	assert_bool(out.get("is_quest_finale", false)).is_true()
	assert_str(str(out.get("quest_id", ""))).is_equal("quest_42")
	assert_str(str(out.get("mission_source", ""))).is_equal("quest")

## ADD-ONLY: a producer that already decided is authoritative.
func test_normalizer_does_not_overwrite_an_explicit_finale_flag() -> void:
	var out: Dictionary = Normalizer.normalize(
		{"is_quest_finale": false}, {"is_quest_finale": true}, 1)
	assert_bool(out["is_quest_finale"]).is_false()


# ── p.120 Step 3: the roll is gated on the BATTLE being a Quest battle ──────

class StubCampaign:
	var progress_data: Dictionary = {"quests_completed": 0}
	var quest_rumors: int = 0

class StubGameState:
	var current_campaign: StubCampaign = null
	var _quest: Dictionary = {}
	var _finale: bool = false
	var completed_calls: int = 0
	func has_active_quest() -> bool:
		return not _quest.is_empty()
	func get_active_quest() -> Dictionary:
		return _quest
	func get_quest_rumors() -> int:
		return current_campaign.quest_rumors if current_campaign else 0
	func add_quest_rumor() -> void:
		if current_campaign:
			current_campaign.quest_rumors += 1
	func set_quest_finale_available(v: bool) -> void:
		_finale = v
	func is_quest_finale_available() -> bool:
		return _finale
	func set_quest_requires_travel(_r: bool, _w: bool) -> void:
		pass
	func complete_active_quest() -> int:
		completed_calls += 1
		_quest = {}
		_finale = false
		if current_campaign:
			current_campaign.progress_data["quests_completed"] = int(
				current_campaign.progress_data.get("quests_completed", 0)) + 1
			return int(current_campaign.progress_data["quests_completed"])
		return 0

func _quest_ctx(battle_result: Dictionary, quest_active: bool) -> ContextClass:
	var c: ContextClass = ContextClass.new()
	c.battle_result = battle_result
	c.crew_participants = []
	c.defeated_enemies = []
	c.mission_successful = bool(battle_result.get("victory", true))
	var gs := StubGameState.new()
	gs.current_campaign = StubCampaign.new()
	if quest_active:
		gs._quest = {"id": "quest_42", "name": "The Lost Cargo"}
	c.game_state = gs
	return c

## p.120 opens "If you just fought a battle THAT WAS PART OF A QUEST". An
## Opportunity mission fought while a Quest happens to be open is not one.
func test_a_non_quest_battle_does_not_advance_the_quest() -> void:
	var resolver := RivalPatronResolverClass.new()
	var ctx: ContextClass = _quest_ctx(
		{"mission_source": "opportunity", "victory": true}, true)
	assert_int(resolver.process_quest_progress(ctx)).is_equal(-1)
	assert_int(ctx.game_state.current_campaign.quest_rumors).is_equal(0)

## No Quest at all: the step does not apply, and must say so (-1) rather than
## report a dead end (0) — the UI logs the difference to the player.
func test_no_quest_means_the_step_does_not_apply() -> void:
	var resolver := RivalPatronResolverClass.new()
	var ctx: ContextClass = _quest_ctx({"mission_source": "quest"}, false)
	assert_int(resolver.process_quest_progress(ctx)).is_equal(-1)

## A Quest battle DOES advance it — the positive control. Without this the two
## cases above would pass against a function that always returned -1.
func test_a_quest_battle_advances_the_quest() -> void:
	var resolver := RivalPatronResolverClass.new()
	var ctx: ContextClass = _quest_ctx({"mission_source": "quest", "victory": true}, true)
	var progress: int = resolver.process_quest_progress(ctx)
	assert_int(progress).is_between(0, 2)

## p.120: the finale is the last stage. It ends the Quest instead of rolling for
## further progress, and it is what the p.64 victory tally counts.
func test_the_finale_concludes_the_quest_and_tallies_it() -> void:
	var resolver := RivalPatronResolverClass.new()
	var ctx: ContextClass = _quest_ctx({
		"mission_source": "quest",
		"is_quest_finale": true,
		"victory": true,
	}, true)
	assert_int(resolver.process_quest_progress(ctx)).is_equal(3)
	assert_int(ctx.game_state.completed_calls).is_equal(1)
	assert_bool(ctx.game_state.has_active_quest()).is_false()
	assert_int(int(ctx.game_state.current_campaign.progress_data["quests_completed"])).is_equal(1)


# ── p.64: "Complete 3 Quests" counts QUESTS ─────────────────────────────────

class VictoryCampaign:
	var progress_data: Dictionary = {}
	var credits: int = 0
	var reputation: int = 0
	var story_points: int = 0
	var victory_conditions: Dictionary = {}

func _victory_campaign(pd: Dictionary) -> VictoryCampaign:
	var c := VictoryCampaign.new()
	c.progress_data = pd
	c.victory_conditions = {
		"type": GlobalEnumsScript.FiveParsecsCampaignVictoryType.QUESTS_3
	}
	return c

## Three battles are not three Quests. This is the regression: the QUESTS_*
## rows read missions_completed, so a crew that had never seen a Quest won on it.
func test_completing_missions_does_not_win_a_quest_victory() -> void:
	var campaign := _victory_campaign({"missions_completed": 12, "battles_won": 12})
	var result: Dictionary = VictoryCheckerClass.check_victory(campaign, 12)
	assert_bool(result.get("achieved", false)).is_false()

## ...and completing three Quests does.
func test_completing_three_quests_wins_the_quest_victory() -> void:
	var campaign := _victory_campaign({"quests_completed": 3, "missions_completed": 3})
	var result: Dictionary = VictoryCheckerClass.check_victory(campaign, 3)
	assert_bool(result.get("achieved", false)).is_true()

## The boundary, so the assertion above is not passing on an always-true.
func test_two_quests_is_not_yet_a_victory() -> void:
	var campaign := _victory_campaign({"quests_completed": 2, "missions_completed": 99})
	var result: Dictionary = VictoryCheckerClass.check_victory(campaign, 99)
	assert_bool(result.get("achieved", false)).is_false()
