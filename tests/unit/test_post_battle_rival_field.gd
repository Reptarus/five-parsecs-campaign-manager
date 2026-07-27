extends GdUnitTestSuite
## Post-battle rival acquisition and removal must operate on the CANONICAL
## `rivals` field of FiveParsecsCampaignCore.
##
## THE BUG THIS EXISTS TO PREVENT
## RivalPatronResolver was written against `active_rivals`, which is a property of
## RivalManager / RivalSystem / FactionSystem / the legacy Campaign class, NOT of
## FiveParsecsCampaignCore (whose field is `rivals`, declared at :44). Both write
## branches were therefore permanently false for a real campaign:
##
##     if "active_rivals" in campaign:      # false, Resource has no such property
##         ...
##     elif campaign is Dictionary:         # false, it is a Resource
##
## Consequences, both live in the 14-step orchestrator (PostBattlePhase.gd:108,160):
##  - ACQUISITION: hold the field, roll a 1 on 1D6, and the new rival was built,
##    silently discarded, and its id returned as though recorded. `new_rivals` is
##    consumed by nothing, so nothing noticed. Core Rules p.86 never fired.
##  - REMOVAL: worse. process_rival_status appends to `rivals_removed` BEFORE
##    calling _remove_rival (line 32), and rivals_removed IS consumed
##    (PostBattlePhase.gd:161 -> CampaignTurnController.gd:381,
##    PostBattleSequence.gd:649). So the post-battle screen reported a rival as
##    removed while the canonical list still held it, and it came back next turn.
##
## gdUnit4 v6.0.3 compatible.

const RESOLVER = preload("res://src/core/campaign/phases/post_battle/RivalPatronResolver.gd")
const CTX = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")


var _previous_campaign = null
var _swapped: bool = false


func _game_state() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GameState")


func after_test() -> void:
	## Restore GameState in a LIFECYCLE HOOK, not inline at the end of each test.
	##
	## The first version of this suite restored inline. Any test whose resolver call
	## aborted early therefore left its throwaway campaign installed on the autoload,
	## and the very next suite in the same process (test_post_battle_subsystems)
	## failed on test_failed_mission_still_pays because PaymentProcessor was handed a
	## campaign with no crew and no credits. The fix was passing; the TEST was
	## leaking. after_test() runs regardless of how the test body exits.
	if not _swapped:
		return
	var gs := _game_state()
	if gs:
		gs.current_campaign = _previous_campaign
	_previous_campaign = null
	_swapped = false


func _install(campaign) -> void:
	## Swap a throwaway campaign onto the GameState autoload. after_test() undoes it.
	var gs := _game_state()
	if gs == null:
		return
	_previous_campaign = gs.current_campaign
	_swapped = true
	gs.current_campaign = campaign


func _ctx_for(_campaign) -> Object:
	## The resolver reads ctx.game_state.current_campaign, so it has to go through
	## the real autoload — hence the swap above.
	var ctx = CTX.new()
	ctx.game_state = _game_state()
	ctx.battle_result = {"enemy_type": "Raiders", "planet_id": "p1", "turn": 4}
	return ctx


# --- the field contract itself ---------------------------------------------

func test_campaign_core_has_rivals_and_not_active_rivals() -> void:
	# If this ever flips, the resolver's field name has to move with it.
	var campaign = CampaignCore.new()
	assert_bool("rivals" in campaign).override_failure_message(
		"FiveParsecsCampaignCore lost its canonical `rivals` field"
	).is_true()
	assert_bool("active_rivals" in campaign).override_failure_message(
		"FiveParsecsCampaignCore grew an `active_rivals` field; the two rival " +
		"lists must not coexist or post-battle writes will split across them"
	).is_false()


# --- acquisition -------------------------------------------------------------

func test_new_battle_rival_lands_in_the_canonical_list() -> void:
	if _game_state() == null:
		return
	var campaign = CampaignCore.new()
	_install(campaign)

	var resolver = RESOLVER.new()
	var new_id: String = resolver._create_new_rival_from_battle(_ctx_for(campaign))
	var recorded: Array = campaign.rivals

	assert_str(new_id).override_failure_message(
		"resolver returned no id, so acquisition did not run at all"
	).is_not_empty()
	assert_int(recorded.size()).override_failure_message(
		"the new rival was returned but never recorded on campaign.rivals — " +
		"this is the exact silent-discard the fix removed"
	).is_equal(1)


func test_the_returned_id_matches_the_recorded_rival() -> void:
	# The id is handed back to process_rival_status and out through new_rivals; if
	# it does not match what landed, any future consumer of new_rivals is broken.
	if _game_state() == null:
		return
	var campaign = CampaignCore.new()
	_install(campaign)

	var resolver = RESOLVER.new()
	var new_id: String = resolver._create_new_rival_from_battle(_ctx_for(campaign))
	var recorded: Array = campaign.rivals.duplicate(true)

	assert_int(recorded.size()).is_equal(1)
	assert_str(str((recorded[0] as Dictionary).get("id", ""))).is_equal(new_id)


# --- removal -----------------------------------------------------------------

func test_removal_actually_removes_from_the_canonical_list() -> void:
	if _game_state() == null:
		return
	var campaign = CampaignCore.new()
	campaign.rivals = [
		{"id": "rival_keep", "name": "Keep Me"},
		{"id": "rival_drop", "name": "Drop Me"},
	]
	_install(campaign)

	var resolver = RESOLVER.new()
	resolver._remove_rival(_ctx_for(campaign), "rival_drop")
	var remaining: Array = campaign.rivals.duplicate(true)

	assert_int(remaining.size()).override_failure_message(
		"removal was a no-op; the post-battle screen would report a removal that " +
		"never happened and the rival would return next turn"
	).is_equal(1)
	assert_str(str((remaining[0] as Dictionary).get("id", ""))).is_equal("rival_keep")


func test_removal_tolerates_string_entries() -> void:
	# `rivals` is a MIXED array: CharacterGeneration appends plain name Strings
	# (e.g. "Deserters") while CrewTaskComponent and CharacterTransferService append
	# Dictionaries. Removal must walk both without erroring on the String ones.
	if _game_state() == null:
		return
	var campaign = CampaignCore.new()
	campaign.rivals = ["Deserters", {"id": "rival_drop", "name": "Drop Me"}]
	_install(campaign)

	var resolver = RESOLVER.new()
	resolver._remove_rival(_ctx_for(campaign), "rival_drop")
	var remaining: Array = campaign.rivals.duplicate(true)

	assert_int(remaining.size()).is_equal(1)
	assert_str(str(remaining[0])).is_equal("Deserters")
