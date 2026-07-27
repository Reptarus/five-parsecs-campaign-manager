extends GdUnitTestSuite
## GameStateManager's credits/supplies/reputation/story_progress members are
## CACHES. FiveParsecsCampaignCore's top-level @vars own those values
## (data-ownership table, CLAUDE.md). These tests pin that the cache can never
## out-vote the owner.
##
## THE BUG THIS EXISTS TO PREVENT
## get_credits() returned the cache unchecked, and every arithmetic helper is
## `set_X(f(get_X()))` — so add/remove/modify derived the new CANONICAL value from
## the CACHE. Any code that wrote campaign.credits directly was invisible to them
## and got silently reverted by the next write.
##
## Real instance (RedZoneSystem.gd:108): buying the Red Zone licence does
## `campaign.credits -= 15`, then _commit_zone_travel calls modify_credits(-5)
## computed from the stale cache. Result: the 15cr fee is refunded and the player
## keeps the licence. Core Rules Appendix III's endgame gate cost nothing.
## Same exposure: AdvancementPhasePanel.gd:553/557, PostBattleSequence.gd:2594,
## ShiplessSystem.gd:53/135, CharacterGeneration.gd:443.
##
## gdUnit4 v6.0.3 compatible.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

var _previous_campaign = null
var _swapped: bool = false


func _gsm() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager")


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GameState")


func after_test() -> void:
	## Restore in a lifecycle hook, never inline — an early exit would leak this
	## throwaway campaign onto the GameState autoload and break later suites.
	## (That exact leak broke test_post_battle_subsystems earlier today.)
	if not _swapped:
		return
	var gs := _gs()
	if gs:
		gs.current_campaign = _previous_campaign
	_previous_campaign = null
	_swapped = false


func _install(credits: int) -> Object:
	var gs := _gs()
	if gs == null:
		return null
	var campaign = CampaignCore.new()
	campaign.credits = credits
	_previous_campaign = gs.current_campaign
	_swapped = true
	gs.current_campaign = campaign
	return campaign


# --- the owner is authoritative on read ---------------------------------------

func test_direct_owner_write_is_visible_to_the_getter() -> void:
	var gsm := _gsm()
	var campaign = _install(40)
	if gsm == null or campaign == null:
		return
	assert_int(gsm.get_credits()).is_equal(40)

	campaign.credits -= 15  # what RedZoneSystem.purchase_license does

	assert_int(gsm.get_credits()).override_failure_message(
		"getter returned the stale cache; every arithmetic helper derives from this"
	).is_equal(25)


# --- the refund scenario, end to end ------------------------------------------

func test_a_direct_deduction_is_not_refunded_by_the_next_modify() -> void:
	var gsm := _gsm()
	var campaign = _install(40)
	if gsm == null or campaign == null:
		return
	gsm.get_credits()          # seed the cache in sync, as a real load would
	campaign.credits -= 15     # licence fee, written directly to the owner
	gsm.modify_credits(-5)     # travel cost, through the manager

	assert_int(int(campaign.credits)).override_failure_message(
		"the 15cr licence fee was refunded: expected 40-15-5=20"
	).is_equal(20)


func test_remove_credits_respects_a_direct_deduction() -> void:
	# remove_credits also gates affordability on get_credits(), so a stale cache
	# would let the player spend money they no longer have.
	var gsm := _gsm()
	var campaign = _install(20)
	if gsm == null or campaign == null:
		return
	gsm.get_credits()
	campaign.credits -= 18  # now only 2 left
	var ok: bool = gsm.remove_credits(10)

	assert_bool(ok).override_failure_message(
		"remove_credits approved a 10cr spend against a 2cr balance"
	).is_false()
	assert_int(int(campaign.credits)).is_equal(2)


# --- the owner is authoritative on write --------------------------------------

func test_setter_writes_through_even_when_the_cache_already_matches() -> void:
	# The old change-guard skipped the owner write when cache == new_amount, so a
	# campaign switch or a direct owner write left the owner permanently stale.
	var gsm := _gsm()
	var campaign = _install(30)
	if gsm == null or campaign == null:
		return
	gsm.get_credits()        # cache = 30
	campaign.credits = 999   # owner diverges behind the manager's back
	gsm.set_credits(30)      # cache already says 30

	assert_int(int(campaign.credits)).override_failure_message(
		"owner was not written through because the cache already matched"
	).is_equal(30)


func test_story_progress_reads_the_canonical_story_points() -> void:
	var gsm := _gsm()
	var campaign = _install(0)
	if gsm == null or campaign == null:
		return
	campaign.story_points = 7
	assert_int(gsm.get_story_progress()).override_failure_message(
		"story_progress cache out-voted campaign.story_points"
	).is_equal(7)
