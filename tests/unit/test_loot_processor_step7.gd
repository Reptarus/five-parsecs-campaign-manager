extends GdUnitTestSuite
## Pins the 2026-06-01 LootProcessor fix to Core Rules p.120 Step 7 "Gather the Loot":
## roll ONCE on the Loot Table per battle (NOT per defeated enemy with a fabricated D6
## tier gate). Invasion battles grant no loot; a Quest's final stage grants 3 rolls.

const LootProcessor = preload("res://src/core/campaign/phases/post_battle/LootProcessor.gd")
const PostBattleContext = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")


func _make_ctx(battle_result: Dictionary) -> PostBattleContext:
	var ctx = PostBattleContext.new()
	ctx.battle_result = battle_result
	# Several defeated enemies present — must NOT scale loot (the old fabricated behavior).
	ctx.defeated_enemies = [{"type": "basic"}, {"type": "elite"}, {"type": "boss"}, {"type": "basic"}]
	return ctx


func test_normal_battle_is_one_roll() -> void:
	var lp = LootProcessor.new()
	# One Loot Table roll -> 1 item, or 2 if a DAMAGED category is rolled. Never 4 (per-enemy).
	for i in range(40):
		var loot: Array = lp.process_loot_gathering(_make_ctx({}))
		assert_int(loot.size()).is_greater_equal(1)
		assert_int(loot.size()).is_less_equal(2)


func test_invasion_yields_no_loot() -> void:
	var lp = LootProcessor.new()
	var loot: Array = lp.process_loot_gathering(_make_ctx({"is_invasion": true}))
	assert_array(loot).is_empty()


func test_quest_final_stage_is_three_rolls() -> void:
	var lp = LootProcessor.new()
	for i in range(20):
		var loot: Array = lp.process_loot_gathering(_make_ctx({"quest_final_stage": true}))
		# 3 rolls, each 1-2 items.
		assert_int(loot.size()).is_greater_equal(3)
		assert_int(loot.size()).is_less_equal(6)


func test_reward_grants_resources_not_item() -> void:
	# Core Rules p.133: a Rewards-Subtable result grants credits/rumors/story points,
	# NOT a carried item. It must apply the resource and not enter the inventory.
	var lp = LootProcessor.new()
	var ctx = PostBattleContext.new()
	var stub = _StubGameState.new()
	ctx.game_state = stub
	lp._add_loot_to_inventory(ctx, {
		"name": "Cargo Crate", "type": "reward", "is_reward": true, "credits": 5
	})
	assert_int(stub.credits_added).is_equal(5)
	assert_int(stub.items_added).is_equal(0)


class _StubGameState extends RefCounted:
	var credits_added: int = 0
	var items_added: int = 0
	func add_credits(amount: int) -> void:
		credits_added += amount
	func add_inventory_item(_data: Dictionary) -> void:
		items_added += 1
