extends GdUnitTestSuite
## Regression: credits can never go negative (Core Rules — you cannot spend below 0).
##
## Guards the negative-credits bug found in the Jul 5 2026 runtime walk: the
## "Life Support Upgrade" campaign event deducted via the UNCLAMPED
## GameStateManager.add_credits() once commit 1de89630 (backend event bridge)
## made campaign-event effects actually apply — driving the balance to -4.
## Fixes under test: CampaignEventEffects now deducts via modify_credits(), and
## add_credits() itself now clamps at 0 (GameStateManager.gd:300).

const GameStateManagerScript := preload(
	"res://src/core/managers/GameStateManager.gd")
const CampaignEventEffects := preload(
	"res://src/core/campaign/phases/post_battle/CampaignEventEffects.gd")
const PostBattleContextClass := preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")

## Bare GameStateManager (not added to the tree, so _ready() does not fire) with
## an explicit starting balance. Credit arithmetic is member-var based and needs
## no game_state, so this is a valid isolated fixture.
func _make_gsm(start_credits: int) -> Node:
	var gsm: Node = auto_free(GameStateManagerScript.new())
	gsm.set_credits(start_credits)
	return gsm

func test_add_credits_clamps_at_zero():
	## A negative larger than the balance clamps at 0 (never negative).
	var gsm := _make_gsm(2)
	gsm.add_credits(-100)
	assert_that(gsm.get_credits()).is_equal(0)

func test_modify_credits_clamps_at_zero():
	## modify_credits has always clamped; pin it so the two stay consistent.
	var gsm := _make_gsm(3)
	gsm.modify_credits(-100)
	assert_that(gsm.get_credits()).is_equal(0)

func test_add_credits_positive_unaffected():
	## Positive additions (e.g. mission pay) are unaffected by the clamp.
	var gsm := _make_gsm(2)
	gsm.add_credits(5)
	assert_that(gsm.get_credits()).is_equal(7)

func test_add_credits_partial_deduction_within_balance():
	## An affordable deduction still deducts the exact amount.
	var gsm := _make_gsm(6)
	gsm.add_credits(-4)
	assert_that(gsm.get_credits()).is_equal(2)

func test_life_support_upgrade_never_negative():
	## The "Life Support Upgrade" event (cost 1D6) must not drive credits below 0
	## when the crew cannot afford it. Regression for the -4 credits bug.
	var gsm := _make_gsm(0)
	var ctx = auto_free(PostBattleContextClass.new())
	ctx.game_state_manager = gsm
	var effects := CampaignEventEffects.new()
	effects.apply_effect("Life Support Upgrade", ctx)
	assert_that(gsm.get_credits()).is_greater_equal(0)
