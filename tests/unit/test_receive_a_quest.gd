extends GdUnitTestSuite
## "Receive a Quest" starts a Quest (Core Rules p.85), whichever rule hands it over.
##
## Measured on 2026-10-29 before the fix: Letter from home (p.128, "On a 5-6 you
## immediately receive a Quest") and a Traveler's 11-12 (p.22, "the crew immediately
## receives a Quest") each added a Quest Rumor. Only the Resolve Rumors roll (p.85)
## ever started a Quest, and only that route spent a held Local maps (p.79).

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const PostBattleContextClass = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const CharacterEventEffectsClass = preload(
	"res://src/core/campaign/phases/post_battle/CharacterEventEffects.gd")
const PostBattleCompletionClass = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleCompletion.gd")
const Events = preload("res://src/core/campaign/DeferredCrewEvents.gd")
const SaveDirGuard = preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _prior_campaign: Resource = null
var _user_state: Dictionary = {}


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_prior_campaign = GameState.current_campaign


func after_test() -> void:
	for key: String in ["Letter from Home Quest", "Traveler"]:
		DiceManager.clear_forced_results(key)
	GameState.current_campaign = _prior_campaign
	SaveDirGuard.restore(_user_state)


func _ctx(members: Array) -> Variant:
	var c = CampaignCore.new()
	c.from_dictionary({"campaign_id": "receive_a_quest", "crew": {"members": members}})
	c.progress_data["turns_played"] = 4
	GameState.current_campaign = c
	var ctx = PostBattleContextClass.new()
	ctx.campaign = c
	ctx.battle_result = {"turn": 5}
	return ctx


func _member(id: String, extra: Dictionary = {}) -> Dictionary:
	var m := {"character_id": id, "character_name": "Rin %s" % id, "combat": 1,
		"speed": 4, "toughness": 3, "luck": 0, "experience": 0, "equipment": [],
		"status_effects": [], "origin": "human", "species_id": "human"}
	m.merge(extra, true)
	return m


func _letter(ctx, roll: int) -> String:
	DiceManager.queue_forced_result("Letter from Home Quest", roll)
	var m: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	return CharacterEventEffectsClass.new().apply_effect("Letter from Home", m, ctx)


func test_a_letter_from_home_on_a_5_or_6_starts_a_quest() -> void:
	var ctx = _ctx([_member("c1")])
	_letter(ctx, 5)
	assert_bool(GameState.has_active_quest()).override_failure_message(
		"p.128: On a 5-6 you immediately receive a Quest").is_true()
	assert_str(str(GameState.get_active_quest().get("source", ""))).contains("p.128")
	assert_int(int(ctx.campaign.quest_rumors)).override_failure_message(
		"a Quest, not a Quest Rumor").is_equal(0)

	var miss = _ctx([_member("c1")])
	_letter(miss, 4)
	assert_bool(GameState.has_active_quest()).is_false()


func test_a_quest_already_running_is_kept() -> void:
	var ctx = _ctx([_member("c1")])
	GameState.set_active_quest({"id": "q_old", "name": "Old Lead"})
	var text: String = _letter(ctx, 6)
	assert_str(str(GameState.get_active_quest().get("id", ""))).override_failure_message(
		"p.85 tracks one Quest at a time").is_equal("q_old")
	assert_str(text).contains("already on one")


func test_a_traveler_11_or_12_starts_a_quest() -> void:
	var ctx = _ctx([_member("t1", {"species_id": "traveler", "origin": "traveler"})])
	ctx.crew_participants = [ctx.campaign.get_crew_member_by_id("t1")]
	DiceManager.queue_forced_result("Traveler", 11)
	var results: Array = PostBattleCompletionClass.new().check_traveler_disappearance(ctx)
	assert_str(str(results[0].get("type", ""))).is_equal("quest")
	assert_bool(GameState.has_active_quest()).override_failure_message(
		"p.22: On an 11-12, the crew immediately receives a Quest").is_true()
	assert_bool(bool(results[0].get("received", false))).is_true()
	assert_int(int(ctx.campaign.quest_rumors)).is_equal(0)


func test_local_maps_add_a_rumor_to_a_quest_from_any_rule() -> void:
	var ctx = _ctx([_member("c1")])
	var pd: Dictionary = ctx.campaign.progress_data
	var maps := {"id": "maps_1", "event_name": "Local maps", "trigger_type": "",
		"crew_id": "", "effect": {}, "consumed": false}
	Events.stamp(maps, 4)
	pd[Events.KEY] = [maps]
	_letter(ctx, 6)
	assert_int(int(ctx.campaign.quest_rumors)).override_failure_message(
		"p.79: receive a Quest on this or the following world, add 1 Rumor").is_equal(1)
	assert_int(Events.live(pd, "Local maps", 4).size()).is_equal(0)
