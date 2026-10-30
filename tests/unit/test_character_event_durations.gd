extends GdUnitTestSuite
## Character Events that bind "the next campaign turn" (Core Rules pp.128-130) bind it.
##
## Measured on 2026-10-29 before the fix: the turn rollover runs at the START of every
## turn, before its World Phase and battle, and it ticked every status effect. An effect
## written post-battle with a duration of 1 was therefore removed by the very rollover
## that opened the turn it was for:
##   - Violence is depressing never kept anyone out of a battle;
##   - Argue with the crew never blocked a task, Melancholy never withheld XP, and
##     Time to burn never granted its action;
##   - Business elsewhere lasted one turn instead of two;
##   - Feel great carried a duration of 1, where p.130 says "Next time this character
##     would be forced to roll on the Injury Table", so it expired before any injury.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const PostBattleContextClass = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const CharacterEventEffectsClass = preload(
	"res://src/core/campaign/phases/post_battle/CharacterEventEffects.gd")
const CharacterScript = preload("res://src/core/character/Character.gd")
const SaveDirGuard = preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _prior_campaign: Resource = null
var _user_state: Dictionary = {}


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_prior_campaign = GameState.current_campaign


func after_test() -> void:
	GameState.current_campaign = _prior_campaign
	SaveDirGuard.restore(_user_state)


func _ctx(members: Array) -> Variant:
	var c = CampaignCore.new()
	c.from_dictionary({"campaign_id": "cev_durations", "crew": {"members": members}})
	GameState.current_campaign = c
	var ctx = PostBattleContextClass.new()
	ctx.campaign = c
	ctx.battle_result = {"turn": 5}
	return ctx


func _member(id: String, extra: Dictionary = {}) -> Dictionary:
	var m := {"character_id": id, "character_name": "Kaya %s" % id,
		"combat": 1, "speed": 4, "toughness": 3, "luck": 0, "experience": 0,
		"equipment": [], "status_effects": [], "origin": "human", "species_id": "human"}
	m.merge(extra, true)
	return m


func _rollover(ctx) -> void:
	CampaignPhaseManager._process_character_event_effects(ctx.campaign)


func _has(member: Dictionary, effect_type: String) -> bool:
	for e: Dictionary in member.get("status_effects", []):
		if str(e.get("type", "")) == effect_type:
			return true
	return false


func test_violence_is_depressing_keeps_them_out_of_the_next_turns_battle() -> void:
	var ctx = _ctx([_member("c1")])
	var m: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	CharacterEventEffectsClass.new().apply_effect("Violence is Depressing", m, ctx)

	_rollover(ctx)  # opens the next campaign turn
	assert_array(GameStateManager.filter_deployable([m])).override_failure_message(
		"p.128: refuses any battle during the next campaign turn").is_empty()

	_rollover(ctx)  # the turn after
	assert_array(GameStateManager.filter_deployable([m])).override_failure_message(
		"one turn only").has_size(1)


func test_business_elsewhere_is_away_for_two_turns() -> void:
	var ctx = _ctx([_member("c1")])
	var m: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	CharacterEventEffectsClass.new().apply_effect("Business Elsewhere", m, ctx)
	for turn: int in [1, 2]:
		_rollover(ctx)
		assert_bool(_has(m, "unavailable")).override_failure_message(
			"p.128: away for the next 2 campaign turns (turn %d)" % turn).is_true()
	_rollover(ctx)
	assert_bool(_has(m, "unavailable")).override_failure_message(
		"back on the third").is_false()


func test_feel_great_waits_for_an_injury_roll() -> void:
	var ctx = _ctx([_member("c1")])
	var m: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	CharacterEventEffectsClass.new().apply_effect("Feel Great", m, ctx)
	for i: int in 4:
		_rollover(ctx)
	assert_bool(_has(m, "ignore_next_injury")).override_failure_message(
		"p.130: lasts until the next Injury Table roll, however many turns away"
	).is_true()


func test_a_character_resource_skips_the_same_rollover() -> void:
	var ch = CharacterScript.new()
	ch.add_status_effect({"type": "no_xp", "duration": 1, "skip_first_rollover": true})
	ch.process_status_effect_turn()
	assert_bool(ch.has_status_effect("no_xp")).override_failure_message(
		"the rollover that opens the next turn leaves it").is_true()
	ch.process_status_effect_turn()
	assert_bool(ch.has_status_effect("no_xp")).is_false()


func test_the_row_dice_can_be_forced() -> void:
	## Business elsewhere's 1D6 XP and Time to reflect's 1D3 XP rolled raw randi().
	var fx = CharacterEventEffectsClass.new()
	for roll: int in [6, 1]:
		var ctx = _ctx([_member("c1")])
		var m: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
		DiceManager.queue_forced_result("Business Elsewhere XP", roll)
		fx.apply_effect("Business Elsewhere", m, ctx)
		var away: Dictionary = (m.status_effects as Array)[0]
		assert_int(int(away.get("return_xp", 0))).is_equal(roll)
	for roll: int in [3, 1]:
		var ctx = _ctx([_member("c1")])
		var m: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
		DiceManager.queue_forced_result("Time to Reflect XP", roll)
		fx.apply_effect("Time to Reflect", m, ctx)
		assert_int(int(m.get("experience", 0))).is_equal(roll)
	DiceManager.clear_forced_results("Business Elsewhere XP")
	DiceManager.clear_forced_results("Time to Reflect XP")


func test_effects_from_other_sources_still_count_down_at_once() -> void:
	## The stamp lives in CharacterEventEffects, not in the shared
	## PostBattleContext chokepoint, which Sick Bay effects also pass through.
	var ctx = _ctx([_member("c1")])
	var m: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	ctx.apply_character_status_effect(m, {"type": "other", "duration": 1})
	_rollover(ctx)
	assert_bool(_has(m, "other")).is_false()
